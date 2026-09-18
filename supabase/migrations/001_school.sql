-- Closed RPC API. Tables are not writable by clients. All money mutations hold
-- the school's transaction lock, then update immutable ledger + wallet + stock.
create schema if not exists app_private;
revoke all on schema app_private from public;
create table public.schools (
  id uuid primary key default gen_random_uuid(), name text not null
);
create table public.profiles (
  id uuid primary key references auth.users(id), school_id uuid not null references public.schools(id),
  name text not null check(length(name) between 1 and 100),
  role text not null check(role in ('student','teacher','coordinator','guardian','delivery'))
);
create table public.school_records (
  id text primary key default gen_random_uuid()::text,
  school_id uuid not null references public.schools(id),
  kind text not null check(kind in ('classes','subjects','enrollments','assignments','links','activities','submissions','personal','wallets','ledger','rewards','redemptions','rules','goals','contributions','achievements','notifications','audit')),
  body jsonb not null check(jsonb_typeof(body)='object'),
  created_at timestamptz not null default now()
);
create index records_school_kind on public.school_records(school_id,kind);
create index records_student on public.school_records(school_id,kind,(body->>'student_id'));
create unique index unique_wallet on public.school_records(school_id,(body->>'student_id')) where kind='wallets';
create unique index unique_submission on public.school_records(school_id,(body->>'activity_id'),(body->>'student_id')) where kind='submissions';
create unique index unique_credit on public.school_records(school_id,(body->>'reference')) where kind='ledger' and body->>'kind'='gain';
create unique index unique_correction on public.school_records(school_id,(body->>'reference')) where kind='ledger' and body->>'kind'='correction';
create unique index unique_request on public.school_records(school_id,(body->>'student_id'),(body->>'request_id')) where kind='redemptions';
create unique index unique_pickup_code on public.school_records((body->>'code')) where kind='redemptions';
create unique index unique_membership on public.school_records(school_id,(body->>'student_id'),(body->>'class_id')) where kind='enrollments';
create unique index unique_guardian on public.school_records(school_id,(body->>'student_id'),(body->>'guardian_id')) where kind='links';
create unique index unique_badge on public.school_records(school_id,(body->>'student_id'),(body->>'name')) where kind='achievements';
alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.school_records enable row level security;

create function app_private.me() returns public.profiles language sql stable security definer set search_path='' as $$
  select p from public.profiles p where id=auth.uid()
$$;
create function app_private.get_record(k text, rid text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 select body||jsonb_build_object('id',id) into result from public.school_records where kind=k and id=rid and school_id=(app_private.me()).school_id;
 if result is null then raise exception 'Registro não encontrado nesta escola.'; end if;
 return result;
end $$;
create function app_private.items(k text) returns setof jsonb language sql stable security definer set search_path='' as $$
 select body||jsonb_build_object('id',id) from public.school_records where kind=k and school_id=(app_private.me()).school_id order by created_at desc,id
$$;
create function app_private.put(k text, b jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare rid text:=coalesce(b->>'id',gen_random_uuid()::text); school uuid:=(app_private.me()).school_id;
begin
 insert into public.school_records(id,school_id,kind,body) values(rid,school,k,b-'id')
 on conflict(id) do update set body=excluded.body where school_records.school_id=school and school_records.kind=k;
 if not found then raise exception 'Registro pertence a outro contexto.'; end if;
 return b||jsonb_build_object('id',rid);
end $$;
create function app_private.check_rule(ok boolean, message text) returns void language plpgsql set search_path='' as $$begin if ok is distinct from true then raise exception '%',message; end if; end $$;
create function app_private.linked(student text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from app_private.items('links') r where r->>'student_id'=student and r->>'guardian_id'=auth.uid()::text)
$$;
create function app_private.in_class(student text, classroom text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from app_private.items('enrollments') r where r->>'student_id'=student and r->>'class_id'=classroom)
$$;
create function app_private.teaches(a jsonb) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from app_private.items('assignments') r where r->>'teacher_id'=auth.uid()::text and r->>'class_id'=a->>'class_id' and (a->>'kind'<>'academic' or r->>'subject'=a->>'subject'))
$$;
create function app_private.participates(a jsonb,student text) returns boolean language sql stable security definer set search_path='' as $$
 select app_private.in_class(student,a->>'class_id') and (coalesce(jsonb_array_length(a->'participants'),0)=0 or a->'participants' ? student)
$$;
create function app_private.sees_student(student text) returns boolean language sql stable security definer set search_path='' as $$
 select case (app_private.me()).role
 when 'coordinator' then true when 'student' then student=auth.uid()::text when 'guardian' then app_private.linked(student)
 when 'teacher' then exists(select 1 from app_private.items('assignments') a where a->>'teacher_id'=auth.uid()::text and app_private.in_class(student,a->>'class_id')) else false end
$$;
create function app_private.sees_activity(a jsonb) returns boolean language sql stable security definer set search_path='' as $$
 select case (app_private.me()).role
 when 'coordinator' then true when 'teacher' then app_private.teaches(a)
 when 'student' then app_private.participates(a,auth.uid()::text)
 when 'guardian' then exists(select 1 from app_private.items('links') l where l->>'guardian_id'=auth.uid()::text and app_private.participates(a,l->>'student_id')) else false end
$$;
create function app_private.sees_class(cid text) returns boolean language sql stable security definer set search_path='' as $$
 select case (app_private.me()).role when 'coordinator' then true when 'student' then app_private.in_class(auth.uid()::text,cid)
 when 'teacher' then exists(select 1 from app_private.items('assignments') a where a->>'teacher_id'=auth.uid()::text and a->>'class_id'=cid)
 when 'guardian' then exists(select 1 from app_private.items('links') l where l->>'guardian_id'=auth.uid()::text and app_private.in_class(l->>'student_id',cid)) else false end
$$;
create function app_private.visible(k text,b jsonb) returns boolean language plpgsql stable security definer set search_path='' as $$
declare role text:=(app_private.me()).role;
begin
 if role is null or role='delivery' then return false; end if;
 if k='personal' then return b->>'student_id'=auth.uid()::text; end if;
 if k in ('wallets','ledger','redemptions','achievements','notifications') then return app_private.sees_student(b->>'student_id'); end if;
 if k='submissions' then return app_private.sees_student(b->>'student_id') and app_private.sees_activity(app_private.get_record('activities',b->>'activity_id')); end if;
 if k='activities' then return app_private.sees_activity(b); end if;
 if k='audit' then return role='coordinator'; end if;
 if k='assignments' then return role='coordinator' or b->>'teacher_id'=auth.uid()::text; end if;
 if k in ('enrollments','links') then return app_private.sees_student(b->>'student_id'); end if;
 if k='classes' then return app_private.sees_class(b->>'id'); end if;
 if k='goals' then return app_private.sees_class(b->>'class_id'); end if;
 if k='contributions' then return app_private.sees_class(b->>'class_id'); end if;
 return k in ('subjects','rules','rewards');
end $$;
create policy school_tenant on public.schools for select to authenticated using(id=(app_private.me()).school_id);
create policy profile_scope on public.profiles for select to authenticated using(school_id=(app_private.me()).school_id and (id=auth.uid() or ((app_private.me()).role='coordinator') or (role='student' and app_private.sees_student(id::text))));
create policy record_scope on public.school_records for select to authenticated using(school_id=(app_private.me()).school_id and app_private.visible(kind,body||jsonb_build_object('id',id)));
-- No table grants. RPC is the sole API; policy remains defense in depth.
revoke all on public.schools,public.profiles,public.school_records from anon,authenticated;
create function app_private.immutable_history() returns trigger language plpgsql set search_path='' as $$
begin if old.kind in ('ledger','audit','contributions','achievements') then raise exception 'Histórico imutável: use lançamento compensatório.'; end if; return case when tg_op='DELETE' then old else new end; end $$;
create trigger immutable_history before update or delete on public.school_records for each row execute function app_private.immutable_history();
create function app_private.financial_constraints() returns trigger language plpgsql set search_path='' as $$
begin
 if new.kind='wallets' then perform app_private.check_rule((new.body->>'available')::int>=0 and (new.body->>'reserved')::int>=0 and (new.body->>'earned')::int>=0,'Saldo não pode ser negativo.'); end if;
 if new.kind='rewards' then perform app_private.check_rule((new.body->>'stock')::int>=0 and (new.body->>'price')::int>0 and (new.body->>'limit')::int>0,'Estoque, preço ou limite inválido.'); end if;
 return new;
end $$;
create trigger financial_constraints before insert or update on public.school_records for each row execute function app_private.financial_constraints();
create function app_private.wallet(student text) returns jsonb language plpgsql security definer set search_path='' as $$
declare w jsonb;
begin select r into w from app_private.items('wallets') r where r->>'student_id'=student;
 if w is null then w:=app_private.put('wallets',jsonb_build_object('student_id',student,'available',0,'reserved',0,'earned',0)); end if; return w;
end $$;
create function app_private.movement(student text,k text,amount int,title text,ref text) returns void language plpgsql security definer set search_path='' as $$
begin perform app_private.put('ledger',jsonb_build_object('student_id',student,'kind',k,'amount',amount,'title',title,'reference',ref,'actor',(app_private.me()).name,'actor_id',auth.uid(),'at',now())); end $$;
create function app_private.notice(student text,message text) returns void language plpgsql security definer set search_path='' as $$
begin perform app_private.put('notifications',jsonb_build_object('student_id',student,'text',message,'at',now())); end $$;
create function public.school_snapshot() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; me public.profiles:=app_private.me(); k text; records jsonb;
begin
 perform app_private.check_rule(me.id is not null,'Conta sem vínculo com a escola.');
 result:=jsonb_build_object('account',to_jsonb(me));
 if me.role='delivery' then
   select coalesce(jsonb_agg(jsonb_build_object('id',r->>'id','name',r->>'name','location',r->>'location','code',r->>'code','status',r->>'status')),'[]'::jsonb) into records from app_private.items('redemptions') r;
   return result||jsonb_build_object('redemptions',records);
 end if;
 for k in select distinct kind from public.school_records where school_id=me.school_id loop
   select coalesce(jsonb_agg(case when k='contributions' then jsonb_build_object('class_id',r->>'class_id') else r end),'[]'::jsonb) into records from app_private.items(k) r where app_private.visible(k,r);
   result:=result||jsonb_build_object(k,records);
 end loop;
 select coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) into records from public.profiles p where p.school_id=me.school_id and (p.id=me.id or me.role='coordinator' or (p.role='student' and app_private.sees_student(p.id::text)));
 return result||jsonb_build_object('profiles',records);
end $$;

create function public.school_command(operation text,payload jsonb) returns void language plpgsql security definer set search_path='' as $$
declare me public.profiles:=app_private.me(); a jsonb; s jsonb; w jsonb; r jsonb; e jsonb; b jsonb; sid text; student text; count_used int; amount int; k text; approve boolean; rid text; code text;
begin
 perform app_private.check_rule(me.id is not null,'Conta sem vínculo com a escola.');
 -- A single lock order for every mutating command prevents deadlocks and races.
 perform 1 from public.schools where id=me.school_id for update;
 case operation
 when 'publish' then
   perform app_private.check_rule(me.role in ('teacher','coordinator'),'Você não pode publicar atividades.');
   perform app_private.get_record('classes',payload->>'class_id');
   perform app_private.check_rule(me.role='coordinator' or app_private.teaches(payload),'Turma ou disciplina fora da sua atribuição.');
   perform app_private.check_rule(length(trim(payload->>'title')) between 1 and 200 and length(trim(payload->>'criteria')) between 1 and 5000 and length(payload->>'description')<=10000,'Informe título, instruções e critérios observáveis.');
   perform app_private.check_rule(payload->>'kind' in ('academic','practice','collective') and payload->>'validator' in ('teacher','guardian'),'Tipo ou validador inválido.');
   perform app_private.check_rule((payload->>'coins')::int between 0 and 10000 and (payload->>'limit')::int between 1 and 1000 and payload->>'frequency' in ('once','daily','weekly'),'Pontuação ou frequência inválida.');
   perform app_private.check_rule((payload->>'due_at')::timestamptz>(payload->>'start_at')::timestamptz,'Prazo deve ser posterior ao início.');
   perform app_private.check_rule(payload->>'validator'<>'guardian' or payload->>'kind'='practice','A família confirma somente boas práticas atribuídas.');
   if payload->>'kind'='academic' then perform app_private.check_rule(exists(select 1 from app_private.items('subjects') t where t->>'name'=payload->>'subject'),'Disciplina inválida.'); end if;
   for student in select jsonb_array_elements_text(coalesce(payload->'participants','[]')) loop perform app_private.check_rule(app_private.in_class(student,payload->>'class_id'),'Participante fora da turma.'); end loop;
   perform app_private.put('activities',(payload-'id'-'teacher_id'-'school_id')||jsonb_build_object('teacher_id',me.id,'cancelled',false));
 when 'submit' then
   perform app_private.check_rule(me.role='student','Somente o aluno envia a própria entrega.');
   a:=app_private.get_record('activities',payload->>'activity_id');
   perform app_private.check_rule(app_private.participates(a,me.id::text) and not (a->>'cancelled')::boolean,'Atividade indisponível.');
   perform app_private.check_rule(now()>=(a->>'start_at')::timestamptz,'A atividade ainda não começou.');
   perform app_private.check_rule(length(trim(payload->>'text')) between 1 and 10000,'Descreva sua entrega em até 10000 caracteres.');
   select t into s from app_private.items('submissions') t where t->>'activity_id'=a->>'id' and t->>'student_id'=me.id::text;
   perform app_private.check_rule(s is null or s->>'status' in ('changes','completed'),'A entrega já está aguardando validação.');
   if s->>'status'='completed' then
     perform app_private.check_rule((s->>'count')::int<(a->>'limit')::int,'Limite de participação atingido.');
     perform app_private.check_rule(a->>'frequency'<>'once' and now()>=(s->>'validated_at')::timestamptz+case when a->>'frequency'='daily' then interval '1 day' else interval '7 days' end,'Aguarde o próximo período de participação.');
   end if;
   s:=coalesce(s,jsonb_build_object('activity_id',a->>'id','student_id',me.id,'count',0));
   perform app_private.put('submissions',s||jsonb_build_object('text',payload->>'text','status','submitted','submitted_at',now(),'review',null));
 when 'validate' then
   approve:=(payload->>'approve')::boolean;
   perform app_private.check_rule(jsonb_array_length(payload->'ids')>0,'Selecione uma entrega.');
   for sid in select distinct jsonb_array_elements_text(payload->'ids') loop
     s:=app_private.get_record('submissions',sid); a:=app_private.get_record('activities',s->>'activity_id'); student:=s->>'student_id';
     perform app_private.check_rule(not (a->>'cancelled')::boolean,'Atividade cancelada.');
     perform app_private.check_rule(me.role='coordinator' or (me.role='teacher' and app_private.teaches(a) and a->>'validator'='teacher') or (me.role='guardian' and app_private.linked(student) and a->>'validator'='guardian'),'Você não pode validar esta entrega.');
     if s->>'status'='completed' and approve then continue; end if;
     perform app_private.check_rule(s->>'status'='submitted','A entrega não está aguardando validação.');
     if not approve then
       perform app_private.check_rule(length(trim(payload->>'feedback')) between 1 and 5000,'Explique os ajustes necessários.');
       perform app_private.put('submissions',s||jsonb_build_object('status','changes','feedback',payload->>'feedback'));
     else
       count_used:=(s->>'count')::int+1; amount:=(a->>'coins')::int;
       perform app_private.check_rule(count_used<=(a->>'limit')::int,'Limite de participação atingido.');
       perform app_private.put('submissions',s||jsonb_build_object('status','completed','count',count_used,'validated_at',now(),'validator_id',me.id,'review',null));
       w:=app_private.wallet(student);
       perform app_private.put('wallets',w||jsonb_build_object('available',(w->>'available')::int+amount,'earned',(w->>'earned')::int+amount));
       perform app_private.movement(student,'gain',amount,a->>'title',sid||':'||count_used);
       if (a->>'collective')::boolean then
         perform app_private.put('contributions',jsonb_build_object('student_id',student,'class_id',a->>'class_id','submission_id',sid,'category',a->>'category'));
       end if;
       select count(*) into count_used from app_private.items('contributions') t where t->>'student_id'=student and t->>'category'='Colaboração';
       if count_used>=5 and not exists(select 1 from app_private.items('achievements') t where t->>'student_id'=student and t->>'name'='Parceiro da Turma') then
         perform app_private.put('achievements',jsonb_build_object('student_id',student,'name','Parceiro da Turma','at',now()));
       end if;
     end if;
     perform app_private.notice(student,'Há uma atualização na avaliação de uma atividade.');
   end loop;
 when 'review' then
   s:=app_private.get_record('submissions',payload->>'id');
   perform app_private.check_rule(me.role='student' and s->>'student_id'=me.id::text and s->>'status' in ('completed','changes'),'Revisão indisponível.');
   perform app_private.check_rule(length(trim(payload->>'reason')) between 1 and 5000,'Informe o motivo da revisão.');
   perform app_private.put('submissions',s||jsonb_build_object('review',payload->>'reason'));
 when 'adapt' then
   a:=app_private.get_record('activities',payload->>'id');
   perform app_private.check_rule(me.role='coordinator' or (me.role='teacher' and app_private.teaches(a)),'Atividade fora da sua atribuição.');
   perform app_private.check_rule(length(trim(payload->>'reason')) between 1 and 5000,'Informe a justificativa.');
   if payload ? 'due_at' then perform app_private.check_rule((payload->>'due_at')::timestamptz>=(a->>'due_at')::timestamptz,'Use uma data posterior ao prazo atual.'); a:=a||jsonb_build_object('due_at',payload->>'due_at'); end if;
   if payload ? 'criteria' then perform app_private.check_rule(length(trim(payload->>'criteria')) between 1 and 5000,'Informe critérios observáveis.'); a:=a||jsonb_build_object('criteria',payload->>'criteria'); end if;
   if payload->>'cancelled'='true' then a:=a||jsonb_build_object('cancelled',true); end if;
   perform app_private.put('activities',a);
 when 'personal' then
   perform app_private.check_rule(me.role='student','Compromissos pessoais são privados do aluno.');
   perform app_private.check_rule(length(trim(payload->>'title')) between 1 and 200 and (payload->>'due_at')::timestamptz is not null,'Título ou data inválidos.');
   perform app_private.put('personal',jsonb_build_object('student_id',me.id,'title',payload->>'title','due_at',payload->>'due_at'));
 when 'reserve' then
   perform app_private.check_rule(me.role='student','Somente o aluno solicita seu resgate.');
   perform app_private.check_rule(length(payload->>'request_id') between 1 and 200,'Identificador de solicitação obrigatório.');
   if exists(select 1 from app_private.items('redemptions') t where t->>'student_id'=me.id::text and t->>'request_id'=payload->>'request_id') then return; end if;
   r:=app_private.get_record('rewards',payload->>'reward_id'); w:=app_private.wallet(me.id::text); amount:=(r->>'price')::int;
   perform app_private.check_rule(now() between (r->>'start_at')::timestamptz and (r->>'end_at')::timestamptz,'Recompensa fora do período disponível.');
   perform app_private.check_rule((r->>'stock')::int>0,'Esta recompensa está sem estoque.');
   perform app_private.check_rule((w->>'available')::int>=amount,'Você ainda não tem Star Coins suficientes.');
   select count(*) into count_used from app_private.items('redemptions') t where t->>'student_id'=me.id::text and t->>'reward_id'=r->>'id' and t->>'status'<>'cancelled';
   perform app_private.check_rule(count_used<(r->>'limit')::int,'Limite de resgates atingido.');
   rid:=gen_random_uuid()::text; code:=upper(replace(gen_random_uuid()::text,'-',''));
   perform app_private.put('redemptions',jsonb_build_object('id',rid,'student_id',me.id,'reward_id',r->>'id','request_id',payload->>'request_id','name',r->>'name','location',r->>'location','price',amount,'code',code,'status','reserved','at',now()));
   perform app_private.put('wallets',w||jsonb_build_object('available',(w->>'available')::int-amount,'reserved',(w->>'reserved')::int+amount));
   perform app_private.put('rewards',r||jsonb_build_object('stock',(r->>'stock')::int-1));
   perform app_private.movement(me.id::text,'reserve',-amount,r->>'name',rid);
   perform app_private.notice(me.id::text,'Seu resgate está pronto para retirada.');
 when 'deliver','cancel_redemption' then
   if operation='deliver' then
     perform app_private.check_rule(me.role in ('delivery','coordinator'),'Você não pode confirmar entregas.');
     select t into r from app_private.items('redemptions') t where t->>'code'=payload->>'code';
     perform app_private.check_rule(r is not null,'Código inválido.');
   else
     r:=app_private.get_record('redemptions',payload->>'id');
     perform app_private.check_rule(me.role='coordinator' or (me.role='student' and r->>'student_id'=me.id::text),'Você não pode cancelar este resgate.');
   end if;
   perform app_private.check_rule(r->>'status'='reserved','Este código já foi utilizado ou cancelado.');
   student:=r->>'student_id'; amount:=(r->>'price')::int; w:=app_private.wallet(student);
   w:=w||jsonb_build_object('reserved',(w->>'reserved')::int-amount);
   if operation='deliver' then
     r:=r||jsonb_build_object('status','delivered','delivered_at',now(),'delivered_by',me.id);
     perform app_private.movement(student,'spend',-amount,r->>'name',r->>'id');
   else
     r:=r||jsonb_build_object('status','cancelled'); w:=w||jsonb_build_object('available',(w->>'available')::int+amount);
     e:=app_private.get_record('rewards',r->>'reward_id'); perform app_private.put('rewards',e||jsonb_build_object('stock',(e->>'stock')::int+1));
     perform app_private.movement(student,'refund',amount,r->>'name',r->>'id');
   end if;
   perform app_private.put('redemptions',r); perform app_private.put('wallets',w);
   perform app_private.notice(student,'O andamento de um resgate foi atualizado.');
 when 'save_reward' then
   perform app_private.check_rule(me.role='coordinator','Somente a coordenação administra recompensas.');
   perform app_private.check_rule(length(trim(payload->>'name')) between 1 and 200 and length(trim(payload->>'location')) between 1 and 200,'Informe nome e local.');
   perform app_private.check_rule((payload->>'price')::int>0 and (payload->>'stock')::int>=0 and (payload->>'limit')::int>0,'Preço, estoque ou limite inválido.');
   perform app_private.check_rule((payload->>'end_at')::timestamptz>(payload->>'start_at')::timestamptz,'Período inválido.');
   if payload ? 'id' then perform app_private.get_record('rewards',payload->>'id'); end if;
   perform app_private.put('rewards',payload);
 when 'rules' then
   perform app_private.check_rule(me.role='coordinator','Somente a coordenação define as regras.');
   perform app_private.check_rule((payload->>'coins')::int between 0 and 10000,'Pontuação inválida.');
   r:=app_private.get_record('rules',payload->>'id'); perform app_private.put('rules',r||jsonb_build_object('coins',(payload->>'coins')::int));
 when 'correct' then
   perform app_private.check_rule(me.role='coordinator','Somente a coordenação corrige lançamentos.');
   e:=app_private.get_record('ledger',payload->>'id');
   perform app_private.check_rule(e->>'kind'='gain' and not exists(select 1 from app_private.items('ledger') t where t->>'kind'='correction' and t->>'reference'=e->>'id'),'Lançamento já corrigido ou não elegível.');
   perform app_private.check_rule(length(trim(payload->>'reason')) between 10 and 5000,'Explique o erro do lançamento (mínimo 10 caracteres).');
   student:=e->>'student_id'; amount:=(e->>'amount')::int; w:=app_private.wallet(student);
   perform app_private.check_rule((w->>'available')::int>=amount,'Saldo disponível insuficiente para estornar. Cancele reservas antes de corrigir.');
   perform app_private.put('wallets',w||jsonb_build_object('available',(w->>'available')::int-amount));
   perform app_private.movement(student,'correction',-amount,'Correção: '||(payload->>'reason'),e->>'id');
 when 'manage' then
   perform app_private.check_rule(me.role='coordinator','Somente a coordenação administra cadastros.');
   k:=payload->>'table'; b:=payload->'row';
   perform app_private.check_rule(k in ('classes','subjects','enrollments','assignments','links'),'Cadastro inválido.');
   if k in ('classes','subjects') then perform app_private.check_rule(length(trim(b->>'name')) between 1 and 100,'Informe um nome.'); end if;
   if k in ('enrollments','links') then perform app_private.check_rule(exists(select 1 from public.profiles where id::text=b->>'student_id' and school_id=me.school_id and role='student'),'Aluno inválido.'); end if;
   if k='links' then perform app_private.check_rule(exists(select 1 from public.profiles where id::text=b->>'guardian_id' and school_id=me.school_id and role='guardian'),'Responsável inválido.'); end if;
   if k in ('enrollments','assignments') then perform app_private.get_record('classes',b->>'class_id'); end if;
   if k='assignments' then
     perform app_private.check_rule(exists(select 1 from public.profiles where id::text=b->>'teacher_id' and school_id=me.school_id and role='teacher'),'Professor inválido.');
     perform app_private.check_rule(exists(select 1 from app_private.items('subjects') t where t->>'name'=b->>'subject'),'Disciplina inválida.');
   end if;
   if b ? 'id' then
     e:=app_private.get_record(k,b->>'id');
     if k='subjects' and e->>'name'<>b->>'name' then
       for r in select item from app_private.items('assignments') item where item->>'subject'=e->>'name' loop
         perform app_private.put('assignments',r||jsonb_build_object('subject',b->>'name'));
       end loop;
       for r in select item from app_private.items('activities') item where item->>'subject'=e->>'name' loop
         perform app_private.put('activities',r||jsonb_build_object('subject',b->>'name'));
       end loop;
     end if;
   end if;
   perform app_private.put(k,b);
 else raise exception 'Operação não reconhecida.';
 end case;
 perform app_private.put('audit',jsonb_build_object('operation',operation,'actor',me.name,'actor_id',me.id,'at',now(),'reason',coalesce(payload->>'reason',''),'reference',coalesce(payload->>'id',payload->>'activity_id',payload->>'reward_id',''),'submission_ids',coalesce(payload->'ids','[]'::jsonb)));
end $$;
revoke all on all functions in schema app_private from public,anon,authenticated;
revoke all on function public.school_snapshot() from public,anon;
revoke all on function public.school_command(text,jsonb) from public,anon;
grant execute on function public.school_snapshot() to authenticated;
grant execute on function public.school_command(text,jsonb) to authenticated;

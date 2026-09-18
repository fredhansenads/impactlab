-- Invoked only by the verified Edge Function using a server-side service key.
create function public.provision_school_user(actor uuid,target uuid,display_name text,access_role text)
returns void language plpgsql security definer set search_path='' as $$
declare coordinator public.profiles;
begin
 select * into coordinator from public.profiles where id=actor and role='coordinator';
 perform app_private.check_rule(coordinator.id is not null,'Coordenação inválida.');
 perform app_private.check_rule(access_role in ('student','teacher','guardian','delivery') and length(trim(display_name)) between 1 and 100,'Perfil ou nome inválido.');
 perform 1 from public.schools where id=coordinator.school_id for update;
 insert into public.profiles(id,school_id,name,role) values(target,coordinator.school_id,display_name,access_role);
 if access_role='student' then
   insert into public.school_records(school_id,kind,body) values(coordinator.school_id,'wallets',jsonb_build_object('student_id',target,'available',0,'reserved',0,'earned',0));
 end if;
 insert into public.school_records(school_id,kind,body) values(coordinator.school_id,'audit',jsonb_build_object('operation','invite','actor',coordinator.name,'actor_id',actor,'reference',target,'at',now(),'reason','Cadastro pela coordenação'));
end $$;
revoke all on function public.provision_school_user(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.provision_school_user(uuid,uuid,text,text) to service_role;

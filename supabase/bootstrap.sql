-- Run with psql using -v coordinator_id=<existing Auth UUID> -v school_name=<name>
-- This creates a NEW school. Never run against a school already configured.
begin;
select gen_random_uuid()::text as school_id \gset
insert into public.schools(id,name) values(:'school_id',:'school_name');
insert into public.profiles(id,school_id,name,role) values(:'coordinator_id',:'school_id','Coordenação','coordinator');
insert into public.school_records(school_id,kind,body) values
(:'school_id','rules','{"key":"academic","name":"Atividade escolar","coins":10}'),
(:'school_id','rules','{"key":"practice","name":"Boa prática","coins":15}'),
(:'school_id','rules','{"key":"collective","name":"Projeto coletivo","coins":20}');
commit;

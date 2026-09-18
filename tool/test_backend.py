"""Integration suite on an isolated PostgreSQL Docker container. No external service.
Creates a new test database each run; leaves it for inspection. Auth stub is test-only.
Run: python tool/test_backend.py [container-name]
"""
from pathlib import Path
import concurrent.futures, json, subprocess, sys, time
CONTAINER=sys.argv[1] if len(sys.argv)>1 else 'impactlab-postgres-test'
DB='portal_test_'+str(int(time.time()))
ROOT=Path(__file__).resolve().parent.parent
subprocess.run(['docker','exec',CONTAINER,'createdb','-U','postgres',DB],check=True,capture_output=True)
def sql(q,ok=True):
 p=subprocess.run(['docker','exec','-i',CONTAINER,'psql','-U','postgres','-d',DB,'-At','-v','ON_ERROR_STOP=1'],input=q,text=True,encoding='utf-8',capture_output=True)
 if ok and p.returncode: raise AssertionError(p.stderr+'\n'+q[:500])
 if not ok: assert p.returncode, 'Expected permission/rule rejection: '+q
 return p.stdout.strip()
# Roles belong to cluster, so allow repeat runs without recreating them.
stub=(ROOT/'supabase/tests/auth_stub.sql').read_text(encoding='utf-8-sig')
for role in ('anon','authenticated','service_role'):
 if role=='service_role': stub += '\ncreate role service_role nologin;'
 stub=stub.replace(f'create role {role} nologin;',f"do $$ begin if not exists(select from pg_roles where rolname='{role}') then create role {role} nologin; end if; end $$;")
sql(stub)
for migration in sorted((ROOT/'supabase/migrations').glob('*.sql')): sql(migration.read_text(encoding='utf-8-sig'))
SCHOOL='10000000-0000-0000-0000-000000000001'; OTHER='10000000-0000-0000-0000-000000000002'
IDS={role:f'20000000-0000-0000-0000-{i:012}' for i,role in enumerate(['student','student2','teacher','coordinator','guardian','delivery','outsider','teacher2'],1)}
q=f"insert into public.schools values ('{SCHOOL}','Escola teste'),('{OTHER}','Outra escola');"
for role,uid in IDS.items():
 actual='student' if role in ('student2','outsider') else 'teacher' if role=='teacher2' else role
 q+=f"insert into auth.users values ('{uid}'); insert into public.profiles values ('{uid}','{OTHER if role=='outsider' else SCHOOL}','{role}','{actual}');"
sql(q)
def literal(v): return "'"+json.dumps(v,ensure_ascii=False).replace("'","''")+"'::jsonb"
def record(kind,id,b,school=SCHOOL): sql(f"insert into public.school_records(id,school_id,kind,body) values ('{id}','{school}','{kind}',{literal(b)})")
record('classes','c1',{'name':'7º A'});record('classes','c2',{'name':'8º B'})
record('subjects','science',{'name':'Ciências'})
record('assignments','t1',{'teacher_id':IDS['teacher'],'class_id':'c1','subject':'Ciências'})
record('assignments','t2',{'teacher_id':IDS['teacher2'],'class_id':'c2','subject':'Ciências'})
for s in ['student','student2']:
 record('enrollments','e'+s,{'student_id':IDS[s],'class_id':'c1'})
 record('wallets','w'+s,{'student_id':IDS[s],'available':40,'reserved':0,'earned':40})
 record('ledger','opening-'+s,{'student_id':IDS[s],'kind':'gain','amount':40,'reference':'opening-'+s,'title':'Exemplo anterior','actor':'Coordenação','at':'2026-01-01T12:00:00Z'})
record('links','l1',{'student_id':IDS['student'],'guardian_id':IDS['guardian']})
record('rewards','r1',{'name':'Adesivo','description':'Exemplo','price':30,'stock':1,'limit':5,'location':'Biblioteca','instructions':'Intervalo','start_at':'2020-01-01T00:00:00Z','end_at':'2099-01-01T00:00:00Z'})
record('rewards','r2',{'name':'Brinde','description':'Exemplo','price':100,'stock':2,'limit':1,'location':'Secretaria','instructions':'Intervalo','start_at':'2020-01-01T00:00:00Z','end_at':'2099-01-01T00:00:00Z'})
def user_sql(role,q,ok=True): return sql(f"set role authenticated; set request.jwt.claim.sub='{IDS[role]}'; {q}",ok)
def command(role,op,p,ok=True): return user_sql(role,f"select public.school_command('{op}',{literal(p)});",ok)
def snapshot(role): return json.loads(user_sql(role,'select public.school_snapshot();').splitlines()[-1])
def find(kind,id):return json.loads(sql(f"select body||jsonb_build_object('id',id) from public.school_records where kind='{kind}' and id='{id}';"))
def wallet(role='student'): return find('wallets','w'+role)
passed=[]
def check(name,fn):fn();passed.append(name);print('PASS',name,flush=True)
activity={'title':'Ecossistema','description':'Observe e registre.','kind':'academic','subject':'Ciências','class_id':'c1','category':'Colaboração','criteria':'Três observações; alternativa assistida.','coins':10,'validator':'teacher','collective':True,'frequency':'once','limit':1,'start_at':'2020-01-01T00:00:00Z','due_at':'2099-01-01T00:00:00Z'}
check('student cannot publish',lambda:command('student','publish',activity,False))
check('teacher restricted by classroom',lambda:command('teacher2','publish',activity,False))
check('teacher restricted by subject',lambda:command('teacher','publish',activity|{'subject':'Português'},False))
command('teacher','publish',activity)
a=snapshot('student')['activities'][0]['id']
check('other school cannot access publication',lambda:command('outsider','submit',{'activity_id':a,'text':'Fraude'},False))
command('student','submit',{'activity_id':a,'text':'Três observações registradas.'})
s=snapshot('student')['submissions'][0]['id']
assert wallet()['available']==40
check('student cannot self-validate',lambda:command('student','validate',{'ids':[s],'approve':True},False))
check('guardian cannot validate academic work',lambda:command('guardian','validate',{'ids':[s],'approve':True},False))
check('unassigned teacher cannot validate',lambda:command('teacher2','validate',{'ids':[s],'approve':True},False))
def approval_race():
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:list(pool.map(lambda _:command('teacher','validate',{'ids':[s],'approve':True}),range(8)))
 assert wallet()['available']==50 and wallet()['earned']==50
 assert int(sql(f"select count(*) from public.school_records where kind='ledger' and body->>'reference'='{s}:1';"))==1
check('8 concurrent approvals grant exactly once',approval_race)
check('mission participation limit',lambda:command('student','submit',{'activity_id':a,'text':'Repetição'},False))
check('insufficient balance has no side effects',lambda:command('student','reserve',{'reward_id':'r2','request_id':'expensive'},False))
assert find('rewards','r2')['stock']==2
command('student','personal',{'title':'Privado','due_at':'2099-01-01T12:00:00Z'})
def privacy():
 guardian=snapshot('guardian');delivery=snapshot('delivery');other=snapshot('outsider')
 assert not guardian.get('personal') and len(guardian['wallets'])==1
 assert set(delivery)=={'account','redemptions'}
 assert not other.get('activities') and not other.get('wallets')
 assert not snapshot('coordinator').get('personal')
check('tenant, guardian, personal and delivery privacy',privacy)
check('direct wallet overwrite denied',lambda:user_sql('student',"update public.school_records set body='{\"available\":999}' where kind='wallets';",False))
check('direct academic table read denied to delivery',lambda:user_sql('delivery','select * from public.school_records;',False))
check('private function invocation denied',lambda:user_sql('student',"select app_private.put('wallets','{}');",False))
def stock_race():
 def attempt(i):
  try:command('student' if i%2==0 else 'student2','reserve',{'reward_id':'r1','request_id':f'race-{i}'});return True
  except AssertionError as e:
   assert 'sem estoque' in str(e);return False
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: results=list(pool.map(attempt,range(8)))
 assert sum(results)==1 and find('rewards','r1')['stock']==0
 assert wallet()['available']+wallet('student2')['available']==60
 assert wallet()['reserved']+wallet('student2')['reserved']==30
check('8 concurrent reservations contend for last stock atomically',stock_race)
r=json.loads(sql("select body||jsonb_build_object('id',id) from public.school_records where kind='redemptions';"))
owner='student' if r['student_id']==IDS['student'] else 'student2'
command(owner,'reserve',{'reward_id':'r1','request_id':r['request_id']})
assert int(sql("select count(*) from public.school_records where kind='redemptions';"))==1
passed.append('idempotent request retry')
command(owner,'cancel_redemption',{'id':r['id']})
assert find('rewards','r1')['stock']==1 and wallet()['reserved']+wallet('student2')['reserved']==0
check('duplicate cancellation rejected',lambda:command(owner,'cancel_redemption',{'id':r['id']},False))
check('cancelled pickup code rejected',lambda:command('delivery','deliver',{'code':r['code']},False))
command('student','reserve',{'reward_id':'r1','request_id':'final'})
r=next(x for x in snapshot('student')['redemptions'] if x['status']=='reserved')
command('delivery','deliver',{'code':r['code']})
assert wallet()['available']==20 and wallet()['reserved']==0
check('pickup code cannot be reused',lambda:command('delivery','deliver',{'code':r['code']},False))
check('ledger immutable even to administrator',lambda:sql("update public.school_records set body=body||'{\"amount\":999}' where kind='ledger';",False))
gain=next(x for x in snapshot('student')['ledger'] if x['reference']==s+':1')
command('coordinator','correct',{'id':gain['id'],'reason':'Critério registrado incorretamente'})
assert wallet()['available']==10 and wallet()['earned']==50
check('compensating correction cannot repeat',lambda:command('coordinator','correct',{'id':gain['id'],'reason':'Tentativa de correção duplicada'},False))
command('teacher','publish',activity|{'kind':'practice','subject':'','title':'Leitura familiar','validator':'guardian'})
a2=next(x['id'] for x in snapshot('student')['activities'] if x['title']=='Leitura familiar')
command('student','submit',{'activity_id':a2,'text':'Conversei com a família.'})
s2=next(x['id'] for x in snapshot('student')['submissions'] if x['activity_id']==a2)
command('guardian','validate',{'ids':[s2],'approve':True})
assert wallet()['available']==20
passed.append('family mission grants only after linked guardian confirmation')
# Validate that a mixed authorized/forbidden batch is all-or-nothing.
command('teacher','publish',activity|{'title':'Nova atividade'})
a3=next(x['id'] for x in snapshot('student')['activities'] if x['title']=='Nova atividade')
command('student','submit',{'activity_id':a3,'text':'Realizada.'})
s3=next(x['id'] for x in snapshot('student')['submissions'] if x['activity_id']==a3)
command('student2','submit',{'activity_id':a2,'text':'Realizada.'})
s4=next(x['id'] for x in snapshot('student2')['submissions'] if x['activity_id']==a2)
check('batch rollback on unauthorized validation',lambda:command('teacher','validate',{'ids':[s3,s4],'approve':True},False))
assert wallet()['available']==20 and find('submissions',s3)['status']=='submitted'
check('guardian cannot approve unlinked student',lambda:command('guardian','validate',{'ids':[s4],'approve':True},False))
check('student cannot provision privileged accounts',lambda:user_sql('student',f"select public.provision_school_user('{IDS['coordinator']}','{IDS['student']}','Novo','teacher');",False))
new_uid='30000000-0000-0000-0000-000000000001'
sql(f"insert into auth.users values ('{new_uid}'); set role service_role; select public.provision_school_user('{IDS['coordinator']}','{new_uid}','Novo aluno','student');")
assert sql(f"select school_id from public.profiles where id='{new_uid}';")==SCHOOL
passed.append('service provision creates zero-balance student in coordinator school')
record('rewards','r3',{'name':'Lápis','price':30,'stock':100,'limit':50,'location':'Secretaria','start_at':'2020-01-01T00:00:00Z','end_at':'2099-01-01T00:00:00Z'})
def balance_race():
 def attempt(i):
  try:command('student2','reserve',{'reward_id':'r3','request_id':f'balance-{i}'});return True
  except AssertionError as e:
   assert 'suficientes' in str(e);return False
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: result=list(pool.map(attempt,range(8)))
 assert sum(result)==1 and wallet('student2')['available']==10 and wallet('student2')['reserved']==30
check('8 concurrent requests cannot spend the same balance twice',balance_race)
command('coordinator','manage',{'table':'subjects','row':{'id':'science','name':'Ciências Naturais'}})
assert all(x['subject']=='Ciências Naturais' for x in snapshot('teacher')['activities'] if x['kind']=='academic')
passed.append('subject rename preserves assignments and published work')
print(f'\n{len(passed)} checks passed on PostgreSQL. Database retained: {DB}',flush=True)
(ROOT/'docs/backend-test-results.txt').write_text('\n'.join(['PostgreSQL 17 integration suite',f'Database: {DB}']+['PASS '+n for n in passed])+f'\n{len(passed)} checks passed.\n',encoding='utf-8')

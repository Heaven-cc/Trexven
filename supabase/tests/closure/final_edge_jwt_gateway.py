from pathlib import Path
import json,uuid,secrets,urllib.request,urllib.error,base64
REF='qysspzlfiysekvxnlzsh';URL='https://'+REF+'.supabase.co'
PRIVATE=Path('.batch3-tools/jwt-private');EVIDENCE=Path('docs/implementation/evidence/final_edge_jwt_gateway_results.json')
keys=json.loads((PRIVATE/'staging_keys.json').read_text())['keys']
ANON=next(k['api_key'] for k in keys if k['name']=='anon');ADMIN=next(k['api_key'] for k in keys if k['name']=='service_role')
assert REF!='ufehcfrlygqvminfjumf'
checks=[];users={};businesses=[];auth_ids=[]
def request(path,body=None,token=None,method='POST',admin=False,apikey=True):
 headers={'Content-Type':'application/json'}
 if apikey:headers['apikey']=ANON
 if token is not None or admin:headers['Authorization']='Bearer '+(ADMIN if admin else token)
 req=urllib.request.Request(URL+path,headers=headers,data=None if body is None else json.dumps(body).encode(),method=method)
 try:
  with urllib.request.urlopen(req,timeout=35) as r:return r.status,json.loads(r.read() or b'null')
 except urllib.error.HTTPError as e:
  try:return e.code,json.loads(e.read() or b'null')
  except ValueError:return e.code,None
 def_unused=None

def check(name,passed,status=None):
 checks.append({'check':name,'passed':bool(passed),'http_status':status})
 EVIDENCE.write_text(json.dumps({'project':REF,'checks':checks,'passed':all(c['passed'] for c in checks),'production_writes':0},indent=2))
 print(('PASS ' if passed else 'FAIL ')+name,flush=True)
 if not passed:raise RuntimeError('Staging JWT check failed: '+name)
def rpc(name,body,actor):return request('/rest/v1/rpc/'+name,body,users[actor]['token'])
def edge(name,body,actor=None,token=None,apikey=True):return request('/functions/v1/'+name,body,token if token is not None else users[actor]['token'] if actor else None,apikey=apikey)
def create_owner(role):
 password=secrets.token_urlsafe(32);email='trexven-jwt-'+uuid.uuid4().hex+'@example.invalid'
 status,user=request('/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True},admin=True)
 check('isolated Auth fixture '+role,status in (200,201),status);auth_ids.append(user['id'])
 status,session=request('/auth/v1/token?grant_type=password',{'email':email,'password':password})
 check('genuine Auth session '+role,status==200,status)
 users[role]={'id':user['id'],'email':email,'password':password,'token':session['access_token']}
 status,biz=rpc('complete_trexven_onboarding',{'p_business_name':'Synthetic final JWT '+role,'p_business_type':'Other','p_country':'Nigeria','p_currency':'NGN'},role)
 check('synthetic owner onboarding '+role,status==200,status);businesses.append(biz);return biz
cleanup=[]
try:
 biz=create_owner('owner');other=create_owner('other_owner')
 token=users['owner']['token'];header=json.loads(base64.urlsafe_b64decode(token.split('.')[0]+'=='))
 for slug in ['create-employee','manage-employee','angel']:
  for label,bearer,key in [('missing JWT',None,True),('no credentials',None,False),('malformed JWT','invalid',True),('tampered JWT',token[:-8]+'AAAAAAAA',True),('API key as bearer',ANON,True)]:
   status,_=edge(slug,{},token=bearer,apikey=key)
   check(slug+' rejects '+label,status in (400,401,403),status)
 for role in ['manager','sales_employee','inventory_employee','employee']:
  password=secrets.token_urlsafe(32)
  status,created=edge('create-employee',{'business_id':biz,'name':'Synthetic final JWT '+role,'password':password,'role':role},'owner')
  check('valid owner JWT creates '+role,status==200 and created.get('role')==role,status)
  status,session=edge('employee-login',{'employee_id':created['employee_code'],'password':password,'business_id':other,'role':'owner','permissions':['override_price']})
  check('pre-session employee-login returns trusted '+role,status==200 and session.get('business',{}).get('id')==biz and session.get('employee',{}).get('role')==role,status)
  users[role]={'id':session['employee']['user_id'],'employee_id':created['employee_id'],'code':created['employee_code'],'password':password,'token':session['session']['access_token']};auth_ids.append(users[role]['id'])
  status,_=request('/auth/v1/user',token=users[role]['token'],method='GET')
  check('Auth verifies actual returned '+role+' JWT',status==200,status)
 target=users['employee']
 for role in ['sales_employee','inventory_employee','other_owner']:
  status,_=edge('create-employee',{'business_id':biz,'name':'Denied fixture','password':secrets.token_urlsafe(32),'role':'employee'},role)
  check('valid '+role+' JWT cannot administer staff',status in (400,403),status)
  status,_=edge('manage-employee',{'action':'reset_password','business_id':biz,'employee_id':target['employee_id'],'new_password':secrets.token_urlsafe(32)},role)
  check('valid '+role+' JWT cannot reset staff',status in (400,403),status)
 for role in ['owner','manager']:
  new_password=secrets.token_urlsafe(32)
  status,_=edge('manage-employee',{'action':'reset_password','business_id':biz,'employee_id':target['employee_id'],'new_password':new_password},role)
  check('valid '+role+' JWT resets authorized ordinary staff',status==200,status)
  status,_=edge('employee-login',{'employee_id':target['code'],'password':target['password']})
  check('old credential rejected after '+role+' reset',status in (400,401,403),status)
  status,session=edge('employee-login',{'employee_id':target['code'],'password':new_password})
  check('new credential returns real session after '+role+' reset',status==200,status)
  target.update(password=new_password,token=session['session']['access_token'])
 status,_=edge('create-employee',{'business_id':biz,'name':'Denied promotion','password':secrets.token_urlsafe(32),'role':'manager'},'manager')
 check('manager cannot promote staff with a valid JWT',status in (400,403),status)
 status,_=edge('manage-employee',{'action':'reset_password','business_id':biz,'employee_id':users['manager']['employee_id'],'new_password':secrets.token_urlsafe(32)},'manager')
 check('manager cannot reset self through admin route',status in (400,403),status)
 for role in ['manager','sales_employee','inventory_employee','other_owner']:
  status,_=edge('angel',{'message':'Synthetic JWT authorization check','business_id':biz},role)
  check('Angel denies valid non-owner/cross-owner '+role+' JWT',status==403,status)
 status,data=edge('angel',{'message':'Synthetic JWT authorization check','business_id':biz},'owner')
 check('Angel valid owner JWT reaches owned-business handler without provider',status==503 and data.get('business_id')==biz,status)
 status,_=rpc('set_trexven_employee_status',{'p_employee_id':users['manager']['employee_id'],'p_status':'suspended'},'owner')
 check('owner revokes manager authority',status in (200,204),status)
 status,_=edge('manage-employee',{'action':'reset_password','business_id':biz,'employee_id':target['employee_id'],'new_password':secrets.token_urlsafe(32)},'manager')
 check('existing valid manager JWT denied immediately after revocation',status in (400,403),status)
 summary=json.loads(EVIDENCE.read_text());summary['session_jwt_algorithm']=header['alg'];summary['gateway_flags']={'create-employee':True,'manage-employee':True,'angel':True,'employee-login':False};EVIDENCE.write_text(json.dumps(summary,indent=2))
finally:
 for identifier in reversed(auth_ids):
  status,_=request('/auth/v1/admin/users/'+identifier,method='DELETE',admin=True)
  cleanup.append({'synthetic_auth_id':identifier,'delete_status':status})
 (PRIVATE/'fixture_cleanup.json').write_text(json.dumps({'business_ids':businesses,'auth_ids':auth_ids,'cleanup':cleanup},indent=2))
 summary=json.loads(EVIDENCE.read_text()) if EVIDENCE.exists() else {'project':REF,'checks':checks,'passed':False}
 summary['synthetic_auth_cleanup_passed']=all(c['delete_status'] in (200,204) for c in cleanup);summary['production_writes']=0;EVIDENCE.write_text(json.dumps(summary,indent=2))
 print('STAGING_JWT_CHECKS='+str(len(checks))+'; cleanup='+str(summary['synthetic_auth_cleanup_passed']),flush=True)

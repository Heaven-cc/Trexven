from pathlib import Path
import json,os,uuid,secrets,urllib.request,urllib.error,subprocess
assert os.environ.get('BATCH3_REPLAY_RUN')=='4'
raw=Path('.batch3-tools/start4.log').read_bytes()
m=json.loads(next(x for x in raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig').splitlines() if x.startswith('{')))
assert m['runtime']=='native' and m['env']['API_URL']=='http://127.0.0.1:54351'
assert m['endpoints']['database.sql']['port']==54352
probe=subprocess.run(['python','.batch3-tools/native_sql.py'],input='select 1;',text=True,capture_output=True)
assert probe.returncode==0 and probe.stdout.strip()=='1','Local stack identity verification failed'
env=m['env'];base=env['API_URL'];checks=[]
def request(method,path,body=None,token=None,admin=False):
 headers={'apikey':env['ANON_KEY'],'Content-Type':'application/json','Authorization':'Bearer '+(env['SERVICE_ROLE_KEY'] if admin else token or env['ANON_KEY'])}
 req=urllib.request.Request(base+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method)
 try:
  with urllib.request.urlopen(req,timeout=30) as r:return r.status,json.loads(r.read() or 'null')
 except urllib.error.HTTPError as e:
  try:return e.code,json.loads(e.read() or 'null')
  except ValueError:return e.code,None
def check(label,value,status=None):
 checks.append({'check':label,'passed':bool(value),'http_status':status})
 if not value:raise RuntimeError('Local HTTP assertion failed: '+label)
def user():
 password=secrets.token_urlsafe(30);email=str(uuid.uuid4())+'@example.invalid'
 status,created=request('POST','/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True},admin=True)
 check('synthetic local Auth user creation',status in (200,201),status)
 status,signed=request('POST','/auth/v1/token?grant_type=password',{'email':email,'password':password})
 check('real local Auth password session',status==200,status)
 return created['id'],signed['access_token']
def rpc(name,body,token):return request('POST','/rest/v1/rpc/'+name,body,token)
owner,ot=user();other,xt=user();inventory,it=user()
status,biz=rpc('complete_trexven_onboarding',{'p_business_name':'Synthetic HTTP Batch 3','p_business_type':'Other','p_country':'Nigeria','p_currency':'NGN'},ot)
check('owner onboarding creates scoped business',status==200,status)
request('PATCH','/rest/v1/businesses?id=eq.'+biz,{'timezone':'UTC'},ot)
status,other_biz=rpc('complete_trexven_onboarding',{'p_business_name':'Synthetic other HTTP','p_business_type':'Other','p_country':'Nigeria','p_currency':'NGN'},xt)
check('second independent owner business',status==200,status)
employee=str(uuid.uuid4())
sql=f"insert into public.employees(id,business_id,user_id,name,role,employee_code,status) values('{employee}','{biz}','{inventory}','Synthetic HTTP inventory','inventory_employee','HTTP-{employee}','active');insert into public.business_members(business_id,user_id,full_name,role,status) values('{biz}','{inventory}','Synthetic HTTP inventory','employee','active');"
r=subprocess.run(['python','.batch3-tools/native_sql.py'],input=sql,text=True,capture_output=True)
check('guarded synthetic employee fixture',r.returncode==0)
status,ids=rpc('import_trexven_catalog',{'p_business_id':biz,'p_request_id':str(uuid.uuid4()),'p_rows':[{'name':'Measured HTTP oil','unit':'litre','barcode':'HTTP-'+str(uuid.uuid4()),'selling_price':10,'initial_quantity':5.125}]},ot)
check('owner atomic catalog import',status==200,status);product=ids[0]
status,pending=rpc('save_trexven_catalog_product',{'p_business_id':biz,'p_request_id':str(uuid.uuid4()),'p_product_id':None,'p_fields':{'name':'Pending HTTP inventory'}},it)
check('inventory creates pending product without price',status==200,status)
status,rows=request('GET','/rest/v1/products?id=eq.'+pending+'&select=selling_price,active,is_active',token=ot)
check('pending remains unpriced and inactive',status==200 and rows[0]['selling_price'] is None and not rows[0]['active'] and not rows[0]['is_active'],status)
status,_=request('PATCH','/rest/v1/products?id=eq.'+product,{'selling_price':1},it)
check('inventory direct REST price denied',status>=400,status)
status,_=rpc('save_trexven_catalog_product',{'p_business_id':biz,'p_request_id':str(uuid.uuid4()),'p_product_id':product,'p_fields':{'selling_price':1}},it)
check('inventory alternative price RPC denied',status>=400,status)
status,_=request('PATCH','/rest/v1/products?id=eq.'+product,{'quantity':100},ot)
check('direct quantity bypass denied even for owner',status>=400,status)
status,_=rpc('save_trexven_catalog_product',{'p_business_id':other_biz,'p_request_id':str(uuid.uuid4()),'p_product_id':None,'p_fields':{'name':'Forged business'}},it)
check('forged business ID denied',status>=400,status)
status,rows=request('GET','/rest/v1/products?business_id=eq.'+other_biz+'&select=id',token=it)
check('cross-business REST read isolated',status==200 and rows==[],status)
delta={'p_business_id':biz,'p_product_id':product,'p_delta':1,'p_reason':'HTTP delivery','p_request_id':str(uuid.uuid4())}
status,_=rpc('adjust_trexven_catalog_stock',delta,it)
check('ungranted inventory adjustment denied',status>=400,status)
status,_=rpc('set_trexven_employee_permission',{'p_employee_id':employee,'p_permission':'adjust_stock','p_granted':True},ot)
check('owner grants existing inventory permission',status in (200,204),status)
status,q=rpc('adjust_trexven_catalog_stock',delta,it)
check('explicitly permitted inventory adjustment succeeds',status==200 and q==6.125,status)
status,q=rpc('adjust_trexven_catalog_stock',delta,it)
check('REST retry applies stock exactly once',status==200 and q==6.125,status)
status,_=rpc('set_trexven_employee_permission',{'p_employee_id':employee,'p_permission':'adjust_stock','p_granted':False},ot)
check('owner revokes inventory permission',status in (200,204),status)
delta['p_request_id']=str(uuid.uuid4())
status,_=rpc('adjust_trexven_catalog_stock',delta,it)
check('revocation rejects existing session immediately',status>=400,status)
sale={'p_request_id':str(uuid.uuid4()),'p_business_id':biz,'p_employee_id':None,'p_total':1.25,'p_payment_method':'cash','p_items':[{'product_id':product,'quantity':0.125,'unit_price':10,'discount':0}],'p_quick':True}
status,receipt=rpc('submit_trexven_sale',sale,ot)
check('fractional checkout via real Auth REST',status==200 and receipt['total']==1.25,status)
status,replayed=rpc('submit_trexven_sale',sale,ot)
check('receipt and request replay identical',status==200 and replayed==receipt,status)
status,rows=request('GET','/rest/v1/products?id=eq.'+product+'&select=quantity',token=ot)
check('checkout deducts fractional stock exactly once',status==200 and rows[0]['quantity']==6,status)
status,_=rpc('save_trexven_catalog_product',{'p_business_id':biz,'p_request_id':str(uuid.uuid4()),'p_product_id':None,'p_fields':{'name':'Missing auth'}},None)
check('missing identity fails closed',status>=400,status)
Path('docs/implementation/evidence/batch_3_http_results.json').write_text(json.dumps({'target':'fourth disposable loopback Auth/REST only','checks':checks,'passed':True},indent=2),encoding='utf-8')
print('LOCAL_HTTP_PASS='+str(len(checks)))

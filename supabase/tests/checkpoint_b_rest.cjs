// Explicit staging-only real Auth/PostgREST harness. No service-role key.
// Credentials and JWTs are local ignored artifacts; reports contain no secrets.
const fs = require('node:fs');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const dir = '.batch2-tools/';
const cfg = JSON.parse(fs.readFileSync(dir+'checkpoint_b_public_config.json'));
if (cfg.project !== 'qysspzlfiysekvxnlzsh' || cfg.url !== 'https://qysspzlfiysekvxnlzsh.supabase.co') throw Error('Staging target mismatch');
const users = JSON.parse(fs.readFileSync(dir+'checkpoint_b_credentials.json'));
const phase = process.argv[2];
const out = process.env.BATCH_2_HTTP_RESULTS || 'supabase/tests/baseline/checkpoint_b_rest_results.json';
const results = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out)) : [];
const startCount=results.length;
async function request(role, path, method='GET', body, extra={}) {
 if(path.startsWith('/rest/v1/products') && !/[?&]select=/.test(path)) path+=(path.includes('?')?'&':'?')+'select=id,business_id,name,selling_price,quantity,active,is_active';
 const token = users[role]?.token;
 const r = await fetch(cfg.url+path, {method, headers:{apikey:cfg.key,
  ...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json', ...extra},
  ...(body===undefined?{}:{body:JSON.stringify(body)}), signal:AbortSignal.timeout(30000)});
 const text = await r.text(); let data; try {data=JSON.parse(text);} catch {data=text;}
 return {status:r.status,ok:r.ok,data};
}
async function rpc(role,name,body) {return request(role,'/rest/v1/rpc/'+name,'POST',body);}
function success(r) {assert.ok(r.ok, 'HTTP '+r.status+' '+JSON.stringify(r.data));return r.data;}
async function check(name, fn) {
 try {const details=await fn(); results.push({name,pass:true,...(details?{details}:{})});console.log('PASS '+name);}
 catch(e) {results.push({name,pass:false,error:e.message});console.log('FAIL '+name+': '+e.message);}
 fs.writeFileSync(out,JSON.stringify(results,null,2)+'\n');
}
function denied(r) {assert.ok([400,401,403,404].includes(r.status), 'Unexpected response '+JSON.stringify(r));}
function item(p,qty=1,price=10) {return [{product_id:p,quantity:qty,unit_price:price,discount:0}];}
async function awaitHolder(){
 for(let i=0;i<12;i++){
  if(success(await rpc('owner','batch_2_test_hold_ready',{})))return;
  await new Promise(resolve=>setTimeout(resolve,50));
 }
 throw Error('Held-row readiness not observed');
}
function sale(m,p,request_id=crypto.randomUUID(),qty=1,price=10) {return {p_request_id:request_id,p_business_id:m.business,p_employee_id:m.sales_member,p_total:qty*price,p_payment_method:'cash',p_items:item(p,qty,price),p_quick:false};}
async function main() {
 if (phase==='setup') {
  for(const [role,u] of Object.entries(users)) {
   const r=await request(null,'/auth/v1/token?grant_type=password','POST',{email:u.email,password:u.password});
   assert.ok(r.ok && r.data.access_token,'Synthetic Auth login failed: '+r.status);
   assert.equal(r.data.user.id,u.id);u.token=r.data.access_token;
   console.log('PASS real Auth login '+role);
  }
  fs.writeFileSync(dir+'checkpoint_b_credentials.json',JSON.stringify(users));
  const m={users:Object.fromEntries(Object.entries(users).map(([k,v])=>[k,v.id]))};
  const onboarding={p_business_name:'Synthetic Checkpoint B REST',p_business_type:'Other',p_country:'Nigeria',p_currency:'NGN'};
  m.business=success(await rpc('owner','complete_trexven_onboarding',onboarding));
  m.other_business=success(await rpc('other_owner','complete_trexven_onboarding',{...onboarding,p_business_name:'Synthetic other REST'}));
  for(const role of ['manager','sales','inventory']) {
   const employee=success(await rpc('owner','finalize_trexven_employee',{p_business_id:m.business,p_user_id:users[role].id,p_name:'Synthetic '+role,p_email:users[role].email,p_phone:null,p_role:role==='manager'?'manager':role+'_employee',p_employee_code:'B2-REST-'+users[role].id.toUpperCase()}));
   m[role+'_employee']=employee.id;
  }
  const members=success(await request('owner','/rest/v1/business_members?business_id=eq.'+m.business+'&select=id,user_id'));
  m.sales_member=members.find(x=>x.user_id===users.sales.id).id;
  m.product=success(await request('owner','/rest/v1/products','POST',{business_id:m.business,name:'Synthetic REST product',selling_price:10,quantity:100},{Prefer:'return=representation'}))[0].id;
  for(const name of ['a','b','c'])m['branch_'+name]=success(await rpc('owner','create_trexven_branch',{p_business_id:m.business,p_name:'Synthetic REST '+name}));
  for(const name of ['a','b'])success(await rpc('owner','set_trexven_branch_assignment',{p_employee_id:m.sales_employee,p_branch_id:m['branch_'+name],p_active:true}));
  fs.writeFileSync(dir+'checkpoint_b_manifest.json',JSON.stringify(m));
  console.log('Synthetic REST fixtures ready; no branch activation.');return;
 }
 const m=JSON.parse(fs.readFileSync(dir+'checkpoint_b_manifest.json'));
 if(phase==='tests') {
  await check('owner own business',async()=>assert.equal(success(await request('owner','/rest/v1/businesses?id=eq.'+m.business)).length,1));
  await check('cross-business owner read denied',async()=>assert.equal(success(await request('other_owner','/rest/v1/products?id=eq.'+m.product)).length,0));
  await check('employee owner-only staff contract denied',async()=>denied(await rpc('sales','assert_trexven_staff_access',{p_business_id:m.business})));
  await check('manager self permission escalation denied',async()=>denied(await rpc('manager','set_trexven_employee_permission',{p_employee_id:m.manager_employee,p_permission:'override_price',p_granted:true})));
  await check('manager owner promotion denied',async()=>denied(await rpc('manager','update_trexven_employee',{p_employee_id:m.sales_employee,p_name:'Synthetic sales',p_phone:null,p_email:null,p_role:'owner',p_status:'active'})));
  for(const role of ['sales','inventory','manager'])await check(role+' price PATCH denied',async()=>{
   const r=await request(role,'/rest/v1/products?id=eq.'+m.product,'PATCH',{selling_price:99},{Prefer:'return=representation'});
   if(r.ok)assert.equal(r.data.length,0);else denied(r);
  });
  await check('inventory price INSERT denied',async()=>denied(await request('inventory','/rest/v1/products','POST',{business_id:m.business,name:'Forged',selling_price:10})));
  await check('inventory price UPSERT denied',async()=>denied(await request('inventory','/rest/v1/products?on_conflict=id','POST',{id:m.product,business_id:m.business,name:'Forged upsert',selling_price:10},{Prefer:'resolution=merge-duplicates,return=representation'})));
  await check('inventory bulk pricing denied atomically',async()=>denied(await request('inventory','/rest/v1/products','POST',[{business_id:m.business,name:'Mixed pending'},{business_id:m.business,name:'Mixed priced',selling_price:10}])));
  await check('failed bulk leaves no pending row',async()=>assert.equal(success(await request('owner','/rest/v1/products?business_id=eq.'+m.business+'&name=eq.Mixed%20pending')).length,0));
  await check('inventory cost price denied',async()=>denied(await request('inventory','/rest/v1/products','POST',{business_id:m.business,name:'Cost bypass',cost_price:1})));
  await check('inventory pending product allowed',async()=>{
   const p=success(await request('inventory','/rest/v1/products','POST',{business_id:m.business,name:'Synthetic pending REST'},{Prefer:'return=representation'}))[0];
   assert.equal(p.selling_price,null);assert.equal(p.is_active,false);m.pending=p.id;
  });
  await check('pending product cannot sell',async()=>denied(await rpc('owner','record_trexven_sale',{p_business_id:m.business,p_product_id:m.pending,p_quantity:1,p_unit_price:0})));
  await check('forged product business denied',async()=>denied(await request('inventory','/rest/v1/products','POST',{business_id:m.other_business,name:'Forged business'})));
  await check('permission metadata direct mutation denied',async()=>denied(await request('manager','/rest/v1/employee_permissions','POST',{employee_id:m.manager_employee,permission_id:'override_price',granted:true})));
  await check('explicit manager pricing grant works',async()=>{
   success(await rpc('owner','set_trexven_employee_permission',{p_employee_id:m.manager_employee,p_permission:'override_price',p_granted:true}));
   assert.equal(success(await request('manager','/rest/v1/products?id=eq.'+m.product,'PATCH',{selling_price:12},{Prefer:'return=representation'}))[0].selling_price,12);
  });
  await check('stale JWT price revocation immediate',async()=>{
   success(await rpc('owner','set_trexven_employee_permission',{p_employee_id:m.manager_employee,p_permission:'override_price',p_granted:false}));
   denied(await request('manager','/rest/v1/products?id=eq.'+m.product,'PATCH',{selling_price:13}));
   success(await request('owner','/rest/v1/products?id=eq.'+m.product,'PATCH',{selling_price:10}));
  });
  await check('assigned branches only REST',async()=>assert.deepEqual(success(await request('sales','/rest/v1/branches?business_id=eq.'+m.business)).map(x=>x.id).sort(),[m.branch_a,m.branch_b].sort()));
  await check('forged branch checkout denied',async()=>denied(await rpc('sales','submit_trexven_branch_sale',{...sale(m,m.product),p_branch_id:m.branch_c})));
  await check('anonymous public checkout denied',async()=>denied(await rpc(null,'submit_trexven_sale',sale(m,m.product))));
  await check('private transaction RPC unavailable',async()=>denied(await rpc('sales','process_trexven_sale',{})));
  await check('last stock concurrent checkout exactly once',async()=>{
   const p=success(await request('owner','/rest/v1/products','POST',{business_id:m.business,name:'Synthetic last stock',selling_price:10,quantity:1},{Prefer:'return=representation'}))[0];
   const r=await Promise.all([rpc('sales','submit_trexven_sale',sale(m,p.id)),rpc('sales','submit_trexven_sale',sale(m,p.id))]);
   assert.equal(r.filter(x=>x.ok).length,1);assert.equal(success(await request('owner','/rest/v1/products?id=eq.'+p.id))[0].quantity,0);
   const sales=success(await request('owner','/rest/v1/sale_items?product_id=eq.'+p.id));assert.equal(sales.length,1);
  });
  await check('concurrent duplicate request returns same receipt',async()=>{
   const key=crypto.randomUUID(),args=sale(m,m.product,key);
   const before=success(await request('owner','/rest/v1/products?id=eq.'+m.product))[0].quantity;
   const r=await Promise.all([rpc('sales','submit_trexven_sale',args),rpc('sales','submit_trexven_sale',args)]);
   assert.deepEqual(success(r[0]),success(r[1]));assert.equal(success(await request('owner','/rest/v1/products?id=eq.'+m.product))[0].quantity,before-1);
   assert.match(r[0].data.sale_number,/^TRX-/);m.saved_request=args;m.saved_receipt=r[0].data;
  });
  await check('legacy complete_pos_sale RPC works',async()=>success(await rpc('sales','complete_pos_sale',{p_business_id:m.business,p_employee_id:m.sales_member,p_total:10,p_payment_method:'cash',p_items:item(m.product)})));
  await check('wrong total failure leaves stock and sales unchanged',async()=>{
   const before=success(await request('owner','/rest/v1/products?id=eq.'+m.product))[0].quantity;
   const sales=success(await request('owner','/rest/v1/sales?business_id=eq.'+m.business));
   denied(await rpc('sales','submit_trexven_sale',{...sale(m,m.product),p_total:999}));
   assert.equal(success(await request('owner','/rest/v1/products?id=eq.'+m.product))[0].quantity,before);
   assert.equal(success(await request('owner','/rest/v1/sales?business_id=eq.'+m.business)).length,sales.length);
  });
  await check('revoked checkout with stale JWT fails immediately',async()=>{
   success(await rpc('owner','set_trexven_employee_permission',{p_employee_id:m.sales_employee,p_permission:'complete_sales',p_granted:false}));
   denied(await rpc('sales','submit_trexven_sale',sale(m,m.product)));
   success(await rpc('owner','set_trexven_employee_permission',{p_employee_id:m.sales_employee,p_permission:'complete_sales',p_granted:true}));
  });
  await check('changed price rejects stale checkout',async()=>{
   success(await request('owner','/rest/v1/products?id=eq.'+m.product,'PATCH',{selling_price:11}));
   denied(await rpc('sales','submit_trexven_sale',sale(m,m.product)));
   success(await request('owner','/rest/v1/products?id=eq.'+m.product,'PATCH',{selling_price:10}));
  });
  fs.writeFileSync(dir+'checkpoint_b_manifest.json',JSON.stringify(m));
 }
 if(phase==='branch') {
  await check('multi-branch legacy request requires explicit branch',async()=>denied(await rpc('sales','submit_trexven_sale',sale(m,m.product))));
  await check('authorized explicit branch checkout and retry',async()=>{
   const args={...sale(m,m.product),p_branch_id:m.branch_b};
   const receipt=success(await rpc('sales','submit_trexven_branch_sale',args));
   assert.equal(receipt.branch_id,m.branch_b);assert.deepEqual(success(await rpc('sales','submit_trexven_branch_sale',args)),receipt);
   assert.equal(success(await request('owner','/rest/v1/inventory?branch_id=eq.'+m.branch_b))[0].quantity,4);
  });
  await check('unmapped legacy receipt blocked for branch employee',async()=>denied(await rpc('sales','submit_trexven_sale',m.saved_request)));
  await check('owner legacy receipt recovery unchanged',async()=>{
   // Request keys are actor-scoped: the employee receipt must not be adopted by owner.
   assert.equal(success(await request('owner','/rest/v1/sales?id=eq.'+m.saved_receipt.id))[0].id,m.saved_receipt.id);
  });
  await check('branch assignment revocation stale JWT immediate',async()=>{
   success(await rpc('owner','set_trexven_branch_assignment',{p_employee_id:m.sales_employee,p_branch_id:m.branch_b,p_active:false}));
   denied(await rpc('sales','submit_trexven_branch_sale',{...sale(m,m.product),p_branch_id:m.branch_b}));
   assert.equal(success(await request('sales','/rest/v1/inventory?branch_id=eq.'+m.branch_b)).length,0);
  });
 }
 if(phase==='concurrent_revocation') {
  success(await rpc('owner','set_trexven_employee_permission',{p_employee_id:m.sales_employee,p_permission:'complete_sales',p_granted:true}));
  const holder=rpc('owner','batch_2_test_hold_product',{p_change_price:false});
  await awaitHolder();
  await check('revocation ordered against in-flight checkout',async()=>{
   const started=Date.now();
   const checkout=rpc('sales','submit_trexven_sale',sale(m,m.product));
   await new Promise(resolve=>setTimeout(resolve,300));
   const revoke=rpc('owner','set_trexven_employee_permission',{p_employee_id:m.sales_employee,p_permission:'complete_sales',p_granted:false});
   success(await checkout);assert.ok(Date.now()-started>=1000,'Held-row overlap not observed');success(await revoke);
   denied(await rpc('sales','submit_trexven_sale',sale(m,m.product)));
   success(await rpc('owner','set_trexven_employee_permission',{p_employee_id:m.sales_employee,p_permission:'complete_sales',p_granted:true}));
  });
  success(await holder);
 }
 if(phase==='concurrent_price') {
  const holder=rpc('owner','batch_2_test_hold_product',{p_change_price:true});
  await awaitHolder();
  await check('committing concurrent price change rejects stale checkout atomically',async()=>{
   const before=success(await request('owner','/rest/v1/products?id=eq.'+m.product))[0].quantity;
   const count=success(await request('owner','/rest/v1/sales?business_id=eq.'+m.business)).length;
   const started=Date.now();denied(await rpc('sales','submit_trexven_sale',sale(m,m.product)));
   assert.ok(Date.now()-started>=1000,'Held-row overlap not observed');
   assert.equal(success(await request('owner','/rest/v1/products?id=eq.'+m.product))[0].quantity,before);
   assert.equal(success(await request('owner','/rest/v1/sales?business_id=eq.'+m.business)).length,count);
   success(await request('owner','/rest/v1/products?id=eq.'+m.product,'PATCH',{selling_price:10}));
  });
  success(await holder);
 }
 if(phase==='logout') {
  for(const role of Object.keys(users)) {
   const r=await request(role,'/auth/v1/logout?scope=global','POST');
   console.log('Synthetic logout '+role+' HTTP '+r.status);
  }
 }
 console.log('Recorded '+results.filter(x=>x.pass).length+' passed / '+results.filter(x=>!x.pass).length+' failed');
 if(results.slice(startCount).some(x=>!x.pass))process.exitCode=1;
}
main().catch(e=>{console.error('Harness error: '+e.message);process.exitCode=1;});

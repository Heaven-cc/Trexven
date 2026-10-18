// Live staging Edge integration. Credentials/JWTs remain in ignored local files.
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const cfg=JSON.parse(fs.readFileSync('.batch2-tools/checkpoint_b_public_config.json'));
if(cfg.project!=='qysspzlfiysekvxnlzsh'||cfg.url!=='https://qysspzlfiysekvxnlzsh.supabase.co')throw Error('Staging target mismatch');
const users=JSON.parse(fs.readFileSync('.batch2-tools/checkpoint_b_credentials.json'));
const m=JSON.parse(fs.readFileSync('.batch2-tools/checkpoint_b_manifest.json'));
const file=process.env.BATCH_2_EDGE_RESULTS||'supabase/tests/baseline/batch_2_final_edge_results.json';
const results=[];
async function call(role,path,body,method='POST'){
 const r=await fetch(cfg.url+path,{method,headers:{apikey:cfg.key,'Content-Type':'application/json',...(users[role]?.token?{Authorization:'Bearer '+users[role].token}:{})},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(30000)});
 const text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text};return{status:r.status,ok:r.ok,data};
}
const edge=(role,name,body)=>call(role,'/functions/v1/'+name,body);
const rpc=(role,name,body)=>call(role,'/rest/v1/rpc/'+name,body);
function ok(r){assert.ok(r.ok,'HTTP '+r.status+' '+(typeof r.data==='object'?r.data.error||r.data.message||'request failed':'request failed'));return r.data;}
function denied(r){assert.ok([400,401,403].includes(r.status),'Denied request HTTP '+r.status);}
async function check(name,fn){try{await fn();results.push({name,pass:true});console.log('PASS '+name)}catch(e){results.push({name,pass:false,error:e.message});console.log('FAIL '+name+': '+e.message)}fs.writeFileSync(file,JSON.stringify(results,null,2)+'\n');}
async function main(){
 const employees=ok(await call('owner','/rest/v1/employees?business_id=eq.'+m.business+'&select=id,user_id,employee_code',undefined,'GET'));
 const codes=Object.fromEntries(['manager','sales','inventory'].map(role=>[role,employees.find(x=>x.user_id===users[role].id).employee_code]));
 for(const role of ['manager','sales','inventory'])await check('employee-login '+role+' real session and canonical role',async()=>{
  const r=ok(await edge(null,'employee-login',{employee_id:codes[role],password:users[role].password,business_id:m.other_business,role:'owner',permissions:['override_price']}));
  assert.equal(r.employee.user_id,users[role].id);assert.equal(r.business.id,m.business);assert.equal(r.employee.role,role==='manager'?'manager':role+'_employee');
  assert.ok(r.session.access_token&&r.membership.id);assert.ok(!r.employee.permissions.includes('override_price'));
  // Keep returned session only in ignored credentials so cleanup can revoke it.
  users[role].token=r.session.access_token;
 });
 await check('employee-login wrong password denied',async()=>denied(await edge(null,'employee-login',{employee_id:codes.sales,password:crypto.randomUUID()})));
 await check('employee-login missing credentials denied',async()=>denied(await edge(null,'employee-login',{})));
 await check('employee-login disabled account denied',async()=>{
  ok(await rpc('owner','set_trexven_employee_status',{p_employee_id:m.sales_employee,p_status:'suspended'}));
  denied(await edge(null,'employee-login',{employee_id:codes.sales,password:users.sales.password}));
  ok(await rpc('owner','set_trexven_employee_status',{p_employee_id:m.sales_employee,p_status:'active'}));
 });
 const password=crypto.randomBytes(24).toString('base64url');let created;
 await check('owner create-employee atomic Auth/staff/membership',async()=>{
  created=ok(await edge('owner','create-employee',{business_id:m.business,name:'Synthetic Edge ordinary',password,role:'employee'}));
  assert.ok(created.employee_id&&created.employee_code);assert.equal(created.role,'employee');
  const r=ok(await edge(null,'employee-login',{employee_id:created.employee_code,password}));assert.equal(r.employee.id,created.employee_id);assert.equal(r.business.id,m.business);
  m.created_edge_employee=created.employee_id;m.created_edge_user=r.employee.user_id;
  m.created_edge_code=created.employee_code;users.created={token:r.session.access_token,password,id:r.employee.user_id};
 });
 for(const role of ['sales','inventory','other_owner',null])await check('create-employee '+(role||'anonymous')+' denied',async()=>denied(await edge(role,'create-employee',{business_id:m.business,name:'Forbidden create',password,role:'employee'})));
 await check('manager cannot create manager',async()=>denied(await edge('manager','create-employee',{business_id:m.business,name:'Forbidden manager',password,role:'manager'})));
 await check('owner cannot promote new staff to owner',async()=>denied(await edge('owner','create-employee',{business_id:m.business,name:'Forbidden owner',password,role:'owner'})));
 await check('forged business create denied',async()=>denied(await edge('owner','create-employee',{business_id:m.other_business,name:'Forbidden other business',password,role:'employee'})));
 await check('manager can create provisional ordinary staff',async()=>{
  const r=ok(await edge('manager','create-employee',{business_id:m.business,name:'Synthetic Edge provisional',password,role:'employee'}));assert.equal(r.role,'employee');m.provisional_edge_employee=r.employee_id;
 });
 await check('forced persistence failure Auth compensation',async()=>denied(await edge('owner','create-employee',{business_id:m.business,name:'Synthetic compensation final',password,role:'employee'})));
 await check('manager can suspend ordinary staff',async()=>{
  ok(await rpc('manager','set_trexven_employee_status',{p_employee_id:created.employee_id,p_status:'suspended'}));
  denied(await edge(null,'employee-login',{employee_id:created.employee_code,password}));
  ok(await rpc('owner','set_trexven_employee_status',{p_employee_id:created.employee_id,p_status:'active'}));
 });
 for(const role of ['sales','inventory','other_owner',null])await check('manage-employee '+(role||'anonymous')+' denied',async()=>denied(await edge(role,'manage-employee',{action:'reset_password',business_id:m.business,employee_id:created.employee_id,new_password:password})));
 await check('manager self password reset denied',async()=>denied(await edge('manager','manage-employee',{action:'reset_password',business_id:m.business,employee_id:m.manager_employee,new_password:password})));
 await check('forged business reset denied',async()=>denied(await edge('owner','manage-employee',{action:'reset_password',business_id:m.other_business,employee_id:created.employee_id,new_password:password})));
 const newPassword=crypto.randomBytes(24).toString('base64url');
 await check('owner password reset and old password denial',async()=>{
  ok(await edge('owner','manage-employee',{action:'reset_password',business_id:m.business,employee_id:created.employee_id,new_password:newPassword}));
  denied(await edge(null,'employee-login',{employee_id:created.employee_code,password}));
  const r=ok(await edge(null,'employee-login',{employee_id:created.employee_code,password:newPassword}));users.created.token=r.session.access_token;users.created.password=newPassword;
 });
 await check('manager reset authorized ordinary staff',async()=>ok(await edge('manager','manage-employee',{action:'reset_password',business_id:m.business,employee_id:created.employee_id,new_password:newPassword})));
 for(const role of ['manager','sales','inventory','other_owner',null])await check('Angel '+(role||'anonymous')+' unauthorized selected business denied',async()=>denied(await edge(role,'angel',{message:'Synthetic authorization test',business_id:m.business})));
 await check('Angel owner selected-business auth without provider',async()=>{
  const r=await edge('owner','angel',{message:'Synthetic authorization test',business_id:m.business});assert.equal(r.status,503);assert.equal(r.data.business_id,m.business);
 });
 await check('Angel forged-business owner denied',async()=>denied(await edge('owner','angel',{message:'Synthetic authorization test',business_id:m.other_business})));
 fs.writeFileSync('.batch2-tools/checkpoint_b_credentials.json',JSON.stringify(users));
 fs.writeFileSync('.batch2-tools/checkpoint_b_manifest.json',JSON.stringify(m));
 console.log('Edge final '+results.filter(x=>x.pass).length+' passed / '+results.filter(x=>!x.pass).length+' failed');
 if(results.some(x=>!x.pass))process.exitCode=1;
}
main().catch(e=>{console.error('Edge harness: '+e.message);process.exitCode=1});

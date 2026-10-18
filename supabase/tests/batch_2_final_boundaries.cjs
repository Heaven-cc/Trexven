// Live staging-only authorization and local-day boundary checks. No service key.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const cfg = JSON.parse(fs.readFileSync('.batch2-tools/checkpoint_b_public_config.json'));
const users = JSON.parse(fs.readFileSync('.batch2-tools/checkpoint_b_credentials.json'));
const m = JSON.parse(fs.readFileSync('.batch2-tools/checkpoint_b_manifest.json'));
const ids = JSON.parse(fs.readFileSync(process.env.BATCH_2_BOUNDARY_IDS || '.batch2-tools/final_boundary_ids.json'));
if (cfg.project !== 'qysspzlfiysekvxnlzsh' || cfg.url !== 'https://qysspzlfiysekvxnlzsh.supabase.co') throw Error('Staging target mismatch');
const output = process.env.BATCH_2_BOUNDARY_RESULTS || 'supabase/tests/baseline/batch_2_final_boundary_results.json';
const results = fs.existsSync(output) ? JSON.parse(fs.readFileSync(output)) : [];
const startCount = results.length;
async function request(role,path,body,method='POST') {
 const r = await fetch(cfg.url+path,{method,headers:{apikey:cfg.key,'Content-Type':'application/json',...(users[role]?.token?{Authorization:'Bearer '+users[role].token}:{})},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(30000)});
 const bodyText = await r.text();
 return {status:r.status,ok:r.ok,data:bodyText ? JSON.parse(bodyText) : null};
}
function ok(r){assert.ok(r.ok,'HTTP '+r.status);return r.data;}
function denied(r){assert.ok([400,401,403,404].includes(r.status),'Unexpected HTTP '+r.status);}
async function check(name,fn){try{await fn();results.push({name,pass:true});console.log('PASS '+name);}catch(e){results.push({name,pass:false,error:e.message});console.log('FAIL '+name+': '+e.message);}}
const edge=(role,name,body)=>request(role,'/functions/v1/'+name,body);
const selected=role=>request(role,'/rest/v1/sales?id=in.('+ids.previous+','+ids.current+','+ids.next+')&select=id',null,'GET');
async function main(){
 await check('manager password reset across unauthorized branch denied',async()=>denied(await edge('manager','manage-employee',{action:'reset_password',business_id:m.business,employee_id:m.created_edge_employee,new_password:'NotAppliedSyntheticOnly'})));
 await check('denied branch reset leaves old credential valid',async()=>ok(await edge(null,'employee-login',{employee_id:m.created_edge_code,password:users.created.password})));
 await check('employee-login derives enabled business and ignores forged branch',async()=>{const r=ok(await edge(null,'employee-login',{employee_id:m.created_edge_code,password:users.created.password,branch_id:m.branch_c,business_id:m.other_business}));assert.equal(r.business.id,m.business);assert.equal(r.business.branches_enabled,true);assert.equal(r.employee.id,m.created_edge_employee);});
 await check('numeric six-character credential reset/login compatibility',async()=>{
  try {
   ok(await edge('owner','manage-employee',{action:'reset_password',business_id:m.business,employee_id:m.created_edge_employee,new_password:'941782'}));
   ok(await edge(null,'employee-login',{employee_id:m.created_edge_code,password:'941782'}));
  } finally {
   ok(await edge('owner','manage-employee',{action:'reset_password',business_id:m.business,employee_id:m.created_edge_employee,new_password:users.created.password}));
  }
 });
 await check('business-local midnight HTTP includes current day only',async()=>assert.deepEqual(ok(await selected('sales')).map(x=>x.id),[ids.current]));
 await check('owner historical and next-day receipts remain readable',async()=>assert.equal(ok(await selected('owner')).length,3));
 await check('invalid timezone rejected over REST',async()=>denied(await request('owner','/rest/v1/businesses?id=eq.'+m.business,{timezone:'Invalid/Synthetic'},'PATCH')));
 await check('missing timezone fails closed with existing employee JWT',async()=>{ok(await request('owner','/rest/v1/businesses?id=eq.'+m.business,{timezone:null},'PATCH'));assert.equal(ok(await selected('sales')).length,0);assert.equal(ok(await selected('owner')).length,3);});
 await check('timezone restoration takes effect without employee token refresh',async()=>{ok(await request('owner','/rest/v1/businesses?id=eq.'+m.business,{timezone:'America/New_York'},'PATCH'));assert.deepEqual(ok(await selected('sales')).map(x=>x.id),[ids.current]);});
 await check('deferred purchase cost REST projection denied',async()=>denied(await request('sales','/rest/v1/products?id=eq.'+m.product+'&select=id,selling_price,cost_price',null,'GET')));
 fs.writeFileSync(output,JSON.stringify(results,null,2)+'\n');
 const latest = results.slice(startCount);
 console.log(latest.filter(x=>x.pass).length+' passed / '+latest.filter(x=>!x.pass).length+' failed');if(latest.some(x=>!x.pass))process.exitCode=1;
}
main().catch(e=>{console.error(e.message);process.exitCode=1});

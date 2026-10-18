const fs=require('node:fs'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const status=JSON.parse(fs.readFileSync('.batch2-tools/native_status_windows.json'));assert.equal(status.runtime,'native');assert.equal(status.identity.name,'trexven-batch2-closure');const env=status.env;assert.equal(env.API_URL,'http://127.0.0.1:54321');
const out='docs/implementation/evidence/batch_2_closure_native_http.json';const results=fs.existsSync(out)?JSON.parse(fs.readFileSync(out)):[];
const users={};let m={};
function sql(q){fs.writeFileSync('.batch2-tools/native_http_step.sql',q);const r=cp.spawnSync('python',['.batch2-tools/native_sql.py','.batch2-tools/native_http_step.sql'],{encoding:'utf8'});if(r.status!==0)throw Error(r.stderr);return r.stdout;}
async function req(role,path,body,method='POST',admin=false){const r=await fetch(env.API_URL+path,{method,headers:{apikey:env.PUBLISHABLE_KEY,Authorization:'Bearer '+(admin?env.SERVICE_ROLE_KEY:users[role]?.token||env.ANON_KEY),'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(20000)});const t=await r.text();let data;try{data=JSON.parse(t)}catch{data=t}return{status:r.status,ok:r.ok,data};}
function ok(r){assert.ok(r.ok,'HTTP '+r.status+' '+JSON.stringify(r.data));return r.data}function denied(r){assert.ok([400,401,403,404].includes(r.status),'Unauthorized operation HTTP '+r.status)}
const rpc=(role,name,body)=>req(role,'/rest/v1/rpc/'+name,body);
async function check(name,fn){try{await fn();results.push({name,pass:true});console.log('PASS '+name)}catch(e){results.push({name,pass:false,error:e.message});console.log('FAIL '+name+' '+e.message)}fs.writeFileSync(out,JSON.stringify(results,null,2));}
async function main(){
if(process.argv[2]==='retry'){const f=JSON.parse(fs.readFileSync('.batch2-tools/native_http_fixture.json'));Object.assign(users,f.users);m=f.m;m.boundary_sales=m.boundary_receipts.map(r=>r.id);}else{
for(const role of ['owner','other_owner','sales','inventory','manager']){const password=crypto.randomUUID()+'Aa!';const email=crypto.randomUUID()+'@example.invalid';const u=ok(await req(null,'/auth/v1/admin/users',{email,password,email_confirm:true},'POST',true));const s=ok(await req(null,'/auth/v1/token?grant_type=password',{email,password}));users[role]={id:u.id,email,password,token:s.access_token};}
m.business=ok(await rpc('owner','complete_trexven_onboarding',{p_business_name:'Synthetic Closure Local',p_business_type:'Other',p_country:'Nigeria',p_currency:'NGN'}));m.other_business=ok(await rpc('other_owner','complete_trexven_onboarding',{p_business_name:'Synthetic Closure Other',p_business_type:'Other',p_country:'Other',p_currency:'USD'}));
for(const role of ['sales','inventory','manager']){const e=ok(await rpc('owner','finalize_trexven_employee',{p_business_id:m.business,p_user_id:users[role].id,p_name:'Synthetic '+role,p_email:users[role].email,p_phone:null,p_role:role==='manager'?'manager':role+'_employee',p_employee_code:'CLOSE-'+users[role].id}));m[role+'_employee']=e.id;}
const members=ok(await req('owner','/rest/v1/business_members?business_id=eq.'+m.business+'&select=id,user_id',undefined,'GET'));m.sales_member=members.find(x=>x.user_id===users.sales.id).id;
m.product=ok(await req('owner','/rest/v1/products?select=id',{business_id:m.business,name:'Synthetic Closure Local Product',selling_price:10,quantity:500}))[0]?.id;
// POST without Prefer returns no rows; obtain the ID with the approved safe projection.
if(!m.product)m.product=ok(await req('owner','/rest/v1/products?business_id=eq.'+m.business+'&select=id',undefined,'GET'))[0].id;
for(const name of ['a','b','c'])m['branch_'+name]=ok(await rpc('owner','create_trexven_branch',{p_business_id:m.business,p_name:'Synthetic Closure '+name}));
for(const name of ['a','b'])ok(await rpc('owner','set_trexven_branch_assignment',{p_employee_id:m.sales_employee,p_branch_id:m['branch_'+name],p_active:true}));
sql(`begin; select set_config('request.jwt.claim.sub','',true); update public.businesses set branches_enabled=true,timezone='America/New_York' where id='${m.business}'; insert into public.inventory(business_id,branch_id,product_id,quantity) values('${m.business}','${m.branch_a}','${m.product}',500); commit;`);
const payload=()=>({p_request_id:crypto.randomUUID(),p_business_id:m.business,p_branch_id:m.branch_a,p_employee_id:m.sales_member,p_total:10,p_payment_method:'cash',p_items:[{product_id:m.product,quantity:1,unit_price:10,discount:0}],p_quick:false});
const receipts=[];for(let i=0;i<3;i++)receipts.push(ok(await rpc('sales','submit_trexven_branch_sale',payload())));
m.boundary_sales=receipts.map(r=>r.id);m.boundary_receipts=receipts;
fs.writeFileSync('.batch2-tools/native_http_fixture.json',JSON.stringify({url:env.API_URL,key:env.PUBLISHABLE_KEY,users,m}));
}
for(const role of ['owner','manager','sales','inventory'])await check(role+' REST purchase cost unavailable',async()=>denied(await req(role,'/rest/v1/products?select=cost_price',undefined,'GET')));
await check('wildcard product read fails closed',async()=>denied(await req('owner','/rest/v1/products?select=*',undefined,'GET')));
await check('safe product projection works',async()=>{const r=ok(await req('sales','/rest/v1/products?select=id,selling_price,quantity&business_id=eq.'+m.business,undefined,'GET'));assert.equal(r[0].selling_price,10);assert.ok(!('cost_price'in r[0]));});
for(const role of ['owner','inventory'])await check(role+' deferred purchase-cost insert denied',async()=>denied(await req(role,'/rest/v1/products',{business_id:m.business,name:'Forbidden',cost_price:25})));
await check('purchase-cost PATCH denied',async()=>denied(await req('owner','/rest/v1/products?id=eq.'+m.product,{cost_price:25},'PATCH')));
const scenarios=[
['minute before local midnight','2026-10-10T03:59:00Z','2026-10-09',24],['exact local midnight','2026-10-10T04:00:00Z','2026-10-10',24],['minute after local midnight','2026-10-10T04:01:00Z','2026-10-10',24],
['spring before jump','2026-03-08T06:59:00Z','2026-03-08',23],['spring after jump','2026-03-08T07:00:00Z','2026-03-08',23],['fall first 01:30','2026-11-01T05:30:00Z','2026-11-01',25],['fall second 01:30','2026-11-01T06:30:00Z','2026-11-01',25]];
for(const [name,time,date,hours]of scenarios)await check('actual RPC/REST controlled clock '+name,async()=>{
sql(`create or replace function private.business_timestamp() returns timestamptz language sql stable security invoker set search_path='' as $clock$ select '${time}'::timestamptz $clock$; update public.sales set created_at=case id when '${m.boundary_sales[0]}' then ('${date}'::date-1)::timestamp at time zone 'America/New_York' when '${m.boundary_sales[1]}' then '${date}'::date::timestamp at time zone 'America/New_York' else ('${date}'::date+1)::timestamp at time zone 'America/New_York' end where id in (${m.boundary_sales.map(x=>"'"+x+"'").join(',')});`);
const day=ok(await rpc('sales','get_trexven_business_day',{p_business_id:m.business}));assert.equal(day.local_date,date);assert.equal((Date.parse(day.ends_at)-Date.parse(day.starts_at))/3600000,hours);
const rows=ok(await req('sales','/rest/v1/sales?select=id,branch_id,created_at&business_id=eq.'+m.business,undefined,'GET'));assert.deepEqual(rows.map(x=>x.id),[m.boundary_sales[1]]);assert.equal(rows[0].branch_id,m.branch_a);
});
await check('forged business day RPC denied',async()=>denied(await rpc('sales','get_trexven_business_day',{p_business_id:m.other_business})));
await check('missing timezone fails closed',async()=>{sql(`update public.businesses set timezone=null where id='${m.business}'`);denied(await rpc('sales','get_trexven_business_day',{p_business_id:m.business}));assert.deepEqual(ok(await req('sales','/rest/v1/sales?select=id&business_id=eq.'+m.business,undefined,'GET')),[]);});
sql(`update public.businesses set timezone='America/New_York' where id='${m.business}'; create or replace function private.business_timestamp() returns timestamptz language sql stable security invoker set search_path='' as $clock$ select current_timestamp $clock$;`);
console.log('Latest native checks',results.length,'failed',results.filter(x=>!x.pass).length);const latest=new Map(results.map(r=>[r.name,r]));if([...latest.values()].some(x=>!x.pass))process.exitCode=1;
}
main().catch(e=>{fs.writeFileSync('.batch2-tools/native_http_fixture.json',JSON.stringify({url:env.API_URL,key:env.PUBLISHABLE_KEY,users,m}));console.error(e.message);process.exitCode=1});

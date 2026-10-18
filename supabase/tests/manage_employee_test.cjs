const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const {stripTypeScriptTypes}=require('node:module');
const source=fs.readFileSync(path.join(__dirname,'../functions/manage-employee/index.ts'),'utf8').replace(/^import .*;\r?\n/gm,'');
async function run({actor='owner-a',targetBusiness='business-a',targetUser='employee-a',targetRole='sales_employee',manager=false}) {
 let handler, resets=0;
 const admin={rpc:async()=>({data:actor==='owner-a'||manager?{owner:actor==='owner-a'}:null,error:actor==='owner-a'||manager?null:{code:'42501'}}),auth:{getUser:async()=>({data:{user:{id:actor}}}),admin:{updateUserById:async()=>{resets++;return {error:null};}}},from(table){
  const filters={}; const chain={select(){return chain},eq(k,v){filters[k]=v;return chain},
   async single(){
    if(table==='businesses')return {data:{id:'business-a',owner_id:'owner-a'}};
    if(table==='employees')return {data:filters.business_id===targetBusiness?{user_id:targetUser,name:'Target',role:targetRole}:null};
    throw new Error(table);
   },async maybeSingle(){return {data:manager?{role:'manager'}:null}},async insert(){return {error:null}}};return chain;
 }};
 const helper=fs.readFileSync(path.join(__dirname,'../functions/_shared/employee-access.ts'),'utf8').replace(/^export /gm,'');
 vm.runInNewContext(stripTypeScriptTypes(helper+'\n'+source),{serve:fn=>handler=fn,createClient:()=>admin,Deno:{env:{get:()=> 'configured'}},Response,console});
 const result=await handler(new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer test'},body:JSON.stringify({action:'reset_password',employee_id:'target',business_id:'business-a',new_password:'test-password'})}));
 return {status:result.status,resets};
}
(async()=>{
 assert.deepEqual(await run({}),{status:200,resets:1});
 assert.deepEqual(await run({targetBusiness:'business-b'}),{status:400,resets:0});
 assert.deepEqual(await run({actor:'outsider'}),{status:403,resets:0});
 assert.deepEqual(await run({targetUser:'owner-a',targetRole:'owner'}),{status:400,resets:0});
 assert.deepEqual(await run({actor:'manager-a',manager:true,targetRole:'manager'}),{status:400,resets:0});
 assert.deepEqual(await run({actor:'manager-a',manager:true}),{status:200,resets:1});
 console.log('PASS: six employee-reset authorization cases; cross-business and owner/manager protection.');
})().catch(e=>{console.error(e);process.exitCode=1});

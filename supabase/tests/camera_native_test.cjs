const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

async function invoke({ authenticated = true, allowed = true, event = true, insight = true, request = {} } = {}) {
  let handler;
  const calls = [];
  const query = table => {
    const value = table === 'camera_events'
      ? (event ? {id:'event',business_id:'business',camera_id:'camera',event_type:'person_entered',description:'Recorded person'} : null)
      : (insight ? [{metadata:{source_event_ids:['event'],classification:'observed_activity',reasoning:['Native evidence']}}] : []);
    const chain = {select(){return this},eq(){return this},order(){return this},limit(){return this},
      maybeSingle:async()=>({data:value,error:null}),
      then(resolve,reject){return Promise.resolve({data:value,error:null}).then(resolve,reject)}};
    return chain;
  };
  const createClient = (url,key,options) => {
    calls.push({kind:'client',scoped:!!options?.global?.headers?.Authorization});
    return {auth:{getUser:async()=>({data:{user:authenticated?{id:'user'}:null},error:null})},
      from:table=>{calls.push({kind:'read',table});return query(table)},
      rpc:async(name,args)=>{calls.push({kind:'rpc',name});return {data:allowed,error:null}}};
  };
  const source = fs.readFileSync('supabase/functions/camera-ai/index.ts','utf8').replace(/^import .*;\r?\n/gm,'');
  vm.runInNewContext(stripTypeScriptTypes(source),{
    Deno:{serve:callback=>{handler=callback},env:{get:name=>'configured'}},createClient,
    Request,Response,console,fetch:()=>{throw new Error('External fetch prohibited')}
  });
  const response = await handler(new Request('https://backend.invalid/camera-ai',{
    method:'POST',headers:{Authorization:'Bearer valid','Content-Type':'application/json'},
    body:JSON.stringify({event_id:'event',camera_id:'camera',...request})}));
  return {status:response.status,body:await response.json(),calls};
}

(async()=>{
  const result=await invoke();
  assert.equal(result.status,200);
  assert.equal(result.body.external_ai_enabled,false);
  assert.match(result.body.answer,/Native evidence/);
  assert.ok(result.calls.some(call=>call.kind==='client' && call.scoped));
  assert.deepEqual(result.calls.filter(call=>call.kind==='rpc').map(call=>call.name),
    ['require_trexven_feature','consume_camera_explanation_request']);
  assert.equal((await invoke({authenticated:false})).status,401);
  assert.equal((await invoke({event:false})).status,404);
  assert.equal((await invoke({allowed:false})).status,429);
  assert.match((await invoke({insight:false})).body.answer,/No correlated Intelligence conclusion/);
  assert.equal((await invoke({request:{event_id:null}})).status,400);
  console.log('PASS: native camera evidence, no external fetch, scoped reads, independent limiter, missing evidence, authentication and uncertainty.');
})().catch(error=>{console.error(error);process.exitCode=1});

// Actual handler sources, mocked Auth/RPC boundaries. Not a gateway JWT proof.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const {test}=require('node:test');
const {stripTypeScriptTypes}=require('node:module');

async function invoke(slug,options={}) {
  let handler;const calls=[],logs=[];
  const source=fs.readFileSync(`supabase/functions/${slug}/index.ts`,'utf8').replace(/^import .*;\r?\n/gm,'');
  vm.runInNewContext(stripTypeScriptTypes(source),{
    Deno:{serve:fn=>handler=fn,env:{get:name=>{
      calls.push({kind:'env',name});
      if(slug==='delete-account')assert.notEqual(name,'SUPABASE_SERVICE_ROLE_KEY');
      return options.unconfigured?undefined:name==='SUPABASE_URL'?'https://example.invalid':'test-key';
    }}},
    createClient:(url,key,config)=>{
      const scoped=!!config?.global?.headers?.Authorization;
      calls.push({kind:'client',key,config,scoped});
      return {auth:{getUser:async token=>{
        calls.push({kind:'auth',token});
        return {data:{user:options.invalidAuth?null:{id:'verified-user'}},error:options.invalidAuth?{message:'bad JWT'}:null};
      }},rpc:async(name,args)=>{
        calls.push({kind:'rpc',name,args,scoped});
        if(options.throwRpc)throw Error('private database details');
        if(name==='require_trexven_feature')return {data:null,error:options.entitlementDenied?{code:'42501'}:null};
        if(name==='consume_camera_explanation_request')return {data:!options.limited,error:null};
        assert.equal(name,'request_trexven_account_lifecycle');
        return {data:options.emptyReceipt?null:options.badReceipt?{id:'request',status:'deleted'}:{id:'request',status:'requested',financial_records_preserved:true},error:options.denied?{code:'42501'}:options.rpcFailure?{code:'08006'}:null};
      },from:table=>{
        assert.ok(scoped,'all evidence reads use caller JWT');calls.push({kind:'read',table});
        const data=table==='camera_events'?(options.noEvent?null:{id:'event',business_id:'business',camera_id:'camera',event_type:'observation',description:'Synthetic observation'}):[];
        return {select(){return this},eq(column,value){calls.push({kind:'filter',table,column,value});return this},order(){return this},limit(){return this},
          maybeSingle:async()=>({data,error:options.readFailure?{message:'private database details'}:null}),
          then(resolve,reject){return Promise.resolve({data,error:null}).then(resolve,reject)}};
      }};
    },Request,Response,console:{error:message=>logs.push(message)},fetch:()=>{throw Error('network prohibited')}
  });
  const method=options.method||'POST';
  const payload=slug==='delete-account'?{business_id:'owned-business',request_id:'durable-request',reason:'Synthetic review'}:{event_id:'event',camera_id:'camera'};
  const response=await handler(new Request('https://example.invalid/'+slug,{
    method,headers:{...(options.noAuth?{}:{Authorization:options.authorization||'Bearer verified-token'}),'Content-Type':'application/json'},
    ...(method==='POST'?{body:options.rawBody??JSON.stringify({...payload,...options.body})}:{})
  }));
  return {status:response.status,body:method==='OPTIONS'?await response.text():await response.json(),calls,logs};
}
const lifecycle=o=>invoke('delete-account',o),camera=o=>invoke('camera-ai',o);
test('lifecycle acknowledges only a preserved, requested receipt using caller JWT',async()=>{
  const r=await lifecycle();assert.equal(r.status,202);assert.equal(r.body.deleted_user,false);assert.equal(r.body.requested,true);
  const client=r.calls.find(x=>x.kind==='client');assert.equal(client.config.global.headers.Authorization,'Bearer verified-token');
  assert.equal(client.config.auth.persistSession,false);assert.equal(client.config.auth.autoRefreshToken,false);
  assert.deepEqual(r.calls.filter(x=>x.kind==='auth'||x.kind==='rpc').map(x=>x.kind),['auth','rpc']);
});
for(const [name,options] of [['missing JWT',{noAuth:true}],['non-bearer credentials',{authorization:'Basic invalid'}],['invalid JWT',{invalidAuth:true}]]) {
  for(const [slug,fn] of [['lifecycle',lifecycle],['camera',camera]])test(slug+' rejects '+name+' before RPC',async()=>{const r=await fn(options);assert.equal(r.status,401);assert.ok(!r.calls.some(x=>x.kind==='rpc'||x.kind==='read'))});
}
for(const [name,rawBody] of [['legacy destructive payload','{}'],['missing request',JSON.stringify({business_id:'business',reason:'review'})],['null JSON','null'],['malformed JSON','{']])test('lifecycle rejects '+name+' without mutation',async()=>{const r=await lifecycle({rawBody});assert.equal(r.status,409);assert.equal(r.body.deleted_user,false);assert.ok(!r.calls.some(x=>x.kind==='rpc'))});
test('lifecycle ignores forged user, owner, role and destructive kind',async()=>{const r=await lifecycle({body:{user_id:'foreign',owner_id:'forged',role:'owner',kind:'force_delete'}});const rpc=r.calls.find(x=>x.kind==='rpc');assert.deepEqual(Object.keys(rpc.args).sort(),['p_business_id','p_kind','p_reason','p_request_id']);assert.equal(rpc.args.p_kind,'deletion')});
for(const role of ['employee','manager','foreign-owner'])test('lifecycle forwards database denial for '+role,async()=>{const r=await lifecycle({denied:true,body:{role,business_id:'unauthorized'}});assert.equal(r.status,403);assert.equal(r.body.deleted_user,false);assert.equal(r.body.success,false)});
for(const option of ['rpcFailure','emptyReceipt','badReceipt'])test('lifecycle '+option+' never claims confirmation',async()=>{const r=await lifecycle({[option]:true});assert.equal(r.status,503);assert.equal(r.body.success,false);assert.equal(r.body.deleted_user,false)});
test('lifecycle logs only a fixed failure code',async()=>{const r=await lifecycle({throwRpc:true});assert.equal(r.status,503);assert.deepEqual(r.logs,['ACCOUNT_LIFECYCLE_REQUEST_FAILED']);assert.ok(!JSON.stringify(r.body).includes('private'))});
test('camera derives business and actor from verified records',async()=>{
  const r=await camera({body:{business_id:'forged',user_id:'forged',role:'owner'}});assert.equal(r.status,200);assert.equal(r.body.external_ai_enabled,false);
  assert.equal(r.calls.find(x=>x.kind==='auth').token,'verified-token');
  const rpc=r.calls.filter(x=>x.kind==='rpc');assert.deepEqual(rpc.map(x=>x.name),['require_trexven_feature','consume_camera_explanation_request']);
  assert.equal(rpc[0].scoped,true);assert.equal(rpc[0].args.p_business_id,'business');assert.equal(rpc[1].args.p_user_id,'verified-user');
});
test('camera hidden foreign event stops before feature and limiter',async()=>{const r=await camera({noEvent:true});assert.equal(r.status,404);assert.ok(!r.calls.some(x=>x.kind==='rpc'))});
test('camera entitlement denial stops before privileged limiter and insights',async()=>{const r=await camera({entitlementDenied:true});assert.equal(r.status,403);assert.equal(r.calls.filter(x=>x.kind==='rpc').length,1);assert.ok(!r.calls.some(x=>x.table==='angel_insights'))});
test('camera limiter denial returns 429',async()=>assert.equal((await camera({limited:true})).status,429));
test('camera missing correlated evidence is stated honestly',async()=>assert.match((await camera()).body.answer,/No correlated Intelligence conclusion/));
for(const rawBody of ['null','{','{}'])test('camera invalid payload '+rawBody+' returns 400',async()=>assert.equal((await camera({rawBody})).status,400));
test('camera database failure leaks no details',async()=>{const r=await camera({readFailure:true});assert.equal(r.status,500);assert.deepEqual(r.logs,['CAMERA_EVIDENCE_REQUEST_FAILED']);assert.ok(!JSON.stringify(r.body).includes('private'))});
for(const [slug,fn] of [['lifecycle',lifecycle],['camera',camera]]){
  test(slug+' missing configuration is unavailable',async()=>assert.equal((await fn({unconfigured:true})).status,503));
  test(slug+' preflight needs no credentials',async()=>{const r=await fn({method:'OPTIONS',noAuth:true});assert.equal(r.status,200);assert.equal(r.calls.length,0)});
  test(slug+' rejects unsupported method',async()=>assert.equal((await fn({method:'GET'})).status,405));
}

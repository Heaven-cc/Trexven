const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { stripTypeScriptTypes } = require('node:module');
const source = stripTypeScriptTypes(fs.readFileSync(path.join(__dirname,'../functions/angel/catalog_tasks.ts'),'utf8').replace(/^export /gm,''))
  + '\n' + stripTypeScriptTypes(fs.readFileSync(path.join(__dirname,'../functions/angel/index.ts'),'utf8').replace(/^import .*;\r?\n/gm,''));
const actionId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const conversation = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const pending = { id:actionId,status:'pending',operation:'price',product_name:'Rice',before_value:'100',after_value:'120',reason:'Owner price update',unit:'piece',verified:false };
const call = { type:'function',function:{name:'prepare_catalog_change',arguments:JSON.stringify({product_query:'Rice',operation:'price',value:120,reason:'Owner price update'})} };
async function invoke(options={}) {
  let handler, providerBody, providerCalls=0;
  const rpcCalls=[], writes=[], clients=[];
  function createClient(url,key,config) {
    const caller=!!config.global;
    clients.push({caller,config});
    return {auth:{getUser:async()=>({data:{user:options.invalidAuth?null:{id:'owner'}}})},
      rpc:async(name,args)=>{
        rpcCalls.push({name,args,caller});
        if(name==='consume_angel_request')return {data:true,error:null};
        if(name==='user_owns_business')return {data:!options.denied,error:null};
        if(name==='angel_sales_summary')return {data:{},error:null};
        if(name==='prepare_trexven_angel_catalog_action'||name==='resolve_trexven_angel_catalog_action') {
          assert.ok(caller,'tasks use caller JWT');
          if(options.rpcFailure)return {data:null,error:{message:'private failure'}};
          if(options.emptyReceipt)return {data:null,error:null};
          if(options.receipt)return {data:options.receipt,error:null};
          return {data:name.startsWith('prepare')?pending:{...pending,status:args.p_confirm?'completed':'cancelled',verified:args.p_confirm},error:null};
        }
        throw Error('Unexpected RPC '+name);
      },
      from(table){let insertion,filters={};const result=()=>{
        if(insertion){writes.push({table,data:insertion});if(options.chatFailure&&table==='angel_messages'&&insertion.role==='assistant'){
          if(options.throwChat)throw Error('chat network failure');return {data:null,error:Error('chat failed')};}
          return {data:{id:conversation},error:null};}
        if(table==='businesses')return {data:{id:'business',currency:'NGN'},error:null};
        if(table==='angel_conversations')return {data:{id:conversation},error:null};
        if(table==='angel_messages')return {data:options.history??[],error:null};
        return {data:[],error:null};
      };const q={select(){return q},eq(k,v){filters[k]=v;return q},gte(){return q},order(){return q},limit(){return q},
        insert(v){insertion=v;return q},update(){return {eq:async()=>({error:null})}},maybeSingle:async()=>result(),single:async()=>result(),
        then(resolve,reject){return Promise.resolve().then(result).then(resolve,reject)}};return q;}
    };
  }
  vm.runInNewContext(source,{createClient,Deno:{env:{get:key=>options.noProvider&&key==='GROQ_API_KEY'?undefined:'configured'},serve:fn=>handler=fn},
    Request,Response,AbortController,DOMException,setTimeout,clearTimeout,console:{error(){}},
    fetch:async(url,args)=>{providerCalls++;providerBody=JSON.parse(args.body);return new Response(JSON.stringify({choices:[{message:options.modelMessage??{tool_calls:[call]}}]}),{status:200});}});
  const response=await handler(new Request('https://example.invalid',{method:'POST',headers:{Authorization:'Bearer owner-token'},
    body:JSON.stringify({business_id:'business',conversation_id:conversation,message:options.message??'Change Rice selling price to 120'})}));
  return {status:response.status,body:await response.json(),rpcCalls,writes,clients,providerCalls,providerBody};
}
const history=action=>[{role:'assistant',content:'Proposed change',metadata:{catalog_action:action}}];
test('proposals do not execute, and contain explicit confirmation plus trusted context',async()=>{
  const r=await invoke();assert.equal(r.body.task_executed,false);assert.match(r.body.reply,/Reply CONFIRM/);
  assert.equal(r.rpcCalls.filter(x=>x.name.startsWith('resolve')).length,0);
  const task=r.rpcCalls.find(x=>x.name.startsWith('prepare'));assert.equal(task.args.p_business_id,'business');assert.equal(task.args.p_source_message,'Change Rice selling price to 120');
  assert.equal(r.clients.find(x=>x.caller).config.global.headers.Authorization,'Bearer owner-token');
  assert.equal(r.providerBody.parallel_tool_calls,false);
});
test('confirmation bypasses provider and reports only verified database success',async()=>{
  const r=await invoke({message:'CONFIRM',history:history(pending),noProvider:true});
  assert.equal(r.providerCalls,0);assert.equal(r.body.task_executed,true);assert.match(r.body.reply,/Updated and verified/);
  assert.equal(r.rpcCalls.find(x=>x.name.startsWith('resolve')).args.p_action_id,actionId);
});
test('cancellation performs no confirmed task',async()=>{const r=await invoke({message:'CANCEL',history:history(pending)});assert.equal(r.body.task_executed,false);assert.equal(r.body.action.status,'cancelled')});
for(const status of ['expired','conflict','cancelled'])test(status+' never claims mutation',async()=>{
  const r=await invoke({message:'confirm',history:history(pending),receipt:{...pending,status,verified:false}});assert.equal(r.body.task_executed,false);assert.doesNotMatch(r.body.reply,/Updated and verified/);
});
test('repeat confirmations return the receipt without implying a second write',async()=>{
  const completed={...pending,status:'completed',verified:true};const r=await invoke({message:'yes',history:history(completed),receipt:{...completed,replayed:true}});
  assert.match(r.body.reply,/did not apply it twice/);assert.equal(r.body.task_executed,true);
});
test('a later answer invalidates conversational confirmation of an earlier proposal',async()=>{
  const r=await invoke({message:'confirm',history:[{role:'assistant',content:'Another answer'},...history(pending)]});
  assert.equal(r.body.task_executed,false);assert.ok(!r.rpcCalls.some(x=>x.name.startsWith('resolve')));
});
test('confirmation without a stored proposal cannot invent a task',async()=>{const r=await invoke({message:'confirm'});assert.match(r.body.reply,/no pending change/);assert.ok(!r.rpcCalls.some(x=>x.name.startsWith('resolve')))});
for(const option of ['denied','invalidAuth'])test(option+' prevents provider use and tasks',async()=>{const r=await invoke({[option]:true});assert.ok([401,403].includes(r.status));assert.equal(r.providerCalls,0);assert.ok(!r.rpcCalls.some(x=>x.name.startsWith('prepare')))});
for(const option of ['rpcFailure','emptyReceipt'])test(option+' cannot report task success',async()=>{const r=await invoke({message:'confirm',history:history(pending),[option]:true});assert.equal(r.body.task_executed,false);assert.doesNotMatch(r.body.reply,/Updated and verified|private failure/)});
test('unverified completed receipt is rejected',async()=>{const r=await invoke({message:'confirm',history:history(pending),receipt:{...pending,status:'completed',verified:false}});assert.equal(r.body.task_executed,false)});
for(const throwChat of [false,true])test('committed success survives chat persistence failure '+throwChat,async()=>{const r=await invoke({message:'confirm',history:history(pending),chatFailure:true,throwChat});assert.equal(r.body.task_executed,true);assert.equal(r.body.history_saved,false)});
for(const name of ['execute_sql','resolve_trexven_angel_catalog_action'])test('model cannot execute '+name,async()=>{const r=await invoke({modelMessage:{tool_calls:[{...call,function:{...call.function,name}}]}});assert.equal(r.body.task_executed,false);assert.ok(!r.rpcCalls.some(x=>x.name.startsWith('prepare')||x.name.startsWith('resolve')))});
test('extra authority fields in model arguments are rejected',async()=>{const args={...JSON.parse(call.function.arguments),business_id:'foreign'};const r=await invoke({modelMessage:{tool_calls:[{...call,function:{...call.function,arguments:JSON.stringify(args)}}]}});assert.equal(r.body.task_executed,false);assert.ok(!r.rpcCalls.some(x=>x.name.startsWith('prepare')))});
test('multiple tool calls do not partially prepare a batch',async()=>{const r=await invoke({modelMessage:{tool_calls:[call,call]}});assert.ok(!r.rpcCalls.some(x=>x.name.startsWith('prepare')))});
test('plain AI update claims cannot count as a completed action',async()=>{const r=await invoke({modelMessage:{content:"I've updated your stock price."}});assert.equal(r.body.task_executed,false);assert.match(r.body.reply,/haven't changed anything/)});
test('ambiguous products ask the owner to identify a variant',async()=>{const r=await invoke({receipt:{status:'ambiguous',matches:[{name:'Rice',sku:'R1'},{name:'Rice',sku:'R2'}]}});assert.equal(r.body.task_executed,false);assert.match(r.body.reply,/R1.*R2/)});
for(const operation of ['stock_set','stock_adjust'])test(operation+' is forwarded as a scoped proposal',async()=>{const args={...JSON.parse(call.function.arguments),operation,value:operation==='stock_set'?5:-2};const r=await invoke({modelMessage:{tool_calls:[{...call,function:{...call.function,arguments:JSON.stringify(args)}}]}});assert.equal(r.rpcCalls.find(x=>x.name.startsWith('prepare')).args.p_operation,operation)});

// Real hosted gateway verification on dedicated staging only.
// Fixed dedicated staging only; no provider calls, production keys or customer records.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.117.2';

const evidencePath='docs/implementation/evidence/batch_9_staging_edge_gateway_results.json';
type Check={name:string;passed:boolean;status?:number};
const checks:Check[]=[];
function assert(value:unknown,message:string):asserts value { if(!value)throw Error(message); }
function check(name:string,value:unknown,status?:number){
  checks.push({name,passed:!!value,status});
  Deno.writeTextFileSync(evidencePath,JSON.stringify({target:'https://qysspzlfiysekvxnlzsh.supabase.co',kind:'hosted staging gateway, genuine Auth JWT, deployed handlers and RLS',checks,passed:checks.every(c=>c.passed),production_writes:0},null,2));
  console.log((value?'PASS ':'FAIL ')+name);
  assert(value,name+' failed'+(status===undefined?'':' HTTP '+status));
}
function metadata(){
  const API_URL=Deno.env.get('TREXVEN_TEST_URL');
  assert(API_URL==='https://qysspzlfiysekvxnlzsh.supabase.co','Dedicated staging is the only permitted target');
  const ANON_KEY=Deno.env.get('TREXVEN_TEST_ANON'),SERVICE_ROLE_KEY=Deno.env.get('TREXVEN_TEST_SERVICE');
  assert(ANON_KEY&&SERVICE_ROLE_KEY,'Existing staging keys required; never print keys');
  return {API_URL,ANON_KEY,SERVICE_ROLE_KEY};
}

type Handler=(request:Request)=>Promise<Response>;
async function loadHandler(slug:string):Promise<Handler>{
  const env=metadata();
  return async(request:Request)=>fetch(`${env.API_URL}/functions/v1/${slug}`,{
    method:request.method,headers:{...Object.fromEntries(request.headers),apikey:env.ANON_KEY!},body:await request.text(),
  });
}

Deno.test({name:'hosted staging JWT lifecycle and camera authorization integration',sanitizeOps:false,sanitizeResources:false,fn:async()=>{
  const env=metadata();
  Deno.env.set('SUPABASE_URL',env.API_URL);Deno.env.set('SUPABASE_ANON_KEY',env.ANON_KEY);Deno.env.set('SUPABASE_SERVICE_ROLE_KEY',env.SERVICE_ROLE_KEY);
  const options={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
  const admin=createClient(env.API_URL,env.SERVICE_ROLE_KEY,options);
  const users:Record<string,{id:string;token:string;client:SupabaseClient;email:string}>={};
  const fixture:{users:string[];businesses:string[];camera?:string;event?:string}={users:[],businesses:[]};
  const lifecycle=await loadHandler('delete-account'),camera=await loadHandler('camera-ai');
  async function invoke(handler:Handler,token:string|undefined,body:unknown){
    const response=await handler(new Request('http://127.0.0.1:54401/isolated-handler',{
      method:'POST',headers:{...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},body:JSON.stringify(body)}));
    return {status:response.status,body:await response.json()};
  }
  async function create(role:string){
    const email='batch9-edge-'+crypto.randomUUID()+'@example.invalid',password=crypto.randomUUID()+'aA!';
    const created=await admin.auth.admin.createUser({email,password,email_confirm:true});
    check('create synthetic Auth '+role,!created.error&&!!created.data.user);fixture.users.push(created.data.user!.id);
    const client=createClient(env.API_URL,env.ANON_KEY,options);
    const session=await client.auth.signInWithPassword({email,password});check('genuine Auth session '+role,!session.error&&!!session.data.session);
    users[role]={id:created.data.user!.id,email,token:session.data.session!.access_token,client};
  }
  try{
    for(const role of ['owner','other_owner','manager','sales','inventory'])await create(role);
    for(const role of ['owner','other_owner']){
      const r=await users[role].client.rpc('complete_trexven_onboarding',{p_business_name:'Synthetic Batch9 Edge '+role,p_business_type:'Other',p_country:'Nigeria',p_currency:'NGN'});
      check('synthetic business '+role,!r.error&&typeof r.data==='string');fixture.businesses.push(r.data);
    }
    const business=fixture.businesses[0],other=fixture.businesses[1];
    const employees:Record<string,string>={};
    for(const role of ['manager','sales','inventory']){
      const r=await users.owner.client.rpc('finalize_trexven_employee',{p_business_id:business,p_user_id:users[role].id,p_name:'Synthetic '+role,p_email:users[role].email,p_phone:null,p_role:role==='manager'?'manager':role+'_employee',p_employee_code:'EDGE9-'+crypto.randomUUID()});
      check('trusted employee membership '+role,!r.error&&!!r.data?.id);employees[role]=r.data.id;
    }
    const request={business_id:business,request_id:crypto.randomUUID(),reason:'Synthetic retained-records request'};
    for(const [label,token] of [['missing JWT',undefined],['malformed JWT','invalid'],['tampered JWT',users.owner.token.slice(0,-10)+'AAAAAAAAAA'],['anon API key',env.ANON_KEY]] as const){
      for(const [slug,handler] of [['lifecycle',lifecycle],['camera',camera]] as const){
        const r=await invoke(handler,token,request);check(slug+' rejects '+label,r.status===401,r.status);
      }
    }
    for(const role of ['manager','sales','inventory','other_owner']){
      const r=await invoke(lifecycle,users[role].token,{...request,request_id:crypto.randomUUID(),owner_id:users.owner.id,role:'owner'});
      check('lifecycle real JWT denies '+role,r.status===403&&r.body.deleted_user===false,r.status);
    }
    let r=await invoke(lifecycle,users.owner.token,{...request,business_id:other});
    check('owner forged-business lifecycle denied',r.status===403,r.status);
    r=await invoke(lifecycle,users.owner.token,request);
    check('owner lifecycle request acknowledged without deletion',r.status===202&&r.body.deleted_user===false&&r.body.result.financial_records_preserved===true,r.status);
    const original=r.body.result.id;
    r=await invoke(lifecycle,users.owner.token,request);
    check('lifecycle durable request idempotency preserved',r.status===202&&r.body.result.id===original,r.status);
    const surviving=await admin.auth.admin.getUserById(users.owner.id);
    check('lifecycle leaves Auth identity intact',!surviving.error&&surviving.data.user?.id===users.owner.id);
    const retained=await admin.from('businesses').select('id').eq('id',business).single();
    check('lifecycle leaves existing business intact',!retained.error&&retained.data?.id===business);
    const rows=await admin.from('account_lifecycle_requests').select('id').eq('business_id',business);
    check('only authorized single lifecycle record exists',!rows.error&&rows.data?.length===1);
    const c=await users.owner.client.from('cameras').insert({business_id:business,name:'Synthetic Batch9 Camera'}).select('id').single();
    check('synthetic camera created under owner RLS',!c.error&&!!c.data?.id);fixture.camera=c.data!.id;
    const event=await users.owner.client.from('camera_events').insert({business_id:business,camera_id:fixture.camera,event_type:'motion',description:'Synthetic isolated observation'}).select('id').single();
    check('synthetic camera event created under owner RLS',!event.error&&!!event.data?.id);fixture.event=event.data!.id;
    const eventBody={event_id:fixture.event,camera_id:fixture.camera};
    r=await invoke(camera,users.owner.token,eventBody);
    check('owner scoped camera evidence succeeds with real JWT',r.status===200&&r.body.external_ai_enabled===false&&r.body.business_id===business,r.status);
    for(const role of ['other_owner','manager','sales','inventory']){
      r=await invoke(camera,users[role].token,eventBody);check('camera real JWT isolates '+role,r.status===404,r.status);
    }
    r=await invoke(camera,users.owner.token,{...eventBody,camera_id:crypto.randomUUID()});
    check('camera forged pairing cannot disclose event',r.status===404,r.status);
    const grant=await users.owner.client.rpc('set_trexven_employee_permission',{p_employee_id:employees.manager,p_permission:'view_camera_events',p_granted:true});
    check('owner-only Vision permission cannot be delegated',grant.error?.code==='42501');
    r=await invoke(camera,users.manager.token,eventBody);check('forbidden Vision grant does not expose owner events',r.status===404,r.status);
    const revoked=await users.owner.client.rpc('set_trexven_employee_status',{p_employee_id:employees.manager,p_status:'suspended'});
    check('owner revokes manager access',!revoked.error);
    r=await invoke(camera,users.manager.token,eventBody);check('still-valid manager JWT denied immediately after revocation',r.status===404,r.status);
    const subscription=await admin.rpc('apply_verified_trexven_subscription',{
      p_business_id:business,p_event_key:'synthetic-edge-'+crypto.randomUUID(),p_plan_id:'start',p_status:'active',
      p_started:new Date(Date.now()-172800000).toISOString(),p_expires:new Date(Date.now()-86400000).toISOString(),
      p_renews:null,p_grace_until:null,p_expected_version:0,p_enforce:true,
    });
    check('synthetic service-only entitlement transition accepted',!subscription.error);
    r=await invoke(camera,users.owner.token,eventBody);
    check('current Vision entitlement revocation denies an unchanged owner JWT',r.status===403,r.status);
  }finally{
    for(const user of Object.values(users))await user.client.auth.signOut({scope:'local'});
    // Immutable audit foreign keys intentionally prevent destructive Auth cleanup.
    // These synthetic IDs belong only to the dedicated staging project.
    Deno.writeTextFileSync('.batch3-tools/batch9_edge_staging_fixture_ids.json',JSON.stringify({target:env.API_URL,...fixture,cleanup:'synthetic isolated staging fixtures retained for audit; never customer records'},null,2));
    Deno.env.delete('SUPABASE_URL');Deno.env.delete('SUPABASE_ANON_KEY');Deno.env.delete('SUPABASE_SERVICE_ROLE_KEY');
  }
}});

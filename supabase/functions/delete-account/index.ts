import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.117.2";
import { deletionAdmin, deletionFailure, deletionHash, deletionJson, hasRecentDeletionAuthentication, resumeDeletion, validDeletionIdentity } from "../_shared/account-deletion.ts";
// Explicit deletion is opt-in. Existing review-request clients stay compatible.
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return json({success:false,error:"Only POST requests are allowed."},405);
 const authorization=req.headers.get("Authorization");
 if(!authorization?.startsWith("Bearer "))return json({success:false,error:"Authentication required."},401);
 try{
  const url=Deno.env.get("SUPABASE_URL"),key=Deno.env.get("SUPABASE_ANON_KEY")??Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if(!url||!key)return json({success:false,error:"Lifecycle request service unavailable."},503);
  const client=createClient(url,key,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:user,error:authenticationError}=await client.auth.getUser();
  if(authenticationError||!user.user)return json({success:false,error:"Invalid authentication."},401);
  const body=await req.json().catch(()=>null);
  if(body?.action==="delete"){
   if(body.confirmation!=="DELETE" || !validDeletionIdentity(body))return deletionJson({success:false,deleted_user:false,accepted:false,code:"ACCOUNT_DELETION_INVALID_CONFIRMATION",error:"Explicit deletion confirmation and a durable request are required."},400);
   const token=authorization.substring(7);
   if(!hasRecentDeletionAuthentication(token,user.user.id))return deletionJson({success:false,deleted_user:false,accepted:false,code:"ACCOUNT_DELETION_REAUTHENTICATE",error:"Sign out and sign back in, then confirm account deletion within 15 minutes."},403);
   const admin=deletionAdmin(),hash=await deletionHash(body.recovery_token);
   const {error:prepareError}=await admin.rpc("begin_trexven_account_deletion",{p_user_id:user.user.id,p_request_id:body.request_id,p_recovery_hash:hash});
   if(prepareError)return deletionFailure(prepareError);
   return await resumeDeletion(admin,body.request_id,hash);
  }
  if(!body||typeof body.business_id!=="string"||typeof body.request_id!=="string"||typeof body.reason!=="string"){
   return json({success:false,deleted_user:false,error:"Owner review and a durable request are required. No account or financial records were deleted."},409);
  }
  const {data,error}=await client.rpc("request_trexven_account_lifecycle",{p_business_id:body.business_id,p_request_id:body.request_id,p_kind:"deletion",p_reason:body.reason});
  if(error)return json({success:false,deleted_user:false,error:"Deletion request not confirmed."},error.code==="42501"?403:503);
  if(!data || typeof data.id!=="string" || data.status!=="requested" || data.financial_records_preserved!==true){
   return json({success:false,deleted_user:false,error:"Deletion request not confirmed."},503);
  }
  return json({success:true,requested:true,deleted_user:false,result:data},202);
 }catch{
  console.error("ACCOUNT_LIFECYCLE_REQUEST_FAILED");
  return json({success:false,deleted_user:false,error:"Lifecycle request unavailable."},503);
 }
});

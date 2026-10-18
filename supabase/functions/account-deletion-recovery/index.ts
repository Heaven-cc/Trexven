import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { deletionAdmin, deletionCors, deletionFailure, deletionHash, deletionJson, resumeDeletion, validDeletionIdentity } from "../_shared/account-deletion.ts";

// The gateway does not require an Auth session here: deletion revokes sessions.
// This route requires the 256-bit recovery credential of an ALREADY accepted
// deletion. It cannot create a request or choose a user/business to delete.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: deletionCors });
  if (req.method !== "POST") return deletionJson({ success: false, error: "Only POST requests are allowed." }, 405);
  try {
    const body = await req.json().catch(() => null);
    if (!body || !validDeletionIdentity(body)) return deletionJson({ success: false, error: "Valid original recovery credentials are required." }, 400);
    return await resumeDeletion(deletionAdmin(), body.request_id, await deletionHash(body.recovery_token));
  } catch {
    console.error("ACCOUNT_DELETION_RECOVERY_UNCONFIRMED");
    return deletionFailure({});
  }
});

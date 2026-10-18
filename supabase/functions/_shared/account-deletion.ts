import { createClient } from "npm:@supabase/supabase-js@2.117.2";

export const deletionCors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export const deletionJson = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...deletionCors, "Content-Type": "application/json", "Cache-Control": "no-store" },
});
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function validDeletionIdentity(body: Record<string, unknown>): boolean {
  return typeof body.request_id === "string" && uuid.test(body.request_id) &&
    typeof body.recovery_token === "string" && /^[0-9a-f]{64}$/.test(body.recovery_token);
}
export async function deletionHash(secret: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, "0")).join("");
}
export function deletionAdmin() {
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("ACCOUNT_DELETION_UNAVAILABLE");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: (input, init) => fetch(input, { ...init, signal: AbortSignal.timeout(15000) }) },
  });
}
export type DeletionAdmin = ReturnType<typeof deletionAdmin>;

// getUser must have verified this exact bearer token before inspecting claims.
// A refreshed token's iat is deliberately not accepted as reauthentication.
export function hasRecentDeletionAuthentication(token: string, userId: string): boolean {
  try {
    const encoded = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, "=")));
    const now = Math.floor(Date.now() / 1000);
    return claims.sub === userId && typeof claims.session_id === "string" &&
      Array.isArray(claims.amr) && claims.amr.some((entry: { method?: string; timestamp?: number }) =>
        ["password", "oauth", "otp", "totp", "webauthn"].includes(entry.method ?? "") &&
        typeof entry.timestamp === "number" && entry.timestamp <= now + 30 && entry.timestamp >= now - 900);
  } catch { return false; }
}

export function deletionFailure(error: { code?: string; message?: string }): Response {
  const blockers: Record<string, string> = {
    ACCOUNT_DELETION_ACTIVE_USERS: "Remove or transfer other active business users before deleting your account.",
    ACCOUNT_DELETION_OPEN_SHIFT: "Close and reconcile your business cash shifts before deleting your account.",
    ACCOUNT_DELETION_PENDING_REVIEW: "Complete pending credit, customer/supplier returns, stocktake, inventory and handover reviews before deleting your account.",
    ACCOUNT_DELETION_OUTSTANDING_CREDIT: "Settle outstanding customer credit or transfer business ownership before deleting your account.",
    ACCOUNT_DELETION_CONFLICT: "Recover the original account deletion request instead of starting another.",
  };
  const reason = Object.keys(blockers).find((key) => error.message === key);
  if (reason) return deletionJson({ success: false, deleted_user: false, accepted: false, code: reason, error: blockers[reason] }, 409);
  if (error.message === "ACCOUNT_DELETION_NOT_FOUND") {
    return deletionJson({ success: false, deleted_user: false, code: "ACCOUNT_DELETION_NOT_FOUND", error: "No matching accepted deletion request was found." }, 404);
  }
  return deletionJson({ success: false, deleted_user: false, code: "ACCOUNT_DELETION_UNCONFIRMED", error: "Account deletion could not be confirmed. Keep the original request and recover its status." }, 503);
}

export async function resumeDeletion(admin: DeletionAdmin, requestId: string, recoveryHash: string): Promise<Response> {
  const lease = crypto.randomUUID();
  const { data: state, error: claimError } = await admin.rpc("claim_trexven_account_deletion", {
    p_request_id: requestId, p_recovery_hash: recoveryHash, p_lease: lease,
  });
  if (claimError) return deletionFailure(claimError);
  if (state?.status === "deleted") return deletionJson({ success: true, deleted_user: true, request_id: requestId, financial_records_preserved: true });
  if (state?.status === "processing") return deletionJson({ success: false, deleted_user: false, accepted: true, code: "ACCOUNT_DELETION_PROCESSING", error: "Deletion is still processing. Recover this same request shortly." }, 202);
  if (state?.status !== "prepared" || typeof state.user_id !== "string") return deletionFailure({});

  // Never hard-delete the Auth row: financial actor/owner UUID references remain.
  // Auth soft deletion removes credentials/identities, MFA and refresh sessions.
  const { error: authError } = await admin.auth.admin.deleteUser(state.user_id, true);
  if (authError) {
    await admin.rpc("release_trexven_account_deletion", { p_request_id: requestId, p_lease: lease });
    return deletionFailure({});
  }
  const { data: result, error: finishError } = await admin.rpc("finish_trexven_account_deletion", {
    p_request_id: requestId, p_lease: lease,
  });
  if (finishError || result?.status !== "deleted") return deletionFailure(finishError ?? {});
  return deletionJson({ success: true, deleted_user: true, request_id: requestId, financial_records_preserved: true });
}

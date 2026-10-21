import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.2";

// PREPARED ONLY: deploy with verify_jwt=true after explicit approval.
// No service-role client, caller-supplied email/target user, or token response.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: Record<string, unknown>, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
});
const timedFetch: typeof fetch = (input, init) =>
  fetch(input, { ...init, signal: AbortSignal.timeout(10000) });

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  let verifier: ReturnType<typeof createClient> | undefined;
  let verificationSession = false;
  let submitted = false;
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    if (!url || !key) return reply({ error: "Password service unavailable" }, 503);
    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return reply({ error: "Authentication required" }, 401);
    if (Number(req.headers.get("Content-Length") ?? 0) > 8192) return reply({ error: "Invalid request" }, 400);
    const text = await req.text();
    if (text.length > 8192) return reply({ error: "Invalid request" }, 400);
    let body: any;
    try { body = JSON.parse(text); } catch (_) { return reply({ error: "Invalid request" }, 400); }
    if (!body || typeof body !== "object" || Array.isArray(body) ||
        Object.keys(body).some(k => !["business_id", "current_password", "new_password"].includes(k)) ||
        typeof body.business_id !== "string" ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.business_id) ||
        typeof body.current_password !== "string" || !body.current_password ||
        body.current_password.length > 1024 || typeof body.new_password !== "string" ||
        body.new_password.length < 8 || body.new_password.length > 1024 ||
        body.new_password === body.current_password) return reply({ error: "Invalid password details" }, 400);
    const caller = createClient(url, key, {
      global: { headers: { Authorization: authorization }, fetch: timedFetch },
      auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
    });
    const { data: identity, error: identityError } = await caller.auth.getUser(authorization.slice(7));
    const actor = identity.user;
    if (identityError || !actor || actor.is_anonymous) return reply({ error: "Invalid authentication" }, 401);
    const assertContext = async () => {
      const { data, error } = await caller.rpc("get_trexven_pos_context", { p_business_id: body.business_id });
      if (error || !Array.isArray(data) || data.length !== 1 ||
          data[0]?.business?.id !== body.business_id ||
          data[0]?.employee?.business_id !== body.business_id ||
          data[0]?.employee?.user_id !== actor.id ||
          data[0]?.employee?.status !== "active" || !data[0]?.employee?.membership_id) {
        throw new Error("ACCESS_DENIED");
      }
    };
    await assertContext();
    // Resolve only the authenticated user's canonical Auth identifier. Employee
    // profile email may be null; internal Auth email is never sent to Flutter.
    const credentials = actor.email
      ? { email: actor.email, password: body.current_password }
      : actor.phone ? { phone: actor.phone, password: body.current_password } : null;
    if (!credentials) return reply({ error: "Contact the owner to review this account" }, 409);
    verifier = createClient(url, key, {
      global: { fetch: timedFetch },
      auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
    });
    const checked = await verifier.auth.signInWithPassword(credentials);
    verificationSession = checked.data.session != null;
    if (checked.error || !checked.data.session || checked.data.user?.id !== actor.id) {
      return reply({ error: "Current credential verification failed" }, checked.error?.status === 429 ? 429 : 403);
    }
    // Recheck current employee/membership authority after credential verification.
    await assertContext();
    // Update via the ORIGINAL caller session. Auth enforces current password,
    // password policy, MFA and secure-reauthentication requirements. Do not use
    // admin.updateUserById or replace the caller's session with the verifier.
    submitted = true;
    const updated = await timedFetch(url + "/auth/v1/user", {
      method: "PUT",
      headers: { Authorization: authorization, apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({ password: body.new_password, current_password: body.current_password }),
    });
    const result = await updated.json().catch(() => null);
    if (!updated.ok) {
      const reauth = ["reauthentication_needed", "insufficient_aal", "mfa_verification_required"].includes(result?.code);
      return reply({ error: reauth ? "Secure reauthentication required; sign in again" : "Password change rejected",
        code: reauth ? "reauthentication_required" : "password_change_rejected" },
        updated.status === 429 ? 429 : reauth ? 401 : 400);
    }
    if (result?.id !== actor.id) return reply({ error: "Password outcome unconfirmed", code: "outcome_unconfirmed" }, 502);
    return reply({ success: true, user_id: actor.id });
  } catch (error) {
    if (error instanceof Error && error.message === "ACCESS_DENIED") return reply({ error: "Active employee access required" }, 403);
    // Never log/return request data, upstream messages, credentials or tokens.
    return reply({ error: submitted ? "Password outcome unconfirmed; do not retry automatically" : "Password service unavailable",
      code: submitted ? "outcome_unconfirmed" : "unavailable" }, submitted ? 502 : 503);
  } finally {
    if (verificationSession && verifier) {
      // The verifier's temporary session must not survive the request.
      // Password updates normally revoke other sessions already.
      try { await verifier.auth.signOut({ scope: "local" }); } catch (_) { /* No token is persisted or returned. */ }
    }
  }
});

// PREPARED ONLY. Deploy with verify_jwt=true only after explicit approval.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.2";
import { PAYSTACK_TEST_RELEASE_APPROVED, authOptions, cors, reply, serverProvider,
  timedFetch, uuid, readBody } from "../_shared/paystack-server.ts";
serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  if (!PAYSTACK_TEST_RELEASE_APPROVED) return reply({ error: "Checkout is not available yet" }, 503);
  try {
    const authorization = req.headers.get("Authorization");
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    if (!authorization?.startsWith("Bearer ") || !url || !key) return reply({ error: "Authentication required" }, 401);
    const caller = createClient(url, key, { global: { fetch: timedFetch,
      headers: { Authorization: authorization } }, auth: authOptions });
    const { data: identity, error: identityError } = await caller.auth.getUser(authorization.slice(7));
    if (identityError || !identity.user || identity.user.is_anonymous || !identity.user.email) {
      return reply({ error: "Authentication required" }, 401);
    }
    const raw = new TextDecoder().decode(await readBody(req, 4096));
    const body = JSON.parse(raw);
    if (!body || Array.isArray(body) || typeof body !== "object" ||
        Object.keys(body).some(k => !["business_id","request_id","plan_id","country_code","interval_months"].includes(k)) ||
        typeof body.business_id !== "string" || !uuid.test(body.business_id) ||
        typeof body.request_id !== "string" || !uuid.test(body.request_id) ||
        !["start","core","pro"].includes(body.plan_id) ||
        !["NG","GH","CI"].includes(body.country_code) || ![1,12].includes(body.interval_months)) {
      return reply({ error: "Invalid billing selection" }, 400);
    }
    // Owner identity is checked with the caller JWT before creating a service client.
    const { data: business, error: businessError } = await caller.from("businesses")
      .select("id,owner_id").eq("id", body.business_id).maybeSingle();
    if (businessError || business?.owner_id !== identity.user.id) return reply({ error: "Owner required" }, 403);
    const { server, provider } = serverProvider(body.business_id, identity.user.email);
    const { data: session, error } = await caller.rpc("request_trexven_country_billing_session", {
      p_business_id: body.business_id, p_request_id: body.request_id, p_plan_id: body.plan_id,
      p_country_code: body.country_code, p_interval_months: body.interval_months,
    });
    if (error || !session?.id || !uuid.test(session.id)) throw new Error("BILLING_SESSION_UNCONFIRMED");
    // Attach stable reference BEFORE contacting Paystack. A timeout must recover this
    // same reference, never generate another request/session or collect payment again.
    const reference = "trexven-" + session.id;
    const attached = await server.rpc("attach_trexven_billing_provider_session", {
      p_session_id: session.id, p_provider: provider.name, p_provider_session_ref: reference,
    });
    if (attached.error) throw new Error("BILLING_PROVIDER_DISABLED");
    const checkout = await provider.createCheckout({ id: session.id,
      businessId: body.business_id, amount: "", currency: "", plan: body.plan_id }, session.id);
    return reply({ session_id: session.id, reference: checkout.reference, url: checkout.url, status: "pending" });
  } catch (_) {
    // No secrets, provider payloads, access tokens, or personal data in logs/errors.
    return reply({ error: "Checkout was not confirmed. Keep the original request for recovery." }, 503);
  }
});

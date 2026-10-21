// PREPARED ONLY. Provider signatures replace user JWTs; deployment needs explicit
// approval with verify_jwt=false. No automatic entitlement activation is enabled.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { processVerifiedWebhook } from "../_shared/billing-provider.ts";
import { PAYSTACK_TEST_RELEASE_APPROVED, reply, serverProvider, readBody } from "../_shared/paystack-server.ts";
serve(async req => {
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  if (!PAYSTACK_TEST_RELEASE_APPROVED) return reply({ error: "Billing verification unavailable" }, 503);
  try {
    const raw = await readBody(req, 262144);
    const { server, provider } = serverProvider();
    const rpc = { rpc: async (name: string, parameters: Record<string, unknown>) => {
      const { data, error } = await server.rpc(name, parameters);
      return { data, error };
    } };
    await processVerifiedWebhook(provider.name, raw, req.headers, rpc,
      new Map([[provider.name, provider]]));
    // A recorded payment is not subscription activation. The existing service-only
    // activation function requires separate release approval and reconciliation.
    return reply({ received: true });
  } catch (_) {
    // Non-2xx requests can be retried. The SQL event/payment constraints deduplicate.
    return reply({ error: "Billing event not confirmed" }, 503);
  }
});

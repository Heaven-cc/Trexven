// PREPARED ONLY. No endpoint can run until a separately reviewed release changes this.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.2";
import { PreparedPaystackProvider, type CountryBillingSession } from "./paystack-provider.ts";
export const PAYSTACK_TEST_RELEASE_APPROVED = false;
export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export const reply = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });
export const timedFetch: typeof fetch = (input, init) =>
  fetch(input, { ...init, signal: AbortSignal.timeout(10000) });
export const authOptions = { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false };
export const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function serverProvider(ownedBusiness?: string, ownerEmail?: string) {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const secretKey = Deno.env.get("TREXVEN_PAYSTACK_TEST_SECRET");
  const markets = new Set((Deno.env.get("TREXVEN_PAYSTACK_TEST_MARKETS") ?? "")
    .split(",").map(s => s.trim()).filter(Boolean));
  if (!url || !serviceKey || !secretKey) throw new Error("BILLING_PROVIDER_DISABLED");
  const server = createClient(url, serviceKey, { global: { fetch: timedFetch }, auth: authOptions });
  const provider = new PreparedPaystackProvider({
    secretKey, markets,
    readSession: async id => {
      const { data, error } = await server.rpc("get_trexven_country_billing_session", { p_session_id: id });
      if (error || !data || data.id !== id ||
          (ownedBusiness !== undefined && data.business_id !== ownedBusiness)) {
        throw new Error("BILLING_SESSION_INVALID");
      }
      return { id: data.id, businessId: data.business_id, plan: data.plan_id,
        amount: data.amount, currency: data.currency, countryCode: data.country_code,
        intervalMonths: data.interval_months, status: data.status,
        email: ownerEmail } as CountryBillingSession;
    },
  });
  return { server, provider };
}

export async function readBody(req: Request, limit: number): Promise<Uint8Array> {
  const reader = req.body?.getReader();
  if (!reader) throw new Error("BILLING_BODY_REQUIRED");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > limit) {
        await reader.cancel();
        throw new Error("BILLING_BODY_TOO_LARGE");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const result = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.length; }
  return result;
}

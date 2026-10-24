// Google Play subscription verification scaffold.
// This endpoint is intentionally disabled until an authenticated, idempotent
// purchase-token ledger and verified entitlement lifecycle are deployed.
// Never use purchase callbacks or client-supplied prices to activate access.
const JSON_HEADERS = { "content-type": "application/json", "cache-control": "no-store" };
function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, { error: "Method not allowed" });
  // Keep the activation switch server-side. It must never default to true.
  if (Deno.env.get("TREXVEN_PLAY_BILLING_ACTIVE") !== "true") {
    return reply(503, { error: "Google Play billing is not activated." });
  }
  // Deliberately fail closed until purchase ledger, owner authentication,
  // package verification, RTDN, token acknowledgement and state sync exist.
  return reply(503, {
    error: "Google Play purchase verification is not configured.",
  });
});

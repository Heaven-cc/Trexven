// Provider-independent foundation. No provider adapters or credentials are enabled.
// A future webhook endpoint must pass raw bytes through a reviewed adapter;
// parsing an unsigned client response can never create a VerifiedPayment.
export type BillingSession = Readonly<{
  id: string; businessId: string; amount: string; currency: string; plan: string;
}>;
export type ProviderEvent = Readonly<{
  eventId: string; sessionId: string; paymentRef: string;
}>;
export type VerifiedPayment = Readonly<{
  paymentRef: string; sessionId: string; amount: string; currency: string;
  status: "verified" | "failed";
}>;
export interface BillingProvider {
  readonly name: string;
  createCheckout(session: BillingSession, idempotencyKey: string): Promise<{ reference: string; url: string }>;
  verifyWebhook(raw: Uint8Array, headers: Headers): Promise<ProviderEvent>;
  lookupPayment(reference: string): Promise<VerifiedPayment>;
  cancelRenewal(customerReference: string, idempotencyKey: string): Promise<void>;
}
export interface BillingRpc {
  rpc(name: string, parameters: Record<string, unknown>): Promise<{ data: unknown; error: unknown }>;
}
// Empty by design. Live registration, credentials and charging require separate approval.
export const enabledBillingProviders: ReadonlyMap<string, BillingProvider> = new Map();
export async function processVerifiedWebhook(providerName: string, raw: Uint8Array,
  headers: Headers, server: BillingRpc, providers = enabledBillingProviders): Promise<unknown> {
  const provider = providers.get(providerName);
  if (!provider || provider.name !== providerName) throw new Error("BILLING_PROVIDER_DISABLED");
  const event = await provider.verifyWebhook(raw, headers);
  if (!event.eventId || !event.sessionId || !event.paymentRef) throw new Error("BILLING_EVENT_INVALID");
  // Lookup with provider credentials independently confirms the signed notification.
  const payment = await provider.lookupPayment(event.paymentRef);
  if (payment.paymentRef !== event.paymentRef || payment.sessionId !== event.sessionId ||
      !["verified", "failed"].includes(payment.status) ||
      !/^\d+(\.\d{1,2})?$/.test(payment.amount) || !/^[A-Z]{3}$/.test(payment.currency)) {
    throw new Error("BILLING_PAYMENT_MISMATCH");
  }
  const result = await server.rpc("record_verified_trexven_billing_event", {
    p_provider: provider.name, p_event_id: event.eventId, p_session_id: event.sessionId,
    p_payment_ref: payment.paymentRef, p_amount: payment.amount,
    p_currency: payment.currency, p_status: payment.status,
  });
  if (result.error) throw new Error("BILLING_RECORD_UNCONFIRMED");
  return result.data;
}

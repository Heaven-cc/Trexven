// PREPARED ONLY: not registered, not deployed, and test keys only.
// Reviewed against https://paystack.com/docs/api/transaction/,
// https://paystack.com/docs/api/ and https://paystack.com/docs/payments/webhooks/.
import type { BillingProvider, BillingSession, ProviderEvent, VerifiedPayment } from "./billing-provider.ts";

export type CountryBillingSession = BillingSession & Readonly<{
  countryCode: string; intervalMonths: number; status: string; email?: string;
}>;
type Options = Readonly<{
  secretKey: string;
  // Explicitly approved TEST merchant markets; never infer eligibility from XOF.
  markets: ReadonlySet<string>;
  // Must read the stored session snapshot and verified owner's email server-side.
  // The HTTP caller must authorize business ownership before invoking checkout.
  readSession: (id: string) => Promise<CountryBillingSession>;
}>;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const currencies: Readonly<Record<string, string>> = { NG: "NGN", GH: "GHS", CI: "XOF" };
const referenceFor = (id: string) => {
  if (!uuid.test(id)) throw new Error("BILLING_SESSION_INVALID");
  return "trexven-" + id;
};
function sessionFor(reference: string): string {
  const id = reference.startsWith("trexven-") ? reference.slice(8) : "";
  if (!uuid.test(id)) throw new Error("BILLING_REFERENCE_INVALID");
  return id;
}
// Paystack requires x100 even for XOF; XOF itself must remain a whole amount.
function providerAmount(amount: string, currency: string): string {
  if (!/^\d+(\.\d{1,2})?$/.test(amount)) throw new Error("BILLING_AMOUNT_INVALID");
  const [whole, fraction = ""] = amount.split(".");
  if (currency === "XOF" && /[1-9]/.test(fraction)) throw new Error("BILLING_AMOUNT_INVALID");
  const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0") || "0");
  if (minor <= 0n || minor > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error("BILLING_AMOUNT_INVALID");
  return minor.toString();
}
function numericAmount(value: unknown): string {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0) {
    throw new Error("BILLING_PROVIDER_AMOUNT_INVALID");
  }
  return String(value);
}
function object(value: unknown): Record<string, any> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("BILLING_RESPONSE_INVALID");
  return value as Record<string, any>;
}

export class PreparedPaystackProvider implements BillingProvider {
  readonly name = "paystack";
  private readonly options: Options;
  constructor(options: Options) {
    if (!/^sk_test_[a-zA-Z0-9]+$/.test(options.secretKey) ||
        options.markets.size === 0 || [...options.markets].some(m => !currencies[m])) {
      throw new Error("BILLING_PROVIDER_DISABLED");
    }
    this.options = { ...options, markets: new Set(options.markets) };
  }
  private async session(id: string): Promise<CountryBillingSession> {
    referenceFor(id);
    const s = await this.options.readSession(id);
    if (s.id !== id || !uuid.test(s.businessId) ||
        !this.options.markets.has(s.countryCode) || currencies[s.countryCode] !== s.currency ||
        ![1, 12].includes(s.intervalMonths) || !["start", "core", "pro"].includes(s.plan)) {
      throw new Error("BILLING_SESSION_INVALID");
    }
    providerAmount(s.amount, s.currency);
    return s;
  }
  private async request(path: string, body?: Record<string, unknown>): Promise<Record<string, any>> {
    const response = await fetch("https://api.paystack.co" + path, {
      method: body ? "POST" : "GET",
      headers: { Authorization: "Bearer " + this.options.secretKey, "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(10000), redirect: "error",
    });
    if (!response.ok) throw new Error("BILLING_PROVIDER_UNCONFIRMED");
    const envelope = object(await response.json());
    if (envelope.status !== true) throw new Error("BILLING_PROVIDER_UNCONFIRMED");
    return object(envelope.data);
  }
  async createCheckout(input: BillingSession, idempotencyKey: string): Promise<{ reference: string; url: string }> {
    if (idempotencyKey !== input.id) throw new Error("BILLING_REQUEST_INVALID");
    // Ignore supplied price/currency/plan: only the database snapshot is authoritative.
    const s = await this.session(input.id);
    if (!["requested", "pending"].includes(s.status) || typeof s.email !== "string" ||
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s.email)) throw new Error("BILLING_SESSION_INVALID");
    const reference = referenceFor(s.id);
    const data = await this.request("/transaction/initialize", {
      reference, email: s.email, amount: providerAmount(s.amount, s.currency), currency: s.currency,
      metadata: { session_id: s.id, business_id: s.businessId, country_code: s.countryCode,
        interval_months: s.intervalMonths, plan_id: s.plan },
      // No Paystack plan code or reusable authorization: no recurring charge.
    });
    if (data.reference !== reference || typeof data.authorization_url !== "string") {
      throw new Error("BILLING_CHECKOUT_MISMATCH");
    }
    const url = new URL(data.authorization_url);
    if (url.protocol !== "https:" || url.hostname !== "checkout.paystack.com" ||
        url.port || url.username || url.password) throw new Error("BILLING_CHECKOUT_MISMATCH");
    return { reference, url: url.toString() };
  }
  async verifyWebhook(raw: Uint8Array, headers: Headers): Promise<ProviderEvent> {
    if (!raw.length || raw.length > 262144) throw new Error("BILLING_EVENT_INVALID");
    const signature = headers.get("x-paystack-signature") ?? "";
    if (!/^[0-9a-f]{128}$/i.test(signature)) throw new Error("BILLING_SIGNATURE_INVALID");
    const bytes = Uint8Array.from(signature.match(/../g)!, hex => parseInt(hex, 16));
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(this.options.secretKey),
      { name: "HMAC", hash: "SHA-512" }, false, ["verify"]);
    if (!await crypto.subtle.verify("HMAC", key, bytes, raw)) throw new Error("BILLING_SIGNATURE_INVALID");
    const event = object(JSON.parse(new TextDecoder().decode(raw)));
    const data = object(event.data);
    if (event.event !== "charge.success" || data.domain !== "test" || data.status !== "success" ||
        typeof data.reference !== "string" || !/^\d{1,30}$/.test(String(data.id))) {
      throw new Error("BILLING_EVENT_INVALID");
    }
    return { eventId: "charge.success:" + data.id + ":" + data.reference,
      sessionId: sessionFor(data.reference), paymentRef: data.reference };
  }
  async lookupPayment(reference: string): Promise<VerifiedPayment> {
    const s = await this.session(sessionFor(reference));
    const data = await this.request("/transaction/verify/" + encodeURIComponent(reference));
    const metadata = object(data.metadata);
    if (data.reference !== reference || data.domain !== "test" || data.status !== "success" ||
        numericAmount(data.amount) !== providerAmount(s.amount, s.currency) || data.currency !== s.currency ||
        metadata.session_id !== s.id || metadata.business_id !== s.businessId ||
        metadata.country_code !== s.countryCode || metadata.interval_months !== s.intervalMonths ||
        metadata.plan_id !== s.plan) throw new Error("BILLING_PAYMENT_MISMATCH");
    // Pending/abandoned/reversed states never become verified or failed entitlements.
    return { paymentRef: reference, sessionId: s.id, amount: s.amount, currency: s.currency, status: "verified" };
  }
  async cancelRenewal(_customerReference: string, _idempotencyKey: string): Promise<void> {
    // Cancellation remains the existing owner review request; never claim provider cancellation.
    throw new Error("BILLING_RENEWAL_NOT_CONFIGURED");
  }
}

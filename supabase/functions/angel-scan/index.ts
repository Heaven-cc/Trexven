import "jsr:@supabase/functions-js@2.117.2/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

// Angel Scan does not change stock or complete sales. Decisions stay in reviewed RPCs.
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const text = (value: unknown, limit = 150) =>
  typeof value === "string" ? value.trim().slice(0, limit) : "";
const MAX_IMAGE_BYTES = 4_000_000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers });
  if (req.method !== "POST") return respond({ error: "Method not allowed" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const groq = Deno.env.get("GROQ_API_KEY");
    const visionModel = Deno.env.get("GROQ_VISION_MODEL");
    if (!groq || !visionModel) return respond({ error: "Angel Scan vision is not configured" }, 503);
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
    if (!token) return respond({ error: "Sign in required" }, 401);
    const caller = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${token}` } } });
    const { data: auth, error: authError } = await caller.auth.getUser(token);
    if (authError || !auth.user) return respond({ error: "Invalid session" }, 401);
    const body = await req.json();
    const businessId = text(body.business_id, 64);
    const purpose = text(body.purpose, 24);
    if (!uuid.test(businessId) || !["inventory", "sale"].includes(purpose))
      return respond({ error: "Invalid scan context" }, 400);
    const admin = createClient(url, service);
    const { data: business, error: businessError } = await admin.from("businesses")
      .select("id,owner_id").eq("id", businessId).maybeSingle();
    if (businessError || !business) return respond({ error: "Business unavailable" }, 404);
    const owner = business.owner_id === auth.user.id;
    if (!owner) {
      const { data: member, error: memberError } = await admin.from("business_members")
        .select("id,role,status").eq("business_id", businessId)
        .eq("user_id", auth.user.id).eq("status", "active").maybeSingle();
      if (memberError || !member) return respond({ error: "Business access denied" }, 403);
      if (purpose === "inventory") {
        if (member.role !== "manager") return respond({ error: "Owner or authorized manager required" }, 403);
        const { data: allowed, error: grantError } = await caller.rpc("angel_scan_can_manage_inventory", { p_business_id: businessId });
        if (grantError || allowed !== true) return respond({ error: "Angel inventory permission required" }, 403);
      } else {
        const { data: permitted, error: permissionError } = await caller.rpc("angel_scan_can_sell", { p_business_id: businessId });
        if (permissionError || permitted !== true) return respond({ error: "POS selling permission required" }, 403);
      }
    }
    if (typeof body.image_base64 !== "string" ||
        body.image_base64.length === 0 || body.image_base64.length > Math.ceil(MAX_IMAGE_BYTES * 4 / 3) + 64 ||
        !/^[a-zA-Z0-9+/]+={0,2}$/.test(body.image_base64))
      return respond({ error: "Unsupported or oversized image" }, 400);
    const mime = text(body.mime_type, 40);
    if (!["image/jpeg", "image/png", "image/webp"].includes(mime))
      return respond({ error: "JPEG, PNG or WebP required" }, 400);

    // Recognition is deliberately advisory: no invented inventory IDs, prices or stock updates.
    const isDocument = body.document === true;
    const instruction = isDocument
      ? "Read the itemized receipt/invoice/product list. Return up to 80 line items with exact visible name, brand, SKU/part number, quantity and purchase unit cost where stated. Never treat purchase cost as selling price. Mark unreadable or missing values null. Preserve evidence and ambiguities."
      : "Identify the visible product, package name, brand, model, SKU or part number, barcode, category and description when supported by the image. If only an illustration is visible, state a likely generic name without inventing the exact manufacturer or model. Report uncertainty.";
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 26000);
    let answer: Response;
    try {
      answer = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST", signal: controller.signal,
        headers: { Authorization: `Bearer ${groq}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: visionModel, temperature: 0, max_completion_tokens: 2500,
          messages: [{
            role: "user", content: [
              { type: "text", text: `Return ONLY JSON with keys items (array of objects: name,brand,sku,barcode,category,quantity,cost,uncertain), and notes (string). ${instruction}` },
              { type: "image_url", image_url: { url: `data:${mime};base64,${body.image_base64}` } },
            ],
          }],
        }),
      });
    } finally { clearTimeout(timeout); }
    if (!answer.ok) {
      console.error("ANGEL_SCAN_VISION_ERROR", answer.status);
      return respond({ error: "Vision recognition unavailable; try barcode or search" }, 502);
    }
    const data = await answer.json();
    const raw = String(data?.choices?.[0]?.message?.content ?? "").replace(/^```(?:json)?\s*|\s*```$/g, "").trim();
    let parsed: any;
    try { parsed = JSON.parse(raw); } catch { return respond({ error: "Vision response could not be parsed" }, 502); }
    if (!Array.isArray(parsed?.items) || parsed.items.length > 80)
      return respond({ error: "Invalid recognition result" }, 502);
    const items = parsed.items.map((entry: any) => ({
      name: text(entry?.name, 180), brand: text(entry?.brand, 100) || null,
      sku: text(entry?.sku, 100) || null, barcode: text(entry?.barcode, 100) || null,
      category: text(entry?.category, 100) || null,
      quantity: Number.isFinite(Number(entry?.quantity)) && Number(entry?.quantity) > 0 ? Number(entry.quantity) : null,
      cost: Number.isFinite(Number(entry?.cost)) && Number(entry?.cost) >= 0 ? Number(entry.cost) : null,
      uncertain: entry?.uncertain !== false,
    })).filter((x: any) => x.name.length > 0);
    // Limit matching to active business; ID equality never comes from the model.
    const { data: catalog, error: catalogError } = await admin.from("products")
      .select("id,name,brand,sku,barcode,category,selling_price,quantity,is_active")
      .eq("business_id", businessId).limit(2000);
    if (catalogError) return respond({ error: "Inventory lookup failed" }, 503);
    const norm = (s: unknown) => text(s, 180).toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
    const matched = items.map((item: any) => {
      const exact = (catalog ?? []).filter((p: any) =>
        (item.barcode && p.barcode && item.barcode === p.barcode) ||
        (item.sku && p.sku && norm(item.sku) === norm(p.sku) &&
          (!item.brand || norm(item.brand) === norm(p.brand))) ||
        (norm(item.name) && norm(item.name) === norm(p.name) &&
          (!item.brand || norm(item.brand) === norm(p.brand))));
      return { ...item, matches: exact.map((p: any) => ({
        product_id: p.id, name: p.name, brand: p.brand, sku: p.sku,
        selling_price: purpose === "sale" ? p.selling_price : null,
        quantity: p.quantity, active: p.is_active,
      })), match_status: exact.length === 1 ? "review_match" : exact.length > 1 ? "ambiguous" : "not_found" };
    });
    return respond({ success: true, requires_review: true, purpose, items: matched, notes: text(parsed.notes, 700) });
  } catch (error) {
    console.error("ANGEL_SCAN_FAILED", error instanceof Error ? error.name : "unknown");
    return respond({ error: "Unable to analyze this scan" }, 500);
  }
});

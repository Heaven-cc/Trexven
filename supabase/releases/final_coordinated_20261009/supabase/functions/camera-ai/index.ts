import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

// Testing build: explain stored TREXVEN evidence without sending camera data
// or snapshots to an external model provider.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status,
    headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Only POST requests are allowed." }, 405);
  try {
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return json({ success: false, error: "Authentication required." }, 401);
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) return json({ success: false, error: "Camera evidence service is not configured." }, 503);
    const admin = createClient(url, key);
    const { data: userData, error: authError } = await admin.auth.getUser(auth.slice(7));
    if (authError || !userData.user) return json({ success: false, error: "Invalid authentication." }, 401);
    const body = await req.json().catch(() => null);
    if (!body || typeof body.event_id !== "string" || typeof body.camera_id !== "string") {
      return json({ success: false, error: "Choose a stored camera event to explain. Use Angel for business questions." }, 400);
    }
    // User JWT makes these reads subject to RLS, even with a server API key.
    const scoped = createClient(url, key, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: event, error: eventError } = await scoped.from("camera_events")
      .select("id,business_id,camera_id,event_type,description,confidence,severity,occurred_at,metadata")
      .eq("id", body.event_id).eq("camera_id", body.camera_id).maybeSingle();
    if (eventError) throw eventError;
    if (!event) return json({ success: false, error: "Event not found or camera access denied." }, 404);
    const { error: entitlementError } = await scoped.rpc("require_trexven_feature", { p_business_id: event.business_id, p_feature: "basic_vision" });
    if (entitlementError) return json({ success: false, error: "Vision subscription access is unavailable." }, 403);
    const { data: allowed, error: limitError } = await admin.rpc("consume_camera_explanation_request", { p_user_id: userData.user.id });
    if (limitError) throw limitError;
    if (!allowed) return json({ success: false, error: "Too many requests. Try again in a minute." }, 429);
    const { data: insights, error: insightError } = await scoped.from("angel_insights")
      .select("metadata").eq("business_id", event.business_id).eq("source", "vision_intelligence")
      .order("created_at", { ascending: false }).limit(100);
    if (insightError) throw insightError;
    const insight = (insights ?? []).find((row: any) =>
      row.metadata?.source_event_ids?.includes(event.id) ||
      row.metadata?.timeline?.some((entry: any) => entry.cloud_event_id === event.id));
    const evidence = insight?.metadata;
    const reasons = Array.isArray(evidence?.reasoning) ? evidence.reasoning
      .filter((reason: unknown) => typeof reason === "string").join("; ")
      : "No correlated Intelligence conclusion is available in this snapshot.";
    const answer = `Recorded observation: ${event.description ?? event.event_type}.\n` +
      `Intelligence: ${evidence?.classification ?? "observed activity"}. ${reasons}\n` +
      "Review the event and associated recording. Detection alone does not confirm misconduct.";
    return json({ success: true, answer, business_id: event.business_id, camera_id: event.camera_id,
      event_type: event.event_type, had_image: false, provider: "structured_intelligence", external_ai_enabled: false });
  } catch (error) {
    console.error("CAMERA_EVIDENCE_REQUEST_FAILED");
    return json({ success: false, error: "Camera evidence could not be retrieved." }, 500);
  }
});

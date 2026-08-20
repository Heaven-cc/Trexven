import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type DetectionInput = {
  detection_type: string;
  object_type?: string;
  object_label?: string;
  track_id?: string;
  confidence?: number;
  bounding_box?: Record<string, unknown>;
  attributes?: Record<string, unknown>;
  occurred_at?: string;
  employee_id?: string;
  zone_id?: string;
};

type EventInput = {
  business_id: string;
  camera_id: string;
  event_type: string;
  confidence?: number;
  description?: string;
  detected_object?: string;
  quantity?: number;
  amount?: number;
  metadata?: Record<string, unknown>;
  occurred_at?: string;
  severity?: string;
  external_event_id?: string;
  source_provider?: string;
  model_name?: string;
  detections?: DetectionInput[];
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Only POST requests are allowed." }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json({ error: "Authentication required." }, 401);

    const token = authHeader.replace("Bearer ", "");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) return json({ error: "Camera intelligence service is not configured." }, 500);

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData.user) return json({ error: "Invalid authentication." }, 401);

    const body: EventInput = await req.json();
    if (!body.business_id || !body.camera_id || !body.event_type) {
      return json({ error: "business_id, camera_id and event_type are required." }, 400);
    }

    const userId = userData.user.id;
    const { data: ownedBusiness } = await admin
      .from("businesses")
      .select("id")
      .eq("id", body.business_id)
      .eq("owner_id", userId)
      .maybeSingle();

    let authorized = !!ownedBusiness;
    if (!authorized) {
      const { data: membership } = await admin
        .from("business_members")
        .select("id")
        .eq("business_id", body.business_id)
        .eq("user_id", userId)
        .eq("status", "active")
        .maybeSingle();
      authorized = !!membership;
    }
    if (!authorized) return json({ error: "You do not have access to this business." }, 403);

    const { data: camera, error: cameraError } = await admin
      .from("cameras")
      .select("id, business_id")
      .eq("id", body.camera_id)
      .eq("business_id", body.business_id)
      .maybeSingle();

    if (cameraError || !camera) return json({ error: "Camera not found for this business." }, 404);
    if (body.confidence !== undefined && (body.confidence < 0 || body.confidence > 1)) {
      return json({ error: "confidence must be between 0 and 1." }, 400);
    }

    const provider = body.source_provider ?? "flutter-app";
    if (body.external_event_id) {
      const { data: existing } = await admin
        .from("camera_events")
        .select("id")
        .eq("business_id", body.business_id)
        .eq("source_provider", provider)
        .eq("external_event_id", body.external_event_id)
        .maybeSingle();
      if (existing) return json({ success: true, duplicate: true, event_id: existing.id });
    }

    const occurredAt = body.occurred_at ?? new Date().toISOString();
    const eventPayload = {
      business_id: body.business_id,
      camera_id: body.camera_id,
      event_type: body.event_type,
      confidence: body.confidence ?? null,
      description: body.description ?? null,
      detected_object: body.detected_object ?? null,
      quantity: body.quantity ?? null,
      amount: body.amount ?? null,
      metadata: body.metadata ?? {},
      occurred_at: occurredAt,
      detected_at: new Date().toISOString(),
      severity: body.severity ?? "low",
      status: "detected",
      external_event_id: body.external_event_id ?? null,
      source_provider: provider,
      model_name: body.model_name ?? null,
      raw_payload: body.metadata ?? {},
    };

    const { data: event, error: eventError } = await admin
      .from("camera_events")
      .insert(eventPayload)
      .select("id")
      .single();

    if (eventError) {
      console.error(eventError);
      return json({ error: "Could not save camera event." }, 500);
    }

    const detections = Array.isArray(body.detections) ? body.detections : [];
    if (detections.length > 0) {
      const rows = detections.map((d) => ({
        business_id: body.business_id,
        camera_id: body.camera_id,
        event_id: event.id,
        zone_id: d.zone_id ?? null,
        employee_id: d.employee_id ?? null,
        detection_type: d.detection_type,
        object_type: d.object_type ?? null,
        object_label: d.object_label ?? null,
        track_id: d.track_id ?? null,
        confidence: d.confidence ?? null,
        bounding_box: d.bounding_box ?? null,
        attributes: d.attributes ?? {},
        occurred_at: d.occurred_at ?? occurredAt,
      }));

      const { error: detectionError } = await admin.from("camera_detections").insert(rows);
      if (detectionError) {
        console.error(detectionError);
        return json({ success: true, event_id: event.id, warning: "Event saved but detections could not be saved." }, 207);
      }
    }

    await admin
      .from("cameras")
      .update({ last_seen_at: new Date().toISOString(), status: "online" })
      .eq("id", body.camera_id);

    return json({ success: true, event_id: event.id, detections_saved: detections.length });
  } catch (error) {
    console.error("camera-ingest error", error);
    return json({ error: "Invalid camera intelligence request." }, 500);
  }
});

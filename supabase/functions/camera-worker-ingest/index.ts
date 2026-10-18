import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Detection = {
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

type Payload = {
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
  detections?: Detection[];
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export default {
  fetch: withSupabase({ auth: "secret" }, async (req, ctx) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return json({ error: "Only POST requests are allowed." }, 405);

    try {
      const body: Payload = await req.json();

      if (!body.business_id || !body.camera_id || !body.event_type) {
        return json({ error: "business_id, camera_id and event_type are required." }, 400);
      }

      const { data: camera, error: cameraError } = await ctx.supabaseAdmin
        .from("cameras")
        .select("id, business_id, is_active")
        .eq("id", body.camera_id)
        .eq("business_id", body.business_id)
        .maybeSingle();

      if (cameraError) {
        console.error(cameraError);
        return json({ error: "Could not verify camera." }, 500);
      }

      if (!camera) return json({ error: "Camera not found for this business." }, 404);

      if (body.confidence !== undefined && (body.confidence < 0 || body.confidence > 1)) {
        return json({ error: "confidence must be between 0 and 1." }, 400);
      }

      const occurredAt = body.occurred_at ?? new Date().toISOString();
      const provider = body.source_provider ?? "vision-worker";

      if (body.external_event_id) {
        const { data: duplicate } = await ctx.supabaseAdmin
          .from("camera_events")
          .select("id")
          .eq("business_id", body.business_id)
          .eq("source_provider", provider)
          .eq("external_event_id", body.external_event_id)
          .maybeSingle();

        if (duplicate) {
          return json({ success: true, duplicate: true, event_id: duplicate.id });
        }
      }

      const { data: event, error: eventError } = await ctx.supabaseAdmin
        .from("camera_events")
        .insert({
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
        })
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

        const { error: detectionError } = await ctx.supabaseAdmin
          .from("camera_detections")
          .insert(rows);

        if (detectionError) {
          console.error(detectionError);
          return json({
            success: true,
            event_id: event.id,
            warning: "Event saved but detections could not be saved.",
          }, 207);
        }
      }

      await ctx.supabaseAdmin
        .from("cameras")
        .update({
          last_seen_at: new Date().toISOString(),
          status: "online",
        })
        .eq("id", body.camera_id);

      return json({
        success: true,
        event_id: event.id,
        detections_saved: detections.length,
      });
    } catch (error) {
      console.error("camera-worker-ingest error", error);
      return json({ error: "Invalid camera intelligence request." }, 500);
    }
  }),
};
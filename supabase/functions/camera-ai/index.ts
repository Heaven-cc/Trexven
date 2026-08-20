import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Flagship model by default — swap via the ANTHROPIC_MODEL secret if you'd
// rather trade some quality for lower cost on this per-event background call
// (e.g. "claude-sonnet-5" or "claude-haiku-4-5").
const DEFAULT_MODEL = "claude-opus-5";

const SYSTEM_PROMPT = `You are the camera intelligence layer inside Trexven, a business security platform.
You analyze evidence from an AI vision pipeline (YOLO detection + tracking) for a physical store.

Rules:
1. Only describe what the evidence actually shows. Never claim to see live video unless an image is attached to this message.
2. Clearly separate: what was directly observed, what was detected by the AI, what is merely possible, and what is confirmed.
3. Never accuse a specific person of theft or wrongdoing — describe behavior and flag it as worth human review instead.
4. When an image is attached, describe what you actually see in it, and connect that to the structured detection data provided.
5. Give a concise risk/severity read and one concrete recommended action.
6. Keep responses short and professional — this is read on a phone.`;

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function fetchImageAsBase64(url: string): Promise<{ data: string; mediaType: string } | null> {
  try {
    const resp = await fetch(url);
    if (!resp.ok) return null;
    const mediaType = resp.headers.get("content-type") || "image/jpeg";
    const bytes = new Uint8Array(await resp.arrayBuffer());
    // Chunk the conversion so large images don't blow the call stack on btoa/String.fromCharCode.
    let binary = "";
    const chunkSize = 8192;
    for (let i = 0; i < bytes.length; i += chunkSize) {
      binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
    }
    return { data: btoa(binary), mediaType };
  } catch (_error) {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Only POST requests are allowed." }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json({ success: false, error: "Authentication required." }, 401);

    const token = authHeader.replace("Bearer ", "");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY");
    const model = Deno.env.get("ANTHROPIC_MODEL") || DEFAULT_MODEL;

    if (!supabaseUrl || !serviceRoleKey || !anthropicApiKey) {
      return json({ success: false, error: "Camera AI service is not configured." }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData.user) return json({ success: false, error: "Invalid authentication." }, 401);

    const body = await req.json();
    const eventType = typeof body?.event_type === "string" ? body.event_type : "observation";
    const data = body?.data && typeof body.data === "object" ? body.data : {};
    const cameraId = body?.camera_id?.toString();
    const eventId = body?.event_id?.toString();

    let businessId: string | null = null;
    if (cameraId) {
      const { data: camera } = await admin
        .from("cameras")
        .select("id, business_id")
        .eq("id", cameraId)
        .maybeSingle();
      businessId = camera?.business_id ?? null;
    }

    if (!businessId) {
      const { data: business } = await admin
        .from("businesses")
        .select("id")
        .eq("owner_id", userData.user.id)
        .maybeSingle();
      businessId = business?.id ?? null;
    }

    if (!businessId) return json({ success: false, error: "No business could be resolved for this request." }, 400);

    const { data: ownedBusiness } = await admin
      .from("businesses")
      .select("id")
      .eq("id", businessId)
      .eq("owner_id", userData.user.id)
      .maybeSingle();

    let authorized = !!ownedBusiness;
    if (!authorized) {
      const { data: membership } = await admin
        .from("business_members")
        .select("id")
        .eq("business_id", businessId)
        .eq("user_id", userData.user.id)
        .eq("status", "active")
        .maybeSingle();
      authorized = !!membership;
    }
    if (!authorized) return json({ success: false, error: "You do not have access to this business." }, 403);

    // Optional: analyzing one specific event. Fetch it (scoped to this
    // business) and, if the vision backend attached a snapshot, fetch that
    // image so Claude can actually look at the moment the event fired.
    let eventRow: Record<string, unknown> | null = null;
    let imageBlock: { type: "image"; source: { type: "base64"; media_type: string; data: string } } | null = null;

    if (eventId) {
      const { data: fetchedEvent } = await admin
        .from("camera_events")
        .select("id,camera_id,event_type,description,detected_object,confidence,severity,occurred_at,metadata")
        .eq("id", eventId)
        .eq("business_id", businessId)
        .maybeSingle();
      eventRow = fetchedEvent ?? null;

      const snapshotUrl = (eventRow?.metadata as Record<string, unknown> | undefined)?.snapshot_url;
      if (typeof snapshotUrl === "string" && snapshotUrl.length > 0) {
        const image = await fetchImageAsBase64(snapshotUrl);
        if (image) {
          imageBlock = {
            type: "image",
            source: { type: "base64", media_type: image.mediaType, data: image.data },
          };
        }
      }
    }

    let question: string;
    const contentBlocks: Anthropic.MessageParam["content"] = [];

    if (eventType === "question") {
      const { data: recentEvents } = await admin
        .from("camera_events")
        .select("id,camera_id,event_type,description,detected_object,confidence,severity,occurred_at,metadata")
        .eq("business_id", businessId)
        .order("occurred_at", { ascending: false })
        .limit(50);

      const { data: recentDetections } = await admin
        .from("camera_detections")
        .select("camera_id,detection_type,object_type,object_label,track_id,confidence,attributes,occurred_at")
        .eq("business_id", businessId)
        .order("occurred_at", { ascending: false })
        .limit(100);

      const context = JSON.stringify({ recent_events: recentEvents ?? [], recent_detections: recentDetections ?? [] });
      question = String(data.question ?? "Summarize recent camera activity.");
      contentBlocks.push({
        type: "text",
        text: `${question}\n\nEvidence (recent events and detections, JSON): ${context}`,
      });
    } else {
      const context = eventRow
        ? JSON.stringify(eventRow)
        : JSON.stringify({ camera_id: cameraId ?? null, event_type: eventType, data });
      question = `Analyze this camera ${eventType}. Return a concise interpretation, risk level, and recommended action.`;
      if (imageBlock) contentBlocks.push(imageBlock);
      contentBlocks.push({ type: "text", text: `${question}\n\nDetection evidence (JSON): ${context}` });
    }

    const anthropic = new Anthropic({ apiKey: anthropicApiKey });

    const message = await anthropic.messages.create({
      model,
      max_tokens: 700,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: contentBlocks }],
    });

    if (message.stop_reason === "refusal") {
      return json({ success: false, error: "The AI declined to analyze this request." }, 502);
    }

    const answer = message.content.find((block) => block.type === "text")?.text;
    if (!answer) return json({ success: false, error: "AI returned an empty response." }, 502);

    return json({
      success: true,
      answer,
      business_id: businessId,
      camera_id: cameraId ?? null,
      event_type: eventType,
      had_image: !!imageBlock,
    });
  } catch (error) {
    console.error("camera-ai error", error);
    return json({ success: false, error: "Camera AI could not process the request." }, 500);
  }
});

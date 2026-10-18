import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.2";
import { assertStaffAccess } from "../_shared/employee-access.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Supabase environment variables not configured");
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing authorization header");

    if (!authHeader.startsWith("Bearer ")) throw new Error("Invalid authentication");
    const token = authHeader.slice(7);
    const { data: { user: actor }, error: userError } = await adminClient.auth.getUser(token);
    if (userError || !actor) throw new Error("Invalid authentication");

    const body = await req.json();
    const { action, employee_id, business_id, ...params } = body;
    const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    if (!publicKey) throw new Error("Server configuration unavailable");
    const caller = createClient(supabaseUrl, publicKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    await assertStaffAccess(caller, business_id, employee_id);

    // Verify actor has permission (must be owner or manager of the business)
    const { data: business, error: bizError } = await adminClient
      .from("businesses")
      .select("id, owner_id")
      .eq("id", business_id)
      .single();

    if (bizError || !business) throw new Error("Business not found");

    // Get the target employee's user_id
    const { data: employee, error: empError } = await adminClient
        .from("employees")
        .select("user_id, name, role")
        .eq("id", employee_id)
        .eq("business_id", business_id)
        .single();

    if (empError || !employee) throw new Error("Employee not found");

    if (!employee.user_id || employee.user_id === business.owner_id || employee.role === "owner") {
      throw new Error("This employee account cannot be managed here");
    }
    if (business.owner_id !== actor.id && (employee.role === "manager" || employee.user_id === actor.id)) {
      throw new Error("Only the owner can manage manager passwords");
    }
    if (action === "reset_password") {
        const { new_password } = params;
        if (!new_password || new_password.length < 6) throw new Error("Password too short");
        await assertStaffAccess(caller, business_id, employee_id);
        // Auth-admin updates cannot participate in the database transaction.
        const { error: intentError } = await adminClient.from("audit_logs").insert({
          business_id, actor_id: actor.id, target_id: employee_id,
          action: "password_reset_requested", metadata: {},
        });
        if (intentError) throw new Error("Unable to audit password reset intent");

        const { error: resetError } = await adminClient.auth.admin.updateUserById(
            employee.user_id,
            { password: new_password }
        );

        if (resetError) throw resetError;

        const { error: auditError } = await adminClient.from("audit_logs").insert({
            business_id: business_id,
            actor_id: actor.id,
            target_id: employee_id,
            action: "password_reset",
            metadata: { employee_name: employee.name }
        });
        if (auditError) throw new Error("Password changed; audit completion requires operator recovery");

        return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    throw new Error("Invalid action");

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Employee request failed" }),
      {
        status: error instanceof Error && error.message === 'Staff administration denied' ? 403 : 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

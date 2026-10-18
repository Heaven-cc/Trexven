import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.2";
import { assertStaffAccess } from "../_shared/employee-access.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);
  let admin: any;
  let createdUserId: string | undefined;
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    if (!url || !serviceKey || !publicKey) throw new Error("Server configuration unavailable");
    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return response({ error: "Authentication required" }, 401);
    admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: { user: actor }, error: authError } = await admin.auth.getUser(authorization.slice(7));
    if (authError || !actor) return response({ error: "Invalid authentication" }, 401);
    const caller = createClient(url, publicKey, {
      global: { headers: { Authorization: authorization } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { business_id, name, email, phone, role = "employee", password } = await req.json();
    if (typeof business_id !== "string" || typeof name !== "string" || !name.trim() ||
        typeof password !== "string" || password.length < 6) throw new Error("Invalid employee details");
    if ((email != null && typeof email !== "string") || (phone != null && typeof phone !== "string")) throw new Error("Invalid contact details");
    const access = await assertStaffAccess(caller, business_id);
    const employeeRole = typeof role === "string" ? role.trim().toLowerCase() : "";
    if (!["manager", "sales_employee", "inventory_employee", "employee"].includes(employeeRole) ||
        (!access.owner && employeeRole !== "employee")) return response({ error: "Only the owner can assign employee roles" }, 403);
    const employeeEmail = email?.trim().toLowerCase() || crypto.randomUUID() + "@employees.trexven.internal";
    const { data, error } = await admin.auth.admin.createUser({
      email: employeeEmail, password, email_confirm: true,
      // Display metadata only, never authorization.
      user_metadata: { full_name: name.trim(), account_type: "employee", business_id, employee_role: employeeRole },
    });
    if (error || !data.user) throw new Error("Employee authentication creation failed");
    createdUserId = data.user.id;
    let employee: any;
    for (let attempt = 0; attempt < 8; attempt++) {
      const random = crypto.getRandomValues(new Uint32Array(1))[0];
      const code = "TRX-EMP-" + (100000 + random % 900000);
      const result = await caller.rpc("finalize_trexven_employee", {
        p_business_id: business_id, p_user_id: createdUserId, p_name: name.trim(),
        p_email: email?.trim() || null, p_phone: phone?.trim() || null,
        p_role: employeeRole, p_employee_code: code,
      });
      if (!result.error) { employee = result.data; break; }
      if (result.error.code !== "23505") throw new Error("Employee authorization or persistence failed");
    }
    if (!employee) throw new Error("Employee code allocation failed");
    // Finalized identity and its audit committed together; do not compensate
    // a committed employee merely because delivery of its response fails.
    createdUserId = undefined;
    return response({ success: true, employee_id: employee.id, employee_code: employee.employee_code,
      name: employee.name, role: employee.role, member_role: employee.role === "manager" ? "manager" : "employee", business_id });
  } catch (error) {
    if (createdUserId && admin) {
      // A timeout may hide a committed finalize RPC. Never delete a linked
      // account or compensate while persistence status is unknown.
      const persisted = await admin.from('employees').select('id').eq('user_id', createdUserId).maybeSingle();
      if (!persisted.error && !persisted.data) {
        const cleanup = await admin.auth.admin.deleteUser(createdUserId);
        if (cleanup.error) console.error("Employee Auth compensation failed; operator recovery required");
      } else console.error("Employee finalize outcome requires operator reconciliation");
    }
    console.error("CREATE EMPLOYEE FAILED", error instanceof Error ? error.message : "Request failed");
    return response({ error: "Unable to create employee" }, 400);
  }
});

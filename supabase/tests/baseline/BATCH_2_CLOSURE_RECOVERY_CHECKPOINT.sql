-- REVIEW ONLY. Recovered post-closure Batch-2 application schema, 8 October 2026.

-- No production data, Auth identities, credentials, buckets or runtime configuration.

-- Schema-only recovery checkpoint, not production migration history or an authorized staging reset.

-- Requires verified Supabase staging qysspzlfiysekvxnlzsh and a reviewed executor.

-- This is a new schema-only recovery artifact; reviewed baseline and migrations were executed separately.

BEGIN;

SET LOCAL search_path = '';

SET LOCAL check_function_bodies = false;

DO $baseline_guard$ BEGIN

 IF current_setting('trexven.staging_project_ref', true) IS DISTINCT FROM 'qysspzlfiysekvxnlzsh' THEN

   RAISE EXCEPTION 'Verified staging executor setting required';

 END IF;

 IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace

            WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p','v','m','S','f'))

 OR EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace

            WHERE n.nspname IN ('public','private')) THEN

   RAISE EXCEPTION 'Empty application schema required; never overwrite a populated database';

 END IF;

 IF pg_catalog.to_regclass('auth.users') IS NULL OR pg_catalog.to_regclass('storage.objects') IS NULL THEN

   RAISE EXCEPTION 'Managed Supabase Auth/Storage prerequisites missing';

 END IF;

 IF EXISTS (SELECT 1 FROM auth.users) THEN RAISE EXCEPTION 'Empty staging Auth required'; END IF;

END $baseline_guard$;

-- Supabase owns Auth/Storage/Vault schemas. Preserve its managed definitions.

-- Extensions are prerequisites already verified in staging; do not copy Vault values.

DO $extension_guard$ BEGIN

 IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='plpgsql' AND extversion='1.0')

 OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='pgcrypto' AND extversion='1.3')

 OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='uuid-ossp' AND extversion='1.1')

 OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='pg_stat_statements' AND extversion='1.11')

 OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='supabase_vault' AND extversion='0.3.1') THEN

   RAISE EXCEPTION 'Reviewed Supabase extension prerequisites missing or different';

 END IF;

END $extension_guard$;

CREATE SCHEMA "private" AUTHORIZATION "postgres";

-- public is the pre-existing platform schema, owned by pg_database_owner.

-- Tables first; defaults/constraints are deferred until functions and all tables exist.

DO $platform_defaults$ DECLARE actual jsonb; BEGIN
 SELECT jsonb_object_agg(d.defaclobjtype::text, (SELECT jsonb_object_agg(
  (CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_catalog.pg_get_userbyid(a.grantee) END)
  || ':' || a.privilege_type, a.is_grantable) FROM pg_catalog.aclexplode(d.defaclacl) a))
 INTO actual FROM pg_catalog.pg_default_acl d JOIN pg_catalog.pg_namespace n ON n.oid=d.defaclnamespace
 WHERE pg_catalog.pg_get_userbyid(d.defaclrole)='supabase_admin' AND n.nspname='public';
 IF actual IS DISTINCT FROM '{"S": {"postgres:SELECT": false, "postgres:UPDATE": false, "postgres:USAGE": false, "anon:SELECT": false, "anon:UPDATE": false, "anon:USAGE": false, "authenticated:SELECT": false, "authenticated:UPDATE": false, "authenticated:USAGE": false, "service_role:SELECT": false, "service_role:UPDATE": false, "service_role:USAGE": false}, "f": {"postgres:EXECUTE": false, "anon:EXECUTE": false, "authenticated:EXECUTE": false, "service_role:EXECUTE": false}, "r": {"postgres:INSERT": false, "postgres:SELECT": false, "postgres:UPDATE": false, "postgres:DELETE": false, "postgres:TRUNCATE": false, "postgres:REFERENCES": false, "postgres:TRIGGER": false, "postgres:MAINTAIN": false, "anon:INSERT": false, "anon:SELECT": false, "anon:UPDATE": false, "anon:DELETE": false, "anon:TRUNCATE": false, "anon:REFERENCES": false, "anon:TRIGGER": false, "anon:MAINTAIN": false, "authenticated:INSERT": false, "authenticated:SELECT": false, "authenticated:UPDATE": false, "authenticated:DELETE": false, "authenticated:TRUNCATE": false, "authenticated:REFERENCES": false, "authenticated:TRIGGER": false, "authenticated:MAINTAIN": false, "service_role:INSERT": false, "service_role:SELECT": false, "service_role:UPDATE": false, "service_role:DELETE": false, "service_role:TRUNCATE": false, "service_role:REFERENCES": false, "service_role:TRIGGER": false, "service_role:MAINTAIN": false}}'::jsonb THEN
   RAISE EXCEPTION 'Platform-owned default privileges differ from reviewed baseline';
 END IF;
END $platform_defaults$;

CREATE TABLE "private"."angel_request_windows" (
  "user_id" uuid NOT NULL,
  "window_start" timestamp with time zone NOT NULL,
  "requests" integer NOT NULL
) USING heap;

ALTER TABLE "private"."angel_request_windows" OWNER TO "postgres";

CREATE TABLE "private"."camera_explanation_request_windows" (
  "user_id" uuid NOT NULL,
  "window_start" timestamp with time zone NOT NULL,
  "requests" integer NOT NULL
) USING heap;

ALTER TABLE "private"."camera_explanation_request_windows" OWNER TO "postgres";

CREATE TABLE "private"."sale_requests" (
  "business_id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "request_id" uuid NOT NULL,
  "payload" jsonb NOT NULL,
  "receipt" jsonb NOT NULL,
  "branch_id" uuid
) USING heap;

ALTER TABLE "private"."sale_requests" OWNER TO "postgres";

CREATE TABLE "public"."alerts" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "alert_type" text NOT NULL,
  "title" text NOT NULL,
  "message" text NOT NULL,
  "severity" text NOT NULL,
  "source" text,
  "reference_id" uuid,
  "is_read" boolean NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."alerts" OWNER TO "postgres";

CREATE TABLE "public"."angel_conversations" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "user_id" uuid,
  "title" text,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."angel_conversations" OWNER TO "postgres";

CREATE TABLE "public"."angel_insights" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "insight_type" text NOT NULL,
  "title" text,
  "summary" text,
  "severity" text,
  "confidence" numeric,
  "source" text,
  "source_id" uuid,
  "metadata" jsonb,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."angel_insights" OWNER TO "postgres";

CREATE TABLE "public"."angel_messages" (
  "id" uuid NOT NULL,
  "conversation_id" uuid NOT NULL,
  "role" text NOT NULL,
  "content" text NOT NULL,
  "metadata" jsonb NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."angel_messages" OWNER TO "postgres";

CREATE TABLE "public"."audit_logs" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "actor_id" uuid,
  "target_id" uuid,
  "action" text NOT NULL,
  "metadata" jsonb,
  "created_at" timestamp with time zone
) USING heap;

ALTER TABLE "public"."audit_logs" OWNER TO "postgres";

CREATE TABLE "public"."branches" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "name" text NOT NULL,
  "is_active" boolean NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."branches" OWNER TO "postgres";

CREATE TABLE "public"."business_activity" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "employee_id" uuid,
  "activity_type" text NOT NULL,
  "title" text NOT NULL,
  "description" text,
  "metadata" jsonb NOT NULL,
  "severity" text NOT NULL,
  "source" text,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."business_activity" OWNER TO "postgres";

CREATE TABLE "public"."business_members" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "user_id" uuid,
  "full_name" text NOT NULL,
  "email" text,
  "phone" text,
  "role" text NOT NULL,
  "status" text NOT NULL,
  "permissions" jsonb NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."business_members" OWNER TO "postgres";

CREATE TABLE "public"."business_settings" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "settings" jsonb NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."business_settings" OWNER TO "postgres";

CREATE TABLE "public"."businesses" (
  "id" uuid NOT NULL,
  "owner_id" uuid NOT NULL,
  "business_name" text NOT NULL,
  "business_type" text NOT NULL,
  "address" text,
  "phone" text,
  "country" text NOT NULL,
  "currency" text NOT NULL,
  "logo_url" text,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL,
  "email" text,
  "website" text,
  "business_hours" jsonb,
  "timezone" text,
  "branches_enabled" boolean NOT NULL,
  "pos_writes_paused" boolean NOT NULL,
  "compatibility_branch_id" uuid
) USING heap;

ALTER TABLE "public"."businesses" OWNER TO "postgres";

CREATE TABLE "public"."camera_ai_jobs" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "camera_id" uuid NOT NULL,
  "job_type" text NOT NULL,
  "status" text NOT NULL,
  "provider" text,
  "model" text,
  "input_url" text,
  "output_metadata" jsonb NOT NULL,
  "error_message" text,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."camera_ai_jobs" OWNER TO "postgres";

CREATE TABLE "public"."camera_detections" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "camera_id" uuid NOT NULL,
  "event_id" uuid,
  "zone_id" uuid,
  "employee_id" uuid,
  "detection_type" text NOT NULL,
  "object_type" text,
  "object_label" text,
  "track_id" text,
  "confidence" numeric,
  "bounding_box" jsonb,
  "attributes" jsonb NOT NULL,
  "occurred_at" timestamp with time zone NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."camera_detections" OWNER TO "postgres";

CREATE TABLE "public"."camera_event_links" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "camera_event_id" uuid NOT NULL,
  "linked_type" text NOT NULL,
  "linked_id" uuid,
  "relationship" text NOT NULL,
  "confidence" numeric,
  "explanation" text,
  "metadata" jsonb NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."camera_event_links" OWNER TO "postgres";

CREATE TABLE "public"."camera_events" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "camera_id" uuid,
  "employee_id" uuid,
  "event_type" text NOT NULL,
  "confidence" numeric(5,4),
  "description" text,
  "detected_object" text,
  "quantity" numeric(14,3),
  "amount" numeric(14,2),
  "metadata" jsonb NOT NULL,
  "image_url" text,
  "video_url" text,
  "status" text NOT NULL,
  "occurred_at" timestamp with time zone NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "severity" text,
  "detected_at" timestamp with time zone,
  "external_event_id" text,
  "source_provider" text,
  "model_name" text,
  "raw_payload" jsonb NOT NULL,
  "reviewed_at" timestamp with time zone,
  "reviewed_by" uuid,
  "review_status" text NOT NULL
) USING heap;

ALTER TABLE "public"."camera_events" OWNER TO "postgres";

CREATE TABLE "public"."camera_health_logs" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "camera_id" uuid NOT NULL,
  "status" text NOT NULL,
  "latency_ms" integer,
  "error_message" text,
  "metadata" jsonb NOT NULL,
  "checked_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."camera_health_logs" OWNER TO "postgres";

CREATE TABLE "public"."camera_zones" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "camera_id" uuid NOT NULL,
  "name" text NOT NULL,
  "zone_type" text NOT NULL,
  "polygon" jsonb NOT NULL,
  "description" text,
  "is_active" boolean NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."camera_zones" OWNER TO "postgres";

CREATE TABLE "public"."cameras" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "name" text NOT NULL,
  "location" text,
  "camera_type" text,
  "stream_url" text,
  "status" text NOT NULL,
  "is_active" boolean NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL,
  "last_seen_at" timestamp with time zone,
  "provider" text,
  "device_id" text,
  "capabilities" jsonb NOT NULL,
  "settings" jsonb NOT NULL,
  "ai_enabled" boolean NOT NULL
) USING heap;

ALTER TABLE "public"."cameras" OWNER TO "postgres";

CREATE TABLE "public"."cash_transactions" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "employee_id" uuid,
  "transaction_type" text NOT NULL,
  "amount" numeric(14,2) NOT NULL,
  "reference_id" uuid,
  "notes" text,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."cash_transactions" OWNER TO "postgres";

CREATE TABLE "public"."employee_activity" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "employee_id" uuid,
  "camera_id" uuid,
  "activity_type" text NOT NULL,
  "description" text,
  "confidence" numeric,
  "metadata" jsonb,
  "occurred_at" timestamp with time zone NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."employee_activity" OWNER TO "postgres";

CREATE TABLE "public"."employee_branch_assignments" (
  "business_id" uuid NOT NULL,
  "employee_id" uuid NOT NULL,
  "branch_id" uuid NOT NULL,
  "is_active" boolean NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."employee_branch_assignments" OWNER TO "postgres";

CREATE TABLE "public"."employee_permissions" (
  "employee_id" uuid NOT NULL,
  "permission_id" text NOT NULL,
  "granted" boolean NOT NULL
) USING heap;

ALTER TABLE "public"."employee_permissions" OWNER TO "postgres";

CREATE TABLE "public"."employees" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "user_id" uuid,
  "name" text NOT NULL,
  "email" text,
  "phone" text,
  "role" text,
  "employee_code" text,
  "status" text NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."employees" OWNER TO "postgres";

CREATE TABLE "public"."expenses" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "employee_id" uuid,
  "category" text NOT NULL,
  "description" text,
  "amount" numeric(14,2) NOT NULL,
  "payment_method" text,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."expenses" OWNER TO "postgres";

CREATE TABLE "public"."financial_transactions" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "employee_id" uuid,
  "transaction_type" text NOT NULL,
  "category" text,
  "amount" numeric NOT NULL,
  "payment_method" text,
  "description" text,
  "reference" text,
  "transaction_date" timestamp with time zone NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."financial_transactions" OWNER TO "postgres";

CREATE TABLE "public"."inventory" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "product_id" uuid NOT NULL,
  "quantity" numeric(14,3) NOT NULL,
  "reserved_quantity" numeric(14,3) NOT NULL,
  "location" text,
  "last_counted_at" timestamp with time zone,
  "updated_at" timestamp with time zone NOT NULL,
  "branch_id" uuid
) USING heap;

ALTER TABLE "public"."inventory" OWNER TO "postgres";

CREATE TABLE "public"."inventory_movements" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "product_id" uuid NOT NULL,
  "employee_id" uuid,
  "movement_type" text NOT NULL,
  "quantity" numeric(14,3) NOT NULL,
  "previous_quantity" numeric(14,3),
  "new_quantity" numeric(14,3),
  "reference_id" uuid,
  "notes" text,
  "created_at" timestamp with time zone NOT NULL,
  "reason" text,
  "source" text,
  "branch_id" uuid
) USING heap;

ALTER TABLE "public"."inventory_movements" OWNER TO "postgres";

CREATE TABLE "public"."permissions" (
  "id" text NOT NULL,
  "description" text
) USING heap;

ALTER TABLE "public"."permissions" OWNER TO "postgres";

CREATE TABLE "public"."products" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "sku" text,
  "barcode" text,
  "name" text NOT NULL,
  "description" text,
  "category" text,
  "brand" text,
  "unit" text,
  "cost_price" numeric(14,2) NOT NULL,
  "selling_price" numeric(14,2),
  "reorder_level" numeric(14,3) NOT NULL,
  "image_url" text,
  "is_active" boolean NOT NULL,
  "created_at" timestamp with time zone NOT NULL,
  "updated_at" timestamp with time zone NOT NULL,
  "quantity" numeric,
  "low_stock_threshold" numeric,
  "supplier" text,
  "location" text,
  "active" boolean
) USING heap;

ALTER TABLE "public"."products" OWNER TO "postgres";

CREATE TABLE "public"."recordings" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "camera_id" uuid NOT NULL,
  "storage_path" text NOT NULL,
  "started_at" timestamp with time zone NOT NULL,
  "duration_seconds" numeric,
  "file_size_bytes" bigint,
  "playback_url" text,
  "status" text NOT NULL,
  "created_at" timestamp with time zone NOT NULL
) USING heap;

ALTER TABLE "public"."recordings" OWNER TO "postgres";

CREATE TABLE "public"."sale_items" (
  "id" uuid NOT NULL,
  "sale_id" uuid NOT NULL,
  "product_id" uuid,
  "product_name" text NOT NULL,
  "quantity" numeric(14,3) NOT NULL,
  "unit_price" numeric(14,2) NOT NULL,
  "discount" numeric(14,2) NOT NULL,
  "total" numeric(14,2) NOT NULL
) USING heap;

ALTER TABLE "public"."sale_items" OWNER TO "postgres";

CREATE TABLE "public"."sales" (
  "id" uuid NOT NULL,
  "business_id" uuid NOT NULL,
  "employee_id" uuid,
  "sale_number" text,
  "subtotal" numeric(14,2) NOT NULL,
  "discount" numeric(14,2) NOT NULL,
  "tax" numeric(14,2) NOT NULL,
  "total" numeric(14,2) NOT NULL,
  "payment_method" text,
  "status" text NOT NULL,
  "notes" text,
  "created_at" timestamp with time zone NOT NULL,
  "product_id" uuid,
  "quantity" numeric,
  "unit_price" numeric,
  "total_amount" numeric,
  "customer_name" text,
  "reference" text,
  "sold_at" timestamp with time zone,
  "branch_id" uuid
) USING heap;

ALTER TABLE "public"."sales" OWNER TO "postgres";

-- Preserve exact catalog function bodies/signatures; validation occurs during staging rehearsal.

CREATE OR REPLACE FUNCTION private.audit_product_price()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare before_price jsonb;
begin
 if auth.uid() is null then return new; end if;
 if tg_op='INSERT' then
   if new.selling_price is null then return new; end if;
 else
   if new.selling_price is not distinct from old.selling_price then return new; end if;
   before_price:=jsonb_build_object('selling_price',old.selling_price);
 end if;
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(new.business_id,auth.uid(),'product_price_changed',jsonb_build_object('product_id',new.id,
 'before',before_price,
 'after',jsonb_build_object('selling_price',new.selling_price)));
 return new;
end $function$;

ALTER FUNCTION "private"."audit_product_price"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.branch_record_access(business uuid, branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select public.user_owns_business(business) or (public.is_business_member(business) and
 (case when branch is not null then private.has_branch_access(business,branch)
 else exists(select 1 from public.businesses where id=business and not branches_enabled) end))
$function$;

ALTER FUNCTION "private"."branch_record_access"(business uuid, branch uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.business_timestamp()
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select current_timestamp
$function$;

ALTER FUNCTION "private"."business_timestamp"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.can_read_membership(business uuid, member_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select public.user_owns_business(business) or member_user=auth.uid() or
 exists(select 1 from public.employees e where e.business_id=business and e.user_id=member_user
        and private.can_read_staff(e.business_id,e.id))
$function$;

ALTER FUNCTION "private"."can_read_membership"(business uuid, member_user uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.can_read_staff(business uuid, employee uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select public.user_owns_business(business) or exists(select 1 from public.employees e
 where e.id=employee and e.business_id=business and public.is_business_member(business) and
 (e.user_id=auth.uid() or (e.role not in ('owner','manager') and private.has_business_permission(business,'manage_employees') and
 (exists(select 1 from public.businesses b where b.id=business and not b.branches_enabled) or
 (exists(select 1 from public.employee_branch_assignments a where a.employee_id=e.id and a.is_active) and
 not exists(select 1 from public.employee_branch_assignments a where a.employee_id=e.id and a.is_active and not private.has_branch_access(business,a.branch_id)))))))
$function$;

ALTER FUNCTION "private"."can_read_staff"(business uuid, employee uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.complete_pos_sale(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin perform private.complete_pos_sale_with_receipt(p_business_id,p_employee_id,p_total,p_payment_method,p_items); end $function$;

ALTER FUNCTION "private"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.complete_pos_sale_with_receipt(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb)
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select private.process_trexven_sale(p_business_id,p_employee_id,p_total,p_payment_method,p_items,false,null)
$function$;

ALTER FUNCTION "private"."complete_pos_sale_with_receipt"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.consume_camera_explanation_request(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare request_count integer; begin
 if p_user_id is null then return false; end if;
 insert into private.camera_explanation_request_windows as w values(p_user_id,clock_timestamp(),1)
 on conflict(user_id) do update set
 requests=case when w.window_start<clock_timestamp()-interval '1 minute' then 1 else w.requests+1 end,
 window_start=case when w.window_start<clock_timestamp()-interval '1 minute' then clock_timestamp() else w.window_start end
 returning requests into request_count;
 return request_count<=20;
end $function$;

ALTER FUNCTION "private"."consume_camera_explanation_request"(p_user_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.guard_business_foundation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.timezone is not null and not exists(select 1 from pg_catalog.pg_timezone_names where name=new.timezone) then
 raise exception 'Invalid business timezone'; end if;
 if auth.uid() is not null then
   if tg_op='INSERT' then
     if new.owner_id is distinct from auth.uid() or new.branches_enabled or new.pos_writes_paused or new.compatibility_branch_id is not null then
       raise exception 'Business identity/activation requires reviewed migration' using errcode='42501'; end if;
   elsif new.owner_id is distinct from old.owner_id or new.branches_enabled is distinct from old.branches_enabled
     or new.pos_writes_paused is distinct from old.pos_writes_paused
     or new.compatibility_branch_id is distinct from old.compatibility_branch_id then
     raise exception 'Business identity/activation requires reviewed migration' using errcode='42501'; end if;
 end if;
 return new;
end $function$;

ALTER FUNCTION "private"."guard_business_foundation"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.guard_legacy_stock()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if tg_op='INSERT' then
   if coalesce(new.quantity,0)=0 then return new; end if;
 else
   if new.quantity is not distinct from old.quantity then return new; end if;
 end if;
 if exists(select 1 from public.businesses where id=new.business_id and branches_enabled) then
   raise exception 'Activated stock requires branch context' using errcode='42501'; end if;
 return new;
end $function$;

ALTER FUNCTION "private"."guard_legacy_stock"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.guard_price_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if not (auth.uid() is null and current_user in ('postgres','supabase_admin','service_role'))
 and not public.user_owns_business(old.business_id)
 and not private.has_business_permission(old.business_id,'override_price') then
   raise exception 'Price permission denied' using errcode='42501'; end if;
 return new;
end $function$;

ALTER FUNCTION "private"."guard_price_assignment"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.guard_product_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare can_price boolean; maintenance boolean;
begin
 maintenance:=auth.uid() is null and current_user in ('postgres','supabase_admin','service_role');
 can_price:=maintenance or (public.user_owns_business(new.business_id)
   or private.has_business_permission(new.business_id,'override_price'));
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.business_id is distinct from old.business_id) then
   raise exception 'Product identity is immutable' using errcode='42501'; end if;
 if tg_op='INSERT' then
   if not maintenance and coalesce(new.quantity,0)<>0 and not private.has_business_permission(new.business_id,'adjust_stock') then
     raise exception 'Stock adjustment permission required' using errcode='42501'; end if;
   if not can_price and new.selling_price is not null then
     raise exception 'Price permission denied' using errcode='42501'; end if;
 else
   -- Direct client stock edits require stock authority; validated transaction
   -- cores run as their trusted definer and check complete_sales themselves.
   if current_user='authenticated' and new.quantity is distinct from old.quantity
   and not private.has_business_permission(new.business_id,'adjust_stock') then
     raise exception 'Stock adjustment permission required' using errcode='42501'; end if;
   if not can_price and (to_jsonb(new)-array['name','barcode','sku','brand','category','description','image_url','unit','supplier','location','reorder_level','low_stock_threshold','quantity','active','is_active','updated_at'])
     is distinct from (to_jsonb(old)-array['name','barcode','sku','brand','category','description','image_url','unit','supplier','location','reorder_level','low_stock_threshold','quantity','active','is_active','updated_at']) then
     raise exception 'Only permitted non-price product fields may change' using errcode='42501'; end if;
   if not can_price and (new.selling_price is distinct from old.selling_price) then
     raise exception 'Price permission denied' using errcode='42501'; end if;
 end if;
 if new.selling_price is not null and (new.selling_price<0 or new.selling_price::text in ('NaN','Infinity','-Infinity')) then
   raise exception 'Invalid selling price'; end if;
 if new.selling_price is null then new.active:=false; new.is_active:=false; end if;
 return new;
end $function$;

ALTER FUNCTION "private"."guard_product_fields"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.guard_sale_item_product()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare business uuid; p public.products%rowtype;
begin
 if auth.uid() is null then
   if session_user in ('postgres','supabase_admin') then return new; end if;
   raise exception 'Sale authorization required' using errcode='42501';
 end if;
 select business_id into business from public.sales where id=new.sale_id;
 if not private.has_business_permission(business,'complete_sales') or not private.has_business_permission(business,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 select * into p from public.products where id=new.product_id and business_id=business;
 if not found or p.selling_price is null or p.is_active is not true or p.active is false
 or new.unit_price is distinct from p.selling_price then raise exception 'Product is pending, inactive or price changed'; end if;
 if coalesce(new.discount,0)>0 and not private.has_business_permission(business,'apply_discount') then
 raise exception 'Discount permission denied' using errcode='42501'; end if;
 return new;
end $function$;

ALTER FUNCTION "private"."guard_sale_item_product"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.guard_staff_scope()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if auth.uid() is not null and not public.user_owns_business(old.business_id) then
   perform public.assert_trexven_staff_access(old.business_id,old.id);
   if new.id is distinct from old.id or new.user_id is distinct from old.user_id
   or new.business_id is distinct from old.business_id or new.role is distinct from old.role then
     raise exception 'Staff identity/role is immutable for managers' using errcode='42501'; end if;
 end if;
 return new;
end $function$;

ALTER FUNCTION "private"."guard_staff_scope"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.has_branch_access(business uuid, branch uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select auth.uid() is not null and exists(select 1 from public.branches b
 where b.id=branch and b.business_id=business and b.is_active and (
 public.user_owns_business(business) or (public.is_business_member(business) and exists(
 select 1 from public.employee_branch_assignments a join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
 where a.business_id=business and a.branch_id=branch and a.is_active and e.user_id=auth.uid() and e.status='active'))))
$function$;

ALTER FUNCTION "private"."has_branch_access"(business uuid, branch uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.has_business_permission(business uuid, permission text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select auth.uid() is not null and permission is not null and permission <> 'view_profit' and (
 public.user_owns_business(business) or exists(
 select 1 from public.employees e join public.business_members m
 on m.business_id=e.business_id and m.user_id=e.user_id
 where e.business_id=business and e.user_id=auth.uid()
 and e.status='active' and m.status='active'
 and e.role in ('manager','sales_employee','inventory_employee','employee')
 -- Owner-only services and role/permission administration are never delegable.
 and permission not in ('view_camera_events','manage_permissions','assign_roles','owner_app')
 and (permission not in ('override_price','edit_prices','change_prices','manage_prices','set_prices','branch_price_override')
      or e.role='manager')
 and (permission<>'apply_discount' or e.role<>'inventory_employee')
 and (permission<>'manage_employees' or e.role='manager')
 and (permission not in ('view_finance') or e.role='manager')
 and not exists(select 1 from public.employee_permissions denied where denied.employee_id=e.id
                and denied.permission_id=permission and not denied.granted)
 and (exists(select 1 from public.employee_permissions p join public.permissions d on d.id=p.permission_id
             where p.employee_id=e.id and p.permission_id=permission and p.granted)
 or (e.role='manager' and permission in ('pos_access','complete_sales','view_inventory','add_products','edit_products','manage_employees','adjust_stock'))
 or (e.role='sales_employee' and permission in ('pos_access','complete_sales','view_inventory'))
 or (e.role='inventory_employee' and permission in ('view_inventory','add_products','edit_products')))))
$function$;

ALTER FUNCTION "private"."has_business_permission"(business uuid, permission text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.process_trexven_sale(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.businesses%rowtype; item jsonb; product public.products%rowtype;
 member uuid; sale uuid; branch uuid; qty integer; price numeric; v_discount numeric; v_total numeric:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into b from public.businesses where id=p_business_id for share;
 if not found then raise exception 'Business access denied' using errcode='42501'; end if;
 if b.pos_writes_paused then raise exception 'Sale writes are temporarily paused for recovery.' using errcode='42501'; end if;
 -- Lock trusted authorization rows so revocation is ordered against the sale.
 perform id from public.employees where business_id=b.id and user_id=auth.uid() for share;
 select id into member from public.business_members where business_id=b.id and user_id=auth.uid() and status='active' for share;
 if not public.is_business_member(b.id) or not private.has_business_permission(b.id,'complete_sales')
 or not private.has_business_permission(b.id,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 if p_quick is null or (not p_quick and p_employee_id is distinct from member)
 or (p_quick and p_employee_id is not null) then raise exception 'Employee does not match session' using errcode='42501'; end if;
 if p_payment_method is null or p_payment_method not in ('cash','card','bank_transfer','mobile_money','other') then raise exception 'Invalid payment method'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Items required'; end if;
 if p_quick and jsonb_array_length(p_items)<>1 then raise exception 'Invalid quick sale'; end if;
 branch:=p_branch_id;
 if b.branches_enabled then
   if branch is null then
     branch:=b.compatibility_branch_id;
     if not public.user_owns_business(b.id) and (select count(*) from public.employee_branch_assignments a
       join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
       join public.branches br on br.id=a.branch_id and br.business_id=a.business_id
       where a.business_id=b.id and e.user_id=auth.uid() and a.is_active and br.is_active)<>1 then
       raise exception 'Explicit branch context required' using errcode='42501'; end if;
   end if;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
   perform id from public.branches where id=branch and business_id=b.id and is_active for share;
   perform a.employee_id from public.employee_branch_assignments a join public.employees e on e.id=a.employee_id
     where a.branch_id=branch and a.business_id=b.id and e.user_id=auth.uid() and a.is_active for share of a;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
 elsif branch is not null then
   raise exception 'Branch operations not activated' using errcode='42501';
 end if;
 perform id from public.products where business_id=b.id and id in
 (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by id for update;
 if branch is not null then
   perform product_id from public.inventory where business_id=b.id and branch_id=branch and product_id in
   (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by product_id for update;
 end if;
 insert into public.sales(business_id,employee_id,total,payment_method,status,branch_id)
 values(b.id,member,0,p_payment_method,'completed',branch) returning id into sale;
 for item in select * from jsonb_array_elements(p_items) loop
   qty:=(item->>'quantity')::integer; price:=(item->>'unit_price')::numeric;
   v_discount:=coalesce((item->>'discount')::numeric,0);
   if qty is null or qty<=0 or price is null or price<0 or price::text in ('NaN','Infinity','-Infinity')
   or v_discount::text in ('NaN','Infinity','-Infinity') or v_discount<0 or v_discount>qty*price then raise exception 'Invalid sale item'; end if;
   if v_discount>0 and (p_quick or not private.has_business_permission(b.id,'apply_discount')) then
     raise exception 'Discount permission denied' using errcode='42501'; end if;
   select * into product from public.products where id=(item->>'product_id')::uuid and business_id=b.id;
   if not found then raise exception 'Product not found in this business'; end if;
   if product.selling_price is null or product.is_active is not true or product.active is false then
     raise exception 'Product is pending or inactive'; end if;
   if price is distinct from product.selling_price then raise exception 'Product price changed'; end if;
   if branch is null then
     if coalesce(product.quantity,0)<qty then raise exception 'Insufficient stock'; end if;
     update public.products set quantity=quantity-qty where id=product.id and business_id=b.id;
   else
     update public.inventory set quantity=quantity-qty where business_id=b.id and branch_id=branch and product_id=product.id
       and quantity-coalesce(reserved_quantity,0)>=qty;
     if not found then raise exception 'Insufficient branch stock'; end if;
   end if;
   insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total)
   values(sale,product.id,product.name,qty,price,v_discount,qty*price-v_discount);
   v_total:=v_total+qty*price-v_discount;
 end loop;
 if v_total is distinct from p_total then raise exception 'Sale total does not match items'; end if;
 update public.sales set total=v_total,total_amount=v_total,
 subtotal=(select sum(quantity*unit_price) from public.sale_items where sale_id=sale),
 discount=(select sum(i.discount) from public.sale_items i where i.sale_id=sale) where id=sale;
 -- Preserve the legacy single-product quick-sale columns.
 if p_quick then update public.sales set product_id=product.id,quantity=qty,unit_price=price where id=sale; end if;
 return sale;
end $function$;

ALTER FUNCTION "private"."process_trexven_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.record_trexven_sale(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric)
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select private.process_trexven_sale(p_business_id,null,p_quantity*p_unit_price,'cash',
 jsonb_build_array(jsonb_build_object('product_id',p_product_id,'quantity',p_quantity,'unit_price',p_unit_price,'discount',0)),true,null)
$function$;

ALTER FUNCTION "private"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.sales_history_access(business uuid, sold_at timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select public.user_owns_business(business) or (private.has_business_permission(business,'pos_access') and
 (private.has_business_permission(business,'view_finance') or exists(select 1 from public.businesses b
 join pg_catalog.pg_timezone_names tz on tz.name=b.timezone where b.id=business
 and (sold_at at time zone b.timezone)::date=(private.business_timestamp() at time zone b.timezone)::date)))
$function$;

ALTER FUNCTION "private"."sales_history_access"(business uuid, sold_at timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.submit_sale_request(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare payload jsonb; saved private.sale_requests%rowtype; sale uuid; receipt jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform id from public.businesses where id=p_business_id for share;
 perform id from public.employees where business_id=p_business_id and user_id=auth.uid() for share;
 perform id from public.business_members where business_id=p_business_id and user_id=auth.uid() for share;
 if auth.uid() is null or not public.is_business_member(p_business_id) or not private.has_business_permission(p_business_id,'complete_sales')
 or not private.has_business_permission(p_business_id,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 if p_request_id is null or p_quick is null then raise exception 'Sale request ID and type required'; end if;
 payload:=jsonb_build_object('employee',p_employee_id,'total',p_total,'payment',p_payment_method,'items',p_items,'quick',p_quick);
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 select * into saved from private.sale_requests where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 if found then
   if saved.branch_id is null and not public.user_owns_business(p_business_id)
   and exists(select 1 from public.businesses where id=p_business_id and branches_enabled) then
     raise exception 'Legacy receipt has no verified branch mapping. Ask the owner to review the saved sale.' using errcode='42501'; end if;
   if saved.payload is distinct from payload or (p_branch_id is not null and saved.branch_id is distinct from p_branch_id) then
     raise exception 'This sale was already submitted with different details. Review its receipt before starting another sale.'; end if;
   if saved.branch_id is not null and not private.has_branch_access(p_business_id,saved.branch_id) then
     raise exception 'Branch access denied' using errcode='42501'; end if;
   return saved.receipt;
 end if;
 sale:=private.process_trexven_sale(p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick,p_branch_id);
 update public.sales set sale_number='TRX-'||sale::text where id=sale;
 select (case when s.branch_id is null then to_jsonb(s)-'branch_id' else to_jsonb(s) end)||jsonb_build_object('sale_items',
 (select jsonb_agg(to_jsonb(i) order by i.id) from public.sale_items i where i.sale_id=sale)) into receipt from public.sales s where s.id=sale;
 insert into private.sale_requests(business_id,user_id,request_id,payload,receipt,branch_id)
 select p_business_id,auth.uid(),p_request_id,payload,receipt,s.branch_id from public.sales s where s.id=sale;
 return receipt;
end $function$;

ALTER FUNCTION "private"."submit_sale_request"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION private.submit_trexven_sale(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select private.submit_sale_request(p_request_id,p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick,null)
$function$;

ALTER FUNCTION "private"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.angel_sales_summary(p_business_id uuid, p_day_start timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select jsonb_build_object('sales_count_30d',count(*),
   'revenue_30d',coalesce(sum(coalesce(total,total_amount,0)),0),
   'sales_count_today',count(*) filter(where created_at>=p_day_start and created_at<p_day_start+interval '1 day'),
   'revenue_today',coalesce(sum(coalesce(total,total_amount,0)) filter(where created_at>=p_day_start and created_at<p_day_start+interval '1 day'),0))
 from public.sales where business_id=p_business_id and status='completed'
 and created_at>=now()-interval '30 days'
$function$;

ALTER FUNCTION "public"."angel_sales_summary"(p_business_id uuid, p_day_start timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.assert_trexven_staff_access(p_business_id uuid, p_employee_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype; owned boolean;
begin
 owned:=public.user_owns_business(p_business_id);
 if auth.uid() is null or (not owned and not private.has_business_permission(p_business_id,'manage_employees')) then
 raise exception 'Staff administration denied' using errcode='42501'; end if;
 if p_employee_id is not null then
   select * into e from public.employees where id=p_employee_id and business_id=p_business_id;
   if not found or e.role='owner' or exists(select 1 from public.businesses where id=p_business_id and owner_id=e.user_id)
   or (not owned and (e.role='manager' or e.user_id=auth.uid())) then
   raise exception 'Staff administration denied' using errcode='42501'; end if;
   if not owned and exists(select 1 from public.businesses where id=p_business_id and branches_enabled) and (
   not exists(select 1 from public.employee_branch_assignments where employee_id=e.id and is_active)
   or exists(select 1 from public.employee_branch_assignments a where a.employee_id=e.id and a.is_active
             and not private.has_branch_access(p_business_id,a.branch_id))) then
     raise exception 'Staff branch scope denied' using errcode='42501'; end if;
 end if;
 return jsonb_build_object('owner',owned);
end $function$;

ALTER FUNCTION "public"."assert_trexven_staff_access"(p_business_id uuid, p_employee_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.camera_event_to_alert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.severity in ('warning', 'high', 'critical') then
    insert into public.alerts(
      business_id,
      alert_type,
      title,
      message,
      severity,
      source,
      reference_id
    ) values (
      new.business_id,
      new.event_type,
      coalesce(new.event_type, 'AI Event'),
      coalesce(new.description, 'AI detected an event on your camera.'),
      new.severity,
      'camera_ai',
      new.id
    );
  end if;
  return new;
end;
$function$;

ALTER FUNCTION "public"."camera_event_to_alert"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.complete_pos_sale(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb)
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$
select private.complete_pos_sale(p_business_id,p_employee_id,p_total,p_payment_method,p_items)
$function$;

ALTER FUNCTION "public"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.complete_trexven_onboarding(p_business_name text, p_business_type text, p_country text, p_currency text, p_address text DEFAULT NULL::text, p_phone text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_user uuid := auth.uid(); v_business uuid; v_name text; v_email text;
begin
 if v_user is null then raise exception 'Authentication required' using errcode = '42501'; end if;
 if nullif(trim(p_business_name),'') is null or nullif(trim(p_business_type),'') is null
 or nullif(trim(p_country),'') is null or nullif(trim(p_currency),'') is null then
   raise exception 'Complete all required business fields';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
 select id into v_business from public.businesses where owner_id = v_user order by created_at limit 1;
 if v_business is null and exists(select 1 from public.business_members where user_id = v_user) then
   raise exception 'This account is already associated with a business' using errcode = '42501';
 end if;
 if v_business is null then
   insert into public.businesses(owner_id,business_name,business_type,country,currency,address,phone)
   values(v_user,trim(p_business_name),p_business_type,p_country,p_currency,p_address,p_phone)
   returning id into v_business;
 else
   update public.businesses set business_name=trim(p_business_name),business_type=p_business_type,
   country=p_country,currency=p_currency,address=p_address,phone=p_phone where id=v_business;
 end if;
 select coalesce(nullif(raw_user_meta_data->>'full_name',''),nullif(raw_user_meta_data->>'name',''),'Owner'),email
 into v_name,v_email from auth.users where id=v_user;
 insert into public.business_members(business_id,user_id,full_name,email,role,status)
 values(v_business,v_user,v_name,v_email,'owner','active')
 on conflict(business_id,user_id) do update set full_name=excluded.full_name,role='owner',status='active';
 return v_business;
end;
$function$;

ALTER FUNCTION "public"."complete_trexven_onboarding"(p_business_name text, p_business_type text, p_country text, p_currency text, p_address text, p_phone text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.consume_angel_request(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare count integer; begin
 insert into private.angel_request_windows as w values(p_user_id,clock_timestamp(),1)
 on conflict(user_id) do update set
 requests=case when w.window_start<clock_timestamp()-interval '1 minute' then 1 else w.requests+1 end,
 window_start=case when w.window_start<clock_timestamp()-interval '1 minute' then clock_timestamp() else w.window_start end
 returning requests into count;
 return count<=20;
end $function$;

ALTER FUNCTION "public"."consume_angel_request"(p_user_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.consume_camera_explanation_request(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 SET search_path TO ''
AS $function$
select private.consume_camera_explanation_request(p_user_id)
$function$;

ALTER FUNCTION "public"."consume_camera_explanation_request"(p_user_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.create_trexven_branch(p_business_id uuid, p_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result uuid; begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501'; end if;
 insert into public.branches(business_id,name) values(p_business_id,trim(p_name)) returning id into result;
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'branch_created',jsonb_build_object('branch_id',result));
 return result;
end $function$;

ALTER FUNCTION "public"."create_trexven_branch"(p_business_id uuid, p_name text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.finalize_trexven_employee(p_business_id uuid, p_user_id uuid, p_name text, p_email text, p_phone text, p_role text, p_employee_code text)
 RETURNS public.employees
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare access jsonb; e public.employees%rowtype;
begin
 access:=public.assert_trexven_staff_access(p_business_id,null);
 if p_role is null or p_role not in ('manager','sales_employee','inventory_employee','employee')
 or (not (access->>'owner')::boolean and p_role<>'employee') or nullif(trim(p_name),'') is null then
 raise exception 'Owner role assignment required' using errcode='42501'; end if;
 perform id from auth.users where id=p_user_id for update;
 if not found or exists(select 1 from public.businesses where owner_id=p_user_id)
 or exists(select 1 from public.employees where user_id=p_user_id)
 or exists(select 1 from public.business_members where user_id=p_user_id) then
 raise exception 'Employee identity unavailable' using errcode='42501'; end if;
 insert into public.employees(business_id,user_id,name,email,phone,role,employee_code,status)
 values(p_business_id,p_user_id,trim(p_name),p_email,p_phone,p_role,p_employee_code,'active') returning * into e;
 insert into public.business_members(business_id,user_id,full_name,email,phone,role,status,permissions)
 values(p_business_id,p_user_id,e.name,p_email,p_phone,case when p_role='manager' then 'manager' else 'employee' end,'active','{}');
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(p_business_id,auth.uid(),e.id,'employee_created',jsonb_build_object('role',p_role,'employee_code',p_employee_code));
 return e;
end $function$;

ALTER FUNCTION "public"."finalize_trexven_employee"(p_business_id uuid, p_user_id uuid, p_name text, p_email text, p_phone text, p_role text, p_employee_code text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.get_camera_activity_summary(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS TABLE(event_type text, event_count bigint, high_severity_count bigint, average_confidence numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select
    e.event_type,
    count(*) as event_count,
    count(*) filter (where e.severity in ('high','critical')) as high_severity_count,
    round(avg(e.confidence), 4) as average_confidence
  from public.camera_events e
  where e.business_id = p_business_id
    and e.occurred_at >= p_from
    and e.occurred_at < p_to
  group by e.event_type
  order by event_count desc;
$function$;

ALTER FUNCTION "public"."get_camera_activity_summary"(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.get_camera_dashboard(p_business_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'cameras', coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from public.cameras c where c.business_id = p_business_id and c.is_active = true), '[]'::jsonb),
    'recent_events', coalesce((select jsonb_agg(to_jsonb(e) order by e.occurred_at desc) from (select * from public.camera_events where business_id = p_business_id order by occurred_at desc limit 50) e), '[]'::jsonb),
    'recent_detections', coalesce((select jsonb_agg(to_jsonb(d) order by d.occurred_at desc) from (select * from public.camera_detections where business_id = p_business_id order by occurred_at desc limit 100) d), '[]'::jsonb)
  );
$function$;

ALTER FUNCTION "public"."get_camera_dashboard"(p_business_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.get_trexven_business_day(p_business_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare zone text; local_date date;
begin
 if auth.uid() is null or not (public.user_owns_business(p_business_id)
  or private.has_business_permission(p_business_id,'pos_access')) then
   raise exception 'Business access denied' using errcode='42501';
 end if;
 select b.timezone into zone from public.businesses b
 join pg_catalog.pg_timezone_names tz on tz.name=b.timezone where b.id=p_business_id;
 if zone is null then raise exception 'Configure a valid business timezone before requesting daily sales'; end if;
 local_date := (private.business_timestamp() at time zone zone)::date;
 return jsonb_build_object('timezone',zone,'local_date',local_date,
  'starts_at',local_date::timestamp at time zone zone,
  'ends_at',(local_date+1)::timestamp at time zone zone);
end $function$;

ALTER FUNCTION "public"."get_trexven_business_day"(p_business_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.is_business_member(target_business_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select auth.uid() is not null and (public.user_owns_business(target_business_id)
 or exists(select 1 from public.business_members m join public.employees e
 on e.business_id=m.business_id and e.user_id=m.user_id
 where m.business_id=target_business_id and m.user_id=auth.uid()
 and m.status='active' and e.status='active'
 and e.role in ('manager','sales_employee','inventory_employee','employee')))
$function$;

ALTER FUNCTION "public"."is_business_member"(target_business_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.record_trexven_sale(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric)
 RETURNS uuid
 LANGUAGE sql
 SET search_path TO ''
AS $function$
select private.record_trexven_sale(p_business_id,p_product_id,p_quantity,p_unit_price)
$function$;

ALTER FUNCTION "public"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.set_trexven_branch_assignment(p_employee_id uuid, p_branch_id uuid, p_active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype; begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found or not public.user_owns_business(e.business_id) or p_active is null then
 raise exception 'Owner required' using errcode='42501'; end if;
 if not exists(select 1 from public.branches where id=p_branch_id and business_id=e.business_id and (is_active or not p_active)) then
 raise exception 'Invalid branch' using errcode='42501'; end if;
 insert into public.employee_branch_assignments(business_id,employee_id,branch_id,is_active)
 values(e.business_id,e.id,p_branch_id,p_active) on conflict(employee_id,branch_id) do update set is_active=excluded.is_active;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'branch_assignment_changed',jsonb_build_object('branch_id',p_branch_id,'active',p_active));
end $function$;

ALTER FUNCTION "public"."set_trexven_branch_assignment"(p_employee_id uuid, p_branch_id uuid, p_active boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.set_trexven_branch_status(p_branch_id uuid, p_active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b public.branches%rowtype; begin
 select * into b from public.branches where id=p_branch_id for update;
 if not found or p_active is null or not public.user_owns_business(b.business_id) then
 raise exception 'Owner required' using errcode='42501'; end if;
 update public.branches set is_active=p_active,updated_at=now() where id=b.id;
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(b.business_id,auth.uid(),'branch_status_changed',jsonb_build_object('branch_id',b.id,'active',p_active));
end $function$;

ALTER FUNCTION "public"."set_trexven_branch_status"(p_branch_id uuid, p_active boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.set_trexven_employee_permission(p_employee_id uuid, p_permission text, p_granted boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype;
begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found or not public.user_owns_business(e.business_id) then
   raise exception 'Owner permission required' using errcode='42501'; end if;
 if e.role='owner' or e.user_id=auth.uid() or p_granted is null
 or not exists(select 1 from public.permissions where id=p_permission)
 or p_permission in ('view_camera_events','manage_permissions','assign_roles','owner_app','view_profit') then
   raise exception 'Invalid employee permission' using errcode='42501'; end if;
 if p_granted and ((p_permission in ('override_price','edit_prices','change_prices','manage_prices','set_prices','branch_price_override','view_finance') and e.role<>'manager')
 or (p_permission='apply_discount' and e.role='inventory_employee')) then
   raise exception 'Permission forbidden for employee role' using errcode='42501'; end if;
 insert into public.employee_permissions(employee_id,permission_id,granted) values(e.id,p_permission,p_granted)
 on conflict(employee_id,permission_id) do update set granted=excluded.granted;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'employee_permission_changed',jsonb_build_object('permission',p_permission,'granted',p_granted));
end $function$;

ALTER FUNCTION "public"."set_trexven_employee_permission"(p_employee_id uuid, p_permission text, p_granted boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.set_trexven_employee_status(p_employee_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype;
begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found then raise exception 'Employee not found'; end if;
 perform public.update_trexven_employee(e.id,e.name,e.phone,e.email,e.role,p_status);
end;
$function$;

ALTER FUNCTION "public"."set_trexven_employee_status"(p_employee_id uuid, p_status text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.submit_trexven_branch_sale(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if p_branch_id is null or not private.has_branch_access(p_business_id,p_branch_id) then
 raise exception 'Branch access denied' using errcode='42501'; end if;
 return private.submit_sale_request(p_request_id,p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick,p_branch_id);
end $function$;

ALTER FUNCTION "public"."submit_trexven_branch_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.submit_trexven_sale(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select private.submit_trexven_sale(p_request_id,p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick)
$function$;

ALTER FUNCTION "public"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.update_businesses_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

ALTER FUNCTION "public"."update_businesses_updated_at"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.update_trexven_employee(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype; owner_actor boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into e from public.employees where id=p_employee_id for update;
 if not found then raise exception 'Employee access denied' using errcode='42501'; end if;
 owner_actor:=public.user_owns_business(e.business_id);
 if not owner_actor and not private.has_business_permission(e.business_id,'manage_employees') then
   raise exception 'Employee access denied' using errcode='42501'; end if;
 if e.role='owner' or exists(select 1 from public.businesses where id=e.business_id and owner_id=e.user_id)
 or (not owner_actor and (e.role='manager' or e.user_id=auth.uid() or p_role is distinct from e.role)) then
   raise exception 'Owner role administration required' using errcode='42501'; end if;
 if p_role is null or p_role not in ('manager','sales_employee','inventory_employee','employee')
 or p_status is null or p_status not in ('active','suspended','inactive','terminated')
 or nullif(trim(p_name),'') is null then raise exception 'Invalid employee details'; end if;
 update public.employees set name=trim(p_name),phone=p_phone,email=p_email,role=p_role,status=p_status,updated_at=now() where id=e.id;
 update public.business_members set full_name=trim(p_name),phone=p_phone,email=p_email,
 role=case when p_role='manager' then 'manager' else 'employee' end,
 status=case when p_status='terminated' then 'inactive' else p_status end where business_id=e.business_id and user_id=e.user_id;
 if e.user_id is not null and not found then raise exception 'Employee membership missing'; end if;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'employee_updated',jsonb_build_object('old_role',e.role,'role',p_role,'status',p_status));
end $function$;

ALTER FUNCTION "public"."update_trexven_employee"(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$;

ALTER FUNCTION "public"."update_updated_at"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION public.user_owns_business(target_business_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    select exists (
        select 1
        from public.businesses
        where id = target_business_id
        and owner_id = auth.uid()
    );
$function$;

ALTER FUNCTION "public"."user_owns_business"(target_business_id uuid) OWNER TO "postgres";

ALTER TABLE "public"."alerts" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."alerts" ALTER COLUMN "severity" SET DEFAULT 'info'::text;

ALTER TABLE "public"."alerts" ALTER COLUMN "source" SET DEFAULT 'system'::text;

ALTER TABLE "public"."alerts" ALTER COLUMN "is_read" SET DEFAULT false;

ALTER TABLE "public"."alerts" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."angel_conversations" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."angel_conversations" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."angel_conversations" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."angel_insights" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."angel_insights" ALTER COLUMN "severity" SET DEFAULT 'info'::text;

ALTER TABLE "public"."angel_insights" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."angel_insights" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."angel_messages" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."angel_messages" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."angel_messages" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."audit_logs" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."audit_logs" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."audit_logs" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."business_activity" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."business_activity" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."business_activity" ALTER COLUMN "severity" SET DEFAULT 'normal'::text;

ALTER TABLE "public"."business_activity" ALTER COLUMN "source" SET DEFAULT 'system'::text;

ALTER TABLE "public"."business_activity" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."business_members" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."business_members" ALTER COLUMN "role" SET DEFAULT 'employee'::text;

ALTER TABLE "public"."business_members" ALTER COLUMN "status" SET DEFAULT 'active'::text;

ALTER TABLE "public"."business_members" ALTER COLUMN "permissions" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."business_members" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."business_members" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."business_settings" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."business_settings" ALTER COLUMN "settings" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."business_settings" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."business_settings" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."businesses" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."businesses" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."businesses" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."businesses" ALTER COLUMN "branches_enabled" SET DEFAULT false;

ALTER TABLE "public"."businesses" ALTER COLUMN "pos_writes_paused" SET DEFAULT false;

ALTER TABLE "public"."camera_ai_jobs" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."camera_ai_jobs" ALTER COLUMN "job_type" SET DEFAULT 'analyze'::text;

ALTER TABLE "public"."camera_ai_jobs" ALTER COLUMN "status" SET DEFAULT 'queued'::text;

ALTER TABLE "public"."camera_ai_jobs" ALTER COLUMN "output_metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."camera_ai_jobs" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."camera_detections" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."camera_detections" ALTER COLUMN "attributes" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."camera_detections" ALTER COLUMN "occurred_at" SET DEFAULT now();

ALTER TABLE "public"."camera_detections" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."camera_event_links" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."camera_event_links" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."camera_event_links" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."camera_events" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."camera_events" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."camera_events" ALTER COLUMN "status" SET DEFAULT 'detected'::text;

ALTER TABLE "public"."camera_events" ALTER COLUMN "occurred_at" SET DEFAULT now();

ALTER TABLE "public"."camera_events" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."camera_events" ALTER COLUMN "severity" SET DEFAULT 'info'::text;

ALTER TABLE "public"."camera_events" ALTER COLUMN "detected_at" SET DEFAULT now();

ALTER TABLE "public"."camera_events" ALTER COLUMN "raw_payload" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."camera_events" ALTER COLUMN "review_status" SET DEFAULT 'unreviewed'::text;

ALTER TABLE "public"."camera_health_logs" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."camera_health_logs" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."camera_health_logs" ALTER COLUMN "checked_at" SET DEFAULT now();

ALTER TABLE "public"."camera_zones" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."camera_zones" ALTER COLUMN "zone_type" SET DEFAULT 'general'::text;

ALTER TABLE "public"."camera_zones" ALTER COLUMN "polygon" SET DEFAULT '[]'::jsonb;

ALTER TABLE "public"."camera_zones" ALTER COLUMN "is_active" SET DEFAULT true;

ALTER TABLE "public"."camera_zones" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."camera_zones" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."cameras" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."cameras" ALTER COLUMN "camera_type" SET DEFAULT 'ip'::text;

ALTER TABLE "public"."cameras" ALTER COLUMN "status" SET DEFAULT 'offline'::text;

ALTER TABLE "public"."cameras" ALTER COLUMN "is_active" SET DEFAULT true;

ALTER TABLE "public"."cameras" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."cameras" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."cameras" ALTER COLUMN "capabilities" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."cameras" ALTER COLUMN "settings" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."cameras" ALTER COLUMN "ai_enabled" SET DEFAULT false;

ALTER TABLE "public"."cash_transactions" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."cash_transactions" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."employee_activity" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."employee_activity" ALTER COLUMN "metadata" SET DEFAULT '{}'::jsonb;

ALTER TABLE "public"."employee_activity" ALTER COLUMN "occurred_at" SET DEFAULT now();

ALTER TABLE "public"."employee_activity" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."employee_permissions" ALTER COLUMN "granted" SET DEFAULT true;

ALTER TABLE "public"."employees" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."employees" ALTER COLUMN "status" SET DEFAULT 'active'::text;

ALTER TABLE "public"."employees" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."employees" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."expenses" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."expenses" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."financial_transactions" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."financial_transactions" ALTER COLUMN "amount" SET DEFAULT 0;

ALTER TABLE "public"."financial_transactions" ALTER COLUMN "transaction_date" SET DEFAULT now();

ALTER TABLE "public"."financial_transactions" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."inventory" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."inventory" ALTER COLUMN "quantity" SET DEFAULT 0;

ALTER TABLE "public"."inventory" ALTER COLUMN "reserved_quantity" SET DEFAULT 0;

ALTER TABLE "public"."inventory" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."inventory_movements" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."inventory_movements" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."products" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."products" ALTER COLUMN "unit" SET DEFAULT 'piece'::text;

ALTER TABLE "public"."products" ALTER COLUMN "cost_price" SET DEFAULT 0;

ALTER TABLE "public"."products" ALTER COLUMN "reorder_level" SET DEFAULT 0;

ALTER TABLE "public"."products" ALTER COLUMN "is_active" SET DEFAULT true;

ALTER TABLE "public"."products" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."products" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."products" ALTER COLUMN "quantity" SET DEFAULT 0;

ALTER TABLE "public"."products" ALTER COLUMN "low_stock_threshold" SET DEFAULT 5;

ALTER TABLE "public"."products" ALTER COLUMN "active" SET DEFAULT true;

ALTER TABLE "public"."recordings" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."recordings" ALTER COLUMN "started_at" SET DEFAULT now();

ALTER TABLE "public"."recordings" ALTER COLUMN "status" SET DEFAULT 'ready'::text;

ALTER TABLE "public"."recordings" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."sale_items" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."sale_items" ALTER COLUMN "discount" SET DEFAULT 0;

ALTER TABLE "public"."sale_items" ALTER COLUMN "total" SET DEFAULT 0;

ALTER TABLE "public"."sales" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."sales" ALTER COLUMN "subtotal" SET DEFAULT 0;

ALTER TABLE "public"."sales" ALTER COLUMN "discount" SET DEFAULT 0;

ALTER TABLE "public"."sales" ALTER COLUMN "tax" SET DEFAULT 0;

ALTER TABLE "public"."sales" ALTER COLUMN "total" SET DEFAULT 0;

ALTER TABLE "public"."sales" ALTER COLUMN "status" SET DEFAULT 'completed'::text;

ALTER TABLE "public"."sales" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."sales" ALTER COLUMN "quantity" SET DEFAULT 1;

ALTER TABLE "public"."sales" ALTER COLUMN "unit_price" SET DEFAULT 0;

ALTER TABLE "public"."sales" ALTER COLUMN "total_amount" SET DEFAULT 0;

ALTER TABLE "public"."sales" ALTER COLUMN "sold_at" SET DEFAULT now();

ALTER TABLE "public"."branches" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."branches" ALTER COLUMN "is_active" SET DEFAULT true;

ALTER TABLE "public"."branches" ALTER COLUMN "created_at" SET DEFAULT now();

ALTER TABLE "public"."branches" ALTER COLUMN "updated_at" SET DEFAULT now();

ALTER TABLE "public"."employee_branch_assignments" ALTER COLUMN "is_active" SET DEFAULT true;

ALTER TABLE "public"."employee_branch_assignments" ALTER COLUMN "created_at" SET DEFAULT now();

-- Non-FK constraints before foreign keys (including managed auth.users references).

ALTER TABLE "private"."angel_request_windows" ADD CONSTRAINT "angel_request_windows_pkey" PRIMARY KEY (user_id);

ALTER TABLE "private"."camera_explanation_request_windows" ADD CONSTRAINT "camera_explanation_request_windows_pkey" PRIMARY KEY (user_id);

ALTER TABLE "private"."sale_requests" ADD CONSTRAINT "sale_requests_pkey" PRIMARY KEY (business_id, user_id, request_id);

ALTER TABLE "public"."alerts" ADD CONSTRAINT "alerts_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."alerts" ADD CONSTRAINT "alerts_severity_check" CHECK (severity = ANY (ARRAY['info'::text, 'low'::text, 'medium'::text, 'warning'::text, 'high'::text, 'critical'::text]));

ALTER TABLE "public"."angel_conversations" ADD CONSTRAINT "angel_conversations_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."angel_insights" ADD CONSTRAINT "angel_insights_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."angel_messages" ADD CONSTRAINT "angel_messages_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."angel_messages" ADD CONSTRAINT "angel_messages_role_check" CHECK (role = ANY (ARRAY['user'::text, 'assistant'::text, 'system'::text]));

ALTER TABLE "public"."audit_logs" ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."business_activity" ADD CONSTRAINT "business_activity_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."business_activity" ADD CONSTRAINT "business_activity_severity_check" CHECK (severity = ANY (ARRAY['normal'::text, 'info'::text, 'warning'::text, 'critical'::text]));

ALTER TABLE "public"."business_members" ADD CONSTRAINT "business_members_business_id_user_id_key" UNIQUE (business_id, user_id);

ALTER TABLE "public"."business_members" ADD CONSTRAINT "business_members_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."business_members" ADD CONSTRAINT "business_members_role_check" CHECK (role = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text, 'employee'::text, 'cashier'::text, 'security'::text]));

ALTER TABLE "public"."business_members" ADD CONSTRAINT "business_members_status_check" CHECK (status = ANY (ARRAY['active'::text, 'inactive'::text, 'suspended'::text]));

ALTER TABLE "public"."business_settings" ADD CONSTRAINT "business_settings_business_id_key" UNIQUE (business_id);

ALTER TABLE "public"."business_settings" ADD CONSTRAINT "business_settings_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."businesses" ADD CONSTRAINT "businesses_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."camera_ai_jobs" ADD CONSTRAINT "camera_ai_jobs_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."camera_ai_jobs" ADD CONSTRAINT "camera_ai_jobs_status_check" CHECK (status = ANY (ARRAY['queued'::text, 'processing'::text, 'completed'::text, 'failed'::text, 'cancelled'::text]));

ALTER TABLE "public"."camera_ai_jobs" ADD CONSTRAINT "camera_ai_jobs_type_check" CHECK (job_type = ANY (ARRAY['analyze'::text, 'detect'::text, 'track'::text, 'snapshot'::text, 'health_check'::text]));

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_confidence_check" CHECK (confidence IS NULL OR confidence >= 0::numeric AND confidence <= 1::numeric);

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_type_check" CHECK (detection_type = ANY (ARRAY['person'::text, 'employee'::text, 'unknown_person'::text, 'object'::text, 'product'::text, 'vehicle'::text, 'cash_activity'::text, 'movement'::text, 'entry'::text, 'exit'::text, 'loitering'::text, 'crowd'::text, 'other'::text]));

ALTER TABLE "public"."camera_event_links" ADD CONSTRAINT "camera_event_links_confidence_check" CHECK (confidence IS NULL OR confidence >= 0::numeric AND confidence <= 1::numeric);

ALTER TABLE "public"."camera_event_links" ADD CONSTRAINT "camera_event_links_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."camera_event_links" ADD CONSTRAINT "camera_event_links_type_check" CHECK (linked_type = ANY (ARRAY['sale'::text, 'inventory_movement'::text, 'employee_activity'::text, 'cash_transaction'::text, 'expense'::text, 'product'::text, 'employee'::text, 'alert'::text, 'other'::text]));

ALTER TABLE "public"."camera_events" ADD CONSTRAINT "camera_events_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."camera_events" ADD CONSTRAINT "camera_events_review_status_check" CHECK (review_status = ANY (ARRAY['unreviewed'::text, 'reviewed'::text, 'dismissed'::text, 'confirmed'::text]));

ALTER TABLE "public"."camera_events" ADD CONSTRAINT "camera_events_status_check" CHECK (status = ANY (ARRAY['detected'::text, 'reviewed'::text, 'confirmed'::text, 'dismissed'::text]));

ALTER TABLE "public"."camera_health_logs" ADD CONSTRAINT "camera_health_logs_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."camera_health_logs" ADD CONSTRAINT "camera_health_status_check" CHECK (status = ANY (ARRAY['online'::text, 'offline'::text, 'degraded'::text, 'unknown'::text]));

ALTER TABLE "public"."camera_zones" ADD CONSTRAINT "camera_zones_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."camera_zones" ADD CONSTRAINT "camera_zones_type_check" CHECK (zone_type = ANY (ARRAY['general'::text, 'entrance'::text, 'exit'::text, 'cash_register'::text, 'sales_floor'::text, 'stock_room'::text, 'restricted'::text, 'shelf'::text, 'loading_area'::text, 'parking'::text, 'other'::text]));

ALTER TABLE "public"."cameras" ADD CONSTRAINT "cameras_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."cameras" ADD CONSTRAINT "cameras_status_check" CHECK (status = ANY (ARRAY['online'::text, 'offline'::text, 'error'::text]));

ALTER TABLE "public"."cash_transactions" ADD CONSTRAINT "cash_transactions_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."cash_transactions" ADD CONSTRAINT "cash_transactions_transaction_type_check" CHECK (transaction_type = ANY (ARRAY['sale'::text, 'expense'::text, 'deposit'::text, 'withdrawal'::text, 'adjustment'::text, 'refund'::text, 'camera_detection'::text]));

ALTER TABLE "public"."employee_activity" ADD CONSTRAINT "employee_activity_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."employee_permissions" ADD CONSTRAINT "employee_permissions_pkey" PRIMARY KEY (employee_id, permission_id);

ALTER TABLE "public"."employees" ADD CONSTRAINT "batch_2_employees_identity" UNIQUE (id, business_id);

ALTER TABLE "public"."employees" ADD CONSTRAINT "employees_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."expenses" ADD CONSTRAINT "expenses_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."financial_transactions" ADD CONSTRAINT "financial_transactions_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inventory" ADD CONSTRAINT "inventory_business_id_product_id_location_key" UNIQUE (business_id, product_id, location);

ALTER TABLE "public"."inventory" ADD CONSTRAINT "inventory_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inventory_movements" ADD CONSTRAINT "inventory_movements_movement_type_check" CHECK (movement_type = ANY (ARRAY['purchase'::text, 'sale'::text, 'return'::text, 'adjustment'::text, 'transfer'::text, 'damage'::text, 'loss'::text, 'camera_detection'::text]));

ALTER TABLE "public"."inventory_movements" ADD CONSTRAINT "inventory_movements_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."permissions" ADD CONSTRAINT "permissions_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."products" ADD CONSTRAINT "batch_2_products_identity" UNIQUE (id, business_id);

ALTER TABLE "public"."products" ADD CONSTRAINT "products_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."recordings" ADD CONSTRAINT "recordings_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."sale_items" ADD CONSTRAINT "sale_items_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."sales" ADD CONSTRAINT "sales_payment_method_check" CHECK (payment_method = ANY (ARRAY['cash'::text, 'card'::text, 'bank_transfer'::text, 'mobile_money'::text, 'other'::text]));

ALTER TABLE "public"."sales" ADD CONSTRAINT "sales_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."sales" ADD CONSTRAINT "sales_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'cancelled'::text, 'refunded'::text]));

ALTER TABLE "public"."branches" ADD CONSTRAINT "branches_id_business_id_key" UNIQUE (id, business_id);

ALTER TABLE "public"."branches" ADD CONSTRAINT "branches_name_check" CHECK (NULLIF(TRIM(BOTH FROM name), ''::text) IS NOT NULL);

ALTER TABLE "public"."branches" ADD CONSTRAINT "branches_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."employee_branch_assignments" ADD CONSTRAINT "employee_branch_assignments_pkey" PRIMARY KEY (employee_id, branch_id);

ALTER TABLE "private"."angel_request_windows" ADD CONSTRAINT "angel_request_windows_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "private"."camera_explanation_request_windows" ADD CONSTRAINT "camera_explanation_request_windows_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "private"."sale_requests" ADD CONSTRAINT "batch_2_request_branch" FOREIGN KEY (branch_id, business_id) REFERENCES public.branches(id, business_id) NOT VALID;

ALTER TABLE "private"."sale_requests" ADD CONSTRAINT "sale_requests_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "private"."sale_requests" ADD CONSTRAINT "sale_requests_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."alerts" ADD CONSTRAINT "alerts_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."angel_conversations" ADD CONSTRAINT "angel_conversations_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."angel_conversations" ADD CONSTRAINT "angel_conversations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE "public"."angel_insights" ADD CONSTRAINT "angel_insights_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."angel_messages" ADD CONSTRAINT "angel_messages_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES public.angel_conversations(id) ON DELETE CASCADE;

ALTER TABLE "public"."audit_logs" ADD CONSTRAINT "audit_logs_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE "public"."audit_logs" ADD CONSTRAINT "audit_logs_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."audit_logs" ADD CONSTRAINT "audit_logs_target_id_fkey" FOREIGN KEY (target_id) REFERENCES public.employees(id) ON DELETE SET NULL;

ALTER TABLE "public"."business_activity" ADD CONSTRAINT "business_activity_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."business_activity" ADD CONSTRAINT "business_activity_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.business_members(id) ON DELETE SET NULL;

ALTER TABLE "public"."business_members" ADD CONSTRAINT "business_members_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."business_members" ADD CONSTRAINT "business_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."business_settings" ADD CONSTRAINT "business_settings_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."businesses" ADD CONSTRAINT "batch_2_compatibility_branch" FOREIGN KEY (compatibility_branch_id, id) REFERENCES public.branches(id, business_id) NOT VALID;

ALTER TABLE "public"."businesses" ADD CONSTRAINT "businesses_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_ai_jobs" ADD CONSTRAINT "camera_ai_jobs_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_ai_jobs" ADD CONSTRAINT "camera_ai_jobs_camera_id_fkey" FOREIGN KEY (camera_id) REFERENCES public.cameras(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_camera_id_fkey" FOREIGN KEY (camera_id) REFERENCES public.cameras(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_event_id_fkey" FOREIGN KEY (event_id) REFERENCES public.camera_events(id) ON DELETE SET NULL;

ALTER TABLE "public"."camera_detections" ADD CONSTRAINT "camera_detections_zone_id_fkey" FOREIGN KEY (zone_id) REFERENCES public.camera_zones(id) ON DELETE SET NULL;

ALTER TABLE "public"."camera_event_links" ADD CONSTRAINT "camera_event_links_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_event_links" ADD CONSTRAINT "camera_event_links_camera_event_id_fkey" FOREIGN KEY (camera_event_id) REFERENCES public.camera_events(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_events" ADD CONSTRAINT "camera_events_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_events" ADD CONSTRAINT "camera_events_camera_id_fkey" FOREIGN KEY (camera_id) REFERENCES public.cameras(id) ON DELETE SET NULL;

ALTER TABLE "public"."camera_events" ADD CONSTRAINT "camera_events_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.business_members(id) ON DELETE SET NULL;

ALTER TABLE "public"."camera_health_logs" ADD CONSTRAINT "camera_health_logs_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_health_logs" ADD CONSTRAINT "camera_health_logs_camera_id_fkey" FOREIGN KEY (camera_id) REFERENCES public.cameras(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_zones" ADD CONSTRAINT "camera_zones_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."camera_zones" ADD CONSTRAINT "camera_zones_camera_id_fkey" FOREIGN KEY (camera_id) REFERENCES public.cameras(id) ON DELETE CASCADE;

ALTER TABLE "public"."cameras" ADD CONSTRAINT "cameras_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."cash_transactions" ADD CONSTRAINT "cash_transactions_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."cash_transactions" ADD CONSTRAINT "cash_transactions_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.business_members(id) ON DELETE SET NULL;

ALTER TABLE "public"."employee_activity" ADD CONSTRAINT "employee_activity_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."employee_activity" ADD CONSTRAINT "employee_activity_camera_id_fkey" FOREIGN KEY (camera_id) REFERENCES public.cameras(id) ON DELETE SET NULL;

ALTER TABLE "public"."employee_activity" ADD CONSTRAINT "employee_activity_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;

ALTER TABLE "public"."employee_permissions" ADD CONSTRAINT "employee_permissions_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;

ALTER TABLE "public"."employee_permissions" ADD CONSTRAINT "employee_permissions_permission_id_fkey" FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;

ALTER TABLE "public"."employees" ADD CONSTRAINT "employees_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."employees" ADD CONSTRAINT "employees_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE "public"."expenses" ADD CONSTRAINT "expenses_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."expenses" ADD CONSTRAINT "expenses_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.business_members(id) ON DELETE SET NULL;

ALTER TABLE "public"."financial_transactions" ADD CONSTRAINT "financial_transactions_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."financial_transactions" ADD CONSTRAINT "financial_transactions_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;

ALTER TABLE "public"."inventory" ADD CONSTRAINT "batch_2_inventory_branch" FOREIGN KEY (branch_id, business_id) REFERENCES public.branches(id, business_id) NOT VALID;

ALTER TABLE "public"."inventory" ADD CONSTRAINT "batch_2_inventory_product" FOREIGN KEY (product_id, business_id) REFERENCES public.products(id, business_id) NOT VALID;

ALTER TABLE "public"."inventory" ADD CONSTRAINT "inventory_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."inventory" ADD CONSTRAINT "inventory_product_id_fkey" FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE "public"."inventory_movements" ADD CONSTRAINT "batch_2_inventory_movements_branch" FOREIGN KEY (branch_id, business_id) REFERENCES public.branches(id, business_id) NOT VALID;

ALTER TABLE "public"."inventory_movements" ADD CONSTRAINT "batch_2_movement_product" FOREIGN KEY (product_id, business_id) REFERENCES public.products(id, business_id) NOT VALID;

ALTER TABLE "public"."inventory_movements" ADD CONSTRAINT "inventory_movements_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."inventory_movements" ADD CONSTRAINT "inventory_movements_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.business_members(id) ON DELETE SET NULL;

ALTER TABLE "public"."inventory_movements" ADD CONSTRAINT "inventory_movements_product_id_fkey" FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE "public"."products" ADD CONSTRAINT "products_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."recordings" ADD CONSTRAINT "recordings_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."recordings" ADD CONSTRAINT "recordings_camera_id_fkey" FOREIGN KEY (camera_id) REFERENCES public.cameras(id) ON DELETE CASCADE;

ALTER TABLE "public"."sale_items" ADD CONSTRAINT "sale_items_product_id_fkey" FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;

ALTER TABLE "public"."sale_items" ADD CONSTRAINT "sale_items_sale_id_fkey" FOREIGN KEY (sale_id) REFERENCES public.sales(id) ON DELETE CASCADE;

ALTER TABLE "public"."sales" ADD CONSTRAINT "batch_2_sales_branch" FOREIGN KEY (branch_id, business_id) REFERENCES public.branches(id, business_id) NOT VALID;

ALTER TABLE "public"."sales" ADD CONSTRAINT "sales_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE "public"."sales" ADD CONSTRAINT "sales_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES public.business_members(id) ON DELETE SET NULL;

ALTER TABLE "public"."branches" ADD CONSTRAINT "branches_business_id_fkey" FOREIGN KEY (business_id) REFERENCES public.businesses(id);

ALTER TABLE "public"."employee_branch_assignments" ADD CONSTRAINT "employee_branch_assignments_branch_id_business_id_fkey" FOREIGN KEY (branch_id, business_id) REFERENCES public.branches(id, business_id);

ALTER TABLE "public"."employee_branch_assignments" ADD CONSTRAINT "employee_branch_assignments_employee_id_business_id_fkey" FOREIGN KEY (employee_id, business_id) REFERENCES public.employees(id, business_id);

CREATE INDEX alerts_business_idx ON public.alerts USING btree (business_id);

CREATE INDEX alerts_created_idx ON public.alerts USING btree (business_id, created_at DESC);

CREATE INDEX alerts_unread_idx ON public.alerts USING btree (business_id, is_read);

CREATE INDEX idx_angel_conversations_business ON public.angel_conversations USING btree (business_id);

CREATE INDEX idx_angel_insights_business ON public.angel_insights USING btree (business_id);

CREATE INDEX angel_messages_conversation_idx ON public.angel_messages USING btree (conversation_id, created_at);

CREATE INDEX idx_angel_messages_conversation ON public.angel_messages USING btree (conversation_id);

CREATE INDEX activity_created_idx ON public.business_activity USING btree (business_id, created_at DESC);

CREATE INDEX business_activity_business_idx ON public.business_activity USING btree (business_id);

CREATE INDEX business_activity_date_idx ON public.business_activity USING btree (business_id, created_at);

CREATE INDEX business_members_business_idx ON public.business_members USING btree (business_id);

CREATE INDEX business_members_user_idx ON public.business_members USING btree (user_id);

CREATE INDEX idx_business_members_business ON public.business_members USING btree (business_id);

CREATE INDEX businesses_owner_id_idx ON public.businesses USING btree (owner_id);

CREATE INDEX idx_businesses_owner ON public.businesses USING btree (owner_id);

CREATE INDEX camera_ai_jobs_status_idx ON public.camera_ai_jobs USING btree (status, created_at);

CREATE INDEX camera_detections_business_time_idx ON public.camera_detections USING btree (business_id, occurred_at DESC);

CREATE INDEX camera_detections_camera_time_idx ON public.camera_detections USING btree (camera_id, occurred_at DESC);

CREATE INDEX camera_detections_track_idx ON public.camera_detections USING btree (camera_id, track_id, occurred_at DESC);

CREATE INDEX camera_event_links_business_idx ON public.camera_event_links USING btree (business_id, created_at DESC);

CREATE INDEX camera_event_links_event_idx ON public.camera_event_links USING btree (camera_event_id);

CREATE INDEX camera_events_business_idx ON public.camera_events USING btree (business_id);

CREATE INDEX camera_events_business_time_idx ON public.camera_events USING btree (business_id, occurred_at DESC);

CREATE INDEX camera_events_camera_idx ON public.camera_events USING btree (camera_id);

CREATE INDEX camera_events_camera_time_idx ON public.camera_events USING btree (camera_id, occurred_at DESC);

CREATE INDEX camera_events_date_idx ON public.camera_events USING btree (business_id, occurred_at);

CREATE INDEX camera_events_external_id_idx ON public.camera_events USING btree (source_provider, external_event_id);

CREATE INDEX camera_events_occurred_idx ON public.camera_events USING btree (business_id, occurred_at DESC);

CREATE INDEX camera_events_type_time_idx ON public.camera_events USING btree (business_id, event_type, occurred_at DESC);

CREATE INDEX idx_camera_events_business ON public.camera_events USING btree (business_id);

CREATE INDEX idx_camera_events_detected_at ON public.camera_events USING btree (detected_at);

CREATE INDEX camera_health_camera_time_idx ON public.camera_health_logs USING btree (camera_id, checked_at DESC);

CREATE INDEX camera_zones_camera_idx ON public.camera_zones USING btree (camera_id, is_active);

CREATE INDEX cameras_business_active_idx ON public.cameras USING btree (business_id, is_active);

CREATE INDEX cameras_business_idx ON public.cameras USING btree (business_id);

CREATE INDEX cameras_last_seen_idx ON public.cameras USING btree (last_seen_at DESC);

CREATE INDEX idx_cameras_business ON public.cameras USING btree (business_id);

CREATE INDEX cash_transactions_business_idx ON public.cash_transactions USING btree (business_id);

CREATE INDEX cash_transactions_date_idx ON public.cash_transactions USING btree (business_id, created_at);

CREATE INDEX idx_employee_activity_business ON public.employee_activity USING btree (business_id);

CREATE UNIQUE INDEX batch_2_employee_code_unique ON public.employees USING btree (employee_code);

CREATE INDEX idx_employees_business ON public.employees USING btree (business_id);

CREATE INDEX expenses_business_idx ON public.expenses USING btree (business_id);

CREATE INDEX expenses_date_idx ON public.expenses USING btree (business_id, created_at);

CREATE INDEX idx_finance_business ON public.financial_transactions USING btree (business_id);

CREATE INDEX batch_2_inventory_branch_idx ON public.inventory USING btree (business_id, branch_id);

CREATE UNIQUE INDEX batch_2_inventory_branch_product ON public.inventory USING btree (business_id, branch_id, product_id) WHERE (branch_id IS NOT NULL);

CREATE INDEX inventory_business_id_idx ON public.inventory USING btree (business_id);

CREATE INDEX inventory_product_id_idx ON public.inventory USING btree (product_id);

CREATE INDEX batch_2_inventory_movements_branch_idx ON public.inventory_movements USING btree (business_id, branch_id);

CREATE INDEX idx_inventory_movements_business ON public.inventory_movements USING btree (business_id);

CREATE INDEX idx_inventory_movements_product ON public.inventory_movements USING btree (product_id);

CREATE INDEX inventory_movements_business_idx ON public.inventory_movements USING btree (business_id);

CREATE INDEX inventory_movements_product_idx ON public.inventory_movements USING btree (product_id);

CREATE INDEX idx_products_business ON public.products USING btree (business_id);

CREATE INDEX products_barcode_idx ON public.products USING btree (business_id, barcode);

CREATE INDEX products_business_id_idx ON public.products USING btree (business_id);

CREATE INDEX products_name_idx ON public.products USING btree (business_id, name);

CREATE INDEX recordings_camera_id_idx ON public.recordings USING btree (camera_id);

CREATE INDEX recordings_started_at_idx ON public.recordings USING btree (started_at DESC);

CREATE INDEX sale_items_sale_id_idx ON public.sale_items USING btree (sale_id);

CREATE INDEX batch_2_sales_branch_idx ON public.sales USING btree (business_id, branch_id);

CREATE INDEX idx_sales_business ON public.sales USING btree (business_id);

CREATE INDEX idx_sales_sold_at ON public.sales USING btree (sold_at);

CREATE INDEX sales_business_id_idx ON public.sales USING btree (business_id);

CREATE INDEX sales_created_at_idx ON public.sales USING btree (business_id, created_at);

CREATE INDEX branches_business_idx ON public.branches USING btree (business_id);

CREATE INDEX employee_branch_business_idx ON public.employee_branch_assignments USING btree (business_id, branch_id);

ALTER TABLE "private"."angel_request_windows" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "private"."camera_explanation_request_windows" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "private"."sale_requests" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."alerts" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."angel_conversations" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."angel_insights" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."angel_messages" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."audit_logs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."branches" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."business_activity" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."business_members" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."business_settings" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."businesses" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."camera_ai_jobs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."camera_detections" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."camera_detections" REPLICA IDENTITY FULL;

ALTER TABLE "public"."camera_event_links" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."camera_events" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."camera_events" REPLICA IDENTITY FULL;

ALTER TABLE "public"."camera_health_logs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."camera_zones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."cameras" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."cash_transactions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."employee_activity" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."employee_branch_assignments" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."employee_permissions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."employees" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."expenses" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."financial_transactions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inventory" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inventory_movements" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."permissions" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."recordings" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."sale_items" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."sales" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Alert permission boundary" ON "public"."alerts" AS RESTRICTIVE FOR ALL TO "authenticated" USING ((public.user_owns_business(business_id) OR ((alert_type ~~ '%stock%'::text) AND private.has_business_permission(business_id, 'view_inventory'::text)) OR ((alert_type !~~ '%stock%'::text) AND private.has_business_permission(business_id, 'view_camera_events'::text)))) WITH CHECK ((public.user_owns_business(business_id) OR ((alert_type ~~ '%stock%'::text) AND private.has_business_permission(business_id, 'view_inventory'::text)) OR ((alert_type !~~ '%stock%'::text) AND private.has_business_permission(business_id, 'view_camera_events'::text))));

CREATE POLICY "members can update alerts" ON "public"."alerts" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "members can view alerts" ON "public"."alerts" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "Angel author boundary" ON "public"."angel_conversations" AS RESTRICTIVE FOR ALL TO "authenticated" USING (((user_id = auth.uid()) AND public.user_owns_business(business_id))) WITH CHECK (((user_id = auth.uid()) AND public.user_owns_business(business_id)));

CREATE POLICY "members can create Angel conversations" ON "public"."angel_conversations" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view Angel conversations" ON "public"."angel_conversations" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage angel conversations" ON "public"."angel_conversations" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Owner insight boundary" ON "public"."angel_insights" AS RESTRICTIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "owners manage angel insights" ON "public"."angel_insights" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Angel message author boundary" ON "public"."angel_messages" AS RESTRICTIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM public.angel_conversations c
  WHERE ((c.id = angel_messages.conversation_id) AND (c.user_id = auth.uid()) AND public.user_owns_business(c.business_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.angel_conversations c
  WHERE ((c.id = angel_messages.conversation_id) AND (c.user_id = auth.uid()) AND public.user_owns_business(c.business_id)))));

CREATE POLICY "members can create Angel messages" ON "public"."angel_messages" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK ((EXISTS ( SELECT 1
   FROM public.angel_conversations c
  WHERE ((c.id = angel_messages.conversation_id) AND public.is_business_member(c.business_id)))));

CREATE POLICY "members can view Angel messages" ON "public"."angel_messages" AS PERMISSIVE FOR SELECT TO PUBLIC USING ((EXISTS ( SELECT 1
   FROM public.angel_conversations c
  WHERE ((c.id = angel_messages.conversation_id) AND public.is_business_member(c.business_id)))));

CREATE POLICY "owners manage angel messages" ON "public"."angel_messages" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM public.angel_conversations c
  WHERE ((c.id = angel_messages.conversation_id) AND public.user_owns_business(c.business_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.angel_conversations c
  WHERE ((c.id = angel_messages.conversation_id) AND public.user_owns_business(c.business_id)))));

CREATE POLICY "Deferred purchase cost audit boundary" ON "public"."audit_logs" AS RESTRICTIVE FOR SELECT TO "authenticated" USING ((NOT (jsonb_path_exists(COALESCE(metadata, '{}'::jsonb), '$.**."cost_price"'::jsonpath) OR jsonb_path_exists(COALESCE(metadata, '{}'::jsonb), '$.**."purchase_cost"'::jsonpath) OR jsonb_path_exists(COALESCE(metadata, '{}'::jsonb), '$.**."purchase_price"'::jsonpath))));

CREATE POLICY "Owners and managers can view audit logs" ON "public"."audit_logs" AS PERMISSIVE FOR SELECT TO PUBLIC USING ((EXISTS ( SELECT 1
   FROM public.business_members
  WHERE ((business_members.business_id = audit_logs.business_id) AND (business_members.user_id = auth.uid()) AND (business_members.role = ANY (ARRAY['owner'::text, 'manager'::text]))))));

CREATE POLICY "Branch authorized read" ON "public"."branches" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((public.user_owns_business(business_id) OR private.has_branch_access(business_id, id)));

CREATE POLICY "members can create business activity" ON "public"."business_activity" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view business activity" ON "public"."business_activity" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "Membership read scope" ON "public"."business_members" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.can_read_membership(business_id, user_id));

CREATE POLICY "Users can read their own membership status" ON "public"."business_members" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((user_id = auth.uid()));

CREATE POLICY "members can view business members" ON "public"."business_members" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "Owner settings boundary" ON "public"."business_settings" AS RESTRICTIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "members can update business settings" ON "public"."business_settings" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "members can view business settings" ON "public"."business_settings" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "Owners can create their own business" ON "public"."businesses" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "Owners can delete their own business" ON "public"."businesses" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((auth.uid() = owner_id));

CREATE POLICY "Owners can update their own business" ON "public"."businesses" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((auth.uid() = owner_id)) WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "Owners can view their own business" ON "public"."businesses" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((auth.uid() = owner_id));

CREATE POLICY "business members can view business" ON "public"."businesses" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(id));

CREATE POLICY "business owners can insert businesses" ON "public"."businesses" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((owner_id = auth.uid()));

CREATE POLICY "business owners can update businesses" ON "public"."businesses" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((owner_id = auth.uid())) WITH CHECK ((owner_id = auth.uid()));

CREATE POLICY "business owners can view businesses" ON "public"."businesses" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((owner_id = auth.uid()));

CREATE POLICY "Camera evidence boundary" ON "public"."camera_ai_jobs" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "members can view camera jobs" ON "public"."camera_ai_jobs" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage camera jobs" ON "public"."camera_ai_jobs" AS PERMISSIVE FOR ALL TO PUBLIC USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner delete boundary" ON "public"."camera_detections" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (public.user_owns_business(business_id));

CREATE POLICY "Camera owner update boundary" ON "public"."camera_detections" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner write boundary" ON "public"."camera_detections" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera read permission" ON "public"."camera_detections" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text));

CREATE POLICY "members can view camera detections" ON "public"."camera_detections" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage camera detections" ON "public"."camera_detections" AS PERMISSIVE FOR ALL TO PUBLIC USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera evidence boundary" ON "public"."camera_event_links" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "members can view camera links" ON "public"."camera_event_links" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage camera links" ON "public"."camera_event_links" AS PERMISSIVE FOR ALL TO PUBLIC USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner delete boundary" ON "public"."camera_events" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (public.user_owns_business(business_id));

CREATE POLICY "Camera owner update boundary" ON "public"."camera_events" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner write boundary" ON "public"."camera_events" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera read permission" ON "public"."camera_events" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text));

CREATE POLICY "members can create camera events" ON "public"."camera_events" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view camera events" ON "public"."camera_events" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage camera events" ON "public"."camera_events" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera evidence boundary" ON "public"."camera_health_logs" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "members can view camera health" ON "public"."camera_health_logs" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage camera health" ON "public"."camera_health_logs" AS PERMISSIVE FOR ALL TO PUBLIC USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner delete boundary" ON "public"."camera_zones" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (public.user_owns_business(business_id));

CREATE POLICY "Camera owner update boundary" ON "public"."camera_zones" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner write boundary" ON "public"."camera_zones" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera read permission" ON "public"."camera_zones" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text));

CREATE POLICY "members can view camera zones" ON "public"."camera_zones" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage camera zones" ON "public"."camera_zones" AS PERMISSIVE FOR ALL TO PUBLIC USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner delete boundary" ON "public"."cameras" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (public.user_owns_business(business_id));

CREATE POLICY "Camera owner update boundary" ON "public"."cameras" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner write boundary" ON "public"."cameras" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera read permission" ON "public"."cameras" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text));

CREATE POLICY "members can manage cameras" ON "public"."cameras" AS PERMISSIVE FOR ALL TO PUBLIC USING (public.is_business_member(business_id)) WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view cameras" ON "public"."cameras" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage cameras" ON "public"."cameras" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Finance permission boundary" ON "public"."cash_transactions" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.has_business_permission(business_id, 'view_finance'::text)) WITH CHECK (private.has_business_permission(business_id, 'view_finance'::text));

CREATE POLICY "Legacy finance branch boundary" ON "public"."cash_transactions" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.branch_record_access(business_id, NULL::uuid)) WITH CHECK (private.branch_record_access(business_id, NULL::uuid));

CREATE POLICY "members can create cash transactions" ON "public"."cash_transactions" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view cash transactions" ON "public"."cash_transactions" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage employee activity" ON "public"."employee_activity" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Assignment authorized read" ON "public"."employee_branch_assignments" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((public.user_owns_business(business_id) OR (EXISTS ( SELECT 1
   FROM public.employees e
  WHERE ((e.id = employee_branch_assignments.employee_id) AND (e.user_id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "Owners and employees can read assigned permissions" ON "public"."employee_permissions" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM public.employees e
  WHERE ((e.id = employee_permissions.employee_id) AND (public.user_owns_business(e.business_id) OR (e.user_id = auth.uid()))))));

CREATE POLICY "Owners and managers can insert employees" ON "public"."employees" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK ((EXISTS ( SELECT 1
   FROM public.business_members
  WHERE ((business_members.business_id = employees.business_id) AND (business_members.user_id = auth.uid()) AND (business_members.role = ANY (ARRAY['owner'::text, 'manager'::text]))))));

CREATE POLICY "Owners and managers can update employees" ON "public"."employees" AS PERMISSIVE FOR UPDATE TO PUBLIC USING ((EXISTS ( SELECT 1
   FROM public.business_members
  WHERE ((business_members.business_id = employees.business_id) AND (business_members.user_id = auth.uid()) AND (business_members.role = ANY (ARRAY['owner'::text, 'manager'::text]))))));

CREATE POLICY "Owners and managers can view business employees" ON "public"."employees" AS PERMISSIVE FOR SELECT TO PUBLIC USING (((EXISTS ( SELECT 1
   FROM public.business_members
  WHERE ((business_members.business_id = employees.business_id) AND (business_members.user_id = auth.uid()) AND (business_members.role = ANY (ARRAY['owner'::text, 'manager'::text]))))) OR (user_id = auth.uid())));

CREATE POLICY "Staff read scope" ON "public"."employees" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.can_read_staff(business_id, id));

CREATE POLICY "owners manage employees" ON "public"."employees" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Finance permission boundary" ON "public"."expenses" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.has_business_permission(business_id, 'view_finance'::text)) WITH CHECK (private.has_business_permission(business_id, 'view_finance'::text));

CREATE POLICY "Legacy finance branch boundary" ON "public"."expenses" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.branch_record_access(business_id, NULL::uuid)) WITH CHECK (private.branch_record_access(business_id, NULL::uuid));

CREATE POLICY "members can create expenses" ON "public"."expenses" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view expenses" ON "public"."expenses" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "Finance permission boundary" ON "public"."financial_transactions" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.has_business_permission(business_id, 'view_finance'::text)) WITH CHECK (private.has_business_permission(business_id, 'view_finance'::text));

CREATE POLICY "Legacy finance branch boundary" ON "public"."financial_transactions" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.branch_record_access(business_id, NULL::uuid)) WITH CHECK (private.branch_record_access(business_id, NULL::uuid));

CREATE POLICY "owners manage financial transactions" ON "public"."financial_transactions" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Inventory branch boundary" ON "public"."inventory" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.branch_record_access(business_id, branch_id));

CREATE POLICY "Inventory read boundary" ON "public"."inventory" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.has_business_permission(business_id, 'view_inventory'::text));

CREATE POLICY "members can modify inventory" ON "public"."inventory" AS PERMISSIVE FOR ALL TO PUBLIC USING (public.is_business_member(business_id)) WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view inventory" ON "public"."inventory" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "Inventory evidence permission" ON "public"."inventory_movements" AS RESTRICTIVE FOR ALL TO "authenticated" USING (private.has_business_permission(business_id, 'view_inventory'::text)) WITH CHECK (private.has_business_permission(business_id, 'edit_products'::text));

CREATE POLICY "Movement branch boundary" ON "public"."inventory_movements" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.branch_record_access(business_id, branch_id));

CREATE POLICY "members can create inventory movements" ON "public"."inventory_movements" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can view inventory movements" ON "public"."inventory_movements" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage inventory movements" ON "public"."inventory_movements" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Authenticated users can read permission definitions" ON "public"."permissions" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "Product create permission" ON "public"."products" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (private.has_business_permission(business_id, 'add_products'::text));

CREATE POLICY "Product delete permission" ON "public"."products" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (public.user_owns_business(business_id));

CREATE POLICY "Product edit permission" ON "public"."products" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (private.has_business_permission(business_id, 'edit_products'::text)) WITH CHECK (private.has_business_permission(business_id, 'edit_products'::text));

CREATE POLICY "Product read permission" ON "public"."products" AS RESTRICTIVE FOR SELECT TO "authenticated" USING ((private.has_business_permission(business_id, 'view_inventory'::text) OR private.has_business_permission(business_id, 'pos_access'::text)));

CREATE POLICY "members can create products" ON "public"."products" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can delete products" ON "public"."products" AS PERMISSIVE FOR DELETE TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "members can update products" ON "public"."products" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "members can view products" ON "public"."products" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage products" ON "public"."products" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Authorized staff read recordings" ON "public"."recordings" AS PERMISSIVE FOR SELECT TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text));

CREATE POLICY "Business owner can manage recordings" ON "public"."recordings" AS PERMISSIVE FOR ALL TO PUBLIC USING ((business_id IN ( SELECT businesses.id
   FROM public.businesses
  WHERE (businesses.owner_id = auth.uid()))));

CREATE POLICY "Camera owner delete boundary" ON "public"."recordings" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (public.user_owns_business(business_id));

CREATE POLICY "Camera owner update boundary" ON "public"."recordings" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera owner write boundary" ON "public"."recordings" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Camera read permission" ON "public"."recordings" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.has_business_permission(business_id, 'view_camera_events'::text));

CREATE POLICY "Sale item scoped read" ON "public"."sale_items" AS RESTRICTIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM public.sales s
  WHERE (s.id = sale_items.sale_id))));

CREATE POLICY "members can create sale items" ON "public"."sale_items" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK ((EXISTS ( SELECT 1
   FROM public.sales s
  WHERE ((s.id = sale_items.sale_id) AND public.is_business_member(s.business_id)))));

CREATE POLICY "members can view sale items" ON "public"."sale_items" AS PERMISSIVE FOR SELECT TO PUBLIC USING ((EXISTS ( SELECT 1
   FROM public.sales s
  WHERE ((s.id = sale_items.sale_id) AND public.is_business_member(s.business_id)))));

CREATE POLICY "Sales branch boundary" ON "public"."sales" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.branch_record_access(business_id, branch_id));

CREATE POLICY "Sales read permission" ON "public"."sales" AS RESTRICTIVE FOR SELECT TO "authenticated" USING (private.sales_history_access(business_id, created_at));

CREATE POLICY "members can create sales" ON "public"."sales" AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (public.is_business_member(business_id));

CREATE POLICY "members can update sales" ON "public"."sales" AS PERMISSIVE FOR UPDATE TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "members can view sales" ON "public"."sales" AS PERMISSIVE FOR SELECT TO PUBLIC USING (public.is_business_member(business_id));

CREATE POLICY "owners manage sales" ON "public"."sales" AS PERMISSIVE FOR ALL TO "authenticated" USING (public.user_owns_business(business_id)) WITH CHECK (public.user_owns_business(business_id));

CREATE POLICY "Authorized staff read recording objects" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((bucket_id = 'recordings'::text) AND (EXISTS ( SELECT 1
   FROM public.recordings r
  WHERE ((r.storage_path = objects.name) AND private.has_business_permission(r.business_id, 'view_camera_events'::text))))));

CREATE POLICY "Owners read their recording objects" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((bucket_id = 'recordings'::text) AND (EXISTS ( SELECT 1
   FROM public.recordings r
  WHERE ((r.storage_path = objects.name) AND public.user_owns_business(r.business_id))))));

CREATE TRIGGER angel_conversations_updated_at BEFORE UPDATE ON public.angel_conversations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER business_members_updated_at BEFORE UPDATE ON public.business_members FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER business_settings_updated_at BEFORE UPDATE ON public.business_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER batch_2_business_foundation BEFORE INSERT OR UPDATE ON public.businesses FOR EACH ROW EXECUTE FUNCTION private.guard_business_foundation();

CREATE TRIGGER businesses_updated_at BEFORE UPDATE ON public.businesses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_camera_event_alert AFTER INSERT ON public.camera_events FOR EACH ROW EXECUTE FUNCTION public.camera_event_to_alert();

CREATE TRIGGER cameras_updated_at BEFORE UPDATE ON public.cameras FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER batch_2_staff_scope BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION private.guard_staff_scope();

CREATE TRIGGER inventory_updated_at BEFORE UPDATE ON public.inventory FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER batch_2_legacy_stock BEFORE INSERT OR UPDATE OF quantity ON public.products FOR EACH ROW EXECUTE FUNCTION private.guard_legacy_stock();

CREATE TRIGGER batch_2_price_assignment BEFORE UPDATE OF selling_price ON public.products FOR EACH ROW EXECUTE FUNCTION private.guard_price_assignment();

CREATE TRIGGER batch_2_price_audit AFTER INSERT OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION private.audit_product_price();

CREATE TRIGGER batch_2_product_fields BEFORE INSERT OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION private.guard_product_fields();

CREATE TRIGGER products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER batch_2_sale_item_guard BEFORE INSERT ON public.sale_items FOR EACH ROW EXECUTE FUNCTION private.guard_sale_item_product();

-- Reset only application object ACLs, then reproduce effective privileges.

REVOKE ALL PRIVILEGES ON SCHEMA "private" FROM PUBLIC, "anon", "authenticated", "pg_database_owner", "postgres", "service_role";

GRANT USAGE ON SCHEMA "private" TO "authenticated";

GRANT CREATE ON SCHEMA "private" TO "postgres";

GRANT USAGE ON SCHEMA "private" TO "postgres";

GRANT USAGE ON SCHEMA "private" TO "service_role";

REVOKE ALL PRIVILEGES ON SCHEMA "public" FROM PUBLIC, "anon", "authenticated", "pg_database_owner", "postgres", "service_role";

GRANT USAGE ON SCHEMA "public" TO PUBLIC;

GRANT USAGE ON SCHEMA "public" TO "anon";

GRANT USAGE ON SCHEMA "public" TO "authenticated";

GRANT CREATE ON SCHEMA "public" TO "pg_database_owner";

GRANT USAGE ON SCHEMA "public" TO "pg_database_owner";

GRANT USAGE ON SCHEMA "public" TO "postgres";

GRANT USAGE ON SCHEMA "public" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "private"."angel_request_windows" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "private"."angel_request_windows" TO "postgres";

GRANT INSERT ON TABLE "private"."angel_request_windows" TO "postgres";

GRANT MAINTAIN ON TABLE "private"."angel_request_windows" TO "postgres";

GRANT REFERENCES ON TABLE "private"."angel_request_windows" TO "postgres";

GRANT SELECT ON TABLE "private"."angel_request_windows" TO "postgres";

GRANT TRIGGER ON TABLE "private"."angel_request_windows" TO "postgres";

GRANT TRUNCATE ON TABLE "private"."angel_request_windows" TO "postgres";

GRANT UPDATE ON TABLE "private"."angel_request_windows" TO "postgres";

REVOKE ALL PRIVILEGES ON TABLE "private"."camera_explanation_request_windows" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

GRANT INSERT ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

GRANT MAINTAIN ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

GRANT REFERENCES ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

GRANT SELECT ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

GRANT TRIGGER ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

GRANT TRUNCATE ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

GRANT UPDATE ON TABLE "private"."camera_explanation_request_windows" TO "postgres";

REVOKE ALL PRIVILEGES ON TABLE "private"."sale_requests" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "private"."sale_requests" TO "postgres";

GRANT INSERT ON TABLE "private"."sale_requests" TO "postgres";

GRANT MAINTAIN ON TABLE "private"."sale_requests" TO "postgres";

GRANT REFERENCES ON TABLE "private"."sale_requests" TO "postgres";

GRANT SELECT ON TABLE "private"."sale_requests" TO "postgres";

GRANT TRIGGER ON TABLE "private"."sale_requests" TO "postgres";

GRANT TRUNCATE ON TABLE "private"."sale_requests" TO "postgres";

GRANT UPDATE ON TABLE "private"."sale_requests" TO "postgres";

REVOKE ALL PRIVILEGES ON TABLE "public"."alerts" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."alerts" TO "anon";

GRANT INSERT ON TABLE "public"."alerts" TO "anon";

GRANT SELECT ON TABLE "public"."alerts" TO "anon";

GRANT UPDATE ON TABLE "public"."alerts" TO "anon";

GRANT DELETE ON TABLE "public"."alerts" TO "authenticated";

GRANT INSERT ON TABLE "public"."alerts" TO "authenticated";

GRANT SELECT ON TABLE "public"."alerts" TO "authenticated";

GRANT UPDATE ON TABLE "public"."alerts" TO "authenticated";

GRANT DELETE ON TABLE "public"."alerts" TO "postgres";

GRANT INSERT ON TABLE "public"."alerts" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."alerts" TO "postgres";

GRANT REFERENCES ON TABLE "public"."alerts" TO "postgres";

GRANT SELECT ON TABLE "public"."alerts" TO "postgres";

GRANT TRIGGER ON TABLE "public"."alerts" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."alerts" TO "postgres";

GRANT UPDATE ON TABLE "public"."alerts" TO "postgres";

GRANT DELETE ON TABLE "public"."alerts" TO "service_role";

GRANT INSERT ON TABLE "public"."alerts" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."alerts" TO "service_role";

GRANT REFERENCES ON TABLE "public"."alerts" TO "service_role";

GRANT SELECT ON TABLE "public"."alerts" TO "service_role";

GRANT TRIGGER ON TABLE "public"."alerts" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."alerts" TO "service_role";

GRANT UPDATE ON TABLE "public"."alerts" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."angel_conversations" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."angel_conversations" TO "anon";

GRANT INSERT ON TABLE "public"."angel_conversations" TO "anon";

GRANT SELECT ON TABLE "public"."angel_conversations" TO "anon";

GRANT UPDATE ON TABLE "public"."angel_conversations" TO "anon";

GRANT DELETE ON TABLE "public"."angel_conversations" TO "authenticated";

GRANT INSERT ON TABLE "public"."angel_conversations" TO "authenticated";

GRANT SELECT ON TABLE "public"."angel_conversations" TO "authenticated";

GRANT UPDATE ON TABLE "public"."angel_conversations" TO "authenticated";

GRANT DELETE ON TABLE "public"."angel_conversations" TO "postgres";

GRANT INSERT ON TABLE "public"."angel_conversations" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."angel_conversations" TO "postgres";

GRANT REFERENCES ON TABLE "public"."angel_conversations" TO "postgres";

GRANT SELECT ON TABLE "public"."angel_conversations" TO "postgres";

GRANT TRIGGER ON TABLE "public"."angel_conversations" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."angel_conversations" TO "postgres";

GRANT UPDATE ON TABLE "public"."angel_conversations" TO "postgres";

GRANT DELETE ON TABLE "public"."angel_conversations" TO "service_role";

GRANT INSERT ON TABLE "public"."angel_conversations" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."angel_conversations" TO "service_role";

GRANT REFERENCES ON TABLE "public"."angel_conversations" TO "service_role";

GRANT SELECT ON TABLE "public"."angel_conversations" TO "service_role";

GRANT TRIGGER ON TABLE "public"."angel_conversations" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."angel_conversations" TO "service_role";

GRANT UPDATE ON TABLE "public"."angel_conversations" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."angel_insights" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."angel_insights" TO "anon";

GRANT INSERT ON TABLE "public"."angel_insights" TO "anon";

GRANT SELECT ON TABLE "public"."angel_insights" TO "anon";

GRANT UPDATE ON TABLE "public"."angel_insights" TO "anon";

GRANT DELETE ON TABLE "public"."angel_insights" TO "authenticated";

GRANT INSERT ON TABLE "public"."angel_insights" TO "authenticated";

GRANT SELECT ON TABLE "public"."angel_insights" TO "authenticated";

GRANT UPDATE ON TABLE "public"."angel_insights" TO "authenticated";

GRANT DELETE ON TABLE "public"."angel_insights" TO "postgres";

GRANT INSERT ON TABLE "public"."angel_insights" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."angel_insights" TO "postgres";

GRANT REFERENCES ON TABLE "public"."angel_insights" TO "postgres";

GRANT SELECT ON TABLE "public"."angel_insights" TO "postgres";

GRANT TRIGGER ON TABLE "public"."angel_insights" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."angel_insights" TO "postgres";

GRANT UPDATE ON TABLE "public"."angel_insights" TO "postgres";

GRANT DELETE ON TABLE "public"."angel_insights" TO "service_role";

GRANT INSERT ON TABLE "public"."angel_insights" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."angel_insights" TO "service_role";

GRANT REFERENCES ON TABLE "public"."angel_insights" TO "service_role";

GRANT SELECT ON TABLE "public"."angel_insights" TO "service_role";

GRANT TRIGGER ON TABLE "public"."angel_insights" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."angel_insights" TO "service_role";

GRANT UPDATE ON TABLE "public"."angel_insights" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."angel_messages" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."angel_messages" TO "anon";

GRANT INSERT ON TABLE "public"."angel_messages" TO "anon";

GRANT SELECT ON TABLE "public"."angel_messages" TO "anon";

GRANT UPDATE ON TABLE "public"."angel_messages" TO "anon";

GRANT DELETE ON TABLE "public"."angel_messages" TO "authenticated";

GRANT INSERT ON TABLE "public"."angel_messages" TO "authenticated";

GRANT SELECT ON TABLE "public"."angel_messages" TO "authenticated";

GRANT UPDATE ON TABLE "public"."angel_messages" TO "authenticated";

GRANT DELETE ON TABLE "public"."angel_messages" TO "postgres";

GRANT INSERT ON TABLE "public"."angel_messages" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."angel_messages" TO "postgres";

GRANT REFERENCES ON TABLE "public"."angel_messages" TO "postgres";

GRANT SELECT ON TABLE "public"."angel_messages" TO "postgres";

GRANT TRIGGER ON TABLE "public"."angel_messages" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."angel_messages" TO "postgres";

GRANT UPDATE ON TABLE "public"."angel_messages" TO "postgres";

GRANT DELETE ON TABLE "public"."angel_messages" TO "service_role";

GRANT INSERT ON TABLE "public"."angel_messages" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."angel_messages" TO "service_role";

GRANT REFERENCES ON TABLE "public"."angel_messages" TO "service_role";

GRANT SELECT ON TABLE "public"."angel_messages" TO "service_role";

GRANT TRIGGER ON TABLE "public"."angel_messages" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."angel_messages" TO "service_role";

GRANT UPDATE ON TABLE "public"."angel_messages" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."audit_logs" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."audit_logs" TO "anon";

GRANT SELECT ON TABLE "public"."audit_logs" TO "authenticated";

GRANT DELETE ON TABLE "public"."audit_logs" TO "postgres";

GRANT INSERT ON TABLE "public"."audit_logs" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."audit_logs" TO "postgres";

GRANT REFERENCES ON TABLE "public"."audit_logs" TO "postgres";

GRANT SELECT ON TABLE "public"."audit_logs" TO "postgres";

GRANT TRIGGER ON TABLE "public"."audit_logs" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."audit_logs" TO "postgres";

GRANT UPDATE ON TABLE "public"."audit_logs" TO "postgres";

GRANT DELETE ON TABLE "public"."audit_logs" TO "service_role";

GRANT INSERT ON TABLE "public"."audit_logs" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."audit_logs" TO "service_role";

GRANT REFERENCES ON TABLE "public"."audit_logs" TO "service_role";

GRANT SELECT ON TABLE "public"."audit_logs" TO "service_role";

GRANT TRIGGER ON TABLE "public"."audit_logs" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."audit_logs" TO "service_role";

GRANT UPDATE ON TABLE "public"."audit_logs" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."branches" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."branches" TO "authenticated";

GRANT DELETE ON TABLE "public"."branches" TO "postgres";

GRANT INSERT ON TABLE "public"."branches" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."branches" TO "postgres";

GRANT REFERENCES ON TABLE "public"."branches" TO "postgres";

GRANT SELECT ON TABLE "public"."branches" TO "postgres";

GRANT TRIGGER ON TABLE "public"."branches" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."branches" TO "postgres";

GRANT UPDATE ON TABLE "public"."branches" TO "postgres";

GRANT DELETE ON TABLE "public"."branches" TO "service_role";

GRANT INSERT ON TABLE "public"."branches" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."branches" TO "service_role";

GRANT REFERENCES ON TABLE "public"."branches" TO "service_role";

GRANT SELECT ON TABLE "public"."branches" TO "service_role";

GRANT TRIGGER ON TABLE "public"."branches" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."branches" TO "service_role";

GRANT UPDATE ON TABLE "public"."branches" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."business_activity" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."business_activity" TO "anon";

GRANT INSERT ON TABLE "public"."business_activity" TO "anon";

GRANT SELECT ON TABLE "public"."business_activity" TO "anon";

GRANT UPDATE ON TABLE "public"."business_activity" TO "anon";

GRANT DELETE ON TABLE "public"."business_activity" TO "authenticated";

GRANT INSERT ON TABLE "public"."business_activity" TO "authenticated";

GRANT SELECT ON TABLE "public"."business_activity" TO "authenticated";

GRANT UPDATE ON TABLE "public"."business_activity" TO "authenticated";

GRANT DELETE ON TABLE "public"."business_activity" TO "postgres";

GRANT INSERT ON TABLE "public"."business_activity" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."business_activity" TO "postgres";

GRANT REFERENCES ON TABLE "public"."business_activity" TO "postgres";

GRANT SELECT ON TABLE "public"."business_activity" TO "postgres";

GRANT TRIGGER ON TABLE "public"."business_activity" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."business_activity" TO "postgres";

GRANT UPDATE ON TABLE "public"."business_activity" TO "postgres";

GRANT DELETE ON TABLE "public"."business_activity" TO "service_role";

GRANT INSERT ON TABLE "public"."business_activity" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."business_activity" TO "service_role";

GRANT REFERENCES ON TABLE "public"."business_activity" TO "service_role";

GRANT SELECT ON TABLE "public"."business_activity" TO "service_role";

GRANT TRIGGER ON TABLE "public"."business_activity" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."business_activity" TO "service_role";

GRANT UPDATE ON TABLE "public"."business_activity" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."business_members" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."business_members" TO "anon";

GRANT SELECT ON TABLE "public"."business_members" TO "authenticated";

GRANT DELETE ON TABLE "public"."business_members" TO "postgres";

GRANT INSERT ON TABLE "public"."business_members" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."business_members" TO "postgres";

GRANT REFERENCES ON TABLE "public"."business_members" TO "postgres";

GRANT SELECT ON TABLE "public"."business_members" TO "postgres";

GRANT TRIGGER ON TABLE "public"."business_members" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."business_members" TO "postgres";

GRANT UPDATE ON TABLE "public"."business_members" TO "postgres";

GRANT DELETE ON TABLE "public"."business_members" TO "service_role";

GRANT INSERT ON TABLE "public"."business_members" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."business_members" TO "service_role";

GRANT REFERENCES ON TABLE "public"."business_members" TO "service_role";

GRANT SELECT ON TABLE "public"."business_members" TO "service_role";

GRANT TRIGGER ON TABLE "public"."business_members" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."business_members" TO "service_role";

GRANT UPDATE ON TABLE "public"."business_members" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."business_settings" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."business_settings" TO "anon";

GRANT INSERT ON TABLE "public"."business_settings" TO "anon";

GRANT SELECT ON TABLE "public"."business_settings" TO "anon";

GRANT UPDATE ON TABLE "public"."business_settings" TO "anon";

GRANT DELETE ON TABLE "public"."business_settings" TO "authenticated";

GRANT INSERT ON TABLE "public"."business_settings" TO "authenticated";

GRANT SELECT ON TABLE "public"."business_settings" TO "authenticated";

GRANT UPDATE ON TABLE "public"."business_settings" TO "authenticated";

GRANT DELETE ON TABLE "public"."business_settings" TO "postgres";

GRANT INSERT ON TABLE "public"."business_settings" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."business_settings" TO "postgres";

GRANT REFERENCES ON TABLE "public"."business_settings" TO "postgres";

GRANT SELECT ON TABLE "public"."business_settings" TO "postgres";

GRANT TRIGGER ON TABLE "public"."business_settings" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."business_settings" TO "postgres";

GRANT UPDATE ON TABLE "public"."business_settings" TO "postgres";

GRANT DELETE ON TABLE "public"."business_settings" TO "service_role";

GRANT INSERT ON TABLE "public"."business_settings" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."business_settings" TO "service_role";

GRANT REFERENCES ON TABLE "public"."business_settings" TO "service_role";

GRANT SELECT ON TABLE "public"."business_settings" TO "service_role";

GRANT TRIGGER ON TABLE "public"."business_settings" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."business_settings" TO "service_role";

GRANT UPDATE ON TABLE "public"."business_settings" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."businesses" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."businesses" TO "anon";

GRANT INSERT ON TABLE "public"."businesses" TO "anon";

GRANT SELECT ON TABLE "public"."businesses" TO "anon";

GRANT UPDATE ON TABLE "public"."businesses" TO "anon";

GRANT DELETE ON TABLE "public"."businesses" TO "authenticated";

GRANT INSERT ON TABLE "public"."businesses" TO "authenticated";

GRANT SELECT ON TABLE "public"."businesses" TO "authenticated";

GRANT UPDATE ON TABLE "public"."businesses" TO "authenticated";

GRANT DELETE ON TABLE "public"."businesses" TO "postgres";

GRANT INSERT ON TABLE "public"."businesses" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."businesses" TO "postgres";

GRANT REFERENCES ON TABLE "public"."businesses" TO "postgres";

GRANT SELECT ON TABLE "public"."businesses" TO "postgres";

GRANT TRIGGER ON TABLE "public"."businesses" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."businesses" TO "postgres";

GRANT UPDATE ON TABLE "public"."businesses" TO "postgres";

GRANT DELETE ON TABLE "public"."businesses" TO "service_role";

GRANT INSERT ON TABLE "public"."businesses" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."businesses" TO "service_role";

GRANT REFERENCES ON TABLE "public"."businesses" TO "service_role";

GRANT SELECT ON TABLE "public"."businesses" TO "service_role";

GRANT TRIGGER ON TABLE "public"."businesses" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."businesses" TO "service_role";

GRANT UPDATE ON TABLE "public"."businesses" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."camera_ai_jobs" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."camera_ai_jobs" TO "anon";

GRANT INSERT ON TABLE "public"."camera_ai_jobs" TO "anon";

GRANT SELECT ON TABLE "public"."camera_ai_jobs" TO "anon";

GRANT UPDATE ON TABLE "public"."camera_ai_jobs" TO "anon";

GRANT DELETE ON TABLE "public"."camera_ai_jobs" TO "authenticated";

GRANT INSERT ON TABLE "public"."camera_ai_jobs" TO "authenticated";

GRANT SELECT ON TABLE "public"."camera_ai_jobs" TO "authenticated";

GRANT UPDATE ON TABLE "public"."camera_ai_jobs" TO "authenticated";

GRANT DELETE ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT INSERT ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT REFERENCES ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT SELECT ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT TRIGGER ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT UPDATE ON TABLE "public"."camera_ai_jobs" TO "postgres";

GRANT DELETE ON TABLE "public"."camera_ai_jobs" TO "service_role";

GRANT INSERT ON TABLE "public"."camera_ai_jobs" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."camera_ai_jobs" TO "service_role";

GRANT REFERENCES ON TABLE "public"."camera_ai_jobs" TO "service_role";

GRANT SELECT ON TABLE "public"."camera_ai_jobs" TO "service_role";

GRANT TRIGGER ON TABLE "public"."camera_ai_jobs" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."camera_ai_jobs" TO "service_role";

GRANT UPDATE ON TABLE "public"."camera_ai_jobs" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."camera_detections" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."camera_detections" TO "anon";

GRANT INSERT ON TABLE "public"."camera_detections" TO "anon";

GRANT SELECT ON TABLE "public"."camera_detections" TO "anon";

GRANT UPDATE ON TABLE "public"."camera_detections" TO "anon";

GRANT DELETE ON TABLE "public"."camera_detections" TO "authenticated";

GRANT INSERT ON TABLE "public"."camera_detections" TO "authenticated";

GRANT SELECT ON TABLE "public"."camera_detections" TO "authenticated";

GRANT UPDATE ON TABLE "public"."camera_detections" TO "authenticated";

GRANT DELETE ON TABLE "public"."camera_detections" TO "postgres";

GRANT INSERT ON TABLE "public"."camera_detections" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."camera_detections" TO "postgres";

GRANT REFERENCES ON TABLE "public"."camera_detections" TO "postgres";

GRANT SELECT ON TABLE "public"."camera_detections" TO "postgres";

GRANT TRIGGER ON TABLE "public"."camera_detections" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."camera_detections" TO "postgres";

GRANT UPDATE ON TABLE "public"."camera_detections" TO "postgres";

GRANT DELETE ON TABLE "public"."camera_detections" TO "service_role";

GRANT INSERT ON TABLE "public"."camera_detections" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."camera_detections" TO "service_role";

GRANT REFERENCES ON TABLE "public"."camera_detections" TO "service_role";

GRANT SELECT ON TABLE "public"."camera_detections" TO "service_role";

GRANT TRIGGER ON TABLE "public"."camera_detections" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."camera_detections" TO "service_role";

GRANT UPDATE ON TABLE "public"."camera_detections" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."camera_event_links" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."camera_event_links" TO "anon";

GRANT INSERT ON TABLE "public"."camera_event_links" TO "anon";

GRANT SELECT ON TABLE "public"."camera_event_links" TO "anon";

GRANT UPDATE ON TABLE "public"."camera_event_links" TO "anon";

GRANT DELETE ON TABLE "public"."camera_event_links" TO "authenticated";

GRANT INSERT ON TABLE "public"."camera_event_links" TO "authenticated";

GRANT SELECT ON TABLE "public"."camera_event_links" TO "authenticated";

GRANT UPDATE ON TABLE "public"."camera_event_links" TO "authenticated";

GRANT DELETE ON TABLE "public"."camera_event_links" TO "postgres";

GRANT INSERT ON TABLE "public"."camera_event_links" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."camera_event_links" TO "postgres";

GRANT REFERENCES ON TABLE "public"."camera_event_links" TO "postgres";

GRANT SELECT ON TABLE "public"."camera_event_links" TO "postgres";

GRANT TRIGGER ON TABLE "public"."camera_event_links" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."camera_event_links" TO "postgres";

GRANT UPDATE ON TABLE "public"."camera_event_links" TO "postgres";

GRANT DELETE ON TABLE "public"."camera_event_links" TO "service_role";

GRANT INSERT ON TABLE "public"."camera_event_links" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."camera_event_links" TO "service_role";

GRANT REFERENCES ON TABLE "public"."camera_event_links" TO "service_role";

GRANT SELECT ON TABLE "public"."camera_event_links" TO "service_role";

GRANT TRIGGER ON TABLE "public"."camera_event_links" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."camera_event_links" TO "service_role";

GRANT UPDATE ON TABLE "public"."camera_event_links" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."camera_events" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."camera_events" TO "anon";

GRANT INSERT ON TABLE "public"."camera_events" TO "anon";

GRANT SELECT ON TABLE "public"."camera_events" TO "anon";

GRANT UPDATE ON TABLE "public"."camera_events" TO "anon";

GRANT DELETE ON TABLE "public"."camera_events" TO "authenticated";

GRANT INSERT ON TABLE "public"."camera_events" TO "authenticated";

GRANT SELECT ON TABLE "public"."camera_events" TO "authenticated";

GRANT UPDATE ON TABLE "public"."camera_events" TO "authenticated";

GRANT DELETE ON TABLE "public"."camera_events" TO "postgres";

GRANT INSERT ON TABLE "public"."camera_events" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."camera_events" TO "postgres";

GRANT REFERENCES ON TABLE "public"."camera_events" TO "postgres";

GRANT SELECT ON TABLE "public"."camera_events" TO "postgres";

GRANT TRIGGER ON TABLE "public"."camera_events" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."camera_events" TO "postgres";

GRANT UPDATE ON TABLE "public"."camera_events" TO "postgres";

GRANT DELETE ON TABLE "public"."camera_events" TO "service_role";

GRANT INSERT ON TABLE "public"."camera_events" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."camera_events" TO "service_role";

GRANT REFERENCES ON TABLE "public"."camera_events" TO "service_role";

GRANT SELECT ON TABLE "public"."camera_events" TO "service_role";

GRANT TRIGGER ON TABLE "public"."camera_events" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."camera_events" TO "service_role";

GRANT UPDATE ON TABLE "public"."camera_events" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."camera_health_logs" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."camera_health_logs" TO "anon";

GRANT INSERT ON TABLE "public"."camera_health_logs" TO "anon";

GRANT SELECT ON TABLE "public"."camera_health_logs" TO "anon";

GRANT UPDATE ON TABLE "public"."camera_health_logs" TO "anon";

GRANT DELETE ON TABLE "public"."camera_health_logs" TO "authenticated";

GRANT INSERT ON TABLE "public"."camera_health_logs" TO "authenticated";

GRANT SELECT ON TABLE "public"."camera_health_logs" TO "authenticated";

GRANT UPDATE ON TABLE "public"."camera_health_logs" TO "authenticated";

GRANT DELETE ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT INSERT ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT REFERENCES ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT SELECT ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT TRIGGER ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT UPDATE ON TABLE "public"."camera_health_logs" TO "postgres";

GRANT DELETE ON TABLE "public"."camera_health_logs" TO "service_role";

GRANT INSERT ON TABLE "public"."camera_health_logs" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."camera_health_logs" TO "service_role";

GRANT REFERENCES ON TABLE "public"."camera_health_logs" TO "service_role";

GRANT SELECT ON TABLE "public"."camera_health_logs" TO "service_role";

GRANT TRIGGER ON TABLE "public"."camera_health_logs" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."camera_health_logs" TO "service_role";

GRANT UPDATE ON TABLE "public"."camera_health_logs" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."camera_zones" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."camera_zones" TO "anon";

GRANT INSERT ON TABLE "public"."camera_zones" TO "anon";

GRANT SELECT ON TABLE "public"."camera_zones" TO "anon";

GRANT UPDATE ON TABLE "public"."camera_zones" TO "anon";

GRANT DELETE ON TABLE "public"."camera_zones" TO "authenticated";

GRANT INSERT ON TABLE "public"."camera_zones" TO "authenticated";

GRANT SELECT ON TABLE "public"."camera_zones" TO "authenticated";

GRANT UPDATE ON TABLE "public"."camera_zones" TO "authenticated";

GRANT DELETE ON TABLE "public"."camera_zones" TO "postgres";

GRANT INSERT ON TABLE "public"."camera_zones" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."camera_zones" TO "postgres";

GRANT REFERENCES ON TABLE "public"."camera_zones" TO "postgres";

GRANT SELECT ON TABLE "public"."camera_zones" TO "postgres";

GRANT TRIGGER ON TABLE "public"."camera_zones" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."camera_zones" TO "postgres";

GRANT UPDATE ON TABLE "public"."camera_zones" TO "postgres";

GRANT DELETE ON TABLE "public"."camera_zones" TO "service_role";

GRANT INSERT ON TABLE "public"."camera_zones" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."camera_zones" TO "service_role";

GRANT REFERENCES ON TABLE "public"."camera_zones" TO "service_role";

GRANT SELECT ON TABLE "public"."camera_zones" TO "service_role";

GRANT TRIGGER ON TABLE "public"."camera_zones" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."camera_zones" TO "service_role";

GRANT UPDATE ON TABLE "public"."camera_zones" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."cameras" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."cameras" TO "anon";

GRANT INSERT ON TABLE "public"."cameras" TO "anon";

GRANT SELECT ON TABLE "public"."cameras" TO "anon";

GRANT UPDATE ON TABLE "public"."cameras" TO "anon";

GRANT DELETE ON TABLE "public"."cameras" TO "authenticated";

GRANT INSERT ON TABLE "public"."cameras" TO "authenticated";

GRANT SELECT ON TABLE "public"."cameras" TO "authenticated";

GRANT UPDATE ON TABLE "public"."cameras" TO "authenticated";

GRANT DELETE ON TABLE "public"."cameras" TO "postgres";

GRANT INSERT ON TABLE "public"."cameras" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."cameras" TO "postgres";

GRANT REFERENCES ON TABLE "public"."cameras" TO "postgres";

GRANT SELECT ON TABLE "public"."cameras" TO "postgres";

GRANT TRIGGER ON TABLE "public"."cameras" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."cameras" TO "postgres";

GRANT UPDATE ON TABLE "public"."cameras" TO "postgres";

GRANT DELETE ON TABLE "public"."cameras" TO "service_role";

GRANT INSERT ON TABLE "public"."cameras" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."cameras" TO "service_role";

GRANT REFERENCES ON TABLE "public"."cameras" TO "service_role";

GRANT SELECT ON TABLE "public"."cameras" TO "service_role";

GRANT TRIGGER ON TABLE "public"."cameras" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."cameras" TO "service_role";

GRANT UPDATE ON TABLE "public"."cameras" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."cash_transactions" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."cash_transactions" TO "anon";

GRANT INSERT ON TABLE "public"."cash_transactions" TO "anon";

GRANT SELECT ON TABLE "public"."cash_transactions" TO "anon";

GRANT UPDATE ON TABLE "public"."cash_transactions" TO "anon";

GRANT DELETE ON TABLE "public"."cash_transactions" TO "authenticated";

GRANT INSERT ON TABLE "public"."cash_transactions" TO "authenticated";

GRANT SELECT ON TABLE "public"."cash_transactions" TO "authenticated";

GRANT UPDATE ON TABLE "public"."cash_transactions" TO "authenticated";

GRANT DELETE ON TABLE "public"."cash_transactions" TO "postgres";

GRANT INSERT ON TABLE "public"."cash_transactions" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."cash_transactions" TO "postgres";

GRANT REFERENCES ON TABLE "public"."cash_transactions" TO "postgres";

GRANT SELECT ON TABLE "public"."cash_transactions" TO "postgres";

GRANT TRIGGER ON TABLE "public"."cash_transactions" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."cash_transactions" TO "postgres";

GRANT UPDATE ON TABLE "public"."cash_transactions" TO "postgres";

GRANT DELETE ON TABLE "public"."cash_transactions" TO "service_role";

GRANT INSERT ON TABLE "public"."cash_transactions" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."cash_transactions" TO "service_role";

GRANT REFERENCES ON TABLE "public"."cash_transactions" TO "service_role";

GRANT SELECT ON TABLE "public"."cash_transactions" TO "service_role";

GRANT TRIGGER ON TABLE "public"."cash_transactions" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."cash_transactions" TO "service_role";

GRANT UPDATE ON TABLE "public"."cash_transactions" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."employee_activity" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."employee_activity" TO "anon";

GRANT INSERT ON TABLE "public"."employee_activity" TO "anon";

GRANT SELECT ON TABLE "public"."employee_activity" TO "anon";

GRANT UPDATE ON TABLE "public"."employee_activity" TO "anon";

GRANT DELETE ON TABLE "public"."employee_activity" TO "authenticated";

GRANT INSERT ON TABLE "public"."employee_activity" TO "authenticated";

GRANT SELECT ON TABLE "public"."employee_activity" TO "authenticated";

GRANT UPDATE ON TABLE "public"."employee_activity" TO "authenticated";

GRANT DELETE ON TABLE "public"."employee_activity" TO "postgres";

GRANT INSERT ON TABLE "public"."employee_activity" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."employee_activity" TO "postgres";

GRANT REFERENCES ON TABLE "public"."employee_activity" TO "postgres";

GRANT SELECT ON TABLE "public"."employee_activity" TO "postgres";

GRANT TRIGGER ON TABLE "public"."employee_activity" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."employee_activity" TO "postgres";

GRANT UPDATE ON TABLE "public"."employee_activity" TO "postgres";

GRANT DELETE ON TABLE "public"."employee_activity" TO "service_role";

GRANT INSERT ON TABLE "public"."employee_activity" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."employee_activity" TO "service_role";

GRANT REFERENCES ON TABLE "public"."employee_activity" TO "service_role";

GRANT SELECT ON TABLE "public"."employee_activity" TO "service_role";

GRANT TRIGGER ON TABLE "public"."employee_activity" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."employee_activity" TO "service_role";

GRANT UPDATE ON TABLE "public"."employee_activity" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."employee_branch_assignments" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."employee_branch_assignments" TO "authenticated";

GRANT DELETE ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT INSERT ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT REFERENCES ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT SELECT ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT TRIGGER ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT UPDATE ON TABLE "public"."employee_branch_assignments" TO "postgres";

GRANT DELETE ON TABLE "public"."employee_branch_assignments" TO "service_role";

GRANT INSERT ON TABLE "public"."employee_branch_assignments" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."employee_branch_assignments" TO "service_role";

GRANT REFERENCES ON TABLE "public"."employee_branch_assignments" TO "service_role";

GRANT SELECT ON TABLE "public"."employee_branch_assignments" TO "service_role";

GRANT TRIGGER ON TABLE "public"."employee_branch_assignments" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."employee_branch_assignments" TO "service_role";

GRANT UPDATE ON TABLE "public"."employee_branch_assignments" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."employee_permissions" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."employee_permissions" TO "anon";

GRANT SELECT ON TABLE "public"."employee_permissions" TO "authenticated";

GRANT DELETE ON TABLE "public"."employee_permissions" TO "postgres";

GRANT INSERT ON TABLE "public"."employee_permissions" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."employee_permissions" TO "postgres";

GRANT REFERENCES ON TABLE "public"."employee_permissions" TO "postgres";

GRANT SELECT ON TABLE "public"."employee_permissions" TO "postgres";

GRANT TRIGGER ON TABLE "public"."employee_permissions" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."employee_permissions" TO "postgres";

GRANT UPDATE ON TABLE "public"."employee_permissions" TO "postgres";

GRANT DELETE ON TABLE "public"."employee_permissions" TO "service_role";

GRANT INSERT ON TABLE "public"."employee_permissions" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."employee_permissions" TO "service_role";

GRANT REFERENCES ON TABLE "public"."employee_permissions" TO "service_role";

GRANT SELECT ON TABLE "public"."employee_permissions" TO "service_role";

GRANT TRIGGER ON TABLE "public"."employee_permissions" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."employee_permissions" TO "service_role";

GRANT UPDATE ON TABLE "public"."employee_permissions" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."employees" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."employees" TO "anon";

GRANT SELECT ON TABLE "public"."employees" TO "authenticated";

GRANT DELETE ON TABLE "public"."employees" TO "postgres";

GRANT INSERT ON TABLE "public"."employees" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."employees" TO "postgres";

GRANT REFERENCES ON TABLE "public"."employees" TO "postgres";

GRANT SELECT ON TABLE "public"."employees" TO "postgres";

GRANT TRIGGER ON TABLE "public"."employees" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."employees" TO "postgres";

GRANT UPDATE ON TABLE "public"."employees" TO "postgres";

GRANT DELETE ON TABLE "public"."employees" TO "service_role";

GRANT INSERT ON TABLE "public"."employees" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."employees" TO "service_role";

GRANT REFERENCES ON TABLE "public"."employees" TO "service_role";

GRANT SELECT ON TABLE "public"."employees" TO "service_role";

GRANT TRIGGER ON TABLE "public"."employees" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."employees" TO "service_role";

GRANT UPDATE ON TABLE "public"."employees" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."expenses" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."expenses" TO "anon";

GRANT INSERT ON TABLE "public"."expenses" TO "anon";

GRANT SELECT ON TABLE "public"."expenses" TO "anon";

GRANT UPDATE ON TABLE "public"."expenses" TO "anon";

GRANT DELETE ON TABLE "public"."expenses" TO "authenticated";

GRANT INSERT ON TABLE "public"."expenses" TO "authenticated";

GRANT SELECT ON TABLE "public"."expenses" TO "authenticated";

GRANT UPDATE ON TABLE "public"."expenses" TO "authenticated";

GRANT DELETE ON TABLE "public"."expenses" TO "postgres";

GRANT INSERT ON TABLE "public"."expenses" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."expenses" TO "postgres";

GRANT REFERENCES ON TABLE "public"."expenses" TO "postgres";

GRANT SELECT ON TABLE "public"."expenses" TO "postgres";

GRANT TRIGGER ON TABLE "public"."expenses" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."expenses" TO "postgres";

GRANT UPDATE ON TABLE "public"."expenses" TO "postgres";

GRANT DELETE ON TABLE "public"."expenses" TO "service_role";

GRANT INSERT ON TABLE "public"."expenses" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."expenses" TO "service_role";

GRANT REFERENCES ON TABLE "public"."expenses" TO "service_role";

GRANT SELECT ON TABLE "public"."expenses" TO "service_role";

GRANT TRIGGER ON TABLE "public"."expenses" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."expenses" TO "service_role";

GRANT UPDATE ON TABLE "public"."expenses" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."financial_transactions" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."financial_transactions" TO "anon";

GRANT INSERT ON TABLE "public"."financial_transactions" TO "anon";

GRANT SELECT ON TABLE "public"."financial_transactions" TO "anon";

GRANT UPDATE ON TABLE "public"."financial_transactions" TO "anon";

GRANT DELETE ON TABLE "public"."financial_transactions" TO "authenticated";

GRANT INSERT ON TABLE "public"."financial_transactions" TO "authenticated";

GRANT SELECT ON TABLE "public"."financial_transactions" TO "authenticated";

GRANT UPDATE ON TABLE "public"."financial_transactions" TO "authenticated";

GRANT DELETE ON TABLE "public"."financial_transactions" TO "postgres";

GRANT INSERT ON TABLE "public"."financial_transactions" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."financial_transactions" TO "postgres";

GRANT REFERENCES ON TABLE "public"."financial_transactions" TO "postgres";

GRANT SELECT ON TABLE "public"."financial_transactions" TO "postgres";

GRANT TRIGGER ON TABLE "public"."financial_transactions" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."financial_transactions" TO "postgres";

GRANT UPDATE ON TABLE "public"."financial_transactions" TO "postgres";

GRANT DELETE ON TABLE "public"."financial_transactions" TO "service_role";

GRANT INSERT ON TABLE "public"."financial_transactions" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."financial_transactions" TO "service_role";

GRANT REFERENCES ON TABLE "public"."financial_transactions" TO "service_role";

GRANT SELECT ON TABLE "public"."financial_transactions" TO "service_role";

GRANT TRIGGER ON TABLE "public"."financial_transactions" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."financial_transactions" TO "service_role";

GRANT UPDATE ON TABLE "public"."financial_transactions" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."inventory" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."inventory" TO "anon";

GRANT SELECT ON TABLE "public"."inventory" TO "authenticated";

GRANT DELETE ON TABLE "public"."inventory" TO "postgres";

GRANT INSERT ON TABLE "public"."inventory" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."inventory" TO "postgres";

GRANT REFERENCES ON TABLE "public"."inventory" TO "postgres";

GRANT SELECT ON TABLE "public"."inventory" TO "postgres";

GRANT TRIGGER ON TABLE "public"."inventory" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."inventory" TO "postgres";

GRANT UPDATE ON TABLE "public"."inventory" TO "postgres";

GRANT DELETE ON TABLE "public"."inventory" TO "service_role";

GRANT INSERT ON TABLE "public"."inventory" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."inventory" TO "service_role";

GRANT REFERENCES ON TABLE "public"."inventory" TO "service_role";

GRANT SELECT ON TABLE "public"."inventory" TO "service_role";

GRANT TRIGGER ON TABLE "public"."inventory" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."inventory" TO "service_role";

GRANT UPDATE ON TABLE "public"."inventory" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."inventory_movements" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."inventory_movements" TO "anon";

GRANT SELECT ON TABLE "public"."inventory_movements" TO "authenticated";

GRANT DELETE ON TABLE "public"."inventory_movements" TO "postgres";

GRANT INSERT ON TABLE "public"."inventory_movements" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."inventory_movements" TO "postgres";

GRANT REFERENCES ON TABLE "public"."inventory_movements" TO "postgres";

GRANT SELECT ON TABLE "public"."inventory_movements" TO "postgres";

GRANT TRIGGER ON TABLE "public"."inventory_movements" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."inventory_movements" TO "postgres";

GRANT UPDATE ON TABLE "public"."inventory_movements" TO "postgres";

GRANT DELETE ON TABLE "public"."inventory_movements" TO "service_role";

GRANT INSERT ON TABLE "public"."inventory_movements" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."inventory_movements" TO "service_role";

GRANT REFERENCES ON TABLE "public"."inventory_movements" TO "service_role";

GRANT SELECT ON TABLE "public"."inventory_movements" TO "service_role";

GRANT TRIGGER ON TABLE "public"."inventory_movements" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."inventory_movements" TO "service_role";

GRANT UPDATE ON TABLE "public"."inventory_movements" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."permissions" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."permissions" TO "anon";

GRANT SELECT ON TABLE "public"."permissions" TO "authenticated";

GRANT DELETE ON TABLE "public"."permissions" TO "postgres";

GRANT INSERT ON TABLE "public"."permissions" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."permissions" TO "postgres";

GRANT REFERENCES ON TABLE "public"."permissions" TO "postgres";

GRANT SELECT ON TABLE "public"."permissions" TO "postgres";

GRANT TRIGGER ON TABLE "public"."permissions" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."permissions" TO "postgres";

GRANT UPDATE ON TABLE "public"."permissions" TO "postgres";

GRANT DELETE ON TABLE "public"."permissions" TO "service_role";

GRANT INSERT ON TABLE "public"."permissions" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."permissions" TO "service_role";

GRANT REFERENCES ON TABLE "public"."permissions" TO "service_role";

GRANT SELECT ON TABLE "public"."permissions" TO "service_role";

GRANT TRIGGER ON TABLE "public"."permissions" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."permissions" TO "service_role";

GRANT UPDATE ON TABLE "public"."permissions" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."products" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."products" TO "anon";

GRANT DELETE ON TABLE "public"."products" TO "authenticated";

GRANT DELETE ON TABLE "public"."products" TO "postgres";

GRANT INSERT ON TABLE "public"."products" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."products" TO "postgres";

GRANT REFERENCES ON TABLE "public"."products" TO "postgres";

GRANT SELECT ON TABLE "public"."products" TO "postgres";

GRANT TRIGGER ON TABLE "public"."products" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."products" TO "postgres";

GRANT UPDATE ON TABLE "public"."products" TO "postgres";

GRANT DELETE ON TABLE "public"."products" TO "service_role";

GRANT INSERT ON TABLE "public"."products" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."products" TO "service_role";

GRANT REFERENCES ON TABLE "public"."products" TO "service_role";

GRANT SELECT ON TABLE "public"."products" TO "service_role";

GRANT TRIGGER ON TABLE "public"."products" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."products" TO "service_role";

GRANT UPDATE ON TABLE "public"."products" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."recordings" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT DELETE ON TABLE "public"."recordings" TO "anon";

GRANT INSERT ON TABLE "public"."recordings" TO "anon";

GRANT SELECT ON TABLE "public"."recordings" TO "anon";

GRANT UPDATE ON TABLE "public"."recordings" TO "anon";

GRANT DELETE ON TABLE "public"."recordings" TO "authenticated";

GRANT INSERT ON TABLE "public"."recordings" TO "authenticated";

GRANT SELECT ON TABLE "public"."recordings" TO "authenticated";

GRANT UPDATE ON TABLE "public"."recordings" TO "authenticated";

GRANT DELETE ON TABLE "public"."recordings" TO "postgres";

GRANT INSERT ON TABLE "public"."recordings" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."recordings" TO "postgres";

GRANT REFERENCES ON TABLE "public"."recordings" TO "postgres";

GRANT SELECT ON TABLE "public"."recordings" TO "postgres";

GRANT TRIGGER ON TABLE "public"."recordings" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."recordings" TO "postgres";

GRANT UPDATE ON TABLE "public"."recordings" TO "postgres";

GRANT DELETE ON TABLE "public"."recordings" TO "service_role";

GRANT INSERT ON TABLE "public"."recordings" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."recordings" TO "service_role";

GRANT REFERENCES ON TABLE "public"."recordings" TO "service_role";

GRANT SELECT ON TABLE "public"."recordings" TO "service_role";

GRANT TRIGGER ON TABLE "public"."recordings" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."recordings" TO "service_role";

GRANT UPDATE ON TABLE "public"."recordings" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."sale_items" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."sale_items" TO "anon";

GRANT SELECT ON TABLE "public"."sale_items" TO "authenticated";

GRANT DELETE ON TABLE "public"."sale_items" TO "postgres";

GRANT INSERT ON TABLE "public"."sale_items" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."sale_items" TO "postgres";

GRANT REFERENCES ON TABLE "public"."sale_items" TO "postgres";

GRANT SELECT ON TABLE "public"."sale_items" TO "postgres";

GRANT TRIGGER ON TABLE "public"."sale_items" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."sale_items" TO "postgres";

GRANT UPDATE ON TABLE "public"."sale_items" TO "postgres";

GRANT DELETE ON TABLE "public"."sale_items" TO "service_role";

GRANT INSERT ON TABLE "public"."sale_items" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."sale_items" TO "service_role";

GRANT REFERENCES ON TABLE "public"."sale_items" TO "service_role";

GRANT SELECT ON TABLE "public"."sale_items" TO "service_role";

GRANT TRIGGER ON TABLE "public"."sale_items" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."sale_items" TO "service_role";

GRANT UPDATE ON TABLE "public"."sale_items" TO "service_role";

REVOKE ALL PRIVILEGES ON TABLE "public"."sales" FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT SELECT ON TABLE "public"."sales" TO "anon";

GRANT SELECT ON TABLE "public"."sales" TO "authenticated";

GRANT DELETE ON TABLE "public"."sales" TO "postgres";

GRANT INSERT ON TABLE "public"."sales" TO "postgres";

GRANT MAINTAIN ON TABLE "public"."sales" TO "postgres";

GRANT REFERENCES ON TABLE "public"."sales" TO "postgres";

GRANT SELECT ON TABLE "public"."sales" TO "postgres";

GRANT TRIGGER ON TABLE "public"."sales" TO "postgres";

GRANT TRUNCATE ON TABLE "public"."sales" TO "postgres";

GRANT UPDATE ON TABLE "public"."sales" TO "postgres";

GRANT DELETE ON TABLE "public"."sales" TO "service_role";

GRANT INSERT ON TABLE "public"."sales" TO "service_role";

GRANT MAINTAIN ON TABLE "public"."sales" TO "service_role";

GRANT REFERENCES ON TABLE "public"."sales" TO "service_role";

GRANT SELECT ON TABLE "public"."sales" TO "service_role";

GRANT TRIGGER ON TABLE "public"."sales" TO "service_role";

GRANT TRUNCATE ON TABLE "public"."sales" TO "service_role";

GRANT UPDATE ON TABLE "public"."sales" TO "service_role";

GRANT INSERT ("id") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("id") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("id") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("business_id") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("business_id") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("business_id") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("sku") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("sku") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("sku") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("barcode") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("barcode") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("barcode") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("name") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("name") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("name") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("description") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("description") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("description") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("category") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("category") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("category") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("brand") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("brand") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("brand") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("unit") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("unit") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("unit") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("selling_price") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("selling_price") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("selling_price") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("reorder_level") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("reorder_level") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("reorder_level") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("image_url") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("image_url") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("image_url") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("is_active") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("is_active") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("is_active") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("created_at") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("created_at") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("created_at") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("updated_at") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("updated_at") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("updated_at") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("quantity") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("quantity") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("quantity") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("low_stock_threshold") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("low_stock_threshold") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("low_stock_threshold") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("supplier") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("supplier") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("supplier") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("location") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("location") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("location") ON TABLE "public"."products" TO "authenticated";

GRANT INSERT ("active") ON TABLE "public"."products" TO "authenticated";

GRANT SELECT ("active") ON TABLE "public"."products" TO "authenticated";

GRANT UPDATE ("active") ON TABLE "public"."products" TO "authenticated";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."audit_product_price"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."audit_product_price"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."branch_record_access"(business uuid, branch uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."branch_record_access"(business uuid, branch uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."branch_record_access"(business uuid, branch uuid) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."business_timestamp"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."business_timestamp"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."can_read_membership"(business uuid, member_user uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."can_read_membership"(business uuid, member_user uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."can_read_membership"(business uuid, member_user uuid) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."can_read_staff"(business uuid, employee uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."can_read_staff"(business uuid, employee uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."can_read_staff"(business uuid, employee uuid) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."complete_pos_sale_with_receipt"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."complete_pos_sale_with_receipt"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."consume_camera_explanation_request"(p_user_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."consume_camera_explanation_request"(p_user_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "private"."consume_camera_explanation_request"(p_user_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."guard_business_foundation"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."guard_business_foundation"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."guard_legacy_stock"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."guard_legacy_stock"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."guard_price_assignment"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."guard_price_assignment"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."guard_product_fields"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."guard_product_fields"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."guard_sale_item_product"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."guard_sale_item_product"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."guard_staff_scope"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."guard_staff_scope"() TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."has_branch_access"(business uuid, branch uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."has_branch_access"(business uuid, branch uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."has_branch_access"(business uuid, branch uuid) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."has_business_permission"(business uuid, permission text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."has_business_permission"(business uuid, permission text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."has_business_permission"(business uuid, permission text) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."process_trexven_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."process_trexven_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."sales_history_access"(business uuid, sold_at timestamp with time zone) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."sales_history_access"(business uuid, sold_at timestamp with time zone) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."sales_history_access"(business uuid, sold_at timestamp with time zone) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."submit_sale_request"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."submit_sale_request"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "private"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "private"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) TO "authenticated";

GRANT EXECUTE ON FUNCTION "private"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) TO "postgres";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."angel_sales_summary"(p_business_id uuid, p_day_start timestamp with time zone) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."angel_sales_summary"(p_business_id uuid, p_day_start timestamp with time zone) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."angel_sales_summary"(p_business_id uuid, p_day_start timestamp with time zone) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."assert_trexven_staff_access"(p_business_id uuid, p_employee_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."assert_trexven_staff_access"(p_business_id uuid, p_employee_id uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."assert_trexven_staff_access"(p_business_id uuid, p_employee_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."assert_trexven_staff_access"(p_business_id uuid, p_employee_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."camera_event_to_alert"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."camera_event_to_alert"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."camera_event_to_alert"() TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."complete_pos_sale"(p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."complete_trexven_onboarding"(p_business_name text, p_business_type text, p_country text, p_currency text, p_address text, p_phone text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."complete_trexven_onboarding"(p_business_name text, p_business_type text, p_country text, p_currency text, p_address text, p_phone text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."complete_trexven_onboarding"(p_business_name text, p_business_type text, p_country text, p_currency text, p_address text, p_phone text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."complete_trexven_onboarding"(p_business_name text, p_business_type text, p_country text, p_currency text, p_address text, p_phone text) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."consume_angel_request"(p_user_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."consume_angel_request"(p_user_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."consume_angel_request"(p_user_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."consume_camera_explanation_request"(p_user_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."consume_camera_explanation_request"(p_user_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."consume_camera_explanation_request"(p_user_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."create_trexven_branch"(p_business_id uuid, p_name text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."create_trexven_branch"(p_business_id uuid, p_name text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."create_trexven_branch"(p_business_id uuid, p_name text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."create_trexven_branch"(p_business_id uuid, p_name text) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."finalize_trexven_employee"(p_business_id uuid, p_user_id uuid, p_name text, p_email text, p_phone text, p_role text, p_employee_code text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."finalize_trexven_employee"(p_business_id uuid, p_user_id uuid, p_name text, p_email text, p_phone text, p_role text, p_employee_code text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."finalize_trexven_employee"(p_business_id uuid, p_user_id uuid, p_name text, p_email text, p_phone text, p_role text, p_employee_code text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."finalize_trexven_employee"(p_business_id uuid, p_user_id uuid, p_name text, p_email text, p_phone text, p_role text, p_employee_code text) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."get_camera_activity_summary"(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_camera_activity_summary"(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone) TO PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."get_camera_activity_summary"(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone) TO "anon";

GRANT EXECUTE ON FUNCTION "public"."get_camera_activity_summary"(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."get_camera_activity_summary"(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_camera_activity_summary"(p_business_id uuid, p_from timestamp with time zone, p_to timestamp with time zone) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."get_camera_dashboard"(p_business_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_camera_dashboard"(p_business_id uuid) TO PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."get_camera_dashboard"(p_business_id uuid) TO "anon";

GRANT EXECUTE ON FUNCTION "public"."get_camera_dashboard"(p_business_id uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."get_camera_dashboard"(p_business_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_camera_dashboard"(p_business_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."get_trexven_business_day"(p_business_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_trexven_business_day"(p_business_id uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."get_trexven_business_day"(p_business_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_trexven_business_day"(p_business_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."is_business_member"(target_business_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."is_business_member"(target_business_id uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."is_business_member"(target_business_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_business_member"(target_business_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."record_trexven_sale"(p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."set_trexven_branch_assignment"(p_employee_id uuid, p_branch_id uuid, p_active boolean) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_branch_assignment"(p_employee_id uuid, p_branch_id uuid, p_active boolean) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_branch_assignment"(p_employee_id uuid, p_branch_id uuid, p_active boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_branch_assignment"(p_employee_id uuid, p_branch_id uuid, p_active boolean) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."set_trexven_branch_status"(p_branch_id uuid, p_active boolean) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_branch_status"(p_branch_id uuid, p_active boolean) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_branch_status"(p_branch_id uuid, p_active boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_branch_status"(p_branch_id uuid, p_active boolean) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."set_trexven_employee_permission"(p_employee_id uuid, p_permission text, p_granted boolean) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_employee_permission"(p_employee_id uuid, p_permission text, p_granted boolean) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_employee_permission"(p_employee_id uuid, p_permission text, p_granted boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_employee_permission"(p_employee_id uuid, p_permission text, p_granted boolean) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."set_trexven_employee_status"(p_employee_id uuid, p_status text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_employee_status"(p_employee_id uuid, p_status text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_employee_status"(p_employee_id uuid, p_status text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_trexven_employee_status"(p_employee_id uuid, p_status text) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."submit_trexven_branch_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."submit_trexven_branch_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."submit_trexven_branch_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."submit_trexven_branch_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean, p_branch_id uuid) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."submit_trexven_sale"(p_request_id uuid, p_business_id uuid, p_employee_id uuid, p_total numeric, p_payment_method text, p_items jsonb, p_quick boolean) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."update_businesses_updated_at"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."update_businesses_updated_at"() TO PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."update_businesses_updated_at"() TO "anon";

GRANT EXECUTE ON FUNCTION "public"."update_businesses_updated_at"() TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."update_businesses_updated_at"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."update_businesses_updated_at"() TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."update_trexven_employee"(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."update_trexven_employee"(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."update_trexven_employee"(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."update_trexven_employee"(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text) TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."update_updated_at"() FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."update_updated_at"() TO PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."update_updated_at"() TO "anon";

GRANT EXECUTE ON FUNCTION "public"."update_updated_at"() TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."update_updated_at"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."update_updated_at"() TO "service_role";

REVOKE ALL PRIVILEGES ON FUNCTION "public"."user_owns_business"(target_business_id uuid) FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

GRANT EXECUTE ON FUNCTION "public"."user_owns_business"(target_business_id uuid) TO "authenticated";

GRANT EXECUTE ON FUNCTION "public"."user_owns_business"(target_business_id uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."user_owns_business"(target_business_id uuid) TO "service_role";

-- postgres-scoped defaults restored; platform supabase_admin defaults are verified, not mutated.

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON SEQUENCES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT USAGE ON SEQUENCES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON SEQUENCES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT USAGE ON SEQUENCES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON SEQUENCES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT USAGE ON SEQUENCES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON SEQUENCES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT USAGE ON SEQUENCES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT EXECUTE ON FUNCTIONS TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT EXECUTE ON FUNCTIONS TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT EXECUTE ON FUNCTIONS TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT EXECUTE ON FUNCTIONS TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, "anon", "authenticated", "postgres", "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT INSERT ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT DELETE ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT TRUNCATE ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT TRIGGER ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT MAINTAIN ON TABLES TO "postgres";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT INSERT ON TABLES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON TABLES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON TABLES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT DELETE ON TABLES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT INSERT ON TABLES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON TABLES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON TABLES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT DELETE ON TABLES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT INSERT ON TABLES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT ON TABLES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON TABLES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT DELETE ON TABLES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT TRUNCATE ON TABLES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES ON TABLES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT TRIGGER ON TABLES TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT MAINTAIN ON TABLES TO "service_role";

-- supabase_admin public defaults are platform-owned and already match staging.

-- Original grantor identities are retained in recovered_catalog.json.

-- Realtime uses the pre-existing managed publication; no subscriptions/endpoints copied.

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."alerts";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."camera_detections";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."camera_events";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."cameras";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."employees";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."products";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."sales";

COMMIT;

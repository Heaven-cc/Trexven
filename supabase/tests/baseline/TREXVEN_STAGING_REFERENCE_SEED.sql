-- REVIEW ONLY, NOT APPLIED. Reference configuration from repository migrations,
-- not exported production rows. Separate from the schema-only baseline.
-- Source: 20260823100000_employee_management.sql (permission IDs/descriptions)
-- and 20260819180000_camera_ai_fixes.sql (private bucket definitions).
BEGIN;
DO $reference_seed_guard$ BEGIN
 IF current_setting('trexven.staging_project_ref', true) IS DISTINCT FROM 'qysspzlfiysekvxnlzsh' THEN
   RAISE EXCEPTION 'Verified staging executor setting required';
 END IF;
 IF EXISTS (SELECT 1 FROM public.businesses) OR EXISTS (SELECT 1 FROM public.employees)
 OR EXISTS (SELECT 1 FROM auth.users) THEN
   RAISE EXCEPTION 'Reference seed requires an empty verified staging baseline';
 END IF;
END $reference_seed_guard$;

INSERT INTO public.permissions (id, description) VALUES
 ('pos_access', 'Access Trexven POS'),
 ('complete_sales', 'Process and complete transactions'),
 ('add_products', 'Add new products to inventory'),
 ('edit_products', 'Modify existing product details'),
 ('view_inventory', 'View stock levels and reports'),
 ('manage_employees', 'Add, edit, or suspend employees'),
 ('view_camera_events', 'Access security camera feed and events')
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) VALUES
 ('recordings', 'recordings', false),
 ('event-snapshots', 'event-snapshots', false)
ON CONFLICT (id) DO NOTHING;

DO $private_bucket_guard$ BEGIN
 IF EXISTS (SELECT 1 FROM storage.buckets WHERE id IN ('recordings','event-snapshots') AND public) THEN
   RAISE EXCEPTION 'Expected private staging buckets; do not silently change an existing bucket';
 END IF;
END $private_bucket_guard$;
COMMIT;

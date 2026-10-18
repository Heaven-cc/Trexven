-- Checkpoint B: permission definitions only; optional Storage buckets excluded.
-- Repository source: 20260823100000_employee_management.sql.
begin;
set local trexven.staging_project_ref='qysspzlfiysekvxnlzsh';
do $$ begin
 if current_setting('trexven.staging_project_ref',true)<>'qysspzlfiysekvxnlzsh'
 or exists(select 1 from public.businesses) or exists(select 1 from auth.users)
 then raise exception 'Empty verified staging baseline required'; end if;
end $$;
insert into public.permissions(id,description) values
 ('pos_access','Access Trexven POS'),
 ('complete_sales','Process and complete transactions'),
 ('add_products','Add new products to inventory'),
 ('edit_products','Modify existing product details'),
 ('view_inventory','View stock levels and reports'),
 ('manage_employees','Add, edit, or suspend employees'),
 ('view_camera_events','Access security camera feed and events')
on conflict(id) do nothing;
commit;

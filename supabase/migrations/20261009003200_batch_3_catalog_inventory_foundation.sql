-- Batch 3, LOCAL DISPOSABLE VERIFIED BEFORE ANY PRODUCTION APPROVAL.
-- Requires all six immutable Batch 2 migrations. No historical product rewrite.
begin;
do $$ begin
 if to_regprocedure('public.get_trexven_business_day(uuid)') is null then
  raise exception 'Apply the six reviewed Batch 2 migrations before Batch 3'; end if;
end $$;
create table public.product_groups(
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id),
 name text not null check(length(btrim(name)) between 1 and 200), unique(business_id,name),
 created_at timestamptz not null default now(), unique(id,business_id));
create index product_groups_business on public.product_groups(business_id);
alter table public.product_groups enable row level security;
create policy "Catalog group read" on public.product_groups for select to authenticated
 using(private.has_business_permission(business_id,'view_inventory') or public.user_owns_business(business_id));
revoke all on public.product_groups from public,anon,authenticated;
grant select on public.product_groups to authenticated;
alter table public.products add column catalog_group_id uuid;
alter table public.products add column variant_attributes jsonb not null default '{}';
alter table public.products add constraint batch_3_variant_group foreign key(catalog_group_id,business_id)
 references public.product_groups(id,business_id) not valid;
alter table public.products add constraint batch_3_variant_attributes check(jsonb_typeof(variant_attributes)='object');
create index batch_3_group_products on public.products(catalog_group_id,business_id) where catalog_group_id is not null;
-- Preserve manufacturer barcode bytes; uniqueness compares trimmed nonempty values.
create unique index batch_3_business_sku on public.products(business_id,btrim(sku)) where nullif(btrim(sku),'') is not null;
create unique index batch_3_business_barcode on public.products(business_id,btrim(barcode)) where nullif(btrim(barcode),'') is not null;
grant select(catalog_group_id,variant_attributes) on public.products to authenticated;
-- Mutations use the audited RPC; existing direct non-price fields retain Batch 2 authorization.
create table private.catalog_requests(
 request_id uuid primary key, business_id uuid not null references public.businesses(id),
 actor_id uuid not null references auth.users(id), payload jsonb not null, response jsonb not null,
 created_at timestamptz not null default now());
alter table private.catalog_requests enable row level security;
revoke all on private.catalog_requests from public,anon,authenticated;
create index catalog_requests_business on private.catalog_requests(business_id);
create table private.catalog_low_stock_state(
 product_id uuid primary key references public.products(id),business_id uuid not null references public.businesses(id),
 below_threshold boolean not null);
alter table private.catalog_low_stock_state enable row level security;
revoke all on private.catalog_low_stock_state from public,anon,authenticated;

create function private.catalog_context(business uuid, permission text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 -- Lock the same business/employee/membership authorization rows as checkout.
 perform id from public.businesses where id=business for share;
 perform id from public.employees where business_id=business and user_id=auth.uid() for share;
 perform id from public.business_members where business_id=business and user_id=auth.uid() for share;
 if not private.has_business_permission(business,permission) then
  raise exception 'Catalog permission denied' using errcode='42501'; end if;
 -- The unactivated legacy branch stock contract remains the only write workflow.
 if exists(select 1 from public.businesses where id=business and branches_enabled) then
  raise exception 'Branch catalog mutation workflow is not activated'; end if;
end $$;
revoke all on function private.catalog_context(uuid,text) from public,anon,authenticated;

create or replace function private.guard_product_fields()
returns trigger language plpgsql security invoker set search_path='' as $$
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
   if not can_price and (to_jsonb(new)-array['name','barcode','sku','brand','category','description','image_url','unit','supplier','location','reorder_level','low_stock_threshold','quantity','active','is_active','updated_at','catalog_group_id','variant_attributes'])
     is distinct from (to_jsonb(old)-array['name','barcode','sku','brand','category','description','image_url','unit','supplier','location','reorder_level','low_stock_threshold','quantity','active','is_active','updated_at','catalog_group_id','variant_attributes']) then
     raise exception 'Only permitted non-price product fields may change' using errcode='42501'; end if;
   if not can_price and (new.selling_price is distinct from old.selling_price) then
     raise exception 'Price permission denied' using errcode='42501'; end if;
 end if;
 if new.selling_price is not null and (new.selling_price<0 or new.selling_price::text in ('NaN','Infinity','-Infinity')) then
   raise exception 'Invalid selling price'; end if;
 if new.selling_price is null then new.active:=false; new.is_active:=false; end if;
 return new;
end $$;


-- History checks must see all referenced sales, even when staff cannot read reports.
create function private.catalog_guard_unit_history() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if coalesce(new.unit,'piece') is distinct from coalesce(old.unit,'piece') and
 (coalesce(old.quantity,0)<>0 or exists(select 1 from public.sale_items where product_id=old.id)
 or exists(select 1 from public.inventory_movements where product_id=old.id)) then
  raise exception 'Unit is immutable after stock or ledger activity'; end if;
 return new;
end $$;
revoke all on function private.catalog_guard_unit_history() from public,anon,authenticated;
create trigger batch_3_unit_history before update of unit on public.products for each row execute function private.catalog_guard_unit_history();

create function private.catalog_validate_product() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if (tg_op='INSERT' or new.unit is distinct from old.unit) and nullif(btrim(new.unit),'') is null then raise exception 'Unit is required'; end if;
 if (tg_op='INSERT' or new.unit is distinct from old.unit) and new.unit not in('piece','kg','g','litre','ml','metre','cm') then raise exception 'Choose a supported count, weight, length or volume unit'; end if;
 if nullif(btrim(new.name),'') is null then raise exception 'Product name is required'; end if;
 if new.low_stock_threshold is not null and (new.low_stock_threshold<0 or new.low_stock_threshold::text in('NaN','Infinity','-Infinity') or scale(new.low_stock_threshold)>3) then raise exception 'Invalid low-stock threshold'; end if;
 if new.quantity is not null and (new.quantity<0 or new.quantity::text in('NaN','Infinity','-Infinity') or scale(new.quantity)>3) then raise exception 'Invalid stock quantity'; end if;
 if lower(btrim(coalesce(new.unit,'piece'))) not in('kg','g','litre','ml','metre','cm') and coalesce(new.quantity,0)<>trunc(coalesce(new.quantity,0)) then raise exception 'Countable units require whole quantities'; end if;

 if current_user='authenticated' and ((tg_op='INSERT' and coalesce(new.quantity,0)<>0)
 or (tg_op='UPDATE' and new.quantity is distinct from old.quantity)) then
  raise exception 'Use authorized stock adjustment with a reason' using errcode='42501'; end if;
 if current_user='authenticated' and ((tg_op='UPDATE' and new.low_stock_threshold is distinct from old.low_stock_threshold)
 or (tg_op='INSERT' and new.low_stock_threshold is distinct from 5::numeric))
 and not(public.user_owns_business(new.business_id) or private.has_business_permission(new.business_id,'override_price')) then
  raise exception 'Threshold authority required' using errcode='42501'; end if;
 if jsonb_typeof(new.variant_attributes)<>'object' or exists(select 1 from jsonb_each(new.variant_attributes)
 where jsonb_typeof(value)<>'string' or length(key)>40 or length(value#>>'{}')>100) then raise exception 'Invalid variant attributes'; end if;
 return new;
end $$;
revoke all on function private.catalog_validate_product() from public,anon,authenticated;
create trigger batch_3_catalog_validate before insert or update on public.products for each row execute function private.catalog_validate_product();

create function public.save_trexven_catalog_product(p_business_id uuid,p_request_id uuid,p_product_id uuid,p_fields jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare prior private.catalog_requests%rowtype; old public.products%rowtype; result_id uuid; payload jsonb;
 can_price boolean; f jsonb; grp uuid;
begin
 if p_request_id is null or p_fields is null or jsonb_typeof(p_fields)<>'object' then raise exception 'Invalid catalog request'; end if;
 perform private.catalog_context(p_business_id,case when p_product_id is null then 'add_products' else 'edit_products' end);
 payload:=jsonb_build_object('operation','save','product_id',p_product_id,'fields',p_fields);
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 select * into prior from private.catalog_requests where request_id=p_request_id;
 if found then
  if prior.business_id<>p_business_id or prior.actor_id<>auth.uid() or prior.payload<>payload then raise exception 'Request identity conflict' using errcode='42501'; end if;
  return (prior.response->>'id')::uuid; end if;
 if exists(select 1 from jsonb_object_keys(p_fields) k where k not in('name','barcode','sku','description','category','brand','image_url','unit','selling_price','low_stock_threshold','active','catalog_group_id','variant_attributes')) then raise exception 'Unsupported product field' using errcode='42501'; end if;
 can_price:=public.user_owns_business(p_business_id) or private.has_business_permission(p_business_id,'override_price');
 if p_fields?'selling_price' and p_fields->>'selling_price' is not null and scale((p_fields->>'selling_price')::numeric)>2 then raise exception 'Price supports two decimal places'; end if;
 if p_fields?'selling_price' and not can_price then raise exception 'Price permission denied' using errcode='42501'; end if;
 if p_fields?'low_stock_threshold' and not can_price then raise exception 'Threshold authority required' using errcode='42501'; end if;
 if p_product_id is not null then
  select * into old from public.products where id=p_product_id and business_id=p_business_id for update;
  if not found then raise exception 'Product not found in this business' using errcode='42501'; end if;
 end if;
 f:=case when p_product_id is null then '{}'::jsonb else to_jsonb(old) end||p_fields;
 grp:=nullif(f->>'catalog_group_id','')::uuid;
 if grp is not null and not exists(select 1 from public.product_groups where id=grp and business_id=p_business_id) then raise exception 'Variant group belongs to another business' using errcode='42501'; end if;
 if p_product_id is null then
  insert into public.products(business_id,name,barcode,sku,description,category,brand,image_url,unit,selling_price,low_stock_threshold,active,is_active,catalog_group_id,variant_attributes,quantity)
  values(p_business_id,f->>'name',nullif(btrim(f->>'barcode'),''),nullif(btrim(f->>'sku'),''),f->>'description',f->>'category',f->>'brand',f->>'image_url',coalesce(f->>'unit','piece'),(f->>'selling_price')::numeric,
   coalesce((f->>'low_stock_threshold')::numeric,5),coalesce((f->>'active')::boolean,true),coalesce((f->>'active')::boolean,true),grp,coalesce(f->'variant_attributes','{}'),0) returning id into result_id;
 else
  update public.products set name=f->>'name',barcode=nullif(btrim(f->>'barcode'),''),sku=nullif(btrim(f->>'sku'),''),description=f->>'description',category=f->>'category',brand=f->>'brand',image_url=f->>'image_url',unit=f->>'unit',selling_price=(f->>'selling_price')::numeric,
   low_stock_threshold=(f->>'low_stock_threshold')::numeric,active=(f->>'active')::boolean,is_active=(f->>'active')::boolean,catalog_group_id=grp,variant_attributes=f->'variant_attributes',updated_at=now()
  where id=old.id and business_id=p_business_id returning id into result_id;
 end if;
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'catalog_product_saved',jsonb_build_object('product_id',result_id,'request_id',p_request_id));
 insert into private.catalog_requests values(p_request_id,p_business_id,auth.uid(),payload,jsonb_build_object('id',result_id),now());
 return result_id;
end $$;
revoke all on function public.save_trexven_catalog_product(uuid,uuid,uuid,jsonb) from public,anon;
grant execute on function public.save_trexven_catalog_product(uuid,uuid,uuid,jsonb) to authenticated;

create function public.save_trexven_product_group(p_business_id uuid,p_group_id uuid,p_name text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result_id uuid;
begin
 perform private.catalog_context(p_business_id,case when exists(select 1 from public.product_groups where id=p_group_id) then 'edit_products' else 'add_products' end);
 if p_group_id is null then raise exception 'Stable group identity required'; end if;
 if exists(select 1 from public.product_groups where id=p_group_id and business_id<>p_business_id) then raise exception 'Group belongs to another business' using errcode='42501'; end if;
 insert into public.product_groups(id,business_id,name) values(p_group_id,p_business_id,p_name)
 on conflict(id) do update set name=excluded.name where product_groups.business_id=p_business_id returning id into result_id;
 if result_id is null then raise exception 'Group not found in this business' using errcode='42501'; end if;
 return result_id;
end $$;
revoke all on function public.save_trexven_product_group(uuid,uuid,text) from public,anon;
grant execute on function public.save_trexven_product_group(uuid,uuid,text) to authenticated;

create function public.adjust_trexven_catalog_stock(p_business_id uuid,p_product_id uuid,p_delta numeric,p_reason text,p_request_id uuid)
returns numeric language plpgsql security definer set search_path='' as $$
declare p public.products%rowtype; prior private.catalog_requests%rowtype; payload jsonb; result_qty numeric;
begin
 perform private.catalog_context(p_business_id,'adjust_stock');
 if p_request_id is null or p_delta is null or p_delta=0 or p_delta::text in('NaN','Infinity','-Infinity') or scale(p_delta)>3 or nullif(btrim(p_reason),'')is null then raise exception 'Valid quantity and reason required'; end if;
 payload:=jsonb_build_object('operation','stock','product_id',p_product_id,'delta',p_delta,'reason',p_reason);
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 select * into prior from private.catalog_requests where request_id=p_request_id;
 if found then
  if prior.business_id<>p_business_id or prior.actor_id<>auth.uid() or prior.payload<>payload then raise exception 'Request identity conflict' using errcode='42501'; end if;
  return (prior.response->>'quantity')::numeric; end if;
 select * into p from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product not found in this business' using errcode='42501'; end if;
 result_qty:=coalesce(p.quantity,0)+p_delta;
 if result_qty<0 then raise exception 'Insufficient stock for adjustment'; end if;
 perform set_config('trexven.catalog_reason',p_reason,true); perform set_config('trexven.catalog_request',p_request_id::text,true);
 update public.products set quantity=result_qty,updated_at=now() where id=p.id;
 perform set_config('trexven.catalog_reason','',true); perform set_config('trexven.catalog_request','',true);
 insert into private.catalog_requests values(p_request_id,p_business_id,auth.uid(),payload,jsonb_build_object('quantity',result_qty),now());
 return result_qty;
end $$;
revoke all on function public.adjust_trexven_catalog_stock(uuid,uuid,numeric,text,uuid) from public,anon;
grant execute on function public.adjust_trexven_catalog_stock(uuid,uuid,numeric,text,uuid) to authenticated;

-- Capture future authorized price changes through every table/RPC write path.
-- This complements operation requests and contains no purchase-cost fields.
create function private.catalog_price_history() returns trigger
language plpgsql security definer set search_path='' as $$
declare previous_price numeric;
begin
 if auth.uid() is null then return new; end if;
 if tg_op='UPDATE' then
  previous_price:=old.selling_price;
  if new.selling_price is not distinct from old.selling_price then return new; end if;
 elsif new.selling_price is null then return new;
 end if;
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(new.business_id,auth.uid(),'catalog_price_changed',jsonb_build_object('product_id',new.id,
  'previous_selling_price',previous_price,'new_selling_price',new.selling_price));
 return new;
end $$;
revoke all on function private.catalog_price_history() from public,anon,authenticated;
create trigger batch_3_price_history after insert or update of selling_price on public.products
for each row execute function private.catalog_price_history();

create function private.catalog_stock_events() returns trigger
language plpgsql security definer set search_path='' as $$
declare before_qty numeric:=0; member uuid; below boolean; was_below boolean; reason text; request uuid; kind text;
begin
 if auth.uid() is null then return new; end if;
 if tg_op='UPDATE' then before_qty:=coalesce(old.quantity,0); end if;
 if coalesce(new.quantity,0)<>before_qty then
  select id into member from public.business_members where business_id=new.business_id and user_id=auth.uid();
  reason:=nullif(current_setting('trexven.catalog_reason',true),'');request:=nullif(current_setting('trexven.catalog_request',true),'')::uuid;
  kind:=case when current_setting('trexven.catalog_operation',true)='sale' then 'sale' else 'adjustment' end;
  insert into public.inventory_movements(business_id,product_id,employee_id,movement_type,quantity,previous_quantity,new_quantity,reference_id,reason,source)
   values(new.business_id,new.id,member,kind,new.quantity-before_qty,before_qty,new.quantity,request,coalesce(reason,'Confirmed checkout stock deduction'),'catalog');
 end if;
 -- Suppress the intermediate zero stock of atomic import creation.
 if current_setting('trexven.catalog_import',true)='creating' then return new; end if;
 below:=new.active is true and new.is_active is true and new.selling_price is not null and coalesce(new.quantity,0)<=coalesce(new.low_stock_threshold,0);
 select below_threshold into was_below from private.catalog_low_stock_state where product_id=new.id;
 if below and coalesce(was_below,false)=false then
  insert into public.alerts(business_id,alert_type,title,message,severity,source,reference_id)
  values(new.business_id,'low_stock','Low stock',new.name||' has '||coalesce(new.quantity,0)||' '||coalesce(new.unit,'piece')||' available',case when coalesce(new.quantity,0)=0 then 'high' else 'warning' end,'inventory',new.id);
 end if;
 insert into private.catalog_low_stock_state values(new.id,new.business_id,below)
 on conflict(product_id)do update set below_threshold=excluded.below_threshold;
 return new;
end $$;
revoke all on function private.catalog_stock_events() from public,anon,authenticated;
create trigger batch_3_stock_events after insert or update on public.products for each row execute function private.catalog_stock_events();

create function public.import_trexven_catalog(p_business_id uuid,p_request_id uuid,p_rows jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior private.catalog_requests%rowtype; row jsonb; i int:=0; ids jsonb:='[]'; product uuid; payload jsonb; fields jsonb; group_name text; grp uuid; target_id uuid; attributes jsonb;
begin
 -- Master plan: bulk import is not an inventory employee default. Owner only until an explicit bulk grant is approved.
 if not public.user_owns_business(p_business_id) then raise exception 'Owner bulk-import authority required' using errcode='42501'; end if;
 perform private.catalog_context(p_business_id,'add_products');
 if p_rows is null or p_request_id is null or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)=0 then raise exception 'Import rows required'; end if;
 payload:=jsonb_build_object('operation','import','rows',p_rows);
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 select * into prior from private.catalog_requests where request_id=p_request_id;
 if found then
  if prior.actor_id<>auth.uid() or prior.business_id<>p_business_id or prior.payload<>payload then raise exception 'Import request conflict' using errcode='42501'; end if;
  return prior.response; end if;
 -- Canonical product lock order matches checkout and prevents update deadlocks.
 perform id from public.products where business_id=p_business_id and id in
  (select nullif(value->>'product_id','')::uuid from jsonb_array_elements(p_rows)) order by id for update;
 for row in select value from jsonb_array_elements(p_rows) loop
  i:=i+1;
  fields:=row-array['product_id','initial_quantity','stock_delta','stock_reason','group_name','size','color','material'];
  target_id:=nullif(row->>'product_id','')::uuid;
  attributes:='{}';
  if target_id is not null then
   select variant_attributes into attributes from public.products where id=target_id and business_id=p_business_id;
   if not found then raise exception 'Import target belongs to another business' using errcode='42501'; end if;
   if row?'initial_quantity' then raise exception 'Initial quantity cannot reset existing stock'; end if;
  elsif row?'stock_delta' then raise exception 'Use initial quantity for new products'; end if;
  group_name:=nullif(btrim(row->>'group_name'),'');
  if group_name is not null then
   if row?'catalog_group_id' then raise exception 'Use one group selector'; end if;
   select id into grp from public.product_groups where business_id=p_business_id and name=group_name;
   if grp is null then grp:=public.save_trexven_product_group(p_business_id,md5(p_request_id::text||':group:'||group_name)::uuid,group_name); end if;
   fields:=fields||jsonb_build_object('catalog_group_id',grp);
  end if;
  if row?'size' or row?'color' or row?'material' then
   fields:=fields||jsonb_build_object('variant_attributes',attributes||coalesce(row->'variant_attributes','{}')||
    jsonb_strip_nulls(jsonb_build_object('size',nullif(row->>'size',''),'color',nullif(row->>'color',''),'material',nullif(row->>'material',''))));
  end if;
  perform set_config('trexven.catalog_import','creating',true);
  product:=public.save_trexven_catalog_product(p_business_id,md5(p_request_id::text||':product:'||i)::uuid,target_id,fields);
  perform set_config('trexven.catalog_import','',true);
  if target_id is not null and row?'stock_delta' and (row->>'stock_delta')::numeric<>0 then
   perform public.adjust_trexven_catalog_stock(p_business_id,product,(row->>'stock_delta')::numeric,row->>'stock_reason',md5(p_request_id::text||':stock:'||i)::uuid);
  elsif row?'initial_quantity' and (row->>'initial_quantity')::numeric<>0 then
   perform public.adjust_trexven_catalog_stock(p_business_id,product,(row->>'initial_quantity')::numeric,'Reviewed bulk import',md5(p_request_id::text||':stock:'||i)::uuid);
  else update public.products set quantity=quantity where id=product and business_id=p_business_id; end if;
  ids:=ids||jsonb_build_array(product);
 end loop;
 insert into private.catalog_requests values(p_request_id,p_business_id,auth.uid(),payload,ids,now()); return ids;
end $$;
revoke all on function public.import_trexven_catalog(uuid,uuid,jsonb) from public,anon;
grant execute on function public.import_trexven_catalog(uuid,uuid,jsonb) to authenticated;
create or replace function private.process_trexven_sale(
 p_business_id uuid,p_employee_id uuid,p_total numeric,p_payment_method text,p_items jsonb,
 p_quick boolean,p_branch_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare b public.businesses%rowtype; item jsonb; product public.products%rowtype;
 member uuid; sale uuid; branch uuid; qty numeric; price numeric; v_discount numeric; v_total numeric:=0;
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
   qty:=(item->>'quantity')::numeric; price:=(item->>'unit_price')::numeric;
   v_discount:=coalesce((item->>'discount')::numeric,0);
   if qty is null or qty<=0 or scale(qty)>3 or qty::text in ('NaN','Infinity','-Infinity') or price is null or price<0 or price::text in ('NaN','Infinity','-Infinity')
   or v_discount::text in ('NaN','Infinity','-Infinity') or v_discount<0 or v_discount>qty*price then raise exception 'Invalid sale item'; end if;
   if v_discount>0 and (p_quick or not private.has_business_permission(b.id,'apply_discount')) then
     raise exception 'Discount permission denied' using errcode='42501'; end if;
   select * into product from public.products where id=(item->>'product_id')::uuid and business_id=b.id;
   if not found then raise exception 'Product not found in this business'; end if;
   if product.selling_price is null or product.is_active is not true or product.active is false then
     raise exception 'Product is pending or inactive'; end if;
   if lower(btrim(coalesce(product.unit,'piece'))) not in('kg','g','litre','ml','metre','cm') and qty<>trunc(qty) then raise exception 'Countable units require whole quantities'; end if;
   if price is distinct from product.selling_price then raise exception 'Product price changed'; end if;
   if branch is null then
     if coalesce(product.quantity,0)<qty then raise exception 'Insufficient stock'; end if;
     perform set_config('trexven.catalog_operation','sale',true);
     perform set_config('trexven.catalog_request',sale::text,true);
     perform set_config('trexven.catalog_reason','Confirmed checkout stock deduction',true);
     update public.products set quantity=quantity-qty where id=product.id and business_id=b.id;
     perform set_config('trexven.catalog_operation','',true);
     perform set_config('trexven.catalog_request','',true);
     perform set_config('trexven.catalog_reason','',true);
   else
     update public.inventory set quantity=quantity-qty where business_id=b.id and branch_id=branch and product_id=product.id
       and quantity-coalesce(reserved_quantity,0)>=qty;
     if not found then raise exception 'Insufficient branch stock'; end if;
   end if;
   insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total)
   values(sale,product.id,product.name,qty,price,v_discount,round(qty*price-v_discount,2));
   v_total:=v_total+round(qty*price-v_discount,2);
 end loop;
 if v_total is distinct from p_total then raise exception 'Sale total does not match items'; end if;
 update public.sales set total=v_total,total_amount=v_total,
 subtotal=(select sum(round(quantity*unit_price,2)) from public.sale_items where sale_id=sale),
 discount=(select sum(i.discount) from public.sale_items i where i.sale_id=sale) where id=sale;
 -- Preserve the legacy single-product quick-sale columns.
 if p_quick then update public.sales set product_id=product.id,quantity=qty,unit_price=price where id=sale; end if;
 return sale;
end $$;
revoke all on function private.process_trexven_sale(uuid,uuid,numeric,text,jsonb,boolean,uuid) from public,anon,authenticated;


notify pgrst,'reload schema';
commit;

-- Replaces the UNDEPLOYED Angel Scan draft. All stock writes remain owner-confirmed.
insert into public.permissions(id,description) values
 ('angel_scan_inventory','Prepare Angel Scan inventory requests for owner approval') on conflict(id) do nothing;

create or replace function public.angel_scan_can_manage_inventory(p_business_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.has_business_permission(p_business_id,'view_inventory') is true
 and (public.user_owns_business(p_business_id) or exists(
 select 1 from public.employees e join public.business_members m on m.business_id=e.business_id and m.user_id=e.user_id
 join public.employee_permissions g on g.employee_id=e.id and g.permission_id='angel_scan_inventory' and g.granted
 where e.business_id=p_business_id and e.user_id=auth.uid() and e.status='active' and e.role='manager'
 and m.status='active' and m.role='manager'));
$$;
create or replace function public.angel_scan_can_sell(p_business_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.has_business_permission(p_business_id,'pos_access') is true
 and private.has_business_permission(p_business_id,'complete_sales') is true
 and (public.user_owns_business(p_business_id) or exists(select 1 from public.employees e
 join public.business_members m on m.business_id=e.business_id and m.user_id=e.user_id
 where e.business_id=p_business_id and e.user_id=auth.uid() and e.status='active' and m.status='active'
 and e.role in ('manager','sales_employee') and m.role in ('manager','sales_employee')));
$$;

create or replace function private.angel_scan_context(business uuid,purpose text,branch uuid)
returns void language plpgsql security definer set search_path='' as $$
declare enabled boolean;
begin
 if auth.uid() is null or purpose is null or purpose not in('inventory','sale') then raise exception 'Authenticated scan context required' using errcode='42501';end if;
 select branches_enabled into enabled from public.businesses where id=business for share;
 if not found then raise exception 'Business unavailable' using errcode='42501';end if;
 perform id from public.employees where business_id=business and user_id=auth.uid() for share;
 perform id from public.business_members where business_id=business and user_id=auth.uid() for share;
 perform ep.employee_id from public.employee_permissions ep join public.employees e on e.id=ep.employee_id
 where e.business_id=business and e.user_id=auth.uid() and ep.permission_id='angel_scan_inventory' for share of ep;
 if (purpose='inventory' and public.angel_scan_can_manage_inventory(business) is not true)
 or (purpose='sale' and public.angel_scan_can_sell(business) is not true) then raise exception 'Scan permission denied' using errcode='42501';end if;
 if enabled then
  perform id from public.branches where business_id=business and id=branch and is_active for share;
  if not found or private.has_branch_access(business,branch) is not true then raise exception 'Authorized branch required' using errcode='42501';end if;
 elsif branch is not null then raise exception 'Branches are not enabled' using errcode='42501';end if;
 if private.subscription_entitled(business,'inventory') is not true then raise exception 'Inventory subscription required' using errcode='42501';end if;
end $$;

create table private.angel_scan_usage(user_id uuid not null,business_id uuid not null,window_start timestamptz not null,uses integer not null,primary key(user_id,business_id));
revoke all on private.angel_scan_usage from public,anon,authenticated;
create or replace function public.authorize_angel_scan(p_business_id uuid,p_purpose text,p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare usage integer;
begin
 perform private.angel_scan_context(p_business_id,p_purpose,p_branch_id);
 insert into private.angel_scan_usage values(auth.uid(),p_business_id,date_trunc('minute',now()),1)
 on conflict(user_id,business_id) do update set
 uses=case when angel_scan_usage.window_start<date_trunc('minute',now()) then 1 else angel_scan_usage.uses+1 end,
 window_start=date_trunc('minute',now()) returning uses into usage;
 if usage>30 then raise exception 'Scan rate limit exceeded' using errcode='54000';end if;
 return jsonb_build_object('owner',public.user_owns_business(p_business_id));
end $$;

-- The model supplies descriptive evidence, never database IDs. Matching searches the complete business catalog.
create or replace function public.match_angel_scan_items(p_business_id uuid,p_purpose text,p_items jsonb,p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare item jsonb; matches jsonb; result jsonb:='[]'; query_name text; query_sku text; query_barcode text;
begin
 perform private.angel_scan_context(p_business_id,p_purpose,p_branch_id);
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items)>80 then raise exception 'Invalid recognition batch';end if;
 for item in select value from jsonb_array_elements(p_items) loop
  query_name:=lower(btrim(item->>'name'));query_sku:=lower(btrim(item->>'sku'));query_barcode:=nullif(btrim(item->>'barcode'),'');
  select coalesce(jsonb_agg(to_jsonb(t) order by t.score desc,t.name),'[]') into matches from (
   select p.id product_id,p.name,p.brand,p.sku,p.barcode,p.unit,p.selling_price,
    p.active and p.is_active and p.selling_price is not null active,
    case when p_branch_id is null then p.quantity else coalesce((select i.quantity-i.reserved_quantity from public.inventory i
      where i.business_id=p_business_id and i.product_id=p.id and i.branch_id=p_branch_id),0) end quantity,
    case when query_barcode is not null and p.barcode=query_barcode then 100
     when query_sku<>'' and lower(p.sku)=query_sku and (nullif(item->>'brand','') is null or lower(p.brand)=lower(item->>'brand')) then 95
     when lower(btrim(p.name))=query_name and (nullif(item->>'brand','') is null or lower(p.brand)=lower(item->>'brand')) then 90 else 50 end score
   from public.products p where p.business_id=p_business_id and (
    (query_barcode is not null and p.barcode=query_barcode) or (query_sku<>'' and lower(p.sku)=query_sku)
    or (length(query_name)>2 and (lower(p.name)=query_name or lower(p.name) like '%'||replace(replace(replace(query_name,'\','\\'),'%','\%'),'_','\_')||'%' escape '\')))
   order by score desc,p.name,p.id limit 12
  ) t;
  result:=result||jsonb_build_array(item||jsonb_build_object('matches',matches,'match_status',
    case when jsonb_array_length(matches)=1 and (matches->0->>'score')::int>=90 then 'review_match' else 'needs_review' end));
 end loop;
 return result;
end $$;

create table public.angel_inventory_approval_requests(
 id uuid primary key,business_id uuid not null references public.businesses(id),branch_id uuid,
 requested_by uuid not null references auth.users(id),requested_employee_id uuid references public.employees(id),
 document_metadata jsonb not null default '{}'::jsonb,
 document_hash text not null check(document_hash ~ '^[a-f0-9]{64}$'),
 items jsonb not null check(jsonb_typeof(items)='array' and jsonb_array_length(items) between 1 and 500),
 status text not null default 'pending' check(status in('pending','approved','rejected')),
 application_status text not null default 'not_applied' check(application_status in('not_applied','applied','failed')),
 application_error text,applied_at timestamptz,applied_products jsonb,
 owner_decided_by uuid references auth.users(id),owner_decided_at timestamptz,owner_note text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(business_id,document_hash),foreign key(branch_id,business_id) references public.branches(id,business_id)
);
create index on public.angel_inventory_approval_requests(business_id,status,created_at desc);
alter table public.angel_inventory_approval_requests enable row level security;
revoke all on public.angel_inventory_approval_requests from public,anon,authenticated;
grant select on public.angel_inventory_approval_requests to authenticated;
create policy angel_inventory_read on public.angel_inventory_approval_requests for select to authenticated using(
 private.has_business_permission(business_id,'view_inventory') is true and
 (public.user_owns_business(business_id) or (requested_by=(select auth.uid())
 and public.angel_scan_can_manage_inventory(business_id) and (branch_id is null or private.has_branch_access(business_id,branch_id)))));

create table private.angel_document_sources(business_id uuid not null references public.businesses(id),fingerprint text not null,request_id uuid not null references public.angel_inventory_approval_requests(id),primary key(business_id,fingerprint));
revoke all on private.angel_document_sources from public,anon,authenticated;

create function private.validate_angel_inventory_items(p_business_id uuid,p_items jsonb)
returns void language plpgsql set search_path='' as $$
declare item jsonb; qty numeric;price numeric;cost numeric;
begin
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 500 or octet_length(p_items::text)>1000000 then raise exception 'Review between 1 and 500 product lines';end if;
 for item in select value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(item)<>'object' or exists(select 1 from jsonb_object_keys(item) k where k not in('product_id','name','brand','sku','barcode','category','unit','quantity','cost','selling_price','line_total','evidence','uncertain'))
  or nullif(btrim(item->>'name'),'') is null or length(item->>'name')>180 then raise exception 'Review every product name';end if;
  qty:=(item->>'quantity')::numeric; price:=nullif(item->>'selling_price','')::numeric;cost:=nullif(item->>'cost','')::numeric;
  if qty is null or qty<=0 or qty>1000000 or scale(qty)>3 or qty::text in('NaN','Infinity','-Infinity') then raise exception 'Review every quantity';end if;
  if (price is not null and (price<0 or price>100000000000 or scale(price)>2 or price::text in('NaN','Infinity','-Infinity')))
  or (cost is not null and (cost<0 or cost>100000000000 or scale(cost)>2 or cost::text in('NaN','Infinity','-Infinity'))) then raise exception 'Invalid price or purchase cost';end if;
  if nullif(item->>'product_id','') is not null then
   if not exists(select 1 from public.products where id=(item->>'product_id')::uuid and business_id=p_business_id) then raise exception 'Product belongs to another business' using errcode='42501';end if;
   if price is not null then raise exception 'Existing selling prices must be changed through the protected price workflow';end if;
  elsif coalesce(nullif(item->>'unit',''),'piece') not in('piece','kg','g','litre','ml','metre','cm') then raise exception 'Choose a supported unit';end if;
 end loop;
end $$;
revoke all on function private.validate_angel_inventory_items(uuid,jsonb) from public,anon,authenticated;

create or replace function public.submit_angel_inventory_approval(p_business_id uuid,p_request_id uuid,p_document_hash text,p_items jsonb,p_branch_id uuid default null,p_document_metadata jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare existing public.angel_inventory_approval_requests%rowtype; item jsonb; qty numeric; price numeric; cost numeric; employee uuid; source_hash text; doc jsonb; identity_hash text;
begin
 perform private.angel_scan_context(p_business_id,'inventory',p_branch_id);
 if p_request_id is null or p_document_hash is null or p_document_hash !~ '^[a-f0-9]{64}$'
 or jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 500
 or octet_length(p_items::text)>1000000 or jsonb_typeof(p_document_metadata) is distinct from 'object' or octet_length(p_document_metadata::text)>100000 then raise exception 'Reviewed document and request identity required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||':angel-submission',0));
 select * into existing from public.angel_inventory_approval_requests where id=p_request_id or (business_id=p_business_id and document_hash=p_document_hash);
 if found then
  if existing.business_id<>p_business_id or (existing.requested_by<>auth.uid() and not public.user_owns_business(p_business_id)) then raise exception 'Request identity conflict' using errcode='42501';end if;
  if existing.id=p_request_id and (existing.items<>p_items or existing.branch_id is distinct from p_branch_id or existing.document_hash<>p_document_hash) then raise exception 'Request identity conflict';end if;
  return jsonb_build_object('id',existing.id,'status',existing.status,'application_status',existing.application_status,'duplicate',true);
 end if;
 if jsonb_typeof(p_document_metadata->'sources') is distinct from 'array' or jsonb_array_length(p_document_metadata->'sources') not between 1 and 20
 or jsonb_typeof(p_document_metadata->'documents') is distinct from 'array' or jsonb_array_length(p_document_metadata->'documents')>500 then raise exception 'Document source identities required';end if;
 for source_hash in select value#>>'{}' from jsonb_array_elements(p_document_metadata->'sources') loop
  if source_hash !~ '^[a-f0-9]{64}$' then raise exception 'Invalid document fingerprint';end if;
  select r.* into existing from private.angel_document_sources d join public.angel_inventory_approval_requests r on r.id=d.request_id
   where d.business_id=p_business_id and d.fingerprint=source_hash;
  if found then
   if existing.requested_by<>auth.uid() and not public.user_owns_business(p_business_id) then raise exception 'This document already has an inventory request';end if;
   return jsonb_build_object('id',existing.id,'status',existing.status,'application_status',existing.application_status,'duplicate',true);
  end if;
 end loop;
 for doc in select value from jsonb_array_elements(p_document_metadata->'documents') loop
  if nullif(btrim(doc->>'supplier'),'') is not null and nullif(btrim(doc->>'document_number'),'') is not null then
   identity_hash:=md5(lower(btrim(doc->>'supplier'))||':'||lower(btrim(doc->>'document_number')));
   select r.* into existing from private.angel_document_sources d join public.angel_inventory_approval_requests r on r.id=d.request_id
    where d.business_id=p_business_id and d.fingerprint=identity_hash;
   if found then
    if existing.requested_by<>auth.uid() and not public.user_owns_business(p_business_id) then raise exception 'This invoice already has an inventory request';end if;
    return jsonb_build_object('id',existing.id,'status',existing.status,'application_status',existing.application_status,'duplicate',true);
   end if;
  end if;
 end loop;
 perform private.validate_angel_inventory_items(p_business_id,p_items);
 select id into employee from public.employees where business_id=p_business_id and user_id=auth.uid() and status='active';
 insert into public.angel_inventory_approval_requests(id,business_id,branch_id,requested_by,requested_employee_id,document_hash,items,document_metadata)
 values(p_request_id,p_business_id,p_branch_id,auth.uid(),employee,p_document_hash,p_items,p_document_metadata);
 for source_hash in select value#>>'{}' from jsonb_array_elements(p_document_metadata->'sources') loop
  insert into private.angel_document_sources values(p_business_id,source_hash,p_request_id) on conflict do nothing;
 end loop;
 for doc in select value from jsonb_array_elements(p_document_metadata->'documents') loop
  if nullif(btrim(doc->>'supplier'),'') is not null and nullif(btrim(doc->>'document_number'),'') is not null then
   insert into private.angel_document_sources values(p_business_id,md5(lower(btrim(doc->>'supplier'))||':'||lower(btrim(doc->>'document_number'))),p_request_id) on conflict do nothing;
  end if;
 end loop;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata) values(p_business_id,auth.uid(),employee,'angel_inventory_submitted',jsonb_build_object('request_id',p_request_id,'branch_id',p_branch_id,'items',jsonb_array_length(p_items)));
 return jsonb_build_object('id',p_request_id,'status','pending','application_status','not_applied','duplicate',false);
end $$;

-- Invoked only by the verified-owner decision function, in an exception subtransaction.
create or replace function private.apply_angel_inventory_request(request uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.angel_inventory_approval_requests%rowtype; item jsonb;p public.products%rowtype; product uuid;
 qty numeric; ids jsonb:='[]'; idx integer:=0; fields jsonb; operation uuid; enabled boolean;
begin
 select * into r from public.angel_inventory_approval_requests where id=request for update;
 if not found or not public.user_owns_business(r.business_id) or r.status<>'approved' then raise exception 'Approved owner request required' using errcode='42501';end if;
 if r.application_status='applied' then return r.applied_products;end if;
 perform private.angel_scan_context(r.business_id,'inventory',r.branch_id);
 -- Serialize identity checks against other Angel imports. Existing catalog constraints remain authoritative.
 perform pg_advisory_xact_lock(hashtextextended(r.business_id::text||':angel-catalog',0));
 select branches_enabled into enabled from public.businesses where id=r.business_id;
 perform id from public.products where business_id=r.business_id and id in(select nullif(value->>'product_id','')::uuid from jsonb_array_elements(r.items)) order by id for update;
 for item in select value from jsonb_array_elements(r.items) loop
  idx:=idx+1;operation:=md5(r.id::text||':angel:'||idx)::uuid;qty:=(item->>'quantity')::numeric;product:=nullif(item->>'product_id','')::uuid;
  if product is null then
   -- Never guess between duplicates; ask the reviewer to select the existing ID.
   if exists(select 1 from public.products x where x.business_id=r.business_id and (
    (nullif(btrim(item->>'barcode'),'') is not null and x.barcode=btrim(item->>'barcode')) or
    (nullif(btrim(item->>'sku'),'') is not null and lower(x.sku)=lower(btrim(item->>'sku'))) or
    (lower(btrim(x.name))=lower(btrim(item->>'name')) and lower(coalesce(x.brand,''))=lower(coalesce(item->>'brand',''))))) then
    raise exception 'A matching product already exists. Review inventory selection';end if;
   fields:=jsonb_strip_nulls(jsonb_build_object('name',btrim(item->>'name'),'barcode',nullif(btrim(item->>'barcode'),''),'sku',nullif(btrim(item->>'sku'),''),
    'brand',item->>'brand','category',item->>'category','unit',coalesce(nullif(item->>'unit',''),'piece'),'selling_price',nullif(item->>'selling_price','')::numeric));
   if enabled then
    insert into public.products(business_id,name,barcode,sku,brand,category,unit,selling_price,quantity,active,is_active,variant_attributes,low_stock_threshold)
    values(r.business_id,fields->>'name',fields->>'barcode',fields->>'sku',fields->>'brand',fields->>'category',fields->>'unit',(fields->>'selling_price')::numeric,0,
      (fields->>'selling_price') is not null,(fields->>'selling_price') is not null,'{}',5) returning id into product;
   else product:=public.save_trexven_catalog_product(r.business_id,md5(operation::text||':create')::uuid,null,fields);end if;
  end if;
  select * into p from public.products where id=product and business_id=r.business_id for update;
  if not found or not private.valid_stock_quantity(product,qty) then raise exception 'Review product quantity and unit';end if;
  if enabled then
   insert into public.inventory(business_id,product_id,branch_id,location,quantity,reserved_quantity)
   select r.business_id,product,r.branch_id,'branch:'||r.branch_id::text,0,0 where not exists(select 1 from public.inventory where business_id=r.business_id and branch_id=r.branch_id and product_id=product);
   perform private.apply_branch_inventory_delta(r.business_id,r.branch_id,product,qty,operation,'Owner-approved Angel Scan restock','angel_scan','adjustment',r.id);
  else perform public.adjust_trexven_catalog_stock(r.business_id,product,qty,'Owner-approved Angel Scan restock',operation);end if;
  ids:=ids||jsonb_build_array(jsonb_build_object('product_id',product,'quantity',qty,'purchase_unit_cost',item->'cost'));
 end loop;
 update public.angel_inventory_approval_requests set application_status='applied',application_error=null,applied_at=now(),applied_products=ids,updated_at=now() where id=request;
 return ids;
end $$;

create or replace function public.decide_angel_inventory_approval(p_business_id uuid,p_request_id uuid,p_approve boolean,p_note text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.angel_inventory_approval_requests%rowtype; result jsonb;failure text;
begin
 if not public.user_owns_business(p_business_id) or p_approve is null or private.has_business_permission(p_business_id,'view_inventory') is not true then raise exception 'Verified owner required' using errcode='42501';end if;
 select * into r from public.angel_inventory_approval_requests where business_id=p_business_id and id=p_request_id for update;
 if not found then raise exception 'Request unavailable' using errcode='42501';end if;
 if r.status='rejected' or r.application_status='applied' then
  return jsonb_build_object('id',r.id,'status',r.status,'application_status',r.application_status);end if;
 if r.status='approved' and not p_approve then raise exception 'Approved requests cannot be rejected';end if;
 update public.angel_inventory_approval_requests set status=case when p_approve then 'approved' else 'rejected' end,
 owner_decided_by=auth.uid(),owner_decided_at=coalesce(owner_decided_at,now()),owner_note=left(p_note,500),updated_at=now() where id=r.id;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata) values(p_business_id,auth.uid(),r.requested_employee_id,'angel_inventory_decided',jsonb_build_object('request_id',r.id,'approve',p_approve,'note',left(p_note,500)));
 if p_approve then
  begin
   result:=private.apply_angel_inventory_request(r.id);
   insert into public.audit_logs(business_id,actor_id,target_id,action,metadata) values(p_business_id,auth.uid(),r.requested_employee_id,'angel_inventory_applied',jsonb_build_object('request_id',r.id,'products',result,'branch_id',r.branch_id));
  exception when others then
   -- Every stock/catalog write in the block is rolled back. Approval remains a separate durable decision.
   failure:=case when sqlerrm like 'A matching product already exists%' then 'Existing product detected. Submit a corrected review with the existing product selected.' else 'Stock was not posted. Review current product, branch, quantity and subscription access before retrying.' end;
   update public.angel_inventory_approval_requests set application_status='failed',application_error=failure,updated_at=now() where id=r.id;
   insert into public.audit_logs(business_id,actor_id,target_id,action,metadata) values(p_business_id,auth.uid(),r.requested_employee_id,'angel_inventory_application_failed',jsonb_build_object('request_id',r.id,'code',sqlstate));
  end;
 end if;
 select * into r from public.angel_inventory_approval_requests where id=r.id;
 return jsonb_build_object('id',r.id,'status',r.status,'application_status',r.application_status,'application_error',r.application_error);
end $$;

-- Owner-only durable request details, including the employee's name; requester access stays under RLS.
create or replace function public.get_angel_inventory_request(p_business_id uuid,p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.angel_inventory_approval_requests%rowtype; employee_name text;history jsonb; reviewed_items jsonb;
begin
 if not public.user_owns_business(p_business_id) or private.has_business_permission(p_business_id,'view_inventory') is not true then raise exception 'Owner access required' using errcode='42501';end if;
 select * into r from public.angel_inventory_approval_requests where id=p_request_id and business_id=p_business_id;
 if not found then raise exception 'Request unavailable';end if;
 select name into employee_name from public.employees where id=r.requested_employee_id and business_id=p_business_id;
 select coalesce(jsonb_agg(jsonb_build_object('action',action,'at',created_at,'actor_id',actor_id) order by created_at),'[]') into history from public.audit_logs where business_id=p_business_id and metadata->>'request_id'=r.id::text and action like 'angel_inventory_%';
 select jsonb_agg(i.value||jsonb_build_object('current_selling_price',p.selling_price,'current_unit',p.unit)) into reviewed_items from jsonb_array_elements(r.items) i left join public.products p on p.id=nullif(i.value->>'product_id','')::uuid and p.business_id=p_business_id;
 return to_jsonb(r)||jsonb_build_object('items',reviewed_items,'employee_name',coalesce(employee_name,'Business owner'),'history',history);
end $$;

-- Extend the PRIVATE feed used by both read and mark-read RPCs, retaining original paths for POS.
alter function private.trexven_visible_notifications(uuid,text) rename to angel_previous_visible_notifications;
create function private.trexven_visible_notifications(business uuid,application text)
returns table(alert_key text,title text,message text,route text,reference_id uuid,occurred_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if application='pos' then return query select * from private.angel_previous_visible_notifications(business,application);return;end if;
 if application is distinct from 'owner' or auth.uid() is null or not public.user_owns_business(business)
 or private.has_business_permission(business,'view_inventory') is not true then raise exception 'Verified owner required' using errcode='42501';end if;
 -- Existing nonbranch owner alerts remain intact. Branch owners receive the same categories across owned branches.
 if not exists(select 1 from public.businesses where id=business and branches_enabled) then
  return query select * from private.angel_previous_visible_notifications(business,application);
 else
  return query select 'alert:'||a.id::text,a.title,a.message,case when a.alert_type like '%stock%' then 'inventory' else 'vision' end,a.reference_id,a.created_at
   from public.alerts a where a.business_id=business and (a.alert_type not like '%stock%' or private.subscription_entitled(business,'low_stock_alerts'))
  union all select 'inventory_review:'||r.id::text,'Inventory discrepancy requires review','Review the original stocktake before posting a correction.','inventory',r.id,null::timestamptz
   from public.inventory_reconciliation_reviews r where r.business_id=business and r.status='pending'
  union all select 'cash_review:'||s.id::text,'Closed drawer requires review','Review the count and variance.','cash',s.id,s.closed_at
   from public.cash_shifts s where s.business_id=business and s.status='closed' and s.review_status='pending'
  union all select 'staff:'||a.id::text,'Employee access changed','Review current employee access.','employees',a.target_id,a.created_at
   from public.audit_logs a where a.business_id=business and a.action in('employee_updated','employee_permission_changed','employee_status_changed');
 end if;
 return query
 select 'angel_inventory_approval:'||a.id::text,'Angel inventory approval',
  coalesce(e.name,'Business owner')||' submitted '||jsonb_array_length(a.items)::text||' products. Decision: '||a.status||'; stock: '||a.application_status||'.',
  'angel_inventory_approval',a.id,a.created_at from public.angel_inventory_approval_requests a
  left join public.employees e on e.id=a.requested_employee_id and e.business_id=a.business_id where a.business_id=business
 union all select 'credit_approval:'||a.id::text,'Credit sale awaiting approval','Review the saved credit request.','credit',a.id,a.created_at
 from public.credit_approvals a where a.business_id=business and a.status='pending'
 union all select 'return:'||r.id::text,'Return awaiting inspection or approval','Review the original transaction and refund request.','returns',r.id,r.created_at
 from public.sale_returns r where r.business_id=business and r.status in('requested','inspected');
end $$;

-- A granted flag cannot authorize a sales employee. The owner can revoke historical grants.
create function private.guard_angel_inventory_grant() returns trigger language plpgsql set search_path='' as $$
begin
 if new.permission_id='angel_scan_inventory' and new.granted and not exists(select 1 from public.employees where id=new.employee_id and role='manager' and status='active') then raise exception 'Angel inventory is available only to active managers';end if;return new;
end $$;
create trigger angel_inventory_manager_grant before insert or update on public.employee_permissions for each row execute function private.guard_angel_inventory_grant();

revoke all on function public.angel_scan_can_manage_inventory(uuid),public.angel_scan_can_sell(uuid),public.authorize_angel_scan(uuid,text,uuid),public.match_angel_scan_items(uuid,text,jsonb,uuid),public.submit_angel_inventory_approval(uuid,uuid,text,jsonb,uuid,jsonb),public.decide_angel_inventory_approval(uuid,uuid,boolean,text),public.get_angel_inventory_request(uuid,uuid) from public,anon;
grant execute on function public.angel_scan_can_manage_inventory(uuid),public.angel_scan_can_sell(uuid),public.authorize_angel_scan(uuid,text,uuid),public.match_angel_scan_items(uuid,text,jsonb,uuid),public.submit_angel_inventory_approval(uuid,uuid,text,jsonb,uuid,jsonb),public.decide_angel_inventory_approval(uuid,uuid,boolean,text),public.get_angel_inventory_request(uuid,uuid) to authenticated;
revoke all on function private.angel_scan_context(uuid,text,uuid),private.apply_angel_inventory_request(uuid),private.guard_angel_inventory_grant(),private.trexven_visible_notifications(uuid,text),private.angel_previous_visible_notifications(uuid,text) from public,anon,authenticated;
notify pgrst,'reload schema';

CREATE OR REPLACE FUNCTION public.get_trexven_notifications(p_business_id uuid, p_application text DEFAULT 'pos'::text, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid notification page';end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc nulls last,t.alert_key),'[]'::jsonb) into result from (
  select n.*,r.read_at from private.trexven_visible_notifications(p_business_id,p_application) n
  left join public.trexven_notification_reads r on r.business_id=p_business_id and r.user_id=auth.uid() and r.alert_key=n.alert_key
  order by n.occurred_at desc nulls last,n.alert_key limit 100 offset p_offset
 ) t;
 return result;
end $function$;


CREATE OR REPLACE FUNCTION public.mark_trexven_notification_read(p_business_id uuid, p_alert_key text, p_read boolean, p_application text DEFAULT 'pos'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if p_read is null or not exists(select 1 from private.trexven_visible_notifications(p_business_id,p_application) n where n.alert_key=p_alert_key) then
  raise exception 'Current authorized notification required' using errcode='42501';end if;
 if p_read then
  insert into public.trexven_notification_reads(business_id,user_id,alert_key) values(p_business_id,auth.uid(),p_alert_key)
  on conflict(business_id,user_id,alert_key) do update set read_at=now();
 else delete from public.trexven_notification_reads where business_id=p_business_id and user_id=auth.uid() and alert_key=p_alert_key;
 end if;
end $function$;


-- Corrections are owner-authored revisions with the complete previous review retained in audit.
create function public.revise_angel_inventory_request(p_business_id uuid,p_request_id uuid,p_items jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.angel_inventory_approval_requests%rowtype;
begin
 if auth.uid() is null or not public.user_owns_business(p_business_id) then raise exception 'Verified owner required' using errcode='42501';end if;
 select * into r from public.angel_inventory_approval_requests where id=p_request_id and business_id=p_business_id for update;
 if not found or r.application_status='applied' or r.status='rejected' then raise exception 'Only an unposted request can be corrected';end if;
 perform private.angel_scan_context(p_business_id,'inventory',r.branch_id);
 perform private.validate_angel_inventory_items(p_business_id,p_items);
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata) values(p_business_id,auth.uid(),r.requested_employee_id,'angel_inventory_revised',jsonb_build_object('request_id',r.id,'previous_items',r.items,'reviewed_items',p_items));
 update public.angel_inventory_approval_requests set items=p_items,status='pending',application_status='not_applied',application_error=null,owner_decided_by=null,owner_decided_at=null,owner_note=null,updated_at=now() where id=r.id;
 return jsonb_build_object('id',r.id,'status','pending','application_status','not_applied','duplicate',false);
end $$;
revoke all on function public.revise_angel_inventory_request(uuid,uuid,jsonb) from public,anon;
grant execute on function public.revise_angel_inventory_request(uuid,uuid,jsonb) to authenticated;

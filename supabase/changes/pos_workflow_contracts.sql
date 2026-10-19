-- Additive POS-only contracts. Existing Owner and legacy POS RPCs remain unchanged.
set lock_timeout='5s';
set statement_timeout='30s';
CREATE OR REPLACE FUNCTION public.approve_pos_return(p_return_id uuid, p_request_id uuid, p_method text, p_confirmed boolean, p_evidence text DEFAULT NULL::text, p_shift_id uuid DEFAULT NULL::uuid, p_restock boolean DEFAULT true, p_restock_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.sale_returns%rowtype; s public.sales%rowtype; a public.credit_accounts%rowtype; x record;
 returned numeric; consumed numeric; v_value numeric:=0; reduction numeric:=0; refund numeric; available numeric; member uuid; payload jsonb; previous jsonb; result jsonb; branch_previous numeric; branch_new numeric;
begin
 select * into r from public.sale_returns where id=p_return_id;
 if not found then raise exception 'Return not found' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_refund',r.branch_id,true);
 payload:=jsonb_build_object('operation','pos_return_approval','return',p_return_id,'method',p_method,'confirmed',p_confirmed,'evidence',p_evidence,'shift',p_shift_id,'restock',p_restock,'restock_reason',p_restock_reason);
 previous:=private.operation_replay(r.business_id,p_request_id,payload);if previous is not null then return previous;end if;
 if p_restock is null or p_confirmed is distinct from true or
  (not p_restock and nullif(btrim(p_restock_reason),'') is null) then
  raise exception 'Confirm the return and explain any decision not to restock';
 end if;
 select * into s from public.sales where id=r.sale_id for update;
 select * into r from public.sale_returns where id=p_return_id for update;
 if r.status<>'inspected' then raise exception 'Separate condition inspection required';end if;
 for x in select i.*,si.product_id,si.quantity sold_qty,si.total sold_value from public.return_items i join public.sale_items si on si.id=i.sale_item_id where i.return_id=r.id order by si.product_id,i.sale_item_id loop
  select coalesce(sum(i.quantity),0),coalesce(sum(i.value),0) into returned,consumed from public.return_items i join public.sale_returns old on old.id=i.return_id where i.sale_item_id=x.sale_item_id and old.status='approved';
  if returned+x.quantity>x.sold_qty then raise exception 'Return exceeds remaining original quantity';end if;
  if x.quantity+returned=x.sold_qty then available:=x.sold_value-consumed;else available:=least(x.sold_value-consumed,round(x.sold_value*x.quantity/x.sold_qty,2));end if;
  update public.return_items set value=available where id=x.id;v_value:=v_value+available;
 end loop;
 select * into a from public.credit_accounts where sale_id=r.sale_id for update;
 if found then reduction:=least(a.outstanding,v_value);end if;
 refund:=v_value-reduction;
 if refund>0 then
  if p_method not in('cash','bank_transfer','card') or p_confirmed is distinct from true or (p_method<>'cash' and nullif(btrim(p_evidence),'')is null) then raise exception 'Confirm actual refund and external reference';end if;
  select coalesce(sum(amount),0) into available from public.sale_payments where sale_id=r.sale_id and method=p_method;
  if not exists(select 1 from public.sale_payments where sale_id=r.sale_id) and s.payment_method=p_method then available:=s.total;end if;
  available:=available+coalesce((select -sum(amount) from public.credit_entries where sale_id=r.sale_id and kind in('repayment','repayment_reversal') and method=p_method),0)-coalesce((select sum(refund_amount) from public.sale_returns where sale_id=r.sale_id and status='approved' and refund_method=p_method),0);
  if refund>available then raise exception 'Refund exceeds money actually collected by this method';end if;
 end if;
 select id into member from public.business_members where business_id=r.business_id and user_id=auth.uid() and status='active';
 perform p.id from public.products p where p.business_id=r.business_id and p.id in(select si.product_id from public.return_items ri join public.sale_items si on si.id=ri.sale_item_id where ri.return_id=r.id) order by p.id for update;
 if refund>0 and p_method='cash' then perform private.validate_operational_shift(r.business_id,member,p_shift_id,r.branch_id);end if;
 if reduction>0 then
  update public.credit_accounts set outstanding=outstanding-reduction where sale_id=r.sale_id;
  insert into public.credit_entries(business_id,sale_id,request_id,actor_id,kind,amount,reason,reference_id) values(r.business_id,r.sale_id,p_request_id,auth.uid(),'return',-reduction,r.reason,r.id);
 end if;
 for x in select i.*,si.product_id from public.return_items i join public.sale_items si on si.id=i.sale_item_id where i.return_id=r.id order by si.product_id loop
  if x.condition='sellable' and p_restock then
   -- Inspection is independently authorized above; refund approval may restock
   -- only the exact inspected quantity and original product, never a price field.
   perform set_config('trexven.catalog_reason','Inspected sellable return: '||r.reason,true);
   perform set_config('trexven.catalog_request',r.id::text,true);
   perform set_config('trexven.catalog_operation','return',true);
   if r.branch_id is null then
    update public.products set quantity=coalesce(quantity,0)+x.quantity,updated_at=now() where id=x.product_id and business_id=r.business_id;
   else
    -- The original branch is authorized by operations_context above. Products
    -- are already locked in the established product-before-inventory order.
    select quantity into branch_previous from public.inventory
     where business_id=r.business_id and branch_id=r.branch_id and product_id=x.product_id for update;
    if not found then raise exception 'Original branch inventory row is unavailable';end if;
    update public.inventory set quantity=coalesce(quantity,0)+x.quantity,updated_at=now()
     where business_id=r.business_id and branch_id=r.branch_id and product_id=x.product_id
     returning quantity into branch_new;
    insert into public.inventory_movements(business_id,product_id,branch_id,movement_type,quantity,previous_quantity,new_quantity,reference_id,reason,source,notes)
     values(r.business_id,x.product_id,r.branch_id,'return',x.quantity,coalesce(branch_previous,0),branch_new,r.id,r.reason,'customer_return','Inspected sellable return to original branch');
   end if;
  end if;
 end loop;
 perform set_config('trexven.catalog_operation','',true);perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);
 update public.sale_returns set status='approved',approved_by=auth.uid(),value=v_value,debt_reduction=reduction,refund_amount=refund,refund_method=case when refund>0 then p_method end,refund_evidence=p_evidence,approved_at=now() where id=r.id;
 if refund>0 and p_method='cash' then perform private.record_operational_cash(r.business_id,member,-refund,'refund',r.id,p_shift_id);end if;
 result:=jsonb_build_object('return_id',r.id,'value',v_value,'debt_reduction',reduction,'refund',refund,'restock',p_restock,'restock_reason',p_restock_reason);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'sale_return_approved',result);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $function$

CREATE OR REPLACE FUNCTION public.issue_pos_branch_offline_scope(p_business_id uuid, p_device_id uuid, p_branch_id uuid, p_shift_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare member uuid; leaseid uuid:=gen_random_uuid(); secret bytea; scope jsonb; signature text; started timestamptz:=clock_timestamp(); expiry timestamptz;
begin
 if p_branch_id is null then raise exception 'Authorized branch required' using errcode='42501'; end if;
 perform private.operations_context(p_business_id,'offline_cash',p_branch_id);
 if private.has_business_permission(p_business_id,'offline_cash') is distinct from true
 or private.has_business_permission(p_business_id,'pos_access') is distinct from true
 or private.has_business_permission(p_business_id,'complete_sales') is distinct from true then
  raise exception 'Current offline cash authority required' using errcode='42501'; end if;
 if not private.subscription_entitled(p_business_id,'pos') then raise exception 'Subscription POS access unavailable';end if;
 expiry:=least(started+interval '24 hours',coalesce((select case when status='past_due' then grace_until else expires_at end from public.business_subscriptions where business_id=p_business_id and enforce),started+interval '24 hours'));
 if not private.has_business_permission(p_business_id,'complete_sales') or not private.has_business_permission(p_business_id,'pos_access') then raise exception 'Cash sale permission required' using errcode='42501';end if;
 if p_device_id is null then raise exception 'Stable device identity required';end if;
 select m.id into member from public.business_members m where business_id=p_business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(p_business_id,member,p_shift_id,p_branch_id,false);
 select jsonb_build_object('version',1,'lease_id',leaseid,'business_id',p_business_id,'user_id',auth.uid(),'membership_id',member,'device_id',p_device_id,
 'issued_at',started,'expires_at',expiry,'branch_id',p_branch_id,'shift_id',p_shift_id,'products',coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'unit',p.unit,'price',p.selling_price,'quantity',greatest(i.quantity-i.reserved_quantity,0),'barcode',p.barcode,'sku',p.sku) order by p.id),'[]'::jsonb)) into scope
 from public.products p join public.inventory i on i.product_id=p.id and i.business_id=p.business_id
 and i.branch_id=p_branch_id where p.business_id=p_business_id and p.selling_price is not null and p.active is true and p.is_active;
 secret:=extensions.gen_random_bytes(32);
 signature:=encode(extensions.hmac(convert_to(scope::text,'UTF8'),secret,'sha256'),'hex');
 insert into private.offline_cash_leases values(leaseid,p_business_id,auth.uid(),member,p_device_id,scope,signature,secret,started,expiry);
 return jsonb_build_object('scope',scope,'signature',signature);
end $function$

CREATE OR REPLACE FUNCTION public.sync_pos_branch_offline_cash(p_request_id uuid, p_ticket jsonb, p_items jsonb, p_total numeric, p_occurred_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare lease private.offline_cash_leases%rowtype; payload jsonb; prior jsonb; receipt jsonb; sale uuid; x jsonb; snapshot jsonb;
 product public.products%rowtype; qty numeric; price numeric; v_total numeric:=0; missing numeric; discrepancies jsonb:='[]'; shift uuid; v_branch uuid; v_stock numeric; v_reserved numeric; v_new numeric;
begin
 select * into lease from private.offline_cash_leases where id=(p_ticket->'scope'->>'lease_id')::uuid;
 if not found or auth.uid() is distinct from lease.user_id or p_ticket->'scope' is distinct from lease.scope or
 p_ticket->>'signature' is distinct from encode(extensions.hmac(convert_to(lease.scope::text,'UTF8'),lease.signing_key,'sha256'),'hex') then raise exception 'Invalid signed offline authorization' using errcode='42501';end if;
 v_branch:=(lease.scope->>'branch_id')::uuid;
 if v_branch is null then raise exception 'Signed branch scope required' using errcode='42501'; end if;
 perform private.operations_context(lease.business_id,'offline_cash',v_branch);
 if private.has_business_permission(lease.business_id,'offline_cash') is distinct from true
 or private.has_business_permission(lease.business_id,'pos_access') is distinct from true
 or private.has_business_permission(lease.business_id,'complete_sales') is distinct from true then
  raise exception 'Current cash authority required; retain the original request for owner review' using errcode='42501'; end if;
 if not private.has_business_permission(lease.business_id,'complete_sales') or not exists(select 1 from public.business_members where id=lease.member_id and user_id=auth.uid() and business_id=lease.business_id and status='active') then raise exception 'Current sale authorization required; retain queue for owner review' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','pos_branch_offline_cash','ticket',p_ticket,'items',p_items,'total',p_total,'occurred_at',p_occurred_at);
 perform pg_advisory_xact_lock(hashtextextended(lease.business_id::text||auth.uid()::text||p_request_id::text,0));
 prior:=private.operation_replay(lease.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if exists(select 1 from private.sale_requests where business_id=lease.business_id and user_id=auth.uid() and request_id=p_request_id) then raise exception 'This key belongs to an original checkout; recover that receipt before another submission';end if;
 if exists(select 1 from public.businesses where id=lease.business_id and pos_writes_paused) then raise exception 'POS writes are paused; retain the encrypted cash queue';end if;
 if p_occurred_at is null or p_occurred_at<lease.issued_at or p_occurred_at>=lease.expires_at or p_occurred_at>clock_timestamp()+interval '5 minutes'
 or not private.valid_money(p_total,true) or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cash sale is outside its authorized scope';end if;
 if exists(select 1 from jsonb_array_elements(p_items) i group by i->>'product_id' having count(*)>1) then raise exception 'Duplicate offline product';end if;
 shift:=(lease.scope->>'shift_id')::uuid;
 perform id from public.products where business_id=lease.business_id and id in(select (i->>'product_id')::uuid from jsonb_array_elements(p_items)i) order by id for update;
 perform private.validate_operational_shift(lease.business_id,lease.member_id,shift,v_branch,true);
 perform set_config('trexven.transaction_contract','v2',true);
 perform set_config('trexven.catalog_operation','offline_cash',true);
 insert into public.sales(business_id,employee_id,branch_id,total,total_amount,payment_method,status,sold_at) values(lease.business_id,lease.member_id,v_branch,p_total,p_total,'cash','completed',p_occurred_at) returning id into sale;
 for x in select * from jsonb_array_elements(p_items) loop
  select s into snapshot from jsonb_array_elements(lease.scope->'products') s where s->>'id'=x->>'product_id';
  qty:=(x->>'quantity')::numeric;price:=(x->>'unit_price')::numeric;
  if snapshot is null or qty is null or qty<=0 or qty::text in('NaN','Infinity','-Infinity') or scale(qty)>3 or price is distinct from (snapshot->>'price')::numeric or coalesce((x->>'discount')::numeric,0)<>0 then raise exception 'Offline quantities and price must match signed catalog';end if;
  if lower(coalesce(snapshot->>'unit','piece')) not in('kg','g','litre','ml','metre','cm') and qty<>trunc(qty) then raise exception 'Countable offline stock requires whole units';end if;
  select * into product from public.products where id=(x->>'product_id')::uuid and business_id=lease.business_id;
  if not found then raise exception 'Original offline product is missing; retain for reconciliation';end if;
  select quantity,reserved_quantity into v_stock,v_reserved from public.inventory
   where business_id=lease.business_id and product_id=product.id and branch_id=v_branch for update;
  if not found then raise exception 'Original branch stock mapping unavailable; retain for owner reconciliation'; end if;
  missing:=greatest(qty-greatest(v_stock-v_reserved,0),0);
  if missing>0 then discrepancies:=discrepancies||jsonb_build_array(jsonb_build_object('product_id',product.id,'requested',qty,'shortfall',missing));end if;
  perform set_config('trexven.catalog_operation','offline_cash',true);perform set_config('trexven.catalog_request',sale::text,true);
  perform set_config('trexven.catalog_reason','Offline cash reconciliation; requested '||qty||', shortfall '||missing,true);
  update public.inventory set quantity=greatest(v_stock-qty,v_reserved),updated_at=now()
   where business_id=lease.business_id and product_id=product.id and branch_id=v_branch
   returning quantity into v_new;
  insert into public.inventory_movements(business_id,product_id,branch_id,movement_type,quantity,previous_quantity,new_quantity,reference_id,reason,source,notes)
   values(lease.business_id,product.id,v_branch,'sale',v_new-v_stock,v_stock,v_new,sale,
    'Signed branch offline cash reconciliation','offline_cash','Requested '||qty||'; shortfall '||missing);
  insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total) values(sale,product.id,snapshot->>'name',qty,price,0,round(qty*price,2));
  v_total:=v_total+round(qty*price,2);
 end loop;
 if v_total is distinct from p_total then raise exception 'Offline total mismatch';end if;
 update public.sales set sale_number='TRX-'||sale::text,subtotal=v_total where id=sale;
 insert into public.sale_payments(business_id,sale_id,request_id,actor_id,method,amount,evidence,confirmed_at) values(lease.business_id,sale,p_request_id,auth.uid(),'cash',v_total,'Signed offline cash scope',p_occurred_at);
 insert into public.offline_sale_reconciliations(business_id,sale_id,lease_id,request_id,device_id,actor_id,occurred_at,discrepancies) values(lease.business_id,sale,lease.id,p_request_id,lease.device_id,auth.uid(),p_occurred_at,discrepancies);
 if v_total>0 then perform private.record_operational_cash(lease.business_id,lease.member_id,v_total,'sale',sale,shift);end if;
 if jsonb_array_length(discrepancies)>0 then
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(lease.business_id,auth.uid(),'offline_stock_discrepancy',jsonb_build_object('sale_id',sale,'discrepancies',discrepancies));
 end if;
 select to_jsonb(s)||jsonb_build_object('sale_items',(select jsonb_agg(to_jsonb(i) order by i.id) from public.sale_items i where sale_id=s.id),'offline_discrepancies',discrepancies) into receipt from public.sales s where id=sale;
 perform private.operation_save(lease.business_id,p_request_id,payload,receipt);
 perform set_config('trexven.catalog_operation','',true);perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);perform set_config('trexven.transaction_contract','',true);
 return receipt;
end $function$

revoke all on function public.approve_pos_return(uuid,uuid,text,boolean,text,uuid,boolean,text) from public,anon;
revoke all on function public.issue_pos_branch_offline_scope(uuid,uuid,uuid,uuid) from public,anon;
revoke all on function public.sync_pos_branch_offline_cash(uuid,jsonb,jsonb,numeric,timestamptz) from public,anon;
grant execute on function public.approve_pos_return(uuid,uuid,text,boolean,text,uuid,boolean,text) to authenticated;
grant execute on function public.issue_pos_branch_offline_scope(uuid,uuid,uuid,uuid) to authenticated;
grant execute on function public.sync_pos_branch_offline_cash(uuid,jsonb,jsonb,numeric,timestamptz) to authenticated;
notify pgrst,'reload schema';

create function private.pos_notification_feed(business uuid, branch uuid)
returns table(alert_key text,title text,message text,route text,reference_id uuid,occurred_at timestamptz)
language plpgsql security definer set search_path='' as $fn$
begin
 if private.has_business_permission(business,'pos_access') is true then
  perform private.operations_context(business,'pos_access',branch);
 elsif private.has_business_permission(business,'view_inventory') is true then
  perform private.operations_context(business,'view_inventory',branch);
 else raise exception 'Current POS access required' using errcode='42501';
 end if;
 if branch is null then
  return query
  select 'alert:'||a.id::text,a.title,a.message,'inventory'::text,a.reference_id,a.created_at
  from public.alerts a where a.business_id=business and a.alert_type like '%stock%'
   and private.has_business_permission(business,'view_inventory') is true
   and private.subscription_entitled(business,'low_stock_alerts')
  union all
  select 'cash_review:'||s.id::text,'Closed drawer requires review',
   'Review its recorded count and variance.','cash',s.id,s.closed_at
  from public.cash_shifts s where s.business_id=business and s.branch_id is null
   and s.status='closed' and s.review_status='pending'
   and private.has_business_permission(business,'review_cash_shifts') is true;
 else
  return query
  select 'branch_stock:'||branch::text||':'||p.id::text,'Low stock in your branch'::text,
   p.name||' has reached its branch stock threshold.','inventory'::text,p.id,i.updated_at
  from public.inventory i join public.products p on p.id=i.product_id and p.business_id=i.business_id
  where i.business_id=business and i.branch_id=branch and i.quantity-i.reserved_quantity<=p.low_stock_threshold
   and private.has_business_permission(business,'view_inventory') is true
   and private.subscription_entitled(business,'low_stock_alerts')
  union all
  select 'cash_review:'||s.id::text,'Closed drawer requires review',
   'Review its recorded count and variance.','cash',s.id,s.closed_at
  from public.cash_shifts s where s.business_id=business and s.branch_id=branch
   and s.status='closed' and s.review_status='pending'
   and private.has_business_permission(business,'review_cash_shifts') is true
  union all
  select 'inventory_review:'||r.id::text,'Inventory discrepancy requires review',
   'Review the original stocktake and movement.','inventory',r.id,null::timestamptz
  from public.inventory_reconciliation_reviews r join public.stocktake_sessions s
   on s.id=r.session_id and s.business_id=r.business_id
  where r.business_id=business and s.branch_id=branch and r.status='pending'
   and private.has_business_permission(business,'approve_stocktake') is true;
 end if;
 return query
 select 'credit_approval:'||a.id::text,'Credit sale awaiting approval'::text,
  'Review the original saved sale; no additional payment is collected.'::text,'credit'::text,a.id,a.created_at
 from public.credit_approvals a where a.business_id=business and a.branch_id is not distinct from branch
  and a.status='pending' and (a.requested_by=auth.uid() or private.has_business_permission(business,'approve_credit') is true)
 union all
 select 'return:'||r.id::text,'Return awaiting inspection or approval',
  'Inspect the original items and review debt reduction before refunding.','returns',r.id,r.created_at
 from public.sale_returns r where r.business_id=business and r.branch_id is not distinct from branch
  and r.status in ('requested','inspected') and (r.requested_by=auth.uid()
   or private.has_business_permission(business,'inspect_returns') is true
   or private.has_business_permission(business,'approve_refund') is true);
end $fn$;
revoke all on function private.pos_notification_feed(uuid,uuid) from public,anon,authenticated;

create function public.get_pos_notifications(p_business_id uuid,p_branch_id uuid default null,p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare result jsonb;
begin
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid notification page'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc nulls last,t.alert_key),'[]'::jsonb)
 into result from (
  select n.*,r.read_at from private.pos_notification_feed(p_business_id,p_branch_id) n
  left join public.trexven_notification_reads r on r.business_id=p_business_id
   and r.user_id=auth.uid() and r.alert_key=n.alert_key
  order by n.occurred_at desc nulls last,n.alert_key limit 100 offset p_offset
 ) t;
 return result;
end $fn$;
revoke all on function public.get_pos_notifications(uuid,uuid,integer) from public,anon;
grant execute on function public.get_pos_notifications(uuid,uuid,integer) to authenticated;

create function public.mark_pos_notification_read(p_business_id uuid,p_alert_key text,p_read boolean,p_branch_id uuid default null)
returns void language plpgsql security definer set search_path='' as $fn$
begin
 if p_read is null or not exists(select 1 from private.pos_notification_feed(p_business_id,p_branch_id) n
  where n.alert_key=p_alert_key) then raise exception 'Current authorized notification required' using errcode='42501'; end if;
 if p_read then
  insert into public.trexven_notification_reads(business_id,user_id,alert_key) values(p_business_id,auth.uid(),p_alert_key)
  on conflict(business_id,user_id,alert_key) do update set read_at=now();
 else
  delete from public.trexven_notification_reads where business_id=p_business_id and user_id=auth.uid() and alert_key=p_alert_key;
 end if;
end $fn$;
revoke all on function public.mark_pos_notification_read(uuid,text,boolean,uuid) from public,anon;
grant execute on function public.mark_pos_notification_read(uuid,text,boolean,uuid) to authenticated;

create function public.get_pos_operation_history(p_business_id uuid,p_branch_id uuid default null,p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare result jsonb;
begin
 if private.has_business_permission(p_business_id,'pos_access') is true then
  perform private.operations_context(p_business_id,'pos_access',p_branch_id);
 elsif private.has_business_permission(p_business_id,'view_inventory') is true then
  perform private.operations_context(p_business_id,'view_inventory',p_branch_id);
 else raise exception 'Current POS access required' using errcode='42501';
 end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid history page'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc,t.request_id),'[]'::jsonb) into result from (
  select r.request_id,r.created_at,r.payload->>'operation' as operation,'confirmed'::text as status
  from private.catalog_requests r where r.business_id=p_business_id and r.actor_id=auth.uid()
   and r.payload->>'operation' not like '%billing%' and r.payload->>'operation' not like '%subscription%'
   and (case when p_branch_id is null then
      coalesce(r.payload->>'branch',r.payload->'ticket'->'scope'->>'branch_id',r.payload->>'source') is null
    else
      p_branch_id::text in (r.payload->>'branch',r.payload->'ticket'->'scope'->>'branch_id',
        r.payload->>'source',r.payload->>'destination')
      or exists(select 1 from public.sale_returns s where s.business_id=p_business_id
       and s.branch_id=p_branch_id and s.id::text=r.payload->>'return')
      or exists(select 1 from public.sales s where s.business_id=p_business_id
       and s.branch_id=p_branch_id and s.id::text=r.payload->>'sale')
      or exists(select 1 from public.stocktake_sessions s where s.business_id=p_business_id
       and s.branch_id=p_branch_id and s.id::text=r.payload->>'session')
      or exists(select 1 from public.cash_shifts s where s.business_id=p_business_id
       and s.branch_id=p_branch_id and s.id::text=r.payload->>'shift')
      or exists(select 1 from public.stock_transfers s where s.business_id=p_business_id
       and (s.source_branch=p_branch_id or s.destination_branch=p_branch_id) and s.id::text=r.payload->>'transfer')
    end)
  order by r.created_at desc,r.request_id limit 100 offset p_offset
 ) t;
 return result;
end $fn$;
revoke all on function public.get_pos_operation_history(uuid,uuid,integer) from public,anon;
grant execute on function public.get_pos_operation_history(uuid,uuid,integer) to authenticated;
notify pgrst,'reload schema';

-- Complete the POS-only feed without changing Owner notification APIs.
create or replace function private.pos_notification_feed(business uuid, branch uuid)
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

 return query
 select 'staff:'||a.id::text,'Employee access changed'::text,
  'Review current access. This update does not grant a new permission.'::text,'employees'::text,a.target_id,a.created_at
 from public.audit_logs a join public.employees e on e.id=a.target_id and e.business_id=a.business_id
 where a.business_id=business and a.action in ('employee_updated','employee_permission_changed','employee_status_changed')
  and (e.user_id=auth.uid() or private.has_business_permission(business,'manage_employees') is true)
  and (branch is null or exists(select 1 from public.employee_branch_assignments b
   where b.business_id=business and b.employee_id=e.id and b.branch_id=branch and b.is_active));
 if branch is null then
  return query select 'inventory_review:'||r.id::text,'Inventory discrepancy requires review'::text,
   'Review the original stocktake and movement.'::text,'inventory'::text,r.id,null::timestamptz
  from public.inventory_reconciliation_reviews r join public.stocktake_sessions s on s.id=r.session_id and s.business_id=r.business_id
  where r.business_id=business and s.branch_id is null and r.status='pending'
   and private.has_business_permission(business,'approve_stocktake') is true;
 end if;
end $fn$;
revoke all on function private.pos_notification_feed(uuid,uuid) from public,anon,authenticated;
notify pgrst,'reload schema';

begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338','20261009070340','20261009075117','20261009075318','20261009075612','20261009075911','20261009080227']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

create function private.audit_sale_terms() returns trigger language plpgsql security definer set search_path='' as $$
declare business uuid; price numeric;
begin
 select business_id into business from public.sales where id=new.sale_id;
 select selling_price into price from public.products where id=new.product_id and business_id=business;
 if auth.uid() is not null and (new.unit_price is distinct from price or coalesce(new.discount,0)>0) then
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(business,auth.uid(),'sale_terms_authorized',jsonb_build_object('sale_id',new.sale_id,'sale_item_id',new.id,'product_id',new.product_id,'catalog_price',price,'sold_price',new.unit_price,'quantity',new.quantity,'discount',new.discount));
 end if;return new;
end $$;
revoke all on function private.audit_sale_terms() from public,anon,authenticated;
create trigger batch_4_sale_terms after insert on public.sale_items for each row execute function private.audit_sale_terms();
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009080751','batch_4_financial_audit_events',array[$trexven_release_source$begin;
create function private.audit_sale_terms() returns trigger language plpgsql security definer set search_path='' as $$
declare business uuid; price numeric;
begin
 select business_id into business from public.sales where id=new.sale_id;
 select selling_price into price from public.products where id=new.product_id and business_id=business;
 if auth.uid() is not null and (new.unit_price is distinct from price or coalesce(new.discount,0)>0) then
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(business,auth.uid(),'sale_terms_authorized',jsonb_build_object('sale_id',new.sale_id,'sale_item_id',new.id,'product_id',new.product_id,'catalog_price',price,'sold_price',new.unit_price,'quantity',new.quantity,'discount',new.discount));
 end if;return new;
end $$;
revoke all on function private.audit_sale_terms() from public,anon,authenticated;
create trigger batch_4_sale_terms after insert on public.sale_items for each row execute function private.audit_sale_terms();
commit;
$trexven_release_source$]::text[]);
commit;

begin;
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

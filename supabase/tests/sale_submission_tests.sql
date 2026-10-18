begin;
do $$
declare u uuid:=gen_random_uuid(); b uuid; p uuid; member uuid; key uuid:=gen_random_uuid();
 receipt jsonb; retry jsonb; items jsonb; failed boolean; before_stock numeric; before_sales integer;
begin
 insert into auth.users(id,email,raw_user_meta_data) values(u,'sale-test-'||u||'@example.invalid','{}');
 perform set_config('request.jwt.claim.sub',u::text,true);
 set local role authenticated;
 b:=public.complete_trexven_onboarding('Sale regression','Other','Nigeria','NGN');
 select id into member from public.business_members where business_id=b and user_id=u;
 insert into public.products(business_id,name,selling_price,quantity) values(b,'Test item',10,20) returning id into p;
 items:=jsonb_build_array(jsonb_build_object('product_id',p,'quantity',2,'unit_price',10,'discount',0));
 receipt:=public.submit_trexven_sale(key,b,null,20,'cash',items,true);
 retry:=public.submit_trexven_sale(key,b,null,20,'cash',items,true);
 if receipt<>retry or (select quantity from public.products where id=p)<>18 or
 (select count(*) from public.sales where business_id=b)<>1 then raise exception 'Quick sale retry duplicated'; end if;
 if receipt->>'payment_method'<>'cash' or receipt->>'sale_number' is null or
 jsonb_array_length(receipt->'sale_items')<>1 or (receipt->>'total')::numeric<>20 then raise exception 'Quick payment/receipt missing'; end if;
 failed:=false;
 begin perform public.submit_trexven_sale(key,b,null,20,'card',items,true); exception when others then failed:=true; end;
 if not failed then raise exception 'Changed retry details accepted'; end if;
 key:=gen_random_uuid();
 receipt:=public.submit_trexven_sale(key,b,member,20,'card',items,false);
 retry:=public.submit_trexven_sale(key,b,member,20,'card',items,false);
 if receipt<>retry or (select quantity from public.products where id=p)<>16 or
 (select count(*) from public.sales where business_id=b)<>2 then raise exception 'POS retry duplicated'; end if;
 if receipt->>'payment_method'<>'card' or receipt->>'sale_number' is null then raise exception 'POS payment/receipt missing'; end if;
 perform public.submit_trexven_sale(gen_random_uuid(),b,member,20,'bank_transfer',items,false);
 -- Every invalid transaction must leave sale/items/stock/retry record atomic.
 before_stock:=(select quantity from public.products where id=p);
 before_sales:=(select count(*) from public.sales where business_id=b);
 failed:=false;
 begin perform public.submit_trexven_sale(gen_random_uuid(),b,member,999,'cash',items,false); exception when others then failed:=true; end;
 if not failed then raise exception 'Wrong total accepted'; end if;
 failed:=false;
 begin perform public.submit_trexven_sale(gen_random_uuid(),b,member,20,'Cash',items,false); exception when others then failed:=true; end;
 if not failed then raise exception 'UI payment label accepted'; end if;
 failed:=false;
 begin perform public.submit_trexven_sale(gen_random_uuid(),b,member,200,'cash',
 jsonb_build_array(jsonb_build_object('product_id',p,'quantity',20,'unit_price',10)),false);
 exception when others then failed:=true; end;
 if not failed then raise exception 'Oversell accepted'; end if;
 failed:=false;
 begin perform public.submit_trexven_sale(gen_random_uuid(),b,gen_random_uuid(),20,'cash',items,false); exception when others then failed:=true; end;
 if not failed then raise exception 'Wrong employee accepted'; end if;
 failed:=false;
 begin perform public.submit_trexven_sale(gen_random_uuid(),b,null,2,'cash',
 jsonb_build_array(jsonb_build_object('product_id',p,'quantity',2,'unit_price',1)),true);
 exception when others then failed:=true; end;
 if not failed then raise exception 'Changed price accepted'; end if;
 if (select quantity from public.products where id=p)<>before_stock or
 (select count(*) from public.sales where business_id=b)<>before_sales then raise exception 'Failed request left partial writes'; end if;
 -- Discounted, repeated lines keep their existing behavior.
 items:=jsonb_build_array(jsonb_build_object('product_id',p,'quantity',1,'unit_price',10,'discount',2),
 jsonb_build_object('product_id',p,'quantity',1,'unit_price',10,'discount',0));
 receipt:=public.submit_trexven_sale(gen_random_uuid(),b,member,18,'cash',items,false);
 if (receipt->>'discount')::numeric<>2 or jsonb_array_length(receipt->'sale_items')<>2 or
 (select quantity from public.products where id=p)<>before_stock-2 then raise exception 'Discount/repeated lines failed'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 failed:=false;
 begin perform public.submit_trexven_sale(key,b,member,20,'card',items,false); exception when insufficient_privilege then failed:=true; end;
 if not failed then raise exception 'Foreign account can replay receipt'; end if;
 reset role;
end $$;
select 'PASS: quick/POS creation, cash/card/transfer, saved receipt/items, retry deduplication, changed payload rejection, stock, discount, total/price/employee/permission validation and atomic rollback' as verification;
rollback;

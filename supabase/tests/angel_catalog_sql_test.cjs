// Ephemeral PostgreSQL only. Executes the migration and the existing catalog
// RPC/validation/history bodies against a minimal synthetic contract fixture.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const {PGlite}=require('../../.tool-cache/angel-tests/node_modules/@electric-sql/pglite');
const root=path.resolve(__dirname,'../..');
const db=new PGlite();
let checks=0;
const equal=(a,b,label)=>{assert.deepEqual(a,b,label);checks++};
async function reject(sql,args=[],code){await assert.rejects(()=>db.query(sql,args),e=>!code||e.code===code);checks++}
async function scalar(sql,args=[]){return (await db.query(sql,args)).rows[0].value}
const owner=randomUUID(),other=randomUUID(),employee=randomUUID(),business=randomUUID(),foreign=randomUUID(),conversation=randomUUID(),product=randomUUID();
async function prepare(operation,value,query=product,conv=conversation,biz=business){return scalar('select public.prepare_trexven_angel_catalog_action($1,$2,$3,$4,$5,$6,$7) as value',[biz,conv,query,operation,String(value),'Synthetic owner task','Synthetic request'])}
async function resolve(a,confirm=true,conv=conversation,biz=business){return scalar('select public.resolve_trexven_angel_catalog_action($1,$2,$3,$4) as value',[biz,conv,a.id,confirm])}
async function actor(id,role='authenticated'){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id??'']);await db.exec('set role '+role)}
async function admin(sql,args=[]){await db.exec('reset role');const r=await db.query(sql,args);await db.exec('set role authenticated');return r}
(async()=>{
  await db.exec(`
    create role authenticated;create role anon;create schema auth;create schema private;
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create table auth.users(id uuid primary key,active boolean not null default true);
    create table public.businesses(id uuid primary key,owner_id uuid references auth.users, country text,timezone text,branches_enabled boolean not null default false);
    create table public.angel_conversations(id uuid primary key,business_id uuid references public.businesses,user_id uuid references auth.users);
    create table public.employees(id uuid default gen_random_uuid(),business_id uuid,user_id uuid);
    create table public.business_members(id uuid default gen_random_uuid(),business_id uuid,user_id uuid);
    create table public.product_groups(id uuid primary key,business_id uuid);
    create table public.products(id uuid primary key default gen_random_uuid(),business_id uuid references public.businesses,name text,sku text,barcode text,description text,category text,brand text,image_url text,unit text default 'piece',selling_price numeric,quantity numeric default 0,low_stock_threshold numeric default 5,active boolean default true,is_active boolean default true,catalog_group_id uuid,variant_attributes jsonb default '{}',updated_at timestamptz default now());
    create table public.audit_logs(id uuid default gen_random_uuid(),business_id uuid,actor_id uuid,action text,metadata jsonb);
    create table public.alerts(id uuid default gen_random_uuid(),business_id uuid,alert_type text,title text,message text,severity text,source text,reference_id uuid);
    create table public.inventory_movements(business_id uuid,product_id uuid,employee_id uuid,movement_type text,quantity numeric,previous_quantity numeric,new_quantity numeric,reference_id uuid,reason text,source text);
    create table private.catalog_requests(request_id uuid primary key,business_id uuid,actor_id uuid,payload jsonb,response jsonb,created_at timestamptz);
    create table private.catalog_low_stock_state(product_id uuid primary key,business_id uuid,below_threshold boolean);
    create function public.user_owns_business(b uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.businesses b1 join auth.users u on u.id=b1.owner_id where b1.id=b and b1.owner_id=auth.uid() and u.active)$$;
    create function private.has_business_permission(b uuid,p text) returns boolean language sql stable security definer set search_path='' as $$select public.user_owns_business(b)$$;
    grant usage on schema auth to authenticated;grant select(id,name,selling_price,quantity) on public.products to authenticated;
  `);
  const canonical=fs.readFileSync(path.join(root,'supabase/migrations/20261009003200_batch_3_catalog_inventory_foundation.sql'),'utf8');
  for(const name of ['private.catalog_context','private.guard_product_fields','private.catalog_validate_product','public.save_trexven_catalog_product','public.adjust_trexven_catalog_stock','private.catalog_price_history','private.catalog_stock_events']){
    const escaped=name.replaceAll('.','\\.');const match=canonical.match(new RegExp('create (?:or replace )?function '+escaped+'\\([\\s\\S]*?end \\$\\$;'));
    assert.ok(match,'Canonical function exists: '+name);await db.exec(match[0]);
  }
  await db.exec(`create trigger catalog_guard before insert or update on public.products for each row execute function private.guard_product_fields();
    create trigger catalog_validation before insert or update on public.products for each row execute function private.catalog_validate_product();
    create trigger price_history after insert or update of selling_price on public.products for each row execute function private.catalog_price_history();
    create trigger stock_history after insert or update on public.products for each row execute function private.catalog_stock_events();`);
  await db.exec(fs.readFileSync(path.join(root,'supabase/migrations/20261015001244_dashboard_feeds_and_angel_catalog_tasks.sql'),'utf8'));
  await db.query('insert into auth.users(id) values($1),($2),($3)',[owner,other,employee]);
  await db.query("insert into public.businesses(id,owner_id,country,timezone) values($1,$2,'Nigeria',null),($3,$4,'Nigeria','UTC')",[business,owner,foreign,other]);
  equal(await scalar('select timezone as value from public.businesses where id=$1',[business]),'Africa/Lagos','Nigeria onboarding supplies timezone');
  equal(await scalar('select timezone as value from public.businesses where id=$1',[foreign]),'UTC','Explicit timezones preserved');
  await db.query('insert into public.angel_conversations values($1,$2,$3)',[conversation,business,owner]);
  await db.query("insert into public.products(id,business_id,name,sku,selling_price,quantity,unit) values($1,$2,'Test rice','R1',100,10,'piece')",[product,business]);
  await actor(owner);
  const price=await prepare('price',120);equal(price.status,'pending');equal(await scalar('select selling_price as value from public.products where id=$1',[product]),'100','Prepare does not mutate');
  equal((await resolve(price)).verified,true);equal(await scalar('select selling_price as value from public.products where id=$1',[product]),'120');
  equal((await resolve(price)).replayed,true,'Retry receipt');
  equal((await admin("select count(*)::int as value from public.audit_logs where action='angel_catalog_action_completed'")).rows[0].value,1,'Single audit for duplicate confirm');
  equal((await admin("select count(*)::int as value from public.audit_logs where action='catalog_price_changed'")).rows[0].value,1,'Existing price history retained');
  const restock=await prepare('stock_adjust',5);equal(restock.after_value,'15');equal((await resolve(restock)).status,'completed');
  equal((await resolve(restock)).replayed,true);equal(await scalar('select quantity as value from public.products where id=$1',[product]),'15','No doubled restock');
  equal((await admin('select count(*)::int as value from public.inventory_movements')).rows[0].value,1,'Existing stock ledger used once');
  const set=await prepare('stock_set',7);equal((await resolve(set)).after_value,'7');
  const remove=await prepare('stock_adjust',-2);equal((await resolve(remove)).after_value,'5');
  const cancelled=await prepare('price',130);equal((await resolve(cancelled,false)).status,'cancelled');equal((await resolve(cancelled)).status,'cancelled');equal(await scalar('select selling_price as value from public.products where id=$1',[product]),'120');
  const stale=await prepare('stock_set',20);await admin('update public.products set quantity=6 where id=$1',[product]);equal((await resolve(stale)).status,'conflict');equal(await scalar('select quantity as value from public.products where id=$1',[product]),'6');
  const expired=await prepare('price',140);await admin("update private.angel_catalog_actions set expires_at=now()-interval '1 minute' where id=$1",[expired.id]);equal((await resolve(expired)).status,'expired');
  const old=await prepare('price',150),latest=await prepare('price',160);equal((await resolve(old)).status,'cancelled','New proposal supersedes old');equal((await resolve(latest)).status,'completed');
  await reject('select public.prepare_trexven_angel_catalog_action($1,$2,$3,$4,$5,$6,$7)',[business,conversation,product,'price','-1','test','test'],'P0001');
  for(const [operation,value] of [['stock_set',-1],['stock_adjust',-100],['stock_set',0.5],['price',1.001],['stock_set',1.0001],['price','NaN'],['delete',1]])await assert.rejects(()=>prepare(operation,value));checks+=7;
  equal((await prepare('price',160)).status,'unchanged');
  equal((await prepare('price',170,'unknown-product')).status,'not_found');
  await admin("insert into public.products(business_id,name,sku,selling_price,quantity,unit) values($1,'Test rice','R2',10,0,'piece')",[business]);
  equal((await prepare('price',180,'Test rice')).status,'ambiguous');equal((await prepare('price',180,'R1')).status,'pending');
  await assert.rejects(()=>prepare('price',180,product,randomUUID()));checks++;
  const authorized=await prepare('stock_adjust',1);
  await actor(other);await assert.rejects(()=>resolve(authorized));await assert.rejects(()=>prepare('price',200));checks+=2;
  await actor(employee);await assert.rejects(()=>resolve(authorized));await assert.rejects(()=>prepare('price',200));checks+=2;
  await actor(null,'anon');await reject('select public.resolve_trexven_angel_catalog_action($1,$2,$3,true)',[business,conversation,authorized.id],'42501');
  await actor(owner);await assert.rejects(()=>resolve(authorized,true,conversation,foreign));checks++;
  await admin('update auth.users set active=false where id=$1',[owner]);await assert.rejects(()=>resolve(authorized));checks++;
  await admin('update auth.users set active=true where id=$1',[owner]);await admin('update public.businesses set branches_enabled=true where id=$1',[business]);await assert.rejects(()=>prepare('price',200));checks++;
  equal((await admin("select relrowsecurity as value from pg_class where oid='private.angel_catalog_actions'::regclass")).rows[0].value,true);
  equal((await admin("select has_table_privilege('authenticated','private.angel_catalog_actions','SELECT') as value")).rows[0].value,false);
  equal((await admin("select has_function_privilege('anon','public.prepare_trexven_angel_catalog_action(uuid,uuid,text,text,numeric,text,text)','EXECUTE') as value")).rows[0].value,false);
  console.log(`PASS: ${checks} PostgreSQL assertions: migration, timezone, catalog writes, price and stock history, duplicate confirmations, stale proposals, expiry, cancellation, precision, product ambiguity, owner/employee/foreign/anonymous denial, and RLS.`);
})().catch(e=>{console.error(e);process.exitCode=1}).finally(()=>db.close());

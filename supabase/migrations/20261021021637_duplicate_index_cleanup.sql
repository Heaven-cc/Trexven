-- PREPARED ONLY. Requires explicit production approval.
-- Remove one verified non-unique duplicate per pair; retain equivalent coverage.
-- The migration runner must execute this batch transactionally.
set local lock_timeout='1s';
set local statement_timeout='10s';

do $cleanup$
declare pair record;removed regclass;retained regclass;d record;k record;
 removals text[]:='{}';name text;
begin
 -- Fail immediately on active table use; never queue a blocking table lock.
 lock table public.business_members,public.businesses,public.camera_events,public.cameras,public.inventory_movements,public.products,public.sales
  in access exclusive mode nowait;

 -- Validate every pair before issuing any DROP.
 for pair in select * from (values
('business_members_business_idx','idx_business_members_business','business_members','CREATE INDEX business_members_business_idx ON public.business_members USING btree (business_id)','CREATE INDEX idx_business_members_business ON public.business_members USING btree (business_id)'),
('businesses_owner_id_idx','idx_businesses_owner','businesses','CREATE INDEX businesses_owner_id_idx ON public.businesses USING btree (owner_id)','CREATE INDEX idx_businesses_owner ON public.businesses USING btree (owner_id)'),
('idx_camera_events_business','camera_events_business_idx','camera_events','CREATE INDEX idx_camera_events_business ON public.camera_events USING btree (business_id)','CREATE INDEX camera_events_business_idx ON public.camera_events USING btree (business_id)'),
('camera_events_occurred_idx','camera_events_business_time_idx','camera_events','CREATE INDEX camera_events_occurred_idx ON public.camera_events USING btree (business_id, occurred_at DESC)','CREATE INDEX camera_events_business_time_idx ON public.camera_events USING btree (business_id, occurred_at DESC)'),
('cameras_business_idx','idx_cameras_business','cameras','CREATE INDEX cameras_business_idx ON public.cameras USING btree (business_id)','CREATE INDEX idx_cameras_business ON public.cameras USING btree (business_id)'),
('inventory_movements_business_idx','idx_inventory_movements_business','inventory_movements','CREATE INDEX inventory_movements_business_idx ON public.inventory_movements USING btree (business_id)','CREATE INDEX idx_inventory_movements_business ON public.inventory_movements USING btree (business_id)'),
('inventory_movements_product_idx','idx_inventory_movements_product','inventory_movements','CREATE INDEX inventory_movements_product_idx ON public.inventory_movements USING btree (product_id)','CREATE INDEX idx_inventory_movements_product ON public.inventory_movements USING btree (product_id)'),
('products_business_id_idx','idx_products_business','products','CREATE INDEX products_business_id_idx ON public.products USING btree (business_id)','CREATE INDEX idx_products_business ON public.products USING btree (business_id)'),
('sales_business_id_idx','idx_sales_business','sales','CREATE INDEX sales_business_id_idx ON public.sales USING btree (business_id)','CREATE INDEX idx_sales_business ON public.sales USING btree (business_id)')
 ) expected(remove_name,keep_name,table_name,remove_definition,keep_definition) loop
  removed:=to_regclass(format('%I.%I','public',pair.remove_name));
  retained:=to_regclass(format('%I.%I','public',pair.keep_name));
  if removed is null or retained is null or removed=retained then
   raise exception 'Duplicate index inventory changed: % / %',pair.remove_name,pair.keep_name;
  end if;
  select i.*,c.relam,c.relkind,c.relispartition,c.reloptions,c.reltablespace,c.relowner
   into d from pg_index i join pg_class c on c.oid=i.indexrelid where i.indexrelid=removed;
  select i.*,c.relam,c.relkind,c.relispartition,c.reloptions,c.reltablespace,c.relowner
   into k from pg_index i join pg_class c on c.oid=i.indexrelid where i.indexrelid=retained;
  if d.indrelid is distinct from to_regclass(format('%I.%I','public',pair.table_name))
   or d.relkind is distinct from 'i' or k.relkind is distinct from 'i'
   or d.relispartition is distinct from false or k.relispartition is distinct from false
   or (to_jsonb(d)-'indexrelid') is distinct from (to_jsonb(k)-'indexrelid')
   or pg_get_indexdef(removed) is distinct from pair.remove_definition
   or pg_get_indexdef(retained) is distinct from pair.keep_definition then
   raise exception 'Duplicate index structure drift: % / %',pair.remove_name,pair.keep_name;
  end if;
  if d.indisunique or d.indisprimary or d.indisexclusion or d.indisreplident or d.indisclustered
   or not d.indisvalid or not d.indisready or not d.indislive then
   raise exception 'Protected or unhealthy index: %',pair.remove_name;
  end if;
  if exists(select 1 from pg_constraint where conindid=removed)
   or exists(select 1 from pg_depend where refclassid='pg_class'::regclass and refobjid=removed)
   or exists(select 1 from pg_depend where classid='pg_class'::regclass and objid=removed and deptype='e')
   or exists(select 1 from pg_inherits where inhrelid=removed or inhparent=removed) then
   raise exception 'Index dependency appeared: %',pair.remove_name;
  end if;
  removals:=array_append(removals,pair.remove_name);
 end loop;
 foreach name in array removals loop
  execute format('drop index %I.%I restrict','public',name);
 end loop;
end $cleanup$;

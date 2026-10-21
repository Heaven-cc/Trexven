-- PREPARED ONLY. Current-state replacement for unrecorded 20261013005127.
-- No historical migration replay or history repair. No business-row rewrites.
do $baseline$
declare expected record;target regprocedure;
begin
 for expected in select * from (values
('public.complete_trexven_transaction(uuid,uuid,uuid,numeric,jsonb,jsonb,jsonb,uuid,uuid)','392c26da300d934bf68c8a8eda784f9f','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
('public.count_trexven_stock(uuid,uuid,jsonb)','739907e0a679143b935e0d4032d6709f','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
('public.inspect_trexven_return(uuid,uuid,jsonb)','b3954579cf36311c1f6c4b1be1b3eee9','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
('public.repay_trexven_credit(uuid,uuid,numeric,text,boolean,text,uuid)','b37a714b72babad334f0714ddecf1afb','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
('public.request_trexven_return(uuid,uuid,jsonb,text)','4b4ab090b7fe2737f1d9e71d99426646','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}')
 ) b(signature,definition_md5,acl) loop
  target:=to_regprocedure(expected.signature);
  if target is null or md5(pg_get_functiondef(target))<>expected.definition_md5
  or (select proacl::text from pg_proc where oid=target) is distinct from expected.acl then
   raise exception 'NULL validation definition/ACL drift: %',expected.signature;
  end if;
 end loop;
end $baseline$;

-- Reject missing JSON collections and payment methods without changing valid
-- request signatures, receipts, authorization, grants, RLS, or historical rows.
-- Fail atomically if a reviewed validation clause has drifted. Only the named
-- clauses change; pg_get_functiondef preserves the current implementation.
do $repair$
declare patch record; target regprocedure; definition text;
begin
 for patch in select * from (values
  ('public.count_trexven_stock(uuid,uuid,jsonb)',
   'jsonb_typeof(p_counts)<>''array''',
   'jsonb_typeof(p_counts) is distinct from ''array'''),
  ('public.complete_trexven_transaction(uuid,uuid,uuid,numeric,jsonb,jsonb,jsonb,uuid,uuid)',
   'jsonb_typeof(p_payments)<>''array''',
   'jsonb_typeof(p_payments) is distinct from ''array'''),
  ('public.repay_trexven_credit(uuid,uuid,numeric,text,boolean,text,uuid)',
   'p_method not in(''cash'',''bank_transfer'',''card'')',
   '(p_method is null or p_method not in(''cash'',''bank_transfer'',''card''))'),
  ('public.request_trexven_return(uuid,uuid,jsonb,text)',
   'jsonb_typeof(p_items)<>''array''',
   'jsonb_typeof(p_items) is distinct from ''array'''),
  ('public.inspect_trexven_return(uuid,uuid,jsonb)',
   'jsonb_typeof(p_conditions)<>''array''',
   'jsonb_typeof(p_conditions) is distinct from ''array'''),
  ('public.inspect_trexven_return(uuid,uuid,jsonb)',
   'line->>''condition'' not in(''sellable'',''damaged'',''defective'')',
   '(line->>''condition'' is null or line->>''condition'' not in(''sellable'',''damaged'',''defective''))')
 ) as repairs(signature,old_clause,new_clause) loop
  target:=to_regprocedure(patch.signature);
  if target is null then raise exception 'Required backend contract missing: %',patch.signature;end if;
  definition:=pg_get_functiondef(target);
  if (length(definition)-length(replace(definition,patch.old_clause,'')))/length(patch.old_clause)<>1 then
   raise exception 'Backend validation clause drift: %',patch.signature;
  end if;
  execute replace(definition,patch.old_clause,patch.new_clause);
 end loop;
end $repair$;


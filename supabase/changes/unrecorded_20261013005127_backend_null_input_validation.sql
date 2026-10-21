-- Reject missing JSON collections and payment methods without changing valid
-- request signatures, receipts, authorization, grants, RLS, or historical rows.
-- Fail atomically if a reviewed validation clause has drifted. Only the named
-- clauses change; pg_get_functiondef preserves the current implementation.
begin;
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
commit;

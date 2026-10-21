-- Phase 4: prepared only; explicit production approval required.
-- Restrict obsolete non-idempotent client write paths; no DROP, row writes,
-- receipt changes, or new privilege grants. Known old clients must upgrade.
DO $guard$
DECLARE v record; target regprocedure;
BEGIN
  FOR v IN SELECT * FROM (VALUES
    ('public.complete_pos_sale(uuid,uuid,numeric,text,jsonb)','f0f5eb7adee045796b3c75550fdbf41b','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('private.complete_pos_sale(uuid,uuid,numeric,text,jsonb)','6f82d9e018b03dd27068ce251b74e916','{postgres=X/postgres,authenticated=X/postgres}'),
    ('public.complete_trexven_transaction(uuid,uuid,uuid,numeric,jsonb,jsonb,jsonb,uuid,uuid)','392c26da300d934bf68c8a8eda784f9f','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.get_trexven_operation_receipt(uuid,uuid)','d09aff632d5ad88ddcf371901aa833eb','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.record_trexven_sale(uuid,uuid,integer,numeric)','6735cd34d42571ddc99ddbb306c8ecc3','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('private.record_trexven_sale(uuid,uuid,integer,numeric)','015232fd4eadb406b503b4ba0df780f6','{postgres=X/postgres,authenticated=X/postgres}'),
    ('public.recover_trexven_legacy_checkout(uuid,uuid,uuid,numeric,jsonb,text,uuid)','d9cc3f491cd4ba0737a135401d84a4c1','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.submit_trexven_branch_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean,uuid)','c332d41b8f5c3a0126d23c60dcfa597a','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('public.submit_trexven_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean)','76695df94dedb55462eaf27757ac50c0','{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
    ('private.submit_trexven_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean)','c738a84ca5f1dca9372689726f216f05','{postgres=X/postgres,authenticated=X/postgres}')
  ) AS baselines(signature, definition_hash, acl)
  LOOP
    target := to_regprocedure(v.signature);
    IF target IS NULL OR md5(pg_get_functiondef(target)) IS DISTINCT FROM v.definition_hash
       OR (SELECT proacl::text FROM pg_proc WHERE oid=target) IS DISTINCT FROM v.acl THEN
      RAISE EXCEPTION 'Phase 4 baseline changed: %; review before deployment', v.signature;
    END IF;
  END LOOP;
END;
$guard$;

REVOKE EXECUTE ON FUNCTION public.complete_pos_sale(uuid,uuid,numeric,text,jsonb)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.complete_pos_sale(uuid,uuid,numeric,text,jsonb)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_trexven_sale(uuid,uuid,integer,numeric)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.record_trexven_sale(uuid,uuid,integer,numeric)
  FROM PUBLIC, anon, authenticated;

-- Keep existing postgres/service_role ACLs as they are; do not add grants.
-- complete_trexven_transaction, submit_trexven_sale / branch variant,
-- recover_trexven_legacy_checkout and get_trexven_operation_receipt are untouched.

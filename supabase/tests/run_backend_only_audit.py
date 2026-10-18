"""Reuse the guarded schema-only replay; never connect to a hosted database.

The original runner and frozen suites remain byte-for-byte unchanged. This
wrapper redirects evidence to a new folder and inserts before/after validation
checks into a newly created, API-unexposed synthetic database.
"""
from pathlib import Path
import argparse
import json
import os
import re

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--execute-local', action='store_true')
parser.add_argument('--attempt', default='attempt_2')
options = parser.parse_args()
if not options.execute_local or os.environ.get('SUPABASE_DB_URL'):
    raise SystemExit('Explicit local execution required; remote configuration prohibited.')

if not re.fullmatch(r'[a-z0-9_]+', options.attempt):
    raise SystemExit('Safe evidence directory name required.')
EVIDENCE = ROOT / 'docs/implementation/evidence/backend_only_20261013' / options.attempt
if EVIDENCE.exists():
    raise SystemExit('Preserve existing evidence; select a fresh attempt name.')
EVIDENCE.mkdir(parents=True, exist_ok=True)
original = ROOT / 'supabase/tests/run_final_native_qa.py'
source = original.read_text(encoding='utf-8-sig')
for old, new in [
    ("ROOT / '.batch3-tools' / ('final_qa9_' + name + '.log')", "EVIDENCE / (name + '.log')"),
    ("ROOT / 'docs/implementation/evidence/batch_9_native_replay_results.json'", "EVIDENCE / 'database_results.json'"),
    ("ROOT/'docs/implementation/evidence/batch_9_native_replay_results.json'", "EVIDENCE / 'database_results.json'"),
    ("ROOT/'.batch3-tools/batch9_platform_prerequisite_restore.log'", "EVIDENCE / 'platform_restore.log'"),
]:
    if source.count(old) != 1:
        raise SystemExit('Reviewed replay runner has drifted: ' + old)
    source = source.replace(old, new)

fixture = (ROOT / 'supabase/tests/batch_2_fixture.sql').read_text(encoding='utf-8-sig')
old_product = "insert into public.products(business_id,name,selling_price,quantity) values(business,'Synthetic product',10,100) returning id into p;"
new_product = "p:=(public.import_trexven_catalog(business,gen_random_uuid(),'[{\"name\":\"Synthetic product\",\"selling_price\":10,\"initial_quantity\":100}]')->>0)::uuid;"
assert fixture.count(old_product) == 1
fixture = fixture.replace(old_product, new_product)
seed = (ROOT / 'supabase/tests/baseline/TREXVEN_STAGING_REFERENCE_SEED.sql').read_text(encoding='utf-8-sig')
seed = seed[seed.index('INSERT INTO public.permissions'):seed.index('INSERT INTO storage.buckets')]
prefix = """begin;
do $$ begin
 if exists(select from public.businesses) or exists(select from auth.users)
 or exists(select from storage.objects) then raise exception 'Empty synthetic database required';end if;
end $$;
create table if not exists private.batch_2_test_environment(marker text primary key);
insert into private.batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY') on conflict do nothing;
"""
test = (ROOT / 'supabase/tests/backend_null_input_tests.sql').read_text(encoding='utf-8-sig')
def validation_sql(reject):
    return prefix + "set local backend.audit_expect_rejection='" + str(reject).lower() + "';\n" + seed + fixture + test + '\nrollback;'

migration = ROOT / 'supabase/migrations/20261013005127_backend_null_input_validation.sql'
insertion = """
execute('validation_defects_reproduced', BEFORE_SQL, rolled_back=True)
execute('contract_snapshot', CONTRACT_SNAPSHOT)
# Force drift at the third patch: the first two replacements must roll back.
drift = subprocess.run(args, input=DRIFT_SQL.encode(), capture_output=True, timeout=120)
(EVIDENCE / 'migration_drift_expected_failure.log').write_bytes(drift.stdout + drift.stderr)
assert drift.returncode != 0 and b'Backend validation clause drift' in drift.stderr
execute('migration_drift_rollback_verified', DRIFT_VERIFY, expected_failure_exit=drift.returncode)
execute('backend_null_input_validation', MIGRATION_SQL)
execute('contracts_preserved', CONTRACT_VERIFY)
execute('validation_regressions', AFTER_SQL, rolled_back=True)
execute('angel_conversation_access', ANGEL_ACCESS_SQL, rolled_back=True)
"""
marker = "for suite in sorted((ROOT / '.batch3-tools/staging-final-qa').glob('*.sql')):"
assert source.count(marker) == 1
source = source.replace(marker, insertion + marker)
namespace = {
    '__file__': str(original), '__name__': '__main__', 'EVIDENCE': EVIDENCE,
    'BEFORE_SQL': validation_sql(False), 'AFTER_SQL': validation_sql(True),
    'ANGEL_ACCESS_SQL': prefix + seed + fixture + (ROOT / 'supabase/tests/angel_conversation_access_tests.sql').read_text(encoding='utf-8-sig') + '\nrollback;',
    'MIGRATION_SQL': migration.read_text(encoding='utf-8-sig'),
    'CONTRACT_SNAPSHOT': """create table private.backend_audit_contracts as
      select p.oid,md5((to_jsonb(p)-'prosrc')::text) metadata_hash,md5(p.prosrc) source_hash
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname in ('public','private');""",
    'CONTRACT_VERIFY': """do $$ begin
      if exists(select from private.backend_audit_contracts b left join pg_proc p on p.oid=b.oid
        where p.oid is null or b.metadata_hash<>md5((to_jsonb(p)-'prosrc')::text))
      then raise exception 'Function identity, grants or security changed';end if;
      if (select count(*) from private.backend_audit_contracts b join pg_proc p on p.oid=b.oid
        where b.source_hash<>md5(p.prosrc))<>5 then raise exception 'Unexpected function source changes';end if;
      end $$;""",
    'DRIFT_SQL': """begin; do $drift$ declare definition text;begin
      definition:=pg_get_functiondef('public.repay_trexven_credit(uuid,uuid,numeric,text,boolean,text,uuid)'::regprocedure);
      execute replace(definition,'p_method not in(''cash'',''bank_transfer'',''card'')',
        'p_method IS NULL');
      end $drift$;""" + migration.read_text(encoding='utf-8-sig').replace('begin;', '', 1).rsplit('commit;', 1)[0],
    'DRIFT_VERIFY': """do $$ begin
      if exists(select from private.backend_audit_contracts b join pg_proc p on p.oid=b.oid
        where b.source_hash<>md5(p.prosrc)) then raise exception 'Failed migration partially persisted';end if;
      end $$;""",
}
exec(compile(source, str(original), 'exec'), namespace)

"""Explicit final-QA runner. Synthetic loopback harness only; no deployment."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--execute-final-qa', action='store_true')
args = parser.parse_args()
if not args.execute_final_qa:
    parser.error('Execution is deferred; pass --execute-final-qa only during final QA.')
if os.environ.get('BATCH3_REPLAY_RUN') != '6' or os.environ.get('SUPABASE_DB_URL'):
    raise SystemExit('Only the explicitly selected synthetic loopback harness is allowed.')
fixture = (ROOT / 'supabase/tests/batch_2_fixture.sql').read_text(encoding='utf-8')
old = "insert into public.products(business_id,name,selling_price,quantity) values(business,'Synthetic product',10,100) returning id into p;"
new = "p:=(public.import_trexven_catalog(business,gen_random_uuid(),'[{\"name\":\"Synthetic product\",\"selling_price\":10,\"initial_quantity\":100}]')->>0)::uuid;"
if fixture.count(old) != 1:
    raise SystemExit('Fixture changed; review the catalog adaptation before execution.')
fixture = fixture.replace(old, new)
seed = (ROOT / 'supabase/tests/baseline/TREXVEN_STAGING_REFERENCE_SEED.sql').read_text(encoding='utf-8')
seed = seed[seed.index('INSERT INTO public.permissions'):seed.index('INSERT INTO storage.buckets')]
head = """begin;
do $$ begin
 if to_regprocedure('public.get_trexven_cash_context(uuid)') is null
 or to_regclass('public.business_subscriptions') is null then
 raise exception 'Replay all fourteen migrations on the fresh local schema first';end if;
end $$;
create table if not exists private.batch_2_test_environment(marker text primary key);
insert into private.batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY') on conflict do nothing;
"""
results = []
for suite in ['batch_4_financial_operations_tests', 'batch_4_offline_cash_tests',
              'batch_4_recovery_boundary_tests', 'batch_5_inventory_operations_tests',
              'batch_6_shared_drawer_tests', 'batch_7_subscription_security_tests']:
    source = (ROOT / f'supabase/tests/{suite}.sql').read_text(encoding='utf-8')
    sql_file = ROOT / '.batch3-tools/batches_4_7_final_qa.sql'
    sql_file.write_text(head + seed + fixture + source + '\nrollback;', encoding='utf-8')
    completed = subprocess.run([sys.executable, str(ROOT / '.batch3-tools/native_sql.py'), str(sql_file)],
                               cwd=ROOT, capture_output=True, text=True)
    evidence = ROOT / f'docs/implementation/evidence/{suite}_final_qa.log'
    evidence.write_text(completed.stdout + completed.stderr, encoding='utf-8')
    results.append({'suite': suite, 'exit_code': completed.returncode})
    print(suite, completed.returncode)
    if completed.returncode:
        break
(ROOT / 'docs/implementation/evidence/batches_4_7_final_qa_results.json').write_text(
    json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(1 if any(row['exit_code'] for row in results) else 0)

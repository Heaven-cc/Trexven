"""Compile reviewed psql suites into self-contained rollback-only staging tests.

No connection or credential handling. Run generated SQL only on the empty,
dedicated qysspzlfiysekvxnlzsh rehearsal project, never production.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.batch3-tools/staging-final-qa'
OUT.mkdir(exist_ok=True)
fixture = (ROOT / 'supabase/tests/batch_2_fixture.sql').read_text(encoding='utf-8')
old = "insert into public.products(business_id,name,selling_price,quantity) values(business,'Synthetic product',10,100) returning id into p;"
new = "p:=(public.import_trexven_catalog(business,gen_random_uuid(),'[{\"name\":\"Synthetic product\",\"selling_price\":10,\"initial_quantity\":100}]')->>0)::uuid;"
assert fixture.count(old) == 1
fixture = fixture.replace(old, new)
seed = (ROOT / 'supabase/tests/baseline/TREXVEN_STAGING_REFERENCE_SEED.sql').read_text(encoding='utf-8')
seed = seed[seed.index('INSERT INTO public.permissions'):seed.index('INSERT INTO storage.buckets')]
head = """begin;
-- Dedicated empty staging only. The caller must independently verify project ID.
do $$ begin
 if exists(select 1 from public.businesses) or exists(select 1 from auth.users)
 or exists(select 1 from storage.objects) then
 raise exception 'Empty synthetic staging required'; end if;
end $$;
create table if not exists private.batch_2_test_environment(marker text primary key);
insert into private.batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY') on conflict do nothing;
create temporary table test_variables(name text primary key,value text);
grant select,insert,update on test_variables to authenticated;
create function pg_temp.test_value(key text) returns text language sql as
$$ select value from pg_temp.test_variables where name=key $$;
"""
sources = list((ROOT / 'supabase/tests').glob('batch_[3456789]_*tests.sql'))
sources += [ROOT/'supabase/tests'/('batch_2_'+name+'_tests.sql') for name in
            ['authorization','branch_isolation','price_security','checkout_compatibility']]
for source in sorted(sources):
    lines = []
    json_variables = {'items', 'payments', 'credit', 'draft', 'receipt', 'return_receipt1',
                      'return_receipt2', 'summary', 'ticket', 'original', 'new_receipt',
                      'fields','update_rows','updated_ids','imported','free_ids'}
    body = source.read_text(encoding='utf-8')
    if source.name.startswith('batch_2_'):
        assert body.startswith('begin;') and body.rstrip().endswith('rollback;')
        body = body[len('begin;'):body.rfind('rollback;')]
        assert body.count('\\ir batch_2_fixture.sql') == 1
        body = body.replace('\\ir batch_2_fixture.sql','')
        body = body.replace("insert into public.products(business_id,name,selling_price,quantity) values((select id from batch2_ids where key='business'),'Synthetic free',0,5);",
          "select public.import_trexven_catalog((select id from batch2_ids where key='business'),gen_random_uuid(),'[{\"name\":\"Synthetic free\",\"selling_price\":0,\"initial_quantity\":5}]');")
    for line in body.splitlines():
        def value(match):
            key = match.group(1)
            kind = 'jsonb' if key in json_variables else 'timestamptz' if key == 'occurred' else 'uuid'
            return f"pg_temp.test_value('{key}')::{kind}"
        line = re.sub(r":'([A-Za-z0-9_]+)'", value, line)
        line = re.sub(r"(set_config\('request.jwt.claim.sub',pg_temp.test_value\('[^']+'\)::uuid)(,true)",
                      r'\1::text\2', line)
        line = re.sub(r"(metadata->>'[A-Za-z_]+')\s*=\s*(pg_temp.test_value\('[^']+'\))::uuid",
                      r'\1=\2::text',line)
        if '\\gset' in line:
            query = line.split('\\gset')[0].strip().rstrip(';')
            while not query.lower().startswith('select '):
                assert lines, 'Incomplete multiline gset query'
                query = lines.pop().strip() + ' ' + query
            assert query.lower().startswith('select '), line
            line = ("insert into pg_temp.test_variables select key,value "
                    "from jsonb_each_text(to_jsonb(q)) from_placeholder "
                    "on conflict(name) do update set value=excluded.value;")
            line = line.replace('from jsonb_each_text(to_jsonb(q)) from_placeholder',
                                f'from ({query}) q cross join lateral jsonb_each_text(to_jsonb(q))')
        assert '\\' not in line, f'Unsupported psql construct: {line}'
        lines.append(line)
    target = OUT / source.name
    reject = "create function pg_temp.reject(statement text,expected text,label text) returns void language plpgsql as $$begin begin execute statement;exception when others then if sqlstate=expected then return; end if;raise;end;raise exception 'Expected denial missing: %',label;end $$;\n"
    target.write_text(head + seed + fixture + reject + '\n' + '\n'.join(lines) +
                      "\nreset role; select '" + source.stem + "' as suite, 'passed' as result; rollback;\n",
                      encoding='utf-8')
    print(target.name)

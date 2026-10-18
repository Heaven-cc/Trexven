"""Render existing rollback-only psql suites for explicitly targeted MCP staging.

No network, credentials, project link or database writes. SQL execution is separate.
The original loopback runner is unchanged. A transport-only temporary marker and
typed temporary variables replace psql includes/gset/binds; assertions are retained.
"""
from pathlib import Path
import json
import re
import hashlib

BASE = Path(__file__).parent
fixture = (BASE / 'batch_2_fixture.sql').read_text().replace(
    'private.batch_2_test_environment', 'pg_temp.batch_2_test_environment')
marker = """create temporary table batch_2_test_environment(marker text primary key);
insert into batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY');
"""
result = []
for path in sorted(BASE.glob('batch_2_*tests.sql')):
    original = path.read_text()
    sql = original.replace('\\ir batch_2_fixture.sql', marker + fixture)
    def variable(match):
        expr, name = match.groups()
        return (f'create temporary table batch2_var_{name} as select {expr} as value;\n'
                f'grant select on batch2_var_{name} to authenticated,anon;')
    sql = re.sub(r'select\s+([^;]*?)\s+as\s+(\w+)\s*\\gset', variable, sql, flags=re.I)
    def bind(match):
        name = match.group(1)
        cast = '::jsonb' if name in ('items', 'receipt') else ''
        return f'(select value{cast} from batch2_var_{name})'
    sql = re.sub(r":'(\w+)'", bind, sql)
    if '\\gset' in sql or '\\ir' in sql:
        raise ValueError('Untranslated psql command')
    counts = {n: len(re.findall(r'pg_temp\.' + n + r'\(', original))
              for n in ('assert_true','denied','fails')}
    summary = json.dumps({'suite': path.name, 'assertions': counts, 'rolled_back': True})
    sql += "\nselect '" + summary + "'::jsonb as suite_result;\n"
    result.append({'file': path.name, 'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                   'assertions': counts, 'sql': sql})
print(json.dumps(result))

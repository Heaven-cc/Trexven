"""SQL syntax validation only. Does not execute or verify database behavior."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.batch2-tools'))
from pglast import parse_sql, parse_plpgsql

paths = sorted((ROOT / 'supabase/migrations').glob('*batch_2*.sql'))
paths += sorted((ROOT / 'supabase/tests').glob('batch_2_*tests.sql'))
paths += [ROOT / 'supabase/tests/batch_2_fixture.sql']
functions = 0
sql_functions = 0
blocks = 0
for path in paths:
    source = path.read_text(encoding='utf-8')
    # psql include/bind commands are not SQL. Validate their SQL portions,
    # substituting synthetic literals; this is not execution/type checking.
    source = re.sub(r'^\\ir.*$', '', source, flags=re.M)
    source = source.replace('\\gset', ';')
    source = re.sub(r":'\w+'", "'00000000-0000-0000-0000-000000000001'", source)
    parse_sql(source)
    for match in re.finditer(r'create (?:or replace )?function\b.*?\$\$;', source, re.I | re.S):
        if re.search(r'language\s+plpgsql', match.group(), re.I):
            parse_plpgsql(match.group())
            functions += 1
        elif re.search(r'language\s+sql\b', match.group(), re.I):
            parse_sql(re.search(r'\$\$(.*?)\$\$', match.group(), re.S).group(1))
            sql_functions += 1
    for match in re.finditer(r'\bdo\s+\$\$(.*?)\$\$;', source, re.I | re.S):
        parse_plpgsql('create function batch2_static_block() returns void language plpgsql as $$' + match.group(1) + '$$;')
        blocks += 1
    print(f'SYNTAX ONLY: {path.name}')
print(f'Parsed {len(paths)} SQL files, {functions} PL/pgSQL functions, {sql_functions} SQL function bodies and {blocks} DO blocks; no database tests executed.')

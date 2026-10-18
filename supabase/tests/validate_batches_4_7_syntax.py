"""Offline syntax checks only. Does not connect to PostgreSQL or execute SQL."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.batch2-tools'))
from pglast import parse_sql, parse_plpgsql
from pglast.stream import RawStream

results = []
failed = False
for path in sorted((ROOT / 'supabase/migrations').glob('*_batch_[4567]_*.sql')):
    entry = {'file': path.name, 'sql_syntax': 'passed', 'plpgsql_bodies': 0, 'sql_function_bodies':0, 'errors': []}
    try:
        statements = parse_sql(path.read_text(encoding='utf-8'))
        for statement in statements:
            node = statement.stmt
            if type(node).__name__ == 'CreateFunctionStmt' and any(
                option.defname == 'language' and option.arg.sval == 'plpgsql'
                for option in node.options
            ):
                try:
                    parse_plpgsql(RawStream()(node) + ';')
                    entry['plpgsql_bodies'] += 1
                except Exception as error:
                    entry['errors'].append(str(error))
            elif type(node).__name__ == 'DoStmt':
                try:
                    parse_plpgsql(RawStream()(node) + ';')
                    entry['plpgsql_bodies'] += 1
                except Exception as error:
                    entry['errors'].append(str(error))
            elif type(node).__name__ == 'CreateFunctionStmt' and any(
                option.defname == 'language' and option.arg.sval == 'sql' for option in node.options
            ):
                try:
                    body=next(option.arg[0].sval for option in node.options if option.defname=='as')
                    parse_sql(body)
                    entry['sql_function_bodies']+=1
                except Exception as error:
                    entry['errors'].append(str(error))
    except Exception as error:
        entry['sql_syntax'] = 'failed'
        entry['errors'].append(str(error))
    failed |= bool(entry['errors'])
    results.append(entry)
report={'database_executed':False,'files':results}
(ROOT/'docs/implementation/evidence/batches_4_7_syntax_results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(1 if failed else 0)

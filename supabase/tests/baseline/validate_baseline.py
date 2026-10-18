"""Local-only validation and migration comparison; never connects to a database."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
sys.path.insert(0, str(ROOT / '.batch2-tools'))
from pglast import parse_sql, parse_plpgsql, scan

def clean(node):
    if isinstance(node, (tuple, list)):
        return [clean(x) for x in node]
    if isinstance(node, dict):
        return {k: clean(v) for k, v in node.items()
                if k not in ('location', 'stmt_location', 'stmt_len', 'arg_location',
                             'rexpr_list_start', 'rexpr_list_end')}
    return node

def body_tokens(body):
    result = []
    body = body.replace('\r\n', '\n').replace('\r', '\n')
    for t in scan(body):
        if 'COMMENT' in t.name:
            continue
        value = body[t.start:t.end + 1]
        if t.name == 'IDENT' and not value.startswith('"'):
            value = value.lower()
        elif t.kind != 'NO_KEYWORD':
            value = t.name
        result.append(value)
    if result and result[-1] == ';':
        result.pop()
    return result

def normalized(node):
    n = clean(node())
    if n.get('@') == 'CreateFunctionStmt':
        for opt in n['options']:
            if opt['defname'] == 'as':
                opt['arg'] = [body_tokens(v['sval']) for v in opt['arg']]
        n['options'] = sorted(n['options'], key=lambda o: o['defname'])
    elif n.get('@') == 'DoStmt':
        for opt in n['args']:
            if opt['defname'] == 'as':
                opt['arg'] = body_tokens(opt['arg']['sval'])
    return n

def function_parts(stmt):
    n = clean(stmt())
    name = '.'.join(x['sval'] for x in n['funcname'])
    opts = {x['defname']: x for x in n['options']}
    for p in n['parameters'] or []:
        names = p['argType']['names']
        if len(names) == 2 and names[0]['sval'] == 'pg_catalog':
            p['argType']['names'] = names[1:]
        default = p['defexpr']
        if default and default.get('@') == 'TypeCast' and default['arg'].get('@') == 'A_Const' and default['arg']['isnull']:
            p['defexpr'] = default['arg']
    return name, {'parameters': n['parameters'], 'returns': n['returnType'],
                  'body': body_tokens(opts['as']['arg'][0]['sval']),
                  'language': opts['language']['arg']}

def main():
    metadata = json.loads((BASE / 'recovered_catalog.json').read_text())
    history = json.loads((BASE / 'migration_history_metadata.json').read_text())
    sql = (BASE / 'TREXVEN_PRE_BATCH_2_BASELINE.sql').read_text()
    parsed = parse_sql(sql)
    counts = Counter(type(s.stmt).__name__ for s in parsed)
    expected = metadata['structure']
    assert counts['CreateStmt'] == len(expected['tables']) == 32
    assert counts['CreateFunctionStmt'] == len(metadata['functions']) == 22
    assert counts['CreatePolicyStmt'] == len(metadata['security']['policies']) == 108
    assert counts['CreateTrigStmt'] == len(metadata['security']['triggers']) == 8
    assert counts['AlterPublicationStmt'] == len(metadata['security']['publications']) == 7
    assert counts['IndexStmt'] == len([i for i in expected['indexes'] if not i['constraint']]) == 61
    constraint_nodes = [c for s in parsed if type(s.stmt).__name__ == 'AlterTableStmt'
                        for c in s.stmt.cmds if c.def_ and type(c.def_).__name__ == 'Constraint']
    assert len(constraint_nodes) == len(expected['constraints']) == 115
    for s in parsed:
        assert type(s.stmt).__name__ not in ('InsertStmt', 'UpdateStmt', 'DeleteStmt', 'CopyStmt',
                                           'TruncateStmt', 'CreateRoleStmt', 'DropStmt')
    plpgsql = sql_bodies = blocks = 0
    emitted_functions = {}
    for raw in parsed:
        stmt = raw.stmt
        if type(stmt).__name__ == 'CreateFunctionStmt':
            name, parts = function_parts(stmt)
            emitted_functions[name] = parts
            body = next(o.arg[0].sval for o in stmt.options if o.defname == 'as')
            language = next(o.arg.sval for o in stmt.options if o.defname == 'language')
            if language == 'plpgsql':
                from pglast.stream import RawStream
                parse_plpgsql(RawStream()(stmt))
                plpgsql += 1
            else:
                parse_sql(body)
                sql_bodies += 1
        elif type(stmt).__name__ == 'DoStmt':
            body = next(o.arg.sval for o in stmt.args if o.defname == 'as')
            parse_plpgsql('create function baseline_static_guard() returns void language plpgsql as $$' + body + '$$;')
            blocks += 1
    for f in metadata['functions']:
        name, parts = function_parts(parse_sql(f['definition'])[0].stmt)
        assert parts == emitted_functions[name]
    # Screen all recovered metadata including descriptions, ACLs and historical SQL.
    raw_text = '\n'.join(p.read_text() for p in (BASE / 'recovered_catalog.json',
                         BASE / 'migration_history_metadata.json', BASE / 'TREXVEN_PRE_BATCH_2_BASELINE.sql'))
    prohibited_patterns = {
        'production ref': r'ufehcfrlygqvminfjumf',
        'URLs / credential DSNs': r'https?://|postgres(?:ql)?://',
        'email literals': r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
        'JWT': r'eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
        'known API key prefixes': r'\b(?:sb_secret_|sb_publishable_|gsk_|sk_live_|sk_test_)[A-Za-z0-9_-]+',
        'hardcoded UUID literal': r"'[0-9a-f]{8}-[0-9a-f-]{27,}'",
        'password assignment': r"(?:password|api_key|secret|token)\s*(?:=|:=)\s*'[^']+'"
    }
    for label, pattern in prohibited_patterns.items():
        assert not re.search(pattern, raw_text, re.I), 'Security screening requires review: ' + label
    last_functions = {}
    created_tables = set()
    comparisons = []
    for entry in history:
        path = next((ROOT / 'supabase/migrations').glob(entry['version'] + '_*.sql'))
        local = parse_sql(path.read_text())
        remote = parse_sql('\n'.join(s.rstrip().rstrip(';') + ';' for s in (entry['statements'] or [])))
        same = [normalized(x.stmt) for x in local] == [normalized(x.stmt) for x in remote]
        comparisons.append({'version': entry['version'], 'name': entry['name'],
                            'local_statements': len(local), 'remote_statements': len(remote),
                            'normalized_ast_equal': same,
                            'local_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                            'recorded_sql_sha256': hashlib.sha256('\n'.join(entry['statements'] or []).encode()).hexdigest()})
        for raw in local:
            stmt = raw.stmt
            if type(stmt).__name__ == 'CreateFunctionStmt':
                name, parts = function_parts(stmt)
                last_functions[name] = (entry['version'], parts)
            elif type(stmt).__name__ == 'CreateStmt':
                created_tables.add((stmt.relation.schemaname or 'public') + '.' + stmt.relation.relname)
    matches = []
    absent = []
    differing = []
    for f in metadata['functions']:
        name, parts = function_parts(parse_sql(f['definition'])[0].stmt)
        if name not in last_functions:
            absent.append(name)
        else:
            version, repository = last_functions[name]
            if parts == repository:
                matches.append(name)
            else:
                differing.append({'name': name, 'last_definition_migration': version,
                                  'changed_parts': [k for k in parts if parts[k] != repository[k]]})
    missing_tables = sorted(t['schema'] + '.' + t['name'] for t in expected['tables']
                            if t['schema'] + '.' + t['name'] not in created_tables)
    findings = {'migration_comparisons': comparisons, 'table_create_definitions_in_history': sorted(created_tables),
                'tables_without_create_definition': missing_tables,
                'live_functions_matching_latest_repository_body_contract': sorted(matches),
                'live_functions_without_repository_create_definition': sorted(absent),
                'live_functions_differing_from_latest_repository_body_contract': differing,
                'baseline_statement_counts': dict(counts), 'plpgsql_functions_parsed': plpgsql,
                'sql_function_bodies_parsed': sql_bodies, 'do_blocks_parsed': blocks,
                'baseline_sha256': hashlib.sha256(sql.encode()).hexdigest(),
                'catalog_sha256': hashlib.sha256((BASE / 'recovered_catalog.json').read_bytes()).hexdigest(),
                'database_tests_executed': False}
    (BASE / 'validation_and_drift.json').write_text(json.dumps(findings, indent=2) + '\n', encoding='utf-8')
    print('PASS: syntax, body/contract preservation, object coverage, deterministic input/security screening.')
    print('Parsed', len(parsed), 'statements;', plpgsql, 'PL/pgSQL,', sql_bodies, 'SQL bodies,', blocks, 'DO blocks.')
    print('Migration AST equality:', sum(x['normalized_ast_equal'] for x in comparisons), '/', len(comparisons))
    print('Original table definitions missing from migration history:', len(missing_tables))
    print('Live function body/contract matches:', len(matches), '; definitions absent:', len(absent), '; differences:', len(differing))
    print('Database execution: NONE.')

if __name__ == '__main__':
    main()


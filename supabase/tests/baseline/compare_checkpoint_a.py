"""Read-only artifact comparison after a staging restore. No DB calls."""
from pathlib import Path
import hashlib
import json
import sys

BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE))
from validate_baseline import normalized
from pglast import parse_sql

def canon(value):
    if isinstance(value, list):
        return sorted((canon(x) for x in value), key=lambda x: json.dumps(x, sort_keys=True))
    if isinstance(value, dict):
        return {k: canon(v) for k, v in value.items()}
    if isinstance(value, str):
        return value.replace('\r\n', '\n').replace('\r', '\n')
    return value

def structure(meta):
    src = meta['structure']
    tables = {str(t['oid']): t['schema'] + '.' + t['name'] for t in src['tables']}
    indexes = {str(i['oid']): i['name'] for i in src['indexes']}
    result = {}
    result['tables'] = [{k: v for k, v in t.items() if k != 'oid'} for t in src['tables']]
    result['columns'] = [{**c, 'table': tables[str(c['table'])]} for c in src['columns']]
    result['constraints'] = [{**c, 'table': tables[str(c['table'])],
                             'index': indexes.get(str(c['index']), str(c['index']))}
                            for c in src['constraints']]
    result['indexes'] = [{**{k: v for k, v in i.items() if k != 'oid'},
                         'table': tables[str(i['table'])]} for i in src['indexes']]
    result['types'] = src['types']
    result['inheritance'] = src['inheritance']
    return result

def functions(meta):
    return [{**{k: v for k, v in f.items() if k not in ('oid', 'definition')},
             'definition': normalized(parse_sql(f['definition'])[0].stmt)}
            for f in meta['functions']]

def security(meta):
    result = dict(meta['security'])
    ids = {str(f['oid']): f['schema'] + '.' + f['name'] + '(' + f['args'] + ')'
           for f in meta['functions']}
    result['triggers'] = [{**t, 'function': ids[str(t['function'])],
                           'definition': normalized(parse_sql(t['definition'])[0].stmt)}
                          for t in result['triggers']]
    return result

def compare_group(name, source, stage):
    equal = canon(source) == canon(stage)
    result = {'group': name, 'match': equal}
    if isinstance(source, list):
        result.update(source_count=len(source), staging_count=len(stage))
    if not equal:
        if isinstance(source, list):
            a = {json.dumps(canon(x), sort_keys=True) for x in source}
            b = {json.dumps(canon(x), sort_keys=True) for x in stage}
            result['source_only'] = [json.loads(x) for x in sorted(a - b)]
            result['staging_only'] = [json.loads(x) for x in sorted(b - a)]
        else:
            result['source'] = source
            result['staging'] = stage
    return result

def main():
    source_path = BASE / 'recovered_catalog.json'
    stage_path = BASE / 'checkpoint_a_staging_catalog.json'
    source = json.loads(source_path.read_text())
    stage = json.loads(stage_path.read_text())
    results = []
    a, b = structure(source), structure(stage)
    for key in a:
        results.append(compare_group('structure.' + key, a[key], b[key]))
    results.append(compare_group('functions.body_contract_owner_settings', functions(source), functions(stage)))
    a, b = security(source), security(stage)
    for key in a:
        results.append(compare_group('security.' + key, a[key], b[key]))
    for key in source['acl']:
        results.append(compare_group('acl.' + key, source['acl'][key], stage['acl'][key]))
    for key in source['dependencies']:
        results.append(compare_group('dependencies.' + key, source['dependencies'][key], stage['dependencies'][key]))
    for key in source['extras']:
        results.append(compare_group('extras.' + key, source['extras'][key], stage['extras'][key]))
    report = {
        'target_project_ref': 'qysspzlfiysekvxnlzsh',
        'source_catalog_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
        'staging_catalog_sha256': hashlib.sha256(stage_path.read_bytes()).hexdigest(),
        'groups': results, 'semantic_match': all(r['match'] for r in results),
        'normalization': ['Catalog OIDs replaced by qualified object names.',
                          'ACL/dependency row order ignored, grantor/options retained.',
                          'Function/trigger AST compared after body whitespace/comment normalization.',
                          'CR/LF normalized; column ordinals retained.'],
        'security_integration_tests_executed': False
    }
    (BASE / 'checkpoint_a_catalog_comparison.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    for r in results:
        print(('MATCH ' if r['match'] else 'MISMATCH ') + r['group'])
    print('Semantic catalog match:', report['semantic_match'])
    raise SystemExit(0 if report['semantic_match'] else 1)

if __name__ == '__main__':
    main()


"""Rebuild a REVIEW-ONLY schema baseline from catalog metadata. No database calls."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parent
CATALOG = ROOT / 'recovered_catalog.json'
OUTPUT = ROOT / 'TREXVEN_PRE_BATCH_2_BASELINE.sql'
DATA = json.loads(CATALOG.read_text(encoding='utf-8'))
STRUCTURE = DATA['structure']
ACL = DATA['acl']

def ident(value):
    return '"' + value.replace('"', '""') + '"'

def qualified(schema, name):
    return ident(schema) + '.' + ident(name)

def role(value):
    return 'PUBLIC' if value == 'PUBLIC' else ident(value)

def literal(value):
    return "'" + value.replace("'", "''") + "'"

def emit_acl(statements, scope, privileges, extra_roles=()):
    recipients = sorted(set(['PUBLIC', 'anon', 'authenticated', 'service_role', 'postgres', *extra_roles]
                            + [p['role'] for p in (privileges or [])]))
    statements.append('REVOKE ALL PRIVILEGES ON ' + scope + ' FROM ' + ', '.join(role(r) for r in recipients) + ';')
    for p in sorted(privileges or [], key=lambda p: (p['role'], p['privilege'], p['grantable'])):
        statements.append('GRANT ' + p['privilege'] + ' ON ' + scope + ' TO ' + role(p['role']) +
                          (' WITH GRANT OPTION' if p['grantable'] else '') + ';')

def render(allow_unvalidated=False):
    assert not STRUCTURE['types'] and not STRUCTURE['inheritance']
    assert all(t['kind'] == 'r' and t['persistence'] == 'p' and not t['options'] for t in STRUCTURE['tables'])
    assert all(not c['identity'] and not c['generated'] and not c['collation'] for c in STRUCTURE['columns'])
    assert not DATA['security']['rules'] and not DATA['security']['event_triggers']
    assert not DATA['extras']['statistics_objects'] and not DATA['extras']['unusual_column_metadata']
    assert not DATA['extras']['object_descriptions']
    assert not DATA['dependencies']['custom_casts'] and not DATA['dependencies']['custom_operators']
    assert not DATA['dependencies']['custom_aggregates'] and not DATA['dependencies']['custom_collations']
    assert all(i['valid'] and i['ready'] and not i['clustered'] and not i['replica_identity'] for i in STRUCTURE['indexes'])
    assert all(t['owner'] == 'postgres' for t in STRUCTURE['tables'])
    assert all(f['owner'] == 'postgres' and not f['sql_body'] for f in DATA['functions'])
    tables = {str(t['oid']): t for t in STRUCTURE['tables']}
    lines = [
        '-- REVIEW ONLY. Recovered current pre-Batch-2 application schema, 8 October 2026.',
        '-- No production data, Auth identities, credentials, buckets or runtime configuration.',
        '-- NOT the lost historical initial schema. Do not replay its nine incorporated deltas.',
        '-- Requires verified Supabase staging qysspzlfiysekvxnlzsh and a reviewed executor.',
        '-- No file in this directory has been applied to any database.',
        'BEGIN;', "SET LOCAL search_path = '';", 'SET LOCAL check_function_bodies = false;',
        # Explicit target passed only by an independently verified staging executor.
        "DO $baseline_guard$ BEGIN",
        " IF current_setting('trexven.staging_project_ref', true) IS DISTINCT FROM 'qysspzlfiysekvxnlzsh' THEN",
        "   RAISE EXCEPTION 'Verified staging executor setting required';",
        " END IF;",
        " IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace",
        "            WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p','v','m','S','f'))",
        " OR EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace",
        "            WHERE n.nspname IN ('public','private')) THEN",
        "   RAISE EXCEPTION 'Empty application schema required; never overwrite a populated database';",
        " END IF;",
        " IF pg_catalog.to_regclass('auth.users') IS NULL OR pg_catalog.to_regclass('storage.objects') IS NULL THEN",
        "   RAISE EXCEPTION 'Managed Supabase Auth/Storage prerequisites missing';",
        " END IF;",
        " IF EXISTS (SELECT 1 FROM auth.users) THEN RAISE EXCEPTION 'Empty staging Auth required'; END IF;",
        "END $baseline_guard$;",
        '-- Supabase owns Auth/Storage/Vault schemas. Preserve its managed definitions.',
        '-- Extensions are prerequisites already verified in staging; do not copy Vault values.',
        "DO $extension_guard$ BEGIN",
        " IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='plpgsql' AND extversion='1.0')",
        " OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='pgcrypto' AND extversion='1.3')",
        " OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='uuid-ossp' AND extversion='1.1')",
        " OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='pg_stat_statements' AND extversion='1.11')",
        " OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname='supabase_vault' AND extversion='0.3.1') THEN",
        "   RAISE EXCEPTION 'Reviewed Supabase extension prerequisites missing or different';",
        " END IF;",
        "END $extension_guard$;",
        'CREATE SCHEMA "private" AUTHORIZATION "postgres";',
        '-- public is the pre-existing platform schema, owned by pg_database_owner.',
        '-- Tables first; defaults/constraints are deferred until functions and all tables exist.'
    ]
    platform_defaults = {o['kind']: {p['role'] + ':' + p['privilege']: p['grantable']
                                    for p in o['privileges']}
                         for o in ACL['defaults'] if o['owner'] == 'supabase_admin'}
    lines.append("DO $platform_defaults$ DECLARE actual jsonb; BEGIN\n"
                 " SELECT jsonb_object_agg(d.defaclobjtype::text, (SELECT jsonb_object_agg(\n"
                 "  (CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_catalog.pg_get_userbyid(a.grantee) END)\n"
                 "  || ':' || a.privilege_type, a.is_grantable) FROM pg_catalog.aclexplode(d.defaclacl) a))\n"
                 " INTO actual FROM pg_catalog.pg_default_acl d JOIN pg_catalog.pg_namespace n ON n.oid=d.defaclnamespace\n"
                 " WHERE pg_catalog.pg_get_userbyid(d.defaclrole)='supabase_admin' AND n.nspname='public';\n"
                 " IF actual IS DISTINCT FROM " + literal(json.dumps(platform_defaults)) + "::jsonb THEN\n"
                 "   RAISE EXCEPTION 'Platform-owned default privileges differ from reviewed baseline';\n"
                 " END IF;\nEND $platform_defaults$;")
    for t in STRUCTURE['tables']:
        cols = [c for c in STRUCTURE['columns'] if str(c['table']) == str(t['oid'])]
        lines.append('CREATE TABLE ' + qualified(t['schema'], t['name']) + ' (\n' +
                     ',\n'.join('  ' + ident(c['name']) + ' ' + c['type'] + (' NOT NULL' if c['not_null'] else '') for c in cols) +
                     '\n) USING heap;')
        lines.append('ALTER TABLE ' + qualified(t['schema'], t['name']) + ' OWNER TO "postgres";')
    lines.append('-- Preserve exact catalog function bodies/signatures; validation occurs during staging rehearsal.')
    for f in DATA['functions']:
        lines.append(f['definition'].replace('\r\n', '\n').replace('\r', '\n').rstrip().rstrip(';') + ';')
        lines.append('ALTER FUNCTION ' + qualified(f['schema'], f['name']) + '(' + f['args'] + ') OWNER TO "postgres";')
    for c in STRUCTURE['columns']:
        if c['default'] is not None:
            t = tables[str(c['table'])]
            lines.append('ALTER TABLE ' + qualified(t['schema'], t['name']) + ' ALTER COLUMN ' +
                         ident(c['name']) + ' SET DEFAULT ' + c['default'] + ';')
    lines.append('-- Non-FK constraints before foreign keys (including managed auth.users references).')
    for c in sorted(STRUCTURE['constraints'], key=lambda c: (c['type'] == 'f', str(c['table']), c['name'])):
        assert str(c['parent']) == '0' and (c['validated'] or allow_unvalidated)
        t = tables[str(c['table'])]
        lines.append('ALTER TABLE ' + qualified(t['schema'], t['name']) + ' ADD CONSTRAINT ' +
                     ident(c['name']) + ' ' + c['def'] + ';')
    for i in STRUCTURE['indexes']:
        if not i['constraint']:
            lines.append(i['def'].rstrip(';') + ';')
    for t in STRUCTURE['tables']:
        if t['rls']:
            lines.append('ALTER TABLE ' + qualified(t['schema'], t['name']) + ' ENABLE ROW LEVEL SECURITY;')
        if t['force_rls']:
            lines.append('ALTER TABLE ' + qualified(t['schema'], t['name']) + ' FORCE ROW LEVEL SECURITY;')
        if t['replica_identity'] != 'd':
            assert t['replica_identity'] == 'f'
            lines.append('ALTER TABLE ' + qualified(t['schema'], t['name']) + ' REPLICA IDENTITY FULL;')
    commands = {'r':'SELECT', 'a':'INSERT', 'w':'UPDATE', 'd':'DELETE', '*':'ALL'}
    for p in DATA['security']['policies']:
        lines.append('CREATE POLICY ' + ident(p['name']) + ' ON ' + qualified(p['schema'], p['table']) +
                     (' AS PERMISSIVE' if p['permissive'] else ' AS RESTRICTIVE') +
                     ' FOR ' + commands[p['command']] + ' TO ' + ', '.join(role(r) for r in p['roles']) +
                     (' USING (' + p['using'] + ')' if p['using'] else '') +
                     (' WITH CHECK (' + p['check'] + ')' if p['check'] else '') + ';')
    for t in DATA['security']['triggers']:
        assert t['enabled'] == 'O'
        lines.append(t['definition'].rstrip(';') + ';')
    lines.append('-- Reset only application object ACLs, then reproduce effective privileges.')
    for o in ACL['schemas']:
        emit_acl(lines, 'SCHEMA ' + ident(o['name']), o['privileges'], ['pg_database_owner'])
    for o in ACL['tables']:
        emit_acl(lines, 'TABLE ' + qualified(o['schema'], o['name']), o['privileges'])
    # Older captured baselines have no column grants; their output is unchanged.
    # Column restrictions are essential to the deferred purchase-cost contract.
    for o in ACL['columns'] or []:
        for p in sorted(o['privileges'] or [], key=lambda p: (p['role'], p['privilege'], p['grantable'])):
            assert p['grantor'] == 'postgres', 'Unreviewed column grantor'
            assert p['privilege'] in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
            lines.append('GRANT ' + p['privilege'] + ' (' + ident(o['column']) + ') ON TABLE ' +
                         qualified(o['schema'], o['table']) + ' TO ' + role(p['role']) +
                         (' WITH GRANT OPTION' if p['grantable'] else '') + ';')
    for o in ACL['functions']:
        emit_acl(lines, 'FUNCTION ' + qualified(o['schema'], o['name']) + '(' + o['args'] + ')', o['privileges'])
    lines.append('-- postgres-scoped defaults restored; platform supabase_admin defaults are verified, not mutated.')
    for o in ACL['defaults']:
        if o['owner'] != 'postgres':
            continue
        category = {'S':'SEQUENCES', 'f':'FUNCTIONS', 'r':'TABLES'}[o['kind']]
        prefix = 'ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA ' + ident(o['schema']) + ' '
        recipients = sorted(set(['PUBLIC', 'anon', 'authenticated', 'service_role', 'postgres']
                                + [p['role'] for p in o['privileges']]))
        lines.append(prefix + 'REVOKE ALL PRIVILEGES ON ' + category + ' FROM ' + ', '.join(role(r) for r in recipients) + ';')
        for p in o['privileges']:
            lines.append(prefix + 'GRANT ' + p['privilege'] + ' ON ' + category + ' TO ' + role(p['role']) +
                         (' WITH GRANT OPTION' if p['grantable'] else '') + ';')
    lines += [
        '-- supabase_admin public defaults are platform-owned and already match staging.',
        '-- Original grantor identities are retained in recovered_catalog.json.',
        '-- Realtime uses the pre-existing managed publication; no subscriptions/endpoints copied.'
    ]
    for p in DATA['security']['publications']:
        assert p['name'] == 'supabase_realtime' and p['columns'] is None and p['filter'] is None
        lines.append('ALTER PUBLICATION "supabase_realtime" ADD TABLE ' + qualified(p['schema'], p['table']) + ';')
    lines.append('COMMIT;')
    return '\n\n'.join(lines) + '\n'

def main():
    output = render()
    digest = hashlib.sha256(output.encode('utf-8')).hexdigest()
    if '--check' in sys.argv:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding='utf-8') != output:
            raise SystemExit('FAIL: generated baseline differs from reviewed output')
        print('PASS: deterministic baseline regeneration; SHA256 ' + digest)
    else:
        OUTPUT.write_text(output, encoding='utf-8', newline='\n')
        print('Generated REVIEW-ONLY baseline; SHA256 ' + digest)

if __name__ == '__main__':
    main()


"""Run adversarial SQL only against a manually provisioned loopback test DB.

Requires BATCH_2_ISOLATED_DSN, psql and private.batch_2_test_environment with
marker='TREXVEN_SYNTHETIC_ONLY'. Never reads project .env or Supabase links.
This runner does not apply migrations, initialize a database or copy data.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlparse

dsn = os.environ.get('BATCH_2_ISOLATED_DSN', '')
parsed = urlparse(dsn)
if parsed.scheme not in ('postgres', 'postgresql') or parsed.hostname not in ('127.0.0.1', 'localhost', '::1'):
    sys.exit('BLOCKED: supply a dedicated loopback PostgreSQL test DSN; remote targets are rejected.')
if 'ufehcfrlygqvminfjumf' in dsn or parsed.query:
    sys.exit('BLOCKED: production identifiers and DSN query overrides are prohibited.')
psql = shutil.which('psql')
if not psql:
    sys.exit('BLOCKED: psql is unavailable.')
# Keep credentials out of process arguments/output and never print the DSN.
env = dict(os.environ, PGHOST=parsed.hostname, PGPORT=str(parsed.port or 5432),
           PGUSER=parsed.username or '', PGPASSWORD=parsed.password or '',
           PGDATABASE=parsed.path.removeprefix('/'))
check = subprocess.run([psql, '-X', '-At', '-v', 'ON_ERROR_STOP=1', '-c',
    "select marker from private.batch_2_test_environment"], env=env, capture_output=True, text=True)
if check.returncode or check.stdout.strip() != 'TREXVEN_SYNTHETIC_ONLY':
    sys.exit('BLOCKED: synthetic-only environment marker missing or invalid.')
for path in sorted(Path(__file__).parent.glob('batch_2_*tests.sql')):
    result = subprocess.run([psql, '-X', '-v', 'ON_ERROR_STOP=1', '-f', str(path)], env=env)
    if result.returncode:
        sys.exit(result.returncode)

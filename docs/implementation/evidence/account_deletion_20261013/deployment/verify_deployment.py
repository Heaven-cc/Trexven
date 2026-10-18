"""Read-only live rejection checks and source comparison. Never deletes accounts."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

destination = Path(__file__).resolve().parent
root = Path(__file__).resolve().parents[5]
main = (root / 'lib/main.dart').read_text(encoding='utf-8')
key = re.search(r"'SUPABASE_PUBLISHABLE_KEY',\s*defaultValue: '([^']+)'", main).group(1)
base = 'https://ufehcfrlygqvminfjumf.supabase.co'
checks = []
for name, path, method, body, expected in [
    ('delete_requires_auth', '/functions/v1/delete-account', 'POST', b'{}', 401),
    ('recovery_rejects_missing_credential', '/functions/v1/account-deletion-recovery', 'POST', b'{}', 400),
    ('recovery_cors', '/functions/v1/account-deletion-recovery', 'OPTIONS', None, 200),
    ('anonymous_api_hook_admission', '/rest/v1/rpc/trexven_account_access_allowed', 'POST', b'{}', 200),
]:
    request = Request(base + path, data=body, method=method,
                      headers={'apikey': key, 'Content-Type': 'application/json'})
    try:
        response = urlopen(request, timeout=25)
    except HTTPError as error:
        response = error
    with response:
        status = response.code
        text = response.read().decode('utf-8')
        checks.append({'check': name, 'status': status, 'expected': expected,
                       'passed': status == expected, 'response': text,
                       'cache_control': response.headers.get('Cache-Control')})

manifest = json.loads((destination.parent / 'source_manifest.json').read_text(encoding='utf-8'))
frontend = {path: hashlib.sha256((root/path).read_bytes()).hexdigest() == expected
            for path, expected in manifest['after_sha256'].items() if path.startswith('lib/')}
result = {'project_id': 'ufehcfrlygqvminfjumf', 'live_checks': checks,
          'account_deletion_invoked': False, 'local_tests_run': False,
          'frontend_unchanged_since_implementation_snapshot': frontend}
(destination / 'live_checks.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
diff = subprocess.run(['git', 'diff', '--name-status', '--', 'lib'], cwd=root,
                      capture_output=True, text=True, encoding='utf-8', check=True)
(destination / 'frontend_git_diff_existing.txt').write_text(diff.stdout, encoding='utf-8')
print(json.dumps(result, indent=2))

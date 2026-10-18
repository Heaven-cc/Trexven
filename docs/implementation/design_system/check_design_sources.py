"""Read-only design architecture and preserved source audit. Run from Owner root."""
from pathlib import Path
import re, json, zipfile, hashlib
from scan_ui import close, args

BASE = Path(__file__).resolve().parent
OWNER = BASE.parents[2]
ROOTS = {'owner': OWNER / 'lib', 'pos': OWNER.parent / 'trexvenpos/lib',
         'operations': OWNER / 'packages/trexven_operations/lib'}

def normalized(s):
    compact = re.sub(r'\s+', '', re.sub(r'\bconst\s+', '', s))
    return re.sub(r',(?=[)\]}])', '', compact)

def backend_calls(s):
    result = []
    pattern = r'\b(?:_db|db|_client|client|_supabase|supabase|Supabase\.instance\.client)\.(\w+)\('
    for m in re.finditer(pattern, s):
        if m[1] in {'of', 'read', 'watch'}: continue
        result.append(normalized(s[m.start():close(s, m.end()-1)+1]))
    for m in re.finditer(r'\.(?:rpc|from|signInWithPassword|signUp|resetPasswordForEmail|updateUser|signOut)\(', s):
        result.append(normalized(s[m.start():close(s, m.end()-1)+1]))
    return sorted(result)

report = {'obsolete_references': [], 'raw_controls': [], 'unlabelled_fields': [],
          'authorized_ui_call_additions': [],
          'backend_call_differences': [], 'preserved_nonpresentation_files': 0,
          'source_changes': {}, 'deleted_source_files': []}
for project, root in ROOTS.items():
    for p in root.rglob('*.dart'):
        s = p.read_text(encoding='utf-8-sig')
        name = f'{project}/{p.relative_to(root).as_posix()}'
        if re.search(r'\b(?:AppTheme|AppSizing)\b|(?:core/app_theme|core/app_sizing|widgets/trexven_widgets)\.dart', s):
            report['obsolete_references'].append(name)
        if re.search(r'\b(?:TextField|TextFormField|DropdownButtonFormField|InputDecoration|ThemeData|InputDecorationTheme)\(', s):
            report['raw_controls'].append(name)
        for m in re.finditer(r'\bTrexven(?:TextField|TextFormField|Dropdown)(?:<[^>]+>)?\(', s):
            body = s[m.end():close(s, m.end()-1)]
            if not re.search(r'\b(?:label|labelText|hintText|showLabel|variant):', body):
                report['unlabelled_fields'].append(f'{name}:{s.count(chr(10),0,m.start())+1}')
with zipfile.ZipFile(BASE/'before_sources.zip') as z:
    for name in z.namelist():
        project, rel = name.split('/', 1)
        p = ROOTS[project]/rel
        raw = z.read(name)
        original = raw.decode('utf-8-sig')
        if not p.exists():
            report['deleted_source_files'].append(name)
            continue
        current = p.read_text(encoding='utf-8-sig')
        if raw != p.read_bytes():
            report['source_changes'].setdefault(project, []).append(rel)
        if 'package:flutter/material.dart' not in original:
            if raw == p.read_bytes(): report['preserved_nonpresentation_files'] += 1
        old_calls, new_calls = backend_calls(original), backend_calls(current)
        expected_price_call = normalized("_db.saveCatalogProduct(product.id, {'selling_price': intent.price}, _restockPriceRequestId)")
        if name == 'owner/screens/inventory/add_product_screen.dart' and expected_price_call in new_calls:
            new_calls.remove(expected_price_call)
            report['authorized_ui_call_additions'].append({'file': name, 'call': expected_price_call,
                'reason': 'User explicitly requested editable selling price in restock; existing partial-update API reused.'})
        if old_calls != new_calls:
            report['backend_call_differences'].append(name)
print(json.dumps(report, indent=2))
if report['obsolete_references'] or report['raw_controls'] or report['backend_call_differences']:
    raise SystemExit(1)

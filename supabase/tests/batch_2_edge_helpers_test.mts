import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { loginPermissions } from '../functions/_shared/login-permissions.ts';
import { assertStaffAccess } from '../functions/_shared/employee-access.ts';

test('manager defaults exclude prices, detailed finance and Vision', () => {
  const actual = loginPermissions('manager', []);
  assert.ok(actual.includes('manage_employees'));
  for (const p of ['override_price', 'view_finance', 'view_camera_events']) assert.ok(!actual.includes(p));
});
test('inventory and sales cannot receive price authority from stale grants', () => {
  for (const role of ['sales_employee', 'inventory_employee']) {
    const p = loginPermissions(role, ['override_price', 'branch_price_override', 'manage_employees', 'view_finance']);
    assert.ok(!p.includes('override_price'));
    assert.ok(!p.includes('branch_price_override'));
    assert.ok(!p.includes('manage_employees'));
    assert.ok(!p.includes('view_finance'));
  }
  assert.ok(!loginPermissions('inventory_employee', ['apply_discount']).includes('apply_discount'));
});
test('explicit manager price/finance grants survive and duplicate grants collapse', () => {
  const p = loginPermissions('manager', ['override_price', 'view_finance', 'override_price']);
  assert.equal(p.filter(v => v === 'override_price').length, 1);
  assert.ok(p.includes('view_finance'));
});
test('owner-only grants and unknown roles fail closed', () => {
  assert.deepEqual(loginPermissions('forged-owner', ['override_price']), []);
  assert.ok(!loginPermissions('manager', ['owner_app', 'view_camera_events', 'assign_roles']).includes('owner_app'));
});
test('staff helper calls trusted RPC without forwarding actor/permission claims', async () => {
  const calls: unknown[] = [];
  const client = { rpc: async (...args: unknown[]) => { calls.push(args); return { data: { owner: false }, error: null }; } };
  assert.deepEqual(await assertStaffAccess(client, 'business', 'employee'), { owner: false });
  assert.deepEqual(calls, [['assert_trexven_staff_access', { p_business_id: 'business', p_employee_id: 'employee' }]]);
});
test('RPC error, missing or malformed authorization response fails closed', async () => {
  for (const result of [{ error: {}, data: null }, { error: null, data: null }, { error: null, data: { owner: 'true' } }]) {
    await assert.rejects(() => assertStaffAccess({ rpc: async () => result }, 'business'));
  }
});
test('explicit denial overrides role defaults and stale grants', () => {
  assert.ok(!loginPermissions('manager', ['complete_sales'], ['complete_sales']).includes('complete_sales'));
});
test('deferred purchase-cost profit permission is omitted even for an explicitly granted manager', () => {
  const permissions = loginPermissions('manager', ['view_profit', 'view_finance']);
  assert.ok(!permissions.includes('view_profit'));
  assert.ok(permissions.includes('view_finance'));
  const angel = readFileSync(new URL('../functions/angel/index.ts', import.meta.url), 'utf8');
  assert.ok(!angel.includes('cost_price'));
});
test('POS employee-login deployment mirror matches the canonical Owner source', () => {
  for (const relative of ['employee-login/index.ts', '_shared/login-permissions.ts']) {
    assert.equal(readFileSync(new URL('../functions/' + relative, import.meta.url), 'utf8'),
      readFileSync(new URL('../../../trexvenpos/supabase/functions/' + relative, import.meta.url), 'utf8'));
  }
});

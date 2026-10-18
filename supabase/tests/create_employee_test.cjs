const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { webcrypto } = require('node:crypto');
const helper = fs.readFileSync('supabase/functions/_shared/employee-access.ts', 'utf8').replace(/^export /gm, '');
const source = fs.readFileSync('supabase/functions/create-employee/index.ts', 'utf8').replace(/^import .*;\r?\n/gm, '');

async function run(options = {}) {
  let handler, creates = 0, deletes = 0, finalizes = 0;
  const calls = [];
  const admin = {
    auth: { getUser: async () => ({ data: { user: options.invalidAuth ? null : { id: 'verified-user' } }, error: null }),
      admin: {
        createUser: async () => { creates++; return { data: { user: { id: 'new-auth-user' } }, error: null }; },
        deleteUser: async () => { deletes++; return { error: null }; },
      } },
    from: () => ({ select() { return this; }, eq() { return this; },
      maybeSingle: async () => ({ data: options.persisted ? { id: 'committed-employee' } : null,
        error: options.unknownPersistence ? { code: 'network' } : null }) }),
  };
  const caller = { rpc: async (name, args) => {
    calls.push([name, args]);
    if (name === 'assert_trexven_staff_access') return { data: options.denied ? null : { owner: !options.manager }, error: options.denied ? { code: '42501' } : null };
    finalizes++;
    if (options.finalizeFailure) return { data: null, error: { code: '42501' } };
    if (options.collision && finalizes === 1) return { data: null, error: { code: '23505' } };
    return { data: { id: 'employee', employee_code: args.p_employee_code, name: 'Synthetic', role: args.p_role }, error: null };
  } };
  vm.runInNewContext(stripTypeScriptTypes(helper + '\n' + source), {
    serve: fn => handler = fn,
    createClient: (url, key, config) => config?.global?.headers?.Authorization ? caller : admin,
    Deno: { env: { get: name => name === 'SUPABASE_URL' ? 'https://example.invalid' : 'test-only' } },
    crypto: webcrypto, Response, console: { error() {} },
  });
  const response = await handler(new Request('https://example.invalid', {
    method: 'POST', headers: { Authorization: 'Bearer test-only' },
    body: JSON.stringify({ business_id: 'business', name: 'Synthetic', password: 'test-password',
      role: options.role ?? 'sales_employee', actor_id: 'forged-owner', permissions: { override_price: true } }),
  }));
  return { status: response.status, creates, deletes, finalizes, calls, body: await response.json() };
}
(async () => {
  let r = await run();
  assert.equal(r.status, 200); assert.equal(r.creates, 1); assert.equal(r.deletes, 0);
  assert.equal(r.body.member_role, 'employee');
  assert.deepEqual(Object.keys(r.calls[0][1]).sort(), ['p_business_id', 'p_employee_id']);
  r = await run({ manager: true }); assert.equal(r.status, 403); assert.equal(r.creates, 0);
  r = await run({ manager: true, role: 'employee' }); assert.equal(r.status, 200);
  r = await run({ denied: true }); assert.equal(r.creates, 0); assert.equal(r.finalizes, 0);
  r = await run({ invalidAuth: true }); assert.equal(r.status, 401); assert.equal(r.creates, 0);
  r = await run({ finalizeFailure: true }); assert.equal(r.deletes, 1); assert.equal(r.status, 400);
  r = await run({ finalizeFailure: true, persisted: true }); assert.equal(r.deletes, 0);
  r = await run({ finalizeFailure: true, unknownPersistence: true }); assert.equal(r.deletes, 0);
  r = await run({ collision: true }); assert.equal(r.status, 200); assert.equal(r.finalizes, 2);
  console.log('PASS: nine employee-creation mock scenarios, provisional roles, caller-derived authorization, collisions and safe compensation.');
})().catch(error => { console.error(error); process.exitCode = 1; });

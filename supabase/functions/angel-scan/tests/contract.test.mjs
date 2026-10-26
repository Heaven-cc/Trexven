// Run: node --test supabase/functions/angel-scan/tests/contract.test.mjs
// Provider and auth are mocked; these are non-production handler contract tests.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = (await readFile(new URL('../index.ts', import.meta.url), 'utf8'))
  .replace(/^import .*\n/, '');
const compiled = stripTypeScriptTypes(source, { mode: 'transform' });
async function fixture({ denied = false, auth = true, type = 'product', count = 1 } = {}) {
  let handler;
  const rpcCalls = [], providerBodies = [];
  const sandbox = {
    Response, Request, TextEncoder, TextDecoder, Uint8Array, AbortSignal,
    crypto: globalThis.crypto, atob, console: { info() {}, error() {} },
    createClient: () => ({ auth: { getUser: async () => ({ data: { user: auth ? { id: 'user' } : null } }) },
      rpc: async (name, params) => {
        rpcCalls.push([name, params]);
        if (denied) return { error: { code: '42501' } };
        return name === 'match_angel_scan_items' ? { data: params.p_items.map(i => ({ ...i, matches: [] })) } : { data: {} };
      } }),
    fetch: async (url, options) => {
      if (url.endsWith('/models')) return Response.json({ data: [] });
      const body = JSON.parse(options.body); providerBodies.push(body);
      if (body.tools) return Response.json({ choices: [{ message: { content: 'Manufacturer finding', annotations: [] } }] });
      return Response.json({ choices: [{ message: { content: JSON.stringify({ type,
        document_kind: type === 'document' ? 'receipt' : null, items: Array.from({ length: count }, () => ({
          name: 'Brake pad', brand: 'Example', quantity: 2, cost: 4, uncertain: true,
        })) }) } }] });
    },
    Deno: { env: { get: name => name === 'GROQ_API_KEY' ? 'mock-key' : 'mock-config' }, serve: h => { handler = h; } },
  };
  vm.runInNewContext(compiled, sandbox);
  const body = { business_id: '11111111-1111-4111-8111-111111111111', purpose: 'inventory',
    mime_type: 'image/jpeg', image_base64: Buffer.from([255,216,255,0,0,0,0,0,0,0,0,0]).toString('base64'), auto_detect: true };
  const invoke = async (overrides = {}, token = true) => handler(new Request('https://example.test', {
    method: 'POST', headers: token ? { authorization: 'Bearer mock-user-jwt' } : {}, body: JSON.stringify({ ...body, ...overrides }),
  }));
  return { invoke, rpcCalls, providerBodies };
}

test('unauthenticated and unauthorized callers never reach provider or matching', async () => {
  for (const options of [{ auth: false }, { denied: true }]) {
    const f = await fixture(options); const response = await f.invoke();
    assert.equal(response.status, options.denied ? 403 : 401); assert.equal(f.providerBodies.length, 0);
  }
  const f = await fixture(); assert.equal((await f.invoke({}, false)).status, 401);
});
test('automatic single inventory product retains product classification', async () => {
  const f = await fixture(); const response = await f.invoke(); const result = await response.json();
  assert.equal(response.status, 200); assert.equal(result.type, 'product'); assert.equal(result.items.length, 1);
  assert.deepEqual(f.rpcCalls.map(([name]) => name), ['authorize_angel_scan', 'match_angel_scan_items']);
});
test('automatic receipt preserves document classification even with one line', async () => {
  const f = await fixture({ type: 'document' }); const result = await (await f.invoke()).json();
  assert.equal(result.type, 'document'); assert.equal(result.document_kind, 'receipt'); assert.equal(result.items.length, 1);
});
test('normal selling rejects explicit document requests', async () => {
  const f = await fixture(); assert.equal((await f.invoke({ purpose: 'sale', document: true })).status, 400);
  assert.equal(f.providerBodies.length, 0);
});
test('selling strips purchase cost from matched items', async () => {
  const f = await fixture(); const result = await (await f.invoke({ purpose: 'sale', auto_detect: false })).json();
  assert.equal(result.items[0].cost, undefined); assert.equal(f.rpcCalls[1][1].p_items[0].cost, undefined);
});
test('no detection returns empty items without opening a review', async () => {
  const f = await fixture({ type: 'none', count: 0 }); const result = await (await f.invoke()).json();
  assert.equal(result.requires_review, false); assert.equal(result.items.length, 0); assert.equal(f.rpcCalls.length, 1);
});
test('research authorizes scope, sends public identifiers only, and never changes stock', async () => {
  const f = await fixture(); const response = await f.invoke({ action: 'research', item: {
    name: 'Brake pad', barcode: '00123', customer: 'private', cost: 45, product_id: 'not-inventory',
  } });
  const result = await response.json(); assert.equal(response.status, 200); assert.equal(result.research.requires_confirmation, true);
  assert.deepEqual(f.rpcCalls.map(([name]) => name), ['authorize_angel_scan']);
  const sent = JSON.stringify(f.providerBodies); assert.ok(!sent.includes('private')); assert.ok(!sent.includes('not-inventory'));
});
test('malformed image is rejected before vision', async () => {
  const f = await fixture(); assert.equal((await f.invoke({ image_base64: 'not-valid' })).status, 400);
  assert.equal(f.providerBodies.length, 0);
});

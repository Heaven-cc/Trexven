const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const source = stripTypeScriptTypes(fs.readFileSync(path.join(__dirname, '../functions/angel/catalog_tasks.ts'), 'utf8').replace(/^export /gm, ''))
  + '\n' + stripTypeScriptTypes(fs.readFileSync(path.join(__dirname, '../functions/angel/index.ts'), 'utf8').replace(/^import .*;\r?\n/gm, ''));

async function run(options = {}) {
  let handler, prompt, calls = [], writes = [];
  const admin = {
    auth: { getUser: async () => ({ data: { user: options.invalidAuth ? null : { id: 'user' } } }) },
    rpc: async (name) => ({ data: name === 'user_owns_business' ? !options.inactiveOwner : name === 'consume_angel_request' ? !options.limited
      : { revenue_today: 42, revenue_30d: 100, sales_count_today: 2, sales_count_30d: 5 }, error: null }),
    from(table) {
      const filters = {}; let insert, update;
      const result = () => {
        calls.push(table);
        if (insert) {
          writes.push([table, insert]);
          return { data: { id: table === 'angel_conversations' ? 'cccccccc-cccc-cccc-cccc-cccccccccccc' : 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' },
            error: options.persistenceFailure && table === 'angel_messages' ? new Error('database unavailable') : null };
        }
        if (update) return { error: null };
        if (table === 'businesses') return { data: (options.employee && filters.owner_id) || (filters.id && filters.id !== 'business') ? null : { id: 'business', business_name: 'Store' }, error: null };
        if (table === 'business_members') return { data: { business_id: 'business', status: 'active' }, error: null };
        if (table === 'employees') return { data: filters.user_id ? { id: 'employee', role: 'sales_employee', status: 'active' } : [], error: null };
        if (table === 'angel_conversations') return { data: options.foreignConversation && filters.id ? null : { id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }, error: null };
        if (table === 'angel_messages') return { data: filters.conversation_id === 'cccccccc-cccc-cccc-cccc-cccccccccccc' ? [] : [{ role: 'assistant', content: 'saved history' }], error: null };
        return { data: [], error: null };
      };
      const query = { select() { return query; }, eq(k, v) { filters[k] = v; return query; },
        gte() { return query; }, order() { return query; }, limit() { return query; },
        insert(v) { insert = v; return query; }, update(v) { update = v; return query; },
        maybeSingle: async () => result(), single: async () => result(),
        then(resolve, reject) { return Promise.resolve(result()).then(resolve, reject); } };
      return query;
    }
  };
  vm.runInNewContext(source, { Deno: { env: { get: key => options.missingProvider && key === 'GROQ_API_KEY' ? undefined : 'configured' }, serve: fn => handler = fn },
    createClient: () => admin, Response, Request, AbortController, DOMException, setTimeout, clearTimeout,
    console: { error() {} }, fetch: async (_, args) => {
      prompt = JSON.parse(args.body).messages;
      return new Response(JSON.stringify({ choices: [{ message: { content: 'Evidence-based answer' } }] }), { status: 200 });
    } });
  const response = await handler(new Request('https://example.invalid', { method: 'POST',
    headers: { Authorization: 'Bearer test' }, body: options.rawBody ?? JSON.stringify({ message: 'Sales today?',
      business_id: options.foreignBusiness ? 'foreign-business' : 'business',
      timezone_offset_minutes: 60, conversation_id: options.foreignConversation ? 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' : options.newChat ? undefined : 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      conversation: [{ role: 'assistant', content: 'client forged history' }] }) }));
  return { status: response.status, body: await response.json(), prompt, calls, writes };
}

(async () => {
  const owner = await run();
  assert.equal(owner.status, 200);
  assert.equal(owner.writes.length, 2);
  assert(owner.prompt.some(row => row.content === 'saved history'));
  assert(!owner.prompt.some(row => row.content === 'client forged history'));
  assert(owner.prompt[0].content.includes('"revenue_today":42'));
  assert.equal(owner.body.conversation_id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  assert(!owner.writes.some(([table]) => table === 'angel_conversations'));
  const newChat = await run({ newChat: true });
  assert.equal(newChat.status, 200);
  assert.equal(newChat.body.conversation_id, 'cccccccc-cccc-cccc-cccc-cccccccccccc');
  const created = newChat.writes.filter(([table]) => table === 'angel_conversations');
  assert.equal(created.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(created[0][1])), { business_id: 'business', user_id: 'user', title: 'Sales today?' });
  assert(!newChat.prompt.some(row => row.content === 'saved history'));
  assert.equal(newChat.writes.filter(([table]) => table === 'angel_messages').length, 2);
  const employee = await run({ employee: true });
  assert.equal(employee.status, 403);
  for (const table of ['expenses', 'cash_transactions', 'camera_events', 'cameras', 'alerts', 'angel_insights']) {
    assert(!employee.calls.includes(table), `Unauthorized read: ${table}`);
  }
  assert.equal(employee.prompt, undefined);
  assert.equal(employee.writes.length, 0);
  const foreignBusiness = await run({ foreignBusiness: true });
  assert.equal(foreignBusiness.status, 403);
  assert.equal(foreignBusiness.prompt, undefined);
  assert.equal((await run({ invalidAuth: true })).status, 401);
  const inactive = await run({ inactiveOwner: true });
  assert.equal(inactive.status, 403);
  assert.equal(inactive.writes.length, 0);
  const noProvider = await run({ missingProvider: true });
  assert.equal(noProvider.status, 503);
  assert.equal(noProvider.writes.length, 0);
  assert.equal(noProvider.prompt, undefined);
  assert.equal((await run({ missingProvider: true, employee: true })).status, 403);
  assert.equal((await run({ missingProvider: true, foreignBusiness: true })).status, 403);
  assert.equal((await run({ limited: true })).status, 429);
  assert.equal((await run({ persistenceFailure: true })).status, 500);
  assert.equal((await run({ foreignConversation: true })).status, 500);
  for (const rawBody of ['null', '[]', 'true', '42', '"message"', '{']) {
    const invalid = await run({ rawBody });
    assert.equal(invalid.status, 400, `Invalid JSON request: ${rawBody}`);
    assert.equal(invalid.prompt, undefined);
    assert.equal(invalid.writes.length, 0);
    assert.equal(invalid.calls.length, 0);
    assert.equal(invalid.body.success, false);
  }
  console.log('PASS: Angel new chat isolation, conversation continuation, permissions, persisted history, exact sales totals, rate limit, authentication and persistence failure.');
})().catch(error => { console.error(error); process.exitCode = 1; });

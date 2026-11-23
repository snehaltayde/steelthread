import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { startTestServer, TOKENS } from './helpers.js';
import { readJson, sendJson } from '../src/http.js';

const UNAUTHORIZED = '{"error":"unauthorized"}';
const SECRET = 'boom-secret-detail';

let t;
before(async () => {
  t = await startTestServer({
    extraRoutes: [
      {
        method: 'POST',
        path: '/echo',
        async handler(req, res) {
          sendJson(res, 200, { got: await readJson(req) });
        },
      },
      {
        method: 'GET',
        path: '/boom',
        handler() {
          throw new Error(SECRET);
        },
      },
    ],
  });
});
after(() => t.close());

function assertJson(res) {
  assert.equal(res.headers['content-type'], 'application/json');
}

const OWN = { admin: { name: 'ada', role: 'admin' }, member: { name: 'max', role: 'member' }, guest: { name: 'gus', role: 'guest' } };

for (const role of ['admin', 'member', 'guest']) {
  test(`${role} gets 200 with own name and role only`, async () => {
    const res = await t.request(role, 'GET', '/me');
    assert.equal(res.status, 200);
    assertJson(res);
    assert.deepEqual(res.body, OWN[role]);
    assert.deepEqual(Object.keys(res.body).sort(), ['name', 'role']);
  });
}

test('guest sees only its own data (no other user, no id or hash)', async () => {
  const res = await t.request('guest', 'GET', '/me');
  assert.doesNotMatch(res.text, /ada|max|admin|member|token|hash|"id"/);
});

test('no Authorization header -> 401', async () => {
  const res = await t.request(null, 'GET', '/me');
  assert.equal(res.status, 401);
  assertJson(res);
  assert.equal(res.text, UNAUTHORIZED);
});

test('unknown token -> 401', async () => {
  const res = await t.request(null, 'GET', '/me', { headers: { authorization: 'Bearer nope-unknown' } });
  assert.equal(res.status, 401);
  assert.equal(res.text, UNAUTHORIZED);
});

test('unknown path without token -> 401 identical to unknown-token 401', async () => {
  const a = await t.request(null, 'GET', '/does-not-exist');
  const b = await t.request(null, 'GET', '/me', { headers: { authorization: 'Bearer nope-unknown' } });
  assert.equal(a.status, 401);
  assert.equal(b.status, 401);
  assert.equal(a.text, b.text);
  assert.equal(a.text, UNAUTHORIZED);
});

for (const header of [
  'Basic x',
  'Bearer',
  'Bearer ',
  'Bearer a b',
  `bearer${TOKENS.admin}`,
  TOKENS.admin,
  `Bearer ${'x'.repeat(257)}`,
]) {
  test(`malformed header ${JSON.stringify(header.slice(0, 40))} -> 401`, async () => {
    const res = await t.request(null, 'GET', '/me', { headers: { authorization: header } });
    assert.equal(res.status, 401);
    assert.equal(res.text, UNAUTHORIZED);
  });
}

test('lowercase bearer scheme with a valid token -> 200', async () => {
  const res = await t.request(null, 'GET', '/me', { headers: { authorization: `bearer ${TOKENS.member}` } });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, OWN.member);
});

for (const method of ['POST', 'PATCH', 'DELETE']) {
  test(`${method} on unknown path without token -> 401`, async () => {
    const res = await t.request(null, method, '/nowhere', { body: { a: 1 } });
    assert.equal(res.status, 401);
    assert.equal(res.text, UNAUTHORIZED);
  });
}

test('authenticated unknown path -> 404 not_found', async () => {
  const res = await t.request('guest', 'GET', '/nowhere');
  assert.equal(res.status, 404);
  assertJson(res);
  assert.deepEqual(res.body, { error: 'not_found' });
});

test('authenticated POST /me -> 404 (no 405)', async () => {
  const res = await t.request('admin', 'POST', '/me', { body: {} });
  assert.equal(res.status, 404);
  assert.deepEqual(res.body, { error: 'not_found' });
});

test('readJson: valid body is parsed', async () => {
  const res = await t.request('member', 'POST', '/echo', { body: { a: 1 } });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { got: { a: 1 } });
});

test('readJson: invalid JSON -> 400 invalid_input', async () => {
  const res = await t.request('member', 'POST', '/echo', { body: '{bad' });
  assert.equal(res.status, 400);
  assertJson(res);
  assert.deepEqual(res.body, { error: 'invalid_input' });
});

const oversize = JSON.stringify({ pad: 'x'.repeat(200 * 1024) });

test('readJson: body over 100 KB -> 400 invalid_input', async () => {
  const res = await t.request('member', 'POST', '/echo', { body: oversize });
  assert.equal(res.status, 400);
  assert.deepEqual(res.body, { error: 'invalid_input' });
});

test('readJson: oversize chunked body (no content-length) -> 400 invalid_input', async () => {
  const res = await t.request('member', 'POST', '/echo', {
    body: oversize,
    headers: { 'transfer-encoding': 'chunked' },
  });
  assert.equal(res.status, 400);
  assert.deepEqual(res.body, { error: 'invalid_input' });
});

test('readJson routes without a token -> 401 (bad and oversize bodies)', async () => {
  for (const body of ['{bad', oversize]) {
    const res = await t.request(null, 'POST', '/echo', { body });
    assert.equal(res.status, 401);
    assert.equal(res.text, UNAUTHORIZED);
  }
});

test('throwing route -> 500 internal with no detail, server stays up', async () => {
  const res = await t.request('admin', 'GET', '/boom');
  assert.equal(res.status, 500);
  assertJson(res);
  assert.equal(res.text, '{"error":"internal"}');
  assert.doesNotMatch(res.text, new RegExp(`${SECRET}|stack|at |${TOKENS.admin}`));
  const again = await t.request('admin', 'GET', '/me');
  assert.equal(again.status, 200);
});

test('role in header, query or body cannot change the result', async () => {
  const res = await t.request('guest', 'GET', '/me?role=admin&name=ada', {
    headers: { 'x-role': 'admin', 'x-user': 'ada' },
    body: { role: 'admin', name: 'ada' },
  });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, OWN.guest);
});

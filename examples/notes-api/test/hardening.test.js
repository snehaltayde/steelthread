import { test } from 'node:test';
import assert from 'node:assert/strict';
import { connect } from 'node:net';
import { startTestServer, TOKENS } from './helpers.js';

// Sends raw bytes over a TCP socket and resolves with everything the server wrote back.
function rawRequest(port, bytes) {
  return new Promise((resolve, reject) => {
    const socket = connect(port, '127.0.0.1', () => socket.write(bytes));
    const chunks = [];
    socket.on('data', (c) => chunks.push(c));
    socket.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    socket.on('error', reject);
    socket.setTimeout(2000, () => socket.destroy(new Error('raw request timed out')));
  });
}

function parseRaw(text) {
  const [head, body] = text.split('\r\n\r\n');
  const [statusLine, ...lines] = head.split('\r\n');
  const headers = Object.fromEntries(
    lines.map((l) => [l.slice(0, l.indexOf(':')).toLowerCase(), l.slice(l.indexOf(':') + 1).trim()]),
  );
  return { status: Number(statusLine.split(' ')[1]), headers, body };
}

test('unparseable request URL without a token -> 401 JSON, server stays up', async () => {
  const t = await startTestServer();
  try {
    const raw = await rawRequest(t.port, 'GET http://[ HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n');
    const res = parseRaw(raw);
    assert.equal(res.status, 401);
    assert.equal(res.headers['content-type'], 'application/json');
    assert.equal(res.body, '{"error":"unauthorized"}');
    const again = await t.request('admin', 'GET', '/me');
    assert.equal(again.status, 200);
  } finally {
    await t.close();
  }
});

test('unparseable request URL with a valid token -> 404 not_found', async () => {
  const t = await startTestServer();
  try {
    const raw = await rawRequest(
      t.port,
      `GET http://[ HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer ${TOKENS.member}\r\nConnection: close\r\n\r\n`,
    );
    const res = parseRaw(raw);
    assert.equal(res.status, 404);
    assert.equal(res.body, '{"error":"not_found"}');
  } finally {
    await t.close();
  }
});

test('malformed HTTP -> fixed JSON 400 with Connection: close, server stays up', async () => {
  const t = await startTestServer();
  try {
    const raw = await rawRequest(t.port, 'THIS IS NOT HTTP\r\n\r\n');
    const res = parseRaw(raw);
    assert.equal(res.status, 400);
    assert.equal(res.headers['content-type'], 'application/json');
    assert.equal(res.headers.connection, 'close');
    assert.equal(res.body, '{"error":"invalid_input"}');
    const again = await t.request('guest', 'GET', '/me');
    assert.equal(again.status, 200);
  } finally {
    await t.close();
  }
});

test('log lines never contain the token or the authorization header', async () => {
  const lines = [];
  const t = await startTestServer({
    log: (line) => lines.push(line),
    extraRoutes: [{ method: 'GET', path: '/boom', handler() { throw new Error('boom'); } }],
  });
  try {
    for (const role of ['admin', 'member', 'guest']) {
      await t.request(role, 'GET', '/me');
      await t.request(role, 'GET', `/nowhere?token=${TOKENS[role]}`);
      await t.request(role, 'GET', '/boom');
    }
    assert.ok(lines.length >= 9);
    for (const line of lines) {
      for (const token of Object.values(TOKENS)) assert.ok(!line.includes(token), line);
      assert.doesNotMatch(line, /authorization/i);
    }
  } finally {
    await t.close();
  }
});

import { createServer, request as httpRequest } from 'node:http';
import { openDb } from '../src/db.js';
import { migrate } from '../src/migrate.js';
import { createApp } from '../src/app.js';
import { attachClientErrorHandler } from '../src/http.js';
import { hashToken } from '../src/auth.js';

export const TOKENS = {
  admin: 'test-token-admin-0001',
  member: 'test-token-member-0002',
  guest: 'test-token-guest-0003',
};
const USERS = [
  { name: 'ada', role: 'admin' },
  { name: 'max', role: 'member' },
  { name: 'gus', role: 'guest' },
];

export async function startTestServer({ extraRoutes = [], log = () => {} } = {}) {
  const db = openDb(':memory:');
  migrate(db);
  const insert = db.prepare(
    'INSERT INTO users (name, role, token_hash, created_at) VALUES (?, ?, ?, ?)',
  );
  for (const u of USERS) insert.run(u.name, u.role, hashToken(TOKENS[u.role]), new Date().toISOString());

  const server = attachClientErrorHandler(createServer(createApp({ db, extraRoutes, log })));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}`;

  // role: 'admin' | 'member' | 'guest' | null (no Authorization header).
  // opts.headers overrides (set authorization to send a raw header); opts.body: string or object.
  function request(role, method, path, opts = {}) {
    const headers = {};
    if (role) headers.authorization = `Bearer ${TOKENS[role]}`;
    Object.assign(headers, opts.headers);
    let body = opts.body;
    if (body !== undefined && typeof body !== 'string' && !Buffer.isBuffer(body)) {
      body = JSON.stringify(body);
      headers['content-type'] ??= 'application/json';
    }
    // Node's client sends GET/DELETE bodies without framing unless told; always frame them.
    if (body !== undefined && !headers['transfer-encoding']) {
      headers['content-length'] = Buffer.byteLength(body);
    }
    return new Promise((resolve, reject) => {
      const req = httpRequest({ host: '127.0.0.1', port, method, path, headers }, (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          let json;
          try {
            json = JSON.parse(text);
          } catch {
            json = undefined;
          }
          resolve({ status: res.statusCode, headers: res.headers, text, body: json });
        });
      });
      req.on('error', reject);
      req.end(body);
    });
  }

  function close() {
    server.closeAllConnections();
    return new Promise((resolve) => server.close(() => { db.close(); resolve(); }));
  }

  return { baseUrl, port, db, tokens: TOKENS, request, close };
}

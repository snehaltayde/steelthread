import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { openDb } from '../src/db.js';
import { migrate } from '../src/migrate.js';
import { hashToken } from '../src/auth.js';

const MIGRATIONS = fileURLToPath(new URL('../migrations/', import.meta.url));

function freshDb() {
  const db = openDb(':memory:');
  migrate(db);
  return db;
}

function addUser(db, name, role, token) {
  db.prepare('INSERT INTO users (name, role, token_hash, created_at) VALUES (?, ?, ?, ?)').run(
    name,
    role,
    hashToken(token),
    new Date().toISOString(),
  );
}

test('fresh database gets users and schema_migrations with 001', () => {
  const db = freshDb();
  const tables = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
    .all()
    .map((r) => r.name);
  assert.ok(tables.includes('users'));
  assert.ok(tables.includes('schema_migrations'));
  const versions = db.prepare('SELECT version FROM schema_migrations').all().map((r) => r.version);
  assert.deepEqual(versions, ['001']);
  db.close();
});

test('second run applies nothing', () => {
  const db = freshDb();
  assert.deepEqual(migrate(db), []);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM schema_migrations').get().n, 1);
  db.close();
});

test('users constraints: bad role, duplicate name, duplicate token_hash throw', () => {
  const db = freshDb();
  addUser(db, 'ada', 'admin', 't1');
  assert.throws(() => addUser(db, 'eve', 'owner', 't2'), /CHECK/);
  assert.throws(() => addUser(db, 'ada', 'member', 't3'), /UNIQUE/);
  assert.throws(() => addUser(db, 'bob', 'member', 't1'), /UNIQUE/);
  db.close();
});

test('a broken migration rolls back and records no version', () => {
  const dir = mkdtempSync(join(tmpdir(), 'notes-migrate-'));
  try {
    writeFileSync(join(dir, '001-users.sql'), 'CREATE TABLE ok_table (id INTEGER PRIMARY KEY);');
    writeFileSync(
      join(dir, '002-broken.sql'),
      'CREATE TABLE half_done (id INTEGER PRIMARY KEY);\nTHIS IS NOT SQL;',
    );
    const db = openDb(':memory:');
    assert.throws(() => migrate(db, dir), /002-broken\.sql/);
    const versions = db.prepare('SELECT version FROM schema_migrations').all().map((r) => r.version);
    assert.deepEqual(versions, ['001']);
    const half = db.prepare("SELECT name FROM sqlite_master WHERE name = 'half_done'").get();
    assert.equal(half, undefined);
    assert.equal(db.isTransaction, false);
    db.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
  assert.ok(MIGRATIONS); // default dir resolves
});

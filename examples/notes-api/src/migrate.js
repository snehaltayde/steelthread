import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { openDb } from './db.js';

const DEFAULT_DIR = fileURLToPath(new URL('../migrations/', import.meta.url));
const FILE_PATTERN = /^(\d{3})-.+\.sql$/;

// Applies migrations/NNN-*.sql in order, one transaction each, skipping applied versions.
// Returns the versions applied by this run.
export function migrate(db, dir = DEFAULT_DIR) {
  db.exec(
    'CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TEXT NOT NULL)',
  );
  const applied = new Set(
    db.prepare('SELECT version FROM schema_migrations').all().map((r) => r.version),
  );
  const files = readdirSync(dir)
    .filter((f) => FILE_PATTERN.test(f))
    .sort();
  const ran = [];
  for (const file of files) {
    const version = file.match(FILE_PATTERN)[1];
    if (applied.has(version)) continue;
    const sql = readFileSync(join(dir, file), 'utf8');
    db.exec('BEGIN');
    try {
      db.exec(sql);
      db.prepare('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)').run(
        version,
        new Date().toISOString(),
      );
      db.exec('COMMIT');
    } catch (err) {
      db.exec('ROLLBACK');
      throw new Error(`migration ${file} failed: ${err.message}`, { cause: err });
    }
    ran.push(version);
  }
  return ran;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const file = process.env.DB_FILE || 'data/notes.db';
  const db = openDb(file);
  const ran = migrate(db);
  db.close();
  console.log(ran.length ? `applied ${ran.join(', ')}` : 'nothing to apply');
}

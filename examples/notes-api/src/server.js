import { createServer } from 'node:http';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { openDb } from './db.js';
import { migrate } from './migrate.js';
import { createApp } from './app.js';
import { attachClientErrorHandler } from './http.js';

const port = Number(process.env.PORT || 3000);
const dbFile = process.env.DB_FILE || 'data/notes.db';

if (dbFile !== ':memory:') mkdirSync(dirname(dbFile), { recursive: true });
const db = openDb(dbFile);
migrate(db);

const server = attachClientErrorHandler(createServer(createApp({ db })));
server.listen(port, '127.0.0.1', () => {
  console.log(`listening on http://127.0.0.1:${server.address().port}`);
});

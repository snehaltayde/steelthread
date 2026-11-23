# Phase 0 plan

## Line 1: GET /me, auth gate, server, DB, migration 001, JSON error shell

Plan by steelthread:architect (approved on the owner's behalf). Feature list is a floor.

### Features
1. `node src/server.js` binds 127.0.0.1; `PORT`, `DB_FILE` overrides (defaults 3000, `data/notes.db`); creates `data/` if missing; runs migrations at start; logs one line per request (method, path, status; never the token or Authorization header).
2. Auth gate runs first for every request (any method, unknown paths too). Missing/malformed -> 401 `{"error":"unauthorized"}`. Malformed = no header, scheme other than `Bearer` (case-insensitive), empty token, extra parts, token > 256 chars. Unknown token -> identical 401 body.
3. Role comes from the DB row: `req.user = {id, name, role}`.
4. `GET /me` -> 200 `{"name","role"}` only (no id, no hash), after `me.read` check via `src/permissions/me.js`; false -> 403 `{"error":"forbidden"}`.
5. Error shell: all responses JSON with content-type application/json. 401 unauthorized, 403 forbidden, 404 not_found, 400 invalid_input, 500 `{"error":"internal"}` (no message/stack; error logged to stderr without headers). Shared `readJson` helper: invalid JSON or body > 100 KB -> 400 invalid_input.
6. After auth: unknown path or wrong method -> 404 not_found (no 405).
7. `src/migrate.js`: creates `schema_migrations` itself, applies `migrations/NNN-*.sql` in order, one transaction each, skips applied. CLI (`DB_FILE=... node src/migrate.js`) and importable `migrate(db, dir?)`.

### Files
- `package.json` `{"type":"module","private":true}`, no dependencies, `test` script
- `.gitignore` (`data/`)
- `migrations/001-users.sql`: users(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, role TEXT NOT NULL CHECK (role IN ('admin','member','guest')), token_hash TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL); no BEGIN/COMMIT inside
- `src/db.js` `openDb(file)` (foreign_keys=ON)
- `src/migrate.js`
- `src/auth.js` `hashToken`, `parseBearer`, `authenticate(db, req)` (parameterised lookup on token_hash)
- `src/permissions/me.js` `ME_ACTIONS = {read: Set(admin,member,guest)}`, `canReadMe(user)` (deny by default)
- `src/routes/me.js`
- `src/app.js` `createApp({db, extraRoutes=[], log})`: router (exact method+path), `sendJson`, `readJson`, try/catch -> 500
- `src/server.js`
- `test/helpers.js` `startTestServer({extraRoutes})`: :memory:, migrate, users ada/admin, max/member, gus/guest with fixed tokens hashed via `hashToken`; port 0; silent log; returns `{baseUrl, db, tokens, request(role|null, method, path, opts), close()}`
- `test/me.test.js`, `test/migrate.test.js`

### Tests
me.test.js: each role gets 200 with own name/role and exactly keys name, role; guest sees only own data; no header 401; unknown token 401; unknown path no token 401 with body identical to unknown-token 401; malformed headers (`Basic x`, `Bearer` alone, `Bearer a b`, `bearer<valid>` no space, token w/o scheme) 401, lowercase `bearer <valid>` 200; POST/PATCH/DELETE on unknown path w/o token 401; authenticated unknown path 404; authenticated `POST /me` 404; injected route using readJson: `{bad` -> 400 invalid_input, oversize -> 400, same without token -> 401; injected throwing route -> 500 `{"error":"internal"}` with no message/stack/token in raw text and server stays up; role header/query/body cannot change result.
migrate.test.js: fresh DB has users + schema_migrations 001; second run applies nothing; bad role / duplicate name / duplicate token_hash throw; broken temp migration rolls back with no version row.

### Risks
node:sqlite API unconfirmed: check locally first (`node --version`, a one-line DatabaseSync check). Test oversize-body case first (destroy/drain stream on overflow or tests hang). No install, no download.

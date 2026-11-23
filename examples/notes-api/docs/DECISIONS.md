# Decisions

Newest first. One entry per choice that someone might later ask "why" about. Entries made
without asking the owner are marked so they are easy to review.

## 2026-11-24 Line 1 build details

- **Decision:** Migration versions are the 3-digit file prefix (`001`). Request log lines hold the path without the query string. `readJson` rejects early on a declared `content-length` over 100 KB and otherwise counts bytes while streaming; on overflow it stops collecting and drains (`resume`) the rest so the 400 reaches the client. Any request body left unread (for example a 401 before parsing) is drained after the response. `log(line, level)` is the one log function; `level === 'error'` goes to stderr. `HttpError(status, code)` is thrown by routes and turned into the JSON body by the app; anything else becomes the fixed 500.
- **Why:** Keeps one error path and avoids hung or reset connections on oversize bodies; the query string could carry user input that should not land in logs.
- **Instead of:** Destroying the socket on overflow (the client would see a reset instead of the 400).
- **Decided by:** feature-builder, without asking the owner
- **Slice:** Any of the three roles can send its token to `GET /me`

## 2026-11-24 Auth and error shell details

- **Decision:** `GET /me` returns only `{name, role}`. Auth runs before routing and body parsing; every auth failure gives one identical 401 body. A wrong method on a known path is 404 (not 405). The 500 body is fixed `{"error":"internal"}`; errors go to stderr without headers. `schema_migrations` is created by `migrate.js` itself; migration files hold no transaction statements. JSON bodies are capped at 100 KB; Bearer scheme match is case-insensitive. `createApp` takes `extraRoutes` and a log function so the error shell is testable. `package.json` is added with `"type":"module"` and no dependencies.
- **Why:** Least needed to meet the line, nothing leaks, error set stays at the five documented codes.
- **Instead of:** Returning id/hash, 405 responses, verbose 500s.
- **Decided by:** on the owner's behalf, from the architect's recommendation
- **Slice:** Any of the three roles can send its token to `GET /me`

## 2026-11-24 Hard delete, no audit trail

- **Decision:** `DELETE /notes/:id` removes the row; no audit table in this version.
- **Why:** Not asked for; keeps the product tiny. Recorded so it is a choice, not an oversight.
- **Instead of:** Soft delete plus an audit log; better once more than one team relies on it.
- **Decided by:** on the owner's behalf, from the architect's recommendation
- **Slice:** An admin can delete a note

## 2026-11-24 Note permissions

- **Decision:** Notes are private by default; admin and member see all notes; a member may mark only their own notes public, an admin any; public is one-way (no "make private again" in this version); only admin deletes. Check order is 401, role 403, 404, ownership 403, so a guest never learns a private note exists.
- **Why:** The brief fixes guest = public only and delete = admin only; the rest fills gaps with the least-trusted-first reading.
- **Instead of:** Members seeing only their own notes (a "shared team notes" product would be pointless) or members marking any note public.
- **Decided by:** on the owner's behalf, from the architect's recommendation
- **Slice:** Phase 1 note lines

## 2026-11-24 Tokens stored hashed, seeded for dev

- **Decision:** Bearer tokens; the database holds only the SHA-256 hash. `scripts/seed.js` makes one user per role with random tokens printed once. Tokens are 32 random bytes, so a plain unsalted hash is enough.
- **Why:** The brief asks for sign-in "with a token" only; hashing costs a few lines and protects a copied database file.
- **Instead of:** Plain-text tokens (simpler, leaks on copy) or a login endpoint with passwords (not requested).
- **Decided by:** on the owner's behalf, from the architect's recommendation
- **Slice:** Any of the three roles can send its token to `GET /me`

## 2026-11-24 Stack: Node built-ins only

- **Decision:** Node 26.0.0, `node:http`, `node:sqlite`, `node:test`, plain ES modules, no `package.json` dependencies, bound to `127.0.0.1`.
- **Why:** The owner's insistence: nothing installed or downloaded, no UI. Verified here: `node:sqlite` loads without a flag on v26.0.0 (SQLite 3.53.0).
- **Instead of:** Express or Fastify with better-sqlite3 (more convenient; ruled out by the owner). I could not check Node's release page online (web search was not permitted), so the version is the one installed, not confirmed as the latest.
- **Decided by:** owner
- **Slice:** Phase 0

## 2026-11-24 Lint and browser tests have no tool

- **Decision:** Lint row is `node --check` on every source file (syntax only, no style rules). Browser test rows point at `node:test`, since there are no screens.
- **Why:** The built-in-only rule leaves no linter; the check is the closest real one.
- **Instead of:** ESLint (a dependency); worth revisiting only if the owner relaxes the rule.
- **Decided by:** on the owner's behalf, from the architect's recommendation
- **Slice:** Phase 0

## 2026-11-24 Malformed requests answer in JSON, URL parsed after auth

- **Decision:** The request URL is parsed only after authentication, inside the handler's try: no token -> 401, unparseable URL -> 404 `not_found`. Requests rejected before auth log their path as `-`. HTTP the parser rejects gets a fixed `400 {"error":"invalid_input"}` with `Connection: close` from `attachClientErrorHandler` in `src/http.js`, used by the server and the test server alike.
- **Why:** An unparseable request target crashed the process; unauthenticated callers should learn nothing about paths, and every error stays JSON.
- **Instead of:** Logging the raw URL of unauthenticated requests (attacker-controlled text in logs) or Node's default plain-text 400.
- **Decided by:** on the owner's behalf, from review findings
- **Slice:** Any of the three roles can send its token to `GET /me`

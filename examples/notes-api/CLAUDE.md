# Team Notes API

A tiny JSON API for shared team notes, used by a team in three roles: `admin`, `member`
and `guest`. It runs locally only, has no UI, and must never show a private note to a
guest.

## Stack (do not swap without asking)

| Layer | Choice | Version | Why |
|---|---|---|---|
| Language / runtime | Node.js, built-in modules only, plain JavaScript (ES modules) | 26.0.0 (the version installed here; checked locally, not against the web) | Owner's requirement: no npm dependencies, nothing installed or downloaded |
| Framework | `node:http`, a small hand-written router | built in | Owner's requirement |
| Database and migrations | `node:sqlite` (`DatabaseSync`), numbered `.sql` files in `migrations/` applied by `src/migrate.js` | SQLite 3.53.0 (bundled with Node 26.0.0) | Owner's requirement; file database locally, `:memory:` in tests |
| Auth | Bearer token (`Authorization: Bearer <token>`); only the SHA-256 hash is stored (`node:crypto`) | built in | Simple sign-in by token; a leaked database does not leak tokens |
| Tests (unit, browser) | `node:test` with `node:assert`; requests go to a real server on an ephemeral port. No browser tests: there are no screens | built in | Owner's requirement |
| Hosting | Local machine only, bound to `127.0.0.1` | n/a | Owner's requirement |

## Folder layout

- `src/server.js` starts the HTTP server; `src/app.js` builds the handler and the router.
- `src/auth.js` token lookup and the 401 gate. `src/db.js` opens the database. `src/migrate.js` runs migrations.
- `src/permissions/` one module per domain (`notes.js`, `me.js`): the only place a role is checked.
- `src/routes/` one file per domain (`me.js`, `notes.js`). A new feature's routes go here and its checks in `src/permissions/`.
- `migrations/` numbered SQL files (`001-users.sql`, ...). `scripts/seed.js` seeds data.
- `test/` one `*.test.js` per domain, plus `test/helpers.js` (the per-role request helper).
- `docs/` ARCHITECTURE, FEATURES, DECISIONS, PLAYBOOK. No `UI.md`: there are no screens.

## Non-negotiable rules

- **Permissions:** checks live in `src/permissions/`, one module per domain. Nothing reads or
  writes without going through them. Anything not in the matrix in `docs/ARCHITECTURE.md` is denied.
- **Authentication first:** every route, including unknown paths, returns 401 for a missing or
  unknown token before anything else happens. No route is public.
- **Data scoping:** every notes read is filtered by visibility in SQL (`WHERE public = 1` for a
  guest), not by filtering in JavaScript afterwards. The role comes from the database row of the
  token, never from the request.
- **Least-trusted role:** `guest`. It gets a test on every new read, route and write.
  A guest must not learn a private note exists (no private titles, counts, ids or distinct
  error messages).
- **Audit trail:** none in this version; recorded in `docs/DECISIONS.md`. Add one in the same
  transaction as the write if it becomes a requirement.
- **Data formats:** ids are integers; times are ISO 8601 UTC strings; deletion is a hard
  delete; all bodies are JSON with `{"error": "<code>"}` on failure.
- **Tokens:** never stored or logged in plain text outside seed output for local development.
- **Dependencies:** none. No `package.json` dependencies, nothing installed or downloaded. Any
  new dependency needs a stated reason in `docs/DECISIONS.md` and the owner's approval.

## Commands

| Task | Command |
|---|---|
| Install | Nothing to install (no dependencies). Check the runtime: `node --version` (needs 26+) |
| Run locally | `node src/server.js` (listens on `127.0.0.1:3000`; set `PORT` and `DB_FILE` to override) |
| Lint | No linter exists for built-in-only Node. Closest real check: `node --check` on every source file: `find src scripts test -name '*.js' -print0 \| xargs -0 -n1 node --check` |
| Unit tests (all) | `node --test` |
| Unit tests (one file) | `node --test test/<file>.test.js` |
| Migrate a fresh database | `rm -f data/fresh.db && DB_FILE=data/fresh.db node src/migrate.js` |
| Browser tests (one spec) | None: no screens. Use `node --test test/<file>.test.js` |
| Browser tests (all) | None: no screens. Use `node --test` |
| Seed | `node scripts/seed.js` (creates one user per role and prints their dev tokens) |

<!-- The working agreement from the steelthread plugin goes below this line. -->

# Working agreement: how software is built here

These rules apply whenever a session builds or changes software in this project. The
project's own rules above win where they say something different.

## Before any code

- A project needs four documents before feature work: `CLAUDE.md` (stack, folder layout,
  non-negotiable rules, commands), `docs/ARCHITECTURE.md`, `docs/FEATURES.md` (phases of
  checkboxes, in build order) and `docs/DECISIONS.md`; plus `docs/UI.md` if it has screens.
  If they are missing, run `/steelthread:new-project` first.
- The stack and the non-negotiable rules are chosen per project and then not swapped.
- Check a library's current docs before using its API. Do not write from memory.

## One slice at a time, end to end

- A slice is one `docs/FEATURES.md` line taken from data model to tests: schema → migration →
  permission checks → reads and writes → UI → tests. No empty screens for later phases.
- Flow per slice: `steelthread:architect` plans (full feature list, file plan, decisions) →
  `steelthread:feature-builder` builds → `steelthread:ui-designer` for any new or changed
  screen → `steelthread:reviewer` on the result → fix → verify.
  `/steelthread:feature <line>` runs this.
- **No scope cutting.** The architect's feature list is a floor. Lean code is welcome (reuse,
  no speculative options, no new dependency without a stated reason); fewer features is not.
- Permissions live in one place per domain and are tested for every role before the reads
  that depend on them. The least-trusted role gets a test on every new read.

## Deciding without me

- Do not stop for my approval of plans, decisions, merges or the next task. Take the
  architect's recommendation, record it in `docs/DECISIONS.md`, keep going, and list the
  decisions made on my behalf in the report (schema and permission decisions first).
- When a slice is finished and checked, start the next line in order.
- Still ask first: deleting or re-seeding my data, the first push or first production deploy
  of a project, anything that costs money, anything that cannot be undone.
- If a requirement is truly ambiguous, ask one precise question and carry on with the rest.

## Verifying

- After coding: lint, the full unit suite, and migrations against a fresh database, run
  through `steelthread-verify`. Builders run only the slice's own tests; the session does
  the one full run. A slice runs only its own browser spec; the full browser suite runs
  once per phase.
- Never say something works unless it was run. Every report says what was run, what failed,
  and what was not verified. A test that fails only in full runs is reported, not hidden.
- The main branch never holds an unverified state. One session owns merges into it.

## Running agents

- Model split: the session model plans and reviews; `opus` writes server, permission,
  security and hard UI code; `sonnet` does docs, seed data and simple packages.
- Never two writers in one checkout. Independent feature blocks may run side by side, each in
  its own git worktree, branch and database. Heavy commands (test suites, builds) run through
  `steelthread-lock` so only one runs at a time on the machine.
- Keep usage low: briefs name exact files; agents do not read large docs whole; one plan file
  per phase (`docs/plans/phase-<n>.md`) instead of a fresh plan per agent; about 150 tool
  calls per agent; reports of about ten lines.
- Never kill processes by name pattern or port sweep.

## Reporting to me

- Short, plain updates. A status table only when a slice finishes or something goes wrong.
- Progress updates name the slice, its stage and the estimated time left.

Lessons this project has learned live in `docs/PLAYBOOK.md`. Deeper notes for long builds
are in the `steelthread:orchestrating-builds`, `steelthread:migration-safety` and
`steelthread:go-live` skills; load them when the work calls for them.

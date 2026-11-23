# The example: one real run of `tests/live-slice.sh`

[`notes-api`](notes-api) is what one run of [`tests/live-slice.sh`](../tests/live-slice.sh)
produced. Nothing in it was edited by hand: it is the project's git tree as the session
committed it. Run the script yourself and you will get a different project of the same
shape.

## The run

| | |
|---|---|
| Date | 24 November 2026 |
| Machine | macOS 26.5, Apple silicon, Node 26.0 |
| Claude Code | 2.1.330, headless (`claude -p`), this plugin only, no user settings |
| Models | Session on Sonnet; `feature-builder` on Opus, as its agent file says |
| Session 1, `/steelthread:new-project` | 61 seconds, about 0.34 US dollars |
| Session 2, `/steelthread:feature` (one line) | 6 minutes 3 seconds, about 1.68 US dollars |
| Total | About 7 minutes, about 2.02 US dollars |
| Agents started | 1 architect, 2 feature-builders (the build, then the reviewer's fixes), 2 reviewers (the review, then a recheck) |
| Commits | 3: the documents, the plan, the feature |
| Tests in the built project | 42, all passing when run from outside the session |
| Outside checks by the script | 20 of 20 passed |

The line it built, from [`notes-api/docs/FEATURES.md`](notes-api/docs/FEATURES.md):

> Any of the three roles (admin, member, guest) can send its token to `GET /me` and get its
> own name and role back, and a missing or unknown token gets 401 on every route.

## What the script checked

```text
Checks on <work-folder>/notes-api
  PASS  both sessions finished without an error
  PASS  CLAUDE.md was written
  PASS  docs/ARCHITECTURE.md was written
  PASS  docs/FEATURES.md was written
  PASS  docs/DECISIONS.md was written
  PASS  docs/PLAYBOOK.md was written
  PASS  CLAUDE.md holds the working agreement, unchanged
  PASS  the plan was saved to docs/plans/phase-0.md
  PASS  exactly one feature line is ticked
  PASS  the documents were committed before the feature
  PASS  nothing is left uncommitted
  PASS  a migration was written
  PASS  permission rules have a file of their own
  PASS  the tests name all three roles
  PASS  the tests cover a request with no token (401)
  PASS  architect, feature-builder and reviewer each ran
  PASS  the session ran steelthread-verify
  PASS  the report says what was not verified
  PASS  the report lists decisions made on your behalf
  PASS  the project's tests pass when run from outside (node --test)
           ℹ tests 42
           ℹ pass 42
           ℹ fail 0
```

## Things to look at

- [`notes-api/CLAUDE.md`](notes-api/CLAUDE.md): the project's rules and commands, with the
  working agreement below them.
- [`notes-api/docs/plans/phase-0.md`](notes-api/docs/plans/phase-0.md): the architect's
  plan, saved by the session.
- [`notes-api/docs/DECISIONS.md`](notes-api/docs/DECISIONS.md): every decision made
  without asking, with the reason.
- [`notes-api/src/permissions/me.js`](notes-api/src/permissions/me.js): the permission
  rule, in its own file, denying by default.
- [`notes-api/test/me.test.js`](notes-api/test/me.test.js): `GET /me` tested as each of
  the three roles, plus a guest test that it sees nothing but its own name and role.

To run its tests (a Node with `node:sqlite` built in; we used Node 26; nothing to install):

```bash
cd examples/notes-api && node --test
```

## The session's finishing report, as written

The commit it names (`c821b8f`) is not the final one: the session amended it to tick the
box, and the run ended on `048fa9d`. It says 41 tests where `node --test` counts 42; we
left the report as written.

---

The first Phase 0 line is built, verified and committed. I stopped there, as you asked.

#### What was built
- **First commit:** the project documents (`09dfe59`), before any code.
- **Slice** (`c821b8f`): `GET /me` returns `{name, role}` for admin, member and guest. A missing, malformed or unknown token gets the same 401 JSON body on every path and method.
- **Supporting parts:**
  - the `127.0.0.1` server
  - the SQLite database
  - migration `001-users.sql` through `src/migrate.js`
  - the JSON error shell (400, 401, 403, 404, 500, with a fixed 500 body)
- **Tests:** 41 across `test/me.test.js`, `test/migrate.test.js`, `test/hardening.test.js` and `test/permissions.test.js`.
- **Plan:** saved in `docs/plans/phase-0.md`.

#### Decisions made on your behalf
- **Schema:**
  - `users` only in migration 001: unique name, unique `token_hash`, and a role limited to the three roles.
  - `schema_migrations` is created by `migrate.js` itself.
  - Migration files contain no transaction statements.
- **Permissions:**
  - `GET /me` returns only name and role, with no id or hash.
  - The role comes from the database row of the token.
  - `me.read` is an allow-list in `src/permissions/me.js` that denies by default.
  - Auth runs before routing and body parsing.
- **Other:**
  - A wrong method on a known path is 404, not 405.
  - JSON bodies are capped at 100 KB.
  - `package.json` was added with no dependencies.
- **Reviewer fixes:**
  - An unparseable request URL used to crash the server before auth. It now gets 401, or 404 once authenticated.
  - Malformed HTTP now gets a JSON 400.
  - The circular import is gone.
  - Tests were added for token-free logs and `canReadMe`.
- **Where recorded:** all in `docs/DECISIONS.md`.

#### `steelthread-verify` report
| Step | Result |
|---|---|
| lint | PASS |
| unit (`node --test`) | PASS |
| migrate-fresh | PASS |
| browser | NOT RUN: no screens |

#### Not verified
- Starting `node src/server.js` by hand and calling it with `curl`; the tests use real servers on ephemeral ports, but the CLI entry point and default port 3000 were not run.
- The data-directory creation path.
- The fresh-database check printed its result, but I did not read it. Only the PASS verdict was confirmed.
- A browser suite and the phase-end audit, which come at the end of the phase.

#### Click through yourself
Run `node src/server.js`, then `curl -i localhost:3000/me` (expect 401). The tokens only exist once the seed line is built, so a 200 with a token can't be tried by hand yet.

#### FLOW NOTES
1. **Monitor tool:** I tried it to wait for an agent and it failed schema validation because it was deferred; I didn't load it and just waited for the notification. The skill doesn't say how to wait.
2. **Reviewer wording:** the skill says the reviewer checks "only those fixes". The reviewer agent has no way to be told to run nothing, so I had to say "read-only" in the brief.
3. **Builder reached outside its brief:** it ran a bare `node --test` once, against the instruction to use `steelthread-verify`.
4. **Lint command:** the CLAUDE.md lint command lists `scripts/`, which doesn't exist until the seed slice. The builder had to be told to drop it. In my full run it passed anyway, because the pipeline's exit status comes from `xargs`, so a missing directory is silently ignored. CLAUDE.md also lists `node scripts/seed.js`, which doesn't exist yet.
5. **Builder in the same checkout:** the second builder was a fresh agent rather than a continuation of the first, since SendMessage is deferred. It cost context re-reading the files.
6. **Tick step:** the BSD `sed` form I used first (`0,/re/`) silently did nothing on macOS, so the commit went in with the box unticked. I caught it and amended. The skill gives no portable tick command.
7. **Migrate-fresh in CLAUDE.md:** the "Migrate a fresh database" command assumes `data/` exists, and no such directory exists in a fresh checkout. I added `mkdir -p data` myself.
8. **Architect:** it said it could not run Node, so its `node:sqlite` API details were unconfirmed; the builder had to check them. Nothing in the flow assigns that check.
9. **Quoting:** the architect's plan came back with HTML-escaped characters (`&lt;`, `&gt;`), which I had to clean up when saving it.
10. **"Next line" instruction:** the skill's "then start the next line" conflicted with your "stop after one line". I followed yours.
11. **Never started:** `steelthread:ui-designer` and the phase-end skills. The UI designer had no screen to work on. I found no failures in agent startup, paths or helper commands (`steelthread-verify` worked).

---

## What we changed after reading those flow notes

The notes are the session's own list of where the plugin was unclear. These led to
changes in this repository, made after the run and not yet rerun live:

| Note | Change |
|---|---|
| 2. Reviewer recheck wording | The feature skill now says the reviewer reads the fixes again without rerunning the tests |
| 3. Builder ran a bare test command | The builder's instructions now say every run goes through `steelthread-verify` |
| 4 and 7. Commands that name folders a later slice adds, or need a folder that does not exist | `new-project` now requires every command to run in a fresh checkout |
| 6. `sed` did not tick the box on macOS | The feature skill now says to tick with the Edit tool and look at the line before committing |
| 8. Nobody was assigned the architect's run-first checks | The feature skill now puts them in the builder's brief as its first step |
| 9. Escaped characters in the saved plan | The feature skill now says to put the real characters back |

Notes 1, 5 and 10 are about the headless test setup (tools that were not loaded, and our
instruction to stop after one line), not the plugin. Note 11 confirms nothing failed to
start.

---
name: least-trusted-audit
description: Build the per-role permission test harness and audit a project from the least-trusted role's point of view. Use when adding a project's first permission checks, whenever a slice adds a read, route or other entry point, and at the end of every phase before it is called done.
---

# Least-trusted audit

The rule this serves: permissions live in one place per domain, they are tested for every
role before the reads that depend on them, and the least-trusted role gets a test on every
new read. A leak is found by asking "what can the weakest role reach?", not "does the happy
path work?".

## Find the facts first

- The roles and the least-trusted one: the project's `CLAUDE.md`.
- The permission matrix (action × role → allow, own only, deny): `docs/ARCHITECTURE.md`.
  If there is no matrix, write it before any check. Anything not listed is denied.
- Where checks live: one module per domain, named in `CLAUDE.md`.

## The harness (built once, in Phase 0)

1. **Fixtures:** one user per role, plus a second tenant or owner with its own data. Leaks
   across tenants only show up when there is someone else's data to leak.
2. **Matrix test:** table-driven, one row per action × role, expected result taken from the
   matrix. Adding a role or an action without a row must fail the suite.
3. **Sign-in helper:** something like `as(role)` that returns a real authenticated client,
   so tests go through the same entry points users do.
4. **Guard test:** lists every entry point (routes, server actions, RPC methods, socket
   events) and fails when one has no permission check. New code is denied until listed.

## Every slice that adds a read

1. Add the action to the matrix. The matrix test goes red.
2. Write the check in the domain's permission module. The matrix test goes green.
3. Only then write the read, and add a test that calls the real entry point as the
   least-trusted role. Assert on the body, not just the status: the fields returned and the
   rows returned.
4. Check the side doors the read opens: lists and search, counts and totals, exports,
   realtime payloads, emails and notifications, AI tool results, error messages that reveal
   a record exists, and IDs in URLs (try a neighbour's ID).

## Phase-end audit

Sign in as the least-trusted role and walk everything. Work from a list, not from memory.

1. List every entry point by searching the code. Include background jobs a user can
   trigger and tools exposed to an AI.
2. For each one, record a row: entry point, where its check is, its scope filter, what the
   least-trusted role gets, the test that proves it.
3. Attack each one: another tenant's ID, another user's ID, a soft-deleted record, a
   record in a state the role should not see yet, bulk endpoints, paging past your own
   data.
4. Do a browser pass as that role: every navigation item, a pasted deep link to a screen
   the role should not have, and the empty states.
5. Every gap becomes a failing test first, then a fix, then a rerun.

Report: entry points found, how many have a least-trusted test, gaps found and fixed, and
anything not checked.

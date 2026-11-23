---
name: adopt-existing-project
description: Bring an existing codebase into the slice-by-slice build flow by recording it as it is. Use when /steelthread:new-project is run in a folder that already has code, or when a project has code but no CLAUDE.md, docs/FEATURES.md or permission matrix.
---

# Adopting an existing project

The documents record the project as it is. Adoption changes no application code, swaps no
part of the stack and refactors nothing. What is wrong becomes a line in the feature list.

## 1. Take inventory

Read, in this order, and note what you find with file paths:

1. The manifest and lockfile: language, framework, versions, scripts.
2. The top two levels of the folder layout.
3. The data model: schema files and migrations. Run the migration chain on an empty
   database if it is safe to, and note whether it works.
4. Auth and roles: how a user is identified, which roles exist, where a role is checked.
5. Entry points: routes, server actions, RPC methods, jobs, socket events.
6. Tests: which kinds exist, how they run, whether they pass now. Run them under
   `steelthread-lock`.
7. How it is run and deployed: env files (names only, never values), CI, hosting.

Do not read large files whole. Search for what each step needs.

## 2. Write the documents from what you found

- `CLAUDE.md`: the stack as it is, with real versions; the layout; the real commands. If
  one exists, keep it and add what is missing.
- `docs/ARCHITECTURE.md`: the data model from the schema, and the permission matrix as the
  code enforces it today. Mark every cell you could not confirm from a check in the code.
- `docs/FEATURES.md`: tick a line only when you saw it working: a passing test or an entry
  point you exercised. "The code is there" is not enough; leave it unticked and say why.
- `docs/DECISIONS.md`: choices you can see were made (stack, auth approach), dated today
  and marked as recorded after the fact.

## 3. Put the gaps into Phase 0

An adopted project gets a Phase 0 of hardening lines before new features, for whichever of
these are missing:

- The permission test harness and the guard test (see `steelthread:least-trusted-audit`).
- Permission checks gathered into one module per domain, where they are scattered.
- A least-trusted-role test for each existing read that returns another user's data.
- A migration chain that runs on an empty database.
- Seed data for every role.
- Lint and unit-test commands that pass, or a recorded list of what fails today.

## 4. Report before building

Show the owner: the stack found, the roles and the least-trusted one, what works today,
what could not be confirmed, and the Phase 0 list. Existing failures are reported as
found, not fixed during adoption.

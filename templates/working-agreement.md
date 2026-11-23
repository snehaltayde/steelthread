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

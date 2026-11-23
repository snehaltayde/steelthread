# Decisions

Choices made while turning the kit into a plugin. Newest first.

## 2026-11-24 The tests ship with the plugin, and the page quotes only them

- **Decision:** the script tests (`tests/run.sh`), the two live tests and the project the
  live test built (`examples/notes-api`) are in the repository. The README states only
  numbers these produce, and has a section for what has not been tested.
- **Why:** the owner asked for a page that shows real test numbers and how to repeat them.
  A comparison against Claude Code without the plugin was not run, so the page says so
  instead of claiming an improvement.
- **Decided by:** on the owner's behalf.

## 2026-11-24 Liveness is checked three ways

- **Decision:** `steelthread-lock` treats a pid as alive if `kill -0` succeeds, or
  `/proc/<pid>` exists, or `ps -p` finds it.
- **Why:** running the tests on Alpine showed BusyBox `ps` has no `-p`, so every live lock
  looked dead and was taken over. `kill -0` alone fails on another user's process.
- **Decided by:** on the owner's behalf.

## 2026-11-24 Commits carry a GitHub noreply address

- **Decision:** this repository's commits use the owner's GitHub noreply email.
- **Why:** the repository is public, and a personal address in the history cannot be
  taken back.
- **Decided by:** on the owner's behalf.

## 2026-11-23 Name: Steelthread

- **Decision:** the plugin, its marketplace and its commands are named `steelthread`.
- **Why:** "steel thread" is the engineering term for a thin end-to-end path through a
  system, which is what a slice is. A GitHub search found no notable project using it.
- **Instead of:** Ratchet (crowded: twbs/ratchet, huggingface/ratchet), Slipway (an AI
  coding workflow tool already uses it), Strake (an AI data company uses it).
- **Decided by:** on the owner's behalf. Trademark and X handle were not checked.

## 2026-11-23 The working agreement is copied into each project

- **Decision:** `/steelthread:new-project` appends `templates/working-agreement.md` to the
  project's `CLAUDE.md`.
- **Why:** a plugin cannot ship always-on instructions; a root `CLAUDE.md` in a plugin is
  not loaded. Copying also makes the rules travel with the repository.
- **Instead of:** a SessionStart hook injecting the agreement into every session, which
  would apply it to projects that never opted in.
- **Decided by:** on the owner's behalf.

## 2026-11-23 Commands are skills

- **Decision:** `new-project`, `feature` and `status` live in `skills/`. Only
  `new-project` has `disable-model-invocation: true`.
- **Why:** the Claude Code docs call `commands/` the older form and prefer skills.
  `feature` must stay loadable by Claude, because `new-project` hands over to it.
- **Decided by:** on the owner's behalf.

## 2026-11-23 One hook, and only for a rule a script can judge

- **Decision:** the only hook blocks killing processes by name pattern or port sweep.
- **Why:** it is the one rule in the agreement that can be checked from the command text
  alone. "Verified before done" and "one writer per checkout" are served by
  `steelthread-verify` and `steelthread-lock` instead of a hook that would guess.
- **Decided by:** on the owner's behalf.

## 2026-11-23 The lock is a directory, not `lockf` or `flock`

- **Decision:** `steelthread-lock` takes a lock by creating `/tmp/steelthread-heavy.lock`.
- **Why:** `lockf` exists only on macOS and `flock` only on Linux; `mkdir` is atomic on
  both. A lock whose wrapper and command have both died is taken over, one waiter at a
  time.
- **Decided by:** on the owner's behalf.

## 2026-11-23 One full test run per slice, owned by the session

- **Decision:** builders and the reviewer run lint and the slice's own tests; the session
  runs the full `steelthread-verify` once, after review, and only then ticks the box.
- **Why:** the independent review found three full runs per slice and a box ticked before
  verification.
- **Decided by:** on the owner's behalf.

## 2026-11-23 `frontend-design` is optional, not a declared dependency

- **Decision:** `ui-designer` loads the `frontend-design` skill if present and works from
  `docs/UI.md` alone if not.
- **Why:** it lives in another marketplace; a hard dependency could make the install fail.
- **Decided by:** on the owner's behalf.

## 2026-11-23 The old playbook is split into skills

- **Decision:** `build-playbook.md` is gone; its sections became `orchestrating-builds`,
  `migration-safety`, `verify-slice`, `least-trusted-audit` and `go-live`. Each project now
  keeps its own lessons in `docs/PLAYBOOK.md`, written by `phase-retro`.
- **Decided by:** on the owner's behalf.

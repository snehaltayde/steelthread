---
name: status
description: Report where a slice-by-slice build stands (phase progress, the next line, work in flight, recent decisions). For projects built with the steelthread flow (they have docs/FEATURES.md); use when the user asks where the build is, what is next, or what happened while they were away.
---

Report where this build stands. Read only; run nothing heavy and change nothing.

1. **Progress.** From `docs/FEATURES.md`, count ticked and total lines per phase. Name the
   current phase and the next unticked line. If the file is missing, say the project is not
   set up and point to `/steelthread:new-project`.
2. **In flight.** `git status --short`, the current branch, `git worktree list`, and
   branches not merged into the main branch. Say which slice each one belongs to if the
   name or the last commit makes it clear, and say so when it does not.
3. **Last verified state.** The most recent commit on the main branch and the line it
   ticked. Do not claim anything passes; say when it was last verified, if a report or
   commit message records it, or that it is not recorded.
4. **Decisions.** The three newest entries in `docs/DECISIONS.md`, with any made on the
   owner's behalf marked.
5. **Blocked or waiting.** Anything that needs the owner: an approval, an ambiguous
   requirement, a failing check that fixes did not clear.

Answer in this shape, in about ten lines:

- Phase table: phase, ticked / total.
- Next line.
- In flight (or "nothing").
- Waiting on you (or "nothing").

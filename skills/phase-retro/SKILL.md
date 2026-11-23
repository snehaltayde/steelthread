---
name: phase-retro
description: At the end of a phase, turn what went wrong and what worked into short rules in the project's docs/PLAYBOOK.md. Use when the last line of a phase is ticked, after a production incident, or when the same mistake has shown up in two slices.
---

# Phase retro

The point is that the next phase does not repeat this one's mistakes. The output is a few
rules in `docs/PLAYBOOK.md`, not a write-up.

## 1. Collect facts, not impressions

Look at what the phase left behind:

- `steelthread-verify` runs that failed, and what the cause turned out to be.
- Reviewer findings that came up in more than one slice.
- Tests that failed only in full runs, or only at certain times.
- Migrations that had to be renumbered or rewritten.
- Decisions in `docs/DECISIONS.md` that were reversed, and why.
- Slices that ran over the tool-call budget or had to be split, and what made them large.
- Anything that worked locally and failed in production.

If the facts are not recorded anywhere, say so; do not reconstruct them from memory.

## 2. Write at most five lessons

Each lesson is one line: the situation, then the rule.

```text
- Two branches added a migration in the same hour → the second branch renumbers and reruns
  the chain on an empty database before asking to merge.
```

A lesson earns its place when it would change what the next builder does. "Be more
careful" does not. If a lesson only restates a rule already in `CLAUDE.md`, the fix is
enforcement (a test, a guard, a hook), so add a line to `docs/FEATURES.md` for that
instead.

## 3. Put each lesson where it will be read

- A rule that must never be broken in this project goes into the project's `CLAUDE.md`
  under the non-negotiable rules, with a decision entry.
- Everything else goes into `docs/PLAYBOOK.md` under the heading it belongs to. Create the
  file from `${CLAUDE_PLUGIN_ROOT}/templates/PLAYBOOK.md` if it does not exist.

## 4. Prune

Keep `docs/PLAYBOOK.md` under about 80 lines. Before adding, merge lessons that say the
same thing, reword ones that proved too narrow, and delete ones that proved wrong or that
a test now enforces.

## 5. Report

In about five lines: the lessons added, the lessons removed, any rule promoted to
`CLAUDE.md`, and any lesson that looks true for every project, so the owner can decide
whether to carry it to their other projects.

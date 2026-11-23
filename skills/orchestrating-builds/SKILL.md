---
name: orchestrating-builds
description: Run a build of many slices with several agents, worktrees and a merge queue while keeping token usage down. Use when orchestrating more than one slice at a time, when writing briefs for builder agents, when merging parallel branches, or when a build is using too many tokens.
---

# Orchestrating a build of many slices

## Who does what

- One orchestrator session plans, briefs, verifies and merges. It is the only session that
  merges into the main branch.
- Builders work in git worktrees: one writer per checkout, each with its own branch,
  database name and ports. Two writers in one checkout overwrite each other.
- Running more slices side by side saves more time than more agents inside one slice.
  A line that depends on another line waits for it.
- An agent's report is a claim, not proof. Check the diff and rerun the suite before
  merging.

## Merge queue

One merge at a time, in this order:

1. A branch finishes its slice.
2. Bring the main branch into it.
3. Lint, the full unit suite and the migration chain on an empty database pass on the
   merged branch (`steelthread-verify`).
4. Fast-forward the main branch.

Conflicts in docs (`docs/FEATURES.md`, `docs/DECISIONS.md`) are resolved by keeping both
sides. Migration conflicts follow the `steelthread:migration-safety` skill.

## Heavy commands

Test suites, builds and migrations run through `steelthread-lock <command>`, or through
`steelthread-verify`, which takes the same lock. Without it, parallel test runs exhaust
database connections and produce failures that are not real.

Never free a port or stop a server by name pattern or port sweep. Each worktree keeps the
PID of what it started and stops exactly that.

## Keeping usage down

The cost in a long build comes from agents re-reading large context: a few big documents
read by most agents, repeated architect and reviewer runs, and thousands of test runs.

- One small plan file per phase, which every agent in that phase reads, instead of a fresh
  plan per agent.
- Briefs name exact files. Agents search large docs for the part they need and do not read
  them whole.
- About 150 tool calls per agent. An agent that runs out reports where it stopped.
- During the build, builders and the reviewer run only the slice's own test files. The
  orchestrator does the one full run per slice, on the merged branch.
- One review per slice, then a recheck of the fixes only.
- Reports of about ten lines.
- Use the cheaper model for docs, seed data, guard tests and mechanical merges.

## A brief that works

```text
Slice: <the docs/FEATURES.md line>
Plan: docs/plans/phase-<n>.md, section <name>
Your work package: <exact files to create or change>
Read first: <exact files, and the section of each>
Do not touch: <files owned by another package>
Worktree: <path>   Branch: <name>   Database: <name>   Ports: <numbers>
Done means: <the feature-list items in this package>, steelthread-verify passing
Budget: about 150 tool calls. Report in about ten lines: built, verified, not verified, left.
```

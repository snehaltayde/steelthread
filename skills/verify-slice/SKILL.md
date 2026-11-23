---
name: verify-slice
description: Run the checks that let a slice be called done (lint, full unit suite, migrations on a fresh database, the slice's browser spec) under the machine-wide lock, and report the real results. For projects built with the steelthread flow (they have docs/FEATURES.md); use after coding a slice, before a merge, and when a test fails only in full runs.
---

# Verify a slice

Nothing is called working unless it was run. This skill is how it gets run and how the
result is reported.

## Run it

Take the commands from the project's `CLAUDE.md` and pass them to `steelthread-verify`,
which the plugin puts on the PATH:

```bash
steelthread-verify \
  --step lint    "<lint command>" \
  --step unit    "<full unit suite>" \
  --step migrate "<migrate an empty database>" \
  --step browser "<this slice's browser spec only>"
```

- It takes the machine-wide lock, runs every step even after a failure, prints one table,
  shows the last 30 lines of each failing log and exits non-zero if anything failed.
- A check that does not apply is declared, not dropped: `--skip browser "no screen in this
  slice"`. It then appears in the report as NOT RUN.
- The slice runs only its own browser spec. The full browser suite runs once at the end of
  a phase.
- The migrate step must start from an empty database and run the whole chain.
- Any other heavy command goes through the same lock: `steelthread-lock <command>`.
- Suites, and waiting for the lock, often take longer than the Bash tool's default
  timeout. Run `steelthread-verify` in the background, or with the longest timeout the
  tool allows, and wait for its report. A run that is cut off prints no report; do not
  start a second one because the first is quiet.
- Who runs what: a builder runs lint and the slice's own test files; the session runs the
  full set once per slice, after review.

## Report it

Paste the table as printed. Then say in plain words what failed and what was not verified.
Do not turn a FAIL into "mostly passing", and do not report a step you did not run.

## When a check fails

- **Fails alone and in the full run:** it is a real failure. Fix the code, not the test,
  unless the test asserts something the plan does not ask for.
- **Fails only in the full run:** almost always shared state, such as a shared mailbox, a
  row another test left behind, or event order. Find which earlier test it needs by
  running the suite up to it. Report it every time until the cause is found; never retry
  it into passing.
- **Fails only at certain times:** the test depends on today's date or the hour. Pin the
  clock in the test. Week and month rollovers are the usual trigger.
- **Browser failures on a laptop:** a machine on battery or under load produces false
  timeouts. Plug in, make sure nothing else is running under the lock, and rerun once. If
  it fails again, it is real.
- **Database connection errors in a parallel build:** two suites ran at once. Something
  bypassed `steelthread-lock`.

One round of fixes, then run the whole thing again. If it still fails, stop and report.

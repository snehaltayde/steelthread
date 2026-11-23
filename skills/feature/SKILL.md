---
name: feature
description: Build one feature slice end to end (plan, build, design, review, verify), then carry on with the next line. Only for a project set up with /steelthread:new-project (it has docs/FEATURES.md); use when the user runs /steelthread:feature or when that flow moves on to its next line.
argument-hint: <line from docs/FEATURES.md, or a described change>
---

Feature to build: $ARGUMENTS

1. Find it in `docs/FEATURES.md` (add a line if it is new work). If something it depends on
   is not built, say so and build that first. If the project has no `docs/FEATURES.md`,
   stop and tell me to run `/steelthread:new-project` first.
2. Use the **steelthread:architect** agent for the feature list, design and file plan. Take
   its recommendations as approved and record them in `docs/DECISIONS.md`; do not wait for
   me. The architect cannot write files, so save its plan yourself as a section of
   `docs/plans/phase-<n>.md` (one file per phase); every later agent reads it from there.
   If the plan came back with escaped characters (`&lt;`, `&gt;`), put the real ones back.
   Checks the architect listed for running first go into the builder's brief as its
   first step.
   If builders will work in worktrees, commit the plan file first so each worktree has it.
3. Use the **steelthread:feature-builder** agent to implement the plan (several at once only
   on disjoint files, each in its own worktree). The builder runs lint and this slice's own
   tests, not the full suite.
4. Use the **steelthread:ui-designer** agent for any new or changed screen.
5. Use the **steelthread:reviewer** agent on the result, including files not yet committed.
   Fix every leak, integrity and missing-feature finding, then have the reviewer read
   only those fixes again, without rerunning the tests.
6. Verify with `steelthread-verify`, taking the commands from the project's `CLAUDE.md`:
   lint, the full unit suite, the migrations on a fresh database, and the slice's own
   browser spec. A check that does not apply is passed as `--skip` with the reason. This is
   the slice's one full run, and it is the proof; an agent's report is only a claim.
7. Only now tick the checkbox, update `docs/DECISIONS.md`, and commit with a conventional
   message. Tick with the Edit tool (change the line's `- [ ]` to `- [x]`), not with
   `sed`, which behaves differently on macOS and Linux, and look at the line before you
   commit. No agent ticks the box.

Briefs to agents name the exact files to read and change, cap the agent at about 150 tool
calls and ask for a report of about ten lines. The builder's brief gives it the exact
`steelthread-verify` command for its own checks, so it does not run them some other way.

Finish with: what was built, the decisions made on my behalf (schema and permission
decisions first), the `steelthread-verify` report, what was not verified, and the one thing
I should click through myself.

Then start the next line in order, unless one of these holds:

- I have said to stop.
- Verification failed and one round of fixes did not clear it: stop and report.
- This was the last line of a phase. Before the next phase, run the full browser suite,
  the phase-end audit from the `steelthread:least-trusted-audit` skill, and the
  `steelthread:phase-retro` skill, then report the phase and continue.
- The next step is one I asked to approve first: deleting or re-seeding data, a first
  push, a first production deploy, anything that costs money or cannot be undone.

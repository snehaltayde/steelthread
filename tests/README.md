# Tests

Three tests, from free and exact to live and approximate.

| Test | Needs | Uses your Claude account | Time |
|---|---|---|---|
| [`run.sh`](run.sh) | bash, jq, perl, python3 | No | About 2 minutes |
| [`live-smoke.sh`](live-smoke.sh) | the `claude` CLI, jq, git | Yes, capped at 1 US dollar (ours: about 10 cents) | About 10 seconds |
| [`live-slice.sh`](live-slice.sh) | the `claude` CLI, jq, git, a Node with `node:sqlite` (we used 26) | Yes, capped at 13 US dollars (ours: about 2 US dollars) | About 7 minutes |

Each script exits 0 only when every check passes, and prints one line per failed check.

## `run.sh`: the script tests

```bash
bash tests/run.sh
```

It runs the two helpers and the hook directly, in a temp folder with its own lock
directory, so it does not touch a lock that a real session is holding. It ends with a
summary like this:

```text
steelthread script tests on Darwin arm64, bash 3.2.57, awk version 20200816
  lock: one heavy command at a time         25 / 25
  lock: 12 waiters race for a dead lock      8 / 8
  verify: the honest report                 16 / 16
  hook: pattern kills it must block         42 / 42
  hook: ordinary commands it must allow     33 / 33
  hook: machines without jq or python3      17 / 17
  ---------------------------------------------------
  total                                    141 / 141
  hook time per Bash call: about 8 ms (average of 50)
```

To run it on Linux from a Mac, with Docker:

```bash
docker run --rm -v "$PWD":/kit:ro ubuntu:24.04 bash -c 'apt-get update -qq && apt-get install -y -qq jq perl python3 procps >/dev/null && bash /kit/tests/run.sh'
```

Swap in `ubuntu:26.04` to test against the Rust core utilities.

```bash
docker run --rm -v "$PWD":/kit:ro alpine:3.20 sh -c 'apk add -q bash jq perl python3 && bash /kit/tests/run.sh'
```

What the groups cover:

- **Lock, one at a time (25).** A command runs and its exit code comes back. A second
  command waits for the first. A lock whose holder died is taken over; a lock whose holder
  is alive, even another user's process, is not, and the waiter times out with exit 75.
  TERM stops the command and everything it started, then frees the lock. If the wrapper is
  killed outright, the lock stays held until the command it started has ended.
- **Lock, the race (8).** Eight rounds. In each, 12 commands start together against a lock
  left by a dead process. Each writes a start mark and an end mark; the round passes only
  if the marks strictly alternate, which means no two commands ever ran at once. This is
  the test that caught a `mkdir` that is not exclusive on Ubuntu 26.04.
- **Verify (16).** All steps run even after one fails. One failure makes the exit code 1
  and the verdict FAILED. A skipped step is listed as NOT RUN and named in the verdict.
  The last lines of a failing step's log are printed. Wrong arguments fail at once instead
  of waiting for the lock.
- **Hook, must block (42).** Each entry is a command Claude might write to free a port or
  stop a server by name. All must be refused with exit 2.
- **Hook, must allow (33).** Ordinary commands, including ones that only mention `pkill`
  in a commit message, a `grep` pattern, a comment or a note written with a heredoc, plus
  the off switch and empty input. All must pass with exit 0.
- **Hook without jq or python3 (17).** The same decisions when the hook has only sed and
  awk to read its input, and when `python3` exists but is broken.

Found a command the hook gets wrong? Add it to the `blocked` or `allowed` list in
`run.sh` and open a pull request or an issue.

## `live-smoke.sh`: does the plugin load?

```bash
bash tests/live-smoke.sh
```

Starts one headless session (`claude -p --plugin-dir <this repository>`) in a new temp
folder and asks it to list the plugin's agents and skills, run `steelthread-verify`, try a
`pkill` on a process name that does not exist, and locate the helpers. The script then
looks for 18 things in the reply. The session loads only this plugin and no user settings
(`--setting-sources project,local`), so your other plugins do not affect the result.

If `claude` is not on your PATH, point at it:

```bash
CLAUDE_BIN=/path/to/claude bash tests/live-smoke.sh
```

## `live-slice.sh`: one feature, built for real

```bash
bash tests/live-slice.sh
```

Pass a folder to keep the result somewhere you choose: `bash tests/live-slice.sh ~/steelthread-run`.

1. Session one runs `/steelthread:new-project` for a small notes API (roles: admin, member,
   guest; Node built-in modules only, so nothing is installed). It writes the documents
   and stops.
2. Session two gives the go-ahead and runs `/steelthread:feature` for the first line of
   Phase 0, then stops after that one line.
3. The script checks the project from outside: files, commits, the ticked line, the
   working agreement, and `node --test`.

The session model defaults to `sonnet`; set `STEELTHREAD_TEST_MODEL` to change it. The
`feature-builder` agent runs on `opus` either way, and that is most of the cost.

This is one run of a model, not a benchmark. Two runs produce different code, and a check
can fail because the model took a different, reasonable path (for example a different
folder name for permission rules). Read the failed line and the session's report before
calling it a bug. The report is in the JSON the script names at the end:

```bash
jq -r .result <work-folder>/2-feature.json
```

Our run, its numbers and the project it produced are in [`../examples`](../examples).

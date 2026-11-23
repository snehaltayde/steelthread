#!/usr/bin/env bash
# Live slice test: have a real, headless Claude Code session set up a small project with
# /steelthread:new-project and build its first feature line with /steelthread:feature,
# then check the result from outside the session.
#
#   bash tests/live-slice.sh [work-folder]
#
# This uses your Claude account: two sessions, capped at 3 and 10 US dollars (see
# examples/README.md for what ours cost). The project is a notes API on Node's built-in
# modules, so nothing is installed or downloaded. Model output varies from run to run:
# expect the same shape, not the same code.
# Needs: the `claude` CLI (or CLAUDE_BIN=/path/to/claude), jq, git and a Node that has
# node:sqlite built in (we used Node 26). STEELTHREAD_TEST_MODEL picks the session model (default: sonnet);
# the feature-builder agent runs on opus whatever you choose.
KIT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${CLAUDE_BIN:-claude}"
MODEL="${STEELTHREAD_TEST_MODEL:-sonnet}"
command -v "$CLAUDE" >/dev/null 2>&1 || { echo "claude CLI not found. Install Claude Code, or set CLAUDE_BIN to its path." >&2; exit 2; }
for need in jq git node; do command -v "$need" >/dev/null 2>&1 || { echo "this test needs $need" >&2; exit 2; }; done
node -e "require('node:sqlite')" 2>/dev/null || { echo "this test needs a Node with node:sqlite built in" >&2; exit 2; }

tmp="${TMPDIR:-/tmp}"; W="${1:-$(mktemp -d "${tmp%/}/steelthread-slice.XXXXXX")}"
mkdir -p "$W/notes-api" && W="$(cd "$W" && pwd)" || exit 2
P="$W/notes-api"
[ -z "$(ls -A "$P")" ] || { echo "$P is not empty; give an empty work folder" >&2; exit 2; }
cd "$P" && git init -q . || exit 2

# run <name> <budget> <tools...> -- <prompt>
# Saves the event stream (<name>.jsonl), everything the session said (<name>.report.md)
# and the closing figures (<name>.json). ScheduleWakeup is off so a headless session ends
# when its work does instead of waiting on a timer.
total_s=0
run() {
  name="$1"; budget="$2"; shift 2; tools=()
  while [ "$1" != "--" ]; do tools+=("$1"); shift; done; shift
  echo "[$(date +%H:%M:%S)] $name ..."
  t0=$(date +%s)
  "$CLAUDE" -p --plugin-dir "$KIT" --setting-sources project,local --model "$MODEL" \
    --permission-mode acceptEdits --allowedTools "${tools[@]}" --disallowedTools ScheduleWakeup \
    --output-format stream-json --verbose --max-budget-usd "$budget" "$1" \
    < /dev/null > "$W/$name.jsonl" 2> "$W/$name.stderr.txt"
  secs=$(( $(date +%s) - t0 )); total_s=$((total_s + secs))
  jq -rs '[.[] | select(.type == "assistant" and .parent_tool_use_id == null) | .message.content[]? | select(.type == "text") | .text] | join("\n\n")' "$W/$name.jsonl" > "$W/$name.report.md" 2>/dev/null
  jq -s '[.[] | select(.type == "result")] | last' "$W/$name.jsonl" > "$W/$name.json" 2>/dev/null
  jq -r --arg s "$secs" '"           \($s) s, about \(.total_cost_usd * 100 | round / 100) US dollars, error: \(.is_error)"' "$W/$name.json" 2>/dev/null
}

run 1-new-project 3 Bash Read Write Edit Glob Grep Skill -- "/steelthread:new-project A tiny JSON API for shared team notes. Answers to your questions, up front, so do not ask any: Roles are admin, member and guest; guest is the least trusted and may only read notes marked public. It must do: sign in with a token, create a note, list notes, mark a note public, delete a note (admin only). It must never show a private note to a guest. It runs locally only. Stack I insist on: Node with built-in modules only (node:http, node:sqlite, node:test), no npm dependencies, nothing installed or downloaded, no screens and no UI. Keep the feature list short: Phase 0 plus one Phase 1. The first line of Phase 0 must be this slice: any of the three roles can send its token to GET /me and get its own name and role back, and a missing or unknown token gets 401 on every route. Write the documents and stop at the summary; I will give the go-ahead later."

run 2-feature 10 Bash Read Write Edit Glob Grep Skill Agent -- "/steelthread:feature the first unticked line of Phase 0 in docs/FEATURES.md --- Go-ahead given for Phase 0: first commit the project documents as the project's first commit, as the new-project flow says. This is a test run of the flow itself: build only this one line, then stop and give the finishing report; do not start the next line. Do not install or download anything. At the very end add a section titled FLOW NOTES listing, literally, every place where the steelthread instructions, agents, skills or helper commands were unclear, wrong, missing or failed (for example an agent type that would not start, a path that did not exist, a helper that errored), or say none."

# ---- checks made from outside the session
pass=0; fail=0
check() { if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); echo "  PASS  $1"; else fail=$((fail+1)); echo "  FAIL  $1"; fi; }
cd "$P"
echo
echo "Checks on $P"
check "both sessions finished without an error" '[ "$(jq -r .is_error "$W/1-new-project.json")" = false ] && [ "$(jq -r .is_error "$W/2-feature.json")" = false ]'
for f in CLAUDE.md docs/ARCHITECTURE.md docs/FEATURES.md docs/DECISIONS.md docs/PLAYBOOK.md; do check "$f was written" "[ -s '$f' ]"; done
check "CLAUDE.md holds the working agreement, unchanged" 'diff <(sed -n "/^# Working agreement: how software is built here/,\$p" CLAUDE.md) "$KIT/templates/working-agreement.md"'
check "the plan was saved to docs/plans/phase-0.md" '[ -s docs/plans/phase-0.md ]'
check "exactly one feature line is ticked" '[ "$(grep -c "^- \[x\]" docs/FEATURES.md)" -eq 1 ]'
check "the documents were committed before the feature" '[ "$(git rev-list --count HEAD)" -ge 2 ] && git show --stat --format= "$(git rev-list --max-parents=0 HEAD)" | grep -q "docs/FEATURES.md"'
check "nothing is left uncommitted" '[ -z "$(git status --porcelain)" ]'
check "a migration was written" 'ls migrations/*'
check "permission rules have a file of their own" 'find src -ipath "*permission*" -type f | grep -q .'
check "the tests name all three roles" 'grep -rlq admin test && grep -rlq member test && grep -rlq guest test'
check "the tests cover a request with no token (401)" 'grep -rq 401 test'
check "architect, feature-builder and reviewer each ran" '[ "$(jq -r "[.subagent_stats.by_type | has(\"steelthread:architect\"), has(\"steelthread:feature-builder\"), has(\"steelthread:reviewer\")] | all" "$W/2-feature.json")" = true ]'
check "the session ran steelthread-verify" 'jq -rs "[.[] | select(.type == \"assistant\" and .parent_tool_use_id == null) | .message.content[]? | select(.type == \"tool_use\") | .input.command // empty] | join(\"\n\")" "$W/2-feature.jsonl" | grep -q steelthread-verify'
check "the report says what was not verified" 'grep -qi "not verified" "$W/2-feature.report.md"'
check "the report lists decisions made on your behalf" 'grep -qi "decisions" "$W/2-feature.report.md"'
node --test > "$W/node-test.txt" 2>&1; t=$?
check "the project's tests pass when run from outside (node --test)" "[ $t -eq 0 ]"
grep -E '^(ℹ|#) (tests|pass|fail) ' "$W/node-test.txt" | sed 's/^/           /'

echo
jq -rs --arg s "$total_s" '"  total: about \(map(.total_cost_usd) | add * 100 | round / 100) US dollars, \($s) s"' "$W/1-new-project.json" "$W/2-feature.json" 2>/dev/null
echo "  the project:           $P"
echo "  the finishing report:  $W/2-feature.report.md"
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]

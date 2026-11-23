#!/usr/bin/env bash
# Live smoke test: load the plugin into a real, headless Claude Code session and check
# that its agents, skills, helpers and hook are all there and working.
#
#   bash tests/live-smoke.sh
#
# This uses your Claude account: one short session, capped at 1 US dollar (ours cost
# about 0.07). It works in a new temp folder and changes nothing else.
# Needs: the `claude` CLI (or CLAUDE_BIN=/path/to/claude), jq and git.
# STEELTHREAD_TEST_MODEL picks the model (default: sonnet).
KIT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${CLAUDE_BIN:-claude}"
MODEL="${STEELTHREAD_TEST_MODEL:-sonnet}"
command -v "$CLAUDE" >/dev/null 2>&1 || { echo "claude CLI not found. Install Claude Code, or set CLAUDE_BIN to its path." >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "this test needs jq" >&2; exit 2; }

tmp="${TMPDIR:-/tmp}"; W=$(mktemp -d "${tmp%/}/steelthread-smoke.XXXXXX")
cd "$W" && git init -q . || exit 2
echo "Running a headless Claude Code session with the plugin from $KIT ..."

"$CLAUDE" -p --plugin-dir "$KIT" --setting-sources project,local --model "$MODEL" \
  --allowedTools "Bash" --output-format json --max-budget-usd 1 \
  "This is a smoke test of a plugin called steelthread. Do exactly these four things and report each result literally, without fixing anything:
1. List every skill and every agent type available to you whose name starts with 'steelthread:'.
2. Run this in Bash and paste its full output and exit code: steelthread-verify --step a \"true\" --skip b \"live test\"
3. Run this in Bash and paste exactly what came back (output, error or block message): pkill -f steelthread-no-such-process-xyz
4. Run this in Bash and paste the output: which steelthread-lock steelthread-verify" \
  < /dev/null > "$W/result.json" 2> "$W/stderr.txt"
code=$?
result=$(jq -r '.result // ""' "$W/result.json" 2>/dev/null)

pass=0; fail=0
check() { if [ "$2" = "yes" ]; then pass=$((pass+1)); echo "  PASS  $1"; else fail=$((fail+1)); echo "  FAIL  $1"; fi; }
has() { printf '%s' "$result" | grep -q -e "$1" && echo yes || echo no; }
# The exact name, not a longer one that starts the same way (feature / feature-builder).
named() { printf '%s' "$result" | grep -q -e "steelthread:$1\([^a-z-]\|\$\)" && echo yes || echo no; }

echo
check "the session finished without an error" "$([ "$code" -eq 0 ] && [ "$(jq -r '.is_error' "$W/result.json" 2>/dev/null)" = "false" ] && echo yes || echo no)"
for a in architect feature-builder reviewer ui-designer; do check "agent steelthread:$a is registered" "$(named "$a")"; done
for s in feature status least-trusted-audit verify-slice orchestrating-builds migration-safety slice-writing adopt-existing-project go-live phase-retro; do
  check "skill steelthread:$s is loadable" "$(named "$s")"
done
check "steelthread-verify ran and reported the skipped step" "$(has 'VERDICT: PASSED (1 step), 1 NOT VERIFIED')"
check "the hook blocked pkill" "$(has 'by name or by port sweep is not allowed')"
check "both helpers are on the PATH" "$([ "$(has 'bin/steelthread-lock')" = yes ] && [ "$(has 'bin/steelthread-verify')" = yes ] && echo yes || echo no)"

echo
jq -r '"  session: \(.num_turns) turns, \((.duration_ms / 1000) | floor) s, about \(.total_cost_usd * 100 | round) US cents"' "$W/result.json" 2>/dev/null
echo "  full reply and raw JSON: $W/result.json"
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]

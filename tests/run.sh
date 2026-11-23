#!/usr/bin/env bash
# Steelthread's script tests: the lock, the verify report and the kill hook.
# No Claude session and no network are needed, and nothing outside a temp folder is touched.
#
#   bash tests/run.sh
#
# Needs: bash, jq, perl, python3 and the usual ps/find/sed/awk. Takes about a minute.
# Exit 0 when every check passes.
KIT="$(cd "$(dirname "$0")/.." && pwd)"
for need in jq perl python3 find awk sed; do
  command -v "$need" >/dev/null 2>&1 || { echo "tests/run.sh needs '$need' on the PATH" >&2; exit 2; }
done

tmp="${TMPDIR:-/tmp}"; T=$(mktemp -d "${tmp%/}/steelthread-tests.XXXXXX"); mkdir "$T/locks"
trap 'rm -rf "$T"' EXIT
export STEELTHREAD_LOCK_DIR="$T/locks"
unset STEELTHREAD_LOCK_HELD STEELTHREAD_ALLOW_PATTERN_KILL
LK="$T/locks/steelthread-heavy.lock"
L="$KIT/bin/steelthread-lock"; V="$KIT/bin/steelthread-verify"; H="$KIT/hooks/no-pattern-kill.sh"

pass=0; fail=0; gpass=0; gfail=0; gname=""; summary=""
flush() { [ -n "$gname" ] && summary="$summary$(printf '  %-40s %3d / %d' "$gname" "$gpass" "$((gpass + gfail))")
"; }
group() { flush; gname="$1"; gpass=0; gfail=0; echo "== $1"; }
ok() {
  if [ "$2" = "$3" ]; then pass=$((pass+1)); gpass=$((gpass+1))
  else fail=$((fail+1)); gfail=$((gfail+1)); echo "FAIL $1 (got '$2', want '$3')"; fi
}

# ---------------------------------------------------------------- steelthread-lock
group "lock: one heavy command at a time"
ok "runs command" "$("$L" echo hi)" "hi"
"$L" bash -c 'exit 7'; ok "passes exit code" "$?" "7"
[ -e "$LK" ]; ok "released after run" "$?" "1"
"$L" 2>/dev/null; ok "usage error" "$?" "64"
"$L" -t abc true 2>/dev/null; ok "-t abc rejected" "$?" "64"
ok "re-entrant" "$("$L" -- "$L" echo nested)" "nested"
ok "stdin passes through" "$(echo piped | "$L" cat)" "piped"
: > "$T/order.txt"
"$L" bash -c "echo A-start >> '$T/order.txt'; sleep 3; echo A-end >> '$T/order.txt'" & p1=$!; sleep 1
"$L" bash -c "echo B-start >> '$T/order.txt'; echo B-end >> '$T/order.txt'" 2>/dev/null & p2=$!; wait $p1 $p2
ok "serializes" "$(tr '\n' ' ' < "$T/order.txt")" "A-start A-end B-start B-end "
echo 999999 > "$LK"
ok "stale lock taken over" "$("$L" -t 10 echo took-over 2>/dev/null)" "took-over"
# A live holder owned by someone else (pid 1) must not be stolen.
echo 1 > "$LK"
"$L" -t 2 echo nope >/dev/null 2>&1; ok "pid 1 holder not stolen, times out" "$?" "75"
[ -f "$LK" ]; ok "pid 1 lock still there" "$?" "0"
rm -rf "$LK"
# STEELTHREAD_LOCK_HELD inherited from an unrelated holder must not skip the lock.
echo $$ > "$LK"
STEELTHREAD_LOCK_HELD=424242 "$L" -t 2 echo nope >/dev/null 2>&1; ok "stale HELD env does not bypass" "$?" "75"
rm -rf "$LK"
# A missing lock directory fails at once with 73.
t0=$(date +%s); STEELTHREAD_LOCK_DIR="$T/nope" "$L" echo x >/dev/null 2>&1; c=$?
ok "missing lock dir exits 73" "$c" "73"; ok "missing lock dir fails fast" "$(( $(date +%s) - t0 < 3 ))" "1"
# TERM: the lock is released promptly and the command is stopped.
"$L" bash -c "echo \$\$ > '$T/child.pid'; sleep 30" & hp=$!; sleep 1; t0=$(date +%s); kill -TERM $hp; wait $hp 2>/dev/null; c=$?
ok "TERM exit code 143" "$c" "143"
ok "TERM is prompt" "$(( $(date +%s) - t0 < 5 ))" "1"
[ -e "$LK" ]; ok "released on TERM" "$?" "1"
sleep 1; kill -0 "$(cat "$T/child.pid")" 2>/dev/null; ok "child stopped on TERM" "$?" "1"
# KILL of the wrapper: the command keeps running, so the lock must stay held.
"$L" sleep 6 & hp=$!; sleep 1; kill -KILL $hp; wait $hp 2>/dev/null
"$L" -t 2 echo nope >/dev/null 2>&1; ok "lock held while orphaned command runs" "$?" "75"
ok "lock freed after orphan exits" "$("$L" -t 15 echo freed 2>/dev/null)" "freed"
# TERM through verify must stop the running step (a compound command with a grandchild).
"$V" --step slow "echo \$\$ > '$T/step.pid'; sleep 30; echo done > '$T/step.done'" >/dev/null 2>&1 & vp=$!; sleep 2
kill -TERM $vp; wait $vp 2>/dev/null; sleep 1
kill -0 "$(cat "$T/step.pid")" 2>/dev/null; ok "TERM through verify stops the step" "$?" "1"
[ -e "$T/step.done" ]; ok "stopped step did not finish" "$?" "1"
[ -e "$LK" ]; ok "lock released after TERM through verify" "$?" "1"
# A directory at the lock path (not a lock file).
mkdir "$LK"; "$L" -t 5 echo x >/dev/null 2>&1; ok "directory at lock path exits 73" "$?" "73"; rmdir "$LK"
# --locked typed by hand still takes the lock.
echo $$ > "$LK"
out=$(env -u STEELTHREAD_LOCK_HELD "$V" --locked --step a true 2>&1 & vp=$!; sleep 2; kill -TERM $vp 2>/dev/null; wait $vp 2>/dev/null; echo "code:$?")
ok "hand-typed --locked waits for the lock" "$(echo "$out" | grep -c 'waiting for pid')" "1"; rm -rf "$LK"

group "lock: 12 waiters race for a dead lock"
# 8 rounds, 12 waiters each on a dead holder's lock. Each round must run strictly one at a time.
for r in 1 2 3 4 5 6 7 8; do
  rm -rf "$LK" "$LK.takeover"; echo 999999 > "$LK"; : > "$T/race.txt"
  for w in 1 2 3 4 5 6 7 8 9 10 11 12; do
    "$L" -t 60 bash -c "echo s >> '$T/race.txt'; perl -e 'select(undef,undef,undef,0.05)'; echo e >> '$T/race.txt'" 2>/dev/null &
  done; wait
  ok "round $r: no two commands overlap" "$(tr -d '\n' < "$T/race.txt")" "sesesesesesesesesesesese"
done

# -------------------------------------------------------------- steelthread-verify
group "verify: the honest report"
out=$("$V" --step a "true" --step b "echo fine" 2>/dev/null); ok "all pass exit 0" "$?" "0"
ok "verdict passed" "$(echo "$out" | grep -c 'VERDICT: PASSED (2 steps)\.')" "1"
out=$("$V" --step lint "true" --step unit "echo boom-marker; exit 3" --step after "true" --skip browser "no screen" 2>/dev/null); ok "failure exit 1" "$?" "1"
ok "shows FAIL(3)" "$(echo "$out" | grep -c '^FAIL(3)  *unit')" "1"
ok "ran step after failure" "$(echo "$out" | grep -c '^PASS  *after')" "1"
ok "lists NOT RUN" "$(echo "$out" | grep -c '^NOT RUN  *browser .*no screen')" "1"
ok "failing log tail" "$(echo "$out" | sed -n '/^--- unit: last 30 lines/,$p' | grep -c '^boom-marker$')" "1"
ok "verdict failed" "$(echo "$out" | grep -c 'VERDICT: FAILED (1 of 3 steps failed, 1 not run)')" "1"
out=$("$V" --step only "true" --skip browser "no screen" 2>/dev/null)
ok "skipped step shows in the verdict" "$(echo "$out" | grep -c 'VERDICT: PASSED (1 step), 1 NOT VERIFIED')" "1"
out=$("$V" --step t "echo first-out; exit 1" --step t "echo second-out; exit 1" 2>/dev/null)
ok "duplicate names keep separate logs" "$(echo "$out" | grep -c -e '^first-out$' -e '^second-out$')" "2"
"$V" >/dev/null 2>&1; ok "no args usage" "$?" "64"
"$V" --skip only "x" >/dev/null 2>&1; ok "skip-only usage" "$?" "64"
echo $$ > "$LK"; t0=$(date +%s); "$V" --bogus >/dev/null 2>&1; c=$?; rm -rf "$LK"
ok "bad arg is usage error without waiting for the lock" "$c:$(( $(date +%s) - t0 < 2 ))" "64:1"
ok "nested verify works" "$("$V" --step outer "'$V' --step inner true" 2>/dev/null | grep -c '^PASS  *outer')" "1"
ok "step stdin is closed" "$(echo data | "$V" --step s 'cat; true' 2>/dev/null | grep -c '^PASS')" "1"
[ -e "$LK" ]; ok "verify released lock" "$?" "1"

# ------------------------------------------------------------------------ the hook
hook() { printf '{"tool_name":"Bash","tool_input":{"command":%s,"description":"Kill stuff with pkill"}}' "$(printf '%s' "$1" | jq -Rs .)" | "$H" >/dev/null 2>&1; echo $?; }

group "hook: pattern kills it must block"
blocked=( 'pkill -f node' 'killall node' 'sudo pkill -9 postgres' 'sudo -u postgres pkill -9 postgres' 'kill -9 $(lsof -ti:3000)' 'kill -9 "$(lsof -ti :3000)"'
 'lsof -ti:3000 | xargs kill -9' 'npm test; pkill vite' 'kill `pgrep node`' 'npx kill-port 3000' 'npx -y kill-port 3000' 'pnpm dlx kill-port 5173'
 'fuser -k 3000/tcp' 'pgrep -f next | xargs kill' 'cd app && killall -9 node' 'PID=$(lsof -ti:3000); kill -9 $PID' 'pids=$(pgrep -f vite); kill $pids'
 "ps aux | grep vite | awk '{print \$2}' | xargs kill -9" 'for p in $(pgrep node); do kill $p; done' '/usr/bin/pkill -f node' 'PORT=3000 pkill -f vite'
 'STEELTHREAD_ALLOW_PATTERN_KILL=1 pkill -f vite' 'env pkill node' 'command pkill node' 'nohup pkill node' 'timeout 5 pkill node'
 'if true; then pkill node; fi' '{ pkill node; }' 'bash -c "pkill -f node"' "sh -c 'killall node'" 'fkill :3000' 'lsof -ti:3000 | xargs -n1 kill'
 $'npm test\npkill -f vite' $'bash <<EOF\npkill -f node\nEOF' $'cat <<EOF | sh\nkillall node\nEOF' 'eval "pkill -f node"' 'npx kill-port@latest 3000'
 'npx fkill-cli :3000' 'timeout -s KILL 5 pkill node' 'kill $(ps aux | grep vite | awk "{print 1}")' 'case $1 in stop) pkill node ;; esac' 'kill -9 $PID $(lsof -ti:3000)' )
for c in "${blocked[@]}"; do ok "blocks: $c" "$(hook "$c")" "2"; done

group "hook: ordinary commands it must allow"
allowed=( 'kill 12345' 'kill -TERM "$(cat .pid)"' 'kill -0 $PID && echo alive' 'grep -rn pkill docs/' 'echo "do not use killall"' 'lsof -i :3000' 'pgrep -f next'
 'npm run skill-check' 'npx playwright test' 'docker exec db psql -c "select 1"' 'git commit -m "remove pkill usage"'
 'lsof -i :3000 | grep LISTEN || echo "nothing to kill"' 'lsof -i :3000 | tee skills.txt' 'pgrep -l node | grep -v skill'
 'pidof nginx | xargs echo "would kill"' 'grep -rnE "pkill|killall " .' "grep -c 'pkill; kill' notes.md"
 $'git commit -m "$(cat <<\'EOF\'\nfix: stop servers by pid\n\npkill -f node was killing other sessions\nkill $(lsof -ti:3000) too\nEOF\n)"'
 $'git commit -m "fix\n\npkill is gone"' $'cat > notes.md <<EOF\nkillall node\nEOF' "ssh box 'pkill -f worker'" '# pkill node' 'ls' "echo it's fine; echo don't pkill" 'kill "$(cat .dev.pid)" && lsof -i :3000' 'lsof -p 1234 | grep cwd; kill 1234' 'lsof -i :3000; kill $(cat .pid)'
 'ps aux | grep node; kill -TERM 4242 4243' 'cat pids.txt | xargs kill' 'jobs; kill %1' $'cat > NOTES.md <<EOF\nnever run pkill -f node\nkill $(lsof -ti:3000)\nEOF' )
for c in "${allowed[@]}"; do ok "allows: $c" "$(hook "$c")" "0"; done
ok "off switch" "$(printf '{"tool_input":{"command":"pkill node"}}' | STEELTHREAD_ALLOW_PATTERN_KILL=1 "$H" >/dev/null 2>&1; echo $?)" "0"
ok "empty input" "$(printf '' | "$H" >/dev/null 2>&1; echo $?)" "0"

group "hook: machines without jq or python3"
# Build a PATH that holds only the named tools, then run the hook with it.
mk() { d="$T/$1"; mkdir -p "$d"; shift; for b in "$@"; do ln -sf "$(command -v "$b")" "$d/$b"; done; }
mk nojq cat tr sed awk bash env python3; mk bare cat tr sed awk bash env
for d in nojq bare; do
  ok "$d blocks pkill" "$(printf '{"tool_name":"Bash","tool_input":{"command":"pkill -f node","description":"x"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "2"
  ok "$d blocks multi-line" "$(printf '{"tool_input":{"command":"npm test\\nkillall node","description":"x"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "2"
  ok "$d blocks lookup kill" "$(printf '{"tool_input":{"command":"kill -9 $(lsof -ti:3000)"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "2"
  ok "$d allows quoted text" "$(printf '{"tool_input":{"command":"git commit -m \\"drop pkill\\"","description":"pkill"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "0"
  ok "$d allows ls" "$(printf '{"tool_input":{"command":"ls -la","description":"pkill things"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "0"
  ok "$d allows heredoc note" "$(printf '{"tool_input":{"command":"cat > N.md <<EOF\\nnever pkill -f node\\nEOF"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "0"
  ok "$d blocks heredoc to shell" "$(printf '{"tool_input":{"command":"bash <<EOF\\npkill -f node\\nEOF"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "2"
  ok "$d allows exact pid with lookup" "$(printf '{"tool_input":{"command":"lsof -p 1234 | grep cwd; kill 1234"}}' | PATH="$T/$d" "$H" >/dev/null 2>&1; echo $?)" "0"
done
# python3 present but broken: must fall through to the sed path.
mk brokenpy cat tr sed awk bash env; printf '#!/bin/sh\nexit 1\n' > "$T/brokenpy/python3"; chmod +x "$T/brokenpy/python3"
ok "broken python3 still blocks" "$(printf '{"tool_input":{"command":"pkill -f node"}}' | PATH="$T/brokenpy" "$H" >/dev/null 2>&1; echo $?)" "2"

flush
# How long the hook adds to one Bash call (not a check, just a measurement).
n=50; json='{"tool_name":"Bash","tool_input":{"command":"npm test -- --run && git status"}}'
ms=$(perl -MTime::HiRes=time -e '
  my ($n, $hook, $json) = @ARGV; my $t = time;
  for (1..$n) { open(my $p, "|-", $hook) or die; print $p $json; close $p }
  printf "%.0f", (time - $t) * 1000 / $n' "$n" "$H" "$json")

echo
echo "steelthread script tests on $(uname -s) $(uname -m), bash ${BASH_VERSION%%(*}, $(awk --version 2>/dev/null | head -1 | cut -c1-28 || true)"
printf '%s' "$summary"
echo "  ---------------------------------------------------"
printf '  %-40s %3d / %d\n' "total" "$pass" "$((pass + fail))"
echo "  hook time per Bash call: about ${ms} ms (average of $n)"
[ "$fail" -eq 0 ]

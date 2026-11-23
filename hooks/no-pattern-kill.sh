#!/usr/bin/env bash
# PreToolUse hook for the Bash tool. Blocks commands that kill processes by name
# pattern or by sweeping a port, because with several sessions and worktrees on one
# machine they take down someone else's server or database.
#
# Blocked: pkill, killall, kill-port, fkill, fuser -k, and a kill (or xargs kill)
# whose target comes from a lookup with lsof, pgrep, pidof, ss, netstat or
# ps | grep. Allowed: kill with literal PIDs, and kill "$(cat some.pid)".
# Text inside quotes, comments and heredocs is ignored, except a script handed to
# a shell (bash -c, eval, bash <<EOF).
#
# This is a guard rail for habits, not a sandbox: it reads the command text only.
# Set STEELTHREAD_ALLOW_PATTERN_KILL=1 in the environment to turn it off.
[ "${STEELTHREAD_ALLOW_PATTERN_KILL:-}" = "1" ] && exit 0

input=$(cat)
cmd=""
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
fi
if [ -z "$cmd" ] && command -v python3 >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | python3 -c 'import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command") or "")
except Exception:
    pass' 2>/dev/null)
fi
if [ -z "$cmd" ]; then
  # No JSON parser worked: cut the string out and undo its escapes by hand.
  cmd=$(printf '%s' "$input" | tr '\n' ' ' \
    | sed -En 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' \
    | awk '{ gsub(/\\\\/, "\001"); gsub(/\\n/, "\n"); gsub(/\\t/, " "); gsub(/\\"/, "\""); gsub(/\001/, "\\\\"); print }')
fi
[ -n "$cmd" ] || exit 0

printf '%s\n' "$cmd" | awk '
function base(w) { sub(/^.*\//, "", w); sub(/@.*$/, "", w); return w }
function flags(g) { while (sub(/^-[^ \t]*[ \t]+/, "", g)) ; return g }

# Collect the command. A heredoc body is left out unless it is fed to a shell.
{
  if (hd != "") {
    t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t)
    if (t == hd) hd = ""
    else if (keep) text = text $0 "\n"
    next
  }
  text = text $0 "\n"
  l = $0; gsub(/<<</, "", l)
  if (match(l, /<<-?[ \t]*[\047"\\]?[A-Za-z_][A-Za-z0-9_]*/)) {
    hd = substr(l, RSTART, RLENGTH)
    sub(/^<<-?[ \t]*[\047"\\]?/, "", hd)
    keep = (l ~ /(^|[^A-Za-z0-9_.-])(bash|sh|zsh|dash)([^A-Za-z0-9_.-]|$)/)
  }
}

END {
  gsub(/\\./, "", text)

  # Pass 1: drop comments and quoted text. Keep a double-quoted string that runs a
  # command substitution, and a script handed to a shell with -c or to eval.
  n = length(text); out = ""; i = 1
  while (i <= n) {
    c = substr(text, i, 1)
    if (c == "#" && (out == "" || out ~ /[ \t\n;]$/)) {
      while (i <= n && substr(text, i, 1) != "\n") i++
    } else if (c == "\047" || c == "\"") {
      rest = substr(text, i + 1); j = index(rest, c)
      if (j == 0) { out = out rest; break }
      body = substr(rest, 1, j - 1); i = i + j + 1
      if (out ~ /(^|[^A-Za-z0-9_-])(bash|sh|zsh|dash)([ \t]+-[A-Za-z]+)*[ \t]+-[A-Za-z]*c[ \t]+$/ || out ~ /(^|[^A-Za-z0-9_-])eval[ \t]+$/)
        out = out "\n" body "\n"
      else if (c == "\"" && body ~ /\$\(|`/)
        out = out body
      else
        out = out "Q"
    } else {
      out = out c; i++
    }
  }

  # Pass 2: one segment per simple command. \002 opens a command substitution,
  # \004 a subshell, \003 closes either.
  n = length(out); marked = ""; tick = 0
  for (i = 1; i <= n; i++) {
    c = substr(out, i, 1)
    if (c == "$" && substr(out, i + 1, 1) == "(") { marked = marked "\n\002"; i++ }
    else if (c == "`") { tick = !tick; marked = marked (tick ? "\n\002" : "\n\003") }
    else if (c == "(") marked = marked "\n\004"
    else if (c == ")") marked = marked "\n\003"
    else marked = marked c
  }
  gsub(/[;&|{}]/, "\n", marked)
  m = split(marked, seg, "\n")

  depth = 0; inkill = 0
  for (k = 1; k <= m; k++) {
    g = seg[k]; mark = substr(g, 1, 1)
    if (mark == "\002" || mark == "\004") {
      g = substr(g, 2)
      iskill[depth + 1] = (mark == "\002" && curkill[depth])
      depth++
      if (iskill[depth]) inkill++
    } else if (mark == "\003") {
      g = substr(g, 2)
      if (depth > 0) {
        if (iskill[depth]) inkill--
        depth--
        continue          # what follows is the rest of the outer command
      }
    }
    curkill[depth] = 0
    sub(/^[ \t]+/, "", g); isx = 0
    do {
      again = 0
      if (sub(/^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+/, "", g)) again = 1
      else if (sub(/^(then|do|else|elif|if|while|until|!|time|command|exec|nohup|builtin)[ \t]+/, "", g)) again = 1
      else if (sub(/^env[ \t]+/, "", g)) { g = flags(g); again = 1 }
      else if (sub(/^(sudo|doas)[ \t]+/, "", g)) { sub(/^-[ugp][ \t]+[^ \t]+[ \t]+/, "", g); g = flags(g); again = 1 }
      else if (sub(/^(npx|bunx|pnpx)[ \t]+/, "", g)) { g = flags(g); again = 1 }
      else if (sub(/^(pnpm|yarn|npm|bun)[ \t]+(dlx|exec|x)[ \t]+/, "", g)) { g = flags(g); again = 1 }
      else if (sub(/^timeout[ \t]+/, "", g)) {
        while (sub(/^-[sk][ \t]+[^ \t]+[ \t]+/, "", g) || sub(/^-[^ \t]*[ \t]+/, "", g)) ;
        sub(/^[^ \t]+[ \t]+/, "", g); again = 1
      }
      else if (sub(/^xargs[ \t]+/, "", g)) isx = 1
    } while (again)

    if (isx) {
      if (g ~ /(^|[ \t\/])(pkill|killall)([ \t]|$)/) hit = 1
      else if (g ~ /(^|[ \t\/])kill([ \t]|$)/ && lookup) hit = 1
      continue
    }
    w = g; sub(/[ \t].*$/, "", w); w = base(w)
    if (w ~ /^(pkill|killall|kill-port|fkill|fkill-cli)$/) hit = 1
    else if (w == "kill") {
      a = g; sub(/^[^ \t]+[ \t]*/, "", a)
      if (a !~ /^-0([ \t]|$)/) {
        curkill[depth] = 1
        while (sub(/^-[sn][ \t]+[^ \t]+[ \t]*/, "", a) || sub(/^-[^ \t]*[ \t]*/, "", a)) ;
        gsub(/[ \t]+$/, "", a)
        # Targets that are not literal PIDs, after a lookup earlier in the command.
        if (a != "" && a !~ /^(%?[0-9]+[ \t]*)+$/ && lookup) hit = 1
      }
    }
    else if (w ~ /^(lsof|pgrep|pidof|ss|netstat|fuser)$/) {
      lookup = 1
      if (inkill) hit = 1
      if (w == "fuser" && g ~ /[ \t]-[A-Za-z]*k/) hit = 1
    }
    else if (w == "ps") ps = 1
    else if (w ~ /^(grep|egrep|fgrep|rg|awk)$/ && ps) { lookup = 1; if (inkill) hit = 1 }
  }
  exit (hit ? 2 : 0)
}'

if [ $? -eq 2 ]; then
  echo "steelthread: killing processes by name or by port sweep is not allowed here; it can stop another session's server or database. Kill the exact PID of the process you started (keep it from the launch, or read the project's PID file)." >&2
  exit 2
fi
exit 0

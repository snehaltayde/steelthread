---
name: new-project
description: Set up a project (new or existing) for the slice-by-slice build flow by writing its CLAUDE.md, architecture, feature list, UI rules and decision log.
argument-hint: <one line on what the product is>
disable-model-invocation: true
---

Product: $ARGUMENTS

Goal: leave this folder with the documents the build flow needs. Write no application code
in this command. Start each document from its template in
`${CLAUDE_PLUGIN_ROOT}/templates/` and keep the template's headings.

1. **Look first.** If the folder already has code, load the
   `steelthread:adopt-existing-project` skill and follow it: the documents must record the
   project as it is, not replace its stack.
2. **Ask me once**, in one batch, only what you cannot work out: who uses it and in which
   roles (and which role is least trusted), the five to ten things it must do, anything it
   must never do, where it will run, and any stack I insist on. Recommend a stack for the
   rest and say why; check current stable versions before naming them.
3. **Write:**
   - `CLAUDE.md` from `templates/PROJECT-CLAUDE.md`: what the product is, the stack table, the
     folder layout, the non-negotiable rules for this product and the commands. Every row
     of the commands table is a command that runs as written in a fresh checkout (it
     creates any folder it needs, and names no file or folder that a later slice has yet
     to add); where the stack has no tool for a row (no linter, say), give the closest
     real check and say so. Then append
     the whole of `templates/working-agreement.md` below it, unchanged. If a `CLAUDE.md`
     already exists, add to it and keep what is there.
   - `docs/ARCHITECTURE.md`: data model, roles and the permission matrix, event flow,
     background work, external services.
   - `docs/FEATURES.md`: phases of checkbox lines in build order. Load the
     `steelthread:slice-writing` skill before writing the lines. Phase 0 is the skeleton
     (auth, roles, permission test harness, app shell, seed data). For an existing project,
     tick only what you have seen working.
   - `docs/UI.md` (if it has screens): type, color, spacing, component and state rules.
   - `docs/DECISIONS.md`: the choices made here, dated.
   - `docs/PLAYBOOK.md` from its template, empty of lessons.
4. **Show me** the stack, the roles and the phase list in a short summary. This is the one
   point where you wait for my go-ahead, because everything later builds on it.
5. After my go-ahead, commit the documents as the project's first commit (run `git init`
   first if the folder is not a repository), so every later slice has a clean base. Then
   build Phase 0 with `/steelthread:feature`, line by line, and carry on in order.

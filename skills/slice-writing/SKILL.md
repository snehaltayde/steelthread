---
name: slice-writing
description: Write and order docs/FEATURES.md lines so that each one is a true end-to-end slice. Use when creating or revising a feature list, when adding new work to it, when a line turns out too big to build in one go, or when a line describes a layer instead of something a user can do.
---

# Writing slices

A slice is one line of `docs/FEATURES.md` that can be built from data model to tests and
then used by someone. When a line is ticked, a person in some role can do something they
could not do before, and a test proves it.

## The shape of a line

`<Role> can <do one thing> <to what>, and <who else> can or cannot <see the result>.`

- One role acting, one capability.
- It names what the less-trusted roles get, because that is where the permission work is.
- It can be checked by one browser flow or one request-level test.

| Not a slice | Why | A slice |
|---|---|---|
| Set up the invoices table | A layer. Nothing can be used. | An admin can create an invoice for a client; the client sees only their own |
| Build the reports API | A layer, and no role | A manager can see this month's totals for their team only |
| Dashboard page (empty for now) | An empty screen for a later phase | Leave it out until a line fills it |
| User management | A whole area | An admin can invite a user by email with a role |
| Improve performance | No finish line | The invoice list loads 5,000 rows in under a second |

## Size

A line fits one builder within about 150 tool calls: usually one new table or a few
columns, one or two permission actions, one screen or one part of a screen. Split a line
when it has:

- more than one role acting (split by role),
- "and" between two capabilities (split at the "and"),
- create, edit, delete and list together (create and list first, then the rest),
- an outside service (first the slice with a stand-in, then the real service).

Do not split by layer. Every piece left after a split is still usable on its own.

## Order

- Phase 0 is the skeleton: sign-in, roles, the permission test harness, the app shell,
  seed data. Nothing else can be tested properly before it.
- Inside a phase, a line comes after everything it reads from.
- Put the riskiest line of a phase early: the one with an outside service, the hardest
  permission rule, or the least-understood requirement.
- A phase ends at a point where the product could be shown to someone.

## Keeping the list honest

- New work gets a line before it gets code.
- A line is ticked only after `steelthread-verify` passes for it.
- Ideas that are not slices yet go under "Later" and are not built from there.

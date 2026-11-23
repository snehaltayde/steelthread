# <Product name>

<Two or three sentences: what it is, who uses it, what it must never do.>

## Stack (do not swap without asking)

| Layer | Choice | Version | Why |
|---|---|---|---|
| Language / runtime | | | |
| Framework | | | |
| Database and migrations | | | |
| Auth | | | |
| Tests (unit, browser) | | | |
| Hosting | | | |

## Folder layout

<The top two levels, one line each, and where a new feature's files go.>

## Non-negotiable rules

- **Permissions:** checks live in `<path>`, one module per domain. Nothing reads or writes
  without going through them.
- **Data scoping:** every query is filtered by `<tenant / owner key>`.
- **Least-trusted role:** `<role>`. It gets a test on every new read.
- **Audit trail:** <what is recorded, where, in the same transaction as the write>.
- **Data formats:** <ids, money, dates and time zones, soft delete or hard delete>.
- **Dependencies:** no new dependency without a stated reason in `docs/DECISIONS.md`.

## Commands

| Task | Command |
|---|---|
| Install | |
| Run locally | |
| Lint | |
| Unit tests (all) | |
| Unit tests (one file) | |
| Migrate a fresh database | |
| Browser tests (one spec) | |
| Browser tests (all) | |
| Seed | |

<!-- The working agreement from the steelthread plugin goes below this line. -->

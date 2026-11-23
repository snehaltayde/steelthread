---
name: migration-safety
description: Write, renumber and check database migrations safely. Use when a migration changes or drops existing data, when two branches both add a migration, when a migration fails on a fresh database, or before merging any branch that contains one.
---

# Migration safety

## Before writing one

- Read the project's migration tool docs for the version in use. Tools differ on how they
  order, name and record migrations.
- Decide whether the change is additive (new table, new nullable column, new index) or
  destructive (drop, rename, type change, new NOT NULL on a table with rows, a narrower
  constraint). Destructive changes are flagged in the plan and in the report.

## Destructive changes: expand, move, contract

Never change a column in place while code that reads the old shape is still running.

1. **Expand:** add the new column or table alongside the old one. Deploy.
2. **Move:** write to both, backfill the old rows in batches, switch the reads. Deploy.
3. **Contract:** drop the old column in a later migration, once nothing reads it.

A backfill that can fail halfway must be safe to run again. Deleting or rewriting the
owner's existing data needs their go-ahead first.

## Every migration, before merge

- Run the whole chain on an empty database, not only the newest file on a database that
  already has the others. This is the `migrate` step of `steelthread-verify`.
- Check that the schema the migrations produce matches the schema the code declares.
- A new filter or join in the slice has an index.
- If the project supports rollback, run down and up once.

## Two branches, two migrations

Parallel branches collide on migration numbers. The branch that merges second fixes it:

1. Bring the main branch in. Keep its migration as it is.
2. Renumber your migration to come after it.
3. If the tool keeps schema snapshots, restore the earlier snapshot from the main branch
   and regenerate yours on top of it, so your snapshot chains from the previous id.
4. If the tool keeps a journal or index file, fix the entries. Indexes must stay
   contiguous, with no gaps and no duplicates.
5. Run the whole chain on an empty database again.

Never edit a migration that has already run on a shared or production database. Add a new
one.

## Going out

Migrations run before the code that needs them. When two deployed parts share the changed
shape, follow the order in the `steelthread:go-live` skill.

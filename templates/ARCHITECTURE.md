# Architecture

## Data model

<One block per table or collection: columns with types, keys, indexes, the scoping key, and
how rows are deleted. Keep it in step with the migrations.>

## Roles and permission matrix

Least-trusted role: `<role>`.

| Action | <role 1> | <role 2> | <least-trusted role> |
|---|---|---|---|
| <domain>.<action> | allow | own only | deny |

"own only" means the row's owner or tenant key must match the caller. Anything not listed
is denied.

## Event flow

<What is emitted or logged on each write, and who consumes it.>

## Background work

<Jobs, schedules, queues: what triggers each one, what it touches, how it retries.>

## External services

<Each outside service: what it is used for, how it fails, and the alert for when it goes
silent.>

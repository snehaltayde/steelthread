---
name: go-live
description: Take a project to production or deploy a change to it safely (deploy order, secrets, shared servers, outside services, first-deploy surprises). Use before a first production deploy, when deploying a change that alters a contract between two parts, when setting up a server, or when something works locally but not in production.
---

# Going live

A first push and a first production deploy need the owner's go-ahead. So does anything
that costs money or cannot be undone. Ask once, with what will happen and where.

## Before the first deploy

- Every outside service the project talks to has had one real run, not only a mock, and
  has an alert for when it goes silent.
- Production secrets live in one git-ignored file and are never printed, logged or pasted
  into a report. Key files have mode 600 and are listed in the Docker ignore file.
- The migration chain runs on an empty database (`steelthread-verify`).
- The phase-end audit in `steelthread:least-trusted-audit` has been done on this build.
- There is a way back: the previous image or release is kept, and the migration is either
  additive or has a tested path back.

## Deploy order

When two parts share a contract (a schema, an API shape, a message format):

1. Migrate the database.
2. Deploy the part that accepts the new contract.
3. Deploy the part that sends it.

Anything else leaves a window where one side speaks a shape the other does not know.

## Building and shipping

- Build images on the development machine or in CI, for the server's architecture, and
  copy them over. Do not build on a small shared server.
- Tag each image with the commit it was built from.

## On a shared server

- Do not take ports 80 or 443, and do not change the firewall.
- Bind the app to loopback and add a site block to the proxy that is already there.
- Leave other projects' containers, volumes and processes alone. Stop only what this
  project started, by its exact name or PID.

## What only production shows

- A new DNS record can stay unresolvable for the negative-cache time, up to about 30
  minutes. A failure straight after creating it is not proof of a wrong record.
- Third-party sign-in behaves differently depending on how the account came to exist:
  invited, self-registered, or linked to an existing account later. Run each path once
  against the real provider, not a mock.
- Long-lived connections drop. Retry them, a bounded number of times, with a delay.
- A first deploy attempt sometimes fails and passes on retry. Retry once, read the log
  both times, and report it either way.

## After the deploy

Check the real thing: load the site signed in as the least-trusted role, run one real
action through each outside service, and read the logs for the first few minutes. Report
what was checked and what was not.

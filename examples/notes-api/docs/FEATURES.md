# Features

One line is one slice: built from data model to tests, in this order. A line is ticked only
when it has been verified. See the `steelthread:slice-writing` skill for how to write lines.
There are no screens, so "app shell" means the running server and its JSON error handling.

## Phase 0: skeleton

- [x] Any of the three roles (admin, member, guest) can send its token to `GET /me` and get its own name and role back, and a missing or unknown token gets 401 on every route (this line also brings up the server, the database, migrations 001 users and the JSON error shell)
- [ ] Each role exists and the permission test harness covers every role: a test helper sends a request as each role and one matrix test asserts allow or deny per action, with every route still denied (401) without a token
- [ ] A fresh setup has seed data for every role: `node scripts/seed.js` creates one admin, one member and one guest and prints their dev tokens, and running it twice changes nothing

## Phase 1: shared notes

- [ ] A member can create a private note (title and body) with `POST /notes`, and a guest gets 403 on the same request
- [ ] An admin or member can list all notes with `GET /notes`, and a guest sees only public notes (an empty list while none is public) with no hint of private ones
- [ ] A member can mark their own note public with `PATCH /notes/:id`, an admin can mark any note public, and a guest then sees it in their list; a member marking someone else's note gets 403 and a guest gets 403
- [ ] An admin can delete a note with `DELETE /notes/:id`, and a member or guest gets 403 whether or not the note exists

## Later (not planned yet)

- Mark a note private again, edit a note, fetch one note by id.
- Create and revoke users and tokens through the API.
- An audit trail of who changed or deleted what.

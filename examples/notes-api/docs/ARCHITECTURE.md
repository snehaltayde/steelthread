# Architecture

A JSON API over HTTP on `127.0.0.1`. One process, one SQLite file. No UI, no background work.

## Data model

**users**
- `id` INTEGER PRIMARY KEY
- `name` TEXT NOT NULL UNIQUE
- `role` TEXT NOT NULL CHECK (role IN ('admin','member','guest'))
- `token_hash` TEXT NOT NULL UNIQUE (SHA-256 hex of the token; the token itself is never stored)
- `created_at` TEXT NOT NULL (ISO 8601 UTC)
- Scoping key: none (a single team). Rows are never deleted in this version.

**notes**
- `id` INTEGER PRIMARY KEY
- `author_id` INTEGER NOT NULL REFERENCES users(id)
- `title` TEXT NOT NULL (1 to 200 chars)
- `body` TEXT NOT NULL (up to 10,000 chars)
- `public` INTEGER NOT NULL DEFAULT 0 CHECK (public IN (0,1)). A new note is private.
- `created_at` TEXT NOT NULL (ISO 8601 UTC)
- Index on `(public)`. Visibility key: `public`; a guest query always carries `WHERE public = 1`.
- Rows are hard-deleted (admin only).

**schema_migrations**: `version` TEXT PRIMARY KEY, `applied_at` TEXT. Migrations are numbered
files in `migrations/` and applied in order, each inside a transaction.

## Roles and permission matrix

Least-trusted role: `guest`.

| Action | admin | member | guest |
|---|---|---|---|
| me.read (`GET /me`) | allow | allow | allow |
| notes.create (`POST /notes`) | allow | allow | deny |
| notes.list (`GET /notes`) | allow (all notes) | allow (all notes) | public notes only |
| notes.markPublic (`PATCH /notes/:id`) | allow (any note) | own only | deny |
| notes.delete (`DELETE /notes/:id`) | allow | deny | deny |

"own only" means the note's `author_id` must equal the caller's id. Anything not listed is
denied. Order of checks on every route: token (401) → role permission (403) → existence (404)
→ ownership (403). A guest is denied before any note is looked up, so a guest cannot tell
whether a private note exists.

Responses: 401 `{"error":"unauthorized"}` for a missing or unknown token on every path
(including unknown paths); 403 `{"error":"forbidden"}`; 404 `{"error":"not_found"}`;
400 `{"error":"invalid_input"}`.

## Event flow

None. Writes are not emitted or logged anywhere beyond the database row itself; the server
logs one line per request (method, path, status) without tokens. No consumers.

## Background work

None.

## External services

None. The server makes no outgoing calls.

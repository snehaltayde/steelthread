CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'member', 'guest')),
  token_hash TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
);

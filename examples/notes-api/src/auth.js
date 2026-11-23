import { createHash } from 'node:crypto';

const MAX_TOKEN_LENGTH = 256;

export function hashToken(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

// Returns the token from "Bearer <token>" (scheme case-insensitive), or null if malformed.
export function parseBearer(header) {
  if (typeof header !== 'string') return null;
  const parts = header.split(' ');
  if (parts.length !== 2) return null;
  const [scheme, token] = parts;
  if (scheme.toLowerCase() !== 'bearer') return null;
  if (token.length === 0 || token.length > MAX_TOKEN_LENGTH || /\s/.test(token)) return null;
  return token;
}

// Returns {id, name, role} from the database row of the token, or null.
export function authenticate(db, req) {
  const token = parseBearer(req.headers.authorization);
  if (token === null) return null;
  const row = db
    .prepare('SELECT id, name, role FROM users WHERE token_hash = ?')
    .get(hashToken(token));
  return row ? { id: row.id, name: row.name, role: row.role } : null;
}

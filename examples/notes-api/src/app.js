import { authenticate } from './auth.js';
import { HttpError, sendJson } from './http.js';
import { meRoutes } from './routes/me.js';

const defaultLog = (line, level) => (level === 'error' ? console.error : console.log)(line);

// Unparseable request target (e.g. "http://[") -> 404, never an uncaught throw.
function parsePath(url) {
  try {
    return new URL(url, 'http://localhost').pathname;
  } catch {
    throw new HttpError(404, 'not_found');
  }
}

export function createApp({ db, extraRoutes = [], log = defaultLog }) {
  const routes = [...meRoutes, ...extraRoutes];

  return async function handle(req, res) {
    let path = '-'; // logged as '-' until the URL has been parsed
    try {
      const user = authenticate(db, req);
      if (!user) throw new HttpError(401, 'unauthorized');
      path = parsePath(req.url);
      const route = routes.find((r) => r.method === req.method && r.path === path);
      if (!route) throw new HttpError(404, 'not_found');
      await route.handler(req, res, { db, user });
    } catch (err) {
      if (err instanceof HttpError) {
        if (!res.headersSent) sendJson(res, err.status, { error: err.code });
      } else {
        log(`error ${req.method} ${path}: ${err && err.stack ? err.stack : err}`, 'error');
        if (!res.headersSent) sendJson(res, 500, { error: 'internal' });
        else res.destroy();
      }
    }
    if (!req.complete) req.resume(); // unread body (e.g. a 401 before parsing): drain it
    log(`${req.method} ${path} ${res.statusCode}`);
  };
}

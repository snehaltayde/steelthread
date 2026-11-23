import { canReadMe } from '../permissions/me.js';
import { HttpError, sendJson } from '../http.js';

export const meRoutes = [
  {
    method: 'GET',
    path: '/me',
    handler(req, res, { user }) {
      if (!canReadMe(user)) throw new HttpError(403, 'forbidden');
      sendJson(res, 200, { name: user.name, role: user.role });
    },
  },
];

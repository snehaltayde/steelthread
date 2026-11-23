// The only place the me.* actions are checked. Anything not listed is denied.
export const ME_ACTIONS = {
  read: new Set(['admin', 'member', 'guest']),
};

export function canReadMe(user) {
  return Boolean(user) && ME_ACTIONS.read.has(user.role);
}

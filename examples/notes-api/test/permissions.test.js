import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canReadMe } from '../src/permissions/me.js';

for (const role of ['admin', 'member', 'guest']) {
  test(`canReadMe: ${role} -> true`, () => {
    assert.equal(canReadMe({ id: 1, name: 'x', role }), true);
  });
}

for (const [label, user] of [
  ['unknown role', { id: 1, name: 'x', role: 'owner' }],
  ['null', null],
  ['undefined', undefined],
]) {
  test(`canReadMe: ${label} -> false`, () => {
    assert.equal(canReadMe(user), false);
  });
}

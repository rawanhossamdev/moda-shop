import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { isBreached, passwordProblem } from '../src/services/password-policy.js';

test('Local policy permits passphrases, Unicode and eight letters without forced composition', () => {
  for (const value of ['silkfern', 'linen breeze in autumn', 'été forêt']) assert.equal(passwordProblem(value), null);
  for (const value of [null, '', 'short', 'PASSWORD123!', 'aaaaaaaa', '🔒'.repeat(19)]) assert.ok(passwordProblem(value));
});

test('Optional breach screening sends only a five-character prefix, requests padding and checks counts', async () => {
  const password = 'synthetic screening fixture';
  const hash = createHash('sha1').update(password).digest('hex').toUpperCase();
  let calls = 0;
  const lookup = async (url, options) => {
    calls++;
    assert.ok(url === `https://api.pwnedpasswords.com/range/${hash.slice(0, 5)}`);
    assert.ok(!url.includes(password));
    assert.equal(options.headers['Add-Padding'], 'true');
    assert.ok(options.signal instanceof AbortSignal);
    return { ok: true, text: async () => `${hash.slice(5)}:42\r\n${'0'.repeat(35)}:0` };
  };
  assert.equal(await isBreached(password, { enabled: false, lookup }), false);
  assert.equal(calls, 0);
  assert.equal(await isBreached(password, { enabled: true, lookup }), true);
  assert.equal(await isBreached(password, { enabled: true,
    lookup: async () => ({ ok: true, text: async () => `${hash.slice(5)}:0` }) }), false);
  await assert.rejects(isBreached(password, { enabled: true, lookup: async () => ({ ok: false }) }));
  await assert.rejects(isBreached(password, { enabled: true, lookup: async () => ({ ok: true, text: async () => 'invalid provider response' }) }));
});

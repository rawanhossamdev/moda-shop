import { createHash } from 'node:crypto';
// A small offline blocklist, not a comprehensive breach database. Keep the
// matching client policy in sync. Optional breach screening sends only a prefix.
const common = new Set(['password', 'password1', 'password123', 'password123!', '12345678', '123456789', '1234567890', 'qwerty123', 'qwertyuiop', 'letmein123', 'iloveyou', 'welcome123', 'admin123', 'abcdefgh', 'modashop123']);

export function passwordProblem(value) {
  if (typeof value !== 'string' || [...value].length < 8) return 'Use at least 8 characters. A longer passphrase works well.';
  if (Buffer.byteLength(value, 'utf8') > 72 || value.includes('\0')) return 'Use up to 72 UTF-8 bytes without null characters.';
  if (common.has(value.trim().toLowerCase()) || /^(.)\1+$/u.test(value)) return 'This password is too common. Choose a less predictable passphrase.';
  return null;
}

export async function isBreached(value, { enabled = process.env.CHECK_BREACHED_PASSWORDS === 'true', lookup = fetch } = {}) {
  if (!enabled) return false;
  // SHA-1 is ONLY a lookup identifier, never a credential storage algorithm.
  const hash = createHash('sha1').update(value, 'utf8').digest('hex').toUpperCase();
  const response = await lookup(`https://api.pwnedpasswords.com/range/${hash.slice(0, 5)}`, {
    headers: { 'Add-Padding': 'true', 'User-Agent': 'MODA-Password-Screening' },
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error('Password screening unavailable.');
  const rows = (await response.text()).trim().split(/\r?\n/);
  if (!rows.length || rows.some((row) => !/^[A-F0-9]{35}:\d+$/.test(row))) throw new Error('Password screening unavailable.');
  return rows.some((row) => {
    const [suffix, count] = row.split(':');
    return suffix === hash.slice(5) && Number(count) > 0;
  });
}

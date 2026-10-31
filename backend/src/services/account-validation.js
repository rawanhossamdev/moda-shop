import { mailbox } from '../config/email.js';

export function accountEmail(value) {
  return typeof value === 'string' ? mailbox(value.trim()) : null;
}
export function accountName(value) {
  return typeof value === 'string' && value.trim().length >= 2 && value.trim().length <= 120 &&
    !/[\x00-\x1f\x7f]/.test(value) ? value.trim() : null;
}
export function currentPasswordValid(value) {
  return typeof value === 'string' && value.length > 0 && Buffer.byteLength(value, 'utf8') <= 72 && !value.includes('\0');
}

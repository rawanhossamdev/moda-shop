import { createEmailService } from './email.service.js';

export function createResetMailer(source = process.env, send = fetch, client) {
  const email = createEmailService({ source, send, client });
  return {
    get configured() {
      return email.configured;
    },
    assertRecipient(address) { email.assertRecipient(address); },
    send(address, token) { return email.sendPasswordReset(address, token); },
  };
}

import { createEmailService } from './email.service.js';

export function createVerificationMailer(source = process.env, send = fetch, client) {
  const email = createEmailService({ source, send, client });
  return {
    get configured() {
      return email.configured;
    },
    assertRecipient(address) { email.assertRecipient(address); },
    send(address, code) { return email.sendVerification(address, code); },
  };
}

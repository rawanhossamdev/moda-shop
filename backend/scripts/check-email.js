import 'dotenv/config';
import { readEmailConfig } from '../src/config/email.js';

const config = readEmailConfig();
// Readiness only: no request, no database access, and no private values.
console.log(`Resend key present: ${Boolean(process.env.RESEND_API_KEY?.trim())}`);
console.log(`Email delivery enabled: ${config.enabled}`);
console.log(`Configuration result: ${config.reason ?? 'READY_FOR_MANUAL_TEST'}`);
console.log('No email sent. Configuration readiness does not verify sender ownership or inbox delivery.');

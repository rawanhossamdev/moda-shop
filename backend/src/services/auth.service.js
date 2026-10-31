import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { randomBytes, randomUUID } from 'node:crypto';
import { readAuthConfig } from '../config/env.js';
import { passwordProblem, isBreached } from './password-policy.js';
import { accountEmail, accountName, currentPasswordValid } from './account-validation.js';

export class AuthError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
const invalidCredentials = () => new AuthError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect.');
const invalidToken = () => new AuthError(401, 'UNAUTHENTICATED', 'Please sign in again.');
export const publicUser = ({ id, email, name, emailVerifiedAt }) => ({ id, email, name, emailVerified: Boolean(emailVerifiedAt) });

export async function screenNewPassword(password) {
  let breached;
  try { breached = await isBreached(password); }
  catch { throw new AuthError(503, 'SCREENING_UNAVAILABLE', 'Password safety checks are unavailable. Please try again.'); }
  if (breached) throw new AuthError(400, 'COMPROMISED_PASSWORD', 'This password has appeared in a data breach. Choose a different passphrase.');
}

function input(body, registration) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new AuthError(400, 'VALIDATION_ERROR', 'Enter valid account details.');
  }
  const { email, password } = body;
  if (!accountEmail(email)) {
    throw new AuthError(400, 'VALIDATION_ERROR', 'Enter a valid email address.');
  }
  if (registration && passwordProblem(password)) {
    throw new AuthError(400, 'PASSWORD_POLICY', passwordProblem(password));
  }
  if (!registration && !currentPasswordValid(password)) {
    throw new AuthError(400, 'VALIDATION_ERROR', 'Enter a valid password.');
  }
  if (registration && !accountName(body.name)) {
    throw new AuthError(400, 'VALIDATION_ERROR', 'Name must be between 2 and 120 characters.');
  }
  return { email: accountEmail(email), password, ...(registration ? { name: accountName(body.name) } : {}) };
}

export function createAuthService(repository, config = readAuthConfig, screenPassword = screenNewPassword) {
  let dummyHash;
  function settings() {
    try { return config(); } catch { throw new AuthError(503, 'AUTH_UNAVAILABLE', 'Account services are temporarily unavailable.'); }
  }
  function session(user, options) {
    return {
      token: jwt.sign({ ver: user.authVersion }, options.secret, {
        algorithm: 'HS256', subject: user.id, jwtid: randomUUID(),
        issuer: options.issuer, audience: options.audience, expiresIn: options.ttlSeconds,
      }),
      user: publicUser(user),
    };
  }
  return {
    async updateProfile(user, body) {
      const name = accountName(body?.name);
      const email = accountEmail(body?.email);
      if (!name || !email) throw new AuthError(400, 'VALIDATION_ERROR', 'Enter a valid name and email address.');
      const emailChanged = email !== user.email.toLowerCase();
      if (emailChanged && (!currentPasswordValid(body.currentPassword) || !user.passwordHash || !await bcrypt.compare(body.currentPassword, user.passwordHash))) {
        throw new AuthError(403, 'CURRENT_PASSWORD_INCORRECT', 'Your current password is incorrect.');
      }
      const options = settings();
      try {
        const updated = await repository.updateProfile(user, { name, email }, emailChanged);
        if (!updated) throw new AuthError(409, 'ACCOUNT_CHANGED', 'Your account changed during this request. Please sign in again.');
        return { ...session(updated, options), emailChanged };
      } catch (error) {
        if (error.code === 'P2002') throw new AuthError(409, 'EMAIL_IN_USE', 'An account with this email already exists.');
        throw error;
      }
    },
    async changePassword(user, body) {
      if (!currentPasswordValid(body?.currentPassword) || !user.passwordHash || !await bcrypt.compare(body.currentPassword, user.passwordHash)) {
        throw new AuthError(403, 'CURRENT_PASSWORD_INCORRECT', 'Your current password is incorrect.');
      }
      const problem = passwordProblem(body?.password);
      if (problem) throw new AuthError(400, 'PASSWORD_POLICY', problem);
      if (body.confirmPassword !== body.password) throw new AuthError(400, 'VALIDATION_ERROR', 'Passwords do not match.');
      if (await bcrypt.compare(body.password, user.passwordHash)) throw new AuthError(400, 'PASSWORD_UNCHANGED', 'Choose a password different from your current password.');
      await screenPassword(body.password);
      const passwordHash = await bcrypt.hash(body.password, 12);
      const result = await repository.changePassword(user, passwordHash);
      if (result.count !== 1) throw new AuthError(409, 'ACCOUNT_CHANGED', 'Your account changed during this request. Please sign in again.');
    },
    async register(body) {
      const { name, email, password } = input(body, true);
      const options = settings();
      await screenPassword(password);
      if (await repository.findByEmail(email)) {
        throw new AuthError(409, 'EMAIL_IN_USE', 'An account with this email already exists.');
      }
      const passwordHash = await bcrypt.hash(password, 12);
      try {
        const user = await repository.create({ name, email, passwordHash });
        return session(user, options);
      } catch (error) {
        if (error.code === 'P2002') throw new AuthError(409, 'EMAIL_IN_USE', 'An account with this email already exists.');
        throw error;
      }
    },
    async login(body) {
      const { email, password } = input(body, false);
      const options = settings();
      const user = await repository.findByEmail(email);
      dummyHash ??= bcrypt.hash(randomBytes(32).toString('hex'), 12);
      const hash = user?.passwordHash ?? await dummyHash;
      const valid = await bcrypt.compare(password, hash);
      if (!user?.passwordHash || !valid) throw invalidCredentials();
      return session(user, options);
    },
    async authenticate(header) {
      const options = settings();
      if (typeof header !== 'string' || !/^Bearer [^\s]+$/.test(header)) throw invalidToken();
      let payload;
      try {
        payload = jwt.verify(header.slice(7), options.secret, {
          algorithms: ['HS256'], issuer: options.issuer, audience: options.audience,
        });
      } catch { throw invalidToken(); }
      if (typeof payload !== 'object' || typeof payload.sub !== 'string' ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payload.sub) || !Number.isInteger(payload.ver)) throw invalidToken();
      const user = await repository.findById(payload.sub);
      if (!user?.passwordHash || user.authVersion !== payload.ver) throw invalidToken();
      return user;
    },
    current(user) { return publicUser(user); },
    async logout(user) { await repository.revoke(user.id, user.authVersion); },
  };
}

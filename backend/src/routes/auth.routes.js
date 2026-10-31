import { Router } from 'express';
import { AuthError, createAuthService } from '../services/auth.service.js';
import { authRateLimit } from '../middleware/auth-rate-limit.js';
import { createPasswordResetService } from '../services/password-reset.service.js';
import { createVerificationService } from '../services/verification.service.js';

export function createAuthRouter(repository, config, limiter = authRateLimit(), recoveryOptions, screenPassword, verificationOptions) {
  const router = Router();
  const service = createAuthService(repository, config, screenPassword);
  const recovery = createPasswordResetService(repository, { ...recoveryOptions, ...(screenPassword ? { screenPassword } : {}) });
  const verification = createVerificationService(repository, { ...verificationOptions, ...(config ? { config } : {}) });
  async function verificationOutcome(userId) {
    try {
      const user = await repository.findById(userId);
      await verification.send(user);
      return { status: 'accepted', message: 'The email provider accepted your verification email. Check your inbox and spam folder.' };
    } catch (error) {
      const status = { EMAIL_UNAVAILABLE: 'unavailable', EMAIL_RECIPIENT_RESTRICTED: 'restricted', VERIFY_COOLDOWN: 'cooldown' }[error?.code] ?? 'failed';
      return { status, message: status === 'restricted'
        ? 'Development email is restricted to the configured Resend account test recipient.'
        : 'Verification email was not confirmed. Use Request or resend code after email delivery is available.' };
    }
  }
  router.use((_request, response, next) => { response.set('Cache-Control', 'no-store'); next(); });
  router.post('/register', limiter, async (request, response) => {
    const session = await service.register(request.body);
    const verificationEmail = await verificationOutcome(session.user.id);
    response.status(201).json({ data: { ...session, verificationEmail } });
  });
  router.post('/login', limiter, async (request, response) => {
    response.json({ data: await service.login(request.body) });
  });
  router.post('/forgot-password', limiter, (request, response) => {
    response.status(202).json({ data: { message: recovery.request(request.body) } });
  });
  router.post('/reset-password', limiter, async (request, response) => {
    await recovery.reset(request.body);
    response.status(204).end();
  });
  async function authenticated(request, _response, next) {
    request.authUser = await service.authenticate(request.get('authorization'));
    next();
  }
  router.get('/me', authenticated, (request, response) => {
    response.json({ data: { user: service.current(request.authUser) } });
  });
  router.patch('/profile', limiter, authenticated, async (request, response) => {
    const result = await service.updateProfile(request.authUser, request.body);
    const verificationEmail = result.emailChanged ? await verificationOutcome(result.user.id) : undefined;
    response.json({ data: { ...result, ...(verificationEmail ? { verificationEmail } : {}) } });
  });
  router.post('/change-password', limiter, authenticated, async (request, response) => {
    await service.changePassword(request.authUser, request.body);
    response.status(204).end();
  });
  router.post('/send-verification', limiter, authenticated, async (request, response) => {
    await verification.send(request.authUser);
    response.json({ data: { message: request.authUser.emailVerifiedAt ? 'Your email is already verified.' : 'The email provider accepted your verification email. Check your inbox and spam folder.' } });
  });
  router.post('/verify-email', limiter, authenticated, async (request, response) => {
    response.json({ data: { user: await verification.verify(request.authUser, request.body) } });
  });
  router.post('/logout', authenticated, async (request, response) => {
    await service.logout(request.authUser);
    response.status(204).end();
  });
  router.use((error, _request, response, next) => {
    if (!(error instanceof AuthError)) return next(error);
    if (error.status === 401) response.set('WWW-Authenticate', 'Bearer');
    return response.status(error.status).json({ error: { code: error.code, message: error.message } });
  });
  return router;
}

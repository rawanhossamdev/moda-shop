import { getDatabase } from '../config/database.js';

export function createAuthRepository(database = getDatabase) {
  return {
    findByEmail(email) {
      return database().user.findFirst({ where: { email: { equals: email, mode: 'insensitive' } } });
    },
    findById(id) { return database().user.findUnique({ where: { id } }); },
    create(data) { return database().user.create({ data }); },
    updateProfile(user, data, emailChanged) {
      return database().$transaction(async (tx) => {
        const result = await tx.user.updateMany({ where: { id: user.id, authVersion: user.authVersion, email: user.email, passwordHash: user.passwordHash },
          data: { ...data, ...(emailChanged ? { emailVerifiedAt: null, verificationHash: null, verificationExpiresAt: null,
            verificationSentAt: null, verificationAttempts: 0, resetTokenHash: null, resetExpiresAt: null, authVersion: { increment: 1 } } : {}) } });
        return result.count ? tx.user.findUnique({ where: { id: user.id } }) : null;
      });
    },
    changePassword(user, passwordHash) {
      return database().user.updateMany({ where: { id: user.id, authVersion: user.authVersion, passwordHash: user.passwordHash },
        data: { passwordHash, authVersion: { increment: 1 }, resetTokenHash: null, resetExpiresAt: null } });
    },
    issueVerification(id, verificationHash, now, expiry) {
      return database().user.updateMany({ where: { id, emailVerifiedAt: null,
        OR: [{ verificationSentAt: null }, { verificationSentAt: { lte: new Date(now.getTime() - 60000) } }] },
        data: { verificationHash, verificationExpiresAt: expiry, verificationSentAt: now, verificationAttempts: 0 } });
    },
    async consumeVerification(id, verificationHash, now) {
      const result = await database().user.updateMany({ where: { id, emailVerifiedAt: null,
        verificationHash, verificationExpiresAt: { gt: now }, verificationAttempts: { lt: 5 } },
        data: { emailVerifiedAt: now, verificationHash: null, verificationExpiresAt: null } });
      if (!result.count) await database().user.updateMany({ where: { id, emailVerifiedAt: null,
        verificationExpiresAt: { gt: now }, verificationAttempts: { lt: 5 } }, data: { verificationAttempts: { increment: 1 } } });
      return result;
    },
    setReset(id, resetTokenHash, resetExpiresAt) {
      return database().user.update({ where: { id }, data: { resetTokenHash, resetExpiresAt } });
    },
    async consumeReset(resetTokenHash, passwordHash, now) {
      // One SQL update makes concurrent attempts single-use and revokes all JWTs.
      return database().user.updateMany({
        where: { resetTokenHash, resetExpiresAt: { gt: now } },
        data: { passwordHash, resetTokenHash: null, resetExpiresAt: null, authVersion: { increment: 1 } },
      });
    },
    revoke(id, version) {
      return database().user.updateMany({
        where: { id, authVersion: version }, data: { authVersion: { increment: 1 } },
      });
    },
  };
}

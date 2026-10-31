-- Additive only: existing users, passwords, products and orders are preserved.
ALTER TABLE "User" ADD COLUMN "resetTokenHash" CHAR(64),
                   ADD COLUMN "resetExpiresAt" TIMESTAMP(3);
CREATE UNIQUE INDEX "User_resetTokenHash_key" ON "User"("resetTokenHash");

-- Additive only: existing users and order relations are preserved.
-- Legacy users with no password hash cannot sign in until securely provisioned.
ALTER TABLE "User" ADD COLUMN "passwordHash" VARCHAR(60);
ALTER TABLE "User" ADD COLUMN "authVersion" INTEGER NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX "User_email_case_insensitive_key" ON "User" (LOWER("email"));

CREATE TYPE "PaymentMethod" AS ENUM ('COD', 'PAYMOB_CARD', 'PAYMOB_WALLET');
CREATE TYPE "PaymentStatus" AS ENUM ('UNPAID', 'PENDING', 'PAID', 'FAILED', 'CANCELLED', 'UNKNOWN');
ALTER TABLE "User" ADD COLUMN "emailVerifiedAt" TIMESTAMP(3),
  ADD COLUMN "verificationHash" CHAR(64), ADD COLUMN "verificationExpiresAt" TIMESTAMP(3),
  ADD COLUMN "verificationSentAt" TIMESTAMP(3), ADD COLUMN "verificationAttempts" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Order" ADD COLUMN "subtotalInCents" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "shippingFeeInCents" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "shippingName" VARCHAR(120), ADD COLUMN "shippingPhone" VARCHAR(30),
  ADD COLUMN "shippingAddress" VARCHAR(500), ADD COLUMN "shippingCity" VARCHAR(100),
  ADD COLUMN "deliveryNotes" VARCHAR(1000),
  ADD COLUMN "paymentMethod" "PaymentMethod" NOT NULL DEFAULT 'COD',
  ADD COLUMN "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'UNPAID',
  ADD COLUMN "clientRequestId" UUID, ADD COLUMN "requestHash" CHAR(64);
-- Backfill only the new subtotal field; original totals and all records survive.
UPDATE "Order" SET "subtotalInCents" = "totalInCents";
ALTER TABLE "Order" ADD CONSTRAINT "Order_shipping_nonnegative" CHECK ("shippingFeeInCents" >= 0),
  ADD CONSTRAINT "Order_subtotal_nonnegative" CHECK ("subtotalInCents" >= 0);
CREATE UNIQUE INDEX "Order_userId_clientRequestId_key" ON "Order"("userId", "clientRequestId");
CREATE TABLE "PaymentAttempt" (
  "id" UUID NOT NULL PRIMARY KEY, "orderId" UUID NOT NULL REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING', "integrationId" INTEGER NOT NULL,
  "providerOrderId" VARCHAR(80) UNIQUE, "intentionId" VARCHAR(160) UNIQUE,
  "checkoutCiphertext" TEXT, "expiresAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE INDEX "PaymentAttempt_orderId_idx" ON "PaymentAttempt"("orderId");
CREATE TABLE "PaymentEvent" (
  "id" CHAR(64) NOT NULL PRIMARY KEY, "attemptId" UUID NOT NULL REFERENCES "PaymentAttempt"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  "transactionId" VARCHAR(80) NOT NULL, "status" "PaymentStatus" NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "PaymentEvent_transactionId_idx" ON "PaymentEvent"("transactionId");
CREATE TABLE "OrderEvent" (
  "id" UUID NOT NULL PRIMARY KEY, "orderId" UUID NOT NULL REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  "eventKey" VARCHAR(160) NOT NULL UNIQUE, "kind" VARCHAR(40) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

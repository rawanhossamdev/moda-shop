-- Add saved addresses and immutable snapshots; preserve all existing orders.
CREATE TABLE "ShippingAddress" (
 "id" UUID NOT NULL, "userId" UUID NOT NULL,
 "fullName" VARCHAR(120) NOT NULL, "mobile" VARCHAR(30) NOT NULL,
 "governorate" VARCHAR(100) NOT NULL, "city" VARCHAR(100) NOT NULL,
 "streetAddress" VARCHAR(500) NOT NULL, "buildingDetails" VARCHAR(200) NOT NULL,
 "deliveryNotes" VARCHAR(1000) NOT NULL DEFAULT '', "isDefault" BOOLEAN NOT NULL DEFAULT false,
 "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
 CONSTRAINT "ShippingAddress_pkey" PRIMARY KEY ("id"),
 CONSTRAINT "ShippingAddress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "ShippingAddress_userId_idx" ON "ShippingAddress"("userId");
CREATE UNIQUE INDEX "ShippingAddress_one_default_per_user" ON "ShippingAddress"("userId") WHERE "isDefault" = true;
ALTER TABLE "Order" ADD COLUMN "shippingSnapshot" JSONB;
ALTER TABLE "OrderItem" ADD COLUMN "productImage" VARCHAR(512);

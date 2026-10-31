-- Retain old variant rows and historical order sizes; only availability changes.
ALTER TABLE "ProductSize" ADD COLUMN "isAvailable" BOOLEAN NOT NULL DEFAULT true;
UPDATE "ProductSize" SET "isAvailable" = false
WHERE "productId" = 'shoulder-bag' AND "size" IN ('S', 'M', 'L');
INSERT INTO "ProductSize" ("id", "productId", "size", "isAvailable")
SELECT gen_random_uuid(), "id", 'ONE_SIZE', true FROM "Product" WHERE "id" = 'shoulder-bag'
ON CONFLICT ("productId", "size") DO UPDATE SET "isAvailable" = true;

-- Add structures; retain ProductSize and all original historical snapshots.
ALTER TABLE "Product" ADD COLUMN "isDemo" BOOLEAN NOT NULL DEFAULT false,
 ADD COLUMN "isFeatured" BOOLEAN NOT NULL DEFAULT false,
 ADD COLUMN "defaultColorKey" VARCHAR(60);
CREATE TABLE "ProductColor" (
 "id" VARCHAR(160) PRIMARY KEY, "productId" VARCHAR(80) NOT NULL REFERENCES "Product"("id") ON DELETE RESTRICT,
 "key" VARCHAR(60) NOT NULL, "name" VARCHAR(80) NOT NULL, "hex" CHAR(7) NOT NULL, "sortOrder" INTEGER NOT NULL DEFAULT 0,
 UNIQUE ("productId", "key")
);
CREATE TABLE "ProductVariant" (
 "id" VARCHAR(160) PRIMARY KEY, "productId" VARCHAR(80) NOT NULL REFERENCES "Product"("id") ON DELETE RESTRICT,
 "colorId" VARCHAR(160) REFERENCES "ProductColor"("id") ON DELETE RESTRICT,
 "size" "ProductSizeValue" NOT NULL, "isAvailable" BOOLEAN NOT NULL DEFAULT true, "priceInCents" INTEGER,
 CONSTRAINT "ProductVariant_price_nonnegative" CHECK ("priceInCents" IS NULL OR "priceInCents" >= 0),
 UNIQUE ("productId", "colorId", "size")
);
CREATE INDEX "ProductVariant_productId_isAvailable_idx" ON "ProductVariant"("productId", "isAvailable");
CREATE UNIQUE INDEX "ProductVariant_colorless_size" ON "ProductVariant"("productId", "size") WHERE "colorId" IS NULL;
CREATE TABLE "ProductMedia" (
 "id" VARCHAR(180) PRIMARY KEY, "productId" VARCHAR(80) NOT NULL REFERENCES "Product"("id") ON DELETE RESTRICT,
 "colorId" VARCHAR(160) REFERENCES "ProductColor"("id") ON DELETE RESTRICT, "path" VARCHAR(512) NOT NULL,
 "kind" VARCHAR(20) NOT NULL DEFAULT 'photo', "label" VARCHAR(200) NOT NULL, "sortOrder" INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX "ProductMedia_productId_colorId_sortOrder_idx" ON "ProductMedia"("productId", "colorId", "sortOrder");
ALTER TABLE "OrderItem" ADD COLUMN "variantId" VARCHAR(160), ADD COLUMN "colorId" VARCHAR(160), ADD COLUMN "colorName" VARCHAR(80);
-- Colors visually checked against the existing four bundled photographs.
INSERT INTO "ProductColor" ("id","productId","key","name","hex")
SELECT "id" || ':' || CASE "id" WHEN 'knit-sweater' THEN 'cream' WHEN 'wide-leg-trousers' THEN 'sand' ELSE 'black' END,
 "id", CASE "id" WHEN 'knit-sweater' THEN 'cream' WHEN 'wide-leg-trousers' THEN 'sand' ELSE 'black' END,
 CASE "id" WHEN 'knit-sweater' THEN 'Cream' WHEN 'wide-leg-trousers' THEN 'Sand' ELSE 'Black' END,
 CASE "id" WHEN 'knit-sweater' THEN '#E9DECA' WHEN 'wide-leg-trousers' THEN '#B6A386' ELSE '#252320' END
FROM "Product" WHERE "id" IN ('knit-sweater','wide-leg-trousers','tailored-blazer','shoulder-bag');
UPDATE "Product" SET "defaultColorKey" = CASE "id" WHEN 'knit-sweater' THEN 'cream' WHEN 'wide-leg-trousers' THEN 'sand' ELSE 'black' END,
 "isDemo" = true WHERE "id" IN ('knit-sweater','wide-leg-trousers','tailored-blazer','shoulder-bag');
-- Copy IDs, sizes and availability; do not replace legacy ProductSize identifiers.
INSERT INTO "ProductVariant" ("id","productId","colorId","size","isAvailable")
SELECT s."id"::text, s."productId", c."id", s."size", s."isAvailable" FROM "ProductSize" s
LEFT JOIN "ProductColor" c ON c."productId" = s."productId" WHERE s."isAvailable" = true;
INSERT INTO "ProductMedia" ("id","productId","colorId","path","kind","label")
SELECT p."id" || ':original', p."id", c."id", p."image", 'photo', 'Existing bundled product photograph'
FROM "Product" p LEFT JOIN "ProductColor" c ON c."productId" = p."id";

-- Reclassify only the original bag; keep the Accessories category and its records.
INSERT INTO "Category" ("id","slug","name","updatedAt") VALUES (gen_random_uuid(),'bags','Bags',CURRENT_TIMESTAMP) ON CONFLICT ("slug") DO NOTHING;
UPDATE "Product" p SET "categoryId" = (SELECT "id" FROM "Category" WHERE "slug"='bags')
WHERE p."id"='shoulder-bag' AND p."categoryId"=(SELECT "id" FROM "Category" WHERE "slug"='accessories');
ALTER TABLE "ProductColor" ADD CONSTRAINT "ProductColor_identity_product" UNIQUE ("id","productId");
ALTER TABLE "ProductVariant" ADD CONSTRAINT "ProductVariant_color_product" FOREIGN KEY ("colorId","productId") REFERENCES "ProductColor"("id","productId") ON DELETE RESTRICT;
ALTER TABLE "ProductMedia" ADD CONSTRAINT "ProductMedia_color_product" FOREIGN KEY ("colorId","productId") REFERENCES "ProductColor"("id","productId") ON DELETE RESTRICT;

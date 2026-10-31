-- Optional editorial information only; no manufacturer measurements/composition invented.
ALTER TABLE "Product" ADD COLUMN "description" VARCHAR(2000),
 ADD COLUMN "materials" VARCHAR(1000), ADD COLUMN "careInstructions" VARCHAR(1000),
 ADD COLUMN "sizeAndFit" VARCHAR(1000), ADD COLUMN "informationIsSample" BOOLEAN NOT NULL DEFAULT false;
UPDATE "Product" SET
 "description" = 'Sample catalog item for the MODA portfolio demonstration. Product photography and names illustrate the shopping experience; this is not a manufacturer specification.',
 "materials" = 'Manufacturer composition has not been verified for this demonstration item.',
 "careInstructions" = 'Care specifications are not supplied. For a real product, follow its manufacturer care label.',
 "sizeAndFit" = CASE WHEN "id" = 'shoulder-bag'
 THEN 'One Size is the available variant label. Dimensions and capacity have not been verified.'
 ELSE 'S, M and L are catalog variant labels. Measurements and fit have not been verified; no size chart is claimed.' END,
 "informationIsSample" = true
WHERE "id" IN ('knit-sweater', 'wide-leg-trousers', 'tailored-blazer', 'shoulder-bag');

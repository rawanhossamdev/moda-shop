import fs from 'node:fs';
import {products} from '../backend/prisma/catalog.js';
const quote = text => "'" + text.replaceAll("'", "''") + "'";
let sql = 'BEGIN;\n-- Replace only app-owned demo presentation assets. Preserve all rows, variants and order snapshots.\n';
const legacyPhotos={ 'knit-sweater':'knit_sweater','wide-leg-trousers':'wide_leg_trousers','tailored-blazer':'tailored_blazer','shoulder-bag':'shoulder_bag' };
for (const product of products) {
 const id=quote(product.id);
 const oldPaths=product.colors.flatMap(c=>['front','detail'].map(view=>`assets/images/catalog/${product.id}_${c.key}_${view}.png`));
 if(legacyPhotos[product.id])oldPaths.push(`assets/images/${legacyPhotos[product.id]}.png`);
 sql+=`\nUPDATE "Product" SET "image"=${quote(product.image)} WHERE "id"=${id} AND "isDemo"=true AND "image" IN (${oldPaths.map(quote).join(',')});\n`;
 sql+=`UPDATE "ProductMedia" m SET "kind"=CASE WHEN m."kind"='illustration' THEN 'archived_art' ELSE 'archived_photo' END WHERE m."productId"=${id} AND m."path" IN (${oldPaths.map(quote).join(',')}) AND m."kind" IN ('illustration','photo') AND EXISTS (SELECT 1 FROM "Product" p WHERE p."id"=m."productId" AND p."isDemo"=true);\n`;
 for(const color of product.colors)for(const media of color.images) {
  sql+=`INSERT INTO "ProductMedia" ("id","productId","colorId","path","kind","label","sortOrder") SELECT ${[media.id,product.id,color.id,media.path,media.kind,media.label].map(quote).join(',')},${media.sortOrder} FROM "Product" p JOIN "ProductColor" c ON c."productId"=p."id" WHERE p."id"=${id} AND p."isDemo"=true AND c."id"=${quote(color.id)} ON CONFLICT ("id") DO NOTHING;\n`;
 }
}
const directory=new URL('../backend/prisma/migrations/20261030050000_demo_product_photography/',import.meta.url);
sql+='\nCOMMIT;\n';
fs.mkdirSync(directory,{recursive:true});fs.writeFileSync(new URL('migration.sql',directory),sql);
console.log('Generated non-destructive demo presentation migration.');

import fs from 'node:fs';
import { products, categories } from '../backend/prisma/catalog.js';
const root = new URL('../', import.meta.url);
const historical = fs.readdirSync(new URL('assets/images/catalog/',root)).filter(p=>p.endsWith('.png')).map(p=>'assets/images/catalog/'+p);
const originals = ['knit_sweater','wide_leg_trousers','tailored_blazer','shoulder_bag'].map(p=>'assets/images/'+p+'.png');
const assets = [...historical,...originals,...new Set(products.flatMap(p => [p.image, ...p.colors.flatMap(c => c.images.map(i => i.path))]))];
fs.writeFileSync(new URL('lib/data/catalog_assets.dart', root), '// Generated from the approved bundled demo catalog.\nconst catalogAssets = <String>{\n' + assets.map(p => '  ' + JSON.stringify(p) + ',').join('\n') + '\n};\n');
const fixture = products.map((p,index) => ({...p, currency:'USD', category:{...categories.find(c=>c.slug===p.categorySlug),id:p.categorySlug},
  defaultColorId:p.colors[0]?.id ?? null, images:[], createdAt:new Date(Date.UTC(2026,9,30,0,index)).toISOString()}));
fs.writeFileSync(new URL('test/support/catalog_fixture.json',root),JSON.stringify(fixture,null,2)+'\n');
if (process.argv.includes('--art')) fs.writeFileSync(new URL('.catalog-art.json',root),JSON.stringify(products));
console.log(`Generated catalog asset allowlist and ${products.length} API fixtures.`);

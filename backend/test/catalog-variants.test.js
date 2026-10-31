import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { products } from '../prisma/catalog.js';
import { seedCatalog } from '../prisma/seed-catalog.js';
import { cartInput, calculateQuote, orderInput } from '../src/services/checkout.service.js';
import { readCommerceConfig } from '../src/config/commerce.js';

const record = id => {
  const p=products.find(p=>p.id===id);
  return {...p,isActive:true,currency:'USD',sizes:p.availableSizes.map(size=>({size,isAvailable:true})),colors:p.colors.map(c=>({...c,media:c.images}))};
};
const config = readCommerceConfig({ SHIPPING_FEE_CENTS:'200' });

test('One-size variant validation rejects clothing sizes even when legacy size rows are stale', () => {
  const bag = record('shoulder-bag');
  bag.variants = bag.variants.map(v => ({...v}));
  bag.sizes = ['S','M','L','ONE_SIZE'].map(size => ({ size, isAvailable: true }));
  const one = bag.variants.find(v => v.isAvailable);
  const line = {productId:bag.id, size:'ONE_SIZE', variantId:one.id, quantity:2};
  const quoted = calculateQuote(cartInput([line]), [bag], config);
  assert.equal(quoted.items[0].size, 'ONE_SIZE');
  assert.equal(quoted.subtotalInCents, 13000);
  for (const size of ['S','M','L']) {
    assert.throws(() => calculateQuote([{...line,size}], [bag], config), {code:'CART_UNAVAILABLE'});
    assert.throws(() => calculateQuote([{productId:bag.id,size,quantity:1}], [bag], config), {code:'CART_UNAVAILABLE'});
  }
  bag.variants.forEach(v => { v.isAvailable = false; });
  assert.throws(() => calculateQuote([line], [bag], config), {code:'CART_UNAVAILABLE'});
});

test('Only available color/size combinations are quoted, with server-selected images and price', () => {
  const sweater=record('knit-sweater');
  const cream=sweater.variants.find(v=>v.colorId.endsWith(':cream')&&v.size==='M');
  const mocha=sweater.variants.find(v=>v.colorId.endsWith(':mocha')&&v.size==='L');
  const lines=cartInput([{productId:sweater.id,variantId:cream.id,size:'M',quantity:1}, {productId:sweater.id,variantId:mocha.id,size:'L',quantity:2}]);
  const quote=calculateQuote(lines,[sweater],config);
  assert.equal(quote.totalInCents,10700);
  assert.deepEqual(new Set(quote.items.map(i=>i.colorName)),new Set(['Cream','Mocha']));
  assert.equal(quote.items.find(i=>i.colorName==='Cream').productImage,sweater.image);
  assert.match(quote.items.find(i=>i.colorName==='Mocha').productImage,/_mocha_/);
  const bad=sweater.variants.find(v=>v.colorId.endsWith(':mocha')&&v.size==='M');
  for (const changes of [{variantId:bad.id,size:'M'}, {variantId:cream.id,size:'L'}, {variantId:'other-product:cream:M',size:'M'}, {variantId:cream.id,size:'M',colorId:'wrong-color'}]) {
    assert.throws(()=>calculateQuote([{productId:sweater.id,quantity:1,...changes}],[sweater],config),{code:'CART_UNAVAILABLE'});
  }
  assert.throws(()=>cartInput([lines[0],lines[0]]),{code:'INVALID_CART'});
  assert.throws(()=>calculateQuote([{productId:sweater.id,size:'M',quantity:1},lines[0]],[sweater],config),{code:'INVALID_CART'});
  const override={...sweater,variants:sweater.variants.map(v=>v.id===cream.id?{...v,priceInCents:4000}:v)};
  assert.equal(calculateQuote([{...lines[0],priceInCents:1}],[override],config).subtotalInCents,4000);
});

test('Shoe sizes, one-size jewelry, image-less colors and colorless legacy data are valid without false images', () => {
  const shoe=record('classic-loafers'), jewelry=record('pendant-necklace'), bag=record('shoulder-bag');
  const shoeVariant=shoe.variants.find(v=>v.size==='EU_39'&&v.colorId.endsWith(':brown'));
  bag.colors.find(c=>c.key==='brown').media=[]; // Controlled missing-image fixture.
  const brown=bag.variants.find(v=>v.colorId.endsWith(':brown'));
  const quoted=calculateQuote(cartInput([{productId:shoe.id,size:'EU_39',variantId:shoeVariant.id,quantity:1},
    {productId:bag.id,size:'ONE_SIZE',variantId:brown.id,quantity:1}, {productId:jewelry.id,size:'ONE_SIZE',quantity:1}]),[shoe,jewelry,bag],config);
  assert.equal(quoted.items.find(i=>i.productId===bag.id).productImage,null);
  assert.equal(quoted.items.find(i=>i.productId===bag.id).colorName,'Brown');
  assert.equal(quoted.items.find(i=>i.productId===jewelry.id).size,'ONE_SIZE');
  assert.throws(()=>cartInput([{productId:shoe.id,size:'EU_43',quantity:1}]),{code:'INVALID_CART'});
  assert.throws(()=>calculateQuote([{productId:shoe.id,size:'M',quantity:1}],[shoe],config),{code:'CART_UNAVAILABLE'});
  const legacy={id:'legacy',name:'Legacy',isActive:true,currency:'USD',priceInCents:1000,sizes:[{size:'M'}],variants:[],colors:[],image:'old.png'};
  assert.equal(calculateQuote([{productId:'legacy',size:'M',quantity:1}],[legacy],config).items[0].productImage,'old.png');
});

test('Legacy pending checkout bodies retain the same request hash; new variant IDs distinguish requests', () => {
  const body={addressId:randomUUID(),clientRequestId:randomUUID(),paymentMethod:'COD',expectedTotalInCents:3700,items:[{productId:'knit-sweater',size:'M',quantity:1}]};
  const legacy={items:body.items,addressId:body.addressId,paymentMethod:'COD',expectedTotalInCents:3700};
  assert.equal(orderInput(body,config).requestHash,createHash('sha256').update(JSON.stringify(legacy)).digest('hex'));
  const variant=record('knit-sweater').variants[1];
  const next=orderInput({...body,items:[{...body.items[0],variantId:variant.id}]},config);
  assert.notEqual(next.requestHash,orderInput(body,config).requestHash);
});

function seedFixture() {
  const tables={};
  for (const name of ['category','product','productColor','productVariant','productMedia','productSize']) tables[name]=[];
  let sequence=0;
  const matches=(row,where)=>Object.entries(where).every(([key,value])=>typeof value==='object'?matches(row,value):row[key]===value);
  const tx=Object.fromEntries(Object.entries(tables).map(([name,rows])=>[name,{
    async findUnique({where}) {return rows.find(row=>matches(row,where))??null;},
    async upsert({where,create,update}) {let row=rows.find(row=>matches(row,where)); if(row)Object.assign(row,update);else{row={id:`synthetic-${++sequence}`,isAvailable:true,...create};rows.push(row);}return row;},
  }]));
  return {tables,tx};
}

test('Create-only seed is repeatable and preserves owner collisions, prices, IDs and retired variants', async () => {
  const {tables,tx}=seedFixture();
  tables.product.push({id:'relaxed-shirt',isDemo:false,name:'Owner record',priceInCents:9999});
  tables.product.push({id:'knit-sweater',isDemo:true,name:'Existing sweater',priceInCents:1234});
  tables.productSize.push({id:'original-size-id',productId:'knit-sweater',size:'M',isAvailable:false});
  await seedCatalog(tx);
  const first=JSON.stringify(tables);
  await seedCatalog(tx);
  assert.equal(JSON.stringify(tables),first);
  assert.equal(tables.product.length,24);
  assert.equal(tables.category.length,5);
  assert.equal(tables.product.find(p=>p.id==='relaxed-shirt').priceInCents,9999);
  assert.equal(tables.product.find(p=>p.id==='knit-sweater').priceInCents,1234);
  assert.equal(tables.productVariant.find(v=>v.id==='original-size-id').isAvailable,false);
  assert.ok(!tables.productVariant.some(v=>v.productId==='relaxed-shirt'));
  assert.equal(new Set(tables.productVariant.map(v=>v.id)).size,tables.productVariant.length);
});

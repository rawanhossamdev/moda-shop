// Real PostgreSQL checks. All synthetic account/order writes ALWAYS roll back.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { getDatabase, disconnectDatabase } from '../src/config/database.js';
import { seedCatalog } from '../prisma/seed-catalog.js';
import { products as catalog } from '../prisma/catalog.js';
import { createOrdersRepository } from '../src/repositories/orders.repository.js';
import { createAddressesRepository } from '../src/repositories/addresses.repository.js';
import { addressInput } from '../src/services/address.service.js';
import { cartInput, orderInput } from '../src/services/checkout.service.js';
import { readCommerceConfig } from '../src/config/commerce.js';

const db=getDatabase(), rollback=new Error('Expected synthetic verification rollback');
const counts=async client=>{const values=[];for(const table of ['user','shippingAddress','order','orderItem','product','productSize','productColor','productVariant','productMedia'])values.push(await client[table].count());return values;};
try {
  const before=await counts(db);
  try {
    await db.$transaction(async tx=>{
      const originals=await tx.product.findMany({orderBy:{id:'asc'},select:{id:true,name:true,priceInCents:true,image:true,categoryId:true}});
      const sizeIds=await tx.productSize.findMany({orderBy:{id:'asc'}});
      const variantIds=await tx.productVariant.findMany({orderBy:{id:'asc'}});
      const once=await seedCatalog(tx), afterOnce=await counts(tx);
      await seedCatalog(tx);
      assert.equal(once.products,24);
      assert.deepEqual(await counts(tx),afterOnce);
      assert.deepEqual(await tx.product.findMany({orderBy:{id:'asc'},select:{id:true,name:true,priceInCents:true,image:true,categoryId:true}}),originals);
      assert.deepEqual(await tx.productSize.findMany({orderBy:{id:'asc'}}),sizeIds);
      assert.deepEqual(await tx.productVariant.findMany({orderBy:{id:'asc'}}),variantIds);
      assert.equal(await tx.product.count({where:{id:{in:catalog.map(p=>p.id)}}}),24);
      const bag=await tx.product.findUnique({where:{id:'shoulder-bag'},include:{sizes:true,variants:true,colors:{orderBy:{sortOrder:'asc'},include:{media:{orderBy:{sortOrder:'asc'}}}}}});
      for(const size of bag.sizes.filter(s=>s.isAvailable)) assert.equal(bag.variants.find(v=>v.size===size.size&&v.colorId.endsWith(':black')).id,size.id);
      let sequence=0;
      const adapter=new Proxy(tx,{get(target,key){return key==='$transaction'?async action=>{
        const point=`catalog_check_${++sequence}`;
        await target.$executeRawUnsafe(`SAVEPOINT ${point}`);
        try{const value=await action(target);await target.$executeRawUnsafe(`RELEASE SAVEPOINT ${point}`);return value;}
        catch(error){await target.$executeRawUnsafe(`ROLLBACK TO SAVEPOINT ${point}`);await target.$executeRawUnsafe(`RELEASE SAVEPOINT ${point}`);throw error;}
      }:Reflect.get(target,key);}});
      const user=await tx.user.create({data:{email:`catalog-${randomUUID()}@example.test`,name:'Synthetic catalog check',emailVerifiedAt:new Date()}});
      const address=await createAddressesRepository(()=>adapter).save(user.id,addressInput({fullName:'Synthetic member',mobile:'01012345678',governorate:'Cairo',city:'Maadi',streetAddress:'25 Test street',buildingDetails:'Apartment 4'}));
      const repo=createOrdersRepository(()=>adapter),config=readCommerceConfig({SHIPPING_FEE_CENTS:'200'});
      const shoe=await tx.product.findUnique({where:{id:'classic-loafers'},include:{variants:true}});
      const selected=[bag.variants.find(v=>v.colorId.endsWith(':black')&&v.isAvailable),bag.variants.find(v=>v.colorId.endsWith(':brown')&&v.isAvailable),shoe.variants.find(v=>v.size==='EU_39'&&v.isAvailable)];
      const items=cartInput(selected.map(v=>({productId:v.productId,variantId:v.id,colorId:v.colorId,size:v.size,quantity:1})));
      const quote=await repo.quote(items,config);
      assert.match(quote.items.find(i=>i.colorName==='Brown').productImage,/shoulder-bag_brown_front.jpg$/);
      const body={clientRequestId:randomUUID(),addressId:address.id,paymentMethod:'COD',items,expectedTotalInCents:quote.totalInCents};
      const input=orderInput(body,config),order=await repo.create(user.id,input,config);
      assert.equal(order.status,'PENDING');assert.equal(order.paymentStatus,'UNPAID');
      assert.equal(order.items.length,3);assert.ok(order.items.every(i=>i.variantId&&i.colorName));
      assert.ok(order.items.some(i=>i.size==='EU_39'));
      assert.equal((await repo.create(user.id,input,config)).id,order.id);
      assert.match((await repo.detail(order.id,user.id)).items.find(i=>i.colorName==='Brown').productImage,/shoulder-bag_brown_front.jpg$/);
      await assert.rejects(repo.findRequest(randomUUID(),body.clientRequestId),{code:'ORDER_NOT_FOUND'});
      const bad=shoe.variants.find(v=>v.size==='EU_38'&&!v.isAvailable);
      await assert.rejects(repo.quote(cartInput([{productId:shoe.id,variantId:bad.id,size:'EU_38',quantity:1}]),config),{code:'CART_UNAVAILABLE'});
      const legacyItems=[{productId:bag.id,size:'ONE_SIZE',quantity:1}];
      const legacyQuote=await repo.quote(legacyItems,config);
      const legacyInput=orderInput({...body,clientRequestId:randomUUID(),items:legacyItems,expectedTotalInCents:legacyQuote.totalInCents},config);
      const legacy=await repo.create(user.id,legacyInput,config);
      assert.equal(legacy.items[0].colorName,'Black');
      assert.equal(legacy.items[0].variantId,bag.sizes.find(s=>s.size==='ONE_SIZE').id);
      assert.equal((await repo.create(user.id,legacyInput,config)).id,legacy.id);
      throw rollback;
    },{timeout:60000});
  }catch(error){if(error!==rollback)throw error;}
  assert.deepEqual(await counts(db),before);
  console.log('Expanded catalog verified: 24 products, five categories, repeatable create-only seed, unchanged legacy IDs/prices, valid colors/footwear, immutable snapshots, color-specific photography and idempotent COD. All synthetic writes rolled back; existing counts unchanged.');
}catch(error){console.error(`Expanded catalog verification failed (${error.code??error.name}). No private values printed.`);process.exitCode=1;}
finally{await disconnectDatabase();}

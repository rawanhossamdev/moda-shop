// Original demo assortment: sample USD prices and availability, not real inventory.
export const categories = ['Clothing','Bags','Shoes','Jewelry','Accessories'].map(name => ({name, slug: name.toLowerCase()}));
export const sizes = ['S', 'M', 'L'];
export const footwearSizes = ['EU_36','EU_37','EU_38','EU_39','EU_40','EU_41','EU_42'];
const palette = {
 cream:['Cream','#E9DECA'], sand:['Sand','#B6A386'], black:['Black','#252320'], mocha:['Mocha','#8B6C57'],
 charcoal:['Charcoal','#4A4A49'], camel:['Camel','#BA936B'], brown:['Brown','#76513C'], white:['White','#F1EFE9'],
 navy:['Navy','#29384C'], rose:['Dusty Rose','#B88783'], blue:['Denim Blue','#657C92'], gold:['Gold tone','#B69B57'],
 silver:['Silver tone','#A8ACB0'], olive:['Olive','#7D8164'], burgundy:['Burgundy','#784349'],
};
function product(id,name,categorySlug,priceInCents,type,colorKeys,availableSizes=sizes,featured=false) {
 const colors = colorKeys.map((key,index) => ({ id:`${id}:${key}`, key, name:palette[key][0], hex:palette[key][1], sortOrder:index,
  images: ['front', ...(index===0 ? ['side','detail'] : [])].map((view,rank)=>({
    id:`${id}:${key}:photo:${view}`,path:`assets/images/photography/${id}_${key}_${view}.jpg`,
    kind:'ai_photo',label:`${palette[key][0]} / AI-generated demo product / ${view}`,sortOrder:rank,
  })),
 }));
 return {id,name,categorySlug,priceInCents,type,isDemo:true,isFeatured:featured,defaultColorKey:colorKeys[0],colors,availableSizes,image:colors[0].images[0].path,
  description:`${name} is a sample styling piece in the MODA portfolio assortment. Prices and color/size availability are demonstration data, not real store inventory.`,
  materials:'Sample catalog: manufacturer composition and construction have not been independently verified.',
  careInstructions:'No manufacturer care specification is supplied. For a real item, consult its actual care label.',
  sizeAndFit:categorySlug==='shoes'?'EU 36-42 are demonstration footwear labels, not verified measurements or a fit guarantee.':availableSizes.includes('ONE_SIZE')?'One Size is a variant label. Dimensions, capacity and fit have not been verified.':'S/M/L are demonstration size labels. Measurements and fit have not been verified.',
  informationIsSample:true,
  variants:colors.flatMap((color,colorIndex)=>availableSizes.map(size=>({id:`${id}:${color.key}:${size}`,colorId:color.id,size,isAvailable:!(colorIndex===1 && (size==='M'||size==='EU_38'))}))),
 };
}
export const products = [
 product('knit-sweater','Ribbed Knit Sweater','clothing',3500,'sweater',['cream','mocha'],sizes,true),
 product('wide-leg-trousers','Wide Leg Trousers','clothing',5500,'trousers',['sand','charcoal']),
 product('tailored-blazer','Tailored Blazer','clothing',8500,'blazer',['black','camel'],sizes,true),
 product('shoulder-bag','Shoulder Bag','bags',6500,'bag',['black','brown'],['ONE_SIZE'],true),
 product('relaxed-shirt','Relaxed Button Shirt','clothing',4200,'shirt',['white','blue']),
 product('pleated-midi-skirt','Pleated Midi Skirt','clothing',5800,'skirt',['sand','navy']),
 product('wrap-midi-dress','Wrap Midi Dress','clothing',7900,'dress',['rose','black'],sizes,true),
 product('straight-leg-jeans','Straight Leg Jeans','clothing',6200,'trousers',['blue','charcoal']),
 product('longline-coat','Longline City Coat','clothing',12500,'coat',['camel','black']),
 product('structured-tote','Structured Everyday Tote','bags',7200,'tote',['brown','black'],['ONE_SIZE']),
 product('crescent-crossbody','Crescent Crossbody Bag','bags',5900,'bag',['cream','burgundy'],['ONE_SIZE']),
 product('mini-evening-bag','Mini Evening Bag','bags',4800,'bag',['black','rose'],['ONE_SIZE']),
 product('classic-loafers','Classic City Loafers','shoes',8900,'loafers',['black','brown'],footwearSizes,true),
 product('court-sneakers','Everyday Court Sneakers','shoes',7600,'sneakers',['white','sand'],footwearSizes),
 product('slingback-flats','Slingback Ballet Flats','shoes',6800,'flats',['rose','black'],footwearSizes),
 product('ankle-boots','Essential Ankle Boots','shoes',10900,'boots',['black','brown'],footwearSizes),
 product('sculpted-hoops','Sculpted Hoop Earrings','jewelry',2900,'earrings',['gold','silver'],['ONE_SIZE']),
 product('pendant-necklace','Minimal Pendant Necklace','jewelry',3400,'necklace',['gold'],['ONE_SIZE']),
 product('chain-bracelet','Modern Chain Bracelet','jewelry',2700,'bracelet',['silver','gold'],['ONE_SIZE']),
 product('stacking-ring-set','Sculptural Ring Set','jewelry',3100,'rings',['gold'],['ONE_SIZE']),
 product('printed-scarf','Geometric Square Scarf','accessories',2500,'scarf',['navy','olive'],['ONE_SIZE']),
 product('slim-belt','Minimal Everyday Belt','accessories',3200,'belt',['black','brown'],['ONE_SIZE']),
 product('frame-sunglasses','Sculpted Frame Sunglasses','accessories',3900,'glasses',['black','brown'],['ONE_SIZE']),
 product('ribbed-beanie','Ribbed Everyday Beanie','accessories',2200,'beanie',['cream','charcoal'],['ONE_SIZE']),
];

// Integrity checks only. Passing cannot establish a copyright or likeness right.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
const hash=file=>createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const registry=JSON.parse(fs.readFileSync('assets/images/PUBLICATION_REPLACEMENTS.json'));
const catalog=JSON.parse(fs.readFileSync('assets/images/photography/PROVENANCE.json'));
let failures=0;
for(const row of [...registry.replacements,...registry.screenshots,...catalog.map(row=>({...row,path:row.asset}))]) {
  if(!fs.existsSync(row.path)||hash(row.path)!==row.sha256){console.log(JSON.stringify({file:row.path,rule:'asset-hash-mismatch'}));failures++;}
  if(row.previousSha256 && row.previousSha256===row.sha256){console.log(JSON.stringify({file:row.path,rule:'replacement-did-not-change'}));failures++;}
}
const screenshotMetadata=[];
for(const name of ['home','catalog','product','variants']) {
  const data=fs.readFileSync(`docs/screenshots/${name}.png`);
  let offset=8;
  while(offset+12<=data.length){const length=data.readUInt32BE(offset),type=data.toString('ascii',offset+4,offset+8);if(['tEXt','zTXt','iTXt','eXIf'].includes(type))screenshotMetadata.push({name,type});offset+=length+12;}
}
console.log(JSON.stringify({replacementsChecked:registry.replacements.length,catalogPhotosChecked:catalog.length,screenshotMetadata,integrityFailures:failures,rightsClearance:'not-inferred-from-hashes; see owner approvals in docs/IMAGE_PROVENANCE.md'}));
if(failures||screenshotMetadata.length)process.exitCode=1;

// Extract only the two official Web templates from the release ZIP using HTTP ranges.
import {mkdir, writeFile} from 'node:fs/promises';
import {inflateRawSync} from 'node:zlib';
import path from 'node:path';
const version = process.argv[2] || '4.7.2';
if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error('Invalid version');
const url = `https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_export_templates.tpz`;
const dest = path.resolve('.tools', 'godot-templates', version);
const redirect = await fetch(url);
const assetUrl = redirect.url;
const totalSize = Number(redirect.headers.get('content-length'));
await redirect.body?.cancel();
if (!Number.isSafeInteger(totalSize) || totalSize < 65536) throw new Error('Official ZIP size unavailable');
async function range(start, end) {
  if (start < 0) {start = totalSize + start; end = totalSize - 1;}
  const response = await fetch(assetUrl, {headers:{Range:start < 0 ? `bytes=${start}` : `bytes=${start}-${end}`}});
  if (response.status !== 206) {await response.body?.cancel(); throw new Error(`Server does not support range downloads (${response.status}). Download the official .tpz and extract web_nothreads_debug.zip and web_nothreads_release.zip to ${dest}.`);}
  return {bytes:Buffer.from(await response.arrayBuffer()),total:Number(response.headers.get('content-range').split('/')[1])};
}
const tail = await range(-65536, '');
let eocd = tail.bytes.length - 22;
while (eocd >= 0 && tail.bytes.readUInt32LE(eocd) !== 0x06054b50) eocd--;
if (eocd < 0) throw new Error('ZIP directory not found');
const size = tail.bytes.readUInt32LE(eocd+12);
const offset = tail.bytes.readUInt32LE(eocd+16);
const directory = (await range(offset,offset+size-1)).bytes;
const entries = [];
for(let p=0; p<directory.length;) {
  if(directory.readUInt32LE(p)!==0x02014b50) throw new Error('Invalid ZIP directory');
  const nameLength=directory.readUInt16LE(p+28),extra=directory.readUInt16LE(p+30),comment=directory.readUInt16LE(p+32);
  const name=directory.subarray(p+46,p+46+nameLength).toString();
  if(/\/(web_nothreads_(debug|release)\.zip|version\.txt)$/.test(name)) entries.push({name,method:directory.readUInt16LE(p+10),crc:directory.readUInt32LE(p+16),size:directory.readUInt32LE(p+20),rawSize:directory.readUInt32LE(p+24),offset:directory.readUInt32LE(p+42)});
  p+=46+nameLength+extra+comment;
}
if(entries.filter(e=>e.name.endsWith('.zip')).length!==2) throw new Error('Matching single-threaded Web templates not found');
await mkdir(dest,{recursive:true});
const table=Array.from({length:256},(_,i)=>{let c=i;for(let b=0;b<8;b++)c=(c&1)?0xedb88320^(c>>>1):c>>>1;return c>>>0;});
function crc32(bytes){let c=0xffffffff;for(const b of bytes)c=table[(c^b)&255]^(c>>>8);return (c^0xffffffff)>>>0;}
for(const entry of entries) {
  const header=(await range(entry.offset,entry.offset+29)).bytes;
  if(header.readUInt32LE(0)!==0x04034b50)throw new Error('Invalid ZIP entry');
  const dataOffset=entry.offset+30+header.readUInt16LE(26)+header.readUInt16LE(28);
  const compressed=(await range(dataOffset,dataOffset+entry.size-1)).bytes;
  const data=entry.method===8?inflateRawSync(compressed):compressed;
  if(data.length!==entry.rawSize||crc32(data)!==entry.crc) throw new Error('Corrupted template');
  if(entry.name.endsWith('version.txt')&&data.toString().trim()!==version+'.stable')throw new Error('Template version mismatch');
  await writeFile(path.join(dest,path.basename(entry.name)),data);
  console.log(`Downloaded ${path.basename(entry.name)} (${data.length} bytes) from official Godot ${version}`);
}

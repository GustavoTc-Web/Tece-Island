// Read-only hosted provenance check. Credentials enter via hidden stdin only.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile,writeFile} from 'node:fs/promises';
if(process.stdin.isTTY)process.stdin.setRawMode(true);
console.log('Ready for private verification JSON on stdin (input is hidden).');
let input='';for await(const chunk of process.stdin){input+=chunk;if(/[\r\n]/.test(input))break;}
const request=JSON.parse(input);input='';
const origin=new URL(request.url);
assert.equal(origin.protocol,'https:');assert.ok(origin.hostname.endsWith('.chatgpt.site'));
assert.equal(origin.username,'');assert.equal(origin.password,'');
const headers={'OAI-Sites-Authorization':'Bearer '+request.token};request.token='';
const get=async name=>{
 const response=await fetch(new URL('/Tece-Island/'+name,origin),{headers,redirect:'manual',signal:AbortSignal.timeout(30000)});
 assert.equal(response.status,200,name);return response;
};
const expected=JSON.parse(await readFile('build/chat-pilot/pilot-build.json','utf8'));
const manifest=await(await get('pilot-build.json')).json();
assert.deepEqual(manifest,expected);
assert.equal(manifest.allowed_account_count,2);assert.equal(manifest.world_rules_unchanged,true);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const pck=hash(Buffer.from(await(await get('index.pck')).arrayBuffer()));
assert.equal(pck,hash(await readFile('build/chat-pilot/index.pck')));
await writeFile('.tools/private-pilot-live-verification.json',JSON.stringify({verified:true,url:origin.origin,manifest,pck_sha256:pck},null,2)+'\n');
console.log(JSON.stringify({verified:true,version:manifest.version,commit:manifest.commit,allowed_account_count:2,pck_sha256:pck}));

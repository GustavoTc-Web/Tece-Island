// Read-only public artifact verification; never authenticates to Firebase.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const url=process.env.TEST_URL||'https://gustavotc-web.github.io/Tece-Island/';
const output=process.env.VERIFIED_OUTPUT||'.tools/official-served';
const get=async name=>{const r=await fetch(new URL(name,url),{signal:AbortSignal.timeout(60000),cache:'no-store'});assert.equal(r.status,200,name);return r;};
const manifest=await(await get('version.json')).json();
assert.equal(manifest.version,'0.8.3');assert.match(manifest.commit,/^[a-f0-9]{40}$/);
if(process.env.EXPECTED_COMMIT)assert.equal(manifest.commit,process.env.EXPECTED_COMMIT);
assert.equal(manifest.allowed_account_count,2);assert.equal(manifest.chat_enabled,true);assert.equal(manifest.world_sync_enabled,true);
assert.equal(manifest.chat_transport,'rest_incremental_with_window_count');
assert.equal(manifest.chat_poll_seconds,5);assert.equal(manifest.chat_idle_poll_seconds,15);
assert.equal(manifest.chat_idle_after_seconds,60);assert.equal(manifest.chat_reconcile_seconds,120);assert.equal(manifest.world_sync_interval_seconds,120);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const [file,expected] of Object.entries(manifest.source_sha256)){
 const source=execFileSync('git',['show',manifest.commit+':'+file],{encoding:'utf8'}).replaceAll('\r\n','\n');
 assert.equal(hash(source),expected,file+' source hash');
}
await mkdir(output,{recursive:true});
for(const file of ['index.pck','index.js','index.wasm']){
 const bytes=Buffer.from(await(await get(file)).arrayBuffer());assert.equal(hash(bytes),manifest.sha256[file],file+' served package hash');
 await writeFile(output+'/'+file,bytes);
}
await writeFile(output+'/version.json',JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({verified:true,url,version:manifest.version,commit:manifest.commit,allowed_account_count:2,verified_files:['index.pck','index.js','index.wasm'],source_hashes_match:true},null,2));

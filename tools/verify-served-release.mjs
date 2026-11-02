// Read-only public artifact verification; never authenticates to Firebase.
import assert from 'node:assert/strict';
import {mkdir,writeFile,readFile,readdir} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const url=process.env.TEST_URL||'https://gustavotc-web.github.io/Tece-Island/';
const output=process.env.VERIFIED_OUTPUT||'.tools/official-served';
const get=async name=>{const r=await fetch(new URL(name,url),{signal:AbortSignal.timeout(60000),cache:'no-store'});assert.equal(r.status,200,name);return r;};
const manifest=await(await get('version.json')).json();
assert.equal(manifest.version,'0.9.1-beta.2');assert.match(manifest.commit,/^[a-f0-9]{40}$/);
assert.equal(manifest.approved_candidate,'0.9.1-beta.2-rc.1');
assert.equal(manifest.approved_game_commit,'2738a9f49fb5d390fdb6bbcfec06e2af54aeb358');
assert.equal(manifest.consolidation_commit,'0edc372942e741c567c03b0d091be9c2350bc7ea');
assert.equal(manifest.candidate,false);
assert.equal(manifest.save_schema,9);assert.equal(manifest.campaign_schema,2);assert.equal(manifest.tasks_schema,2);
assert.equal(manifest.multiplayer_available,false);assert.equal(manifest.public_solo,true);
assert.equal(manifest.public_chat,false);assert.equal(manifest.public_world_sync,false);
assert.equal(manifest.firestore_rules_deployed,false);assert.equal(manifest.chat_audience,'allowlist');
assert.equal(manifest.chat_allowed_account_count,2);assert.equal(manifest.world_sync_allowed_account_count,2);
if(process.env.EXPECTED_COMMIT)assert.equal(manifest.commit,process.env.EXPECTED_COMMIT);
assert.equal(manifest.allowed_account_count,2);assert.equal(manifest.chat_enabled,true);assert.equal(manifest.world_sync_enabled,true);
assert.equal(manifest.chat_transport,'rest_incremental_with_window_count');
assert.equal(manifest.chat_poll_seconds,5);assert.equal(manifest.chat_idle_poll_seconds,15);
assert.equal(manifest.chat_idle_after_seconds,60);assert.equal(manifest.chat_reconcile_seconds,120);assert.equal(manifest.world_sync_interval_seconds,120);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const [file,expected] of Object.entries(manifest.source_sha256)){
 const source=execFileSync('git',['-c','safe.directory='+process.cwd().replaceAll('\\','/'),'show',manifest.commit+':'+file],{encoding:'utf8'}).replaceAll('\r\n','\n');
 assert.equal(hash(source),expected,file+' source hash');
}
await mkdir(output,{recursive:true});
for(const file of ['index.pck','index.js','index.wasm']){
 const bytes=Buffer.from(await(await get(file)).arrayBuffer());assert.equal(hash(bytes),manifest.sha256[file],file+' served package hash');
 await writeFile(output+'/'+file,bytes);
}
await writeFile(output+'/version.json',JSON.stringify(manifest,null,2)+'\n');
// Compare every served file with the actual GitHub Pages artifact, when supplied.
const artifact=process.env.PAGES_ARTIFACT_DIRECTORY,verified=[];
if(artifact){
 for(const entry of await readdir(artifact,{recursive:true,withFileTypes:true})){
  if(!entry.isFile())continue;
  const relative=(entry.parentPath||entry.path).slice(artifact.length).replaceAll('\\','/').replace(/^\//,'');
  const file=(relative?relative+'/':'')+entry.name;
  const expected=await readFile(artifact+'/'+file);
  const actual=Buffer.from(await(await get(file)).arrayBuffer());
  assert.equal(hash(actual),hash(expected),file+' matches Pages artifact');
  await mkdir(output+'/'+file.split('/').slice(0,-1).join('/'),{recursive:true});
  await writeFile(output+'/'+file,actual);
  verified.push({file,bytes:actual.length,sha256:hash(actual)});
 }
}
const result={at:new Date().toISOString(),verified:true,url,version:manifest.version,commit:manifest.commit,allowed_account_count:2,source_hashes:Object.keys(manifest.source_sha256).length,source_hashes_match:true,files:verified,sha256:manifest.sha256,firebase_admin_writes:false,authenticated_game_test:false,physical:false};
await writeFile(output+'/verification.json',JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));

// Build configuration only. No Godot clients, authentication or Firebase calls.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,readFile,writeFile,cp} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
const root=process.cwd(),original=['original-a','original-b'];
async function fixture(){await mkdir('.tools',{recursive:true});return mkdtemp(path.join(root,'.tools/release-access-'));}
const run=(dir,script,extra={})=>spawnSync(process.execPath,[path.join(root,'tools',script)],{cwd:dir,encoding:'utf8',env:{...process.env,TECE_PILOT_ALLOWED_UIDS:original.join(','),TECE_CHAT_AUDIENCE:'allowlist',TECE_CHAT_ALLOWED_UIDS:'',...extra},windowsHide:true});
const json=async(dir,file)=>JSON.parse(await readFile(path.join(dir,file),'utf8'));
async function prepareManifest(dir){
 for(const file of ['scripts','web','firestore.rules'])await cp(path.join(root,file),path.join(dir,file),{recursive:true});
 await mkdir(path.join(dir,'build/web'),{recursive:true});
 for(const file of ['index.pck','index.js','index.wasm'])await writeFile(path.join(dir,'build/web',file),'metadata fixture, not a game build');
 await writeFile(path.join(dir,'config/build-public.json'),JSON.stringify({version:'0.9.1-beta-rc.2',commit:'7c254c1f8454d768228c171cf6fa040b5eb322dc',save_schema:9,campaign_schema:2,tasks_schema:2}));
}
test('default rollout preserves the original two accounts for both services',async()=>{
 const dir=await fixture();assert.equal(run(dir,'configure-release-access.mjs').status,0);
 assert.deepEqual((await json(dir,'config/global-chat.json')).allowed_uids,original);
 assert.deepEqual((await json(dir,'config/world-sync.json')).allowed_uids,original);
 await prepareManifest(dir);assert.equal(run(dir,'write-web-manifest.mjs').status,0);
 const manifest=await json(dir,'build/web/version.json');assert.equal(manifest.chat_audience,'allowlist');assert.equal(manifest.chat_allowed_account_count,2);assert.equal(manifest.world_sync_allowed_account_count,2);
});
test('inviting a verified chat account cannot expand the world-sync list',async()=>{
 const dir=await fixture();assert.equal(run(dir,'configure-release-access.mjs',{TECE_CHAT_ALLOWED_UIDS:'original-a,original-b,guest-new'}).status,0);
 assert.deepEqual((await json(dir,'config/global-chat.json')).allowed_uids,[...original,'guest-new']);
 assert.deepEqual((await json(dir,'config/world-sync.json')).allowed_uids,original);
 await prepareManifest(dir);assert.equal(run(dir,'write-web-manifest.mjs').status,0);
 const manifest=await json(dir,'build/web/version.json');assert.equal(manifest.chat_allowed_account_count,3);assert.equal(manifest.world_sync_allowed_account_count,2);assert.equal(manifest.allowed_account_count,2);
});
test('verified audience opens only the client chat policy, retaining two sync accounts',async()=>{
 const dir=await fixture();assert.equal(run(dir,'configure-release-access.mjs',{TECE_CHAT_AUDIENCE:'verified'}).status,0);
 assert.equal((await json(dir,'config/global-chat.json')).audience,'verified');
 assert.deepEqual((await json(dir,'config/world-sync.json')).allowed_uids,original);
 await prepareManifest(dir);assert.equal(run(dir,'write-web-manifest.mjs').status,0);
 const manifest=await json(dir,'build/web/version.json');assert.equal(manifest.chat_audience,'verified');assert.equal(manifest.chat_allowed_account_count,null);assert.equal(manifest.world_sync_allowed_account_count,2);
});
test('invalid, duplicate, missing original and mixed invitation policies are refused',async()=>{
 for(const extra of [{TECE_CHAT_ALLOWED_UIDS:'original-a,guest-new'},{TECE_CHAT_ALLOWED_UIDS:'original-a,original-b,guest-new,guest-new'},{TECE_CHAT_ALLOWED_UIDS:'original-a,original-b,bad/uid'},{TECE_CHAT_AUDIENCE:'everyone'},{TECE_CHAT_AUDIENCE:'verified',TECE_CHAT_ALLOWED_UIDS:'original-a,original-b,guest-new'},{TECE_PILOT_ALLOWED_UIDS:'original-a,original-b,guest-new'}]){
  assert.notEqual(run(await fixture(),'configure-release-access.mjs',extra).status,0);
 }
});
test('manifest rejects an accidentally expanded sync list even when chat includes it',async()=>{
 const dir=await fixture();assert.equal(run(dir,'configure-release-access.mjs',{TECE_CHAT_ALLOWED_UIDS:'original-a,original-b,guest-new'}).status,0);
 await prepareManifest(dir);const sync=await json(dir,'config/world-sync.json');sync.allowed_uids.push('guest-new');await writeFile(path.join(dir,'config/world-sync.json'),JSON.stringify(sync));
 assert.notEqual(run(dir,'write-web-manifest.mjs').status,0);
});

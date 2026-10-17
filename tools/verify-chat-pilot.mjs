// Read-only check of the combined private build and its save-sync provenance.
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const read=async path=>JSON.parse(await readFile(path,'utf8'));
const git=(...args)=>execFileSync('git',args,{encoding:'utf8'}).trim();
const normalize=s=>s.replaceAll('\r\n','\n');
const source='.tools/chat-pilot-project';
const chat=await read(source+'/config/global-chat.json'),sync=await read(source+'/config/world-sync.json');
const previous=await read('.tools/sync-real-project/config/world-sync.json');
const stamp=await read(source+'/config/build-public.json');
assert.equal(chat.enabled,true);assert.equal(sync.enabled,true);
assert.equal(chat.allowed_uids.length,2);
assert.deepEqual([...chat.allowed_uids].sort(),[...previous.allowed_uids].sort());
assert.deepEqual([...sync.allowed_uids].sort(),[...chat.allowed_uids].sort());
assert.equal(sync.interval_seconds,120);assert.equal(stamp.emulated,false);
assert.equal(stamp.working_tree,false);assert.match(stamp.commit,/^[a-f0-9]{40}$/);
git('merge-base','--is-ancestor',stamp.commit,'HEAD');
// Publication records may advance HEAD without changing the exported game.
const appPaths=['scripts','scenes','assets','web','project.godot','config/firebase-public.json','config/global-chat.json','config/world-sync.json','export_presets.cfg'];
assert.equal(git('diff','--name-only',stamp.commit,'--',...appPaths),'','Game source changed after the exported commit');
assert.equal(git('status','--porcelain','--untracked-files=all','--',...appPaths),'','Uncommitted game source must be exported first');
assert.equal(stamp.sync_pilot_base,'0.8.1-sync-pilot.2');
assert.equal((await read('config/global-chat.json')).enabled,false);
assert.equal((await read('config/world-sync.json')).enabled,false);
git('merge-base','--is-ancestor','7300d24','HEAD');git('merge-base','--is-ancestor','f2dd666','HEAD');
const baseline=normalize(execFileSync('git',['show','f2dd666:firestore.rules'],{encoding:'utf8'}));
const current=normalize(await readFile('firestore.rules','utf8'));
assert.equal(current.slice(0,current.indexOf('    // Global chat pilot.')),baseline.slice(0,baseline.indexOf('    match /{document=**}')));
const hashes={};
for(const file of ['scripts/world_sync.gd','scripts/firestore_client.gd','scripts/account_progress.gd','scripts/world_library.gd','scripts/save_store.gd','scripts/save_validation.gd','scripts/progress_controller.gd']){
 const original=normalize(execFileSync('git',['show',`f2dd666:${file}`],{encoding:'utf8'}));
 const built=normalize(await readFile(source+'/'+file,'utf8'));
 assert.equal(built,original,file+' must preserve the corrected save implementation');
 hashes[file]=createHash('sha256').update(built).digest('hex');
}
const chatHashes={};
for(const file of ['scripts/chat/global_chat.gd','scripts/chat/chat_client.gd','scripts/chat/chat_panel.gd','web/shell.html']){
 const original=normalize(execFileSync('git',['show',`${stamp.commit}:${file}`],{encoding:'utf8'}));
 const built=normalize(await readFile(source+'/'+file,'utf8'));
 assert.equal(built,original,file+' must match the exported source commit');
 chatHashes[file]=createHash('sha256').update(built).digest('hex');
}
const result={version:stamp.version,commit:stamp.commit,sync_pilot_base:stamp.sync_pilot_base,world_rules_unchanged:true,allowed_account_count:2,world_sync_enabled:true,chat_enabled:true,public_defaults_disabled:true,save_source_sha256:hashes,chat_source_sha256:chatHashes,firestore_rules_sha256:createHash('sha256').update(current).digest('hex')};
await writeFile('build/chat-pilot/pilot-build.json',JSON.stringify(result,null,2)+'\n');
console.log('PRIVATE PILOT: same 2 accounts; corrected sync and world rules preserved; public defaults off.');

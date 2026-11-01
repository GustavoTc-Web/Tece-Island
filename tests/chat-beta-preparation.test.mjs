// File-only administrative preparation; never connects to Firebase.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdir,mkdtemp,readFile,writeFile,access} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
const root=process.cwd(),pattern=/    function chatAccess\(\) \{[\s\S]*?\n    \}/g;
async function fixture(){
 await mkdir('.tools',{recursive:true});const dir=await mkdtemp(path.join(root,'.tools/chat-beta-prep-'));
 const canonical=await readFile('firestore.rules','utf8');
 const base=canonical.replace(pattern,'    function chatAccess() {\n      let settings = get(/databases/$(database)/documents/chatSettings/global).data;\n      return chatVerified() && settings.enabled == true && request.auth.uid in settings.allowed_uids;\n    }');
 const settings={fields:{enabled:{booleanValue:true},allowed_uids:{arrayValue:{values:[{stringValue:'original-a'},{stringValue:'original-b'},{stringValue:'previous-guest'}]}},admin_uids:{arrayValue:{values:[{stringValue:'existing-admin'}]}}},updateTime:'2026-11-01T10:00:00Z'};
 await writeFile(path.join(dir,'base.rules'),base);await writeFile(path.join(dir,'settings.json'),JSON.stringify(settings));return{dir,base,settings};
}
const run=({dir},args=[])=>spawnSync(process.execPath,['tools/prepare-chat-beta.mjs','--base',path.join(dir,'base.rules'),'--settings',path.join(dir,'settings.json'),'--output',path.join(dir,'out'),...args],{cwd:root,encoding:'utf8',windowsHide:true});
const json=async(dir,name)=>JSON.parse(await readFile(path.join(dir,'out',name),'utf8'));
test('invite patch merges chat UIDs while preserving administrators, enable flag and prior guests',async()=>{
 const f=await fixture();assert.equal(run(f,['--mode','allowlist','--invite-uids','new-verified']).status,0);
 const patch=await json(f.dir,'settings-patch.rest.json'),pre=await json(f.dir,'preconditions.json');
 assert.deepEqual(Object.keys(patch.fields),['access_mode','allowed_uids']);
 assert.deepEqual(patch.fields.allowed_uids.arrayValue.values.map(x=>x.stringValue),['original-a','original-b','previous-guest','new-verified']);
 assert.deepEqual(pre.updateMask.fieldPaths,['access_mode','allowed_uids']);assert.equal(pre.currentDocument.updateTime,f.settings.updateTime);assert.equal(pre.applied,false);
 assert.equal((await readFile(path.join(f.dir,'out/firestore.rules'),'utf8')).replace(pattern,''),f.base.replace(pattern,''));
 assert.deepEqual((await json(f.dir,'client-chat-config.json')).allowed_uids,patch.fields.allowed_uids.arrayValue.values.map(x=>x.stringValue));
});
test('verified mode changes only access mode and never supplies an admin or sync override',async()=>{
 const f=await fixture();assert.equal(run(f,['--mode','verified']).status,0);
 const patch=await json(f.dir,'settings-patch.rest.json');assert.deepEqual(patch,{fields:{access_mode:{stringValue:'verified'}}});
 await assert.rejects(access(path.join(f.dir,'out/world-sync.json')));
 assert.notEqual(run(await fixture(),['--mode','verified','--invite-uids','guest-new']).status,0);
});
test('unexpected world rules or malformed invitation stop before producing deployment files',async()=>{
 const f=await fixture();await writeFile(path.join(f.dir,'base.rules'),f.base.replace('request.auth.uid == uid','true'));
 assert.notEqual(run(f,['--mode','allowlist']).status,0);await assert.rejects(access(path.join(f.dir,'out/settings-patch.rest.json')));
 assert.notEqual(run(await fixture(),['--mode','allowlist','--invite-uids','bad/uid']).status,0);
});

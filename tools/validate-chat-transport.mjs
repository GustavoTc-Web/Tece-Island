// Isolated demo data only; run inside firebase emulators:exec after rule tests.
import {readFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,setDoc} from 'firebase/firestore';
assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8085');
assert.ok(process.env.GODOT_EXE,'GODOT_EXE is required');
const env=await initializeTestEnvironment({projectId:'demo-tece-island',firestore:{rules:await readFile('firestore.rules','utf8')}});
try{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c=>{const db=c.firestore();await setDoc(doc(db,'chatSettings/global'),{enabled:true,allowed_uids:['chat-a','chat-b'],admin_uids:['chat-b']});await setDoc(doc(db,'chatProfiles/chat-a'),{nickname:'Ana'});});
 const test=spawnSync(process.env.GODOT_EXE,['--headless','--path','.','--script','tests/validate_chat_transport.gd'],{encoding:'utf8',windowsHide:true,maxBuffer:4*1024*1024});
 const log=(test.stdout||'')+(test.stderr||'');process.stdout.write(log);assert.equal(test.status,0);assert.ok(!/SCRIPT ERROR|FAIL:/.test(log));assert.match(log,/CHAT NATIVE: 11 verificações, 0 falhas/u);
}finally{await env.cleanup();}

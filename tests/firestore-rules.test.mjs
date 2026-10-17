import {before, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, collection, getDoc, getDocs, setDoc, deleteDoc, writeBatch} from 'firebase/firestore';

const projectId='demo-tece-island';
let env;
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Execute npm run test:rules; estes testes nunca usam produção.');
  env=await initializeTestEnvironment({projectId,firestore:{rules:await readFile('firestore.rules','utf8')}});
});
after(async()=>{if(env)await env.cleanup();});
const db=uid=>env.authenticatedContext(uid,{email_verified:true}).firestore();
const path=(uid,world)=>`users/${uid}/worlds/${world}`;
function metadata(uid,world,revision=1,chunkCount=1,previous=''){
  return {schema:1,owner_uid:uid,world_id:world,name:'Ilha de teste',revision,
    snapshot:`v-${revision}`,previous_snapshot:previous,hash:'a'.repeat(64),
    chunk_count:chunkCount,raw_bytes:100,encoded_bytes:chunkCount*4};
}
function commit(client,uid,world,data,{missing=-1,payload='YWJj',owner=uid}={}){
  const batch=writeBatch(client),root=path(uid,world);
  batch.set(doc(client,root),{...data,owner_uid:owner});
  batch.set(doc(client,`${root}/versions/${data.snapshot}`),data);
  for(let i=0;i<data.chunk_count;i++)if(i!==missing)batch.set(doc(client,`${root}/versions/${data.snapshot}/chunks/${i}`),{index:i,payload});
  return batch.commit();
}
test('conta autenticada grava versão completa e lê só a própria lista',async()=>{
  const a=db('rules-a'),b=db('rules-b');
  await assertSucceeds(commit(a,'rules-a','world-a',metadata('rules-a','world-a')));
  await assertSucceeds(getDoc(doc(a,path('rules-a','world-a'))));
  await assertSucceeds(getDocs(collection(a,'users/rules-a/worlds')));
  await assertFails(getDoc(doc(b,path('rules-a','world-a'))));
  await assertFails(getDocs(collection(b,'users/rules-a/worlds')));
  await assertFails(getDoc(doc(b,`${path('rules-a','world-a')}/versions/v-1/chunks/0`)));
});
test('acesso anônimo e e-mail não verificado são negados',async()=>{
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),path('rules-a','world-a'))));
  const unverified=env.authenticatedContext('rules-a',{email_verified:false}).firestore();
  await assertFails(getDoc(doc(unverified,path('rules-a','world-a'))));
});
test('dono, ID e campos administrativos não podem ser forjados',async()=>{
  const a=db('rules-a');
  await assertFails(commit(a,'rules-b','foreign',metadata('rules-b','foreign')));
  await assertFails(commit(a,'rules-a','bad-owner',metadata('rules-a','bad-owner'),{owner:'rules-b'}));
  await assertFails(commit(a,'rules-a','bad-id',{...metadata('rules-a','other'),snapshot:'v-new'}));
  await assertFails(commit(a,'rules-a','admin',{...metadata('rules-a','admin'),admin:true}));
});
test('mundo incompleto não se torna visível; batch aborta inteiro',async()=>{
  const a=db('rules-a'),m=metadata('rules-a','incomplete',1,2);
  await assertFails(commit(a,'rules-a','incomplete',m,{missing:1}));
  assert.equal((await getDoc(doc(a,path('rules-a','incomplete')))).exists(),false);
  await assertFails(setDoc(doc(a,path('rules-a','head-only')),metadata('rules-a','head-only')));
});
test('oito partes cabem nos limites de avaliação das regras',async()=>{
  await assertSucceeds(commit(db('rules-a'),'rules-a','eight',metadata('rules-a','eight',1,8)));
});
test('tamanho e quantidade de partes são limitados',async()=>{
  await assertFails(commit(db('rules-a'),'rules-a','oversize',metadata('rules-a','oversize'),{payload:'x'.repeat(200001)}));
  await assertFails(commit(db('rules-a'),'rules-a','nine',metadata('rules-a','nine',1,9)));
});
test('sessão antiga não pode repetir revisão ou pular revisões',async()=>{
  const a=db('rules-a');
  await assertSucceeds(commit(a,'rules-a','revision',metadata('rules-a','revision')));
  await assertSucceeds(commit(a,'rules-a','revision',metadata('rules-a','revision',2,1,'v-1')));
  await assertFails(commit(a,'rules-a','revision',{...metadata('rules-a','revision',2,1,'v-2'),snapshot:'v-stale'}));
  await assertFails(commit(a,'rules-a','revision',metadata('rules-a','revision',4,1,'v-2')));
});
test('snapshots são imutáveis; atual e predecessor não podem ser apagados',async()=>{
  const a=db('rules-a'),root=path('rules-a','revision');
  await assertFails(setDoc(doc(a,`${root}/versions/v-1/chunks/0`),{index:0,payload:'other'}));
  await assertFails(deleteDoc(doc(a,root)));
  await assertFails(deleteDoc(doc(a,`${root}/versions/v-2/chunks/0`)));
  await assertFails(deleteDoc(doc(a,`${root}/versions/v-1/chunks/0`)));
  await assertSucceeds(commit(a,'rules-a','revision',metadata('rules-a','revision',3,1,'v-2')));
  await assertSucceeds(deleteDoc(doc(a,`${root}/versions/v-1/chunks/0`)));
  await assertSucceeds(deleteDoc(doc(a,`${root}/versions/v-1`)));
  await assertFails(deleteDoc(doc(db('rules-b'),`${root}/versions/v-2/chunks/0`)));
});
test('mundos distintos da mesma conta têm revisões independentes',async()=>{
  const a=db('rules-a');
  await assertSucceeds(commit(a,'rules-a','second',metadata('rules-a','second')));
  assert.equal((await getDoc(doc(a,path('rules-a','second')))).data().revision,1);
  assert.equal((await getDoc(doc(a,path('rules-a','revision')))).data().revision,3);
});
test('Godot nativo usa o protocolo REST completo no emulador', {skip:!process.env.GODOT_EXE},()=>{
  const r=spawnSync(process.env.GODOT_EXE,['--headless','--path','.','--script','tests/validate_firestore_transport.gd','--log-file','.tools/firestore-native.log'],{encoding:'utf8',timeout:120000});
  if(r.stdout)process.stdout.write(r.stdout);
  if(r.stderr)process.stderr.write(r.stderr);
  assert.equal(r.status,0,r.error?.message||'Godot REST falhou');
  assert.ok(r.stdout.includes('FIRESTORE REST:')&&!r.stdout.includes('FAIL:'));
});

import {before, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, collection, getDoc, getDocs, getCountFromServer, setDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp, query, orderBy, limit, where} from 'firebase/firestore';

let env;
const users=['chat-a','chat-b','chat-admin'];
const db=(uid='chat-a',verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
before(async()=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Use npm run test:chat; produção nunca é usada.');
 env=await initializeTestEnvironment({projectId:'demo-tece-island',firestore:{rules:await readFile('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();await setDoc(doc(d,'chatSettings/global'),{enabled:true,allowed_uids:users,admin_uids:['chat-admin']});
  for(const uid of users)await setDoc(doc(d,'chatProfiles/'+uid),{nickname:uid==='chat-a'?'Ana':'Beto'});
 });
});
after(async()=>{if(env)await env.cleanup();});
async function reset(){await env.withSecurityRulesDisabled(async c=>{
 const d=c.firestore();for(const collectionId of ['globalMessages','chatRuntime','chatRates'])for(const row of (await getDocs(collection(d,collectionId))).docs)await deleteDoc(row.ref);
});}
async function age(uid){await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'chatRates/'+uid),{sequence:0,sent_at:Timestamp.fromMillis(Date.now()-10000)}));}
async function send(client,uid='chat-a',{author=uid,nickname=uid==='chat-a'?'Ana':'Beto',text='Olá, ilha!',sequence,slot,omit='',extra={}}={}){
 if(sequence===undefined){const counter=await getDoc(doc(client,'chatRuntime/global'));sequence=counter.exists()?counter.data().sequence+1:1;}
 const batch=writeBatch(client),stamp={sequence,sent_at:serverTimestamp()};
 if(omit!=='counter')batch.set(doc(client,'chatRuntime/global'),stamp);
 if(omit!=='rate')batch.set(doc(client,'chatRates/'+uid),stamp);
 if(omit!=='message')batch.set(doc(client,'globalMessages/'+(slot??String(sequence%100))),{...stamp,uid:author,nickname,text,...extra});
 return batch.commit();
}
test('duas contas verificadas enviam e recebem a consulta das 50 recentes',async()=>{
 await reset();await assertSucceeds(send(db()));await assertSucceeds(send(db('chat-b'),'chat-b'));
 const rows=await assertSucceeds(getDocs(query(collection(db('chat-b'),'globalMessages'),orderBy('sequence','desc'),limit(50))));
 assert.deepEqual(rows.docs.map(d=>d.data().uid),['chat-b','chat-a']);
 assert.equal(rows.docs[0].data().sent_at instanceof Timestamp,true);
});
test('anônimo, não verificado e UID fora do piloto não leem nem escrevem',async()=>{
 for(const client of [env.unauthenticatedContext().firestore(),db('chat-a',false),db('outsider')]){
  await assertFails(getDocs(query(collection(client,'globalMessages'),limit(50))));
  await assertFails(setDoc(doc(client,'chatProfiles/chat-a'),{nickname:'Forjado'}));
  await assertFails(getDoc(doc(client,'chatSettings/global')));
 }
});
test('regra recusa autoria, apelido e campos privados falsificados',async()=>{
 await reset();const client=db();
 await assertFails(send(client,'chat-a',{author:'chat-b'}));
 await assertFails(send(client,'chat-a',{nickname:'Administrador'}));
 await assertFails(send(client,'chat-a',{extra:{email:'private@example.invalid'}}));
 await assertSucceeds(send(client));
});
test('intervalo de 5 s é validado pelo servidor, mesmo sem temporizador cliente',async()=>{
 await reset();await assertSucceeds(send(db()));await assertFails(send(db()));
 await assertFails(deleteDoc(doc(db(),'chatRates/chat-a')));
 await assertFails(setDoc(doc(db(),'chatRates/chat-a'),{sequence:1,sent_at:Timestamp.fromMillis(0)}));
 await age('chat-a');await assertSucceeds(send(db()));
});
test('batch incompleto, slot errado e salto de sequência são rejeitados atomicamente',async()=>{
 await reset();for(const omit of ['rate','counter','message'])await assertFails(send(db(),'chat-a',{sequence:1,omit}));
 await assertFails(send(db(),'chat-a',{sequence:1,slot:'2'}));
 await assertFails(send(db(),'chat-a',{sequence:3}));
 assert.equal((await getDoc(doc(db(),'chatRuntime/global'))).exists(),false);
});
test('limites de texto e consulta; marcação permanece texto literal',async()=>{
 await reset();await assertFails(send(db(),'chat-a',{text:''}));await assertFails(send(db(),'chat-a',{text:'   '}));
 await assertFails(send(db(),'chat-a',{text:'a'.repeat(201)}));
 await assertSucceeds(send(db(),'chat-a',{text:'á'.repeat(200)}));
 await assertFails(getDocs(collection(db(),'globalMessages')));
 await assertFails(getDocs(query(collection(db(),'globalMessages'),limit(51))));
 await age('chat-a');const text='<img src=x onerror=alert(1)> [b]texto[/b]';await assertSucceeds(send(db(),'chat-a',{text}));
 assert.equal((await getDoc(doc(db(),'globalMessages/2'))).data().text,text);
 await assertSucceeds(getDocs(query(collection(db(),'globalMessages'),where('sequence','>',1),orderBy('sequence','desc'),limit(50))));
});
test('apelido mutável só pelo dono, com esquema e caracteres validados',async()=>{
 await reset();await assertSucceeds(send(db()));
 await assertSucceeds(setDoc(doc(db(),'chatProfiles/chat-a'),{nickname:'João 7'}));
 assert.equal((await getDoc(doc(db(),'chatProfiles/chat-a'))).data().nickname,'João 7');
 assert.equal((await getDoc(doc(db(),'globalMessages/1'))).data().nickname,'Ana');
 await age('chat-a');await assertFails(send(db()));
 await assertSucceeds(send(db(),'chat-a',{nickname:'João 7'}));
 for(const nickname of ['x','a'.repeat(21),'@nome',' Nome','Nome ','','<b>'])await assertFails(setDoc(doc(db(),'chatProfiles/chat-a'),{nickname}));
 await assertFails(setDoc(doc(db(),'chatProfiles/chat-a'),{nickname:'João',admin:true}));
 await assertFails(setDoc(doc(db(),'chatProfiles/chat-b'),{nickname:'Outro'}));
 await assertFails(setDoc(doc(db('chat-admin'),'chatProfiles/chat-a'),{nickname:'Admin forjado'}));
 await assertFails(deleteDoc(doc(db(),'chatProfiles/chat-a')));
 await assertFails(getDoc(doc(db(),'chatProfiles/chat-b')));
 await assertSucceeds(setDoc(doc(db(),'chatProfiles/chat-a'),{nickname:'Ana'}));
});
test('alterar apelido não concede cargo ou acesso às configurações',async()=>{
 await assertSucceeds(setDoc(doc(db(),'chatProfiles/chat-a'),{nickname:'Moderador'}));
 await reset();await send(db(),'chat-a',{nickname:'Moderador'});
 await assertFails(deleteDoc(doc(db(),'globalMessages/1')));
 await assertFails(setDoc(doc(db(),'chatSettings/global'),{enabled:true,allowed_uids:users,admin_uids:['chat-a']}));
 await assertFails(setDoc(doc(db('chat-admin'),'chatSettings/global'),{enabled:true,allowed_uids:users,admin_uids:users}));
 await assertSucceeds(setDoc(doc(db(),'chatProfiles/chat-a'),{nickname:'Ana'}));
});
test('apenas administrador validado nas regras pode remover mensagens',async()=>{
 await reset();await send(db());await assertFails(deleteDoc(doc(db(),'globalMessages/1')));
 await assertFails(deleteDoc(doc(db('outsider'),'globalMessages/1')));
 await assertSucceeds(deleteDoc(doc(db('chat-admin'),'globalMessages/1')));
 assert.equal((await getDoc(doc(db(),'globalMessages/1'))).exists(),false);
});
test('concorrência aceita só uma sequência; uma falha não consome o cooldown',async()=>{
 await reset();const results=await Promise.allSettled([send(db(),'chat-a',{sequence:1}),send(db('chat-b'),'chat-b',{sequence:1})]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const loser=results[0].status==='rejected'?'chat-a':'chat-b';await assertSucceeds(send(db(loser),loser));
});
test('histórico circula em 100 documentos; consulta conserva as últimas 50',async()=>{
 await reset();for(let i=1;i<=105;i++){await age('chat-a');await assertSucceeds(send(db(),'chat-a',{text:'Mensagem '+i}));}
 const rows=await getDocs(query(collection(db(),'globalMessages'),orderBy('sequence','desc'),limit(50)));
 assert.equal(rows.size,50);assert.equal(rows.docs[0].data().sequence,105);assert.equal(rows.docs.at(-1).data().sequence,56);
 await env.withSecurityRulesDisabled(async c=>assert.equal((await getDocs(collection(c.firestore(),'globalMessages'))).size,100));
});

test('contagem limitada detecta remoção sem expor dados ou ampliar acesso',async()=>{
 await reset();await send(db());await send(db('chat-b'),'chat-b');
 const window=client=>query(collection(client,'globalMessages'),where('sequence','>=',1),where('sequence','<=',2),limit(50));
 assert.equal((await assertSucceeds(getCountFromServer(window(db())))).data().count,2);
 await assertSucceeds(deleteDoc(doc(db('chat-admin'),'globalMessages/1')));
 assert.equal((await getCountFromServer(window(db()))).data().count,1);
 // A later insert cannot hide a deletion in the frozen window.
 await age('chat-a');await send(db());
 assert.equal((await getCountFromServer(window(db()))).data().count,1);
 for(const client of [env.unauthenticatedContext().firestore(),db('outsider'),db('chat-a',false)])await assertFails(getCountFromServer(window(client)));
 await assertFails(getCountFromServer(collection(db(),'globalMessages')));
 await assertFails(getCountFromServer(query(collection(db(),'globalMessages'),limit(51))));
});

test('prepared verified-chat mode admits new verified UID without granting administration or foreign saves',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'chatSettings/global'),{enabled:true,access_mode:'verified',allowed_uids:users,admin_uids:['chat-admin']}));
 try{
  await reset();const client=db('new-verified');
  await assertSucceeds(setDoc(doc(client,'chatProfiles/new-verified'),{nickname:'Nova conta'}));
  await assertSucceeds(send(client,'new-verified',{nickname:'Nova conta'}));
  await assertSucceeds(getDocs(query(collection(client,'globalMessages'),limit(50))));
  await assertFails(deleteDoc(doc(client,'globalMessages/1')));
  await assertFails(setDoc(doc(client,'chatSettings/global'),{enabled:true,access_mode:'verified',allowed_uids:users,admin_uids:['new-verified']}));
  await assertFails(setDoc(doc(client,'chatProfiles/new-verified'),{nickname:'Nova conta',admin:true}));
  await assertFails(getDoc(doc(client,'users/chat-a/worlds/private-world')));
  for(const denied of [db('new-unverified',false),env.unauthenticatedContext().firestore()]){
   await assertFails(getDocs(query(collection(denied,'globalMessages'),limit(50))));
   await assertFails(setDoc(doc(denied,'chatProfiles/new-unverified'),{nickname:'Nao verificada'}));
  }
  await assertSucceeds(deleteDoc(doc(db('chat-admin'),'globalMessages/1')));
 }finally{
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'chatSettings/global'),{enabled:true,allowed_uids:users,admin_uids:['chat-admin']}));
 }
 await assertFails(getDoc(doc(db('new-verified'),'chatSettings/global')));
});

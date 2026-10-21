import {test} from 'node:test';
import assert from 'node:assert/strict';
import {startServer} from '../service.mjs';
import {firebaseVerifier} from '../auth.mjs';
import {Client,identities,pause} from './helpers.mjs';

test('connection diagnostics identify stages and never log identities, tokens or profile exceptions',async t=>{
 const users=await identities(),verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true}),events=[];
 let resolveProfile;
 const profile=new Promise(resolve=>resolveProfile=resolve);
 const server=await startServer({verify:t=>verifier.verify(t),nickname:async()=>{await profile;throw Error('PRIVATE profile payload must not be logged');},allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:0,log:e=>events.push(e)});
 const clients=[],make=()=>{const c=new Client(`ws://127.0.0.1:${server.port}/room`);clients.push(c);return c;};
 t.after(async()=>{resolveProfile();for(const c of clients)c.ws.terminate();await server.close();await verifier.close();});
 const a=make();await a.open();a.send({type:'hello',protocol:3,token:users['mp-a'].token});
 await a.wait(m=>m.type==='authenticated');assert.ok(!a.messages.some(m=>m.type==='welcome'));
 assert.ok(events.some(e=>e.event==='auth_ok'));assert.ok(!events.some(e=>e.event==='welcome_sent'));
 resolveProfile();const welcome=await a.wait(m=>m.type==='welcome');assert.equal(welcome.players[0].nickname,'Jogador 1');
 await pause(160);assert.ok(events.some(e=>e.event==='state_started'));
 const b=make();await b.hello(users['mp-b']);await a.walk(-1,0,250);
 assert.equal(b.state.players.length,2);
 const bad=make();await bad.hello({token:'PRIVATE-forged-token'});assert.ok(events.some(e=>e.event==='rejected'&&e.code==='auth_failed'));
 const health=await(await fetch(`http://127.0.0.1:${server.port}/health`)).json();
 assert.equal(health.diagnostics.authenticated,2);assert.equal(health.diagnostics.welcomes,2);assert.ok(health.diagnostics.states>0);
 const output=JSON.stringify(events)+JSON.stringify(health);
 for(const secret of [...Object.values(users).map(u=>u.token),'mp-a','mp-b','PRIVATE profile payload','PRIVATE-forged-token'])assert.ok(!output.includes(secret));
 const names=events.filter(e=>e.connection===events.find(e=>e.event==='auth_ok').connection).map(e=>e.event);
 assert.ok(names.indexOf('socket_open')<names.indexOf('auth_begin'));assert.ok(names.indexOf('auth_ok')<names.indexOf('welcome_sent'));assert.ok(names.indexOf('welcome_sent')<names.indexOf('state_started'));
});

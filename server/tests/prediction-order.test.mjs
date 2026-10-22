import {test} from 'node:test';
import assert from 'node:assert/strict';
import {startServer} from '../service.mjs';
import {firebaseVerifier} from '../auth.mjs';
import {Client,identities,pause} from './helpers.mjs';

test('ordered input acknowledgements identify the input applied by each protocol-3 state',async t=>{
 const users=await identities(),verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true});
 const server=await startServer({verify:token=>verifier.verify(token),nickname:async()=> 'Teste',allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:0});
 const snapshot=server.room.snapshot.bind(server.room);
 // Test observation only; production wire format is unchanged.
 server.room.snapshot=(p,rev)=>({...snapshot(p,rev),_test_input_at_emit:p.input});
 const a=new Client(`ws://127.0.0.1:${server.port}/room`);let acknowledged=0,observed=0;const mismatches=[];
 a.ws.on('message',bytes=>{const m=JSON.parse(bytes);if(m.type==='ack'&&m.action==='input'&&m.ok)acknowledged=m.seq;if(m.type==='state'){observed++;if(m._test_input_at_emit!==acknowledged)mismatches.push([m._test_input_at_emit,acknowledged]);}});
 t.after(async()=>{a.ws.terminate();await server.close();await verifier.close();});
 await a.hello(users['mp-a']);
 for(let i=1;i<=35;i++){a.send({type:'input',seq:i,x:i%2?1:-1,y:0});await pause(17);}
 await pause(200);assert.ok(observed>=5);assert.deepEqual(mismatches,[]);
});

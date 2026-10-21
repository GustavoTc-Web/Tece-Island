import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Room} from '../room.mjs';
import {ARENA} from './arena-fixture.mjs';
import {startServer} from '../service.mjs';
import {firebaseVerifier} from '../auth.mjs';
import {Client,identities,pause} from './helpers.mjs';

test('all extraction quantities remain on the ground until explicit pickup',()=>{
 for(const kind of ['madeira','pedra','fibra']){
  const room=new Room({...ARENA,resources:[...ARENA.resources,{id:'fiber-test',kind:'fibra',x:500,y:650}]}),p=room.join({uid:'test'},'Test',{close(){}}),r=room.resources.find(r=>r.kind===kind);
  p.x=r.x-35;p.y=r.y;r.hits=5.99;
  if(kind==='pedra'){p.items.select(1);p.tool=p.items.tool();}
  if(kind==='fibra'){p.items.select(-1);p.tool=p.items.tool();}
  assert.equal(room.action(p,{type:'harvest',seq:1,resource:r.id},1000),null);
  const [drop]=room.drops.values();assert.equal(drop.quantity,ARENA.extraction[kind].reward);assert.equal(p.items.count(kind),0);
  assert.ok(room.geometry.free(drop.x,drop.y,room.depleted));
  assert.equal(room.action(p,{type:'pickup',seq:2,drop:drop.id},1001),null);
  assert.equal(p.items.count(kind),ARENA.extraction[kind].reward);assert.equal(room.drops.size,0);
 }
});

test('pickup rejects distance, walls, missing IDs and replay without losing ground items',()=>{
 const layout={...ARENA,colliders:[{owner:'wall',type:'rect',x:600,y:450,size:[10,100]}]};
 const room=new Room(layout),p=room.join({uid:'test'},'Test',{close(){}});
 const drop={id:'test-drop',kind:'pedra',quantity:4,x:620,y:450};room.drops.set(drop.id,drop);
 p.x=200;p.y=450;assert.equal(room.action(p,{type:'pickup',seq:1,drop:drop.id},0),'too_far');
 p.x=580;assert.equal(room.action(p,{type:'pickup',seq:2,drop:drop.id},0),'blocked_path');
 p.x=620;assert.equal(room.action(p,{type:'pickup',seq:3,drop:'forged'},0),'drop_unavailable');
 assert.equal(room.drops.size,1);assert.equal(p.items.count('pedra'),0);
 assert.equal(room.action(p,{type:'pickup',seq:4,drop:drop.id,quantity:999,kind:'madeira'},0),null);
 assert.equal(p.items.count('pedra'),4);assert.equal(p.items.count('madeira'),0);
 assert.equal(room.action(p,{type:'pickup',seq:4,drop:drop.id},0),'replayed_action');
});

test('needs are individual, server-owned, preserved on reconnect; hunger does not decay without food',()=>{
 const room=new Room(ARENA),socket={close(){}},identity={uid:'a',expires:Date.now()/1000+3600};
 const a=room.join(identity,'A',socket),b=room.join({...identity,uid:'b'},'B',socket);
 a.health=87;a.hunger=73;a.thirst=50;
 for(let i=0;i<600;i++)room.step(.1,i*100);
 assert.equal(a.health,87);assert.equal(a.hunger,73);assert.equal(b.hunger,100);
 assert.ok(Math.abs(a.thirst-42)<.01);assert.ok(Math.abs(b.thirst-92)<.01);
 assert.equal(room.action(a,{type:'needs',seq:1,health:999,hunger:999,thirst:999},0),'invalid_action');
 const s=room.snapshot(a);assert.equal(s.health,87);assert.equal(s.hunger,73);assert.equal(s.max_health,100);assert.equal(s.hunger_decay,false);
 assert.ok(!s.players.some(p=>'health'in p||'hunger'in p||'inventory'in p));
 room.disconnect(a,socket);assert.equal(room.join(identity,'A',socket),a);assert.equal(a.health,87);assert.equal(a.hunger,73);
});

test('partial pickup leaves the exact remainder, preserving total yield between players',()=>{
 const room=new Room(ARENA),a=room.join({uid:'a'},'A',{close(){}}),b=room.join({uid:'b'},'B',{close(){}});
 a.x=b.x=600;a.y=b.y=450;a.items.add('madeira',59);
 room.drops.set('test',{id:'test',kind:'madeira',quantity:5,x:600,y:450});
 assert.equal(room.action(a,{type:'pickup',seq:1,drop:'test'},0),null);
 assert.equal(a.items.count('madeira'),60);assert.equal(room.drops.get('test').quantity,4);
 assert.equal(room.action(b,{type:'pickup',seq:1,drop:'test'},0),null);
 assert.equal(b.items.count('madeira'),4);assert.equal(room.drops.size,0);
});

test('unchanged world is omitted from snapshots; changed and fresh snapshots retain complete state',()=>{
 const room=new Room(ARENA),p=room.join({uid:'test'},'Test',{close(){}});
 const first=room.snapshot(p);assert.ok(Array.isArray(first.drops));assert.ok(Array.isArray(first.resources));
 const unchanged=room.snapshot(p,first.world_revision);assert.ok(!('drops'in unchanged));assert.ok(!('resources'in unchanged));
 p.x=560;p.y=400;room.resourceIndex.get('tree-1').hits=4;
 room.action(p,{type:'harvest',seq:1,resource:'tree-1'},1000);
 const changed=room.snapshot(p,first.world_revision);assert.equal(changed.drops.length,1);
 const [drop]=changed.drops;room.action(p,{type:'pickup',seq:2,drop:drop.id},1001);
 const removed=room.snapshot(p,changed.world_revision);assert.deepEqual(removed.drops,[]);
 assert.ok(room.snapshot(p).resources.some(r=>r.id==='tree-1'&&r.depleted));
});

test('real WS late join and reconnect see remaining drops, full inventory cannot consume them',async t=>{
 const users=await identities(),verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true});
 const server=await startServer({verify:t=>verifier.verify(t),nickname:async()=> 'Tester',allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:0,layout:ARENA});
 const clients=[],make=()=>{const c=new Client(`ws://127.0.0.1:${server.port}/room`);clients.push(c);return c;};
 t.after(async()=>{for(const c of clients)c.ws.terminate();await server.close();await verifier.close();});
 const a=make();await a.hello(users['mp-a']);const p=server.room.players.get('mp-a');p.x=560;p.y=400;
 server.room.resourceIndex.get('tree-1').hits=4;
 assert.equal((await a.action('harvest',{resource:'tree-1'})).ok,true);await pause(120);
 const [drop]=a.state.drops;assert.equal(a.state.inventory.madeira,0);
 const b=make(),welcome=await b.hello(users['mp-b']);assert.deepEqual(welcome.drops,[drop]);
 a.ws.terminate();await pause(100);const again=make(),reopen=await again.hello(users['mp-a']);assert.deepEqual(reopen.drops,[drop]);assert.equal(reopen.self,a.self);
 p.items.add('madeira',60);assert.equal((await again.action('pickup',{drop:drop.id})).code,'inventory_full');
 const q=server.room.players.get('mp-b');q.x=p.x;q.y=p.y;
 const results=await Promise.all([again.action('pickup',{drop:drop.id}),b.action('pickup',{drop:drop.id})]);
 assert.equal(results.filter(r=>r.ok).length,1);await pause(130);
 assert.equal(b.state.inventory.madeira,5);assert.deepEqual(again.state.drops,[]);
});

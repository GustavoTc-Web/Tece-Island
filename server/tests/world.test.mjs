import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {WORLD_DATA,WorldGeometry} from '../world.mjs';
import {Room} from '../room.mjs';
import {Inventory} from '../inventory.mjs';
import {reachable,route} from './paths.mjs';
import {firebaseVerifier} from '../auth.mjs';
import {startServer} from '../service.mjs';
import {Client,identities,pause} from './helpers.mjs';
import {ARENA} from './arena-fixture.mjs';

test('full world matches solo terrain, regions and canonical original wells',()=>{
  const g=new WorldGeometry(WORLD_DATA),samples=JSON.parse(readFileSync(new URL('../../tests/fixtures/multiplayer-terrain-parity.json',import.meta.url)));
  assert.deepEqual(WORLD_DATA.bounds,[-3072,-2560,9984,5632]);assert.equal(WORLD_DATA.regions.length,18);
  assert.equal(WORLD_DATA.resources.length,274);assert.equal(WORLD_DATA.wells.length,18);assert.equal(WORLD_DATA.buildings.length,39);
  for(const s of samples){assert.equal(g.contains(...s.point),s.inside,JSON.stringify(s));assert.equal(g.water(...s.point),s.water,JSON.stringify(s));}
  for(const [id,point]of Object.entries({forest:[1310,768],swamp:[3000,768],fields:[4520,768],desert:[6030,768]})){
    const w=WORLD_DATA.wells.find(w=>w.id==='well:'+id);assert.deepEqual([w.x,w.y],point);
  }
});

test('ordinary server movement can reach every biome and a usable approach to every well',()=>{
  const room=new Room(),g=room.geometry,tree=reachable(g,WORLD_DATA.spawns[0]);
  const p=room.join({uid:'path-test',expires:Date.now()/1000+3600},'Path',{close(){}});
  let now=performance.now();
  const walk=points=>{
    for(const target of points.slice(1)){
      let steps=0;
      while(Math.hypot(p.x-target[0],p.y-target[1])>.25){
        const distance=Math.hypot(p.x-target[0],p.y-target[1]);
        const dx=(target[0]-p.x)/distance,dy=(target[1]-p.y)/distance;
        const speed=WORLD_DATA.speed*(g.water(p.x,p.y)?WORLD_DATA.swim_speed:1);
        const dt=Math.min(.05,distance/speed);now+=dt*1000;
        assert.equal(room.move(p,{seq:p.input+1,x:dx,y:dy},now),null);room.step(dt,now);
        assert.ok(++steps<1500,'Server could not follow valid route to '+target);
      }
    }
  };
  for(const r of WORLD_DATA.regions){
    p.x=tree.from[0];p.y=tree.from[1];
    const center=[r.rect[0]+r.rect[2]/2,r.rect[1]+r.rect[3]/2];walk(route(tree,center));
    assert.equal(g.region(p.x,p.y).id,r.id);
  }
  for(const w of WORLD_DATA.wells){
    const candidates=[[0,64],[0,-64],[64,0],[-64,0]].map(([x,y])=>[w.x+x,w.y+y]);
    const approach=candidates.map(to=>{try{return route(tree,to).at(-1);}catch{return null;}}).find(a=>a&&Math.hypot(a[0]-w.x,a[1]-w.y)<=90&&g.sight({x:a[0],y:a[1]},w,new Set(),w.id));
    assert.ok(approach,'No accessible well approach: '+w.id);
    p.x=tree.from[0];p.y=tree.from[1];walk(route(tree,approach));p.thirst=20;
    assert.equal(room.action(p,{type:'well',seq:p.action+1,well:w.id,action:'drink'},now),null);
    assert.equal(p.thirst,60);
  }
});

test('collisions, line of sight, water speed and inventory bounds are enforced',()=>{
  const room=new Room(),g=room.geometry,p=room.join({uid:'geometry',expires:Date.now()/1000+3600},'Geometry',{close(){}});
  assert.ok(!g.free(-3100,768));
  const fence=WORLD_DATA.colliders.find(c=>c.type==='rect'&&c.x===3976);
  assert.ok(fence);assert.ok(!g.free(fence.x,fence.y));
  assert.ok(!g.sight({x:fence.x-50,y:fence.y},{x:fence.x+50,y:fence.y},new Set()));
  const sample=WORLD_DATA.ponds[0];p.x=sample[0]+sample[2]/2;p.y=sample[1]+sample[3]/2;
  const before=p.x,now=performance.now();room.move(p,{seq:1,x:1,y:0},now);room.step(.1,now);
  assert.ok(Math.abs(p.x-before-WORLD_DATA.speed*.1*.6)<.01);
  assert.equal(room.action(p,{type:'well',seq:1,well:'well:forest',action:'drink'},now),'too_far');
  const inv=new Inventory();assert.equal(inv.select(99),'invalid_slot');assert.equal(inv.swap(0,-2),'invalid_slot');
  assert.equal(inv.equip('machado_pedra'),'invalid_tool');assert.equal(inv.use(2),'canteen_empty');
  assert.ok(inv.add('madeira',60));assert.ok(!inv.add('pedra',1));assert.equal(inv.count('madeira'),60);
});

test('two real WebSocket clients use shared well, private slots and reconnect without duplication',async t=>{
  const users=await identities(),verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true});
  const server=await startServer({verify:token=>verifier.verify(token),nickname:async()=> 'Explorer',allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:0});
  const url=`ws://127.0.0.1:${server.port}/room`,clients=[];
  const make=()=>{const c=new Client(url);clients.push(c);return c;};
  t.after(async()=>{for(const c of clients)c.ws.terminate();await server.close();await verifier.close();});
  const a=make(),b=make();assert.equal((await a.hello(users['mp-a'])).type,'welcome');await b.hello(users['mp-b']);
  await Promise.all([a.walk(1,0,500),b.walk(1,0,200)]);
  assert.ok((await a.action('well',{well:'well:forest',action:'fill'})).ok);
  assert.ok((await b.action('well',{well:'well:forest',action:'fill'})).ok);await pause(150);
  assert.equal(a.state.slots.slots[2].water,3);assert.equal(b.state.slots.slots[2].water,3);
  assert.ok((await a.action('use',{index:2,water:999,uid:'mp-b'})).ok);await pause(150);
  assert.equal(a.state.slots.slots[2].water,2);assert.equal(b.state.slots.slots[2].water,3);
  assert.equal((await a.action('select',{index:999})).code,'invalid_slot');
  assert.equal((await a.action('well',{well:'well:desert',action:'drink'})).code,'too_far');
  const id=a.self,slots=a.state.slots;a.ws.terminate();await pause(200);
  const again=make();await again.hello(users['mp-a']);assert.equal(again.self,id);assert.deepEqual(again.state.slots,slots);assert.equal(again.state.players.length,2);
});

test('server actions reject blocked sight and well cooldown without mutating items',()=>{
  const layout={...ARENA,wells:[{id:'well:test',x:800,y:600}],colliders:[...ARENA.colliders,{owner:'wall',type:'rect',x:780,y:600,size:[12,100]},{owner:'well:test',type:'circle',x:800,y:600,radius:22}]};
  const room=new Room(layout),p=room.join({uid:'sight'},'Sight',{close(){}});p.x=750;p.y=600;
  assert.equal(room.action(p,{type:'well',seq:1,well:'well:test',action:'fill'},0),'blocked_path');
  assert.equal(p.items.slots[2].water,0);
  p.x=850;
  assert.equal(room.action(p,{type:'well',seq:2,well:'well:test',action:'fill'},0),null);
  assert.equal(room.action(p,{type:'well',seq:3,well:'well:test',action:'drink'},10),'cooldown');
  assert.equal(p.items.slots[2].water,3);
  assert.equal(room.action(p,{type:'well',seq:4,well:'well:test',action:'delete'},600),'invalid_action');
});

test('full inventory preserves ground reward; free collector picks it atomically',()=>{
  const room=new Room(ARENA),socket={close(){}},a=room.join({uid:'full'},'Full',socket),b=room.join({uid:'free'},'Free',socket);
  a.x=b.x=560;a.y=b.y=400;a.items.add('madeira',60);
  const resource=room.resourceIndex.get('tree-1');resource.hits=4;
  assert.equal(room.action(a,{type:'harvest',seq:1,resource:'tree-1'},1000),null);
  assert.equal(resource.depleted,true);assert.equal(a.items.count('madeira'),60);
  const [drop]=room.drops.values();assert.equal(drop.quantity,5);
  assert.equal(room.action(a,{type:'pickup',seq:2,drop:drop.id},1001),'inventory_full');
  assert.equal(room.drops.get(drop.id).quantity,5);assert.equal(a.items.count('madeira'),60);
  assert.equal(room.action(b,{type:'pickup',seq:1,drop:drop.id},1002),null);
  assert.equal(b.items.count('madeira'),5);assert.equal(room.drops.size,0);
  assert.equal(room.action(a,{type:'pickup',seq:3,drop:drop.id},1003),'drop_unavailable');
});

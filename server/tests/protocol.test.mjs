import {test} from 'node:test';
import assert from 'node:assert/strict';
import {firebaseVerifier} from '../auth.mjs';
import {startServer} from '../service.mjs';
import {Room, WORLD} from '../room.mjs';
import {Client, identities, pause} from './helpers.mjs';
import {ARENA} from './arena-fixture.mjs';

test('real WebSocket protocol with Firebase emulator identities and two independent clients', async t => {
  const users = await identities();
  const verifier = firebaseVerifier({projectId: 'demo-tece-island', apiKey: 'local-test', localTest: true});
  const server = await startServer({verify: token => verifier.verify(token), nickname: async (_, uid) => uid === 'mp-a' ? 'Ana' : 'Beto',
    allowedUids: ['mp-a', 'mp-b'], origins: ['http://localhost:8060'], port: 0, layout: ARENA});
  const url = `ws://127.0.0.1:${server.port}/room`, clients = [];
  const make = () => {const client = new Client(url); clients.push(client); return client;};
  t.after(async () => {for (const c of clients) c.ws.terminate(); await server.close(); await verifier.close();});
  let a, b;
  await t.test('anonymous and unverified identities cannot join', async () => {
    const anonymous = make(); await anonymous.open(); anonymous.send({type: 'input', x: 1, y: 0, seq: 1});
    assert.equal((await anonymous.wait(m => m.type === 'error')).code, 'auth_required');
    assert.equal((await make().hello(users['mp-unverified'])).code, 'auth_failed');
  });
  await t.test('outsider cannot impersonate an authorized UID or nickname', async () => {
    assert.equal((await make().hello(users['mp-outsider'], {uid: 'mp-a', nickname: 'Ana'})).code, 'not_authorized');
    assert.equal((await make().hello({token: 'forged.jwt.signature', uid: 'mp-a'})).code, 'auth_failed');
    assert.equal(server.room.players.size, 0);
  });
  await t.test('allowed token creates one actor with server tools and canonical nickname', async () => {
    a = make(); const welcome = await a.hello(users['mp-a'], {uid: 'mp-b', nickname: 'Forged', inventory: {madeira: 9999}});
    assert.equal(welcome.type, 'welcome');
    assert.equal(welcome.players[0].nickname, 'Ana');
    assert.deepEqual(welcome.inventory, {machado_madeira: 1, picareta_madeira: 1, cantil: 1, madeira: 0, pedra: 0, fibra: 0});
    assert.equal(welcome.players.length, 1);
  });
  await t.test('movement is server simulated and diagonal speed is capped', async () => {
    const before = {...a.state.players[0]};
    await a.walk(1, 1, 400);
    const p = a.state.players.find(p => p.id === a.self);
    assert.ok(Math.hypot(p.x - before.x, p.y - before.y) > 40);
    assert.ok(Math.hypot(p.x - before.x, p.y - before.y) < WORLD.speed * 0.7);
    assert.equal((await a.action('teleport', {x: 1200, y: 800})).code, 'invalid_action');
    a.send({type: 'input', seq: ++a.input, x: 9000, y: 0});
    assert.equal((await a.wait(m => m.type === 'ack' && m.code === 'invalid_input')).ok, false);
    // Return to the tree's south edge using actual movement messages.
    await a.walk(-1, -1, 400); await a.walk(0, -1, 220);
  });
  await t.test('distance, server tool inventory and action intervals are checked', async () => {
    assert.equal((await a.action('harvest', {resource: 'rock-6'})).code, 'too_far');
    assert.equal((await a.action('equip', {tool: 'machado_pedra'})).code, 'invalid_tool');
    assert.equal((await a.action('equip', {tool: 'picareta_madeira'})).ok, true);
    assert.equal((await a.action('harvest', {resource: 'tree-1'})).code, 'wrong_tool');
    await a.action('equip', {tool: 'machado_madeira'});
    assert.equal((await a.action('harvest', {resource: 'tree-1'})).ok, true);
    assert.equal((await a.action('harvest', {resource: 'tree-1'})).code, 'cooldown');
  });
  await t.test('late join receives current tree progress, positions and separate inventory', async () => {
    b = make(); const welcome = await b.hello(users['mp-b']);
    assert.equal(welcome.players.length, 2);
    assert.equal(welcome.resources.find(r => r.id === 'tree-1').progress, 1 / 3);
    assert.equal(welcome.inventory.madeira, 0);
    assert.ok(welcome.players.some(p => p.nickname === 'Ana'));
    await b.walk(-1, -0.6, 260); // 100,100 offset to within the same tree's reach.
  });
  await t.test('simultaneous final hits create one ground stack; concurrent pickup awards once', async () => {
    await pause(550);
    const results = await Promise.all([a.action('harvest', {resource: 'tree-1'}), b.action('harvest', {resource: 'tree-1'})]);
    assert.ok(results.every(r => r.ok), JSON.stringify(results));
    await pause(150);
    assert.equal(a.state.resources.find(r => r.id === 'tree-1').depleted, true);
    assert.equal(a.state.inventory.madeira + b.state.inventory.madeira, 0);
    const [drop]=a.state.drops;assert.equal(drop.quantity,5);
    const pickups=await Promise.all([a.action('pickup',{drop:drop.id}),b.action('pickup',{drop:drop.id})]);
    assert.equal(pickups.filter(r=>r.ok).length,1);assert.equal(pickups.find(r=>!r.ok).code,'drop_unavailable');
    await pause(150);assert.equal(a.state.inventory.madeira + b.state.inventory.madeira,5);assert.deepEqual(a.state.drops,[]);
    assert.equal((await a.action('harvest', {resource: 'tree-1'})).code, 'resource_unavailable');
    assert.equal((await b.action('harvest', {resource: 'tree-1'})).code, 'resource_unavailable');
  });
  await t.test('replayed action does not repeat rewards or alter inventories', async () => {
    const before = JSON.stringify(a.state.inventory);
    a.send({type: 'harvest', seq: a.seq, resource: 'tree-2'});
    await a.wait(m => m.code === 'replayed_action'); await pause(130);
    assert.equal(JSON.stringify(a.state.inventory), before);
  });
  await t.test('stone extraction synchronizes and rewards only the authenticated collector inventory', async () => {
    await b.walk(1, 0.25, 430);
    assert.equal((await b.action('harvest', {resource:'rock-1'})).code, 'wrong_tool');
    await b.action('equip', {tool:'picareta_madeira'});
    for (let i=0;i<6;i++) {
      await pause(550);
      assert.equal((await b.action('harvest', {resource:'rock-1', player:a.self, inventory:{pedra:999}})).ok, true);
    }
    await pause(150);
    assert.equal(b.state.inventory.pedra,0);
    const drop=b.state.drops.find(d=>d.kind==='pedra');assert.equal(drop.quantity,4);
    assert.equal((await b.action('pickup',{drop:drop.id,inventory:{pedra:999}})).ok,true);
    await pause(150);assert.equal(b.state.inventory.pedra, 4);
    assert.equal(a.state.inventory.pedra, 0);
    assert.equal(a.state.resources.find(r=>r.id==='rock-1').depleted, true);
  });
  await t.test('disconnect marks actor offline; reconnect restores same inventory and ID', async () => {
    const self = b.self, before = {...b.state.inventory}, room = b.state.room;
    b.ws.terminate(); await pause(220);
    assert.equal(a.state.players.find(p => p.id === self).online, false);
    b = make(); const welcome = await b.hello(users['mp-b']);
    assert.equal(welcome.self, self); assert.equal(welcome.room, room);
    assert.deepEqual(welcome.inventory, before); assert.equal(welcome.players.length, 2);
    assert.equal(welcome.resources.find(r => r.id === 'tree-1').depleted, true);
  });
  await t.test('same identity replaces previous socket without duplicating actor or inventory', async () => {
    const old = a, previous = {...a.state.inventory}; a = make(); await a.hello(users['mp-a']); await pause(150);
    assert.equal(old.closed.code, 4009); assert.equal(server.room.players.size, 2);
    assert.deepEqual(a.state.inventory, previous);
    assert.equal((await a.action('equip', {tool: 'picareta_madeira'})).ok, true);
  });
  await t.test('missing input expires instead of moving indefinitely', async () => {
    a.send({type: 'input', seq: ++a.input, x: 0, y: 1}); await pause(500);
    const p = a.state.players.find(p => p.id === a.self); await pause(400);
    const later = a.state.players.find(p => p.id === a.self);
    assert.equal(p.x, later.x); assert.equal(p.y, later.y);
  });
  await t.test('token refresh is verified and cannot switch the actor identity', async () => {
    a.send({type: 'refresh', token: users['mp-a'].token}); await a.wait(m => m.type === 'refreshed');
    a.send({type: 'refresh', token: users['mp-b'].token});
    assert.equal((await a.wait(m => m.type === 'error')).code, 'auth_failed');
  });
  await t.test('unexpected browser Origin is refused before authentication', async () => {
    const c = new Client(url, 'https://untrusted.example'); clients.push(c);
    await assert.rejects(c.open());
  });
  await t.test('malformed packets and flooding are refused without changing room state', async () => {
    const c = make(); await c.open(); c.ws.send('{');
    assert.equal((await c.wait(m => m.type === 'error')).code, 'invalid_message');
    const d = make(); await d.hello(users['mp-a']);
    for (let i = 0; i < 70; i++) if (d.ws.readyState === 1) d.send({type: 'input', seq: ++d.input, x: 0, y: 0});
    await d.wait(m => m.code === 'rate_limit');
    assert.equal(server.room.players.size, 2);
  });
  await t.test('restart creates new room and resets test progress', async () => {
    const fresh = await startServer({verify: token => verifier.verify(token), nickname: async ()=>'Ana', allowedUids:['mp-a','mp-b'], origins:['http://localhost:8060'], port:0});
    try {
      const client = new Client(`ws://127.0.0.1:${fresh.port}/room`); clients.push(client);
      const welcome = await client.hello(users['mp-a']);
      assert.notEqual(welcome.room, server.room.id);
      assert.equal(welcome.players.length, 1);
      assert.equal(welcome.inventory.madeira, 0); assert.equal(welcome.inventory.pedra, 0);
      assert.ok(welcome.resources.every(r => !r.depleted));
    } finally {await fresh.close();}
  });
});

test('room capacity and integral extraction with tool switching', () => {
  const room = new Room(ARENA), socket = {close() {}};
  const a = room.join({uid: 'one'}, 'One', socket), b = room.join({uid: 'two'}, 'Two', socket);
  assert.equal(room.join({uid: 'three'}, 'Three', socket), null);
  a.x = b.x = 560; a.y = b.y = 400;
  assert.equal(room.action(a, {type: 'harvest', seq: 1, resource: 'tree-1'}, 0), null);
  assert.equal(room.action(b, {type: 'equip', seq: 1, tool: 'maos'}, 0), null);
  for (let i = 0; i < 4; i++) assert.equal(room.action(b, {type: 'harvest', seq: i + 2, resource: 'tree-1'}, i * 1200), null);
  assert.equal(room.resources[0].depleted, true);
  assert.equal(a.items.count('madeira') + b.items.count('madeira'), 0);
  assert.equal([...room.drops.values()].reduce((n,d)=>n+d.quantity,0),5);
});

test('production startup refuses emulator authentication even when accidentally inherited', () => {
  assert.throws(() => firebaseVerifier({projectId: 'real-project', apiKey: 'public-key'}), /forbidden/);
});

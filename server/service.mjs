import {createServer} from 'node:http';
import {WebSocketServer, WebSocket} from 'ws';
import {Room} from './room.mjs';
import {randomBytes} from 'node:crypto';
const VERSION='0.9.0-multiplayer-pilot.6';

const safeNickname = (value, fallback) => typeof value === 'string' && /^[\p{L}\p{N}_ .-]{3,20}$/u.test(value) ? value : fallback;
export async function startServer({verify, nickname, allowedUids, origins, host = '127.0.0.1', port = 8787, layout, log = ()=>{}}) {
  if (allowedUids.length !== 2 || new Set(allowedUids).size !== 2 || !allowedUids.every(uid => typeof uid === 'string' && uid.length > 0)) throw new Error('Exactly two authorized accounts are required');
  if (!origins.length || origins.some(origin => new URL(origin).origin !== origin)) throw new Error('Explicit browser origins are required');
  const room = new Room(layout);
  const diagnostics={upgrades:0,hellos:0,authenticated:0,welcomes:0,states:0,rejected:0,closed:0};
  const event=(name,connection,code='')=>log({at:new Date().toISOString(),event:name,connection,code});
  const http = createServer((req, res) => {
    res.writeHead(req.url === '/health' ? 200 : 404, {'Content-Type': 'application/json', 'Cache-Control': 'no-store'});
    res.end(JSON.stringify(req.url === '/health' ? {ok: true, protocol: 3, version: VERSION, connected_players: [...room.players.values()].filter(p => p.socket?.readyState === WebSocket.OPEN).length,diagnostics} : {error: 'not_found'}));
  });
  const wss = new WebSocketServer({noServer: true, maxPayload: 16384, perMessageDeflate: false});
  http.on('upgrade', (req, socket, head) => {
    // Native Godot has no Origin. Authentication remains mandatory in both cases.
    if (req.url !== '/room' || (req.headers.origin && !origins.includes(req.headers.origin)) || wss.clients.size >= 8) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return;
    }
    wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws));
  });
  const send = (ws, message) => {
    if (ws.readyState !== WebSocket.OPEN) return;
    if (ws.bufferedAmount > 128 * 1024) {ws.close(4010, 'slow_client'); return;}
    ws.send(JSON.stringify(message));
  };
  wss.on('connection', ws => {
    const connection=randomBytes(4).toString('hex');diagnostics.upgrades++;
    event('socket_open',connection);
    let stateStarted=false;
    let player, authenticating = false, requests = 0, window = performance.now();
    let alive = true;
    let handshake;
    const deadline=phase=>{clearTimeout(handshake);handshake=setTimeout(()=>{event('handshake_timeout',connection,phase);ws.close(4001,phase==='authentication'?'auth_timeout':'initial_timeout');},10000);};
    deadline('authentication');
    const heartbeat = setInterval(() => {
      if (!alive) return ws.terminate();
      alive = false; ws.ping();
    }, 15000);
    ws.on('pong', () => {alive = true;});
    ws.on('error', () => {}); // Never log payloads or tokens.
    ws.on('close', code => {diagnostics.closed++;event('socket_closed',connection,String(code));clearTimeout(handshake); clearInterval(heartbeat); room.disconnect(player, ws);});
    const refuse = (code, reason) => {diagnostics.rejected++;event('rejected',connection,reason);send(ws, {type: 'error', code: reason}); ws.close(code, reason);};
    ws.on('message', async (bytes, binary) => {
      const now = performance.now();
      if (now - window > 1000) {window = now; requests = 0;}
      if (++requests > 60) return refuse(4008, 'rate_limit');
      let message;
      try {message = JSON.parse(bytes.toString());} catch {return refuse(4002, 'invalid_message');}
      if (binary || !message || typeof message !== 'object' || Array.isArray(message)) return refuse(4002, 'invalid_message');
      if (!player) {
        if (message.type === 'hello' && message.protocol !== 3) return refuse(4002, 'client_outdated');
        if (authenticating || message.type !== 'hello' || typeof message.token !== 'string' || message.token.length > 12000) return refuse(4001, 'auth_required');
        authenticating = true;
        diagnostics.hellos++;event('auth_begin',connection);
        try {
          const identity = await verify(message.token);
          if (ws.readyState !== WebSocket.OPEN) return;
          if (!allowedUids.includes(identity.uid)) return refuse(4003, 'not_authorized');
          diagnostics.authenticated++;event('auth_ok',connection);
          send(ws,{type:'authenticated',protocol:3,server_version:VERSION});
          deadline('initial_state');
          let alias;
          // Profile presentation must not turn a verified identity into an
          // authentication failure when optional Firestore lookup is unavailable.
          try{alias=await nickname(message.token, identity.uid);}
          catch{event('profile_unavailable',connection);}
          if (ws.readyState !== WebSocket.OPEN) return;
          player = room.join(identity, safeNickname(alias, `Jogador ${allowedUids.indexOf(identity.uid) + 1}`), ws);
          if (!player) return refuse(4004, 'room_full');
          clearTimeout(handshake);
          send(ws, {...room.snapshot(player), type: 'welcome', protocol: 3, self: player.id, nextAction: player.action + 1});
          ws.worldRevision=room.worldRevision;
          diagnostics.welcomes++;event('welcome_sent',connection);
          ws.markState=()=>{diagnostics.states++;if(!stateStarted){stateStarted=true;event('state_started',connection);}};
        } catch {return refuse(4001, 'auth_failed');}
        finally {message.token = ''; authenticating = false;}
        return;
      }
      if (player.socket !== ws) return refuse(4009, 'session_replaced');
      if (message.type === 'refresh') {
        if (authenticating || typeof message.token !== 'string') return refuse(4001, 'auth_failed');
        authenticating = true;
        try {
          const identity = await verify(message.token);
          if (identity.uid !== [...room.players.entries()].find(([, p]) => p === player)?.[0]) return refuse(4001, 'auth_failed');
          if (player.socket === ws) player.expires = identity.expires;
          send(ws, {type: 'refreshed'});
        } catch {return refuse(4001, 'auth_failed');}
        finally {authenticating = false; message.token = '';}
        return;
      }
      if (player.expires <= Date.now() / 1000) return refuse(4001, 'auth_expired');
      const error = message.type === 'input' ? room.move(player, message, now) : room.action(player, message, now);
      send(ws, {type: 'ack', seq: message.seq, action: message.type, ok: !error, code: error || '', effect: !error && message.type === 'well' ? (message.action === 'fill' ? 'filled' : 'drank') : ''});
    });
  });
  let last = performance.now(), snapshots = 0;
  const tick = setInterval(() => {
    const now = performance.now();
    room.step(Math.min(0.1, (now - last) / 1000), now); last = now;
    if (++snapshots % 2) return; // Simulation 20 Hz; snapshots 10 Hz.
    for (const player of room.players.values()) if (player.socket) {
      send(player.socket, room.snapshot(player,player.socket.worldRevision));
      player.socket.markState?.();
      player.socket.worldRevision=room.worldRevision;
    }
  }, 50);
  await new Promise((resolve, reject) => {http.once('error', reject); http.listen(port, host, resolve);});
  return {room, port: http.address().port, async close() {
    clearInterval(tick);
    for (const ws of wss.clients) ws.terminate();
    await new Promise(resolve => wss.close(resolve));
    await new Promise(resolve => http.close(resolve));
  }};
}

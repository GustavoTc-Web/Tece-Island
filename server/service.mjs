import {createServer} from 'node:http';
import {WebSocketServer, WebSocket} from 'ws';
import {Room} from './room.mjs';

const safeNickname = (value, fallback) => typeof value === 'string' && /^[\p{L}\p{N}_ .-]{3,20}$/u.test(value) ? value : fallback;
export async function startServer({verify, nickname, allowedUids, origins, host = '127.0.0.1', port = 8787, layout}) {
  if (allowedUids.length !== 2 || new Set(allowedUids).size !== 2 || !allowedUids.every(uid => typeof uid === 'string' && uid.length > 0)) throw new Error('Exactly two authorized accounts are required');
  if (!origins.length || origins.some(origin => new URL(origin).origin !== origin)) throw new Error('Explicit browser origins are required');
  const room = new Room(layout);
  const http = createServer((req, res) => {
    res.writeHead(req.url === '/health' ? 200 : 404, {'Content-Type': 'application/json', 'Cache-Control': 'no-store'});
    res.end(JSON.stringify(req.url === '/health' ? {ok: true, protocol: 2, version: '0.9.0-multiplayer-pilot.3', connected_players: [...room.players.values()].filter(p => p.socket?.readyState === WebSocket.OPEN).length} : {error: 'not_found'}));
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
    let player, authenticating = false, requests = 0, window = performance.now();
    let alive = true;
    const handshake = setTimeout(() => ws.close(4001, 'auth_timeout'), 10000);
    const heartbeat = setInterval(() => {
      if (!alive) return ws.terminate();
      alive = false; ws.ping();
    }, 15000);
    ws.on('pong', () => {alive = true;});
    ws.on('error', () => {}); // Never log payloads or tokens.
    ws.on('close', () => {clearTimeout(handshake); clearInterval(heartbeat); room.disconnect(player, ws);});
    const refuse = (code, reason) => {send(ws, {type: 'error', code: reason}); ws.close(code, reason);};
    ws.on('message', async (bytes, binary) => {
      const now = performance.now();
      if (now - window > 1000) {window = now; requests = 0;}
      if (++requests > 60) return refuse(4008, 'rate_limit');
      let message;
      try {message = JSON.parse(bytes.toString());} catch {return refuse(4002, 'invalid_message');}
      if (binary || !message || typeof message !== 'object' || Array.isArray(message)) return refuse(4002, 'invalid_message');
      if (!player) {
        if (message.type === 'hello' && message.protocol !== 2) return refuse(4002, 'client_outdated');
        if (authenticating || message.type !== 'hello' || typeof message.token !== 'string' || message.token.length > 12000) return refuse(4001, 'auth_required');
        authenticating = true;
        try {
          const identity = await verify(message.token);
          if (ws.readyState !== WebSocket.OPEN) return;
          if (!allowedUids.includes(identity.uid)) return refuse(4003, 'not_authorized');
          const alias = await nickname(message.token, identity.uid);
          if (ws.readyState !== WebSocket.OPEN) return;
          player = room.join(identity, safeNickname(alias, `Jogador ${allowedUids.indexOf(identity.uid) + 1}`), ws);
          if (!player) return refuse(4004, 'room_full');
          clearTimeout(handshake);
          send(ws, {...room.snapshot(player), type: 'welcome', protocol: 2, self: player.id, nextAction: player.action + 1});
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
    for (const player of room.players.values()) if (player.socket) send(player.socket, room.snapshot(player));
  }, 50);
  await new Promise((resolve, reject) => {http.once('error', reject); http.listen(port, host, resolve);});
  return {room, port: http.address().port, async close() {
    clearInterval(tick);
    for (const ws of wss.clients) ws.terminate();
    await new Promise(resolve => wss.close(resolve));
    await new Promise(resolve => http.close(resolve));
  }};
}

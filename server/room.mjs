import {randomUUID} from 'node:crypto';

// Same starter tools, extraction rewards, hits and intervals as ResourceRules.
export const RULES = {
  madeira: {reward: 5, hits: {maos: 6, machado_madeira: 3}},
  pedra: {reward: 4, hits: {picareta_madeira: 6}}
};
export const INTERVAL = {maos: 1.2, machado_madeira: 0.54, picareta_madeira: 0.54};
export const WORLD = {width: 1280, height: 900, speed: 210, reach: 82};
export class Room {
  constructor() {
    this.id = randomUUID();
    this.revision = 0;
    this.players = new Map();
    this.resources = [
      ['tree-1', 'madeira', 560, 350], ['rock-1', 'pedra', 730, 450],
      ['tree-2', 'madeira', 330, 450], ['rock-2', 'pedra', 420, 580],
      ['tree-3', 'madeira', 870, 310], ['rock-3', 'pedra', 940, 580],
      ['tree-4', 'madeira', 250, 240], ['rock-4', 'pedra', 1040, 240],
      ['tree-5', 'madeira', 570, 690], ['rock-5', 'pedra', 700, 710],
      ['tree-6', 'madeira', 140, 650], ['rock-6', 'pedra', 1120, 730]
    ].map(([id, kind, x, y]) => ({id, kind, x, y, hits: 0, depleted: false}));
  }
  join(identity, nickname, socket) {
    let player = this.players.get(identity.uid);
    if (!player && this.players.size >= 2) return null;
    if (!player) {
      const slot = this.players.size;
      player = {id: `player-${slot + 1}`, x: 600 + slot * 60, y: 450, dx: 0, dy: 0,
        inventory: {machado_madeira: 1, picareta_madeira: 1, madeira: 0, pedra: 0},
        tool: 'machado_madeira', action: 0, lastHit: -Infinity};
      this.players.set(identity.uid, player);
    }
    // A verified identity owns exactly one actor, even after socket replacement.
    const previous = player.socket;
    player.socket = socket;
    player.nickname = nickname;
    player.expires = identity.expires;
    player.input = 0;
    player.dx = player.dy = 0;
    player.inputAt = performance.now();
    if (previous && previous !== socket) previous.close(4009, 'session_replaced');
    this.revision++;
    return player;
  }
  disconnect(player, socket) {
    if (player?.socket !== socket) return;
    player.socket = null;
    player.dx = player.dy = 0;
    this.revision++;
  }
  move(player, message, now) {
    if (!Number.isSafeInteger(message.seq) || message.seq <= player.input ||
        !Number.isFinite(message.x) || !Number.isFinite(message.y) ||
        Math.abs(message.x) > 1 || Math.abs(message.y) > 1) return 'invalid_input';
    player.input = message.seq;
    const length = Math.max(1, Math.hypot(message.x, message.y));
    player.dx = message.x / length;
    player.dy = message.y / length;
    player.inputAt = now;
    return null;
  }
  action(player, message, now) {
    if (!Number.isSafeInteger(message.seq) || message.seq <= player.action) return 'replayed_action';
    player.action = message.seq;
    if (message.type === 'equip') {
      if (!Object.hasOwn(INTERVAL, message.tool) || (message.tool !== 'maos' && !(player.inventory[message.tool] > 0))) return 'invalid_tool';
      player.tool = message.tool;
      this.revision++;
      return null;
    }
    if (message.type !== 'harvest') return 'invalid_action';
    const resource = this.resources.find(r => r.id === message.resource);
    if (!resource || resource.depleted) return 'resource_unavailable';
    if (Math.hypot(player.x - resource.x, player.y - resource.y) > WORLD.reach) return 'too_far';
    if (!Object.hasOwn(RULES[resource.kind].hits, player.tool) ||
        (player.tool !== 'maos' && !(player.inventory[player.tool] > 0))) return 'wrong_tool';
    if (now - player.lastHit < INTERVAL[player.tool] * 1000 - 1) return 'cooldown';
    player.lastHit = now;
    // Integral work units permit tool switching without floating point rewards.
    resource.hits += 6 / RULES[resource.kind].hits[player.tool];
    if (resource.hits >= 6) {
      resource.depleted = true; // Set before awarding; no await in this transaction.
      player.inventory[resource.kind] += RULES[resource.kind].reward;
    }
    this.revision++;
    return null;
  }
  step(dt, now) {
    for (const p of this.players.values()) {
      if (!p.socket) continue;
      if (p.expires <= Date.now() / 1000) { p.socket.close(4001, 'auth_expired'); this.disconnect(p, p.socket); continue; }
      if (now - p.inputAt > 350) p.dx = p.dy = 0;
      const nextX = Math.max(16, Math.min(WORLD.width - 16, p.x + p.dx * WORLD.speed * dt));
      const nextY = Math.max(45, Math.min(WORLD.height - 16, p.y + p.dy * WORLD.speed * dt));
      const free = (x, y) => !this.resources.some(r => !r.depleted && Math.hypot(x - r.x, y - r.y) < (r.kind === 'madeira' ? 25 : 33));
      if (free(nextX, p.y)) p.x = nextX;
      if (free(p.x, nextY)) p.y = nextY;
    }
    this.revision++;
  }
  snapshot(forPlayer) {
    return {type: 'state', room: this.id, revision: this.revision, world: WORLD,
      players: [...this.players.values()].map(p => ({id: p.id, nickname: p.nickname, x: p.x, y: p.y,
        dx: p.dx, dy: p.dy, online: !!p.socket, tool: p.tool})),
      resources: this.resources.map(r => ({...r, progress: r.hits / 6})),
      inventory: {...forPlayer.inventory}, tool: forPlayer.tool};
  }
}

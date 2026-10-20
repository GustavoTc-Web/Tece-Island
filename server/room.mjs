import {randomUUID} from 'node:crypto';
import {WORLD_DATA, WORLD_HASH, WorldGeometry} from './world.mjs';
import {Inventory} from './inventory.mjs';

export const RULES = WORLD_DATA.extraction;
export const INTERVAL = WORLD_DATA.interval;
export const WORLD = {bounds:WORLD_DATA.bounds,speed:WORLD_DATA.speed,reach:WORLD_DATA.reach};
export class Room {
  constructor(layout=WORLD_DATA) {
    this.id=randomUUID();this.revision=0;this.players=new Map();
    this.layout=layout;this.geometry=new WorldGeometry(layout);
    this.resources=layout.resources.map(r=>({...r,hits:0,depleted:false}));
    this.resourceIndex=new Map(this.resources.map(r=>[r.id,r]));
    this.wells=new Map(layout.wells.map(w=>[w.id,w]));
    this.depleted=new Set();
  }
  join(identity,nickname,socket) {
    let player=this.players.get(identity.uid);
    if(!player&&this.players.size>=2)return null;
    if(!player) {
      const slot=this.players.size,[x,y]=this.layout.spawns[slot];
      player={id:`player-${slot+1}`,x,y,dx:0,dy:0,items:new Inventory(),tool:'machado_madeira',action:0,lastHit:-Infinity,lastWell:-Infinity,thirst:this.layout.water.maximum,swing:0};
      this.players.set(identity.uid,player);
    }
    const previous=player.socket;
    player.socket=socket;player.nickname=nickname;player.expires=identity.expires;
    player.input=0;player.dx=player.dy=0;player.inputAt=performance.now();
    if(previous&&previous!==socket)previous.close(4009,'session_replaced');
    this.revision++;return player;
  }
  disconnect(player,socket) {
    if(player?.socket!==socket)return;
    player.socket=null;player.dx=player.dy=0;this.revision++;
  }
  move(player,message,now) {
    if(!Number.isSafeInteger(message.seq)||message.seq<=player.input||!Number.isFinite(message.x)||!Number.isFinite(message.y)||Math.abs(message.x)>1||Math.abs(message.y)>1)return 'invalid_input';
    player.input=message.seq;const length=Math.max(1,Math.hypot(message.x,message.y));
    player.dx=message.x/length;player.dy=message.y/length;player.inputAt=now;return null;
  }
  action(player,message,now) {
    if(!Number.isSafeInteger(message.seq)||message.seq<=player.action)return 'replayed_action';
    player.action=message.seq;
    let error;
    if(message.type==='equip')error=player.items.equip(message.tool);
    else if(message.type==='select'||message.type==='equip_slot')error=player.items.select(message.index);
    else if(message.type==='swap')error=player.items.swap(message.from,message.to);
    else if(message.type==='use') {
      error=player.items.use(message.index);
      if(!error)player.thirst=Math.min(this.layout.water.maximum,player.thirst+this.layout.water.restores);
    } else if(message.type==='well') {
      const well=this.wells.get(message.well);
      if(!well)return 'well_unavailable';
      if(Math.hypot(player.x-well.x,player.y-well.y)>this.layout.well_reach)return 'too_far';
      if(!this.geometry.sight(player,well,this.depleted,well.id))return 'blocked_path';
      if(!['drink','fill'].includes(message.action))return 'invalid_action';
      if(now-player.lastWell<500)return 'cooldown';
      if(message.action==='drink')player.thirst=Math.min(this.layout.water.maximum,player.thirst+this.layout.water.restores);
      else error=player.items.fill();
      if(!error)player.lastWell=now;
    } else if(message.type==='harvest') {
      const resource=this.resourceIndex.get(message.resource);
      if(!resource||resource.depleted)return 'resource_unavailable';
      if(Math.hypot(player.x-resource.x,player.y-resource.y)>this.layout.reach)return 'too_far';
      if(!this.geometry.sight(player,resource,this.depleted,resource.id))return 'blocked_path';
      const rule=this.layout.extraction[resource.kind];
      if(!Object.hasOwn(rule.hits,player.tool))return 'wrong_tool';
      if(now-player.lastHit<this.layout.interval[player.tool]*1000-1)return 'cooldown';
      const work=6/rule.hits[player.tool];
      if(resource.hits+work>=6&&!player.items.add(resource.kind,rule.reward))return 'inventory_full';
      player.lastHit=now;resource.hits+=work;
      if(resource.hits>=6){resource.depleted=true;this.depleted.add(resource.id);}
      player.swing=message.seq;player.sx=resource.x;player.sy=resource.y;
    } else return 'invalid_action';
    if(error)return error;
    player.tool=player.items.tool();this.revision++;return null;
  }
  step(dt,now) {
    dt=Math.max(0,Math.min(.1,dt));
    for(const p of this.players.values()) {
      if(!p.socket)continue;
      if(p.expires<=Date.now()/1000){p.socket.close(4001,'auth_expired');this.disconnect(p,p.socket);continue;}
      if(now-p.inputAt>350)p.dx=p.dy=0;
      p.thirst=Math.max(0,p.thirst-this.layout.water.per_minute*dt/60);
      const speed=this.layout.speed*(this.geometry.water(p.x,p.y)?this.layout.swim_speed:1);
      const count=Math.max(1,Math.ceil(speed*dt/3)),mx=p.dx*speed*dt/count,my=p.dy*speed*dt/count;
      for(let i=0;i<count;i++) {
        if(this.geometry.free(p.x+mx,p.y,this.depleted))p.x+=mx;
        if(this.geometry.free(p.x,p.y+my,this.depleted))p.y+=my;
      }
    }
    this.revision++;
  }
  snapshot(forPlayer) {
    return {type:'state',room:this.id,revision:this.revision,
      world:{...WORLD,hash:WORLD_HASH,version:this.layout.version},
      players:[...this.players.values()].map(p=>({id:p.id,nickname:p.nickname,x:p.x,y:p.y,dx:p.dx,dy:p.dy,online:!!p.socket,tool:p.tool,swimming:this.geometry.water(p.x,p.y),swing:p.swing,sx:p.sx||p.x,sy:p.sy||p.y})),
      // Send changes only; late join receives every change since room reset.
      resources:this.resources.filter(r=>r.hits>0||this.layout.fixture).map(r=>({id:r.id,hits:r.hits,depleted:r.depleted,progress:r.hits/6})),
      inventory:forPlayer.items.counts(),slots:forPlayer.items.snapshot(),tool:forPlayer.tool,thirst:forPlayer.thirst};
  }
}

import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';

const bytes = readFileSync(new URL('../assets/data/multiplayer-world.json', import.meta.url));
export const WORLD_DATA = JSON.parse(bytes);
export const WORLD_HASH = createHash('sha256').update(bytes).digest('hex');
const inside = (x,y,r) => x>=r[0]&&y>=r[1]&&x<r[0]+r[2]&&y<r[1]+r[3];
export class WorldGeometry {
  constructor(data) {
    this.data=data;this.cells=new Map();
    for(const c of data.colliders) {
      const rx=(c.type==='circle'?c.radius:c.size[0]/2)+data.player_radius,ry=(c.type==='circle'?c.radius:c.size[1]/2)+data.player_radius;
      for(let x=Math.floor((c.x-rx)/128);x<=Math.floor((c.x+rx)/128);x++)for(let y=Math.floor((c.y-ry)/128);y<=Math.floor((c.y+ry)/128);y++){
        const key=x+':'+y;if(!this.cells.has(key))this.cells.set(key,[]);this.cells.get(key).push(c);
      }
    }
  }
  at(x,y) {return this.cells.get(Math.floor(x/128)+':'+Math.floor(y/128))||[];}
  region(x,y) {return this.data.regions.find(r=>inside(x,y,r.rect));}
  contains(x,y) {return !!this.region(x,y);}
  water(x,y) {
    if(this.data.ponds.some(r=>inside(x,y,r)))return true;
    const region=this.region(x,y);
    if(region?.kind!=='Aquático')return false;
    const [, ,w,h]=region.rect, lx=x-region.rect[0],ly=y-region.rect[1];
    if(lx<14||ly<14||lx>w-14||ly>h-14||Math.abs(lx-w/2)<46||Math.abs(ly-h/2)<46)return false;
    return ![[.25,.25],[.75,.75],[.25,.75]].some(([a,b])=>Math.hypot(lx-w*a,ly-h*b)<=112);
  }
  overlaps(x,y,c,radius=0) {
    if(c.type==='circle')return Math.hypot(x-c.x,y-c.y)<c.radius+radius;
    const dx=Math.max(0,Math.abs(x-c.x)-c.size[0]/2),dy=Math.max(0,Math.abs(y-c.y)-c.size[1]/2);
    return dx*dx+dy*dy<radius*radius || (radius===0&&Math.abs(x-c.x)<c.size[0]/2&&Math.abs(y-c.y)<c.size[1]/2);
  }
  free(x,y,depleted=new Set(),radius=this.data.player_radius) {
    if(![[0,0],[radius,0],[-radius,0],[0,radius],[0,-radius]].every(([dx,dy])=>this.contains(x+dx,y+dy)))return false;
    return !this.at(x,y).some(c=>!depleted.has(c.owner)&&this.overlaps(x,y,c,radius));
  }
  sight(from,to,depleted,ignore='') {
    const length=Math.hypot(to.x-from.x,to.y-from.y),steps=Math.max(1,Math.ceil(length/3));
    for(let i=1;i<steps;i++) {
      const x=from.x+(to.x-from.x)*i/steps,y=from.y+(to.y-from.y)*i/steps;
      if(!this.contains(x,y)||this.at(x,y).some(c=>(!ignore||c.owner!==ignore)&&!depleted.has(c.owner)&&this.overlaps(x,y,c,0)))return false;
    }
    return true;
  }
}

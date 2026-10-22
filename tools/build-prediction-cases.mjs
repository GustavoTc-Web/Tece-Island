import {Room} from '../server/room.mjs';
import {WORLD_DATA} from '../server/world.mjs';
import {writeFile} from 'node:fs/promises';
const cases=[];
for(const [index,region]of WORLD_DATA.regions.entries()){
 const room=new Room(),player=room.join({uid:'fixture',expires:Date.now()/1000+3600},'Teste',{close(){}});
 let start;
 for(let x=region.rect[0]+20;x<region.rect[0]+region.rect[2]&&!start;x+=31)for(let y=region.rect[1]+20;y<region.rect[1]+region.rect[3];y+=37)if(room.geometry.free(x,y,room.depleted)){start=[x,y];break;}
 const points=[start,[region.rect[0]+region.rect[2]/2+60,region.rect[1]+region.rect[3]/2+60]];
 for(const point of points){
  if(!room.geometry.free(...point,room.depleted))continue;
  player.x=point[0];player.y=point[1];const steps=[];
  for(let i=0;i<24;i++){
   const angle=(i+index)*1.7,dt=[1/60,.05,.1,.0333][i%4],dx=Math.cos(angle),dy=Math.sin(angle),now=performance.now();
   room.move(player,{seq:player.input+1,x:dx,y:dy},now);room.step(dt,now);
   steps.push({direction:[dx,dy],dt,position:[player.x,player.y]});
  }
  cases.push({name:region.id,start:point,steps});
 }
}
// Approach actual circular/rectangular colliders and world edges.
for(const collider of WORLD_DATA.colliders.slice(0,20)){
 const room=new Room(),p=room.join({uid:'fixture',expires:Date.now()/1000+3600},'Teste',{close(){}});
 const half=collider.type==='circle'?collider.radius:collider.size[0]/2,start=[collider.x-half-WORLD_DATA.player_radius-1,collider.y];
 if(!room.geometry.free(...start,room.depleted))continue;p.x=start[0];p.y=start[1];const steps=[];
 for(let i=0;i<12;i++){const now=performance.now();room.move(p,{seq:i+1,x:1,y:0},now);room.step(.05,now);steps.push({direction:[1,0],dt:.05,position:[p.x,p.y]});}cases.push({name:'collider-'+collider.owner,start,steps});
}
await writeFile('.tools/prediction-cases.json',JSON.stringify(cases));console.log(cases.length+' authoritative Room trajectories');

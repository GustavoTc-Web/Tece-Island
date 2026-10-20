import {WORLD_DATA} from '../world.mjs';

// Small deterministic fixture retains the .2 protocol regression scenarios.
// Production startServer() always defaults to the exported solo-world layout.
const resources=[['tree-1','madeira',560,350],['rock-1','pedra',730,450],['tree-2','madeira',330,450],['rock-2','pedra',420,580],['tree-3','madeira',870,310],['rock-3','pedra',940,580],['tree-4','madeira',250,240],['rock-4','pedra',1040,240],['tree-5','madeira',570,690],['rock-5','pedra',700,710],['tree-6','madeira',140,650],['rock-6','pedra',1120,730]].map(([id,kind,x,y])=>({id,kind,x,y}));
export const ARENA={...WORLD_DATA,fixture:true,bounds:[0,0,1280,900],regions:[{id:'forest',kind:'Floresta',rect:[0,0,1280,900]}],ponds:[],resources,wells:[],buildings:[],spawns:[[600,450],[660,450]],colliders:resources.map(r=>({owner:r.id,type:'circle',x:r.x,y:r.y,radius:r.kind==='madeira'?15:23}))};

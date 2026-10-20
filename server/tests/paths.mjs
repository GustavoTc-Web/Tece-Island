// Test navigation submits ordinary movement; no teleport action exists.
export function segmentFree(g,a,b) {
  const n=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/6));
  for(let i=1;i<=n;i++)if(!g.free(a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n))return false;
  return true;
}
export function reachable(g,from,step=32) {
  const key=p=>p[0]+':'+p[1],start=from.map(n=>Math.round(n/step)*step);
  if(!g.free(...start)||!segmentFree(g,from,start))throw Error('Blocked path start');
  const queue=[start],parents=new Map([[key(start),null]]);
  for(let index=0;index<queue.length;index++) {
    const p=queue[index];
    for(const [dx,dy]of [[step,0],[-step,0],[0,step],[0,-step]]){
      const q=[p[0]+dx,p[1]+dy],k=key(q);
      if(parents.has(k)||!g.free(...q)||!segmentFree(g,p,q))continue;
      parents.set(k,p);queue.push(q);
    }
  }
  return {from,start,queue,parents,step};
}
export function route(tree,to) {
  const key=p=>p[0]+':'+p[1];
  let end=tree.queue.reduce((best,p)=>Math.hypot(p[0]-to[0],p[1]-to[1])<Math.hypot(best[0]-to[0],best[1]-to[1])?p:best,tree.start);
  if(Math.hypot(end[0]-to[0],end[1]-to[1])>64)throw Error('Destination unreachable: '+to);
  const path=[];for(let p=end;p;p=tree.parents.get(key(p)))path.push(p);
  path.reverse();
  const result=[tree.from];let direction='';
  for(let i=1;i<path.length;i++) {
    const d=(path[i][0]-path[i-1][0])+':'+(path[i][1]-path[i-1][1]);
    if(d!==direction){result.push(path[i-1]);direction=d;}
  }
  result.push(end);return result.filter((p,i)=>!i||key(p)!==key(result[i-1]));
}

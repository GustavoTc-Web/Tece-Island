// Identical RFC6455 control-ping measurement on local and public paths of the
// SAME running server. No Firebase identity, game action, character or mutation.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {WebSocket} from '../server/node_modules/ws/wrapper.mjs';
const runtime=JSON.parse(await readFile('.tools/mp-runtime.json','utf8'));
const stat=a=>{const s=[...a].sort((x,y)=>x-y),q=p=>s[Math.min(s.length-1,Math.floor(s.length*p))]||0;return {n:s.length,p50:q(.5),p95:q(.95),max:q(1)};};
const result={physical:false,scope:'same live server, WebSocket control RTT only; not authenticated input-to-display time',paths:[]};
for(const [path,url] of [['local',`ws://127.0.0.1:${runtime.port}/room`],['public',runtime.wss]]){
 const rtts=[],gaps=[];let version='';
 const health=await(await fetch(url.replace(/^ws/,'http').replace('/room','/health'),{signal:AbortSignal.timeout(10000)})).json();version=health.version;
 for(let batch=0;batch<5;batch++)await new Promise((resolve,reject)=>{
  const ws=new WebSocket(url,{origin:'https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site',handshakeTimeout:10000});let began=0,count=0;
  const timer=setTimeout(()=>{ws.terminate();reject(Error('ping_timeout'));},9000);
  const ping=()=>{began=performance.now();ws.ping(String(count));};
  ws.on('open',ping);ws.on('error',reject);ws.on('pong',()=>{
   rtts.push(performance.now()-began);
   if(++count===12){clearTimeout(timer);ws.close();resolve();}else setTimeout(ping,100);
  });
 });
 for(let i=1;i<rtts.length;i++)gaps.push(Math.abs(rtts[i]-rtts[i-1]));
 result.paths.push({path,url,version,rtt_ms:stat(rtts),rtt_variation_ms:stat(gaps)});
}
await mkdir('.tools/performance',{recursive:true});await writeFile(`.tools/performance/public-${process.argv[2]||'sample'}.json`,JSON.stringify(result,null,2));console.log(JSON.stringify(result));

// Measures public tunnel transport without accessing real Firebase sessions.
// Anonymous rejection RTT is not authenticated game input-to-display latency.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import WebSocket from '../server/node_modules/ws/wrapper.mjs';
const runtime=JSON.parse(await readFile(process.argv[2]||'.tools/mp-runtime.json','utf8'));
const health=runtime.wss.replace('wss:','https:').replace('/room','/health'),https=[],connect=[],rejection=[];
for(let i=0;i<10;i++){const t=performance.now(),r=await fetch(health,{signal:AbortSignal.timeout(15000)});const body=await r.json();if(!r.ok||!body.ok)throw Error('Unhealthy endpoint');https.push(performance.now()-t);}
for(let i=0;i<5;i++)await new Promise((resolve,reject)=>{
 const began=performance.now(),ws=new WebSocket(runtime.wss,{origin:'https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site',handshakeTimeout:15000});let sent=0;
 const timer=setTimeout(()=>{ws.terminate();reject(Error('No auth refusal'));},15000);
 ws.on('open',()=>{connect.push(performance.now()-began);sent=performance.now();ws.send(JSON.stringify({type:'input',seq:1,x:0,y:0}));});
 ws.on('message',b=>{const m=JSON.parse(b);if(m.type==='error'&&m.code==='auth_required'){rejection.push(performance.now()-sent);clearTimeout(timer);ws.close();resolve();}else reject(Error('Unexpected unauthenticated response'));});ws.on('error',reject);
});
const stat=a=>{a.sort((x,y)=>x-y);return{n:a.length,p50:+a[Math.floor(a.length*.5)].toFixed(2),p95:+a[Math.min(a.length-1,Math.floor(a.length*.95))].toFixed(2),max:+a.at(-1).toFixed(2)};};
const result={endpoint:runtime.wss,measured_at:new Date().toISOString(),physical:false,authenticated_game_latency:false,https_health_ms:stat(https),wss_connect_ms:stat(connect),anonymous_rejection_rtt_ms:stat(rejection)};
await mkdir('.tools/performance',{recursive:true});await writeFile(`.tools/performance/transport-${process.argv[3]||'sample'}.json`,JSON.stringify(result,null,2));console.log(JSON.stringify(result));

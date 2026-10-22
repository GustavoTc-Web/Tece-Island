// Comparable before/after workload. Full Godot Web, two separate browser
// processes, real WS, Auth emulator; delay proxy is loopback-only.
import {createServer} from 'node:http';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {monitorEventLoopDelay} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {WebSocketServer,WebSocket} from '../server/node_modules/ws/wrapper.mjs';
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {startServer} from '../server/service.mjs';
import {firebaseVerifier} from '../server/auth.mjs';
import {identities,pause} from '../server/tests/helpers.mjs';
import {WORLD_DATA} from '../server/world.mjs';
const label=process.argv[2],profile=process.argv[3]||'local',delay=profile==='lag'?120:0,jitter=profile==='lag'?30:0;
const root=resolve(process.argv[4]||'build/multiplayer-fixture'),users=await identities();
const verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true});
let tickTotals=[];
const originalInterval=globalThis.setInterval;
globalThis.setInterval=(callback,interval,...args)=>originalInterval((...values)=>{const began=performance.now();callback(...values);if(interval===50)tickTotals.push(performance.now()-began);},interval,...args);
const server=await startServer({verify:t=>verifier.verify(t),nickname:async(_,u)=>u,allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:8788});
globalThis.setInterval=originalInterval;
const relay=new WebSocketServer({host:'127.0.0.1',port:8789}),browsers=[],pages=[],errors=[],connections=[];
let seed=7123;const random=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/2**32;};
relay.on('connection',front=>{
 const back=new WebSocket('ws://127.0.0.1:8788/room',{origin:'http://localhost:8060'});connections.push(front,back);
 const forward=(from,to)=>{let next=0;from.on('message',(bytes,binary)=>{const due=Math.max(performance.now()+delay+(random()*2-1)*jitter,next);next=due+0.01;setTimeout(()=>{if(to.readyState===1)to.send(bytes,{binary});},Math.max(0,due-performance.now()));});};
 back.on('open',()=>{forward(front,back);forward(back,front);});
 for(const [from,to]of [[front,back],[back,front]]){from.on('close',()=>to.close());from.on('error',()=>{});}
});
const http=createServer(async(req,res)=>{const p=resolve(root,'.'+(req.url==='/'?'/index.html':req.url.split('?')[0]));if(!p.startsWith(root+sep)){res.writeHead(403).end();return;}try{res.writeHead(200,{'Content-Type':{'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.ttf':'font/ttf'}[extname(p)]||'application/octet-stream'});res.end(await readFile(p));}catch{res.writeHead(404).end();}});
await new Promise(r=>http.listen(8060,'127.0.0.1',r));
let timings=[],gaps=[],builds=[],sizes=[],stateSizes=[],counts={state:0,ack:0,input:0,other:0},previous=0;
const step=server.room.step.bind(server.room),snapshot=server.room.snapshot.bind(server.room);
server.room.step=(dt,now)=>{const began=performance.now();step(dt,now);timings.push(performance.now()-began);if(previous)gaps.push(now-previous);previous=now;};
server.room.snapshot=(p,revision)=>{const began=performance.now(),state=snapshot(p,revision);builds.push(performance.now()-began);return state;};
const stat=a=>{const s=a.filter(Number.isFinite).sort((x,y)=>x-y),q=p=>s[Math.min(s.length-1,Math.floor(s.length*p))]||0;return {n:s.length,p50:+q(.5).toFixed(3),p95:+q(.95).toFixed(3),p99:+q(.99).toFixed(3),max:+q(1).toFixed(3)};};
const loop=monitorEventLoopDelay({resolution:10});loop.enable();
const dpr=Number(process.env.MP_DPR||1);
const result={label,profile,physical:false,renderer:'SwiftShader',device_pixel_ratio:dpr,render_override:process.env.MP_NATIVE_RENDER==='1'?'native':'build default',server_version:'0.9.0-multiplayer-pilot.6',transport:'real loopback WS with FIFO delay proxy',one_way_delay_ms:delay,jitter_ms:jitter,phases:[],errors};
result.client_build=JSON.parse(await readFile(resolve(root,'version.json'),'utf8'));
result.client_pck_sha256=createHash('sha256').update(await readFile(resolve(root,'index.pck'))).digest('hex');
result.server_source_sha256=createHash('sha256').update(await readFile('server/service.mjs')).digest('hex');
const state=p=>p.evaluate(()=>window.tcMpState);
async function phase(name,ms,work){
 timings=[];gaps=[];builds=[];sizes=[];stateSizes=[];tickTotals=[];counts={state:0,ack:0,input:0,other:0};loop.reset();
 await Promise.all(pages.map(p=>p.evaluate(()=>{window.benchFrames=[];window.benchRtts=[];window.benchSamples=[];window.benchLast=0;window.benchActive=true;window.tcMpFixture(JSON.stringify({action:'probe_reset'}));})));
 const sample=setInterval(()=>{for(const p of pages)p.evaluate(()=>{const s=window.tcMpState;window.benchSamples.push([s.process_ms,s.draw_calls,s.primitives,s.apply_us,s.net,s.prediction]);}).catch(()=>{});},200);
 if(work)await work();else await pause(ms);
 clearInterval(sample);
 const clients=await Promise.all(pages.map(p=>p.evaluate(()=>{window.benchActive=false;const c=document.querySelector('#canvas');return {frames:window.benchFrames,rtts:window.benchRtts,samples:window.benchSamples,responses:window.tcMpState.response_ms,online:window.tcMpState.online,canvas_pixels:[c.width,c.height],canvas_css:[c.getBoundingClientRect().width,c.getBoundingClientRect().height]};})));
 const data={name,duration_ms:ms,server_step_ms:stat(timings),server_tick_ms:stat(gaps),full_tick_cpu_ms:stat(tickTotals),snapshot_build_ms:stat(builds),state_bytes:stat(stateSizes),server_event_loop_p95_ms:loop.percentile(95)/1e6,sent_bytes:sizes.reduce((a,b)=>a+b,0),message_counts:counts,
 clients:clients.map((c,i)=>({format:i?'mobile-emulated-640x360':'PC-1920x950',online:c.online,canvas_pixels:c.canvas_pixels,canvas_css:c.canvas_css,frame_ms:stat(c.frames),frames_over_50:c.frames.filter(x=>x>50).length,process_ms:stat(c.samples.map(x=>x[0])),apply_us:stat(c.samples.map(x=>x[3])),draw_calls:stat(c.samples.map(x=>x[1])),input_response_ms:stat(c.responses),input_ack_rtt_ms:stat(c.rtts),rtt_variation_ms:stat(c.rtts.slice(1).map((v,i)=>Math.abs(v-c.rtts[i]))),correction_units:stat(c.samples.map(x=>x[5]?.correction)),last_net:c.samples.at(-1)?.[4]}))};result.phases.push(data);console.log(JSON.stringify(data));
}
try{
 for(const [i,uid]of ['mp-a','mp-b'].entries()){
  const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});browsers.push(browser);
  const page=await browser.newPage({viewport:i?{width:640,height:360}:{width:1920,height:950},hasTouch:!!i,deviceScaleFactor:dpr});pages.push(page);
  await page.addInitScript(()=>{
   window.benchActive=false;window.benchFrames=[];window.benchRtts=[];
   const Original=window.WebSocket;window.WebSocket=class extends Original{
    constructor(...args){super(...args);this.sentTimes=new Map();this.addEventListener('message',e=>{if(typeof e.data!=='string')return;const m=JSON.parse(e.data);if(m.type==='ack'&&m.action==='input'&&this.sentTimes.has(m.seq)){if(window.benchActive)window.benchRtts.push(performance.now()-this.sentTimes.get(m.seq));this.sentTimes.delete(m.seq);}});}
    send(data){try{const m=JSON.parse(typeof data==='string'?data:new TextDecoder().decode(data));if(m.type==='input')this.sentTimes.set(m.seq,performance.now());}catch{}super.send(data);}
   };
   function frame(t){if(window.benchActive){if(window.benchLast)window.benchFrames.push(t-window.benchLast);window.benchLast=t;}requestAnimationFrame(frame);}requestAnimationFrame(frame);
  });
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&/SCRIPT ERROR|Parse Error|Invalid call|Invalid access/.test(m.text()))errors.push(m.text());});
  await page.goto('http://localhost:8060/');await page.waitForFunction(()=>window.tcMpState?.ready,null,{timeout:60000});
  await page.evaluate(u=>window.tcMpFixture(JSON.stringify({action:'connect',...u})),users[uid]);await page.waitForFunction(()=>window.tcMpState.online,null,{timeout:30000});
  if(process.env.MP_NATIVE_RENDER==='1')await page.evaluate(()=>window.tcMpFixture(JSON.stringify({action:'graphics'})));
 }
 for(const p of server.room.players.values()){
  const ws=p.socket,send=ws.send.bind(ws);ws.send=(bytes,...args)=>{const size=Buffer.byteLength(bytes);sizes.push(size);const m=JSON.parse(bytes);if(m.type==='state')stateSizes.push(size);counts[m.type]=(counts[m.type]||0)+1;return send(bytes,...args);};ws.on('message',bytes=>{const m=JSON.parse(bytes);if(m.type==='input')counts.input++;});
 }
 await pause(1500);await phase('idle',5000);
 for(const [i,p]of [...server.room.players.values()].entries()){p.x=1152+i*60;p.y=576;}
 await Promise.all(pages.map(p=>p.keyboard.down('d')));await phase('simultaneous-exploration',8000);await Promise.all(pages.map(p=>p.keyboard.up('d')));
 for(const [i,p]of [...server.room.players.values()].entries()){p.x=1368+i*64;p.y=576;}
 await pause(800);await Promise.all(pages.map(p=>p.keyboard.down('f')));await phase('shared-harvest',5000);await Promise.all(pages.map(p=>p.keyboard.up('f')));
 for(const [i,p]of [...server.room.players.values()].entries()){p.x=1152+i*60;p.y=576;}
 await pause(1000);await phase('input-onset',7500,async()=>{for(let n=0;n<6;n++){const keys=n%2?['d','a']:['a','d'];await Promise.all(pages.map((p,i)=>p.keyboard.down(keys[i])));await pause(350);await Promise.all(pages.map((p,i)=>p.keyboard.up(keys[i])));await pause(900);}});
 let index=0;const sweep=setInterval(()=>{const r=WORLD_DATA.regions[index++%18].rect;for(const [i,p]of [...server.room.players.values()].entries()){p.x=r[0]+r[2]/2+64+i*40;p.y=r[1]+r[3]/2;}},500);await phase('18-biomes-camera-sweep',9000);clearInterval(sweep);
 if(errors.length)throw Error(errors.join('\n'));
}finally{loop.disable();for(const b of browsers)await b.close();for(const c of connections)c.terminate();await new Promise(r=>relay.close(r));await server.close();await verifier.close();await new Promise(r=>http.close(r));await mkdir('.tools/performance',{recursive:true});await writeFile(`.tools/performance/${label}-${profile}.json`,JSON.stringify(result,null,2));}

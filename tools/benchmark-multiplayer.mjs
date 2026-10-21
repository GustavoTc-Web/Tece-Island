// Controlled Web workload. Two independent Edge processes, software WebGL;
// Firebase Auth emulator only. These numbers are not physical PC/phone results.
import {createServer} from 'node:http';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {startServer} from '../server/service.mjs';
import {firebaseVerifier} from '../server/auth.mjs';
import {identities,pause} from '../server/tests/helpers.mjs';
import {WORLD_DATA} from '../server/world.mjs';

const label=process.argv[2]||'measurement',users=await identities();
const verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true});
const server=await startServer({verify:t=>verifier.verify(t),nickname:async(_,u)=>u,allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:8789});
const root=resolve('build/multiplayer-fixture'),browsers=[],pages=[],sessions=[],errors=[];
const http=createServer(async(req,res)=>{const p=resolve(root,'.'+(req.url==='/'?'/index.html':req.url.split('?')[0]));if(!p.startsWith(root+sep)){res.writeHead(403).end();return;}try{res.writeHead(200,{'Content-Type':{'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.ttf':'font/ttf'}[extname(p)]||'application/octet-stream'});res.end(await readFile(p));}catch{res.writeHead(404).end();}});
await new Promise(r=>http.listen(8060,'127.0.0.1',r));
let timings=[],gaps=[],snapshots=[],sizes=[],rtts=[],previous=0;
const step=server.room.step.bind(server.room),snapshot=server.room.snapshot.bind(server.room);
server.room.step=(dt,now)=>{const t=performance.now();step(dt,now);timings.push(performance.now()-t);if(previous)gaps.push(now-previous);previous=now;};
server.room.snapshot=(p,revision)=>{const t=performance.now(),s=snapshot(p,revision);snapshots.push(performance.now()-t);sizes.push(Buffer.byteLength(JSON.stringify(s)));return s;};
const stat=a=>{a=a.filter(Number.isFinite).sort((x,y)=>x-y);const q=p=>a[Math.min(a.length-1,Math.floor(a.length*p))]??0;return {n:a.length,p50:+q(.5).toFixed(3),p95:+q(.95).toFixed(3),p99:+q(.99).toFixed(3),max:+(a.at(-1)||0).toFixed(3)};};
const result={label,environment:'Windows; two independent headless Edge processes; SwiftShader; Firebase Auth emulator; local WS',physical:false,phases:[],errors};
let pingTimer;
async function phase(name,ms){
 timings=[];gaps=[];snapshots=[];sizes=[];rtts=[];
 const taskBefore=await Promise.all(sessions.map(async s=>(await s.send('Performance.getMetrics')).metrics.find(m=>m.name==='TaskDuration').value));
 await Promise.all(pages.map(p=>p.evaluate(()=>{window.benchFrames=[];window.benchSamples=[];window.benchActive=true;window.benchLast=0;})));
 const sampleTimer=setInterval(()=>{for(const p of pages)p.evaluate(()=>{const s=window.tcMpState;window.benchSamples.push([s.process_ms,s.draw_calls,s.primitives,s.fps]);}).catch(()=>{});},200);
 await pause(ms);clearInterval(sampleTimer);
 const clients=await Promise.all(pages.map(p=>p.evaluate(()=>{window.benchActive=false;return {frames:window.benchFrames,samples:window.benchSamples,online:window.tcMpState.online,position:window.tcMpState.snapshot.players.find(p=>p.id===window.tcMpState.self)};})));
 const taskAfter=await Promise.all(sessions.map(async s=>(await s.send('Performance.getMetrics')).metrics.find(m=>m.name==='TaskDuration').value));
 const data={name,duration_ms:ms,server_step_ms:stat(timings),server_tick_interval_ms:stat(gaps),snapshot_build_ms:stat(snapshots),snapshot_bytes:stat(sizes),local_socket_rtt_ms:stat(rtts),clients:clients.map((c,i)=>({format:i?'mobile-640x360':'PC-1920x950',online:c.online,position:[c.position.x,c.position.y],frame_ms:stat(c.frames),frames_over_50ms:c.frames.filter(x=>x>50).length,process_ms:stat(c.samples.map(s=>s[0])),draw_calls:stat(c.samples.map(s=>s[1])),primitives:stat(c.samples.map(s=>s[2]))}))};
 for(let i=0;i<data.clients.length;i++)data.clients[i].browser_main_thread_task_ms=+((taskAfter[i]-taskBefore[i])*1000).toFixed(2);
 result.phases.push(data);console.log(JSON.stringify(data));
}
try{
 for(const [i,uid] of ['mp-a','mp-b'].entries()){
  const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});browsers.push(browser);
  const page=await browser.newPage({viewport:i?{width:640,height:360}:{width:1920,height:950},hasTouch:!!i});pages.push(page);
  const cdp=await page.context().newCDPSession(page);await cdp.send('Performance.enable');sessions.push(cdp);
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error'&&/SCRIPT ERROR|Parse Error|Invalid call|Invalid access/.test(m.text()))errors.push(m.text());});
  await page.goto('http://localhost:8060/');await page.waitForFunction(()=>window.tcMpState?.ready,null,{timeout:60000});
  await page.evaluate(u=>window.tcMpFixture(JSON.stringify({action:'connect',...u})),users[uid]);await page.waitForFunction(()=>window.tcMpState.online);
  await page.evaluate(()=>{function frame(t){if(window.benchActive){if(window.benchLast)window.benchFrames.push(t-window.benchLast);window.benchLast=t;}requestAnimationFrame(frame);}requestAnimationFrame(frame);});
 }
 for(const p of server.room.players.values()){
  const ws=p.socket;let sent=0;ws.on('pong',()=>{if(sent){rtts.push(performance.now()-sent);sent=0;}});
  ws.benchPing=()=>{if(ws.readyState===1){sent=performance.now();ws.ping();}};
 }
 pingTimer=setInterval(()=>{for(const p of server.room.players.values())p.socket?.benchPing?.();},500);
 await pause(1500);await phase('idle',6000);
 for(const [i,p]of [...server.room.players.values()].entries()){p.x=1152+i*60;p.y=576;}
 await Promise.all(pages.map(p=>p.keyboard.down('d')));await phase('simultaneous-exploration',8000);await Promise.all(pages.map(p=>p.keyboard.up('d')));
 for(const [i,p]of [...server.room.players.values()].entries()){p.x=1368+i*64;p.y=576;}
 await pause(400);await Promise.all(pages.map(p=>p.keyboard.down('f')));await phase('simultaneous-harvest',5000);await Promise.all(pages.map(p=>p.keyboard.up('f')));
 if(process.env.MP_BIOME_SCAN==='1'){
  // Controlled camera sweep, not a human route: same 18 positions and duration
  // with original draw calls and chunked draw calls in this same compiled build.
  for(const reference of [true,false]){
   await Promise.all(pages.map(p=>p.evaluate(enabled=>window.tcMpFixture(JSON.stringify({action:'reference',enabled})),reference)));
   let index=0;const next=()=>{const r=WORLD_DATA.regions[index++%18].rect;for(const [i,p]of [...server.room.players.values()].entries()){p.x=r[0]+r[2]/2+64+i*40;p.y=r[1]+r[3]/2;}};
   next();const timer=setInterval(next,500);await phase(reference?'18-biomes-original-drawing':'18-biomes-chunked-drawing',9000);clearInterval(timer);
  }
 }
 await Promise.all(pages.map(p=>p.evaluate(()=>window.tcMpFixture(JSON.stringify({action:'render',visible:false})))));await pause(500);await phase('world-hidden-control',6000);
 if(errors.length)throw Error(errors.join('\n'));
}finally{
 clearInterval(pingTimer);for(const b of browsers)await b.close();await server.close();await verifier.close();await new Promise(r=>http.close(r));await mkdir('.tools/performance',{recursive:true});await writeFile(`.tools/performance/${label}.json`,JSON.stringify(result,null,2));
}

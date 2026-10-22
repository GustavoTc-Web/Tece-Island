import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {firebaseVerifier} from '../server/auth.mjs';
import {startServer} from '../server/service.mjs';
import {identities,pause} from '../server/tests/helpers.mjs';

const checks=[],browsers=[],errors=[],seen=[],directory=resolve('build/multiplayer-fixture');
const check=(ok,label)=>{assert.ok(ok,label);checks.push({pass:true,label});console.log('PASS: '+label);};
const users=await identities(),verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true});
const server=await startServer({verify:token=>verifier.verify(token),nickname:async(_,uid)=>uid==='mp-a'?'Ana':'Beto',allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:8789});
let route='route-a',unavailable=true,lookups=0;
const http=createServer(async(req,res)=>{
  if(new URL(req.url,'http://localhost').pathname==='/endpoint.json'){
    lookups++;res.writeHead(unavailable?503:200,{'Content-Type':'application/json','Cache-Control':'no-store'});
    res.end(JSON.stringify({schema:1,protocol:3,url:`wss://${route}.trycloudflare.com/room`}));return;
  }
  const path=resolve(directory,'.'+(new URL(req.url,'http://localhost').pathname==='/'?'/index.html':new URL(req.url,'http://localhost').pathname));
  if(!path.startsWith(directory+'/')&&!path.startsWith(directory+'\\')){res.writeHead(403);res.end();return;}
  try{const bytes=await readFile(path);res.writeHead(200,{'Content-Type':{'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.ttf':'font/ttf'}[extname(path)]||'application/octet-stream'});res.end(bytes);}catch{res.writeHead(404);res.end();}
});
await new Promise(r=>http.listen(8060,'127.0.0.1',r));
const state=p=>p.evaluate(()=>window.tcMpState),invoke=(p,data)=>p.evaluate(value=>window.tcMpFixture(JSON.stringify(value)),data);
try{
  const pages=[];
  for(const [uid,viewport,hasTouch] of [['mp-a',{width:1920,height:950},false],['mp-b',{width:640,height:360},true]]){
    const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});browsers.push(browser);
    const context=await browser.newContext({viewport,hasTouch}),page=await context.newPage();pages.push(page);
    page.on('pageerror',e=>errors.push(e.message));
    page.on('console',m=>{if(m.type()==='error'&&/SCRIPT ERROR|Parse Error|Invalid call|Invalid access/.test(m.text()))errors.push(m.text());});
    // Transport adapter exists only in this test harness: validate real Godot
    // discovery and real local WS; public TLS/WSS is probed independently.
    await page.exposeFunction('routeSeen',value=>seen.push(value));
    await page.addInitScript(()=>{
      const Original=window.WebSocket;
      window.WebSocket=class extends Original{
        constructor(url,protocols){
          if(/^wss:\/\/route-[ab]\.trycloudflare\.com\/room$/.test(url)){window.routeSeen(url);url='ws://127.0.0.1:8789/room';}
          super(url,protocols);
        }
      };
    });
    await page.goto('http://localhost:8060/');await page.waitForFunction(()=>window.tcMpState?.ready,null,{timeout:60000});
    await invoke(page,{action:'connect',...users[uid]});
    if(uid==='mp-a'){
      await page.waitForFunction(()=>window.tcMpState?.failed_phase==='discovery',null,{timeout:15000});
      check(!(await state(page)).online&&seen.length===0,'Unavailable discovery does not use stale compiled endpoint or open a socket');
      unavailable=false;
    }
    await page.waitForFunction(()=>window.tcMpState?.online,null,{timeout:30000});
    check((await state(page)).players.length>=1&&(await state(page)).status.includes('piloto .6'),uid+': initial authoritative room, .6 label and rendered character received after discovery');
  }
  const [pc,mobile]=pages;
  await pc.waitForFunction(()=>window.tcMpState.players.length===2);
  await mobile.waitForFunction(()=>window.tcMpState.players.length===2);
  const beforeA=await state(pc),beforeB=await state(mobile),room=beforeA.room;
  check(room===beforeB.room,'Independent PC and mobile-emulated clients join the same room');
  const own=s=>s.snapshot.players.find(p=>p.id===s.self);
  await pc.keyboard.down('a');await mobile.keyboard.down('d');await pause(350);
  await pc.keyboard.up('a');await mobile.keyboard.up('d');await pause(400);
  check(own(await state(pc)).x<own(beforeA).x-20&&own(await state(mobile)).x>own(beforeB).x+20,'Both clients move and receive updated server state');
  route='route-b';
  for(const page of pages)await invoke(page,{action:'retry'});
  for(const page of pages)await page.waitForFunction(()=>window.tcMpState.online&&window.tcMpState.players.length===2,null,{timeout:30000});
  check(seen.filter(x=>x.includes('route-b')).length===2,'Both clients discover rotated endpoint without reloading or recompiling');
  check((await state(pc)).room===room&&(await state(mobile)).room===room&&server.room.players.size===2,'Endpoint rotation preserves the running room and two characters');
  check(JSON.stringify((await state(pc)).inventory)===JSON.stringify(beforeA.inventory),'Room inventory preserved across route refresh');
  await mkdir('.tools/screenshots',{recursive:true});
  await pc.screenshot({path:'.tools/screenshots/multiplayer-6-pc.png'});await mobile.screenshot({path:'.tools/screenshots/multiplayer-6-mobile.png'});
  check(errors.length===0,'No GDScript or browser errors');
} finally {
  for(const browser of browsers)await browser.close();await server.close();await new Promise(r=>http.close(r));
  await writeFile('.tools/multiplayer-discovery-results.json',JSON.stringify({checks,errors,lookups,physical:false,publicTLS:false,transportAdapter:'test-only WSS hostname to real local WS; public TLS tested separately'},null,2));
}

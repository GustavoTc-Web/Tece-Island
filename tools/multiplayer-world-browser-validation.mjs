import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {firebaseVerifier} from '../server/auth.mjs';
import {startServer} from '../server/service.mjs';
import {identities,pause} from '../server/tests/helpers.mjs';
import {WORLD_DATA,WorldGeometry} from '../server/world.mjs';
import {reachable,route as pathTo} from '../server/tests/paths.mjs';

// Leave extra clearance for the input robot's stop latency. The game server
// still uses the actual ten-unit player collider exported from the solo scene.
const checks=[],errors=[],clients=[],geometry=new WorldGeometry({...WORLD_DATA,player_radius:24});
const check=(ok,label)=>{checks.push({pass:!!ok,label});console.log(`${ok?'PASS':'FAIL'}: ${label}`);if(!ok)throw Error(label);};
const users=await identities(),verifier=firebaseVerifier({projectId:'demo-tece-island',apiKey:'local-test',localTest:true});
// Artificial latency makes the distinct handshake phases observable by the
// test-only bridge. Production verification is unchanged.
const server=await startServer({verify:async token=>{await pause(250);return verifier.verify(token);},nickname:async(_,uid)=>{await pause(250);return uid==='mp-a'?'Ana':'Beto';},allowedUids:['mp-a','mp-b'],origins:['http://localhost:8060'],port:8789});
const directory=resolve('build/multiplayer-fixture');
const http=createServer(async(req,res)=>{
 const path=resolve(directory,'.'+(new URL(req.url,'http://localhost').pathname==='/'?'/index.html':new URL(req.url,'http://localhost').pathname));
 if(!path.startsWith(directory+'\\')&&!path.startsWith(directory+'/')){res.writeHead(403);res.end();return;}
 try{const bytes=await readFile(path);res.writeHead(200,{'Content-Type':{'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.svg':'image/svg+xml','.json':'application/json','.ttf':'font/ttf'}[extname(path)]||'application/octet-stream','Cache-Control':'no-store'});res.end(bytes);}catch{res.writeHead(404);res.end();}
});
await new Promise(r=>http.listen(8060,'127.0.0.1',r));await mkdir('.tools/screenshots',{recursive:true});
const state=p=>p.evaluate(()=>window.tcMpState),invoke=(p,data)=>p.evaluate(value=>window.tcMpFixture(JSON.stringify(value)),data);
const own=s=>s.snapshot.players.find(p=>p.id===s.self);
async function launch(viewport,hasTouch){
 const browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});clients.push(browser);
 const context=await browser.newContext({viewport,hasTouch,deviceScaleFactor:hasTouch?2:1}),page=await context.newPage();
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&/SCRIPT ERROR|Parse Error|Invalid call|Invalid access/.test(m.text()))errors.push(m.text());});
 await page.goto('http://localhost:8060/');await page.waitForFunction(()=>window.tcMpState?.ready,null,{timeout:60000});
 const cdp=hasTouch?await context.newCDPSession(page):null;return {page,context,cdp};
}
function cssPoint(s,page,x,y,id=1){const v=page.viewportSize();return {id,x:x*v.width/s.viewport[0],y:y*v.height/s.viewport[1]};}
async function click(page,caption,touch=false){await page.waitForFunction(c=>window.tcMpState.buttons[c]!==undefined,caption,{timeout:5000});const s=await state(page),b=s.buttons[caption];const p=cssPoint(s,page,b[0]+b[2]/2,b[1]+b[3]/2);if(touch)await page.touchscreen.tap(p.x,p.y);else await page.mouse.click(p.x,p.y);}
async function drive(client,to,direct=false){
 const {page,cdp}=client,s=await state(page),p=own(s),path=direct?[[p.x,p.y],to]:pathTo(reachable(geometry,[p.x,p.y]),to);
 console.log('DRIVE',JSON.stringify({from:[p.x,p.y],to,path,fps:s.fps}));
 for(const goal of path.slice(1)){
  const deadline=Date.now()+Math.max(15000,Math.hypot(goal[0]-p.x,goal[1]-p.y)/WORLD_DATA.speed*4000);
  for(let n=0;n<180;n++){
   const s=await state(page),p=own(s),dx=goal[0]-p.x,dy=goal[1]-p.y;
   if(Math.hypot(dx,dy)<11)break;
   if(n===179||Date.now()>deadline)throw Error('UI movement stuck toward '+goal+' at '+[p.x,p.y]+' FPS '+s.fps);
   const horizontal=Math.abs(dx)>Math.abs(dy),key=horizontal?(dx>0?'d':'a'):(dy>0?'s':'w');
   const duration=Math.max(20,Math.min(140,(horizontal?Math.abs(dx):Math.abs(dy))/WORLD_DATA.speed*650));
   if(cdp){
    const [cx,cy,radius]=s.stick;
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[cssPoint(s,page,cx,cy)]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[cssPoint(s,page,cx+(horizontal?Math.sign(dx)*radius*.8:0),cy+(horizontal?0:Math.sign(dy)*radius*.8))]});
    await pause(duration);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   }else{await page.keyboard.down(key);await pause(duration);await page.keyboard.up(key);}
   await pause(180);
  }
  await pause(120);
 }
}
try{
 const pc=await launch({width:1920,height:950},false),a=pc.page;
 await invoke(a,{action:'connect',entry:true,...users['mp-a']});
 await a.waitForFunction(()=>window.tcMpState.phase==='authentication');
 check(!(await state(a)).online,'Open WSS remains blocked while authentication is pending');
 await a.waitForFunction(()=>window.tcMpState.phase==='initial_state');
 check(!(await state(a)).online,'Verified account remains blocked until the initial room state');
 await a.waitForFunction(()=>window.tcMpState.online,null,{timeout:30000});
 check((await state(a)).regions===18&&(await state(a)).total_resources===274&&(await state(a)).wells===18,'Actual menu entry loads full solo-derived world, resources and wells');
 check((await state(a)).slots.slots.length===7&&Object.hasOwn((await state(a)).buttons,'Slot 5'),'Existing HUD has seven inventory slots and five quick slots');
 const initialHUD=await state(a);check(initialHUD.panel[3]*950/initialHUD.viewport[1]<180,'PC HUD remains compact after reusing solo components');
 const mobile=await launch({width:640,height:360},true),b=mobile.page;
 await invoke(b,{action:'connect',...users['mp-b']});await b.waitForFunction(()=>window.tcMpState.online&&window.tcMpState.players.length===2);
 await a.waitForFunction(()=>window.tcMpState.players.length===2);
 check((await state(a)).players.some(p=>p.nickname.includes('Beto'))&&(await state(b)).players.some(p=>p.nickname.includes('Ana')),'Two authenticated clients render each other with nicknames');
 server.room.players.get('mp-a').health=83;server.room.players.get('mp-a').hunger=72;
 await a.waitForFunction(()=>window.tcMpState.needs.health===83&&window.tcMpState.needs.hunger===72);
 check((await state(b)).needs.health===100&&(await state(b)).needs.hunger===100,'Health and hunger HUD show individual server values');
 check((await state(a)).needs.visible&&(await state(b)).needs.visible,'Health, hunger and water bars are visible in PC and mobile HUD');
 const controls=(await state(b)).buttons;
 for(const caption of ['Extrair','Interagir','Inventário']){
  const box=controls[caption];if(!box)continue;
  check(Object.entries(controls).filter(([k])=>k.startsWith('Slot ')).every(([,r])=>!(box[0]<r[0]+r[2]&&box[0]+box[2]>r[0]&&box[1]<r[1]+r[3]&&box[1]+box[3]>r[1])),'Mobile '+caption+' does not overlap quick slots');
 }
 server.room.players.get('mp-a').health=100;server.room.players.get('mp-a').hunger=100;
 const startA=own(await state(a)),startB=own(await state(b)),bs=await state(b),[cx,cy,r]=bs.stick;
 await a.keyboard.down('a');await mobile.cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[cssPoint(bs,b,cx,cy)]});
 await mobile.cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[cssPoint(bs,b,cx+r*.8,cy)]});await pause(300);
 await a.keyboard.up('a');await mobile.cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await pause(180);
 check(own(await state(a)).x<startA.x-20&&own(await state(b)).x>startB.x+20,'Simultaneous PC keyboard and mobile joystick move only their own players');
 const tree=WORLD_DATA.resources.find(r=>r.id==='madeira:1400:530');
 for(const client of [pc,mobile]){await drive(client,[1152,768],true);await drive(client,[1152,576],true);}
 await drive(pc,[tree.x-32,tree.y+46],true);await drive(mobile,[tree.x+32,tree.y+46],true);
 check((await state(a)).target===tree.id&&(await state(b)).target===tree.id,'Both players reach same canonical solo tree through actual controls');
 for(const [label,page]of [['PC',a],['Mobile',b]]){const boxes=(await state(page)).players.map(p=>p.name_box),[x,y,w,h]=boxes[0],[xx,yy,ww,hh]=boxes[1];check(!(x<xx+ww&&x+w>xx&&y<yy+hh&&y+h>yy),label+' nearby player nicknames do not overlap');}
 await a.keyboard.press('f');await a.waitForFunction(id=>window.tcMpState.snapshot.resources.some(r=>r.id===id&&r.progress>0),tree.id);
 await b.waitForFunction(()=>window.tcMpState.swings.some(n=>n>0));
 check(true,'Accepted harvest progress and cut animation reach the other player');
 const s=await state(b),[sx,sy,sr]=s.stick,button=s.buttons.Extrair;
 const finger=cssPoint(s,b,sx-sr*.25,sy),second=cssPoint(s,b,button[0]+button[2]/2,button[1]+button[3]/2,2);
 await mobile.cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[finger]});
 await mobile.cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[finger,second]});
 await pause(100);await mobile.cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[second]});
 await b.waitForFunction(id=>window.tcMpState.snapshot.resources.some(r=>r.id===id&&r.progress>.6),tree.id);
 check((await state(b)).move[0]<-.15,'Mobile second finger harvests while joystick finger remains held');
 await mobile.cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await pause(650);
 await Promise.all([a.keyboard.press('f'),click(b,'Extrair',true)]);
 await a.waitForFunction(id=>window.tcMpState.snapshot.resources.some(r=>r.id===id&&r.depleted),tree.id);
 await b.waitForFunction(id=>window.tcMpState.snapshot.resources.some(r=>r.id===id&&r.depleted),tree.id);
 check((await state(a)).inventory.madeira+(await state(b)).inventory.madeira===0,'Harvest never credits inventory automatically');
 await a.waitForFunction(()=>window.tcMpState.snapshot.drops.length===1);
 const drop=(await state(a)).snapshot.drops[0];check(drop.quantity===5,'One visible shared ground stack contains exactly five wood');
 check((await state(a)).drop_count===1&&(await state(b)).drop_count===1,'Both clients instantiate existing solo ground-item visuals');
 await b.screenshot({path:'.tools/screenshots/multiplayer-5-mobile-ground.png'});
 const oldSelf=(await state(b)).self;await invoke(b,{action:'offline'});await pause(200);await invoke(b,{action:'retry'});await b.waitForFunction(()=>window.tcMpState.online&&window.tcMpState.drop_count===1);
 check((await state(b)).self===oldSelf,'Reconnect before pickup preserves the character and remaining ground stack');
 await drive(pc,[drop.x-12,drop.y+6],true);await drive(mobile,[drop.x+12,drop.y+6],true);await pause(300);
 await Promise.all([a.keyboard.press('e'),click(b,'Pegar',true)]);
 await a.waitForFunction(()=>window.tcMpState.snapshot.drops.length===0);await b.waitForFunction(()=>window.tcMpState.snapshot.drops.length===0);
 check((await state(a)).inventory.madeira+(await state(b)).inventory.madeira===5,'Concurrent E/mobile pickup awards exactly five wood once');
 await drive(pc,[1270,768]);await drive(mobile,[1280,800]);
 check((await state(a)).well_target==='well:forest'&&(await state(b)).well_target==='well:forest','Both players reach the same original forest well');
 await a.keyboard.press('e');await click(b,'Interagir',true);
 await a.waitForFunction(()=>window.tcMpState.active_panel==='well');await b.waitForFunction(()=>window.tcMpState.active_panel==='well');
 check(!(await state(b)).overlay_visible,'Existing well panel opens and hides mobile gameplay controls');
 await b.screenshot({path:'.tools/screenshots/multiplayer-5-mobile-well-panel.png'});
 await Promise.all([click(a,'Encher cantil'),click(b,'Encher cantil',true)]);
 await a.waitForFunction(()=>window.tcMpState.slots.slots[2].water===3);await b.waitForFunction(()=>window.tcMpState.slots.slots[2].water===3);
 check(true,'Server fills a separate three-dose canteen for each player at shared well');
 await pause(550);await click(a,'Beber');await a.waitForFunction(()=>window.tcMpState.thirst>99.8);
 check(true,'Well drink restores water through authoritative server state');
 await click(a,'Fechar');await click(b,'Fechar',true);await click(a,'Slot 3');
 await a.waitForFunction(()=>window.tcMpState.selected===2);await a.keyboard.press('f');
 await a.waitForFunction(()=>window.tcMpState.slots.slots[2].water===2);
 check((await state(b)).slots.slots[2].water===3,'Using canteen affects only its owner inventory');
 await click(b,'Inventário',true);await b.waitForFunction(()=>window.tcMpState.active_panel==='inventory');
 check((await state(b)).buttons['Inventory slot 7']!==undefined,'Actual reused inventory panel renders all seven server slots on mobile');
 await b.screenshot({path:'.tools/screenshots/multiplayer-5-mobile-inventory.png'});
 await click(b,'Inventory slot 2',true);await click(b,'Mover / trocar',true);await click(b,'Inventory slot 5',true);
 await b.waitForFunction(()=>window.tcMpState.slots.slots[4].item==='picareta_madeira');
 check(true,'Inventory slot swap is validated and returned by server');
 await click(b,'Fechar',true);await click(b,'Slot 5',true);await b.waitForFunction(()=>window.tcMpState.snapshot.tool==='picareta_madeira');
 check(true,'Existing quickbar equips server-owned tool after slot movement');
 for(const [name,box]of Object.entries((await state(b)).buttons))if(name.startsWith('Slot ')||['Extrair','Interagir','Inventário','Menu'].includes(name))check(box[2]*640/(await state(b)).viewport[0]>=44&&box[3]*360/(await state(b)).viewport[1]>=44,'Mobile touch target >=44 CSS px: '+name);
 const previous=await state(b);await invoke(b,{action:'offline'});await a.waitForFunction(()=>window.tcMpState.snapshot.players.some(p=>!p.online));
 check(!(await state(b)).overlay_visible,'Disconnected client suspends joystick and inventory gameplay');
 await invoke(b,{action:'retry'});await b.waitForFunction(()=>window.tcMpState.online);
 check((await state(b)).self===previous.self&&JSON.stringify((await state(b)).slots)===JSON.stringify(previous.slots)&&(await state(b)).players.length===2,'Reconnect preserves character, inventory slots and canteen water');
 check((await state(b)).snapshot.resources.some(r=>r.id===tree.id&&r.depleted),'Reconnect retains depleted resources across full world');
 await a.keyboard.press('F3');await a.waitForFunction(()=>window.tcMpState.metrics_visible);
 check((await state(a)).net.rtt>0&&(await state(a)).net.fps>0,'PC diagnostic displays measured frame rate and authenticated input-ACK RTT');
 await a.screenshot({path:'.tools/screenshots/multiplayer-7-pc-diagnostic.png'});await a.keyboard.press('F3');
 const metricsBox=(await state(b)).metrics_button,metricsPoint=cssPoint(await state(b),b,metricsBox[0]+metricsBox[2]/2,metricsBox[1]+metricsBox[3]/2);
 await b.touchscreen.tap(metricsPoint.x,metricsPoint.y);await b.waitForFunction(()=>window.tcMpState.metrics_visible);
 await b.waitForFunction(()=>{const s=window.tcMpState,m=s.metrics_panel,v=s.viewport;return m[0]>=0&&m[1]>=0&&m[0]+m[2]<=v[0]+1&&m[1]+m[3]<=v[1]+1;},null,{timeout:3000});
 const m=(await state(b)).metrics_panel,v=(await state(b)).viewport;
 check(m[0]>=0&&m[1]>=0&&m[0]+m[2]<=v[0]+1&&m[1]+m[3]<=v[1]+1,'Mobile diagnostic panel fits and opens by touch');
 const density=await b.evaluate(()=>({dpr:devicePixelRatio,width:document.querySelector('#canvas').width,css:document.querySelector('#canvas').getBoundingClientRect().width}));
 check(density.dpr===2&&Math.abs(density.width-density.css)<2,'High-DPI mobile uses measured economical pixel density in multiplayer');
 await click(b,'Gráficos: econômicos (1×)',true);await pause(350);
 check(Math.abs(await b.evaluate(()=>document.querySelector('#canvas').width)-density.css*2)<2,'Diagnostic can compare native density without changing the world');
 check(JSON.stringify((await state(b)).viewport)===JSON.stringify(v),'Changing render density preserves logical camera area');
 await click(b,'Gráficos: nativos (até 2×)',true);await pause(350);
 await b.screenshot({path:'.tools/screenshots/multiplayer-7-mobile-diagnostic.png'});await click(b,'Fechar diagnóstico',true);
 await a.keyboard.press('F3');await a.waitForFunction(()=>window.tcMpState.metrics_visible);
 await click(a,'Previsão local: ligada');await a.waitForFunction(()=>!window.tcMpState.prediction.enabled);
 await click(a,'Previsão local: desligada');await a.waitForFunction(()=>window.tcMpState.prediction.enabled);await a.keyboard.press('F3');
 check((await state(a)).prediction.enabled,'Prediction can be toggled for A/B retest without replacing the room');
 const coalescedBefore=[(await state(a)).net.coalesced,(await state(b)).net.coalesced];
 await Promise.all([a,b].map(p=>p.evaluate(()=>{const until=performance.now()+350;while(performance.now()<until){}})));await pause(450);
 check((await state(a)).net.coalesced>coalescedBefore[0]||(await state(b)).net.coalesced>coalescedBefore[1],'Frame stalls coalesce queued states instead of rebuilding HUD for each old update');
 check((await state(a)).inventory.madeira+(await state(b)).inventory.madeira===5&&(await state(b)).snapshot.drops.length===0,'Backlog recovery preserves exact inventory totals and authoritative empty drops');
 await invoke(b,{action:'chat',opened:true});const before=own(await state(b));await b.keyboard.down('d');await pause(300);await b.keyboard.up('d');
 check(Math.hypot(own(await state(b)).x-before.x,own(await state(b)).y-before.y)<.01,'Chat blocks gameplay inputs without pausing the other player');await invoke(b,{action:'chat',opened:false});
 const old=server.room.players.get('mp-b').socket,send=old.send;old.send=function(data,...args){if(JSON.parse(data).type==='state')return;return send.call(this,data,...args);};
 await b.waitForFunction(()=>!window.tcMpState.online&&window.tcMpState.status.includes('Sem resposta'),null,{timeout:10000});
 check(!(await state(b)).overlay_visible,'Five seconds without snapshots pauses controls');old.send=send;
 await b.waitForFunction(()=>window.tcMpState.online,null,{timeout:10000});check((await state(b)).self===previous.self,'Automatic recovery preserves the same player');
 await a.screenshot({path:'.tools/screenshots/multiplayer-5-pc-forest.png'});await b.screenshot({path:'.tools/screenshots/multiplayer-5-mobile-well.png'});
 await drive(pc,[2420,768]);check(geometry.region(own(await state(a)).x,own(await state(a)).y).id==='swamp','Real keyboard traverses original forest-to-swamp connection across former arena limits');
 await a.screenshot({path:'.tools/screenshots/multiplayer-5-pc-swamp.png'});
 for(const [client,label]of [[pc,'pc'],[mobile,'mobile']]){
  await invoke(client.page,{action:'endpoint',value:'ws://127.0.0.1:8799/room'});
  await client.page.waitForFunction(()=>!window.tcMpState.online&&window.tcMpState.failed_phase==='connection');
  // Reveal the actual chat launcher for layout QA without a production chat
  // session or any Firestore calls in the emulated fixture.
  const rect=await client.page.evaluate(()=>{document.querySelector('#tc-chat').hidden=false;document.querySelector('#chat-launch').hidden=false;const r=document.querySelector('#chat-launch').getBoundingClientRect();return [r.x,r.y,r.width,r.height];});
  const s=await state(client.page),v=client.page.viewportSize(),r=s.panel.map((n,i)=>n*(i%2===0?v.width/s.viewport[0]:v.height/s.viewport[1]));
  check(!(rect[0]<r[0]+r[2]&&rect[0]+rect[2]>r[0]&&rect[1]<r[1]+r[3]&&rect[1]+rect[3]>r[1]),label+': Chat launcher never overlaps offline connection card');
  check(r[1]>=54&&r[1]+r[3]<=v.height,label+': offline diagnostic card fits viewport below Chat');
  check(s.diagnostic.includes('protocolo 3')&&s.diagnostic.includes('127.0.0.1:8799')&&!s.diagnostic.includes(users['mp-a'].token),label+': useful endpoint, phase and protocol diagnosis excludes credentials');
  await client.page.screenshot({path:'.tools/screenshots/multiplayer-5-'+label+'-connection.png'});
 }
 await Promise.all([invoke(a,{action:'endpoint',value:'ws://127.0.0.1:8789/room'}),invoke(b,{action:'endpoint',value:'ws://127.0.0.1:8789/room'})]);
 await a.waitForFunction(()=>window.tcMpState.online&&window.tcMpState.players.length===2);await b.waitForFunction(()=>window.tcMpState.online&&window.tcMpState.players.length===2);
 check((await state(a)).phase==='playing'&&(await state(b)).phase==='playing','Both independent clients recover from unavailable transport through auth and initial state into the same room');
 const recoveredA=own(await state(a)),recoveredB=own(await state(b));
 await Promise.all([a.keyboard.down('a'),b.keyboard.down('a')]);await pause(300);await Promise.all([a.keyboard.up('a'),b.keyboard.up('a')]);await pause(180);
 check((await state(a)).room===(await state(b)).room&&own(await state(a)).x<recoveredA.x-15&&own(await state(b)).x<recoveredB.x-15,'Recovered characters move simultaneously in the same authoritative room');
 await click(a,'Menu');await click(a,'Voltar ao menu principal');await a.waitForFunction(()=>window.tcMpState.menu);
 check(true,'Return to solo world library uses existing session flow');check(errors.length===0,'No Godot/JavaScript errors in either actual Web client');
}catch(e){for(const [i,browser]of clients.entries())for(const c of browser.contexts())for(const p of c.pages()){await p.screenshot({path:`.tools/screenshots/multiplayer-5-failure-${i}.png`}).catch(()=>{});await writeFile(`.tools/mp5-failure-${i}.json`,JSON.stringify(await state(p),null,2));}throw e;
}finally{for(const b of clients)await b.close();await server.close();await verifier.close();await new Promise(r=>http.close(r));await writeFile('.tools/multiplayer-world-browser-results.json',JSON.stringify({checks,errors,physical:false},null,2));}

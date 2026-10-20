import {createServer} from 'node:http';
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {resolve, extname} from 'node:path';
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {firebaseVerifier} from '../server/auth.mjs';
import {startServer} from '../server/service.mjs';
import {identities, pause} from '../server/tests/helpers.mjs';

const checks = [], errors = [], clients = [];
const check = (condition, label) => {checks.push({label, pass: !!condition}); console.log(`${condition ? 'PASS' : 'FAIL'}: ${label}`); if (!condition) throw Error(label);};
const users = await identities();
const verifier = firebaseVerifier({projectId: 'demo-tece-island', apiKey: 'local-test', localTest: true});
const server = await startServer({verify: token => verifier.verify(token), nickname: async (_, uid) => uid === 'mp-a' ? 'Ana' : 'Beto', allowedUids: ['mp-a', 'mp-b'], origins: ['http://localhost:8060'], port: 8789});
const directory = resolve('build/multiplayer-fixture');
const http = createServer(async (req, res) => {
  const path = resolve(directory, '.' + (new URL(req.url, 'http://localhost').pathname === '/' ? '/index.html' : new URL(req.url, 'http://localhost').pathname));
  if (!path.startsWith(directory + '\\') && !path.startsWith(directory + '/')) {res.writeHead(403);res.end();return;}
  try {
    const bytes = await readFile(path);
    const mime = {'.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm', '.svg':'image/svg+xml', '.json':'application/json', '.ttf':'font/ttf'}[extname(path)] || 'application/octet-stream';
    res.writeHead(200, {'Content-Type': mime, 'Cache-Control': 'no-store'}); res.end(bytes);
  } catch {res.writeHead(404);res.end();}
});
await new Promise(resolve => http.listen(8060, '127.0.0.1', resolve));
await mkdir('.tools/screenshots', {recursive: true});
const state = page => page.evaluate(() => window.tcMpState);
const invoke = (page, data) => page.evaluate(value => window.tcMpFixture(JSON.stringify(value)), data);
async function launch(viewport, hasTouch) {
  const browser = await chromium.launch({executablePath: process.env.BROWSER_EXE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless: true, args:['--enable-unsafe-swiftshader']});
  clients.push(browser);
  const context = await browser.newContext({viewport, hasTouch});
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', message => {if (message.type() === 'error' && /SCRIPT ERROR|Parse Error|Invalid call|Invalid access/.test(message.text())) errors.push(message.text());});
  await page.goto('http://localhost:8060/');
  await page.waitForFunction(() => window.tcMpState?.ready, null, {timeout: 60000});
  return {page, context};
}
async function click(page, caption, touch = false) {
  const s = await state(page), b = s.buttons[caption];
  if (!b) throw Error(`Missing UI button ${caption}`);
  const size = page.viewportSize(), x = (b[0] + b[2]/2) * size.width / s.viewport[0], y = (b[1] + b[3]/2) * size.height / s.viewport[1];
  if (touch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
}
try {
  const {page: a} = await launch({width: 1920, height: 950}, false);
  await invoke(a, {action: 'connect', entry:true, ...users['mp-a']});
  await a.waitForFunction(() => window.tcMpState.online);
  check((await state(a)).players.length === 1, 'Actual Multiplayer — teste menu entry opens first Godot Web client');
  await a.keyboard.down('a'); await a.waitForFunction(() => window.tcMpState.snapshot.players[0].x < 562); await a.keyboard.up('a');
  await a.keyboard.down('w'); await a.waitForFunction(() => window.tcMpState.snapshot.players[0].y < 414); await a.keyboard.up('w');
  await pause(180);
  check((await state(a)).prompt.includes('árvore'), 'PC keyboard moves to actual tree and shows harvest interaction');
  await a.keyboard.press('f');
  await a.waitForFunction(() => window.tcMpState.snapshot.resources[0].progress > 0);
  const {page: b, context: mobile} = await launch({width: 640, height: 360}, true);
  await invoke(b, {action: 'connect', ...users['mp-b']});
  await b.waitForFunction(() => window.tcMpState.online && window.tcMpState.players.length === 2);
  check(Math.abs((await state(b)).snapshot.resources[0].progress - 1/3) < 0.00001, 'Late mobile client receives tree progress and current PC position');
  await a.waitForFunction(() => window.tcMpState.players.length === 2);
  check((await state(b)).players.some(p => p.nickname.includes('Ana')) && (await state(a)).players.some(p => p.nickname.includes('Beto')), 'Both actual clients render the other account nickname');
  const pc = await state(a);
  check(pc.panel[2]*1920/pc.viewport[0] <= 621 && pc.panel[3]*950/pc.viewport[1] < 150, 'PC 1920 HUD stays compact in CSS pixels rather than scaling with the canvas');
  for (const [name,page] of [['PC',a],['Mobile',b]]) {
    const s=await state(page);
    check(s.players.every(p=>p.screen[0]>0&&p.screen[0]<s.viewport[0]&&p.screen[1]>s.panel[1]+s.panel[3]&&p.screen[1]<s.viewport[1]), name+': camera shows both nearby actors below HUD');
  }
  const bs = await state(b), [cx, cy, radius] = bs.stick, vw = bs.viewport[0], vh = bs.viewport[1];
  const cdp = await mobile.newCDPSession(b);
  const point = (x,y) => ({id: 1, x: x*640/vw, y: y*360/vh});
  const initialA=await state(a), initialB=await state(b);
  const startA=initialA.snapshot.players.find(p=>p.id===initialA.self), startB=initialB.snapshot.players.find(p=>p.id===initialB.self);
  await a.keyboard.down('d');
  await cdp.send('Input.dispatchTouchEvent', {type:'touchStart',touchPoints:[point(cx,cy)]});
  await cdp.send('Input.dispatchTouchEvent', {type:'touchMove',touchPoints:[point(cx-radius*0.8, cy-radius*0.7)]});
  await pause(220);
  await a.keyboard.up('d');
  const movedA=await state(a), movedB=await state(b);
  check(movedA.snapshot.players.find(p=>p.id===movedA.self).x>startA.x+10 && Math.hypot(movedB.snapshot.players.find(p=>p.id===movedB.self).x-startB.x,movedB.snapshot.players.find(p=>p.id===movedB.self).y-startB.y)>10,'PC keyboard and mobile joystick move both independent players simultaneously');
  await a.keyboard.down('a');await pause(220);await a.keyboard.up('a');
  await b.waitForFunction(() => {
    const s = window.tcMpState, p = s.snapshot.players.find(p=>p.id===s.self);
    return Math.hypot(p.x-560,p.y-350)<77;
  });
  await cdp.send('Input.dispatchTouchEvent', {type:'touchEnd',touchPoints:[]});
  await b.waitForFunction(() => window.tcMpState.move.every(v=>v===0));
  check((await state(b)).prompt.includes('árvore'), 'Mobile joystick moves only own actor and releasing touch stops input');
  const as = await state(a), beforeA = as.snapshot.players.find(p => p.id === as.self);
  check(beforeA.x < 570 && beforeA.y < 420, 'Mobile movement leaves PC actor at PC position');
  const finger=point(cx-radius*0.25,cy), buttonBox=(await state(b)).buttons.Coletar;
  const second={id:2,x:(buttonBox[0]+buttonBox[2]/2)*640/vw,y:(buttonBox[1]+buttonBox[3]/2)*360/vh};
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[finger]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[finger,second]});
  await pause(100);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[second]});
  await b.waitForFunction(()=>window.tcMpState.snapshot.resources[0].progress>0.6);
  check((await state(b)).move[0]<-0.15,'Second finger harvests while first finger still holds the moving joystick');
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await pause(600);
  await Promise.all([a.keyboard.press('f'), click(b, 'Coletar', true)]);
  await a.waitForFunction(() => window.tcMpState.snapshot.resources[0].depleted);
  await b.waitForFunction(() => window.tcMpState.snapshot.resources[0].depleted);
  check((await state(a)).inventory.madeira + (await state(b)).inventory.madeira === 5, 'Simultaneous PC key/mobile touch deplete shared tree and grant one reward');
  const previous = await state(b);
  await invoke(b, {action:'offline'}); await a.waitForFunction(() => window.tcMpState.snapshot.players.some(p=>!p.online));
  check(!(await state(b)).online && (await state(b)).status.includes('indisponível'), 'Disconnected mobile shows explicit server state');
  await invoke(b, {action:'retry'}); await b.waitForFunction(() => window.tcMpState.online);
  const resumed = await state(b);
  check(resumed.self === previous.self && resumed.room === previous.room && JSON.stringify(resumed.inventory) === JSON.stringify(previous.inventory) && resumed.players.length === 2, 'Reconnect restores same character, room and inventory');
  check(resumed.snapshot.resources[0].depleted, 'Reconnect retains exhausted tree without duplicate reward');
  await b.screenshot({path:'.tools/screenshots/multiplayer-mobile-640.png'});
  await a.screenshot({path:'.tools/screenshots/multiplayer-pc-1920.png'});
  check(resumed.panel[2] <= resumed.viewport[0] && resumed.panel[3] < resumed.viewport[1]*0.65, 'Compact HUD fits landscape mobile viewport');
  for (const [name, box] of Object.entries(resumed.buttons)) check(box[2]*640/resumed.viewport[0]>=44 && box[3]*360/resumed.viewport[1]>=44, `Mobile ${name} touch target >=44 CSS pixels`);
  await click(b, 'Picareta', true); await b.waitForFunction(() => window.tcMpState.snapshot.tool === 'picareta_madeira');
  check((await state(b)).inventory.picareta_madeira === 1, 'Mobile equipment button requests server-owned tool');
  await invoke(b, {action:'chat', opened:true});
  const saved = await state(b); await b.keyboard.down('d'); await pause(400); await b.keyboard.up('d');
  const blocked = await state(b), ps = saved.snapshot.players.find(p=>p.id===saved.self), pb = blocked.snapshot.players.find(p=>p.id===blocked.self);
  check(ps.x === pb.x && ps.y === pb.y, 'Opening existing chat prevents gameplay controls');
  await invoke(b, {action:'chat', opened:false});
  const oldSocket=server.room.players.get('mp-b').socket, originalSend=oldSocket.send;
  oldSocket.send=function(data,...args){if(JSON.parse(data).type==='state')return;return originalSend.call(this,data,...args);};
  await b.waitForFunction(()=>!window.tcMpState.online&&window.tcMpState.status.includes('Sem resposta'),null,{timeout:10000});
  check(!Object.hasOwn((await state(b)).buttons,'Coletar'),'A stalled open socket pauses controls and hides joystick/collect after five seconds without state');
  oldSocket.send=originalSend;
  await b.waitForFunction(()=>window.tcMpState.online,null,{timeout:10000});
  check((await state(b)).self===resumed.self&&JSON.stringify((await state(b)).inventory)===JSON.stringify(resumed.inventory),'Automatic reconnect after a silent connection preserves identity and inventory');
  await invoke(b, {action:'full'}); await pause(150);
  check((await state(b)).status.includes('Sala cheia') && (await state(b)).fatal, 'Room-full presentation is explicit (injected UI status)');
  await click(a, 'Menu');
  await a.waitForFunction(() => window.tcMpState.menu);
  check((await state(a)).menu, 'Multiplayer Menu returns through existing session to solo world library');
  const {page: unavailable}=await launch({width:800,height:360},true);
  await invoke(unavailable,{action:'connect',...users['mp-a'],endpoint:'ws://127.0.0.1:8798/room'});
  await unavailable.waitForFunction(()=>window.tcMpState.status?.includes('indisponível'));
  const offline=await state(unavailable);
  check(!offline.online&&!Object.hasOwn(offline.buttons,'Coletar')&&!Object.hasOwn(offline.buttons,'Machado')&&offline.status.includes('tentativa'),'Initial outage shows timed retry with gameplay controls hidden');
  await unavailable.screenshot({path:'.tools/screenshots/multiplayer-mobile-unavailable-800.png'});
  check(errors.length === 0, 'No Godot script errors in either Web client');
} catch (error) {
  for (const [index, browser] of clients.entries()) for (const context of browser.contexts()) for (const page of context.pages()) {
    await page.screenshot({path:`.tools/screenshots/multiplayer-failure-${index}.png`}).catch(()=>{});
    await writeFile(`.tools/multiplayer-failure-${index}.json`,JSON.stringify(await state(page),null,2));
  }
  throw error;
} finally {
  for (const browser of clients) await browser.close();
  await server.close(); await verifier.close(); await new Promise(resolve=>http.close(resolve));
  await writeFile('.tools/multiplayer-browser-results.json',JSON.stringify({checks, errors}, null, 2));
}

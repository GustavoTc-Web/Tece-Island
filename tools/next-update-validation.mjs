import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir, writeFile} from 'node:fs/promises';
const results=[];
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
await mkdir('.tools/screenshots',{recursive:true});
try {
 for(const touch of [false,true]) {
  const context=await browser.newContext({viewport:touch?{width:393,height:852}:{width:960,height:540},hasTouch:touch,isMobile:touch,userAgent:touch?'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36':undefined,deviceScaleFactor:touch?2:1});
  let owner='next-browser-A-'+(touch?'mobile':'pc');
  // Isolated positive-auth fixture. No real Firebase account or credentials.
  await context.route('https://identitytoolkit.googleapis.com/**',async route=>{
   const url=route.request().url();
   const data=url.includes('signInWithPassword')?{idToken:'fixture-token',refreshToken:'fixture-refresh',localId:owner,expiresIn:'3600'}:{users:[{localId:owner,email:'fixture@example.invalid',emailVerified:true}]};
   await route.fulfill({status:200,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(data)});
  });
  const page=await context.newPage(), errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  const state=()=>page.evaluate(()=>window.tcState);
  const check=(ok,name)=>{results.push({touch,name,ok:!!ok});console.log((ok?'PASS: ':'FAIL: ')+(touch?'Mobile emulado: ':'PC: ')+name);if(!ok)throw Error(name);};
  const wait=()=>page.waitForTimeout(350);
  async function point(x,y){const s=await state(),size=page.viewportSize();if(touch)await page.touchscreen.tap(x*size.width/s.viewport[0],y*size.height/s.viewport[1]);else await page.mouse.click(x*size.width/s.viewport[0],y*size.height/s.viewport[1]);await wait();}
  async function scroll(down=true){const size=page.viewportSize();if(touch){const cdp=await context.newCDPSession(page);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:11,x:size.width*.55,y:size.height*(down?.82:.2)}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:11,x:size.width*.55,y:size.height*(down?.2:.82)}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}else{await page.mouse.move(size.width*.55,size.height*.55);await page.mouse.wheel(0,down?360:-360);}await wait();}
  async function tap(name){if(name==='Jogar solo')name=(await state()).lobby_page==='worlds'?'Jogar mundo':'Continuar';for(let i=0;i<18;i++){const s=await state();const key=Object.keys(s.buttons).find(k=>k===name)||Object.keys(s.buttons).find(k=>k.startsWith(name))||Object.keys(s.buttons).find(k=>k.includes(name));if(!key)throw Error('Botão ausente: '+name);const r=s.buttons[key],clip=s.button_clips[key]||[0,0,...s.viewport];if(r[1]>=clip[1]&&r[1]+r[3]<=clip[1]+clip[3]){await point(r[0]+r[2]/2,r[1]+r[3]/2);return;}await scroll(r[1]>=clip[1]);}throw Error('Botão fora da tela: '+name);}
  async function fixture(action,data={}){await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,...data});await wait();}
  async function login(){await page.locator('#auth-email').waitFor({timeout:60000});await page.locator('#auth-email').fill('fixture@example.invalid');await page.locator('#auth-password').fill('fixture-only-password');await page.locator('#auth-primary').click();await page.waitForFunction(()=>window.tcState?.library&&!window.tcState?.transitioning,null,{timeout:30000});}
  await page.goto('http://localhost:8081/Tece-Island/');
  await page.locator('#auth-email').waitFor({timeout:60000});
  check(!(await state()).orientation_blocked,'Login acessível na vertical e horizontal');
  const old=JSON.stringify({version:4,owner_uid:owner,world_seed:77,elapsed:28,inventory:{slots:[{item:'madeira',quantity:3},{},{},{},{},{},{}],backpack:{},selected:0}});
  const oldKey=await page.evaluate(async({uid,payload})=>{const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(uid)))].map(b=>b.toString(16).padStart(2,'0')).join('');const key='account/'+hash;await new Promise(resolve=>tcLocalProgress.request('write',key,payload,'',resolve));return key;},{uid:owner,payload:old});
  await login();
  if(touch){check((await state()).orientation_blocked,'Autenticar na vertical apresenta aviso de rotação');await page.evaluate(async()=>{document.documentElement.requestFullscreen=()=>Promise.reject(Error('fixture rejection'));screen.orientation.lock=()=>Promise.reject(Error('fixture rejection'));await tcRequestLandscape();});check((await state()).orientation_blocked,'Recusa de tela cheia e orientação mantém aviso e rotação manual');await page.screenshot({path:'.tools/screenshots/next-rotate.png'});await page.setViewportSize({width:852,height:393});await page.waitForFunction(()=>!window.tcState?.orientation_blocked);}
  check((await state()).library.worlds[0].name==='Meu primeiro mundo','Save anterior migra para o primeiro mundo');
  check(await page.evaluate(({key,payload})=>new Promise(resolve=>tcLocalProgress.request('read',key,'','',raw=>resolve(JSON.parse(raw).value===payload))),{key:oldKey,payload:old}),'Original permanece intacto no IndexedDB');
  await page.screenshot({path:'.tools/screenshots/next-lobby-'+(touch?'mobile':'pc')+'.png'});
  const first=(await state()).selected_world;
  await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);
  const layout=await state();
  if(touch){const action=layout.buttons.Inventário;check(action[1]+action[3]<=layout.quick[0][1]+1,'Botões de ação não sobrepõem a barra rápida após rotação');}
  check((await state()).world_id===first&&(await state()).slots[0].quantity===3,'Partida carrega apenas o mundo selecionado');
  check(/^Dia 1 · Anoitece 04:/.test((await state()).clock_text),'Dia e contagem do mundo carregado aparecem no HUD');
  await fixture('items',{items:[{item:'carne_cozida',quantity:3},{item:'armadura_pedra',quantity:1}]});await fixture('health',{value:50});
  if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}
  await tap('1\n');await tap('Usar');const hp=(await state()).health;await page.waitForTimeout(1500);check((await state()).health===hp,'Painel solo congela cura');
  await tap('2\n');await tap('Equipar este item');check((await state()).protection===10&&(await state()).armor.item==='armadura_pedra','Armadura equipa pelo inventário e atualiza proteção');
  await tap('Fechar');await page.waitForFunction(()=>window.tcState?.regeneration_ticks===0,null,{timeout:30000});check((await state()).health===75,'Comida aplica cinco recuperações de cinco HP');
  await fixture('goals');check((await state()).objectives.tracked==='','Objetivos antecipados concluem sequência');
  await tap('Objetivos');check((await state()).panel==='journal'&&(await state()).journal_text==='Objetivos iniciais concluídos','Botão abre sequência completa');await tap('Fechar');
  if(touch){const s=await state(),size=page.viewportSize(),cdp=await context.newCDPSession(page);const finger=(p,id,dx=0)=>({id,x:(p[0]+dx)*size.width/s.viewport[0],y:p[1]*size.height/s.viewport[1]});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[finger(s.sticks.move,1),finger(s.sticks.aim,2)]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[finger(s.sticks.move,1,40),finger(s.sticks.aim,2,40)]});await wait();check((await state()).move[0]>0&&(await state()).aim[0]>0,'Dois dedos mantêm movimento e ataque');await page.setViewportSize({width:393,height:852});await page.waitForFunction(()=>window.tcState?.orientation_blocked);const stopped=await state();check(stopped.paused&&stopped.move[0]===0&&stopped.aim[0]===0,'Voltar à vertical pausa solo e libera comandos');await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.setViewportSize({width:852,height:393});await page.waitForFunction(()=>!window.tcState?.orientation_blocked&&!window.tcState?.paused);}
  else{const x=(await state()).position[0];await page.keyboard.down('d');await page.waitForTimeout(350);await page.keyboard.up('d');await wait();check((await state()).position[0]>x,'WASD continua funcionando no PC');}
  await page.screenshot({path:'.tools/screenshots/next-hud-'+(touch?'mobile':'pc')+'.png'});
  await page.evaluate(()=>{window.tcOriginalPersistence=tcLocalProgress.request;tcLocalProgress.request=(op,key,payload,claim,done)=>op==='write'&&key.includes('/world/')?done(JSON.stringify({ok:false,error:'Falha injetada de teste'})):tcOriginalPersistence(op,key,payload,claim,done);});
  await tap('Menu');await tap('Voltar ao menu principal');check((await state()).position&&(await state()).panel==='menu'&&(await state()).save_visible,'Falha de gravação conserva partida e retry');
  await page.evaluate(()=>tcLocalProgress.request=tcOriginalPersistence);
  await tap('Voltar ao menu principal');await page.waitForFunction(()=>window.tcState?.menu&&!window.tcState?.position&&!window.tcState?.transitioning);
  async function setName(text){await page.locator('#world-name').waitFor();await page.locator('#world-name').fill(text);await page.locator('#world-confirm').click();await page.waitForFunction(()=>!document.querySelector('#world-dialog'));await wait();}
  await tap('Meus mundos');await tap('Criar mundo');await setName('Ilha independente');await page.waitForFunction(()=>window.tcState?.library?.worlds.length===2);const second=(await state()).selected_world;
  check(first!==second,'Criar mundo produz novo ID');
  await tap('Renomear');await setName('Ilha renomeada');await page.waitForFunction(()=>window.tcState?.library?.worlds.some(w=>w.name==='Ilha renomeada'));check((await state()).selected_world===second,'Renomear preserva o ID e a seleção');
  await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);check((await state()).slots.every(s=>!s.item)&&(await state()).protection===0&&(await state()).objectives.values.wood===0,'Novo mundo começa sem itens, armadura ou objetivos do primeiro');
  await tap('Menu');await tap('Voltar ao menu principal');await page.waitForFunction(()=>window.tcState?.menu&&!window.tcState?.transitioning);
  await tap('Meus mundos');await tap('Meu primeiro mundo');await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);
  check((await state()).world_id===first&&(await state()).protection===10&&(await state()).objectives.tracked==='','Voltar ao primeiro mundo restaura equipamento e objetivos');
  await tap('Menu');await tap('Sair da conta');await page.locator('#auth-email').waitFor();owner='next-browser-B-'+(touch?'mobile':'pc');await login();
  await tap('Criar mundo');await setName('Mundo da conta B');await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);
  check((await state()).slots.every(s=>!s.item)&&(await state()).protection===0&&(await state()).objectives.values.wood===0,'Outra conta tem inventário e progresso próprios');
  if(errors.length)console.log('BROWSER ERRORS',JSON.stringify(errors));
  check(errors.length===0,'Sem erros de execução');
  await context.close();
 }
 const desktopTouch=await browser.newContext({viewport:{width:393,height:852},hasTouch:true,isMobile:false});
 await desktopTouch.route('https://identitytoolkit.googleapis.com/**',route=>route.fulfill({status:200,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(route.request().url().includes('signInWithPassword')?{idToken:'fixture',refreshToken:'fixture',localId:'fixture-desktop-touch',expiresIn:'3600'}:{users:[{localId:'fixture-desktop-touch',emailVerified:true}]})}));
 const desktopPage=await desktopTouch.newPage();await desktopPage.goto('http://localhost:8081/Tece-Island/');await desktopPage.locator('#auth-email').waitFor({timeout:60000});await desktopPage.locator('#auth-email').fill('fixture@example.invalid');await desktopPage.locator('#auth-password').fill('fixture-only-password');await desktopPage.locator('#auth-primary').click();await desktopPage.waitForFunction(()=>window.tcState?.library&&!window.tcState?.transitioning,null,{timeout:30000});const desktopAllowed=await desktopPage.evaluate(()=>!tcState.orientation_blocked);results.push({touch:false,name:'Computador com toque não exige orientação mobile',ok:desktopAllowed});console.log((desktopAllowed?'PASS: ':'FAIL: ')+'Computador com toque não exige orientação mobile');if(!desktopAllowed)throw Error('Desktop touch orientation');await desktopTouch.close();
} finally {await browser.close();await writeFile('.tools/next-browser-results.json',JSON.stringify({authentication:'Firebase positivo simulado por interceptação em fixture; nenhum celular físico',results},null,2));}

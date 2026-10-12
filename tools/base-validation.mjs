import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try{for(const touch of [false,true]){
 const context=await browser.newContext({viewport:{width:960,height:540},hasTouch:touch,deviceScaleFactor:touch?2:1}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 const state=()=>page.evaluate(()=>window.tcState),wait=()=>page.waitForTimeout(300);
 async function box(r){const s=await state(),x=(r[0]+r[2]/2)*960/(s.viewport?.[0]||960),y=(r[1]+r[3]/2)*540/(s.viewport?.[1]||540);if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
 const tap=async t=>box((await state()).buttons[t]);
 const setup=async(action,extra={})=>{await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,...extra});await wait();};
 const check=(value,label)=>{results.push({touch,label,pass:!!value});console.log((value?'PASS: ':'FAIL: ')+(touch?'Toque: ':'Mouse: ')+label);};
 const cdp=await context.newCDPSession(page);
 async function scroll(down){
  if(touch){await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:8,x:500,y:down?430:200}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:8,x:500,y:down?180:460}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
  else{await page.mouse.move(500,300);await page.mouse.wheel(0,down?1000:-1000);}
  await wait();
 }
 async function placement(index){
  if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}
  await scroll(false);await box((await state()).inventory_buttons[index]);await scroll(true);await tap('Colocar selecionado');await page.waitForFunction(()=>window.tcState.placing);await wait();
 }
 async function target(dx,dy){const s=await state(),x=s.player_screen[0]+dx,y=s.player_screen[1]+dy;if(touch)await page.touchscreen.tap(x,y);else await page.mouse.move(x,y);await wait();}
 async function confirm(){if(touch)await tap('Confirmar');else{const s=await state();await page.mouse.click(s.player_screen[0]+s.target_dx,s.player_screen[1]+s.target_dy);}}
 await tap('Jogar solo');await page.waitForFunction(()=>window.tcState.position);
 await setup('items',{items:[{item:'parede_madeira',quantity:1},{item:'porta_madeira',quantity:1},{item:'vidraca',quantity:1},{item:'parede_madeira',quantity:1}]});
 async function build(index,dx,dy,rotate=false){
  await setup('position',{x:1152,y:768});await placement(index);
  if(rotate){if(touch)await tap('Girar');else{await page.keyboard.press('r');await wait();}}
  await target(dx,dy);
  if(touch)await tap('Confirmar');else{const s=await state();await page.mouse.click(s.player_screen[0]+dx,s.player_screen[1]+dy);await wait();}
 }
 await build(0,0,-96);let s=await state();check(s.structures.some(v=>v.kind==='parede_madeira')&&!s.slots[0].item,'Colocar parede pela interface');
 await build(1,96,0,true);s=await state();const door=s.structures.find(v=>v.kind==='porta_madeira');
 check(!!door&&Math.abs(door.rotation-Math.PI/2)<0.001,'Girar e confirmar porta');
 await setup('position',{x:door.x,y:door.y+50});
 if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
 check((await state()).structures.find(v=>v.kind==='porta_madeira').door_open,'Interação abre porta');
 if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
 check(!(await state()).structures.find(v=>v.kind==='porta_madeira').door_open,'Interação fecha porta');
 await build(2,96,-96);s=await state();check(s.structures.some(v=>v.kind==='vidraca')&&!s.slots[2].item,'Colocar vidro pela interface');
 await setup('position',{x:1152,y:768});await placement(3);await target(-96,0);
 if(touch)await tap('Cancelar');else{await page.keyboard.press('Escape');await wait();}
 check(!(await state()).placing&&(await state()).slots[3].item==='parede_madeira','Cancelar mantém peça');
 await setup('position',{x:door.x,y:door.y+50});if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
 await page.screenshot({path:'.tools/screenshots/base-'+(touch?'touch':'desktop')+'.png'});
 await tap('Voltar ao menu');await page.waitForFunction(()=>window.tcState.menu);await page.waitForTimeout(1500);await page.reload();
 await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Jogar solo');await page.waitForFunction(()=>window.tcState.position);s=await state();
 check(s.structures.filter(v=>['parede_madeira','porta_madeira','vidraca'].includes(v.kind)).length===3&&s.structures.find(v=>v.kind==='porta_madeira').door_open,'Reload conserva base e porta aberta');
 check(!errors.length,'Sem erros do engine/navegador');await context.close();
}}finally{await browser.close();}
await writeFile('.tools/base-results.json',JSON.stringify(results,null,2));if(results.some(v=>!v.pass))process.exitCode=1;

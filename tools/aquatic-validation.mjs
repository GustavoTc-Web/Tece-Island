import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try{for(const touch of [false,true]){
 const context=await browser.newContext({viewport:{width:960,height:540},hasTouch:touch,deviceScaleFactor:touch?2:1}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 const state=()=>page.evaluate(()=>window.tcState),wait=()=>page.waitForTimeout(250);
 async function box(r){const s=await state(),x=(r[0]+r[2]/2)*960/(s.viewport?.[0]||960),y=(r[1]+r[3]/2)*540/(s.viewport?.[1]||540);if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
 const tap=async t=>box((await state()).buttons[t]);
 const setup=async(action,extra={})=>{await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,...extra});await wait();};
 const check=(value,label)=>{results.push({touch,label,pass:!!value});console.log((value?'PASS: ':'FAIL: ')+(touch?'Toque: ':'Mouse: ')+label);};
 await tap('Jogar solo');await page.waitForFunction(()=>window.tcState.position);
 await setup('items',{items:[{item:'arco',quantity:1},{item:'flecha',quantity:3}]});await setup('aquatic');await page.waitForFunction(()=>window.tcState.swimming);
 await box((await state()).quick[0]);check((await state()).swimming,'Jogador entra em nado');
 const cdp=await context.newCDPSession(page);
 if(touch){
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x:860,y:425}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x:915,y:425}]});await page.waitForTimeout(400);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 }else{const s=await state();await page.mouse.click(s.player_screen[0]+55,s.player_screen[1]);}
 await wait();
 if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
 let s=await state();check(s.slots.some(v=>v.item==='carne_peixe'&&v.quantity===1),'Combate e coleta de peixe na água');
 const start=s.position;
 if(touch){await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:0,x:100,y:425}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:0,x:160,y:425}]});await page.waitForTimeout(400);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
 else{await page.keyboard.down('d');await page.waitForTimeout(400);await page.keyboard.up('d');}
 await wait();s=await state();check(s.position[0]>start[0]+25&&s.position[0]<start[0]+80,'Movimento em água usa velocidade reduzida');
 await setup('bird_art');await page.screenshot({path:'.tools/screenshots/aquatic-'+(touch?'touch':'desktop')+'.png'});
 await setup('position',{x:-768,y:768});await page.waitForFunction(()=>!window.tcState.swimming);check(!(await state()).swimming,'Transição para passagem de terra');
 check(!errors.length,'Sem erros do engine/navegador');await context.close();
}}finally{await browser.close();}
await writeFile('.tools/aquatic-results.json',JSON.stringify(results,null,2));if(results.some(v=>!v.pass))process.exitCode=1;

import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try{for(const touch of [false,true]){
 const context=await browser.newContext({viewport:{width:960,height:540},hasTouch:touch,deviceScaleFactor:touch?2:1}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 const state=()=>page.evaluate(()=>window.tcState),wait=()=>page.waitForTimeout(200);
 async function box(r){const s=await state(),x=(r[0]+r[2]/2)*960/(s.viewport?.[0]||960),y=(r[1]+r[3]/2)*540/(s.viewport?.[1]||540);if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
 const tap=async t=>box((await state()).buttons[t]);
 const setup=async(action,items)=>{await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,items});await wait();};
 const check=(value,label)=>{results.push({touch,label,pass:!!value});console.log((value?'PASS: ':'FAIL: ')+(touch?'Toque: ':'Mouse: ')+label);};
 await tap('Jogar solo');await page.waitForFunction(()=>window.tcState.position);
 await setup('items',[{item:'pistola',quantity:1,loaded:6},{item:'cantil',quantity:1,water:2}]);await setup('chest');await page.waitForFunction(()=>window.tcState.panel==='chest');await wait();
 await box((await state()).storage_buttons[0]);await tap('Guardar pilha');let s=await state();
 check(s.storage_slots[0].item==='pistola'&&s.storage_slots[0].loaded===6&&!s.slots[0].item,'Guardar arma conserva munição');
 await box(s.storage_buttons[1]);await tap('Guardar 1');s=await state();check(s.storage_slots[1].water===2&&!s.slots[1].item,'Guardar cantil conserva doses');
 await tap('Desmontar baú');check((await state()).storage_status.includes('Baú cheio'),'Recusa desmontar baú cheio');
 await tap('Baú');await wait();await box((await state()).storage_buttons[1]);await tap('Retirar pilha');s=await state();check(s.slots.some(v=>v.item==='cantil'&&v.water===2),'Retirar cantil pelo painel');
 await page.screenshot({path:'.tools/screenshots/chest-'+(touch?'touch':'desktop')+'.png'});
 await tap('Fechar');await setup('items',[{item:'arco',quantity:1},{item:'flecha',quantity:3}]);
 await box((await state()).quick[0]);
 if(touch){const cdp=await context.newCDPSession(page);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x:860,y:425}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x:915,y:425}]});await page.waitForTimeout(350);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
 else{await page.mouse.move(600,270);await page.mouse.down();await page.waitForTimeout(350);await page.mouse.up();}
 await wait();s=await state();check(s.slots.filter(v=>v.item==='flecha').reduce((n,v)=>n+v.quantity,0)===2,'Ataque/mira existente consome uma flecha');
 if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}
 await page.mouse.click(600,270);await wait();s=await state();check(s.slots.filter(v=>v.item==='flecha').reduce((n,v)=>n+v.quantity,0)===2,'Clique em menu não consome flecha');
 await tap('Fechar');await tap('Voltar ao menu');await page.waitForFunction(()=>window.tcState.menu);
 await page.waitForTimeout(1500);await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 await tap('Jogar solo');await page.waitForFunction(()=>window.tcState.position);s=await state();
 check(s.slots.some(v=>v.item==='arco')&&s.structures.some(v=>v.kind==='bau'),'Reabrir navegador carrega progresso local');
 await tap('Interagir').catch(()=>{});await page.keyboard.press('e');await wait();s=await state();
 check(s.storage_slots?.some(v=>v.item==='pistola'&&v.loaded===6),'Baú mantém arma após recarregar navegador');
 check(!errors.length,'Sem erros do engine/navegador');await context.close();
}}finally{await browser.close();}
await writeFile('.tools/chest-bow-results.json',JSON.stringify(results,null,2));if(results.some(v=>!v.pass))process.exitCode=1;

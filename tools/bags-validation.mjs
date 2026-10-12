import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try{for(const touch of [false,true]){
 const context=await browser.newContext({viewport:{width:960,height:540},hasTouch:touch,deviceScaleFactor:touch?2:1}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 const state=()=>page.evaluate(()=>window.tcState),wait=()=>page.waitForTimeout(180);
 async function box(r){const s=await state(),x=(r[0]+r[2]/2)*960/(s.viewport?.[0]||960),y=(r[1]+r[3]/2)*540/(s.viewport?.[1]||540);if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
 const tap=async t=>box((await state()).buttons[t]);
 const setup=async(action,items)=>{await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,items});await wait();};
 const check=(value,label)=>{results.push({touch,label,pass:!!value});console.log((value?'PASS: ':'FAIL: ')+(touch?'Toque: ':'Mouse: ')+label);};
 await tap('Jogar solo');await page.waitForFunction(()=>window.tcState.position);
 await setup('items',[{item:'madeira',quantity:4},{item:'fibra',quantity:12}]);
 if(touch)await tap('Fabricação');else{await page.keyboard.press('c');await wait();}
 for(const [id,level,wood,thread,capacity] of [['mochila',1,0,0,9],['mochila_2',2,12,4,11],['mochila_3',3,20,8,13],['mochila_4',4,30,12,15]]){
  if(wood)await setup('add',[{item:'madeira',quantity:wood},{item:'linha',quantity:thread}]);
  await box((await state()).search);await page.keyboard.press('Control+a');await page.keyboard.type(String(level));await page.waitForFunction(id=>!!window.tcState.recipes[id],id,{timeout:5000});
  await page.waitForTimeout(250);await box((await state()).recipes[id]);await page.waitForFunction(cap=>window.tcState.capacity===cap,capacity,{timeout:2000}).catch(async()=>{console.log(JSON.stringify({recipe:id,box:(await state()).recipes[id],slots:(await state()).slots,errors}));await page.screenshot({path:'.tools/screenshots/bag-failed.png'});});let s=await state();
  check(s.capacity===capacity&&s.backpack.item===id&&!s.slots.some(v=>v.item===id),'Bolsa nível '+level+' substitui anterior: '+capacity+' espaços');
 }
 await tap('Fechar');await wait();
 if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}
 check((await state()).inventory_buttons.length===15,'Inventário exibe os quinze espaços');
 await page.screenshot({path:'.tools/screenshots/bags-'+(touch?'touch':'desktop')+'.png'});
 await tap('Fechar');check(!(await state()).paused,'Fechar restaura controles');
 check(!errors.length,'Sem erros do engine/navegador');await context.close();
}}finally{await browser.close();}
await writeFile('.tools/bags-results.json',JSON.stringify(results,null,2));if(results.some(v=>!v.pass))process.exitCode=1;

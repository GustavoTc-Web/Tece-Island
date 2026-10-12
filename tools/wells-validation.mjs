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
 const original=(await state()).wells;const [x,y]=original[0];
 await setup('items',{items:[{item:'cantil',quantity:1,water:0}]});await setup('needs',{hunger:20,thirst:20});
 await setup('position',{x,y:y+50});
 if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
 check((await state()).panel==='well','Poço natural abre painel');
 await tap('Beber');await tap('Encher cantil');let s=await state();
 check(s.thirst>59&&s.slots.some(v=>v.item==='cantil'&&v.water===3),'Poço permite beber e encher cantil');
 await tap('Fechar');await box((await state()).quick[0]);
 if(touch)await tap('Usar item');else{await page.keyboard.press('f');await wait();}
 check((await state()).slots[0].water===2,'Usar cantil consome uma dose');
 await tap('Voltar ao menu');await page.waitForFunction(()=>window.tcState.menu);await page.waitForTimeout(1500);
 await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 await tap('Jogar solo');await page.waitForFunction(()=>window.tcState.position);s=await state();
 check(JSON.stringify(s.wells)===JSON.stringify(original),'Reload conserva poços sem refazer sorteios');
 check(!errors.length,'Sem erros do engine/navegador');await context.close();
}}finally{await browser.close();}
await writeFile('.tools/wells-results.json',JSON.stringify(results,null,2));if(results.some(v=>!v.pass))process.exitCode=1;

import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try{for(const touch of [false,true]){
 const viewport=touch?{width:852,height:393}:{width:960,height:540};
 const context=await browser.newContext({viewport,hasTouch:touch,deviceScaleFactor:touch?3:1}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 const state=()=>page.evaluate(()=>window.tcState),wait=()=>page.waitForTimeout(300);
 async function box(r){const s=await state(),x=(r[0]+r[2]/2)*viewport.width/(s.viewport?.[0]||960),y=(r[1]+r[3]/2)*viewport.height/(s.viewport?.[1]||540);if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
 const setup=async(x,y)=>{await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action:'position',x,y});await wait();};
 const check=(value,label)=>{results.push({touch,label,pass:!!value});console.log((value?'PASS: ':'FAIL: ')+(touch?'Toque: ':'Desktop: ')+label);};
 await box((await state()).buttons['Jogar solo']);await page.waitForFunction(()=>window.tcState.position);
 let s=await state();check(s.minimap[0]>=s.viewport[0]-170&&s.minimap[1]>68&&s.minimap[1]+s.minimap[3]<396,'Minimapa no canto direito sem sobreposição');
 const explored=s.explored;
 for(const [x,y,id] of [[1152,-25,'swamp_n'],[1152,1550,'forest_s'],[-25,768,'aquatic_w'],[-2304,768,'ruins_w'],[6144,2304,'desert_s']]){
  await setup(x,y);s=await state();check(s.region===id,'Acesso à região '+id);
 }
 check((await state()).explored>explored,'Minimapa acumula terreno visitado');
 await page.screenshot({path:'.tools/screenshots/expansion-'+(touch?'touch':'desktop')+'.png'});
 await setup(1152,20);
 if(touch){
  const s=await state(),scale=viewport.height/s.viewport[1],cdp=await context.newCDPSession(page),x=100*scale,y=(s.viewport[1]-115)*scale;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:0,x,y}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:0,x,y:y-60*scale}]});await page.waitForTimeout(600);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 }else{await page.keyboard.down('w');await page.waitForTimeout(600);await page.keyboard.up('w');}
 await wait();check((await state()).region==='swamp_n','Travessia física entre mapa antigo e norte');
 check(!errors.length,'Sem erros do engine/navegador');await context.close();
}}finally{await browser.close();}
await writeFile('.tools/expansion-results.json',JSON.stringify(results,null,2));if(results.some(v=>!v.pass))process.exitCode=1;

import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const results=[],errors=[];
const route=JSON.parse(await readFile('.tools/solo4-tower-routes.json','utf8')).routes.find(r=>r.fixture==='seed 77').turns;
route[route.length-1]=[1152,-2048]; // Stand on the parchment; allow input/snapshot latency.
await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
try {
 for(const dimensions of [{width:1280,height:720,touch:false,night:3},{width:852,height:393,touch:true,night:4},{width:640,height:360,touch:true,night:4}]) {
  const {width,height,touch,night}=dimensions;
  const context=await browser.newContext({viewport:{width,height},hasTouch:touch,isMobile:touch,deviceScaleFactor:touch?2:1});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error'&&m.text().includes('SCRIPT ERROR'))errors.push(m.text());});
  const state=()=>page.evaluate(()=>tcState);
  const wait=()=>page.waitForTimeout(300);
  const check=(ok,label)=>{results.push({dimensions,pass:!!ok,label});console.log(`${ok?'PASS':'FAIL'}: ${width} ${label}`);assert.ok(ok,label);};
  async function fixture(action,data={}){await page.evaluate(r=>tcFixture(JSON.stringify(r)),{action,...data});await wait();}
  async function tap(name){const s=await state(),key=Object.keys(s.buttons).find(k=>k===name)||Object.keys(s.buttons).find(k=>k.startsWith(name));assert.ok(key,'Missing '+name);const r=s.buttons[key],x=(r[0]+r[2]/2)*width/s.viewport[0],y=(r[1]+r[3]/2)*height/s.viewport[1];if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
  async function interact(){if(touch)await tap('Interagir');else {await page.keyboard.press('e');await wait();}}
  try {
   await page.goto('http://localhost:8081/Tece-Island/');
   await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
   await tap('Continuar');await page.waitForFunction(()=>tcState?.tasks);
   await fixture('tower_route');await fixture('campaign_clock',{day:night,night:false});
   await fixture('items',{items:[{item:'madeira',quantity:8},{item:'linha',quantity:3}]});await fixture('tasks_craft',{id:'arco'});
   await fixture('items',{items:[{item:'flecha',quantity:8},{item:'carne_cozida',quantity:3},{item:'cantil',quantity:1,water:3}]});
   let s=await state();
   check(!s.campaign.discovered&&!s.campaign.map_found&&s.tower_navigation.outside&&s.tower_navigation.bearing==='N','Torre e rumo aparecem sem examinar sinalizador');
   check(s.objective_text.includes('4/5')&&s.tasks.next==='map','Reproduz etapa 3 em 4/5, inclusive no dia 4');
   const [tx,ty,tw,th]=s.tasks.panel_rect,[mx]=s.minimap,[cx,cy,cw,ch]=s.tower_caption_rect;
   check(tx+tw<=mx+1,'Objetivos e minimapa não se sobrepõem');
   check(cx>=0&&cx+cw<=s.viewport[0]+1&&cy+ch<s.viewport[1]*0.58,'Nome e rumo cabem no HUD');
   await page.screenshot({path:`.tools/screenshots/tower4-direction-${width}.png`});
   // Entire journey from the spawn: keyboard or held virtual stick. No teleport,
   // no map-grant fixture, no campaign.interact call.
   const start=s.position;
   const cdp=touch?await context.newCDPSession(page):null;
   for(const point of route){
    s=await state();
    const axis=Math.abs(point[0]-s.position[0])>Math.abs(point[1]-s.position[1])?0:1;
    const delta=point[axis]-s.position[axis];if(Math.abs(delta)<8)continue;
    const sign=Math.sign(delta),key=axis===0?(sign>0?'d':'a'):(sign>0?'s':'w');
    if(touch){
     const x=s.sticks.move[0]*width/s.viewport[0],y=s.sticks.move[1]*height/s.viewport[1],r=s.stick_radius*width/s.viewport[0]*0.8;
     await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,x,y}]});
     await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x:x+(axis===0?sign*r:0),y:y+(axis===1?sign*r:0)}]});
    }else await page.keyboard.down(key);
    await page.waitForFunction(({axis,sign,target})=>sign*(tcState.position[axis]-target)>=-5,{axis,sign,target:point[axis]},{timeout:20000});
    if(touch)await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});else await page.keyboard.up(key);
   }
   await wait();s=await state();
   check(start[1]>500&&s.position[1]<-1995&&s.pickup_kind==='map'&&s.region==='mist_ridge','Percurso completo até o mapa usa movimento e colisões reais');
   check(!s.tower_navigation.outside&&s.tower_navigation.nearby&&s.pickup_prompt.includes('anoitecer'),'Na base, pergaminho selecionado e restrição diurna explícita');
   await interact();check(!(await state()).campaign.map_found,'Interagir de dia mantém missão pendente');
   await page.screenshot({path:`.tools/screenshots/tower4-day-${width}.png`});
   await fixture('campaign_clock',{day:night,night:true});
   check((await state()).pickup_prompt.includes('E ou botão Interagir'),'À noite informa tecla e botão de interação');
   await page.screenshot({path:`.tools/screenshots/tower4-night-${width}.png`});
   await interact();s=await state();
   check(s.campaign.map_found&&s.tasks.conditions.map.done&&Object.keys(s.tower_navigation).length===0,`Coleta real na noite ${night} conclui objetivo e remove marcador`);
   await fixture('save');await page.waitForTimeout(1200);await page.reload();
   await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Continuar');await page.waitForFunction(()=>tcState?.tasks);
   s=await state();check(s.campaign.map_found&&Object.keys(s.tower_navigation).length===0,'Reabrir IndexedDB mantém coleta e não recria pendência');
  } catch(e) {await page.screenshot({path:`.tools/screenshots/tower4-failure-${width}.png`});await writeFile('.tools/tower4-ui-failure.json',JSON.stringify(await state(),null,2));throw e;} finally {await context.close();}
 }
 assert.deepEqual(errors,[]);
} finally {await browser.close();await writeFile('.tools/tower4-browser-results.json',JSON.stringify({results,errors,automated:true,human_played:false,enemies_disabled:true},null,2)+'\n');}

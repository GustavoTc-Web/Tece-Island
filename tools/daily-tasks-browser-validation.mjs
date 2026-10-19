import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const results=[],errors=[];
await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
try{
 for(const dimensions of [{width:1280,height:720,touch:false},{width:852,height:393,touch:true},{width:640,height:360,touch:true}]){
  const {width,height,touch}=dimensions;
  const context=await browser.newContext({viewport:{width,height},hasTouch:touch,isMobile:touch,deviceScaleFactor:touch?2:1});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&m.text().includes('SCRIPT ERROR'))errors.push(m.text());});
  const state=()=>page.evaluate(()=>tcState);
  const wait=()=>page.waitForTimeout(250);
  const check=(ok,label)=>{results.push({dimensions,pass:!!ok,label});console.log(`${ok?'PASS':'FAIL'}: ${width} ${label}`);assert.ok(ok,label);};
  async function fixture(action,data={}){await page.evaluate(r=>tcFixture(JSON.stringify(r)),{action,...data});await wait();}
  async function tap(name){const s=await state(),key=Object.keys(s.buttons).find(k=>k===name)||Object.keys(s.buttons).find(k=>k.startsWith(name));assert.ok(key,'Missing '+name);const r=s.buttons[key],x=(r[0]+r[2]/2)*width/s.viewport[0],y=(r[1]+r[3]/2)*height/s.viewport[1];if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
  async function open(){await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Continuar');await page.waitForFunction(()=>tcState?.tasks);}
  try{
   await open();let s=await state();
   check(s.objective_text.includes('0/4')&&s.tasks.rows.length===4,'Kit inicial tem quatro tarefas e contador');
   const r=s.tasks.panel_rect;check(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=s.viewport[0]+1&&r[1]+r[3]<s.viewport[1]*0.62,'Painel cabe acima dos controles no PC/mobile');
   await fixture('items',{items:[{item:'madeira',quantity:11},{item:'pedra',quantity:7}]});
   for(const id of ['machado_madeira','picareta_madeira','espada_pedra','fogueira'])await fixture('tasks_craft',{id});
   s=await state();check(s.tasks.rows.every(r=>r.done)&&s.objective_text.includes('4/4'),'Fabricação real marca todas com check');
   await page.screenshot({path:`.tools/screenshots/daily3-complete-${width}.png`});
   const expanded=s.tasks.panel_rect[3];await tap('−');s=await state();
   check(s.tasks.collapsed&&s.tasks.panel_rect[3]<expanded,'Recolher mantém contador e libera espaço');
   await fixture('save');await page.waitForTimeout(1200);await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Continuar');await page.waitForFunction(()=>tcState?.tasks);
   s=await state();check(s.tasks.collapsed&&s.tasks.rows.every(r=>r.done),'Reload IndexedDB mantém conquistas e recolhimento');
   await fixture('items',{items:[]});check((await state()).tasks.rows.every(r=>r.done),'Perder itens não apaga fabricação');
   await fixture('campaign_clock',{day:3,night:false});await tap('+');
   check((await state()).tasks.stage===2&&(await state()).tasks.rows.find(r=>r.id==='map').requirement.includes('anoitecer'),'Etapa do mapa mostra requisito noturno');
   await fixture('items',{items:[{item:'carne_cozida',quantity:3},{item:'armadura_pedra',quantity:1},{item:'cantil',quantity:1,water:3}]});
   s=await state();check(s.tasks.conditions.food3.done&&s.tasks.conditions.water3.done&&!s.tasks.conditions.wear.done,'Bolsa e armadura equipada são condições distintas');
   await fixture('tasks_equip_armor',{index:1});check((await state()).tasks.conditions.wear.done,'Equipar conclui condição atual');
   await fixture('needs',{hunger:50,thirst:50});await fixture('tasks_use',{index:0});await fixture('tasks_use',{index:2});
   s=await state();check(!s.tasks.conditions.food3.done&&s.tasks.conditions.food3.value===2&&!s.tasks.conditions.water3.done,'Comer e beber reduzem contadores atuais');
   await page.screenshot({path:`.tools/screenshots/daily3-current-${width}.png`});
   await tap('Dia 3 · Expedição');s=await state();
   check(s.campaign_text.includes('Dia 1')&&s.campaign_text.includes('Dia 6')&&s.campaign_text.includes('Noite 6+')&&s.campaign_text.includes('[x]'),'Diário reúne etapas, checks e pendências antigas');
   await page.screenshot({path:`.tools/screenshots/daily3-journal-${width}.png`});
   await tap('Fechar');check(!(await state()).paused,'Fechar diário devolve os controles');
   const backup=await page.evaluate(async()=>{
    const request=(op,key,payload='',claim='')=>new Promise(resolve=>tcLocalProgress.request(op,key,payload,claim,r=>resolve(JSON.parse(r))));
    const key='tasks-v8-'+crypto.randomUUID(),old=JSON.stringify({version:7,inventory:{slots:[]},objectives:{}}),next=JSON.stringify({version:8,inventory:{slots:[]},objectives:tcState.objectives});
    await request('write',key,old,JSON.stringify({expected:null}));
    const write=await request('write',key,next,JSON.stringify({expected:old}));
    await request('write',key,next,JSON.stringify({expected:next}));
    const stale=await request('write',key,old,JSON.stringify({expected:old}));
    return write.ok&&(await request('read',key+':before-v8')).value===old&&stale.conflict&&(await request('read',key)).value===next;
   });
   check(backup,'Migração v7 para v8 preserva backup exato e rejeita gravação obsoleta');
  }catch(error){await page.screenshot({path:`.tools/screenshots/daily3-failure-${width}.png`});await writeFile('.tools/daily3-ui-failure.json',JSON.stringify(await state(),null,2));throw error;}finally{await context.close();}
 }
 assert.deepEqual(errors,[]);
}finally{await browser.close();await writeFile('.tools/daily3-browser-results.json',JSON.stringify({results,errors},null,2)+'\n');}

import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const results=[],errors=[],frameSamples=[];
await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
try{
 for(const dimensions of [{width:1280,height:720,touch:false},{width:852,height:393,touch:true},{width:640,height:360,touch:true}]){
  const {width,height,touch}=dimensions;
  const context=await browser.newContext({viewport:{width,height},hasTouch:touch,isMobile:touch,deviceScaleFactor:touch?2:1,userAgent:touch?'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36':undefined});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const state=()=>page.evaluate(()=>window.tcState);
  const wait=()=>page.waitForTimeout(250);
  const check=(ok,label)=>{results.push({dimensions,pass:!!ok,label});console.log(`${ok?'PASS':'FAIL'}: ${width} ${label}`);assert.ok(ok,label);};
  async function tap(name){const s=await state(),key=Object.keys(s.buttons).find(k=>k===name)||Object.keys(s.buttons).find(k=>k.startsWith(name));assert.ok(key,'Missing '+name);const r=s.buttons[key];const x=(r[0]+r[2]/2)*width/s.viewport[0],y=(r[1]+r[3]/2)*height/s.viewport[1];if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
  async function fixture(action,data={}){await page.evaluate(r=>tcFixture(JSON.stringify(r)),{action,...data});await wait();}
  async function interact(){if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}}
  try{
   await page.goto('http://localhost:8081/Tece-Island/');
   await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
   await tap('Continuar');await page.waitForFunction(()=>window.tcState?.position);
   let s=await state();check(s.objective_text.includes('sinal'),'HUD mostra o objetivo da campanha');
   const r=s.campaign_objective_rect;
   check(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=s.viewport[0]+1,'Objetivo cabe no HUD');
   if(touch){
    const cdp=await context.newCDPSession(page),start=s.position[0];
    const convert=p=>({x:p[0]*width/s.viewport[0],y:p[1]*height/s.viewport[1]});
    const move=convert(s.sticks.move),aim=convert(s.sticks.aim);
    const radius=s.stick_radius*width/s.viewport[0]*0.8;
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:1,...move},{id:2,...aim}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:1,x:move.x+radius,y:move.y},{id:2,x:aim.x,y:aim.y-radius}]});
    await page.waitForTimeout(350);s=await state();
    check(s.position[0]>start&&s.aim[1]<0,'Dois dedos continuam movendo e mirando');
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   }else{
    const start=s.position[0];await page.keyboard.down('d');await page.waitForTimeout(250);await page.keyboard.up('d');
    check((await state()).position[0]>start+20,'Movimento por teclado preservado');
   }
   await fixture('campaign_visit',{id:'beacon'});await interact();
   check((await state()).campaign.discovered,'Interação real descobre sinalizador');
   await fixture('campaign_visit',{id:'clue'});await interact();
   check((await state()).campaign.clues&&(await state()).journal.discovered.includes('arrival'),'Registro original revela pistas sem competir na coleta');
   for(const id of ['lens','coil','core']){
    await fixture('campaign_visit',{id});await interact();
    check((await state()).campaign.components.includes(id),'Coleta real do componente '+id);
    if(id!=='core')await page.screenshot({path:`.tools/screenshots/solo-${id}-${width}.png`});
    if(id!=='core'){
     const sample=await page.evaluate(()=>new Promise(resolve=>{const deltas=[];let last;function frame(t){if(last!==undefined)deltas.push(t-last);last=t;if(deltas.length<45)requestAnimationFrame(frame);else{deltas.sort((a,b)=>a-b);resolve({median_ms:deltas[22],p95_ms:deltas[42],frames:45});}}requestAnimationFrame(frame);}));
     frameSamples.push({dimensions,region:id,...sample});
    }
   }
   await fixture('campaign_journal');
   check((await state()).campaign_text.includes('Serra Nebulosa')&&(await state()).campaign_text.includes('[x]'),'Diário reúne pistas e componentes');
   await page.screenshot({path:`.tools/screenshots/solo-journal-${width}.png`});
   await fixture('campaign_visit',{id:'beacon'});await interact();
   check((await state()).campaign.repaired,'Interação repara o sinalizador');
   await fixture('campaign_night');await interact();
   check((await state()).campaign.encounter==='active','Sétima noite ativa confronto');
   await fixture('campaign_win');
   check((await state()).campaign.encounter==='won'&&(await state()).paused,'Vitória abre resumo e pausa combate');
   await page.screenshot({path:`.tools/screenshots/solo-victory-${width}.png`});
   await tap('Continuar explorando');
   check(!(await state()).paused&&(await state()).campaign.encounter==='won','Continuar por mouse/toque preserva o mundo');
   const persistence=await page.evaluate(async()=>{
    const request=(op,key,payload='',claim='')=>new Promise(resolve=>tcLocalProgress.request(op,key,payload,claim,r=>resolve(JSON.parse(r))));
    const key='campaign-validation-'+crypto.randomUUID();
    const legacy=JSON.stringify({version:5,inventory:{slots:[]},elapsed:6400});
    await request('write',key,legacy,JSON.stringify({expected:null}));
    const next=JSON.stringify({...JSON.parse(legacy),version:6,campaign:window.tcState.campaign});
    const first=await request('write',key,next,JSON.stringify({expected:legacy}));
    const backup=(await request('read',key+':before-campaign-v1')).value;
    const second=await request('write',key,next,JSON.stringify({expected:next}));
    const repeat=(await request('read',key+':before-campaign-v1')).value;
    const stale=await request('write',key,legacy,JSON.stringify({expected:legacy}));
    return first.ok&&second.ok&&backup===legacy&&repeat===legacy&&(await request('read',key+':before-v6')).value===legacy&&stale.conflict&&(await request('read',key)).value===next;
   });
   check(persistence,'Migração IndexedDB tem backup exato, repetível e conflito protegido');
  }finally{await context.close();}
 }
 assert.deepEqual(errors,[]);
}finally{await browser.close();await writeFile('.tools/solo-browser-results.json',JSON.stringify({results,errors,frameSamples},null,2)+'\n');}

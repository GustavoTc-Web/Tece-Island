// Sampling the Godot Web test build, not a measurement on a physical phone.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const scenarios=[],errors=[];
const percentile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.min(values.length-1,Math.floor(values.length*p))];
try{
 for(const mobile of [false,true]){
  const context=await browser.newContext({viewport:mobile?{width:852,height:393}:{width:1280,height:720},hasTouch:mobile,isMobile:mobile,deviceScaleFactor:mobile?2:1});
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error/.test(m.text()))errors.push(m.text());});
  const start=performance.now();await page.goto('http://localhost:8081/Tece-Island/');
  await page.waitForFunction(()=>window.tcState?.menu&&document.querySelector('#status').style.display==='none',null,{timeout:60000});
  const readyMs=performance.now()-start;
  const fixture=(action,data={})=>page.evaluate(r=>tcFixture(JSON.stringify(r)),{action,...data});
  const s=await page.evaluate(()=>tcState),r=s.buttons.Continuar,v=page.viewportSize();
  await page.mouse.click((r[0]+r[2]/2)*v.width/s.viewport[0],(r[1]+r[3]/2)*v.height/s.viewport[1]);
  await page.waitForFunction(()=>window.tcState?.position);
  for(const name of ['spawn-movement','expanded-biome','temple-encounter']){
   if(name==='expanded-biome')await fixture('position',{x:-2200,y:1700});
   if(name==='temple-encounter'){
    await fixture('campaign_clock',{day:3,night:true});await fixture('campaign_visit',{id:'map'});await page.waitForTimeout(250);await page.keyboard.press('e',{delay:120});
    await page.waitForFunction(()=>tcState.campaign.map_found);
    await fixture('campaign_clock',{day:4,night:true});await fixture('campaign_visit',{id:'lens'});await page.waitForTimeout(250);await page.keyboard.press('e',{delay:120});
    await page.waitForFunction(()=>tcState.campaign.temples.lens.started);
   }
   await page.waitForTimeout(2200);
   const samples=[];await page.keyboard.down('d');
   for(let i=0;i<70;i++){
    await page.waitForTimeout(100);
    const sample=await page.evaluate(()=>({fps:tcState.fps,process_ms:tcState.process_ms,draw_calls:tcState.draw_calls,dead:tcState.dead}));samples.push(sample);
    if(!Number.isFinite(sample.process_ms)||!Number.isFinite(sample.draw_calls))throw Error('Rebuild fixture with performance monitors before measuring');
    if(i===20||i===50){await page.keyboard.up('d');await page.keyboard.down('a');}
    if(i===35){await page.keyboard.up('a');await page.keyboard.down('d');}
   }
   await page.keyboard.up('a');await page.keyboard.up('d');
   if(samples.some(s=>s.dead))throw Error('Performance scenario ended on death: '+name);
   const row={format:mobile?'mobile-emulated':'PC-emulated',scenario:name,viewport:v,deviceScaleFactor:mobile?2:1,load_ready_ms:readyMs,samples:samples.length,fps_median:percentile(samples.map(s=>s.fps),.5),fps_min:Math.min(...samples.map(s=>s.fps)),sampled_process_p95_ms:percentile(samples.map(s=>s.process_ms),.95),draw_calls_median:percentile(samples.map(s=>s.draw_calls),.5)};
   scenarios.push(row);console.log(JSON.stringify(row));
  }
  await context.close();
 }
 if(errors.length)throw Error('Runtime errors in performance fixture');
}finally{await browser.close();await writeFile('.tools/beta-performance-results.json',JSON.stringify({physical:false,renderer:'Headless Edge with SwiftShader permitted; no physical mobile GPU',scope:'Godot Engine FPS and TIME_PROCESS sampled every 100ms for 70 samples per scenario; this is not a per-frame p95 or a network RTT benchmark',scenarios,errors},null,2));}

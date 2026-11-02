// Prepared UI fixture only, mouse and CDP touch emulation; not a human campaign.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const results=[],errors=[];await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
try{
 for(const mobile of [false,true]){
  const viewport=mobile?{width:852,height:393}:{width:1280,height:720};
  const context=await browser.newContext({viewport,hasTouch:mobile}),page=await context.newPage(),cdp=await context.newCDPSession(page);
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error/.test(m.text()))errors.push(m.text());});
  const state=()=>page.evaluate(()=>tcState),wait=()=>page.waitForTimeout(180);
  const check=(ok,label)=>{assert.ok(ok,label);results.push({mobile,pass:true,label});console.log('PASS '+(mobile?'touch':'mouse')+': '+label);};
  const command=async(action,data={})=>{await page.evaluate(r=>tcFixture(JSON.stringify(r)),{action,...data});await wait();};
  const point=async i=>{const s=await state(),r=s.inventory_buttons[i];return {x:(r[0]+r[2]/2)*viewport.width/s.viewport[0],y:(r[1]+r[3]/2)*viewport.height/s.viewport[1]};};
  const send=async(type,p=[])=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints:p.map((v,i)=>({id:i,...v}))});
  async function tap(label){
   for(let attempt=0;attempt<20;attempt++){
    const s=await state(),key=Object.keys(s.buttons).find(k=>k===label)||Object.keys(s.buttons).find(k=>k.startsWith(label));assert.ok(key,'Button '+label);
    const r=s.buttons[key],clip=s.button_clips[key]||[0,0,...s.viewport],center=r[1]+r[3]/2;
    if(center>clip[1]+3&&center<clip[1]+clip[3]-3){const x=(r[0]+r[2]/2)*viewport.width/s.viewport[0],y=center*viewport.height/s.viewport[1];if(mobile)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();return;}
    const down=center>clip[1]+clip[3],x=(clip[0]+20)*viewport.width/s.viewport[0],top=(clip[1]+30)*viewport.height/s.viewport[1],bottom=(clip[1]+clip[3]-30)*viewport.height/s.viewport[1];
    if(mobile){await send('touchStart',[{x,y:down?bottom:top}]);for(let n=1;n<=8;n++){await send('touchMove',[{x,y:(down?bottom:top)+(down?top-bottom:bottom-top)*n/8}]);await page.waitForTimeout(30);}await release();}
    else{await page.mouse.move(x,(top+bottom)/2);await page.mouse.wheel(0,down?160:-160);await wait();}
   }
   throw Error('Clipped button '+label);
  }
  async function hold(i){const p=await point(i);await send('touchStart',[p]);await page.waitForTimeout(450);await wait();return p;}
  async function move(p){await send('touchMove',[p]);await wait();}
  async function release(){await send('touchEnd');await wait();}
  const slots=async()=>JSON.stringify((await state()).slots);
  const items=[{item:'fibra',quantity:4},{item:'madeira',quantity:9},{item:'linha',quantity:2},{item:'pedra',quantity:4},{item:'cantil',quantity:1,water:2},{item:'pistola',quantity:1,loaded:4},{item:'espada_pedra',quantity:1}];
  await page.goto(process.env.TEST_URL||'http://localhost:8086/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:90000});await tap('Continuar');await page.waitForFunction(()=>window.tcState?.position);await command('tower_route');await command('items',{items});
  if(mobile)await tap('Inventário');else{await page.keyboard.press('i');await wait();}
  await tap('7\n');await tap('Equipar este item');
  const before=await state();
  if(mobile){
   const start=await hold(6);let s=await state();check(s.touch_inventory.phase==='dragging'&&s.dragging_inventory&&s.touch_inventory.preview_visible,'Hold produces a visible preview');
   const end=await point(0);await move(end);s=await state();check(s.touch_inventory.target===0&&s.touch_inventory.preview.length===4,'Preview follows finger and target 1 is highlighted');await page.screenshot({path:'.tools/screenshots/touch-drag-preview.png'});await release();
  }else{
   const a=await point(6),b=await point(0);await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(b.x,b.y,{steps:18});await wait();check((await state()).dragging_inventory,'Mouse preview still starts normally');await page.mouse.up();await wait();
  }
  let s=await state();check(s.slots[0].item==='espada_pedra'&&s.slots[6].item==='fibra'&&s.selected===0,'Sword 7 to occupied 1 swaps whole stacks and equipped selection');
  check(s.slots[4].water===2&&s.slots[5].loaded===4&&s.slots[5].uid===before.slots[5].uid,'Water, magazine and weapon identity are conserved');
  const saved=await slots();
  if(mobile){
   await hold(0);await move({x:4,y:viewport.height-4});await release();check(await slots()===saved,'Outside drop cancels with no discard');
   await hold(0);await move(await point(1));await send('touchCancel');await wait();check(await slots()===saved,'Interrupted touch cancels');
   await hold(0);await page.evaluate(()=>window.dispatchEvent(new Event('blur')));await wait();await move(await point(1));await release();check(await slots()===saved&&!(await state()).dragging_inventory,'Window focus loss cancels before release');
   await hold(0);await page.setViewportSize({width:900,height:393});await wait();await release();check(await slots()===saved&&!(await state()).dragging_inventory,'Viewport/orientation change cancels the gesture');await page.setViewportSize(viewport);await wait();
   await page.locator('#canvas').focus();await hold(0);await page.keyboard.press('Escape');await wait();await release();check(await slots()===saved&&(await state()).panel==='','Closing inventory cancels');await tap('Inventário');
   const p=await point(0);await send('touchStart',[p]);await page.waitForTimeout(60);await send('touchMove',[{x:p.x,y:p.y-45}]);await wait();await page.waitForTimeout(450);s=await state();check(!s.dragging_inventory&&s.touch_inventory.phase==='scrolling'&&s.inventory_scroll_value>0,'Swipe before hold scrolls without starting a drag');await release();check(await slots()===saved,'Scroll preserves slot order');
   // Reverse swipe to return to the first row, using the same touch bridge.
   const clip=(await state()).inventory_scroll;const x=(clip[0]+20)*viewport.width/s.viewport[0],y=(clip[1]+35)*viewport.height/s.viewport[1];await send('touchStart',[{x,y}]);for(let n=1;n<=8;n++){await send('touchMove',[{x,y:y+n*14}]);await page.waitForTimeout(30);}await release();
   await command('items',{items:[{item:'espada_pedra',quantity:1}]});await hold(0);await move(await point(1));await release();s=await state();check(Object.keys(s.slots[0]).length===0&&s.slots[1].item==='espada_pedra','Empty slot receives the complete stack');
   await command('items',{items});await tap('7\n');await tap('Equipar este item');await tap('Mover / trocar');await tap('1\n');s=await state();check(s.slots[0].item==='espada_pedra'&&s.slots[6].item==='fibra','Mover / trocar remains available');
  }else{
   const a=await point(0);await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(3,viewport.height-3,{steps:12});await page.keyboard.press('q');await page.mouse.up();await wait();check(await slots()===saved,'Mouse invalid drop plus Q still cancels without discard');
  }
  s=await state();check(s.move.every(v=>v===0)&&s.aim.every(v=>v===0)&&!s.mouse_held,'Gestures do not generate player movement or attack');
  await tap('Fechar');check((await state()).quick_details[0].item==='espada_pedra','Quickbar reflects inventory order');
  await command('campaign_checkpoint_write');await page.waitForFunction(()=>window.tcState?.checkpoint_checks?.ok&&!tcState.checkpoint_checks.busy);await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:90000});await tap('Continuar');await page.waitForFunction(()=>window.tcState?.position);await command('campaign_checkpoint_read');await page.waitForFunction(()=>window.tcState?.checkpoint_checks?.ok&&!tcState.checkpoint_checks.busy);s=await state();check(s.slots[0].item==='espada_pedra'&&s.selected===0,'Durable reopen preserves reordered slots and equipped identity');
  await page.screenshot({path:'.tools/screenshots/inventory-'+(mobile?'touch':'mouse')+'-reopened.png'});await context.close();
 }
 assert.equal(errors.length,0);
}finally{await browser.close();await writeFile('.tools/inventory-browser-results.json',JSON.stringify({physical:false,fixture:true,notExploratoryCampaign:true,results,errors},null,2)+'\n');}

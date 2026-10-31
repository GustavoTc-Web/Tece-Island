// Prepared technical fixture only. This is not the exploratory campaign.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile,mkdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
const results=[],evidence=[];let browser;
await mkdir('.tools/screenshots',{recursive:true});
try{
 browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
 for(const mobile of (process.env.MOBILE_ONLY?[true]:[false,true])){
  const viewport=mobile?{width:852,height:393}:{width:1280,height:720};
  const context=await browser.newContext({viewport,hasTouch:mobile,deviceScaleFactor:mobile?2:1}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'&&/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text());});
  const cdp=await context.newCDPSession(page),state=()=>page.evaluate(()=>tcState),wait=()=>page.waitForTimeout(180);
  const check=(ok,name)=>{results.push({mobile,name,ok:!!ok});console.log((ok?'PASS: ':'FAIL: ')+(mobile?'touch: ':'mouse: ')+name);assert.ok(ok,name);};
  const command=async(action,data={})=>{await page.evaluate(r=>tcFixture(JSON.stringify(r)),{action,...data});await wait();};
  const persist=async()=>{await command('campaign_checkpoint_write');await page.waitForFunction(()=>tcState.checkpoint_checks?.ok&&!tcState.checkpoint_checks.busy);};
  const restore=async()=>{await command('campaign_checkpoint_read');await page.waitForFunction(()=>tcState.checkpoint_checks?.ok&&!tcState.checkpoint_checks.busy);};
  async function clickRect(r){const s=await state(),x=(r[0]+r[2]/2)*viewport.width/s.viewport[0],y=(r[1]+r[3]/2)*viewport.height/s.viewport[1];if(mobile)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
  async function tap(label){for(let attempt=0;attempt<20;attempt++){const s=await state(),key=Object.keys(s.buttons).find(k=>k===label)||Object.keys(s.buttons).find(k=>k.startsWith(label));assert.ok(key,'Button '+label);const r=s.buttons[key],c=s.button_clips[key]||[0,0,...s.viewport],center=r[1]+r[3]/2;if(center>c[1]+3&&center<c[1]+c[3]-3){await clickRect(r);return;}const down=center>c[1]+c[3],x=(c[0]+Math.min(120,c[2]/4))*viewport.width/s.viewport[0],top=(c[1]+40)*viewport.height/s.viewport[1],bottom=(c[1]+c[3]-30)*viewport.height/s.viewport[1];if(mobile){await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:8,x,y:down?bottom:top}]});for(let n=1;n<=8;n++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:8,x,y:(down?bottom:top)+(down?top-bottom:bottom-top)*n/8}]});await page.waitForTimeout(35);}await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}else{await page.mouse.move(x,(top+bottom)/2);await page.mouse.wheel(0,down?160:-160);}await wait();}await page.screenshot({path:'.tools/screenshots/mobile-scroll-failure.png'});await writeFile('.tools/mobile-scroll-failure.json',JSON.stringify(await state(),null,2));throw Error('Clipped button '+label);}
  async function interact(){if(mobile)await tap('Interagir');else{await page.keyboard.down('e');await page.waitForTimeout(100);await page.keyboard.up('e');await wait();}}
  async function openInventory(){if(mobile)await tap('Inventário');else{await page.keyboard.press('i');await wait();}}
  async function walk(x,y){
   for(let n=0;n<65;n++){
    const s=await state(),dx=x-s.position[0],dy=y-s.position[1];if(Math.hypot(dx,dy)<13)return;
    const axis=Math.abs(dx)>Math.abs(dy)?0:1,value=axis?dy:dx,ms=Math.max(40,Math.min(180,Math.abs(value)/180*1000));
    if(mobile){const p=s.sticks.move,a={id:1,x:p[0]*viewport.width/s.viewport[0],y:p[1]*viewport.height/s.viewport[1]},b={...a,x:a.x+(axis?0:Math.sign(value)*40)*viewport.width/s.viewport[0],y:a.y+(axis?Math.sign(value)*40:0)*viewport.height/s.viewport[1]};await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[a]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[b]});await page.waitForTimeout(ms);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
    else{const key=axis?(value<0?'w':'s'):(value<0?'a':'d');await page.keyboard.down(key);await page.waitForTimeout(ms);await page.keyboard.up(key);}
    await page.waitForTimeout(120);
   }
   throw Error('Walking path blocked at '+JSON.stringify((await state()).position)+' target '+x+','+y);
  }
  async function shot(name){const s=await state();check(s.player_screen[0]>25&&s.player_screen[0]<s.viewport[0]-25&&s.player_screen[1]>30&&s.player_screen[1]<s.viewport[1]-30,name+' camera contains actor');const path='.tools/screenshots/after-'+name+'-'+(mobile?'mobile':'pc')+'.png';await page.screenshot({path});evidence.push({mobile,name,path,position:s.position,screen:s.player_screen,viewport:s.viewport,drops:s.nearby_drops,prompt:s.interaction_text});}
  await page.goto('http://localhost:8084/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Continuar');await page.waitForFunction(()=>window.tcState?.position);await command('tower_route');await command('campaign_clock',{day:1,night:false});
  await command('items',{items:[{item:'fibra',quantity:4},{item:'madeira',quantity:9},{item:'linha',quantity:2},{item:'pedra',quantity:4},{item:'cantil',quantity:1,water:2},{item:'pistola',quantity:1,loaded:4},{item:'espada_pedra',quantity:1}]});
  await openInventory();await tap('7\n');await tap('Equipar este item');
  if(mobile){await tap('Mover / trocar');await tap('1\n');}
  else{
   const s=await state(),r=s.inventory_buttons,point=i=>({x:(r[i][0]+r[i][2]/2)*viewport.width/s.viewport[0],y:(r[i][1]+r[i][3]/2)*viewport.height/s.viewport[1]});
   const a=point(6),b=point(0);await page.mouse.move(a.x,a.y);await page.mouse.down();await page.mouse.move(b.x,b.y,{steps:16});await wait();check((await state()).dragging_inventory,'Mouse drag is active with visible preview');await page.screenshot({path:'.tools/screenshots/inventory-drag-preview-pc.png'});await page.mouse.up();await wait();
  }
  let s=await state();await page.screenshot({path:'.tools/screenshots/inventory-swap-'+(mobile?'mobile':'pc')+'.png'});check(s.slots[0].item==='espada_pedra'&&s.slots[6].item==='fibra'&&s.selected===0,'Slot 7 to 1 swaps whole stacks and equipped reference');
  if(!mobile){const before=JSON.stringify(s.slots),r=s.inventory_buttons[0];await page.mouse.move((r[0]+r[2]/2)*viewport.width/s.viewport[0],(r[1]+r[3]/2)*viewport.height/s.viewport[1]);await page.mouse.down();await page.mouse.move(8,viewport.height-8,{steps:12});await page.keyboard.press('q');await page.mouse.up();await wait();check(JSON.stringify((await state()).slots)===before&&!(await state()).mouse_held,'Invalid drop and discard key cancel without loss or attack');}
  await tap('Fechar');s=await state();check(s.quick_details[0].item==='espada_pedra','Quickbar immediately reflects swapped order');await persist();await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Continuar');await page.waitForFunction(()=>window.tcState?.position);await restore();check((await state()).slots[0].item==='espada_pedra'&&(await state()).selected===0,'Browser reopen retains sorted slots and equipment');await command('tower_route');await command('items',{items:[]});
  // Only scenario setup teleports to outside the house; all interior paths use controls.
  await command('position',{x:550,y:1390});await walk(550,1320);await walk(465,1320);await walk(465,1190);await shot('house-upper-left');await walk(635,1190);await shot('house-upper-right');await walk(635,1320);await shot('house-lower-right');await walk(550,1320);await walk(550,1390);check((await state()).position[1]>1350,'House entrance and exit keep physical geometry');
  const [tx,ty]=(await state()).temples[0];await command('position',{x:tx+35,y:ty+300});await walk(tx+35,ty+35);await walk(tx+35,ty-35);await walk(tx-90,ty-35);await walk(tx-210,ty-90);await interact();await wait();check((await state()).nearby_drops.length>0,'Opening upper temple chest releases visible nearby ground items');await shot('temple-upper-left-drops');await interact();check((await state()).slots.some(x=>x.quantity>0),'Normal E or mobile Interagir collects the released item');
  await walk(tx-280,ty-180);await shot('temple-upper-left');await walk(tx-90,ty-35);await walk(tx+90,ty-35);await walk(tx+280,ty-180);await shot('temple-upper-right');await walk(tx+90,ty-35);await walk(tx+35,ty-35);await walk(tx+35,ty+35);await walk(tx+280,ty+180);await shot('temple-lower-right');await walk(tx+90,ty+35);await walk(tx-90,ty+35);await walk(tx-210,ty+150);await interact();await shot('temple-lower-left-drops');await interact();await walk(tx-280,ty+180);await shot('temple-lower-left');await persist();const saved=await state();await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Continuar');await page.waitForFunction(()=>window.tcState?.position);await restore();check(Math.hypot((await state()).position[0]-saved.position[0],(await state()).position[1]-saved.position[1])<15,'Reopen inside lower temple retains position and campaign');await shot('temple-reopened');
  check(errors.length===0,'No engine/browser script errors');await context.close();
 }
}finally{if(browser)await browser.close();await writeFile('.tools/rc2-browser-results.json',JSON.stringify({technical:true,notExploratoryCampaign:true,results,evidence},null,2));}

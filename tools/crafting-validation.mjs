import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try{
 for(const touch of [false,true]){
  const context=await browser.newContext({viewport:{width:960,height:540},deviceScaleFactor:touch?2:1,hasTouch:touch}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.goto('http://localhost:8081/Tece-Island/');
  await page.waitForFunction(()=>window.tcState?.menu&&document.querySelector('#status').style.display==='none',null,{timeout:60000});
  const state=()=>page.evaluate(()=>window.tcState),wait=()=>page.waitForTimeout(180);
  const check=(value,label)=>{results.push({touch,label,pass:!!value});console.log((value?'PASS: ':'FAIL: ')+(touch?'Toque: ':'Mouse: ')+label);};
  async function box(rect){const s=await state(),x=(rect[0]+rect[2]/2)*960/(s.viewport?.[0]||960),y=(rect[1]+rect[3]/2)*540/(s.viewport?.[1]||540);if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
  const tap=async text=>{for(let n=0;n<15;n++){const s=await state(),r=s.buttons[text];if(!r)throw Error('Missing '+text);const c=s.button_clips[text]||[0,0,960,540],center=r[1]+r[3]/2;if(center>c[1]+5&&center<c[1]+c[3]-5){await box(r);return;}const down=center>c[1]+c[3],x=(c[0]+Math.min(100,c[2]/4))*960/s.viewport[0],a=(c[1]+40)*540/s.viewport[1],b=(c[1]+c[3]-25)*540/s.viewport[1];if(touch){const session=await context.newCDPSession(page);await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:8,x,y:down?b:a}]});for(let i=1;i<=8;i++){await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:8,x,y:(down?b:a)+(down?a-b:b-a)*i/8}]});await page.waitForTimeout(35);}await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await session.detach();}else{await page.mouse.move(x,(a+b)/2);await page.mouse.wheel(0,down?180:-180);}await wait();}throw Error('Clipped '+text);};
  const setup=async(action,extra={})=>{await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,...extra});await wait();};
  await tap('Continuar');await page.waitForFunction(()=>window.tcState.position);
  await setup('items',{items:[{item:'madeira',quantity:15},{item:'fibra',quantity:12},{item:'carne_crua',quantity:2}]});
  if(touch){await tap('Inventário');await tap('Fabricação');}else{await page.keyboard.press('c');await wait();}
  let s=await state();check(!!s.recipes.cantil&&!s.recipes.carne_cozida,'Recursos sem receitas cozidas');
  await box(s.recipes.cantil);s=await state();check(s.slots.some(slot=>slot.item==='cantil'),'Fabricação por botão entrega cantil');
  await tap('Ferramentas');s=await state();check(!!s.recipes.picareta_madeira&&!s.recipes.cantil,'Categoria Ferramentas');
  await box(s.search);await page.keyboard.type('picareta');await wait();s=await state();
  check(!!s.recipes.picareta_madeira&&!s.recipes.machado_madeira,'Busca digitada funciona');
  await page.keyboard.press('Control+a');await page.keyboard.press('Backspace');await wait();
  s=await state();check(!s.buttons.Alimentos&&!!s.buttons.Armaduras,'Alimentos removidos da fabricação geral');
  await page.screenshot({path:'.tools/screenshots/crafting-empty-'+(touch?'touch':'desktop')+'.png'});
  await tap('Fechar');await page.waitForFunction(()=>window.tcState.panel==='');await setup('fire');await page.waitForFunction(()=>window.tcState.panel==='cooking',null,{timeout:5000}).catch(async e=>{console.log(JSON.stringify({errors,state:await state()}));throw e;});s=await state();
  check(s.panel==='cooking'&&!!s.recipes.carne_cozida&&!s.recipes.cantil,'Fogueira com interface exclusiva');
  await box(s.recipes.carne_cozida);s=await state();
  check(s.slots.some(slot=>slot.item==='carne_cozida')&&s.slots.filter(slot=>slot.item==='carne_crua').reduce((n,v)=>n+v.quantity,0)===1,'Cozinha consome uma unidade');
  await page.screenshot({path:'.tools/screenshots/crafting-fire-'+(touch?'touch':'desktop')+'.png'});
  await tap('Fechar');s=await state();check(!s.paused,'Fechar restaura jogo');
  const cdp=await context.newCDPSession(page);
  if(touch){
   const start=s.position;
   const move={id:0,x:s.sticks.move[0]*960/s.viewport[0],y:s.sticks.move[1]*540/s.viewport[1]},aim={id:1,x:s.sticks.aim[0]*960/s.viewport[0],y:s.sticks.aim[1]*540/s.viewport[1]};
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[move,aim]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...move,x:move.x-45},{...aim,y:aim.y-45}]});await page.waitForTimeout(400);
   s=await state();check(s.position[0]<start[0]-30&&s.aim[1]<0,'Multitouch com canvas em densidade 2');
   await page.evaluate(()=>window.dispatchEvent(new Event('blur')));await wait();s=await state();check(s.move.every(v=>v===0)&&s.aim.every(v=>v===0),'Perda de foco libera controles');
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  }
  check(!errors.length,'Sem erros do engine/navegador');await context.close();
 }
}finally{await browser.close();}
await writeFile('.tools/crafting-results.json',JSON.stringify(results,null,2));if(results.some(r=>!r.pass))process.exitCode=1;

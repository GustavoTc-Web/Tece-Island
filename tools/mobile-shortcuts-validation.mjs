import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
// Offline gameplay export in .tools only. Production keeps mandatory Firebase login.
const results=[],errors=[];
const browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
await mkdir('.tools/screenshots',{recursive:true});
try{
 for(const dimensions of [{width:852,height:393,touch:true},{width:640,height:360,touch:true},{width:1280,height:720,touch:false}]){
  const {width,height,touch}=dimensions;
  const context=await browser.newContext({viewport:{width,height},hasTouch:touch,isMobile:touch,deviceScaleFactor:touch?2:1});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const state=()=>page.evaluate(()=>tcState),wait=()=>page.waitForTimeout(220);
  const check=(ok,name)=>{results.push({dimensions,name,ok:!!ok});console.log((ok?'PASS: ':'FAIL: ')+width+'×'+height+' '+name);if(!ok)throw Error(name);};
  const fixture=async(action,data={})=>{await page.evaluate(r=>tcFixture(JSON.stringify(r)),{action,...data});await wait();};
  const point=async(x,y)=>{const s=await state();if(touch)await page.touchscreen.tap(x*width/s.viewport[0],y*height/s.viewport[1]);else await page.mouse.click(x*width/s.viewport[0],y*height/s.viewport[1]);await wait();};
  async function tap(name){
   for(let i=0;i<14;i++){
    const s=await state(),key=Object.keys(s.buttons).find(k=>k===name)||Object.keys(s.buttons).find(k=>k.startsWith(name));
    if(!key)throw Error('Ausente: '+name);
    const r=s.buttons[key],clip=s.button_clips[key]||[0,0,...s.viewport];
    if(r[1]>=clip[1]&&r[1]+r[3]<=clip[1]+clip[3]){await point(r[0]+r[2]/2,r[1]+r[3]/2);return;}
    const x=(clip[0]+clip[2]/2)*width/s.viewport[0],top=(clip[1]+12)*height/s.viewport[1],bottom=(clip[1]+clip[3]-12)*height/s.viewport[1];
    if(touch){const cdp=await context.newCDPSession(page);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:9,x,y:bottom}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:9,x,y:top}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();}
    else{await page.mouse.move(x,(top+bottom)/2);await page.mouse.wheel(0,180);}await wait();
   }throw Error('Fora da área: '+name);
  }
  function overlaps(a,b){return a[0]<b[0]+b[2]&&a[0]+a[2]>b[0]&&a[1]<b[1]+b[3]&&a[1]+a[3]>b[1];}
  async function craft(id){
   for(let i=0;i<12;i++){
    const s=await state(),r=s.recipes[id],area=s.crafting_scroll;
    if(r[1]>=area[1]&&r[1]+r[3]<=area[1]+area[3]){await point(r[0]+r[2]/2,r[1]+r[3]/2);return;}
    const delta=Math.max(-area[3]*.6,Math.min(area[3]*.6,r[1]+r[3]/2-area[1]-area[3]/2));
    const x=(area[0]+area[2]/2)*width/s.viewport[0],start=(delta>0?area[1]+area[3]-12:area[1]+12)*height/s.viewport[1],end=start-delta*height/s.viewport[1];
    if(touch){const cdp=await context.newCDPSession(page);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:9,x,y:start}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:9,x,y:end}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();}
    else{await page.mouse.move(x,(area[1]+area[3]/2)*height/s.viewport[1]);await page.mouse.wheel(0,delta*height/s.viewport[1]);}await wait();
   }throw Error('Receita fora da área: '+id);
  }
  function clearLayout(s){
   const shortcuts=s.action_shortcuts.map(x=>x.rect);
   const other=[...s.quick,...Object.values(s.sticks).map(c=>[c[0]-s.stick_radius*1.1,c[1]-s.stick_radius*1.1,s.stick_radius*2.2,s.stick_radius*2.2])];
   return shortcuts.every((r,i)=>r[0]>=0&&r[1]>=0&&r[0]+r[2]<=s.viewport[0]&&r[1]+r[3]<=s.viewport[1]&&other.every(b=>!overlaps(r,b))&&shortcuts.slice(i+1).every(b=>!overlaps(r,b)));
  }
  try{
   await page.goto(process.env.TEST_URL||'http://localhost:8081/Tece-Island/');
   await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Continuar');
   await page.waitForFunction(()=>window.tcState?.position,null,{timeout:30000});await wait();
   await fixture('clear_drops');await fixture('position',{x:1152,y:768});
   await fixture('items',{items:[{item:'madeira',quantity:12},{item:'pedra',quantity:10},{item:'fibra',quantity:10}]});
   if(touch){
    let s=await state();
    check(s.action_shortcuts.map(x=>x.caption).join('|')==='Interagir|Inventário|Fabricar'&&s.action_shortcuts.every(x=>/assets\/ui\/.+\.svg$/.test(x.icon)),'Três atalhos têm desenhos gráficos e legendas visíveis');
    check(s.action_shortcuts.every(x=>x.rect[2]*width/s.viewport[0]>=44&&x.rect[3]*height/s.viewport[1]>=43.9),'Alvos de toque respeitam aproximadamente 44px CSS');
    check(clearLayout(s),'Grupo cabe entre os joysticks e acima dos cinco espaços');
    await page.screenshot({path:'.tools/screenshots/mobile-shortcuts-'+width+'.png'});
    const cdp=await context.newCDPSession(page),positions=Object.entries(s.sticks).map(([key,c],i)=>({id:i+1,x:(c[0]+40)*width/s.viewport[0],y:c[1]*height/s.viewport[1]}));
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:positions});await wait();
    check((await state()).move[0]>0&&(await state()).aim[0]>0,'Movimento e ataque seguem independentes com dois dedos');
    s=await state();const r=s.buttons.Fabricar;
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[...positions,{id:3,x:(r[0]+r[2]/2)*width/s.viewport[0],y:(r[1]+r[3]/2)*height/s.viewport[1]}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:positions});await wait();
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
   }else{await page.keyboard.press('c');await wait();}
   let s=await state();
   check(s.panel==='crafting'&&s.paused&&s.open_item_panels.crafting&&!s.open_item_panels.inventory,'Fabricação abre diretamente e mostra somente seu painel');
   check(s.move.every(x=>x===0)&&s.aim.every(x=>x===0),'Abrir fabricação libera movimento e ataque mantidos');
   const stopped=s.position,inventoryBefore=JSON.stringify(s.slots);
   await point(s.player_screen[0],s.player_screen[1]);await wait();
   s=await state();check(JSON.stringify(s.position)===JSON.stringify(stopped)&&JSON.stringify(s.slots)===inventoryBefore&&!s.mouse_held,'Toque no painel não move, coleta ou ataca o mundo');
   await tap('Ferramentas');s=await state();
   check(s.recipes.machado_madeira&&/Madeira: 12\/3/.test(s.recipe_descriptions.machado_madeira),'Categoria exibe receita e ingredientes existentes');
   await craft('machado_madeira');
   s=await state();check(s.slots.some(x=>x.item==='machado_madeira')&&s.slots.filter(x=>x.item==='madeira').reduce((n,x)=>n+x.quantity,0)===9,'Fabricar produz ferramenta e consome três madeiras');
   await page.screenshot({path:'.tools/screenshots/mobile-shortcuts-crafting-'+width+'.png'});
   await tap('Fechar');s=await state();check(!s.paused&&s.panel===''&&s.move.every(x=>x===0)&&s.aim.every(x=>x===0),'Fechar retorna à partida sem comandos presos');
   if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}
   s=await state();check(s.panel==='inventory'&&s.open_item_panels.inventory&&!s.open_item_panels.crafting,'Inventário abre sozinho');
   await tap('Fabricação');s=await state();check(s.panel==='crafting'&&!s.open_item_panels.inventory,'Alternar do inventário oculta o painel anterior');await tap('Fechar');
   if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}await tap('Fechar');check(!(await state()).paused,'Inventário fecha e libera a partida');
   await fixture('position',{x:1152,y:768});await fixture('drop_probe');s=await state();
   if(touch){check(s.action_shortcuts[0].caption==='Coletar','Mão usa legenda Coletar diante de itens');await tap('Coletar');}else{await page.keyboard.press('e');await wait();}
   check((await state()).slots.filter(x=>x.item==='madeira').reduce((n,x)=>n+x.quantity,0)===14,'Coleta pelo comando existente conserva quantidade');
   await fixture('clear_drops');await fixture('chest',{open:false});
   if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
   check((await state()).panel==='chest'&&(await state()).paused,'Interagir abre o baú contextual existente');await tap('Fechar');
   await fixture('items',{items:[{item:'pistola',quantity:1,loaded:8},{item:'municao_pistola',quantity:8},{item:'carne_cozida',quantity:2}]});
   if(touch){
    s=await state();const extra=s.buttons.Recarregar;
    check(clearLayout(s)&&s.action_shortcuts.every(x=>!overlaps(x.rect,extra)),'Recarregar ocupa linha separada sem sobrepor atalhos');
    const cdp=await context.newCDPSession(page),p=s.sticks.aim;
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:2,x:(p[0]+40)*width/s.viewport[0],y:p[1]*height/s.viewport[1]}]});await page.waitForTimeout(180);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait();await cdp.detach();
    const ammo=(await state()).slots[0].loaded;check(ammo<8,'Combate continua disparando pelo joystick');
    await page.waitForTimeout(650);check((await state()).slots[0].loaded===ammo,'Soltar joystick não mantém disparos');
    const q=(await state()).quick[2];await point(q[0]+q[2]/2,q[1]+q[3]/2);s=await state();
    check(s.selected===2&&clearLayout(s)&&s.buttons.Comer&&s.action_shortcuts.every(x=>!overlaps(x.rect,s.buttons.Comer)),'Seleção por toque e Comer cabem com os três atalhos');
    await tap('Comer');check((await state()).slots[2].quantity===1,'Comer segue consumindo uma unidade por toque');
    await page.screenshot({path:'.tools/screenshots/mobile-shortcuts-context-'+width+'.png'});
   }else{
    await page.keyboard.press('c');await wait();check((await state()).panel==='crafting','Atalho C do computador continua abrindo fabricação');
    await page.keyboard.press('i');await wait();check((await state()).panel==='inventory'&&!(await state()).open_item_panels.crafting,'Atalho I alterna painel sem sobreposição');await page.keyboard.press('Escape');await wait();
   }
   check(errors.length===0,'Sem erros de execução ou recursos');
  }catch(error){await page.screenshot({path:'.tools/screenshots/mobile-shortcuts-failure-'+width+'.png'});console.log(JSON.stringify(await state()));throw error;}finally{await context.close();}
 }
}finally{await browser.close();await writeFile('.tools/mobile-shortcuts-results.json',JSON.stringify({mobile:'Toque emulado; fixture offline isolada',results,errors},null,2));}

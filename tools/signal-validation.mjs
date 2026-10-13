import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try {for(const touch of [false,true]){
 const size=touch?{width:852,height:393}:{width:960,height:540};
 const context=await browser.newContext({viewport:size,hasTouch:touch,deviceScaleFactor:touch?3:1}),page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.tcState),wait=()=>page.waitForTimeout(350);
 const cdp=await context.newCDPSession(page);
 async function scroll(down){
  if(touch){const x=size.width/2,y=down?size.height*0.76:size.height*0.35;await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:17,x,y}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:17,x,y:down?size.height*0.34:size.height*0.76}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
  else{await page.mouse.move(size.width/2,size.height*0.6);await page.mouse.wheel(0,down?800:-800);}
  await wait();
 }
 async function box(r){const s=await state(),x=(r[0]+r[2]/2)*size.width/(s.viewport?.[0]||960),y=(r[1]+r[3]/2)*size.height/(s.viewport?.[1]||540);if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);await wait();}
 async function tap(text){const s=await state(),key=Object.keys(s.buttons).find(k=>k===text)||Object.keys(s.buttons).find(k=>k.startsWith(text));if(!key)throw Error('Botão ausente: '+text);await box(s.buttons[key]);}
 async function setup(action,data={}){await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,...data});await wait();}
 const check=(value,label)=>{results.push({touch,label,pass:!!value});console.log((value?'PASS: ':'FAIL: ')+(touch?'Toque: ':'PC: ')+label);};
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);await wait();
 await tap('Som');check((await state()).panel==='sound'&&(await state()).paused,'Som abre painel e bloqueia gameplay');
 await tap('Silenciar');check((await state()).sound.muted,'Silenciar pela interface');
 const slider=(await state()).volume_slider;await box([slider[0],slider[1],slider[2]*0.4,slider[3]]);check((await state()).sound.volume<0.5,'Volume pelo controle visual');
 await tap('Fechar');check(!(await state()).paused,'Fechar restaura controles');
 await setup('record',{id:'arrival'});
 if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
 check((await state()).journal.discovered.includes('arrival'),'Coleta registro pela interação existente');
 check((await state()).objectives.values.record===1,'Registro progride objetivo');
 if(touch)await tap('Diário');else{await page.keyboard.press('j');await wait();}
 check((await state()).panel==='journal','Diário por botão/atalho');
 await tap('1ª descoberta');check((await state()).journal_text.includes('Lia')&&Object.keys((await state()).journal.unread).length===0,'Leitura marca página como lida');
 await page.screenshot({path:'.tools/screenshots/signal-journal-'+(touch?'touch':'desktop')+'.png'});
 await tap('Objetivos');await scroll(true);await tap('Explorar um templo');check((await state()).objectives.tracked==='temple','Selecionar objetivo para acompanhar');await scroll(false);
 await tap('Mostrar objetivo na HUD');check(!(await state()).objectives.enabled,'Desativar orientação pela interface');
 await tap('Fechar');
 await setup('position',{x:1152,y:768});await setup('items',{items:[{item:'madeira',quantity:14}]});await setup('chest');
 const originalId=(await state()).structures.find(s=>s.kind==='bau').id;
 await box((await state()).chest_name_input);await page.keyboard.press('Control+a');await page.keyboard.type('Provisions');await tap('Renomear');
 check((await state()).structures.some(s=>s.id===originalId&&s.chest_name==='Provisions'),'Nome muda sem trocar ID');
 await box((await state()).storage_buttons[0]);
 if(touch)await tap('Guardar pilha');else{await page.keyboard.press('t');await wait();}
 check((await state()).storage_slots[0]?.quantity===14&&(await state()).slots[0]?.item===undefined,'Pilha por T/botão sem duplicação');
 await tap('Desmontar baú');check((await state()).panel==='base'&&!(await state()).base_confirm_enabled&&(await state()).base_status.includes('Baú cheio'),'Desmontagem bloqueia baú ocupado');
 await tap('Cancelar / Fechar');if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}
 await tap('Baú');await setup('items',{items:[{item:'madeira',quantity:13},...Array.from({length:6},()=>({item:'cama',quantity:1}))]});await box((await state()).storage_buttons[0]);await tap('Retirar pilha');
 check((await state()).slots[0].quantity===15&&(await state()).storage_slots[0].quantity===12,'Transferência parcial preserva restante');
 await setup('items',{items:[]});await tap('Retirar pilha');await tap('Desmontar baú');check((await state()).base_confirm_enabled,'Baú vazio exige confirmação explícita');
 await page.screenshot({path:'.tools/screenshots/signal-base-'+(touch?'touch':'desktop')+'.png'});
 await tap('Confirmar desmontagem');check(!(await state()).structures.some(s=>s.id===originalId),'Confirmar remove a peça selecionada');
 await tap('Cancelar / Fechar');
 await setup('items',{items:[]});await setup('combat_probe');
 if(touch){const s=await state(),x=(s.viewport[0]-100)*size.width/s.viewport[0],y=(s.viewport[1]-115)*size.height/s.viewport[1];await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:23,x,y}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:23,x:x+35,y}]});await page.waitForTimeout(120);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await wait();}
 else{const s=await state();await box([s.combat_enemy.screen[0]-2,s.combat_enemy.screen[1]-2,4,4]);}
 check((await state()).combat_enemy.health===25&&(await state()).combat_enemy.bar>0,'Ataque real mantém dano e mostra vida em combate');
 check((await state()).poison>0&&(await state()).poison<3&&(await state()).poison_text.startsWith('Veneno'),'Veneno com duração restante legível na HUD');
 await page.screenshot({path:'.tools/screenshots/signal-combat-'+(touch?'touch':'desktop')+'.png'});
 await page.waitForTimeout(4500);check((await state()).combat_enemy.bar===0,'Vida inimiga desaparece fora de combate');
 const seed=String(Date.now())+(touch?'t':'p');await setup('account_probe',{seed,phase:'write'});await page.waitForFunction(()=>window.tcState?.account_checks.busy===false,null,{timeout:30000});
 const probe=(await state()).account_checks;check(probe.written&&probe.isolated,'Serviço GDScript grava e isola UIDs de fixture em IndexedDB real');check(probe.imported&&probe.second_import_blocked&&probe.legacy_preserved,'Importação Web é única e preserva original');
 await page.waitForTimeout(3500);check((await state()).save_status==='Progresso salvo.','Indicador confirma gravação concluída');
 await page.screenshot({path:'.tools/screenshots/signal-hud-'+(touch?'touch':'desktop')+'.png'});
 await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);await wait();
 check((await state()).journal.discovered.includes('arrival')&&(await state()).objectives.tracked==='temple'&&!(await state()).objectives.enabled,'Reload mantém diário e preferências dos objetivos');
 await setup('account_probe',{seed,phase:'read'});await page.waitForFunction(()=>window.tcState?.account_checks.busy===false,null,{timeout:30000});check((await state()).account_checks.isolated,'Reload confirma persistência dos dois UIDs no navegador');
 check(errors.length===0,'Sem erros inesperados do navegador/engine');await context.close();
}}finally{await browser.close();}
await writeFile('.tools/signal-browser-results.json',JSON.stringify(results,null,2));
if(results.some(r=>!r.pass))process.exitCode=1;

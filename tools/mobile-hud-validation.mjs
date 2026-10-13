import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try{for(const dimensions of [{width:960,height:540,touch:false},{width:852,height:393,touch:true},{width:393,height:852,touch:true}]){
 const {width,height,touch}=dimensions;const context=await browser.newContext({viewport:{width,height},hasTouch:touch,deviceScaleFactor:touch?3:1});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.tcState);const wait=()=>page.waitForTimeout(400);const check=(ok,name)=>{results.push({dimensions,name,ok:!!ok});console.log((ok?'PASS: ':'FAIL: ')+name);};
 async function setup(action,data={}){await page.evaluate(r=>window.tcFixture(JSON.stringify(r)),{action,...data});await wait();}
 async function scroll(down=true){if(touch){const c=await context.newCDPSession(page);await c.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:9,x:width/2,y:height*(down?.8:.3)}]});await c.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:9,x:width/2,y:height*(down?.3:.8)}]});await c.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}else{await page.mouse.move(width/2,height/2);await page.mouse.wheel(0,down?350:-350);}await wait();}
 async function point(x,y){const s=await state();const v=s.viewport||[960,540];if(touch)await page.touchscreen.tap(x*width/v[0],y*height/v[1]);else await page.mouse.click(x*width/v[0],y*height/v[1]);await wait();}
 async function tap(name){for(let i=0;i<12;i++){const s=await state();const key=Object.keys(s.buttons).find(k=>k===name)||Object.keys(s.buttons).find(k=>k.startsWith(name));if(!key)throw Error('Ausente: '+name);const r=s.buttons[key],v=s.viewport||[960,540];if(r[1]>=0&&r[1]+r[3]<=v[1]){await point(r[0]+r[2]/2,r[1]+r[3]/2);return;}await scroll(r[1]>=0);}throw Error('Fora da tela: '+name);}
 async function craft(id){for(let i=0;i<12;i++){const s=await state(),r=s.recipes[id],area=s.crafting_scroll;if(r[1]>=area[1]&&r[1]+r[3]<=area[1]+area[3]){await point(r[0]+r[2]/2,r[1]+r[3]/2);return;}const x=(area[0]+area[2]/2)*width/s.viewport[0],top=(area[1]+10)*height/s.viewport[1],bottom=(area[1]+area[3]-10)*height/s.viewport[1];if(touch){const c=await context.newCDPSession(page);await c.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:14,x,y:bottom}]});await c.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:14,x,y:top}]});await c.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}else{await page.mouse.move(x,(top+bottom)/2);await page.mouse.wheel(0,180);}await wait();}throw Error('Receita inacessível: '+id);}
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);await wait();
 await page.evaluate(()=>window.tcFixture(JSON.stringify({action:'items',items:[{item:'machado_pedra',quantity:1},{item:'carne_cozida',quantity:3},{item:'cantil',quantity:1,water:3},{item:'cama',quantity:1},{item:'madeira',quantity:10}]})));await wait();
 const s=await state();check(!s.paused,'Partida responde na orientação '+width+'×'+height);check(!touch||s.objectives.collapsed,'Objetivo mobile recolhido');
 check(s.quick.every(r=>r[2]*width/s.viewport[0]>=43.9&&r[3]*height/s.viewport[1]>=43.9),'Cinco slots têm área equivalente a 44px CSS');
 if(touch){const cdp=await context.newCDPSession(page);const convert=(p,id,dx=0)=>({id,x:(p[0]+dx)*width/s.viewport[0],y:p[1]*height/s.viewport[1]});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[convert(s.sticks.move,1),convert(s.sticks.aim,2)]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[convert(s.sticks.move,1,40),convert(s.sticks.aim,2,40)]});await wait();const held=await state();check(held.move[0]>0&&held.aim[0]>0,'Movimento e ataque simultâneos');await page.evaluate(()=>window.dispatchEvent(new Event('blur')));await wait();check((await state()).move[0]===0&&(await state()).aim[0]===0,'Perda de foco limpa ambos os dedos');await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
 await page.screenshot({path:'.tools/screenshots/mobile-hud-'+width+'x'+height+'.png'});
 await tap('Menu');check((await state()).panel==='menu'&&(await state()).paused,'Menu bloqueia personagem e pausa solo');
 await tap('Ajuda e suporte');check((await state()).diagnostic.includes('Commit:')&&!/(token|senha|uid|@|inventory)/i.test((await state()).diagnostic),'Diagnóstico contém apenas versão/plataforma/tela');
 await page.screenshot({path:'.tools/screenshots/mobile-menu-'+width+'x'+height+'.png'});
 await tap('Voltar');await tap('Continuar');check(!(await state()).paused,'Continuar restaura solo');
 await tap(touch?'Inventário':'Menu');if(!touch){await tap('Continuar');await page.keyboard.press('i');await wait();}check((await state()).panel==='inventory','Inventário acessível');
 await page.screenshot({path:'.tools/screenshots/mobile-inventory-'+width+'x'+height+'.png'});
 await tap('2\n');await tap('Usar');check((await state()).slots[1].quantity===2,'Usar no inventário consome apenas uma comida');
 await tap('Fechar');await setup('needs',{hunger:20,thirst:20});
 const q=(await state()).quick[2];await point(q[0]+q[2]/2,q[1]+q[3]/2);
 if(touch)await tap('Usar item');else{await page.keyboard.press('i');await wait();await tap('3\n');await tap('Usar');await tap('Fechar');}
 check((await state()).slots[2].water===2,'Beber consome apenas uma dose');
 await setup('position',{x:1152,y:768});await setup('items',{items:[{item:'madeira',quantity:14},...Array.from({length:6},()=>({item:'cama',quantity:1}))]});await setup('drop_probe');
 if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}check((await state()).slots[0].quantity===15,'Coleta parcial respeita capacidade da pilha');
 if(touch)await tap('Interagir');else{await page.keyboard.press('e');await wait();}check((await state()).slots[0].quantity===15,'Inventário cheio não duplica coleta');
 await setup('clear_drops');await setup('items',{items:[{item:'madeira',quantity:15},{item:'fibra',quantity:15},{item:'pedra',quantity:15}]});
 if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}await tap('Fabricação');await tap('Ferramentas');
 await craft('machado_madeira');check((await state()).slots.some(x=>x.item==='machado_madeira'),'Fabricação acessível pelo inventário');await page.screenshot({path:'.tools/screenshots/mobile-crafting-'+width+'x'+height+'.png'});await tap('Fechar');
 await setup('items',{items:[{item:'cama',quantity:1},{item:'fogueira',quantity:1}]});
 if(touch)await tap('Inventário');else{await page.keyboard.press('i');await wait();}await tap('1\n');await tap('Colocar selecionado');
 await page.waitForFunction(()=>window.tcState?.placement_points?.length>0);const pos=(await state()).placement_points[0];
 if(touch){await point(pos[0],pos[1]);check((await state()).placing,'Toque ajusta a prévia sem consumir item');await tap('Confirmar');}
 else{await page.mouse.click(pos[0]*width/(await state()).viewport[0],pos[1]*height/(await state()).viewport[1]);await wait();}
 check(!(await state()).placing&&(await state()).structures.some(x=>x.kind==='cama'),'Construção confirma com a mesma regra de terreno');
 await setup('save_error');await page.waitForTimeout(2800);check((await state()).save_visible,'Falha de save permanece visível (estado visual de teste)');await setup('save_ok');await page.waitForTimeout(2800);check(!(await state()).save_visible,'Sucesso de save desaparece (estado visual de teste)');
 await tap('Menu');await tap('Voltar ao menu principal');check((await state()).menu&&!(await state()).paused,'Retorno a partir do menu pausado permite jogar novamente');await tap('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);check(!(await state()).paused,'Reentrada mantém controles liberados');
 check(errors.length===0,'Sem erros de execução');if(errors.length)console.log(errors);await context.close();
}}finally{await browser.close();await writeFile('.tools/mobile-hud-results.json',JSON.stringify(results,null,2));}
if(results.some(r=>!r.ok))process.exitCode=1;

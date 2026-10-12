import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[],errors=[];
try{
 for(const touch of [false,true]){
  const context=await browser.newContext({viewport:{width:960,height:540},hasTouch:touch});
  const page=await context.newPage();
  const requests=[];
  page.on('request',r=>{if(r.url().startsWith('https://identitytoolkit.googleapis.com/'))requests.push({endpoint:new URL(r.url()).pathname});});
  page.on('response',r=>{if(r.url().startsWith('https://identitytoolkit.googleapis.com/'))requests.push({status:r.status()});});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error'&&!(process.argv.includes('--live-invalid')&&m.location().url.startsWith('https://identitytoolkit.googleapis.com/')&&m.text().includes('400')))errors.push(m.text());});
  await page.goto('http://localhost:8082/Tece-Island/');
  await page.waitForFunction(()=>window.tcAuthUiState&&document.querySelector('#status').style.display==='none',null,{timeout:30000});
  const state=()=>page.evaluate(()=>window.tcAuthUiState);
  const check=(pass,label)=>{results.push({pass:!!pass,label:(touch?'Toque: ':'Desktop: ')+label});console.log((pass?'PASS: ':'FAIL: ')+results.at(-1).label);};
  async function clickBox(box){
   const s=await state(),viewport=page.viewportSize();
   const x=(box[0]+box[2]/2)*viewport.width/s.viewport[0],y=(box[1]+box[3]/2)*viewport.height/s.viewport[1];
   if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);
   await page.waitForTimeout(180);
  }
  async function scrollDown(){
   if(touch){
    const cdp=await context.newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:2,x:850,y:470}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:2,x:850,y:170}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   }else{await page.mouse.move(850,400);await page.mouse.wheel(0,550);}
   await page.waitForTimeout(250);
  }
  check((await state()).configured&&!(await state()).session,'Configuração pública carregada sem criar sessão');
  await page.screenshot({path:'.tools/screenshots/auth-'+(touch?'touch':'desktop')+'.png'});
  await clickBox((await state()).email_rect);
  await page.keyboard.type('test@example.invalid');
  await page.waitForTimeout(150);
  check((await state()).email_valid,'Campo e-mail recebe foco e texto');
  if(process.argv.includes('--live-invalid')){
   await clickBox((await state()).password_rect);
   await page.keyboard.type('invalid-credential-probe');
   await page.waitForTimeout(150);
   check((await state()).password_present,'Campo senha recebe entrada sem expor o valor');
   await clickBox((await state()).buttons['Entrar']);
   try { await page.waitForFunction(()=>window.tcAuthUiState.status==='E-mail ou senha inválidos.',null,{timeout:25000}); }
   catch(e){console.log(JSON.stringify({status:(await state()).status,requests,errors}));throw e;}
   check(!(await state()).session,'Backend real rejeita credenciais inválidas; nenhum cadastro ou e-mail enviado');
  }
  await scrollDown();await clickBox((await state()).buttons['Criar conta']);
  await page.waitForFunction(()=>window.tcAuthUiState.mode==='register');
  check((await state()).mode==='register','Cadastro abre sem teclado obrigatório');
  await scrollDown();await clickBox((await state()).buttons['Mostrar senha']);
  check(!(await state()).password_hidden&&!(await state()).confirmation_hidden,'Mostrar senha altera ambos os campos');
  await clickBox((await state()).buttons['Mostrar senha']);
  check((await state()).password_hidden&&(await state()).confirmation_hidden,'Ocultar senha altera ambos os campos');
  await scrollDown();await clickBox((await state()).buttons['Esqueci minha senha']);
  await page.waitForFunction(()=>window.tcAuthUiState.mode==='recover');
  check((await state()).mode==='recover','Recuperação acessível');
  check(!(await state()).session,'Nenhuma tela simula autenticação');
  if(touch){
   await page.setViewportSize({width:540,height:960});await page.waitForTimeout(350);
   await page.screenshot({path:'.tools/screenshots/auth-portrait.png'});
   check((await state()).viewport[1]>(await state()).viewport[0],'Formulário acompanha orientação vertical');
  }
  await context.close();
 }
 results.push({pass:errors.length===0,label:'Console sem erros'});
 await writeFile('.tools/auth-ui-results.json',JSON.stringify({results,errors},null,2));
 if(results.some(x=>!x.pass)||errors.length)process.exitCode=1;
}finally{await browser.close();}

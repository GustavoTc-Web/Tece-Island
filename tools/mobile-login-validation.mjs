import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[],errors=[];const url=process.env.TEST_URL||'http://localhost:8080/Tece-Island/';
function check(value,name){results.push({name,ok:!!value});if(!value)throw new Error(name);console.log('PASS: '+name);}
await mkdir('.tools/screenshots',{recursive:true});
try{
 for(const touch of [false,true]){
  const context=await browser.newContext({viewport:touch?{width:393,height:852}:{width:960,height:540},hasTouch:touch,isMobile:touch,permissions:['clipboard-read','clipboard-write']});
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
  await page.goto(url);await page.locator('#auth-email').waitFor({timeout:60000});
  const prefix=touch?'Toque emulado':'PC';const email=page.locator('#auth-email'),password=page.locator('#auth-password');
  const tap=async locator=>{if(touch)await locator.tap();else await locator.click();};
  await tap(email);check(await email.evaluate(e=>document.activeElement===e),prefix+': primeiro toque foca o campo');
  await email.pressSequentially('probe.test@example.invalid');
  await tap(password);await password.pressSequentially(' AAb! @.x ');
  await tap(email);check(await email.inputValue()==='probe.test@example.invalid',prefix+': trocar campo preserva e-mail');
  check(await password.inputValue()===' AAb! @.x ',prefix+': senha mantém caixa, espaços e símbolos');
  await email.evaluate(e=>e.setSelectionRange(6,10));await page.keyboard.press('Backspace');check(await email.inputValue()==='probe.@example.invalid',prefix+': seleção e exclusão');
  await page.evaluate(()=>navigator.clipboard.writeText('validation-probe@example.invalid'));await email.press('Control+A');await email.press('Control+V');check(await email.inputValue()==='validation-probe@example.invalid',prefix+': colagem real do clipboard');
  await tap(password);await password.evaluate(e=>e.setSelectionRange(4,4));await tap(page.locator('#auth-show'));
  check(await password.evaluate(e=>e.type==='text'&&e.selectionStart===4),prefix+': mostrar senha preserva cursor');
  await tap(page.locator('#auth-show'));check(await password.evaluate(e=>e.type==='password'&&e.selectionStart===4),prefix+': ocultar senha preserva cursor');
  check(await password.inputValue()===' AAb! @.x ',prefix+': alternar visibilidade não altera texto');
  await page.setViewportSize({width:852,height:393});await tap(email);await tap(email);check(await email.evaluate(e=>document.activeElement===e),prefix+': rotação e toque repetido mantêm foco');
  await page.setViewportSize({width:393,height:300});await page.locator('#auth-primary').scrollIntoViewIfNeeded();check(await page.locator('#auth-primary').evaluate(e=>{const r=e.getBoundingClientRect();return r.top>=0&&r.bottom<=innerHeight;}),prefix+': envio acessível com viewport reduzido (simulação, sem teclado físico)');
  await tap(page.locator('#auth-mode'));check(await page.locator('#auth-confirmation').isVisible(),prefix+': cadastro acessível');
  await tap(page.locator('#auth-recover'));check(!(await password.isVisible()),prefix+': recuperação acessível');
  await tap(page.locator('#auth-mode'));await password.fill('invalid-credential-probe');
  const response=page.waitForResponse(r=>r.url().startsWith('https://identitytoolkit.googleapis.com/')&&r.url().includes('signInWithPassword'),{timeout:25000});
  await tap(page.locator('#auth-primary'));const r=await response;const data=await r.json();const code=String(data.error?.message||'').split(':')[0];
  check(r.status()===400&&['INVALID_LOGIN_CREDENTIALS','EMAIL_NOT_FOUND','INVALID_PASSWORD'].includes(code),prefix+': Firebase real rejeita credenciais inválidas');
  await page.waitForFunction(()=>!document.querySelector('#auth-primary').disabled);
  check(await page.locator('#auth-message').innerText()!=='',prefix+': falha mostra mensagem e libera nova tentativa');
  await page.setViewportSize(touch?{width:393,height:852}:{width:960,height:540});await page.evaluate(()=>document.querySelector('#auth').scrollTop=0);await password.fill('');await email.fill('');
  await page.screenshot({path:'.tools/screenshots/mobile-login-'+(touch?'portrait':'desktop')+'.png'});
  await context.close();
 }
 if(errors.length)throw new Error('Erros de execução: '+errors.join(', '));
}finally{await writeFile('.tools/mobile-login-results.json',JSON.stringify({url,results,errors},null,2));await browser.close();}

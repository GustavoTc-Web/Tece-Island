import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir, writeFile} from 'node:fs/promises';
const url = process.env.TEST_URL || 'http://localhost:8086/Tece-Island/';
const results = [], errors = [];
await mkdir('.tools/screenshots', {recursive: true});
const browser = await chromium.launch({executablePath: process.env.BROWSER_EXE || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless: true, args: ['--enable-unsafe-swiftshader']});
const check = (ok, label) => { results.push({pass: !!ok, label}); console.log(`${ok ? 'PASS' : 'FAIL'}: ${label}`); };
try {
 for (const mobile of [false, true]) {
  const context = await browser.newContext({viewport: mobile ? {width: 844, height: 390} : {width: 1280, height: 720}, hasTouch: mobile, isMobile: mobile, userAgent: mobile ? 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130.0.0.0 Mobile Safari/537.36' : undefined});
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.text().includes('SCRIPT ERROR')) errors.push(m.text()); });
  const chunks = [];
  page.on('response', r => { if (/engine-.*\.bin$/.test(r.url())) chunks.push(r.status()); });
  await page.goto(url);
  await page.waitForSelector('#auth-email', {timeout: 90000});
  await page.waitForFunction(() => document.querySelector('#status').style.display === 'none', null, {timeout: 90000});
  check(chunks.length >= 2 && chunks.every(status => status === 200), `${mobile ? 'Mobile emulado' : 'PC'}: engine completo carregado em partes`);
  check(await page.locator('#pilot-badge').isVisible(), 'Identificação discreta do piloto visível');
  check(await page.locator('#auth-primary').isEnabled(), 'Configuração real permite tentar autenticação');
  await page.screenshot({path: `.tools/screenshots/sync-pilot-${mobile ? 'mobile' : 'pc'}.png`});
  if (mobile) {
   await page.setViewportSize({width: 390, height: 844});
   await page.waitForTimeout(350);
   check(await page.locator('#auth-email').isVisible(), 'Login continua acessível em retrato');
  } else {
   // Synthetic browser save, never a player world or authenticated Firebase write.
   const key = 'pilot-browser-validation/world';
   const content = JSON.stringify({validation: true, inventory: ['own-test-data']});
   const req = (op, payload = '', claim = '') => page.evaluate(args => new Promise(resolve => window.tcLocalProgress.request(...args, data => resolve(JSON.parse(data)))), [op, key, payload, claim]);
   check((await req('write', content)).ok, 'Piloto confirma gravação IndexedDB de dados próprios');
   await context.setOffline(true);
   await page.locator('#auth-email').fill('validation-probe@example.invalid');
   await page.locator('#auth-password').fill('invalid-credential-probe');
   await page.locator('#auth-primary').click();
   await page.waitForFunction(() => document.querySelector('#auth-message')?.textContent.includes('Sem conexão'), null, {timeout: 25000});
   check((await req('read')).value === content, 'Falha de conexão no login mostra mensagem e preserva bytes locais');
   await context.setOffline(false);
   if (process.argv.includes('--live-invalid')) {
    await page.locator('#auth-primary').click();
    await page.waitForFunction(() => document.querySelector('#auth-message')?.textContent === 'E-mail ou senha inválidos.', null, {timeout: 25000});
    check(true, 'Exportação do piloto rejeita credenciais inválidas pelo Firebase real');
   }
   await page.reload();
   await page.waitForSelector('#auth-email', {timeout: 90000});
   check((await req('read')).value === content, 'Reload do piloto conserva dados locais');
  }
  await context.close();
 }
 // Corrupt download must stop startup rather than load a mixed engine.
 const context = await browser.newContext();
 const page = await context.newPage();
 await page.route('**/engine-*-0.bin', route => route.fulfill({status: 200, body: 'incomplete'}));
 await page.goto(url);
 await page.waitForFunction(() => document.querySelector('#retry')?.hidden === false, null, {timeout: 90000});
 check(await page.locator('#auth-email').count() === 0, 'Parte incompleta impede inicialização e oferece recarregar');
 await context.close();
} finally { await browser.close(); }
await writeFile('.tools/sync-pilot-browser-results.json', JSON.stringify({url, results, errors}, null, 2));
if (errors.length || results.some(r => !r.pass)) process.exitCode = 1;

// Release export only; verified login responses are mocked in this isolated browser.
// This script never changes the shipped authentication or personal IndexedDB data.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
const url=process.env.TEST_URL||'http://localhost:8080/Tece-Island/';
const browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[],errors=[];
await mkdir('.tools/screenshots',{recursive:true});
function check(ok,name){results.push({name,ok:!!ok});console.log((ok?'PASS: ':'FAIL: ')+name);if(!ok)throw Error(name);}
try{
 const context=await browser.newContext({viewport:{width:1280,height:720}});
 await context.route('https://identitytoolkit.googleapis.com/**',route=>route.fulfill({status:200,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(route.request().url().includes('signInWithPassword')?{idToken:'fixture-only',refreshToken:'fixture-only',localId:'release-presentation-fixture',expiresIn:'3600'}:{users:[{localId:'release-presentation-fixture',email:'fixture@example.invalid',emailVerified:true}]})}));
 const page=await context.newPage();
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 page.on('response',r=>{if(r.status()>=400)errors.push('HTTP '+r.status()+' '+new URL(r.url()).pathname);});
 await page.goto(url);
 await page.locator('#auth-email').waitFor({timeout:60000});
 check(await page.evaluate(()=>typeof tcFixture==='undefined'&&typeof tcState==='undefined'),'Exportação pública exclui as interfaces da fixture');
 await page.evaluate(()=>document.fonts.ready);
 check(await page.evaluate(()=>[...document.fonts].filter(f=>['Atkinson','Bree'].includes(f.family)&&f.status==='loaded').length===2),'Formulário carrega as fontes locais');
 await page.locator('#auth-email').fill('fixture@example.invalid');
 await page.locator('#auth-password').fill('fixture-only-password');
 await page.locator('#auth-primary').click();
 await page.waitForFunction(()=>!document.querySelector('#auth'),null,{timeout:30000});
 await page.waitForTimeout(700);
 await page.screenshot({path:'.tools/screenshots/presentation-release-lobby.png'});
 await page.mouse.click(1200,60);
 await page.waitForTimeout(250);
 await page.screenshot({path:'.tools/screenshots/presentation-release-menu.png'});
 // Review this capture: public Menu offers Ajuda and Sair da conta only.
 await page.mouse.click(190,70);
 await page.waitForTimeout(200);
 await page.mouse.click(1040,220);
 await page.locator('#world-name').waitFor();
 await page.locator('#world-name').fill('Clareira ação');
 await page.locator('#world-confirm').click();
 await page.waitForFunction(()=>!document.querySelector('#world-dialog'),null,{timeout:10000});
 check(true,'Criação funciona na exportação release sem ferramentas de teste');
 await page.mouse.click(220,568);
 await page.waitForTimeout(1400);
 await page.screenshot({path:'.tools/screenshots/presentation-release-game.png'});
 check(errors.length===0,'Release inicia lobby e partida sem erros de execução ou recursos');
 await context.close();
}finally{
 await browser.close();
 await writeFile('.tools/presentation-release-results.json',JSON.stringify({url,authentication:'Respostas positivas interceptadas apenas neste navegador isolado',results,errors},null,2));
}

import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
try{
 const context=await browser.newContext({viewport:{width:960,height:540},permissions:['clipboard-read','clipboard-write']});const page=await context.newPage();
 await page.goto('http://localhost:8081/Tece-Island/');await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
 async function click(name){for(let i=0;i<10;i++){const s=await page.evaluate(()=>window.tcState),r=s.buttons[name];if(r&&r[1]>=0&&r[1]+r[3]<=540){await page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await page.waitForTimeout(400);return;}await page.mouse.move(480,350);await page.mouse.wheel(0,300);await page.waitForTimeout(400);}throw Error('Botão inacessível: '+name);}
 await click('Jogar solo');await page.waitForFunction(()=>window.tcState?.position);await click('Menu');await click('Ajuda e suporte');await click('Copiar informações para relatar problema');
 const actual=(await page.evaluate(()=>navigator.clipboard.readText())).replace(/\r\n/g,'\n'),expected=await page.evaluate(()=>window.tcState.diagnostic);
 if(actual!==expected||actual.split('\n').length!==5||/(token|uid|senha|@|slots)/i.test(actual)){console.log({same:actual===expected,lines:actual.split('\n').length,publicOnly:!/(token|uid|senha|@|slots)/i.test(actual)});throw Error('Diagnóstico/clipboard inválido');}
 console.log('PASS: botão copia apenas os cinco campos públicos esperados para o clipboard real');
}finally{await browser.close();}

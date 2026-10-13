import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[],errors=[];
const url=process.env.TEST_URL||'http://localhost:8080/Tece-Island/';
try{
 for(const touch of [false,true]){
  const context=await browser.newContext({viewport:{width:960,height:540},hasTouch:touch});
  const page=await context.newPage();
  const requests=[],authCodes=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{
   const expected=m.location().url.startsWith('https://identitytoolkit.googleapis.com/')&&m.text().includes('400');
   if(m.type()==='error'&&!expected)errors.push(m.text());
  });
  page.on('response',async r=>{
   if(r.url().startsWith('https://identitytoolkit.googleapis.com/')){
    requests.push(r.status());
    if(r.status()>=400){try{const data=await r.json(),code=String(data.error?.message||'').split(':')[0];if(/^[A-Z_]{1,80}$/.test(code))authCodes.push(code);}catch{}}
   }
   else if(r.status()>=400)errors.push('Asset HTTP '+r.status()+': '+new URL(r.url()).pathname);
  });
  await page.goto(url);
  await page.waitForFunction(()=>document.querySelector('#status').style.display==='none',null,{timeout:45000});
  await page.waitForTimeout(500);
  await page.screenshot({path:'.tools/screenshots/auth-release-'+(touch?'touch':'desktop')+'.png'});
  const click=async(x,y)=>{if(touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);};
  await click(450,170);await page.keyboard.type('validation-probe@example.invalid');
  await click(450,270);await page.keyboard.type('invalid-credential-probe');
  await click(480,395);
  await page.waitForResponse(r=>r.url().startsWith('https://identitytoolkit.googleapis.com/'),{timeout:25000}).catch(()=>{});
  await page.waitForTimeout(800);
  await page.screenshot({path:'.tools/screenshots/auth-release-rejected-'+(touch?'touch':'desktop')+'.png'});
  const ok=requests.includes(400)&&authCodes.some(code=>['INVALID_LOGIN_CREDENTIALS','INVALID_PASSWORD','EMAIL_NOT_FOUND'].includes(code));
  results.push({touch,invalidCredentialsRejected:ok,authErrorCodes:authCodes});
  console.log((ok?'PASS: ':'FAIL: ')+(touch?'Toque':'Desktop')+' — exportação principal acessa Firebase e rejeita credenciais inválidas');
  await page.reload();
  await page.waitForFunction(()=>document.querySelector('#status').style.display==='none',null,{timeout:45000});
  await context.close();
 }
 await writeFile('.tools/auth-release-results.json',JSON.stringify({url,results,errors},null,2));
 console.log(JSON.stringify({results,errors}));
 if(errors.length||results.some(r=>!r.invalidCredentialsRejected))process.exitCode=1;
}finally{await browser.close();}

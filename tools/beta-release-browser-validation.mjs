// Full release bundle, isolated browser profiles. Auth responses are mocked;
// no synthetic token or account creation is sent to production Firebase.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const url=process.env.TEST_URL||'http://localhost:8080/Tece-Island/';
const checks=[],errors=[],measurements=[];
const check=(ok,label)=>{assert.ok(ok,label);checks.push({pass:true,label});console.log('PASS: '+label);};
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
await mkdir('.tools/screenshots',{recursive:true});
try{
 for(const mobile of [false,true]){
  const viewport=mobile?{width:852,height:393}:{width:1280,height:720};
  const context=await browser.newContext({viewport,hasTouch:mobile,isMobile:mobile});
  const uid='beta-new-release-'+(mobile?'mobile':'pc'),prefix='account/'+createHash('sha256').update(uid).digest('hex');
  let firestore=0;
  await context.route('https://identitytoolkit.googleapis.com/**',async route=>{
   const endpoint=new URL(route.request().url()).pathname;
   const data=endpoint.endsWith(':signInWithPassword')?{localId:uid,idToken:'mock-only-never-sent-to-Firebase',refreshToken:'mock-refresh',expiresIn:'3600'}:{users:[{localId:uid,email:'new-player@example.test',emailVerified:true}]};
   await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  });
  await context.route('https://firestore.googleapis.com/**',route=>{firestore++;return route.abort();});
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error/.test(m.text()))errors.push(m.text());});
  const start=performance.now();await page.goto(url);await page.locator('#auth-email').waitFor({timeout:90000});
  await page.waitForFunction(()=>document.querySelector('#status').style.display==='none');
  measurements.push({format:mobile?'mobile-emulated':'PC-emulated',load_to_login_ms:performance.now()-start,viewport});
  check((await page.locator('#auth').innerText()).includes('teste fechado'),'Release login explains closed chat/cloud access');
  await page.locator('#auth-email').fill('new-player@example.test');await page.locator('#auth-password').fill('local-mock-only');await page.locator('#auth-primary').click();
  await page.waitForFunction(()=>!document.querySelector('#auth'),null,{timeout:30000});await page.waitForTimeout(1200);
  check(!await page.locator('#chat-launch').isVisible(),'New identity has no chat launcher or permission-error loop');
  await page.screenshot({path:'.tools/screenshots/beta-release-'+(mobile?'mobile':'pc')+'-lobby.png'});
  const logical={width:Math.max(960,540*viewport.width/viewport.height),height:Math.max(540,960*viewport.height/viewport.width)};
  const scale=Math.min(viewport.width/logical.width,viewport.height/logical.height),unit=mobile?Math.max(48,Math.ceil(44/scale)):48;
  const width=Math.max(280,Math.min(360,logical.width*.3)),rows=unit*4+62;
  const x=(logical.width-width/2-36)*scale,y=((logical.height-rows)/2+unit/2)*scale;
  await page.mouse.click(x,y);
  await page.locator('#world-dialog input').waitFor({timeout:10000});
  await page.locator('#world-dialog input').fill('Mundo de teste beta');
  await page.locator('#world-dialog').getByRole('button',{name:'Confirmar',exact:true}).click();
  await page.waitForFunction(()=>!document.querySelector('#world-dialog')||document.querySelector('#world-dialog').hidden);
  await page.waitForTimeout(350);
  // Observed Play-world button centers for the two fixed QA viewports.
  await page.mouse.click(mobile?206:235,mobile?305:570);await page.waitForTimeout(1500);
  await page.bringToFront();await page.locator('#canvas').focus();
  await page.keyboard.down('d');await page.waitForTimeout(450);await page.keyboard.up('d');
  // visibilitychange is the explicit save-on-hide bridge; a synthetic blur
  // only resets input and is not a real OS application-focus notification.
  await page.evaluate(()=>window.tcSaveOnHide());await page.waitForTimeout(3500);
  const scan=()=>page.evaluate(prefix=>new Promise(resolve=>tcLocalProgress.request('scan',prefix,'','',r=>resolve(JSON.parse(r)))),prefix);
  const first=await scan();
  await page.screenshot({path:'.tools/screenshots/beta-release-'+(mobile?'mobile':'pc')+'-world.png'});
  await writeFile('.tools/beta-release-debug.json',JSON.stringify(first.value.filter(e=>e.key.includes('/world/')).map(e=>{const s=JSON.parse(e.value);return {key:e.key,elapsed:s.elapsed,player:s.player};}),null,2));
  check(first.ok&&first.value.some(e=>e.key.includes('/world/')&&JSON.parse(e.value).version===8),'Full release creates and saves a new non-allowlisted world as v8');
  check(first.value.some(e=>{if(!e.key.includes('/world/'))return false;const s=JSON.parse(e.value);return s.elapsed>1&&s.player?.position?.[0]>1157;}),'Play-world opens actual solo; movement and explicit save-on-hide callback persist position');
  check(firestore===0,'New solo identity makes no Firestore chat or sync requests');
  await page.screenshot({path:'.tools/screenshots/beta-release-'+(mobile?'mobile':'pc')+'-world.png'});
  await page.reload();await page.locator('#auth-email').waitFor({timeout:90000});
  const reopened=await scan();check(reopened.value.some(e=>e.key.includes('/world/')&&JSON.parse(e.value).owner_uid===uid),'Reload keeps release world under its original identity');
  await context.close();
 }
 check(errors.length===0,'No GDScript or JavaScript errors in the release flow');
}finally{await browser.close();await writeFile('.tools/beta-release-browser-results.json',JSON.stringify({physical:false,productionLogin:false,auth:'mocked only in browser transport; full unmodified release client and IndexedDB',checks,measurements,errors},null,2));}

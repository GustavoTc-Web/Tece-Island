// Public Web build smoke; no production Firebase authentication or player data.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const url=process.env.TEST_URL||'http://127.0.0.1:8080/Tece-Island/';
const manifest=await(await fetch(new URL('version.json',url))).json();
const results=[],errors=[];const check=(ok,name)=>{results.push({ok:!!ok,name});assert.ok(ok,name);console.log('PASS: '+name);};
check(manifest.version==='0.9.0'&&manifest.save_schema===8&&manifest.campaign_schema===2&&manifest.tasks_schema===1&&manifest.allowed_account_count===2&&manifest.chat_enabled&&manifest.world_sync_enabled,'manifesto 0.9.0 identifica rollout das duas contas e formatos de save');
if(process.env.EXPECTED_COMMIT)check(manifest.commit===process.env.EXPECTED_COMMIT,'commit servido corresponde ao deploy esperado');
check(manifest.chat_idle_poll_seconds===15&&manifest.chat_idle_after_seconds===60&&manifest.chat_reconcile_seconds===120&&manifest.chat_transport==='rest_incremental_with_window_count','manifesto identifica estratégia de consumo validada');
const browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
await mkdir('.tools/screenshots',{recursive:true});
try{
 for(const mobile of [false,true]){
  const c=await browser.newContext({viewport:mobile?{width:852,height:393}:{width:1280,height:800},isMobile:mobile,hasTouch:mobile});const p=await c.newPage();let pck='';
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error'&&m.text().includes('SCRIPT ERROR'))errors.push(m.text());});
  const pckResponse=p.waitForResponse(r=>r.url().endsWith('/index.pck')&&r.status()===200,{timeout:90000});
  await p.route('https://**',r=>new URL(r.request().url()).origin===new URL(url).origin?r.continue():r.abort());await p.goto(url);await pckResponse;
  // API response bodies survive page reloads and browser resource-cache eviction.
  const downloaded=await c.request.get(new URL('index.pck',url).href);assert.equal(downloaded.status(),200);pck=createHash('sha256').update(await downloaded.body()).digest('hex');
  await p.locator('#auth-email').waitFor({timeout:90000});await p.waitForFunction(()=>document.querySelector('#status').style.display==='none',null,{timeout:90000});
  check(await p.locator('#auth-primary').isEnabled(),(mobile?'Mobile emulado':'PC')+': build completo apresenta login obrigatório');
  check(pck===manifest.sha256['index.pck'],'pacote servido corresponde ao hash do manifesto');
  const data=await p.evaluate(()=>new Promise(resolve=>tcLocalProgress.request('write','release-validation/own-data','{"test":true}','',r=>resolve(JSON.parse(r)))));check(data.ok,'build confirma armazenamento local de fixture isolada');
  await p.reload();await p.locator('#auth-email').waitFor({timeout:90000});const stored=await p.evaluate(()=>new Promise(resolve=>tcLocalProgress.request('read','release-validation/own-data','','',r=>resolve(JSON.parse(r)))));check(stored.value==='{"test":true}','reload preserva os bytes do dado de teste');
  if(mobile){await p.setViewportSize({width:393,height:852});check(await p.locator('#auth-primary').isVisible(),'login mobile permanece acessível em retrato');}
  await p.screenshot({path:'.tools/screenshots/release-'+(mobile?'mobile':'pc')+'.png'});await c.close();
 }
 check(errors.length===0,'nenhum erro GDScript ou JavaScript na exportação integrada');
}finally{await browser.close();await writeFile('.tools/release-browser-results.json',JSON.stringify({version:manifest.version,commit:manifest.commit,physical:false,results,errors},null,2)+'\n');}

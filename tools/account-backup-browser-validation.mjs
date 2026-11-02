// Full release client, isolated profile. All auth responses are synthetic and
// intercepted locally; no token/account/data is sent to production Firebase.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {createHash,randomBytes} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import assert from 'node:assert/strict';
const url=process.env.TEST_URL||'http://localhost:8087/Tece-Island/',out='.tools/account-backup-browser';await mkdir(out,{recursive:true});
const uidA='backup-browser-account-a',uidB='backup-browser-account-b',hash=x=>createHash('sha256').update(x).digest('hex');
const marker=randomBytes(15).toString('hex'),secrets={email:'login-'+marker+'@example.invalid',password:'password-'+marker,access:'access-'+marker,refresh:'refresh-'+marker,session:'session-'+marker};
let current=uidA,firestore=0;const checks=[],errors=[];
const check=(ok,label)=>{assert.ok(ok,label);checks.push({pass:true,label});console.log('PASS: '+label);};
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1280,height:720},acceptDownloads:true});
async function setup(ctx){
 await ctx.route('https://identitytoolkit.googleapis.com/**',route=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(route.request().url().includes('signInWithPassword')?{localId:current,idToken:secrets.access,refreshToken:secrets.refresh,expiresIn:'3600'}:{users:[{localId:current,email:secrets.email,emailVerified:true}]})}));
 await ctx.route('https://securetoken.googleapis.com/**',route=>route.abort());await ctx.route('https://firestore.googleapis.com/**',route=>{firestore++;return route.abort();});
}
await setup(context);let page=await context.newPage();
const observe=p=>{p.on('dialog',d=>d.dismiss());p.on('pageerror',()=>errors.push('JavaScript error; values omitted'));p.on('console',m=>{if(/SCRIPT ERROR|Parse Error/.test(m.text()))errors.push('Engine error; values omitted');});};observe(page);
const scan=()=>page.evaluate(()=>new Promise(resolve=>tcLocalProgress.request('scan','','','',r=>resolve(JSON.parse(r)))));
const bridge=(op,key,payload='')=>page.evaluate(({op,key,payload})=>new Promise(resolve=>tcLocalProgress.request(op,key,payload,'',r=>resolve(JSON.parse(r)))),{op,key,payload});
const put=entries=>page.evaluate(entries=>new Promise((resolve,reject)=>{const r=indexedDB.open('tece-island-progress-v4',1);r.onupgradeneeded=()=>r.result.createObjectStore('saves');r.onsuccess=()=>{const db=r.result,tx=db.transaction('saves','readwrite');for(const e of entries)tx.objectStore('saves').put(e.value,e.key);tx.oncomplete=()=>{db.close();resolve(true);};tx.onabort=()=>reject(Error('Fixture transaction failed'));};}),entries);
async function login(uid){current=uid;await page.goto(url);await page.locator('#auth-email').waitFor({timeout:90000});await page.waitForFunction(()=>document.querySelector('#status').style.display==='none');const denied=await page.evaluate(async()=>{try{await tcExportLocalSaves();return false;}catch{return true;}});check(denied,'Unauthenticated export is refused by the real client');await page.locator('#auth-email').fill(secrets.email);await page.locator('#auth-password').fill(secrets.password);await page.locator('#auth-primary').click();await page.waitForFunction(()=>!document.querySelector('#auth'));await page.waitForTimeout(1500);}
async function download(name,foreign){
 const before=await scan(),event=page.waitForEvent('download');await page.evaluate(foreign=>tcExportLocalSaves(foreign),foreign);const file=await event;check(file.suggestedFilename()==='tece-island-meus-mundos.json','New backup filename is used');await file.saveAs(out+'/'+name);const raw=await readFile(out+'/'+name,'utf8'),data=JSON.parse(raw),after=await scan();
 check(data.format===2&&data.scope==='current-account-worlds'&&data.privacy.includes('privado'),'Backup identifies current-account scope and private content');
 const all=data.entries.map(e=>JSON.parse(e.value));check(all.length>0&&all.every(v=>v.owner_uid===current),'Every exported catalog/save/backup belongs to the connected account; caller-supplied UID is ignored');
 check(!raw.includes(foreign)&&!raw.includes(hash(foreign)),'No foreign UID or account hash is present');
 const expanded=raw+'\n'+data.entries.map(e=>e.value).join('\n');check(Object.values(secrets).every(v=>!expanded.includes(v)),'No auth password, tokens, login email or session marker in nested content');
 check(before.ok&&JSON.stringify(before)===JSON.stringify(after),'Export is read-only, including excluded records');return data;
}
let exportA,exportB;
try{
 for(const uid of [uidA,uidB]){
  await login(uid);await page.mouse.click(1040,220);await page.locator('#world-dialog input').waitFor({timeout:10000});await page.locator('#world-dialog input').fill(uid===uidA?'Synthetic world A':'Synthetic world B');await page.locator('#world-dialog').getByRole('button',{name:'Confirmar',exact:true}).click();await page.waitForTimeout(500);await page.mouse.click(235,570);await page.waitForTimeout(1700);await page.evaluate(()=>tcSaveOnHide());await page.waitForTimeout(1700);
  const all=await scan(),keyPrefix='account/'+hash(uid)+'/world/',entry=all.value.find(e=>e.key.startsWith(keyPrefix)&&!e.key.includes(':'));check(!!entry,'Release client created a real owned v9 save');
  const state=JSON.parse(entry.value);state.inventory={slots:[{item:'espada_pedra',quantity:1,uid:17},{item:'pistola',quantity:1,uid:18,loaded:4},{item:'cantil',quantity:1,water:2},{},{},{},{}],selected:1,backpack:{},armor:{},category:'pistola',weapon_uid:18};state.campaign.map_found=true;state.objectives.campaign_tasks.crafted=['espada_pedra'];state.objectives.campaign_tasks.inferred=[];
  await bridge('write',entry.key,JSON.stringify({...state,version:8}));await bridge('write',entry.key,JSON.stringify(state));
  const opaque=gzipSync(Buffer.from(JSON.stringify(secrets))).toString('base64');const bad={...state,opaque};
  await put([{key:entry.key+':conflict-'+'b'.repeat(32),value:JSON.stringify(state)},{key:entry.key+':unreadable-'+'a'.repeat(32),value:'unreadable-synthetic'},{key:entry.key+':recovery-original-'+'c'.repeat(32),value:JSON.stringify(bad)},{key:'legacy-original-v4',value:JSON.stringify(state)},{key:'unknown-synthetic',value:opaque}]);
  // Reopen lobby so the export is not concurrent with a running world's timer.
  await login(uid);
  if(uid===uidB){
   const foreign=JSON.parse(exportA.entries.find(e=>e.key.includes('/world/')).value),all=await scan(),catalog=all.value.find(e=>e.key==='account/'+hash(uidB)+'/worlds'),data=JSON.parse(catalog.value);
   data.worlds.push({id:foreign.world_id,name:foreign.world_name,last_access:1});
   await put([{key:'account/'+hash(uidB)+'/world/foreign-miskey',value:JSON.stringify(foreign)},{key:catalog.key,value:JSON.stringify(data)}]);
  }
  await page.evaluate(s=>{localStorage.setItem('synthetic-session',s.session);sessionStorage.setItem('synthetic-token',s.access);},secrets);
  const exported=await download(uid===uidA?'account-a.json':'account-b.json',uid===uidA?uidB:uidA);
  check(exported.entries.some(e=>e.key.endsWith(':before-v9'))&&exported.entries.some(e=>e.key.includes(':conflict-')),'Owned migration backup and conflict copies are included');
  check(!exported.entries.some(e=>e.key.includes(':unreadable-')||e.key.includes(':recovery-original-')||e.key==='legacy-original-v4'||e.key==='unknown-synthetic'||e.key.endsWith('foreign-miskey')),'Legacy, unreadable, opaque and misowned entries stay outside the standard backup');
  if(uid===uidA)exportA=exported;else exportB=exported;
 }
 const foreign=JSON.parse(exportA.entries.find(e=>e.key.includes('/world/')).value),allB=JSON.stringify(exportB);
 check(!allB.includes(foreign.world_id)&&!allB.includes(foreign.world_name),'B catalog cannot leak A world identifier/name through a dangling reference');
 // Restore the downloaded B backup into a second disposable browser context;
 // writes are fixture restoration only, never a production/user profile.
 const restored=await browser.newContext({viewport:{width:1280,height:720}});await setup(restored);page=await restored.newPage();observe(page);current=uidB;
 await page.goto(url);await page.locator('#auth-email').waitFor({timeout:90000});await put(exportB.entries);await login(uidB);
 await page.mouse.click(1040,220);await page.waitForTimeout(1600);await page.evaluate(()=>tcSaveOnHide());await page.waitForTimeout(1400);
 const saved=await scan(),state=JSON.parse(saved.value.find(e=>e.key.startsWith('account/'+hash(uidB)+'/world/')&&!e.key.includes(':')).value);
 check(state.version===9&&state.inventory.slots[1].loaded===4&&state.inventory.slots[2].water===2&&state.inventory.selected===1&&state.campaign.map_found,'Actual v9 client reopens the downloaded copy preserving inventory attributes, selection and campaign map');
 check(!saved.value.some(e=>e.key.includes(hash(uidA))),'Restored B backup creates no A records');
 check(firestore===0&&errors.length===0,'No production Firebase traffic or script errors');await restored.close();
}finally{await browser.close();await writeFile(out+'/results.json',JSON.stringify({physical:false,auth:'mocked only in browser transport',production_firebase_requests:firestore,checks,errors,actual_client:true,synthetic_data:true},null,2)+'\n');}

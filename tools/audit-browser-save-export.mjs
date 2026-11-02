// Privacy audit only: disposable browser context, synthetic identities, no real
// Firebase credentials/accounts. Never print exported values or canary strings.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash,randomBytes} from 'node:crypto';
import {gzipSync,gunzipSync,inflateSync,inflateRawSync} from 'node:zlib';
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
const url='https://gustavotc-web.github.io/Tece-Island/';
const dir='.tools/save-export-audit';await mkdir(dir,{recursive:true});
const manifest=await(await fetch(url+'version.json',{cache:'no-store'})).json();
assert.equal(manifest.version,'0.9.1-beta.1');
assert.equal(manifest.commit,'fbc56f75c60ae690f5a101516145a384c9fa1304');
const html=await(await fetch(url,{cache:'no-store'})).text();
assert.equal(createHash('sha256').update(html).digest('hex'),'f287787698b3360cc6d960b5a0f7a30c93202b36687d700392af5bbac0d71c93');
const source=execFileSync('git',['-c','safe.directory='+process.cwd().replaceAll('\\','/'),'show',manifest.commit+':web/shell.html'],{encoding:'utf8'}).replaceAll('\r\n','\n');
assert.equal(createHash('sha256').update(source).digest('hex'),manifest.source_sha256['web/shell.html']);
const stamp=randomBytes(10).toString('hex');
const canaries={password:'pw-'+randomBytes(28).toString('hex'),refresh:'rt-'+randomBytes(30).toString('hex'),email:'auth-'+stamp+'@example.invalid',freeTextEmail:'world-'+stamp+'@example.test',session:'session-'+randomBytes(20).toString('hex')};
const uidA='audit-a-'+stamp,uidB='audit-b-'+stamp;
canaries.access=[Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({email:canaries.email,session:canaries.session})).toString('base64url'),'synthetic-no-authentication'].join('.');
let currentUid=uidA,firestoreRequests=0,authIntercepts=0;
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const context=await browser.newContext({viewport:{width:1280,height:720},acceptDownloads:true});
const page=await context.newPage(),errors=[],checks=[];
page.on('pageerror',()=>errors.push('JavaScript page error; values omitted'));
page.on('console',m=>{if(/SCRIPT ERROR|Parse Error/.test(m.text()))errors.push('Engine script error; values omitted');});
const check=(condition,label)=>{assert.ok(condition,label);checks.push({pass:true,label});};
await context.route('https://identitytoolkit.googleapis.com/**',async route=>{
 authIntercepts++;
 const lookup=!route.request().url().includes('signInWithPassword');
 const body=lookup?{users:[{localId:currentUid,email:canaries.email,emailVerified:true}]}:{localId:currentUid,idToken:canaries.access,refreshToken:canaries.refresh,expiresIn:'3600'};
 await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
});
await context.route('https://securetoken.googleapis.com/**',route=>route.abort());
await context.route('https://firestore.googleapis.com/**',route=>{firestoreRequests++;return route.abort();});
const scan=()=>page.evaluate(()=>new Promise(resolve=>tcLocalProgress.request('scan','','','',r=>resolve(JSON.parse(r)))));
const bridge=async(op,key,payload='',claim='')=>page.evaluate(({op,key,payload,claim})=>new Promise(resolve=>tcLocalProgress.request(op,key,payload,claim,r=>resolve(JSON.parse(r)))),{op,key,payload,claim});
const exportFile=async name=>{
 const received=page.waitForEvent('download');await page.evaluate(()=>tcExportLocalSaves());
 const download=await received;check(download.suggestedFilename()==='tece-island-saves.json','Uses the actual published export download');
 await download.saveAs(dir+'/'+name);return JSON.parse(await readFile(dir+'/'+name,'utf8'));
};
function decodeExport(value){
 const texts=[],paths=new Set(),decoded={json_strings:0,base64_json:0,compressed:0};
 const walk=(v,path='$',depth=0)=>{
  if(depth>20)throw Error('Unexpected nesting depth');
  if(Array.isArray(v)){for(const item of v)walk(item,path+'[]',depth+1);return;}
  if(v&&typeof v==='object'){for(const [k,x]of Object.entries(v)){paths.add(path+'.'+k);walk(x,path+'.'+k,depth+1);}return;}
  if(typeof v!=='string')return;texts.push(v);
  if(/^\s*[\[{]/.test(v)){try{const x=JSON.parse(v);decoded.json_strings++;walk(x,path+'{json}',depth+1);return;}catch{}}
  if(v.length<16||v.length%4!==0||!/^[A-Za-z0-9+/]+={0,2}$/.test(v)||/^[a-f0-9]{64}$/.test(v))return;
  const bytes=Buffer.from(v,'base64');
  for(const transform of [x=>x,gunzipSync,inflateSync,inflateRawSync]){
   try{const out=transform(bytes,{maxOutputLength:16*1024*1024}).toString('utf8');if(!/^\s*[\[{]/.test(out))continue;
    const x=JSON.parse(out);decoded.base64_json++;if(transform!==undefined&&transform!==null&&[gunzipSync,inflateSync,inflateRawSync].includes(transform))decoded.compressed++;
    texts.push(out);walk(x,path+'{decoded}',depth+1);break;
   }catch{}
  }
 };
 walk(value);return {texts,paths:[...paths].sort(),decoded};
}
const rawPut=async entries=>page.evaluate(entries=>new Promise((resolve,reject)=>{
 const r=indexedDB.open('tece-island-progress-v4',1);r.onsuccess=()=>{const db=r.result,tx=db.transaction('saves','readwrite');for(const e of entries)tx.objectStore('saves').put(e.value,e.key);tx.oncomplete=()=>{db.close();resolve(true);};tx.onerror=()=>reject(Error('Fixture transaction failed'));};r.onerror=()=>reject(Error('Fixture DB open failed'));
}),entries);
let result;
try{
 for(const uid of [uidA,uidB]){
  currentUid=uid;await page.goto(url);
  await page.locator('#auth-email').waitFor({timeout:90000});
  await page.waitForFunction(()=>document.querySelector('#status').style.display==='none');
  await page.locator('#auth-email').fill(canaries.email);await page.locator('#auth-password').fill(canaries.password);await page.locator('#auth-primary').click();
  await page.waitForFunction(()=>!document.querySelector('#auth'));await page.waitForTimeout(1500);
  await page.mouse.click(1040,220);await page.locator('#world-dialog input').waitFor({timeout:10000});
  await page.locator('#world-dialog input').fill(uid===uidA?'Audit world A':canaries.freeTextEmail);
  await page.locator('#world-dialog').getByRole('button',{name:'Confirmar',exact:true}).click();
  await page.waitForTimeout(500);await page.mouse.click(235,570);await page.waitForTimeout(1600);
  await page.evaluate(()=>tcSaveOnHide());await page.waitForTimeout(1800);
  const saved=await scan();check(saved.ok,'Actual released solo writes a durable synthetic world');
  const prefix='account/'+createHash('sha256').update(uid).digest('hex')+'/world/';
  check(saved.value.some(e=>e.key.startsWith(prefix)&&JSON.parse(e.value).version===9),'Both test identities have their own actual v9 world');
 }
 const actual=await scan();
 // Prepared preservation cases: exact raw bytes are intentionally retained.
 const sample=actual.value.find(e=>e.key.startsWith('account/'+createHash('sha256').update(uidA).digest('hex')+'/world/')&&!e.key.includes(':'));
 const v9=JSON.parse(sample.value),v8={...v9,version:8};
 await bridge('write',sample.key,JSON.stringify(v8));await bridge('write',sample.key,sample.value);
 await bridge('preserve',sample.key,'','before-cloud');
 await rawPut([{key:sample.key+':unreadable-audit',value:'SYNTHETIC malformed save'},{key:'legacy-original-v4',value:JSON.stringify(v8)},{key:'legacy-import-v4',value:createHash('sha256').update(uidA).digest('hex')}]);
 // Sentinels outside the save database must not leak into this export.
 await page.evaluate(c=>{localStorage.setItem('audit-access',c.access);sessionStorage.setItem('audit-refresh',c.refresh);window.auditSession=c.session;document.cookie='audit='+c.session+'; SameSite=Strict';},canaries);
 const before=await scan();const normal=await exportFile('normal-synthetic-export.json');const after=await scan();
 check(JSON.stringify(before)===JSON.stringify(after),'Export does not modify the save database');
 check(normal.format===1&&normal.origin===new URL(url).origin&&typeof normal.exportedAt==='string','Envelope contains format, origin, export time and entries');
 check(normal.entries.length===before.value.length,'Every entry in the saves store is exported');
 const owners=new Set(normal.entries.flatMap(e=>{try{const x=JSON.parse(e.value);return x.owner_uid?[x.owner_uid]:[];}catch{return [];}}));
 check(owners.has(uidA)&&owners.has(uidB),'While signed in as B, export contains A and B');
 check(normal.entries.some(e=>e.key===sample.key+':before-v9')&&normal.entries.some(e=>e.key.includes(':backup'))&&normal.entries.some(e=>e.key.endsWith(':unreadable-audit')),'Migration backups, rolling backups and unreadable bytes are included');
 const decoded=decodeExport(normal),joined=decoded.texts.join('\n');
 const secretPresence=Object.fromEntries(['password','access','refresh','email','session'].map(k=>[k,joined.includes(canaries[k])]));
 check(Object.values(secretPresence).every(v=>!v),'No synthetic auth password, token, login email or session sentinel in normal export, including nested strings');
 check(joined.includes(canaries.freeTextEmail),'A personal string entered as world name is exported');
 check(decoded.decoded.compressed===0&&decoded.decoded.base64_json===0,'Normal exported saves have escaped JSON, no compressed or Base64 payload');
 // Separate adversarial fixture, NOT produced by normal gameplay/authentication.
 const probe={private_email:canaries.email,access_token:canaries.access,refresh_token:canaries.refresh,session:canaries.session};
 const packed=gzipSync(Buffer.from(JSON.stringify(probe))).toString('base64');
 await rawPut([{key:'audit-opaque-probe',value:JSON.stringify({opaque:packed})}]);
 const opaque=await exportFile('opaque-synthetic-export.json'),unpacked=decodeExport(opaque),expanded=unpacked.texts.join('\n');
 check(unpacked.decoded.compressed===1&&Object.values(probe).every(v=>expanded.includes(v)),'Injected gzip/Base64 opaque entry is exported intact: exporter is not a secret scrubber');
 check(firestoreRequests===0&&authIntercepts>=4,'No production Firebase auth/data traffic: mock identities stay in browser transport');
 check(errors.length===0,'No script errors in the synthetic audit flow');
 const worldFields=Object.keys(v9).sort(),catalog=normal.entries.map(e=>{try{return JSON.parse(e.value);}catch{return null;}}).find(v=>v&&v.worlds&&v.servers);
 result={version:manifest.version,commit:manifest.commit,published_html_sha256:createHash('sha256').update(html).digest('hex'),date_brt:'2026-11-02',production_authentication:false,production_firebase_requests:0,personal_profile_used:false,checks,normal_export:{entries:normal.entries.length,top_level_fields:Object.keys(normal),entry_fields:['key','value'],world_fields:worldFields,catalog_fields:Object.keys(catalog).sort(),all_account_owners:owners.size,auth_secret_or_login_email_presence:secretPresence,free_text_personal_data_present:true,decoded_layers:decoded.decoded,field_paths:decoded.paths},opaque_injection:{normal_app_output:false,manual_synthetic_entry:true,compressed_payload_recovered:unpacked.decoded.compressed,not_sanitized:true},classification:'private browser-wide backup; not anonymized support report',runtime_changes:false};
 await writeFile(dir+'/redacted-results.json',JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({checks:checks.length,failed:0,version:result.version,entries:normal.entries.length,account_owners:owners.size,auth_secret_presence:secretPresence,normal_layers:decoded.decoded,opaque_injection_not_sanitized:true,classification:result.classification}));
}finally{await browser.close();}

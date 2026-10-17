// Actual browser/REST traffic against a LOCAL emulator, never billing telemetry.
// Run after chat-browser-validation (both clear the demo database).
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,setDoc,deleteDoc,Timestamp} from 'firebase/firestore';
import {readFile,writeFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8085')throw Error('Local demo emulator required');
const baseline=process.argv[2];
if(!baseline)throw Error('Pass a verified baseline export directory');
const env=await initializeTestEnvironment({projectId:'demo-tece-island',firestore:{rules:await readFile('firestore.rules','utf8')}});
await env.clearFirestore();
let sequence=50;
const message=n=>({sequence:n,uid:'chat-b',nickname:'Beto',text:'Budget '+n,sent_at:Timestamp.now()});
await env.withSecurityRulesDisabled(async c=>{
 const d=c.firestore();await setDoc(doc(d,'chatSettings/global'),{enabled:true,allowed_uids:['chat-a','chat-b'],admin_uids:['chat-b']});
 await setDoc(doc(d,'chatProfiles/chat-a'),{nickname:'Ana'});
 for(let n=1;n<=50;n++)await setDoc(doc(d,'globalMessages/'+n),message(n));
 await setDoc(doc(d,'chatRuntime/global'),{sequence,sent_at:Timestamp.now()});
});
const servers=[];let browser;const observations=[],errors=[],checks=[];let phase='startup';
const check=(value,name)=>{assert.ok(value,name);checks.push(name);console.log('PASS: '+name);};
const command=(page,action)=>page.evaluate(action=>tcChatFixture(JSON.stringify({action})),action);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const summary=(label,p)=>{
 const rows=observations.filter(r=>r.client===label&&r.phase===p);
 return {requests:rows.length,full_queries:rows.filter(r=>r.kind==='full').length,incrementals:rows.filter(r=>r.kind==='incremental').length,counts:rows.filter(r=>r.kind==='count').length,returned_documents:rows.reduce((n,r)=>n+r.documents,0),estimated_direct_reads:rows.reduce((n,r)=>n+r.direct,0),rule_read_reserve:rows.length};
};
try{
 for(const [port,dir] of [[8088,baseline],[8089,'build/chat-emulated']]){
  const server=spawn(process.execPath,['tools/serve-web.mjs',String(port),dir],{stdio:['ignore','pipe','pipe'],windowsHide:true});servers.push(server);
  await new Promise((resolve,reject)=>{server.stdout.once('data',resolve);server.once('error',reject);});
 }
 browser=await chromium.launch({executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
 const clients=[];
 for(const [label,port] of [['before',8088],['after',8089]]){
  const context=await browser.newContext({viewport:{width:1280,height:800}}),page=await context.newPage();
  let inflight=0,maxInflight=0;
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{if(r.url().includes('8085/v1/')){inflight++;maxInflight=Math.max(maxInflight,inflight);}});
  for(const event of ['requestfinished','requestfailed'])page.on(event,r=>{if(r.url().includes('8085/v1/'))inflight--;});
  page.on('response',async response=>{
   if(!response.url().includes('8085/v1/'))return;
   const atPhase=phase,request=response.request(),body=request.postDataJSON();
   const kind=response.url().includes('runAggregationQuery')?'count':response.url().includes('runQuery')?(body.structuredQuery.where?'incremental':'full'):'get';
   try{
    const data=await response.json();
    if((response.status()===429&&atPhase==='quota')||(response.status()===400&&atPhase==='index')){observations.push({client:label,phase:atPhase,kind:'denied',documents:0,direct:0});return;}
    assert.equal(response.status(),200);
    const documents=Array.isArray(data)?data.filter(row=>row.document).length:1;
    observations.push({client:label,phase:atPhase,kind,documents,direct:kind==='count'?1:Math.max(1,documents)});
   }catch(e){errors.push(String(e));}
  });
  await page.route('https://**',route=>route.abort());await page.goto('http://127.0.0.1:'+port+'/Tece-Island/');
  await page.waitForFunction(()=>!!window.tcChatFixture,null,{timeout:60000});
  await page.evaluate(()=>tcChatFixture(JSON.stringify({action:'login',uid:'chat-a'})));
  await page.locator('#chat-launch').click();await page.waitForFunction(()=>tcChatSnapshot.ready&&!tcChatSnapshot.reading);
  check(await page.locator('#chat-list li').count()===50,label+': initial history contains 50 messages');
  clients.push({label,page,max:()=>maxInflight});
 }
 phase='idle';const idleStart=Date.now();console.log('Observando histórico cheio sem mensagens novas por 135 s...');
 await sleep(135000);const idleMs=Date.now()-idleStart;
 check(summary('before','idle').full_queries>=1,'baseline actually rereads the full idle history');
 check(summary('after','idle').full_queries===0&&summary('after','idle').counts>=1,'optimized idle uses count without rereading history');
 check(summary('after','idle').estimated_direct_reads<summary('before','idle').estimated_direct_reads/2,'observed direct read estimate reduced by more than half');
 phase='active';const latencies=[];
 for(let i=0;i<3;i++){
  const started=Date.now();sequence++;
  await env.withSecurityRulesDisabled(async c=>{const d=c.firestore();await setDoc(doc(d,'globalMessages/'+sequence%100),message(sequence));await setDoc(doc(d,'chatRuntime/global'),{sequence,sent_at:Timestamp.now()});});
  await Promise.all(clients.map(async({label,page})=>{await page.waitForFunction(n=>document.querySelector('#chat-list').textContent.includes('Budget '+n),sequence,{timeout:20000});latencies.push({client:label,ms:Date.now()-started});}));
  await sleep(5500);
 }
 for(const {label,page} of clients)check(await page.locator('#chat-list li').count()===50,label+': bounded history without duplicate rows');
 phase='closed';for(const {page} of clients){await page.locator('#chat-text').fill('Draft budget');await page.getByRole('button',{name:'Recolher',exact:true}).click();}
 await sleep(1000);const closedStart=observations.length;await sleep(6000);
 check(observations.length===closedStart,'closed panels make zero new requests');
 for(const {page} of clients){await page.locator('#chat-launch').click();await page.waitForFunction(()=>!tcChatSnapshot.reading);check(await page.locator('#chat-text').inputValue()==='Draft budget','reopening preserves draft');}
 phase='hidden';for(const {page} of clients)await page.evaluate(()=>{window.budgetHidden=true;Object.defineProperty(document,'hidden',{configurable:true,get:()=>window.budgetHidden});document.dispatchEvent(new Event('visibilitychange'));});
 await sleep(1000);const hiddenStart=observations.length;await sleep(6000);
 check(observations.length===hiddenStart,'hidden tabs make zero new requests');
 sequence++;await env.withSecurityRulesDisabled(async c=>{const d=c.firestore();await setDoc(doc(d,'globalMessages/'+sequence%100),message(sequence));await setDoc(doc(d,'chatRuntime/global'),{sequence,sent_at:Timestamp.now()});});
 phase='resume';const resumed=Date.now();
 for(const {page} of clients)await page.evaluate(()=>{window.budgetHidden=false;for(const e of ['online','pageshow','focus'])window.dispatchEvent(new Event(e));document.dispatchEvent(new Event('visibilitychange'));});
 await Promise.all(clients.map(async({label,page})=>{await page.waitForFunction(n=>document.querySelector('#chat-list').textContent.includes('Budget '+n),sequence,{timeout:20000});latencies.push({client:label,phase:'resume',ms:Date.now()-resumed});check(await page.locator('#chat-text').inputValue()==='Draft budget',label+': resume preserves draft');}));
 // Prove frozen-window count handles an OLD client's physical delete while
 // an author is muted; later inserts must not conceal that deletion.
 phase='removal';const optimized=clients[1].page;
 await optimized.locator('#chat-list li').last().getByRole('button',{name:'Silenciar',exact:true}).click();
 await env.withSecurityRulesDisabled(c=>deleteDoc(doc(c.firestore(),'globalMessages/50')));
 await command(optimized,'refresh');await optimized.waitForFunction(()=>!tcChatSnapshot.reading);
 await optimized.locator('#chat-unmute').click();
 await optimized.waitForFunction(()=>![...document.querySelectorAll('#chat-list li')].some(e=>e.textContent.includes('Budget 50')));
 check(await optimized.locator('#chat-list li').count()===50,'count reconciles physical delete, includes muted raw cache, refills window');
 // Final service lifecycle: a query already in flight finishes; no metadata
 // or aggregation follow-up may start once the panel closes.
 phase='close-inflight';let release;const heldRequest=new Promise(resolve=>{release=resolve;});await optimized.route('**/documents:runQuery',route=>release(route));
 await command(optimized,'poll');await optimized.waitForFunction(()=>tcChatSnapshot.reading);
 await optimized.getByRole('button',{name:'Recolher',exact:true}).click();
 const held=await heldRequest;await held.continue();await optimized.unroute('**/documents:runQuery');await optimized.waitForFunction(()=>!tcChatSnapshot.reading);
 const closedAgain=observations.length;await sleep(1500);check(observations.length===closedAgain,'closing an in-flight cycle starts no follow-up request');
 phase='quota';await optimized.locator('#chat-launch').click();
 await optimized.route('**/documents:runAggregationQuery',route=>route.fulfill({status:429,contentType:'application/json',body:JSON.stringify({error:{code:429,status:'RESOURCE_EXHAUSTED'}})}));
 await command(optimized,'refresh');await optimized.waitForFunction(()=>tcChatSnapshot.connection_error.includes('HTTP 429'));
 const quotaStart=observations.length;
 await optimized.evaluate(()=>{for(let i=0;i<10;i++)for(const event of ['online','focus','pageshow'])window.dispatchEvent(new Event(event));});
 await sleep(6000);check(observations.length===quotaStart,'quota failure is visible; focus events preserve backoff without fallback queries');
 await optimized.unroute('**/documents:runAggregationQuery');await command(optimized,'poll');await optimized.waitForFunction(()=>!tcChatSnapshot.reading&&!tcChatSnapshot.connection_error);
 check(await optimized.locator('#chat-text').inputValue()==='Draft budget','quota recovery preserves draft');
 phase='index';let rejected=0;
 await optimized.route('**/documents:runQuery',route=>{
  if(route.request().postDataJSON().structuredQuery.where){rejected++;return route.fulfill({status:400,contentType:'application/json',body:JSON.stringify({error:{code:400,status:'FAILED_PRECONDITION'}})});}
  return route.continue();
 });
 await command(optimized,'poll');await optimized.waitForFunction(()=>tcChatSnapshot.connection_error.includes('HTTP 400')&&!tcChatSnapshot.reading);
 const indexStart=observations.length;
 await optimized.evaluate(()=>{for(let i=0;i<10;i++)window.dispatchEvent(new Event('focus'));});
 await sleep(6000);check(observations.length===indexStart,'successful full fallback still backs off a persistent incremental failure');
 const retryDeadline=Date.now()+20000;
 while(observations.filter(r=>r.client==='after'&&r.phase==='index'&&r.kind==='full').length<2){if(Date.now()>retryDeadline)throw Error('No scheduled index retry');await sleep(100);}
 await optimized.waitForFunction(()=>!tcChatSnapshot.reading);
 check(rejected===2&&observations.filter(r=>r.client==='after'&&r.phase==='index'&&r.kind==='full').length===2,'persistent failure performs only one bounded fallback per backed-off attempt');
 await optimized.unroute('**/documents:runQuery');await command(optimized,'poll');await optimized.waitForFunction(()=>!tcChatSnapshot.connection_error&&!tcChatSnapshot.reading);
 for(const client of clients)check(client.max()<=1,client.label+': maximum one concurrent request');
 check(errors.length===0,'no browser/REST errors');
 const phases=Object.fromEntries(['startup','idle','active','closed','hidden','resume','removal','close-inflight','quota','index'].map(p=>[p,Object.fromEntries(clients.map(c=>[c.label,summary(c.label,p)]))]));
 await writeFile('.tools/chat-budget-results.json',JSON.stringify({kind:'measured-local-browser-http; reads estimated, not billed',physical:false,idle_duration_ms:idleMs,phases,latencies,checks,errors},null,2)+'\n');
 console.log(JSON.stringify({idle_duration_ms:idleMs,idle:phases.idle,active:phases.active,resume:phases.resume,latencies},null,2));
}finally{if(browser)await browser.close();for(const s of servers)s.kill();await env.cleanup();}

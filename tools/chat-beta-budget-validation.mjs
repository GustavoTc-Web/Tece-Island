// Measured local HTTP traffic. Document-read totals are estimates, not billing.
import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,setDoc,Timestamp} from 'firebase/firestore';
import {readFile,writeFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
assert.equal(process.env.FIRESTORE_EMULATOR_HOST,'127.0.0.1:8085');
const env=await initializeTestEnvironment({projectId:'demo-tece-island',firestore:{rules:await readFile('firestore.rules','utf8')}});
await env.clearFirestore();
await env.withSecurityRulesDisabled(async c=>{
 const d=c.firestore();await setDoc(doc(d,'chatSettings/global'),{enabled:true,access_mode:'verified',allowed_uids:['chat-a','chat-b'],admin_uids:['chat-b']});
 for(const uid of ['chat-a','chat-new'])await setDoc(doc(d,'chatProfiles/'+uid),{nickname:uid==='chat-a'?'Ana':'Nova'});
 for(let n=1;n<=50;n++)await setDoc(doc(d,'globalMessages/'+n),{sequence:n,uid:'chat-b',nickname:'Beto',text:'History '+n,sent_at:Timestamp.now()});
 await setDoc(doc(d,'chatRuntime/global'),{sequence:50,sent_at:Timestamp.now()});
});
const server=spawn(process.execPath,['tools/serve-web.mjs','8088','build/chat-emulated'],{stdio:['ignore','pipe','pipe'],windowsHide:true});
await new Promise((r,j)=>{server.stdout.once('data',r);server.once('error',j);});
let browser,phase='startup';const rows=[],checks=[],latencies=[],errors=[];
const check=(ok,name)=>{checks.push({ok:!!ok,name});console.log((ok?'PASS: ':'FAIL: ')+name);assert.ok(ok,name);};
try{
 browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
 const clients=[];
 for(const uid of ['chat-a','chat-new']){
  const c=await browser.newContext({viewport:{width:1280,height:720}}),p=await c.newPage();
  p.on('pageerror',e=>errors.push(e.message));
  p.on('response',async r=>{if(!r.url().includes('8085/v1/'))return;const label=phase;try{const json=await r.json(),documents=Array.isArray(json)?json.filter(x=>x.document).length:1;const kind=r.url().includes('runAggregationQuery')?'count':r.url().includes('runQuery')?(r.request().postDataJSON().structuredQuery.where?'incremental':'full'):'metadata';rows.push({uid,phase:label,kind,status:r.status(),documents,estimated_direct_reads:kind==='count'?1:Math.max(1,documents),time:Date.now()});}catch(e){errors.push(String(e));}});
  await p.route('https://**',r=>r.abort());await p.goto('http://127.0.0.1:8088/Tece-Island/');await p.waitForFunction(()=>!!window.tcChatFixture,null,{timeout:60000});
  await p.evaluate(uid=>tcChatFixture(JSON.stringify({action:'login',uid})),uid);await p.locator('#chat-launch').click();await p.waitForFunction(()=>tcChatSnapshot.ready&&!tcChatSnapshot.reading);
  check(await p.locator('#chat-list li').count()===50,uid+': bounded full history received');clients.push(p);
 }
 phase='idle';const started=Date.now();await clients[0].waitForTimeout(125000);const idleMs=Date.now()-started;
 check(rows.filter(x=>x.phase==='idle'&&x.kind==='count').length>=2,'Natural idle reconciliation uses bounded count');
 check(!rows.some(x=>x.phase==='idle'&&x.kind==='full'),'Stable idle does not reload the full history');
 phase='active';for(let i=0;i<3;i++){
  const n=51+i,t=Date.now();await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'globalMessages/'+n),{sequence:n,uid:'chat-b',nickname:'Beto',text:'Live '+n,sent_at:Timestamp.now()});await setDoc(doc(c.firestore(),'chatRuntime/global'),{sequence:n,sent_at:Timestamp.now()});});
  await Promise.all(clients.map(async(p,index)=>{await p.waitForFunction(n=>document.querySelector('#chat-list').textContent.includes('Live '+n),n,{timeout:20000});latencies.push({index,ms:Date.now()-t});}));await clients[0].waitForTimeout(5200);
 }
 phase='closing';for(const p of clients)await p.getByRole('button',{name:'Recolher',exact:true}).click();for(const p of clients)await p.waitForFunction(()=>!tcChatSnapshot.reading&&tcChatSnapshot.requests===0);phase='closed';await clients[0].waitForTimeout(7000);check(!rows.some(x=>x.phase==='closed'),'Closed panels issue zero requests');
 for(const p of clients){await p.locator('#chat-launch').click();await p.waitForFunction(()=>!tcChatSnapshot.reading);}
 phase='backgrounding';for(const p of clients)await p.evaluate(()=>{window.testHidden=true;Object.defineProperty(document,'hidden',{configurable:true,get:()=>window.testHidden});document.dispatchEvent(new Event('visibilitychange'));});await clients[0].waitForTimeout(1000);phase='hidden';await clients[0].waitForTimeout(7000);check(!rows.some(x=>x.phase==='hidden'),'Background tabs issue zero requests after hide');
 phase='resume';for(const p of clients)await p.evaluate(()=>{window.testHidden=false;document.dispatchEvent(new Event('visibilitychange'));window.dispatchEvent(new Event('focus'));});await clients[0].waitForTimeout(1800);check(rows.some(x=>x.phase==='resume'),'Resume reconciles the current window');
 check(errors.length===0&&rows.every(x=>x.status===200),'No browser or REST errors');
 await writeFile('.tools/chat-beta-budget-results.json',JSON.stringify({measured_at:new Date().toISOString(),environment:'Edge headless and local Firebase demo emulator',billing_measurement:false,physical:false,idle_ms:idleMs,checks,latencies,rows},null,2));
}finally{if(browser)await browser.close();server.kill();await env.cleanup();}

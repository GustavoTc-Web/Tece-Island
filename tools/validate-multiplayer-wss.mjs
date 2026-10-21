// Exercise the production endpoint without obtaining any player's credentials.
import assert from 'node:assert/strict';
import {readFile, writeFile} from 'node:fs/promises';
import {WebSocket} from '../server/node_modules/ws/wrapper.mjs';
const runtime = JSON.parse(await readFile(process.argv[2] || '.tools/mp-runtime.json','utf8'));
const url = runtime.wss;
assert.match(url, /^wss:\/\/[a-z0-9-]+\.trycloudflare\.com\/room$/);
const origin = 'https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site';
const result = {endpoint:url,checks:[],positiveRealAccountLoginTested:false};
const check=(ok,label)=>{assert.ok(ok,label);result.checks.push({pass:true,label});console.log('PASS: '+label);};
function connect(message, expected) {
  return new Promise((resolve,reject)=>{
    const ws=new WebSocket(url,{origin,handshakeTimeout:10000});
    const timer=setTimeout(()=>{ws.terminate();reject(Error('WSS response timeout'));},12000);
    ws.on('open',()=>ws.send(JSON.stringify(message)));
    ws.on('error',()=>{clearTimeout(timer);reject(Error('WSS connection failed'));});
    ws.on('message',bytes=>{
      const data=JSON.parse(bytes);
      if(data.type==='error') {clearTimeout(timer);ws.close();resolve(data.code===expected);}
      else if(data.type==='welcome'||data.type==='state') {clearTimeout(timer);ws.terminate();resolve(false);}
    });
  });
}
try {
  const health=await (await fetch(url.replace('wss://','https://').replace('/room','/health'),{signal:AbortSignal.timeout(10000)})).json();
  check(health.ok&&health.protocol===3&&health.version==='0.9.0-multiplayer-pilot.5','External HTTPS reaches only game service with exact version/protocol');
  const root=await fetch(url.replace('wss://','https://').replace('/room','/'),{signal:AbortSignal.timeout(10000)});
  check(root.status===404,'External tunnel serves no filesystem or other application at root');
  check(await connect({type:'input',seq:1,x:1,y:0},'auth_required'),'External WSS rejects actions without authentication');
  const configuration=JSON.parse(await readFile('config/firebase-public.json','utf8'));
  const allowed=JSON.parse(await readFile(runtime.allowed_uids_file,'utf8')).allowed_uids;
  check(allowed.length===2&&new Set(allowed).size===2,'Production configuration still has exactly the existing two allowed accounts');
  const now=Math.floor(Date.now()/1000), encode=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
  const fakeToken=uid=>`${encode({alg:'none',typ:'JWT'})}.${encode({sub:uid,user_id:uid,aud:configuration.projectId,iss:`https://securetoken.google.com/${configuration.projectId}`,iat:now,exp:now+3600,auth_time:now,email_verified:true,firebase:{sign_in_provider:'password'}})}.`;
  const allowedToken=fakeToken(allowed[0]), outsiderToken=fakeToken('mp-unauthorized-production-probe');
  check(await connect({type:'hello',protocol:3,uid:allowed[0],token:allowedToken},'auth_failed'),'External WSS rejects unsigned token even with allowlisted UID');
  check(await connect({type:'hello',protocol:3,uid:allowed[0],token:outsiderToken},'auth_failed'),'External WSS rejects forged outsider token and claimed allowed UID');
  for(const name of ['production','production-error','tunnel','tunnel-error']) {
    const log=`.tools/${runtime.log_prefix || 'mp'}-${name}.log`;
    const text=await readFile(log,'utf8');
    check(!text.includes(allowedToken)&&!text.includes(outsiderToken)&&!text.includes(allowed[0])&&!text.includes(allowed[1]),`No identity token or UID in ${log}`);
  }
} finally {await writeFile('.tools/multiplayer-wss-results.json',JSON.stringify(result,null,2));}

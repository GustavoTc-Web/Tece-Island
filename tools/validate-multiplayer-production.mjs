// Production verifier/CLI smoke without using any real user's login token.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {readFile, writeFile} from 'node:fs/promises';
import {Client, pause} from '../server/tests/helpers.mjs';
if (!process.env.TECE_ALLOWED_UIDS_FILE) throw Error('Point TECE_ALLOWED_UIDS_FILE at the existing two-account allowlist');
const env = {...process.env, PORT:'8788', TECE_BIND:'127.0.0.1', TECE_ORIGINS:'http://localhost:8060'};
for (const key of ['FIREBASE_AUTH_EMULATOR_HOST','TECE_LOCAL_AUTH_TEST','GOOGLE_APPLICATION_CREDENTIALS','TECE_FIREBASE_PROJECT','TECE_FIREBASE_API_KEY']) delete env[key];
const processServer = spawn(process.execPath, ['server/index.mjs'], {env, windowsHide: true, stdio: ['ignore','pipe','pipe']});
let log = '';
processServer.stdout.on('data', bytes => {log += bytes;});
processServer.stderr.on('data', bytes => {log += bytes;});
const results = [];
const check = (value, label) => {assert.ok(value, label); results.push({pass:true,label}); console.log('PASS: '+label);};
const clients = [];
try {
  for (let i=0;i<100 && !log.includes('listening');i++) {if (processServer.exitCode!==null) throw Error('Server startup failed');await pause(50);}
  const health = await (await fetch('http://127.0.0.1:8788/health')).json();
  check(health.ok && health.protocol===1 && health.version==='0.9.0-multiplayer-pilot.1', 'Actual production CLI starts using only public Firebase config and existing allowlist');
  const anonymous = new Client('ws://127.0.0.1:8788/room'); clients.push(anonymous);
  await anonymous.open(); anonymous.send({type:'input',seq:1,x:1,y:0});
  check((await anonymous.wait(m=>m.type==='error')).code==='auth_required', 'Production server refuses unauthenticated actions');
  const config = JSON.parse(await readFile('config/firebase-public.json','utf8'));
  const allowlist = JSON.parse(await readFile(process.env.TECE_ALLOWED_UIDS_FILE,'utf8'));
  const uid = allowlist.allowed_uids[0], now = Math.floor(Date.now()/1000);
  const claims = {sub:uid,user_id:uid,aud:config.projectId,iss:`https://securetoken.google.com/${config.projectId}`,iat:now,exp:now+3600,auth_time:now,email_verified:true,firebase:{sign_in_provider:'password'}};
  const encode = value=>Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = `${encode({alg:'none',typ:'JWT'})}.${encode(claims)}.`;
  const forged = new Client('ws://127.0.0.1:8788/room'); clients.push(forged);
  check((await forged.hello({token:unsigned,uid})).code==='auth_failed', 'Production SDK rejects unsigned token even with a real allowlisted UID');
  check(log.includes('Firebase verification enabled') && !log.includes('LOCAL EMULATOR'), 'No emulator authentication enabled on production process');
  check(!log.includes(unsigned) && !log.includes(uid), 'Production startup/rejections do not log identity tokens or UIDs');
} finally {
  for(const client of clients) client.ws.terminate();
  processServer.kill();
  await writeFile('.tools/multiplayer-production-results.json',JSON.stringify({results,positiveRealAccountLoginTested:false},null,2));
}

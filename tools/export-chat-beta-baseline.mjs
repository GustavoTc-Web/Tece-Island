// Read-only administrative inspection. Tokens stay in process memory, never output.
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const require=createRequire(import.meta.url),auth=require('firebase-tools/lib/auth.js');
const project='tece-island-285cd',output='.tools/firebase-current';
const account=auth.getGlobalDefaultAccount();
if(!account)throw Error('Faça firebase login --reauth no seu terminal e conclua no navegador. Não envie credenciais pela conversa. Nenhum dado remoto foi alterado.');
const credential=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
const headers={Authorization:'Bearer '+credential.access_token};
async function read(url){const r=await fetch(url,{headers,redirect:'error',signal:AbortSignal.timeout(30000)});if(!r.ok)throw Error('Leitura administrativa recusada: HTTP '+r.status+'. Confira a conta/projeto; nenhuma escrita foi feita.');return r.json();}
const release=await read('https://firebaserules.googleapis.com/v1/projects/'+project+'/releases/cloud.firestore');
if(!new RegExp('^projects/'+project+'/rulesets/[A-Za-z0-9_-]+$').test(release.rulesetName))throw Error('Ruleset inesperado; operação interrompida.');
const ruleset=await read('https://firebaserules.googleapis.com/v1/'+release.rulesetName);
const settings=await read('https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)/documents/chatSettings/global');
if(ruleset.source?.files?.length!==1||typeof ruleset.source.files[0].content!=='string'||!settings.updateTime)throw Error('Exportação inesperada; revise manualmente sem substituir configurações.');
await mkdir(output,{recursive:true});
await writeFile(output+'/firestore.rules',ruleset.source.files[0].content);
await writeFile(output+'/settings.json',JSON.stringify(settings,null,2)+'\n');
await writeFile(output+'/release.json',JSON.stringify({project,checked_at:new Date().toISOString(),ruleset:release.rulesetName,release_updated_at:release.updateTime,rules_sha256:createHash('sha256').update(ruleset.source.files[0].content).digest('hex'),read_only:true},null,2)+'\n');
console.log('Base atual exportada em '+output+'; somente leitura. Tokens e credenciais administrativas não foram gravados.');

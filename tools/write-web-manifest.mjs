import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const read=async p=>JSON.parse(await readFile(p,'utf8'));
const stamp=await read('config/build-public.json'),chat=await read('config/global-chat.json'),sync=await read('config/world-sync.json');
if(stamp.version!=='0.8.2'||!/^[a-f0-9]{40}$/.test(stamp.commit))throw Error('Identificação da versão ausente.');
if(!chat.enabled||!sync.enabled||chat.allowed_uids.length!==2||JSON.stringify([...chat.allowed_uids].sort())!==JSON.stringify([...sync.allowed_uids].sort())||sync.interval_seconds!==120)throw Error('Configuração de rollout divergente.');
const hashes={};for(const name of ['index.pck','index.js','index.wasm'])hashes[name]=createHash('sha256').update(await readFile('build/web/'+name)).digest('hex');
await writeFile('build/web/version.json',JSON.stringify({...stamp,chat_enabled:true,world_sync_enabled:true,allowed_account_count:2,chat_poll_seconds:5,chat_reconcile_seconds:120,world_sync_interval_seconds:120,sha256:hashes},null,2)+'\n');

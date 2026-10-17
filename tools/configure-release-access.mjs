// Build-only rollout. Firebase rules remain the authority; this never writes it.
import {mkdir,writeFile} from 'node:fs/promises';
const raw=process.env.TECE_PILOT_ALLOWED_UIDS||'';
const uids=raw.split(',').map(x=>x.trim()).filter(Boolean);
if(uids.length!==2||new Set(uids).size!==2||uids.some(x=>!/^[A-Za-z0-9_-]{1,128}$/.test(x)))throw Error('Publicação 0.8.2 exige exatamente os dois UIDs já autorizados no piloto. Não usar lista vazia nem liberar todos.');
await mkdir('config',{recursive:true});
await writeFile('config/global-chat.json',JSON.stringify({enabled:true,allowed_uids:uids},null,2)+'\n');
await writeFile('config/world-sync.json',JSON.stringify({enabled:true,allowed_uids:uids,interval_seconds:120},null,2)+'\n');
console.log('Rollout 0.8.2: chat e sincronização restritos a duas contas; nenhum acesso Firebase alterado.');

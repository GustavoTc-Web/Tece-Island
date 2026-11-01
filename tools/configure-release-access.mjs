// Build-only rollout. Firebase rules remain the authority; this never writes it.
import {mkdir,writeFile} from 'node:fs/promises';
const raw=process.env.TECE_PILOT_ALLOWED_UIDS||'';
const uids=raw.split(',').map(x=>x.trim()).filter(Boolean);
if(uids.length!==2||new Set(uids).size!==2||uids.some(x=>!/^[A-Za-z0-9_-]{1,128}$/.test(x)))throw Error('Publicação exige exatamente os dois UIDs já autorizados no piloto. Não usar lista vazia nem liberar todos.');
await mkdir('config',{recursive:true});
const audience=process.env.TECE_CHAT_AUDIENCE||'allowlist';
if(!['allowlist','verified'].includes(audience))throw Error('Invalid chat audience');
const invited=(process.env.TECE_CHAT_ALLOWED_UIDS||'').split(',').map(x=>x.trim()).filter(Boolean);
const chatUids=invited.length?invited:uids;
if(new Set(chatUids).size!==chatUids.length||chatUids.some(x=>!/^[A-Za-z0-9_-]{1,128}$/.test(x))||uids.some(x=>!chatUids.includes(x)))throw Error('Chat must preserve both original accounts and use distinct valid UIDs. World sync is unchanged.');
if(audience==='verified'&&invited.length)throw Error('Verified chat does not use an invitation list; omit TECE_CHAT_ALLOWED_UIDS.');
await writeFile('config/global-chat.json',JSON.stringify({enabled:true,audience,allowed_uids:chatUids},null,2)+'\n');
await writeFile('config/world-sync.json',JSON.stringify({enabled:true,allowed_uids:uids,interval_seconds:120},null,2)+'\n');
console.log('Rollout: chat='+audience+'; world sync keeps its two accounts; no Firebase backend mutation.');

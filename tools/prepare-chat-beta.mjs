// Local preparation only. Never calls Firebase or handles administrative keys.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
const args=process.argv.slice(2),arg=name=>args[args.indexOf(name)+1];
if(!args.includes('--base')||!args.includes('--settings'))throw Error('Use --base EXPORTED_RULES --settings EXPORTED_SETTINGS [--mode verified|allowlist] [--output DIRECTORY]');
const mode=args.includes('--mode')?arg('--mode'):'verified';
if(!['verified','allowlist'].includes(mode))throw Error('Invalid mode');
const base=await readFile(arg('--base'),'utf8'),canonical=await readFile('firestore.rules','utf8');
const normalize=s=>s.replaceAll('\r\n','\n');
const pattern=/    function chatAccess\(\) \{[\s\S]*?\n    \}/g;
const old=[...base.matchAll(pattern)],updated=[...canonical.matchAll(pattern)];
if(old.length!==1||updated.length!==1)throw Error('Expected exactly one chatAccess function');
const before=normalize(base.replace(pattern,'')),after=normalize(canonical.replace(pattern,''));
if(before!==after)throw Error('Rules outside chatAccess differ: review exported production rules; nothing was overwritten');
const settings=JSON.parse(await readFile(arg('--settings'),'utf8'));
if(!settings.fields||!Array.isArray(settings.fields.allowed_uids?.arrayValue?.values)||!/^\d{4}-\d{2}-\d{2}T/.test(settings.updateTime||''))throw Error('Use the exported REST document and updateTime; preserve existing allow/admin lists');
const destination=path.resolve(args.includes('--output')?arg('--output'):'.tools/chat-beta-prepared');
await mkdir(destination,{recursive:true});
await writeFile(path.join(destination,'firestore.rules'),base.replace(pattern,updated[0][0]));
await writeFile(path.join(destination,'firebase.json'),JSON.stringify({firestore:{rules:'firestore.rules'}},null,2)+'\n');
// PATCH ?updateMask.fieldPaths=access_mode ; retain enabled, both UID lists,
// all existing chat data, and optimistic concurrency using this updateTime.
await writeFile(path.join(destination,'settings-patch.rest.json'),JSON.stringify({fields:{access_mode:{stringValue:mode}}},null,2)+'\n');
await writeFile(path.join(destination,'preconditions.json'),JSON.stringify({currentDocument:{updateTime:settings.updateTime},updateMask:{fieldPaths:['access_mode']},rules_sha256:createHash('sha256').update(base).digest('hex'),mode,admin_uids_preserved:true,allowed_uids_preserved:true,world_rules_unchanged:true,applied:false},null,2)+'\n');
console.log('Prepared chatAccess-only rules and access_mode-only PATCH; no remote changes. '+destination);

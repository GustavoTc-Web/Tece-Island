// Prepare a surgical update of EXPORTED current rules. No Firebase writes and
// no settings document/template changes. Everything outside this match stays exact.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
const args=process.argv.slice(2),arg=name=>args[args.indexOf(name)+1];
if(!args.includes('--base'))throw Error('Use --base REGRAS_ATUAIS_EXPORTADAS [--output .tools/chat-profile-update]');
const source=await readFile(arg('--base'),'utf8'),canonical=await readFile('firestore.rules','utf8');
const pattern=/    match \/chatProfiles\/\{uid\} \{[\s\S]*?\n    \}/g;
const blocks=[...source.matchAll(pattern)],expected=[...canonical.matchAll(pattern)];
if(blocks.length!==1||expected.length!==1)throw Error('Exige exatamente um bloco chatProfiles conhecido. Preserve o arquivo e revise manualmente.');
const updated=expected[0][0];
const previous=updated.replace('allow create, update:', 'allow create:').replace('allow delete, list:', 'allow update, delete, list:');
const normalize=s=>s.replaceAll('\r\n','\n');
if(![previous,updated].map(normalize).includes(normalize(blocks[0][0])))throw Error('chatProfiles difere do piloto conhecido; não substituir proteções personalizadas automaticamente.');
const replacement=source.includes('\r\n')?updated.replaceAll('\n','\r\n'):updated;
const result=source.slice(0,blocks[0].index)+replacement+source.slice(blocks[0].index+blocks[0][0].length);
const output=path.resolve(args.includes('--output')?arg('--output'):'.tools/chat-profile-update');
await mkdir(output,{recursive:true});
await writeFile(path.join(output,'firestore.rules'),result);
await writeFile(path.join(output,'firebase.json'),JSON.stringify({firestore:{rules:'firestore.rules'}},null,2)+'\n');
await writeFile(path.join(output,'BASELINE.txt'),'Base exportada: '+path.resolve(arg('--base'))+'\nSomente chatProfiles permite create/update do próprio UID. Nenhum documento chatSettings/global ou save é alterado.\n');
console.log('Regras completas preparadas em '+output+'. Nenhuma alteração remota.');

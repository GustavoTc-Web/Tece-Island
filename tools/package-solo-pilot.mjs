import {cp,mkdir,writeFile,readFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
const source='.tools/solo-pilot-project';
const stamp=JSON.parse(await readFile(path.join(source,'config/build-public.json'),'utf8'));
const chat=JSON.parse(await readFile(path.join(source,'config/global-chat.json'),'utf8'));
const sync=JSON.parse(await readFile(path.join(source,'config/world-sync.json'),'utf8'));
if(stamp.version!=='0.9.0-solo-pilot.1'||stamp.emulated!==false||chat.allowed_uids.length!==2||JSON.stringify(chat.allowed_uids)!==JSON.stringify(sync.allowed_uids))throw Error('Configuração inválida do piloto privado.');
const target=path.resolve('build/tece-island-'+stamp.version);
await mkdir(target,{recursive:true});
await cp('build/solo-pilot',path.join(target,'Tece-Island'),{recursive:true});
const native=path.join(target,'native');await mkdir(path.join(native,'config'),{recursive:true});
for(const name of ['scripts','scenes','assets','web','project.godot','icon.svg'])await cp(path.join(source,name),path.join(native,name),{recursive:true,filter:p=>!p.endsWith('.import')});
for(const name of ['firebase-public.json','world-sync.json','global-chat.json','build-public.json'])await cp(path.join(source,'config',name),path.join(native,'config',name));
await cp('tools/serve-web.mjs',path.join(target,'serve-web.mjs'));
await cp('docs/SOLO_PILOTO.md',path.join(target,'RETESTE.md'));
await writeFile(path.join(target,'BUILD-INFO.json'),JSON.stringify(stamp,null,2)+'\n');
await writeFile(path.join(target,'LEIA-ME.txt'),`Tece-Island ${stamp.version}\nCommit ${stamp.commit}\n\nPiloto privado; publicação oficial preservada. Sem atualização de backend ou faturamento.\nNode.js: node serve-web.mjs 8088 Tece-Island\nPC: http://localhost:8088/Tece-Island/\nCelular na rede local: http://IP-DO-PC:8088/Tece-Island/\nNativo: importar native/project.godot no Godot 4.7.2 e F5.\n\nUse mundos de teste. Saves v5 são migrados com backup para v6.\nA versão oficial 0.8.3 recusa v6; confira RETESTE.md antes de alternar clientes.\nSomente as mesmas duas contas estão liberadas. Reteste físico e de balanceamento pendente.\n`,'utf8');
const files={};
for(const entry of await readdir('build/solo-pilot',{withFileTypes:true})){
 if(entry.isFile()){const bytes=await readFile(path.join('build/solo-pilot',entry.name));files[entry.name]={bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};}
}
await writeFile(path.join(target,'WEB-HASHES.json'),JSON.stringify(files,null,2)+'\n');
console.log(target);

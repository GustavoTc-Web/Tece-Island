// Portable local pilot. Explicit inputs exclude emulation hooks and user saves.
import {cp,mkdir,writeFile,readFile} from 'node:fs/promises';
import path from 'node:path';
const target=path.resolve('build/chat-pilot-bundle');
const stamp=JSON.parse(await readFile('.tools/chat-pilot-project/config/build-public.json','utf8'));
if(stamp.emulated!==false)throw Error('Não empacotar fixture como piloto real.');
await mkdir(target,{recursive:true});
await cp('build/chat-pilot',path.join(target,'Tece-Island'),{recursive:true});
const native=path.join(target,'native');await mkdir(native,{recursive:true});
for(const name of ['scripts','scenes','assets','config','web','project.godot','icon.svg'])await cp(path.join('.tools/chat-pilot-project',name),path.join(native,name),{recursive:true});
await cp('tools/serve-web.mjs',path.join(target,'serve-web.mjs'));
await mkdir(path.join(target,'backend'),{recursive:true});
for(const name of ['firestore.rules','firebase.json','chat-settings.json','chat-settings.rest.json','BASELINE.txt'])await cp(path.join('.tools/chat-backend',name),path.join(target,'backend',name),{recursive:true});
await cp('docs/CHAT_GLOBAL.md',path.join(target,'CHAT_GLOBAL.md'));
await cp('docs/VALIDACAO_CHAT.md',path.join(target,'VALIDACAO_CHAT.md'));
await cp('docs/images',path.join(target,'images'),{recursive:true,filter:source=>!path.extname(source)||path.basename(source).startsWith('chat-')&&!source.endsWith('.import')});
await writeFile(path.join(target,'BUILD-INFO.json'),JSON.stringify(stamp,null,2)+'\n');
await writeFile(path.join(target,'LEIA-ME.txt'),`Tece-Island ${stamp.version}\nCommit: ${stamp.commit}\n\nPiloto privado. Backend do chat ainda depende de configuração e revisão de regras.\nNão publicado e não destinado a substituir a versão pública. Sem cobrança habilitada.\n\nCom Node.js instalado, nesta pasta:\n  node serve-web.mjs 8088 Tece-Island\nPC: http://localhost:8088/Tece-Island/\nCelular na mesma rede: http://IP-DO-PC:8088/Tece-Island/\nGodot nativo: importar native/project.godot no Godot 4.7.2 e F5.\n\nSomente os dois UIDs já configurados no piloto de saves estão liberados no pacote.\nO backend também precisa liberá-los. Administradores não foram configurados.\nOs arquivos em backend/ usam a base da branch de saves; comparar com as regras\natualmente publicadas antes de aplicar. Veja CHAT_GLOBAL.md e VALIDACAO_CHAT.md.\nNão habilitar faturamento, Functions, TTL, SMS ou serviços pagos.\n\nSincronização de mundos desativada neste piloto. Testar com mundos locais de teste.\nTestes físicos de sincronização e teclado mobile continuam pendentes.\n`,'utf8');
console.log('Pacote local preparado em '+target);

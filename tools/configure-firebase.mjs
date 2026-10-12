import {readFile,writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
const base=JSON.parse(await readFile('config/firebase-public.json','utf8'));
const enabled=process.env.FIREBASE_AUTH_ENABLED;
if(enabled&& !['true','false'].includes(enabled))throw Error('FIREBASE_AUTH_ENABLED deve ser true ou false.');
const config={
 enabled:enabled?enabled==='true':base.enabled,
 apiKey:process.env.FIREBASE_API_KEY||base.apiKey||'',
 authDomain:process.env.FIREBASE_AUTH_DOMAIN||base.authDomain||'',
 projectId:process.env.FIREBASE_PROJECT_ID||base.projectId||'',
 continueUrl:process.env.FIREBASE_CONTINUE_URL||base.continueUrl
};
if(typeof config.enabled!=='boolean')throw Error('Configuração enabled inválida.');
const configured=/^AIza[A-Za-z0-9_-]{35}$/.test(config.apiKey)&&/^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(config.authDomain)&&/^[a-z][a-z0-9-]{5,29}$/.test(config.projectId)&&config.continueUrl.startsWith('https://')&&config.continueUrl.endsWith('/Tece-Island/');
if(config.apiKey&&!/^AIza[A-Za-z0-9_-]{35}$/.test(config.apiKey))throw Error('Informe somente a Web API Key pública do Firebase.');
if(config.enabled&&!configured)throw Error('Login obrigatório não pode ser exportado sem a configuração pública completa do Firebase.');
const output=process.argv.includes('--output')?process.argv[process.argv.indexOf('--output')+1]:'config/firebase-public.json';
if(!output)throw Error('Caminho de saída ausente.');
await mkdir(path.dirname(output),{recursive:true});
await writeFile(output,JSON.stringify(config,null,2)+'\n');
console.log(config.enabled?'Firebase obrigatório configurado para exportação.':'Login obrigatório desativado; o modo solo permanece disponível.');

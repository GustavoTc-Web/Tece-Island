import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const profile=`.tools/save-browser-profile-${Date.now()}`;
await mkdir(profile,{recursive:true});
const results=[];
const check=(ok,label)=>{results.push({pass:!!ok,label});console.log(`${ok?'PASS':'FAIL'}: ${label}`);};
const options={executablePath:process.env.BROWSER_EXE||'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,viewport:{width:960,height:540},args:['--enable-unsafe-swiftshader']};
let context;
async function open(){
  context=await chromium.launchPersistentContext(profile,options);
  const page=await context.newPage();await page.goto('http://localhost:8081/Tece-Island/');
  await page.waitForFunction(()=>window.tcLocalProgress&&window.tcState?.menu,null,{timeout:60000});return page;
}
const request=(page,op,key,payload='',claim='')=>page.evaluate(async args=>await new Promise(resolve=>window.tcLocalProgress.request(...args,r=>resolve(JSON.parse(r)))),[op,key,payload,claim]);
const prefix='account/'+createHash('sha256').update('browser-fixture-save-uid').digest('hex');
const key=prefix+'/world/w-browser-test';
const save=JSON.stringify({version:5,owner_uid:'browser-fixture-save-uid',world_id:'w-browser-test',inventory:{slots:[{item:'madeira',quantity:19}],backpack:{},selected:0},player:{health:84},world_seed:318});
try{
  let page=await open();
  check((await request(page,'write',key,save,JSON.stringify({expected:null}))).ok,'Gravação só confirma após concluir transação IndexedDB');
  await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
  check((await request(page,'read',key)).value===save,'Recarregar página mantém os bytes do mundo');
  await context.close();page=await open();
  check((await request(page,'read',key)).value===save,'Fechar navegador e reabrir perfil próprio mantém save');
  const other=await context.newPage();await other.goto('http://localhost:8081/Tece-Island/');await other.waitForFunction(()=>window.tcLocalProgress);
  const next=save.replace('"health":84','"health":92');
  check((await request(page,'write',key,next,JSON.stringify({expected:save}))).ok,'Primeira sessão grava a alteração');
  const stale=await request(other,'write',key,save,JSON.stringify({expected:save}));
  check(!stale.ok&&stale.conflict&&(await request(page,'read',key)).value===next,'Duas abas: sessão antiga não sobrescreve save recente');
  const copies=await request(page,'scan',key+':');
  check(copies.value.some(e=>e.key.includes(':conflict-')&&e.value===save)&&copies.value.some(e=>e.key===key+':backup'&&e.value===save),'Conflito e backup são preservados em armazenamento durável');
  check((await request(page,'scan',prefix+'/world/')).value.some(e=>e.key===key),'Varredura encontra mundo mesmo sem registro no catálogo');
  const second=prefix+'/world/w-second';
  check((await request(page,'read',second)).value===null&&(await request(page,'scan','account/other-uid/world/')).value.length===0,'Dois mundos e contas não compartilham chaves');
  await request(page,'preserve',key,'','before-cloud');
  await request(page,'write',key,save,JSON.stringify({expected:next}));
  await request(page,'preserve',key,'','before-cloud');
  check((await request(page,'read',key+':before-cloud')).value===next,'Backup antes da nuvem é único e conserva a primeira versão');
  check(!(await request(page,'unknown',key)).ok,'Operação inválida nunca retorna sucesso');
  // Actual Godot Web AccountProgress -> BrowserPersistence -> IndexedDB.
  const rect=await page.evaluate(()=>window.tcState.buttons.Continuar),view=await page.evaluate(()=>window.tcState.viewport);
  await page.mouse.click((rect[0]+rect[2]/2)*960/view[0],(rect[1]+rect[3]/2)*540/view[1]);
  await page.waitForFunction(()=>window.tcState.position,null,{timeout:60000});
  const seed='save-browser-'+Date.now();
  await page.evaluate(seed=>window.tcFixture(JSON.stringify({action:'account_probe',seed,phase:'write'})),seed);
  await page.waitForFunction(()=>window.tcState.account_checks?.busy===false,null,{timeout:30000});
  let probe=await page.evaluate(()=>window.tcState.account_checks);
  check(probe.written&&probe.isolated&&probe.imported&&probe.second_import_blocked&&probe.legacy_preserved,'Godot Web salva contas separadas e migra legado uma vez com original preservado');
  await page.reload();await page.waitForFunction(()=>window.tcState?.menu,null,{timeout:60000});
  const button=await page.evaluate(()=>window.tcState.buttons.Continuar),dimensions=await page.evaluate(()=>window.tcState.viewport);
  await page.mouse.click((button[0]+button[2]/2)*960/dimensions[0],(button[1]+button[3]/2)*540/dimensions[1]);
  await page.waitForFunction(()=>window.tcState.position);
  await page.evaluate(seed=>window.tcFixture(JSON.stringify({action:'account_probe',seed,phase:'read'})),seed);
  await page.waitForFunction(()=>window.tcState.account_checks?.busy===false,null,{timeout:30000});
  check((await page.evaluate(()=>window.tcState.account_checks)).isolated,'Godot Web recarrega progresso das mesmas contas após reload');
}finally{if(context)await context.close();}
await writeFile('.tools/save-browser-results.json',JSON.stringify(results,null,2));
if(results.some(r=>!r.pass))process.exitCode=1;

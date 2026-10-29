import {writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
let commit=process.env.GITHUB_SHA||'';
if(!commit){try{commit=execFileSync('git',['-c','safe.directory='+process.cwd().replaceAll('\\','/'),'rev-parse','HEAD'],{encoding:'utf8'}).trim();}catch{}}
if(!/^[a-f0-9]{40}$/.test(commit))commit='desenvolvimento';
await writeFile('config/build-public.json',JSON.stringify({version:'0.9.1-beta-rc.1',commit,save_schema:8,campaign_schema:2,tasks_schema:1,base_release:'0.9.0',multiplayer_available:false,public_solo:true,public_chat:false,public_world_sync:false},null,2)+'\n');

import {writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
let commit=process.env.GITHUB_SHA||'';
if(!commit){try{commit=execFileSync('git',['-c','safe.directory='+process.cwd().replaceAll('\\','/'),'rev-parse','HEAD'],{encoding:'utf8'}).trim();}catch{}}
if(!/^[a-f0-9]{40}$/.test(commit))commit='desenvolvimento';
await writeFile('config/build-public.json',JSON.stringify({version:'0.9.0',commit,save_schema:8,campaign_schema:2,tasks_schema:1,tested_pilot:'0.9.0-solo-pilot.4',tested_pilot_commit:'b3680077a01b5afdfb77a483e385dbb67aa9e1c0'},null,2)+'\n');

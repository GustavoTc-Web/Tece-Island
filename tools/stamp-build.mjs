import {writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
let commit=process.env.GITHUB_SHA||'';
if(!commit){try{commit=execFileSync('git',['-c','safe.directory='+process.cwd().replaceAll('\\','/'),'rev-parse','HEAD'],{encoding:'utf8'}).trim();}catch{}}
if(!/^[a-f0-9]{40}$/.test(commit))commit='desenvolvimento';
await writeFile('config/build-public.json',JSON.stringify({version:'0.9.1-beta.2',commit,save_schema:9,campaign_schema:2,tasks_schema:2,base_release:'0.9.1-beta.1',candidate:false,approved_candidate:'0.9.1-beta.2-rc.1',approved_game_commit:'2738a9f49fb5d390fdb6bbcfec06e2af54aeb358',consolidation_commit:'0edc372942e741c567c03b0d091be9c2350bc7ea',multiplayer_available:false,public_solo:true,public_chat:false,chat_verified_prepared:true,chat_rollout:'original_two_closed_test',firestore_rules_deployed:false,public_world_sync:false},null,2)+'\n');

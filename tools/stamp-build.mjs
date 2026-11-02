import {writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
let commit=process.env.GITHUB_SHA||'';
if(!commit){try{commit=execFileSync('git',['-c','safe.directory='+process.cwd().replaceAll('\\','/'),'rev-parse','HEAD'],{encoding:'utf8'}).trim();}catch{}}
if(!/^[a-f0-9]{40}$/.test(commit))commit='desenvolvimento';
await writeFile('config/build-public.json',JSON.stringify({version:'0.9.1-beta.2-rc.1',commit,save_schema:9,campaign_schema:2,tasks_schema:2,base_release:'0.9.1-beta.1',candidate:true,approved_candidate:'0.9.1-beta-rc.2',approved_game_commit:'7c254c1f8454d768228c171cf6fa040b5eb322dc',consolidation_commit:'17895fc65fa6d4a2a5291eeb8fd1862962d30c66',multiplayer_available:false,public_solo:true,public_chat:false,chat_verified_prepared:true,chat_rollout:'original_two_closed_test',firestore_rules_deployed:false,public_world_sync:false},null,2)+'\n');

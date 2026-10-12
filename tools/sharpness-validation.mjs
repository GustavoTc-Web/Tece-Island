import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {mkdir,writeFile} from 'node:fs/promises';
const phase=process.argv[2]||'before';
await mkdir('.tools/screenshots',{recursive:true});
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const results=[];
try {
 for(const sample of [{name:'desktop',width:960,height:540,dpr:1,touch:false},{name:'phone',width:852,height:393,dpr:3,touch:true}]) {
  const context=await browser.newContext({viewport:{width:sample.width,height:sample.height},deviceScaleFactor:sample.dpr,hasTouch:sample.touch});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  await page.goto('http://localhost:8081/Tece-Island/');
  await page.waitForFunction(()=>window.tcState?.menu&&document.querySelector('#status').style.display==='none',null,{timeout:60000});
  const box=await page.evaluate(()=>window.tcState.buttons['Jogar solo']);
  const x=(box[0]+box[2]/2)*sample.width/960,y=(box[1]+box[3]/2)*sample.height/540;
  if(sample.touch)await page.touchscreen.tap(x,y);else await page.mouse.click(x,y);
  await page.waitForFunction(()=>window.tcState?.position);
  await page.evaluate(()=>window.tcFixture(JSON.stringify({action:'position',x:1152,y:768})));
  await page.waitForTimeout(500);
	  if(phase==='monsters'){await page.evaluate(()=>window.tcFixture(JSON.stringify({action:'monsters'})));await page.waitForTimeout(250);}
  const sizing=await page.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect();return {backing:[c.width,c.height],css:[r.width,r.height],dpr:devicePixelRatio,viewport:window.tcState.viewport};});
  await page.screenshot({path:'.tools/screenshots/sharpness-'+phase+'-'+sample.name+'.png'});
  results.push({...sample,...sizing,errors});
  await context.close();
 }
} finally {await browser.close();}
await writeFile('.tools/sharpness-'+phase+'.json',JSON.stringify(results,null,2));
console.log(JSON.stringify(results));
if(results.some(sample=>sample.errors.length))process.exitCode=1;

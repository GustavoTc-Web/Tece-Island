import {chromium} from '../.tools/browser-test/node_modules/playwright/index.mjs';
import {writeFile} from 'node:fs/promises';
const browser=await chromium.launch({executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',headless:true,args:['--enable-unsafe-swiftshader']});
try {
 const page=await browser.newPage({viewport:{width:852,height:393},hasTouch:true,isMobile:true});
 await page.goto('http://localhost:8080/Tece-Island/');
 await page.waitForFunction(()=>document.querySelector('#status').style.display==='none',null,{timeout:60000});
 await page.evaluate(()=>{window.focusEvents=[];for(const name of ['focusin','focusout'])document.addEventListener(name,e=>focusEvents.push({event:name,tag:e.target.tagName,type:e.target.type||'',disabled:e.target.disabled||false}));});
 await page.touchscreen.tap(350,122);
 await page.waitForTimeout(300);
 const first=await page.evaluate(()=>({focus:document.activeElement.tagName,inputs:[...document.querySelectorAll('input')].map(e=>({disabled:e.disabled,display:e.style.display,type:e.type}))}));
 await page.touchscreen.tap(360,202);
 await page.waitForTimeout(300);
 const second=await page.evaluate(()=>({focus:document.activeElement.tagName,events:focusEvents}));
 await page.touchscreen.tap(380,202);
 await page.waitForTimeout(300);
 const repeated=await page.evaluate(()=>({focus:document.activeElement.tagName,events:focusEvents,disabled:document.querySelector('input').disabled}));
 await writeFile('.tools/login-focus-before.json',JSON.stringify({first,second},null,2));
 console.log(JSON.stringify({first,second,repeated}));
 await page.screenshot({path:'.tools/screenshots/login-before.png'});
}finally{await browser.close();}

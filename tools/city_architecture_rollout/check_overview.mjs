// Local Chromium smoke check and same-camera comparison captures; no server needed.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

const here=path.dirname(fileURLToPath(import.meta.url));
const profile=await fs.mkdtemp(path.join(os.tmpdir(),'dwarf-study-'));
const browser=spawn(process.env.CHROME||'chromium-browser',[
 '--headless=new','--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader',
 '--enable-unsafe-swiftshader','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'
],{stdio:['ignore','ignore','pipe']});
const errors=[],checks=[],captures=[];
class Client{
 constructor(url){this.ws=new WebSocket(url);this.id=0;this.pending=new Map();
  this.ready=new Promise((resolve,reject)=>{this.ws.onopen=resolve;this.ws.onerror=reject});
  this.ws.onmessage=event=>{const m=JSON.parse(event.data);if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);
   if(!m.id)return;const p=this.pending.get(m.id);this.pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result)};
 }
 async send(method,params={}){await this.ready;return new Promise((resolve,reject)=>{const id=++this.id;this.pending.set(id,{resolve,reject});this.ws.send(JSON.stringify({id,method,params}))})}
 async eval(expression){const r=await this.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});
  if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value}
}
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let control;
try{
 const socket=await new Promise((resolve,reject)=>{let log='';browser.stderr.on('data',data=>{log+=data;const m=log.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(m)resolve(m[1])});browser.on('error',reject);browser.on('exit',code=>reject(new Error('Browser exited before ready: '+code+' '+log)))});
 control=new Client(socket);
 const targets=await(await fetch('http://'+new URL(socket).host+'/json/list')).json();
 const page=new Client(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
 await page.send('Page.enable');await page.send('Runtime.enable');

 const check=async(name,expression)=>{assert.equal(await page.eval(expression),true,name);checks.push(name)};
 const catalog=JSON.parse(await fs.readFile(path.join(here,'catalog.json'),'utf8'));
 await page.send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
 await page.send('Page.navigate',{url:'http://127.0.0.1:8875/'});
 await delay(300);
 await check('145 overview cards','document.querySelectorAll(".card").length===145');
 await check('Starts with four representative forms','document.querySelectorAll(".card:not([hidden])").length===4 && document.getElementById("focus").checked');
 await check('Four previous-transfer comparison images','document.querySelectorAll(".previous img").length===4');
 await check('All preview images load','Promise.all([...document.querySelectorAll(".card img")].map(x=>{x.loading="eager";return x.decode()})).then(()=>true)');
 const links=await page.eval('[...document.querySelectorAll(".card")].map(x=>new URL(x.href).searchParams.get("building"))');
 assert.deepEqual([...links].sort(),Object.keys(catalog).sort());checks.push('Every comparison has exactly one valid card link');
 for(const [race,n] of Object.entries({dwarf:28,human:31,elf:22,orc:26,troll:21,undead:17})){
  await page.eval(`document.querySelector('button[data-race="${race}"]').click()`);
  await check(race+' filter',`document.querySelectorAll('.card:not([hidden])').length===${n}`);
 }
 await page.eval('document.querySelector("button[data-race]").click();document.getElementById("attention").click()');
 await check('Seven structural inspection cases','document.querySelectorAll(".card:not([hidden])").length===7');
 await page.eval('document.getElementById("attention").click();document.getElementById("search").value="fish smoker";document.getElementById("search").dispatchEvent(new Event("input"))');
 await check('Building name search','document.querySelectorAll(".card:not([hidden])").length===1');
 await page.eval('document.getElementById("search").value="";document.getElementById("search").dispatchEvent(new Event("input"))');
 await check('154 deferred placement rows, initially collapsed','document.querySelectorAll("tbody tr").length===154 && !document.querySelector("details").open');
 async function shot(file){const r=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});const b=Buffer.from(r.data,'base64');await fs.writeFile(path.join(here,file),b);captures.push({file,sha256:createHash('sha256').update(b).digest('hex')})}
 await page.eval('document.getElementById("focus").click()');
 await check('Focus restores four forms and clears other filters','document.querySelectorAll(".card:not([hidden])").length===4 && !document.getElementById("attention").checked && document.getElementById("search").value===""');
 await shot('overview-desktop.png');
 await page.send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
 await check('Phone overview has no horizontal overflow','document.documentElement.scrollWidth<=innerWidth');
 await page.eval('window.scrollTo(0,document.querySelector("nav").offsetTop)');
 await shot('overview-mobile.png');
 const key=await page.eval('new URL(document.querySelector(".card:not([hidden])").href).searchParams.get("building")');
 await page.eval('document.querySelector(".card:not([hidden])").click()');await delay(300);await page.eval('studyReady');
 await check('Card opens the matching 3D comparison',`study.building===${JSON.stringify(key)}`);
 assert.deepEqual(errors,[]);checks.push('No browser JavaScript exceptions');
 const bytes=await fs.readFile(path.join(here,'index.html'));
 await fs.writeFile(path.join(here,'overview-check.json'),JSON.stringify({page_sha256:createHash('sha256').update(bytes).digest('hex'),checks,captures,errors},null,2)+'\n');
 console.log(`${checks.length} overview checks passed.`);
}finally{
 if(control)await control.send('Browser.close').catch(()=>{});else browser.kill();
 if(browser.exitCode===null)await new Promise(r=>browser.once('exit',r));
 await fs.rm(profile,{recursive:true,force:true});
}

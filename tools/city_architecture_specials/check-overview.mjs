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
const browser=spawn(process.env.CHROME_BIN||'/home/jan/.cache/puppeteer/chrome/linux-151.0.7922.71/chrome-linux64/chrome',[
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
 async function size(width,height){await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await delay(100);await page.eval('window.study?.fit();true')}
 async function check(name,expression){assert.equal(await page.eval(expression),true,name);checks.push(name)}
 async function drag(side){
  const p=await page.eval(`(()=>{const r=document.getElementById('${side}').getBoundingClientRect();return {x:r.x+r.width*.5,y:r.y+r.height*.5}})()`);
  await page.send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...p});
  await page.send('Input.dispatchMouseEvent',{type:'mouseMoved',button:'left',buttons:1,x:p.x+90,y:p.y+20});
  await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,x:p.x+90,y:p.y+20});
 }
 async function shot(file,clip){
  await page.eval('window.study?.fit();true');await delay(70);
  const r=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,...(clip?{clip}: {})});
  const bytes=Buffer.from(r.data,'base64');await fs.writeFile(path.join(here,file),bytes);
  captures.push({file,sha256:createHash('sha256').update(bytes).digest('hex'),page:'overview'});
 }
 await fs.mkdir(path.join(here,'captures'),{recursive:true});
 await size(1500,1000);
 await page.send('Page.navigate',{url:pathToFileURL(path.join(here,'index.html')).href});
 for(let n=0;n<100;n++){if(await page.eval('window.catalogReady===true'))break;await delay(50)}
 const visible='[...document.querySelectorAll(".card")].filter(x=>!x.hidden)';
 await check('All 154 cards present','document.querySelectorAll(".card").length===154');
 await check('Unique card ids','new Set([...document.querySelectorAll(".card")].map(x=>x.id)).size===154');
 await check('All actual images load','Promise.all([...document.querySelectorAll(".card img")].map(x=>{x.loading="eager";return x.decode()})).then(()=>true)');
 await check('All cards link to matching context','[...document.querySelectorAll(".card")].every(x=>new URL(x.querySelector("a").href).searchParams.get("building")===x.id)');
 await check('Completed group is the initial acceptance view',`${visible}.length===138 && ${visible}.every(x=>x.dataset.status==='done')`);
 for(const [status,count] of Object.entries({done:138,pending:0,keep:16})){
  await page.eval(`document.getElementById('status').value='${status}';document.getElementById('status').dispatchEvent(new Event('change'));true`);
  await check('Status group '+status,`${visible}.length===${count} && document.querySelectorAll('.status-group:not([hidden])').length===${count ? 1 : 0}`);
 }
 await page.eval('document.getElementById("status").value="done";document.getElementById("status").dispatchEvent(new Event("change"));true');
 await shot('captures/overview.png');
 await page.eval('document.getElementById("reset").click();true');
 for(const [race,count] of Object.entries({human:30,dwarf:22,elf:24,orc:21,troll:20,undead:37})){
  await page.eval(`document.querySelector('button[data-race="${race}"]').click();true`);
  await check('Culture filter '+race,`${visible}.length===${count} && ${visible}.every(x=>x.dataset.race==='${race}')`);
 }
 await page.eval('document.getElementById("reset").click();document.getElementById("search").value="miners guild";document.getElementById("search").dispatchEvent(new Event("input"));true');
 await check('Search finds six guilds',`${visible}.length===6`);
 await shot('captures/overview-guilds.png');
 await page.eval('document.getElementById("reset").click();document.getElementById("priority").value="Umgesetzt";document.getElementById("priority").dispatchEvent(new Event("change"));true');
 await check('138 completed scenes include remaining special buildings',`${visible}.length===138 && ${visible}.every(x=>x.dataset.status==='done')`);
 await page.eval('document.getElementById("reset").click();document.getElementById("kind").value="treehouse";document.getElementById("kind").dispatchEvent(new Event("change"));true');
 await check('Treehouse filter finds both variants',`${visible}.length===2`);
 await page.eval('document.getElementById("search").value="not-a-building-xyz";document.getElementById("search").dispatchEvent(new Event("input"));true');
 await check('Empty state is visible','!document.getElementById("empty").hidden');
 await page.eval('document.getElementById("reset").click();true');
 await check('Reset restores all cards',`${visible}.length===154`);
 await size(390,844);
 await check('Mobile no overflow','document.documentElement.scrollWidth<=innerWidth');
 await shot('captures/overview-mobile.png');
 assert.deepEqual(errors,[],'Browser JavaScript errors');checks.push('No browser JavaScript exceptions');
 const pageBytes=await fs.readFile(path.join(here,'index.html'));
 await fs.writeFile(path.join(here,'overview-check.json'),JSON.stringify({page_sha256:createHash('sha256').update(pageBytes).digest('hex'),checks,captures,errors},null,2)+'\n');
 console.log(`${checks.length} overview browser checks passed; ${captures.length} captures saved.`);
}finally{
 if(control)await control.send('Browser.close').catch(()=>{});else browser.kill();
 if(browser.exitCode===null)await new Promise(r=>browser.once('exit',r));
 await fs.rm(profile,{recursive:true,force:true});
}

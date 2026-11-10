// Bounded browser verification and review captures for the opening study.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
const folder=path.join(path.dirname(fileURLToPath(import.meta.url)),'intro');
const chrome=process.env.CHROME_BIN||'/home/jan/.cache/puppeteer/chrome/linux-151.0.7922.71/chrome-linux64/chrome';
class CDP{
 constructor(url){this.ws=new WebSocket(url);this.next=0;this.calls=new Map();this.errors=[];this.open=new Promise((resolve,reject)=>{this.ws.addEventListener('open',resolve,{once:true});const fail=()=>{const error=Error('Browser connection closed');reject(error);for(const call of this.calls.values())call.reject(error);this.calls.clear()};this.ws.addEventListener('error',fail);this.ws.addEventListener('close',fail)});this.ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const call=this.calls.get(m.id);if(!call)return;this.calls.delete(m.id);if(m.error)call.reject(Error(JSON.stringify(m.error)));else call.resolve(m.result)}else if(m.method==='Runtime.exceptionThrown')this.errors.push(m.params.exceptionDetails)});}
 async send(method,params={}){await this.open;if(this.ws.readyState!==WebSocket.OPEN)throw Error('Browser connection is not open');return new Promise((resolve,reject)=>{const id=++this.next;this.calls.set(id,{resolve,reject});this.ws.send(JSON.stringify({id,method,params}))})}
 async evaluate(expression){const r=await this.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value}
}

let profile,browser,control,page;
const checks=[];
function check(pass,label){checks.push({pass:!!pass,label});if(!pass)throw Error(label)}
try{
 profile=await fs.mkdtemp(path.join(os.tmpdir(),'grug-intro-review-'));
 browser=spawn(chrome,['--headless=new','--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-gpu-sandbox','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:['ignore','ignore','pipe']});
 let log='';
 const wsURL=await new Promise((resolve,reject)=>{browser.stderr.on('data',data=>{log+=data;const m=log.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(m)resolve(m[1])});browser.once('error',reject);browser.once('exit',code=>reject(Error('Browser exited '+code+': '+log.slice(-1000))))});
 control=new CDP(wsURL);
 const address=new URL(wsURL);const targets=await(await fetch('http://'+address.host+'/json/list')).json();
 page=new CDP(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
 await page.send('Runtime.enable');await page.send('Page.enable');
 async function open(width,height){
  await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
  const loaded=new Promise(resolve=>page.ws.addEventListener('message',function listener(e){if(JSON.parse(e.data).method==='Page.loadEventFired'){page.ws.removeEventListener('message',listener);resolve()}}));
  await page.send('Page.navigate',{url:pathToFileURL(path.join(folder,'preview.html')).href});await loaded;
  await page.evaluate('window.previewReady');
  await page.evaluate('Promise.all([...document.images].map(i=>i.decode())).then(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))))');
 }
 async function shot(name){const r=await page.send('Page.captureScreenshot',{format:'png'});await fs.writeFile(path.join(folder,name+'.png'),Buffer.from(r.data,'base64'))}
 for(const [width,height] of [[1600,1000],[1366,768]]){
  await open(width,height);
  check(await page.evaluate('race===null && cls==="warrior" && document.body.dataset.opening==="true"'),'opening state '+width);
  check(await page.evaluate('getComputedStyle($("classes")).display==="none" && getComputedStyle(document.querySelector(".right")).display==="none"'),'classes and right cards hidden '+width);
  check(await page.evaluate('$("landscape").querySelector("img").naturalWidth===1920'),'real rendered backdrop loaded '+width);
  check(await page.evaluate('document.documentElement.scrollWidth<=innerWidth && document.documentElement.scrollHeight<=innerHeight'),'no page overflow '+width);
  await shot('preview-'+width);
  await page.evaluate('chooseRace("human")');
  check(await page.evaluate('race==="human" && cls==="warrior" && document.body.dataset.opening==="false" && root.visible'),'first click shows warrior '+width);
  check(await page.evaluate('getComputedStyle($("classes")).display!=="none" && getComputedStyle(document.querySelector(".right")).display!=="none"'),'controls restored '+width);
  await page.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
  await shot('selected-'+width);
  await page.evaluate('document.querySelector("[data-class=mage]").click();chooseRace("orc")');
  check(await page.evaluate('cls==="mage" && race==="orc"'),'class preserved cross-faction '+width);
  await page.evaluate('reset()');
  check(await page.evaluate('race==="orc" && document.body.dataset.opening==="false"'),'cannot return to opening '+width);
 }
 check(page.errors.length===0,'no JavaScript errors');
 await fs.writeFile(path.join(folder,'browser-check.json'),JSON.stringify({checks,errors:page.errors},null,2)+'\n');
 console.log(checks.length+' opening checks PASS');
}finally{
 if(page)page.ws.close();
 if(browser?.pid&&browser.exitCode===null&&browser.signalCode===null){const closed=new Promise(resolve=>browser.once('exit',resolve));if(control)await control.send('Browser.close').catch(()=>{});if(browser.exitCode===null&&browser.signalCode===null)browser.kill('SIGTERM');await closed}
 control?.ws.close();if(profile)await fs.rm(profile,{recursive:true,force:true});
}

// Offline browser checks and 1600px review captures; dedicated temporary profile.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
const folder=path.dirname(fileURLToPath(import.meta.url));
const chrome=process.env.CHROME_BIN||'/usr/bin/chromium-browser';
class CDP{
 constructor(url){this.ws=new WebSocket(url);this.next=0;this.calls=new Map();this.errors=[];this.open=new Promise((resolve,reject)=>{this.ws.addEventListener('open',resolve,{once:true});const fail=()=>{const error=Error('Browser connection closed');reject(error);for(const call of this.calls.values())call.reject(error);this.calls.clear()};this.ws.addEventListener('error',fail);this.ws.addEventListener('close',fail)});this.ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const call=this.calls.get(m.id);if(!call)return;this.calls.delete(m.id);if(m.error)call.reject(Error(JSON.stringify(m.error)));else call.resolve(m.result)}else if(m.method==='Runtime.exceptionThrown')this.errors.push(m.params.exceptionDetails);else if(m.method==='Runtime.consoleAPICalled'&&m.params.type==='error')this.errors.push(m.params);else if(m.method==='Log.entryAdded'&&m.params.entry.level==='error')this.errors.push(m.params.entry)});}
 async send(method,params={}){await this.open;if(this.ws.readyState!==WebSocket.OPEN)throw Error('Browser connection is not open');return new Promise((resolve,reject)=>{const id=++this.next;this.calls.set(id,{resolve,reject});this.ws.send(JSON.stringify({id,method,params}))})}
 async evaluate(expression){const r=await this.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value}
}
let profile,browser,control,page;
const checks=[],captures=[];
function check(pass,label){checks.push({pass:!!pass,label});if(!pass)throw Error(label)}
const hash=b=>createHash('sha256').update(b).digest('hex');
try{
 profile=await fs.mkdtemp(path.join(os.tmpdir(),'grug-wide-review-'));
 browser=spawn(chrome,['--headless=new','--no-sandbox','--disable-dev-shm-usage','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{detached:true,env:{...process.env,XDG_CONFIG_HOME:profile,XDG_CACHE_HOME:profile,XDG_DATA_HOME:profile},stdio:['ignore','ignore','pipe']});
 let log='';
 const wsURL=await new Promise((resolve,reject)=>{browser.stderr.on('data',data=>{log+=data;const m=log.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(m)resolve(m[1])});browser.once('error',reject);browser.once('exit',code=>reject(Error('Browser exited '+code+': '+log.slice(-1000))))});
 control=new CDP(wsURL);
 const address=new URL(wsURL),targets=await(await fetch('http://'+address.host+'/json/list')).json();
 page=new CDP(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
 await page.send('Runtime.enable');await page.send('Page.enable');await page.send('Log.enable');
 await page.send('Emulation.setDeviceMetricsOverride',{width:1600,height:1120,deviceScaleFactor:1,mobile:false});
 const loaded=new Promise((resolve,reject)=>{page.ws.addEventListener('close',()=>reject(Error('Browser closed during load')),{once:true});page.ws.addEventListener('message',function listener(e){if(JSON.parse(e.data).method==='Page.loadEventFired'){page.ws.removeEventListener('message',listener);resolve()}})});
 await page.send('Page.navigate',{url:pathToFileURL(path.join(folder,'index.html')).href});await loaded;
 const settle=()=>page.evaluate('previewReady().then(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))))');
 for(const race of ['human','dwarf','elf','orc','troll','undead']){
  await page.evaluate(`chooseRace(${JSON.stringify(race)})`);await settle();
  check(await page.evaluate(`currentRace===${JSON.stringify(race)}&&[...document.querySelectorAll('.stage>img')].every(i=>i.naturalWidth===2560&&i.naturalHeight===1440)&&document.getElementById('game').naturalWidth===1540`),'source images loaded '+race);
  await page.evaluate('document.querySelectorAll("details").forEach(d=>d.open=true)');
  check(await page.evaluate('(()=>{const a=document.querySelector(".size1366").getBoundingClientRect(),b=document.querySelector(".size2560").getBoundingClientRect();return a.width===1366&&a.height===768&&b.width===2560&&b.height===1440})()'),'both requested display sizes '+race);
  check(await page.evaluate('(()=>{const s=document.querySelector(".overview").getBoundingClientRect(),a=document.querySelector(".overview .anchor").getBoundingClientRect(),f=DATA[currentRace].figure;return Math.abs(a.x+a.width/2-s.x-s.width*f.x)<.1&&Math.abs(a.y+a.height/2-s.y-s.height*f.y)<.1})()'),'anchor placement '+race);
  for(const name of ['overlay','figure']){
   await page.evaluate(`document.getElementById('${name}').click()`);
   check(await page.evaluate(`getComputedStyle(document.querySelector('.overview .${name==='overlay'?'layout':'figure'}')).display==='none'`),'hide '+name+' '+race);
   await page.evaluate(`document.getElementById('${name}').click()`);
   check(await page.evaluate(`getComputedStyle(document.querySelector('.overview .${name==='overlay'?'layout':'figure'}')).display!=='none'`),'show '+name+' '+race);
  }
  await page.evaluate('document.querySelectorAll("details").forEach(d=>d.open=false);scrollTo(0,0)');await settle();
  check(await page.evaluate('document.documentElement.scrollWidth<=1600'),'no page overflow '+race);
  const shot=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
  const png=Buffer.from(shot.data,'base64'),name='preview-'+race+'.png';
  await fs.writeFile(path.join(folder,name),png);captures.push({name,sha256:hash(png),width:1600,height:1120});
 }
 check(page.errors.length===0,'no JavaScript or console errors');
 await fs.writeFile(path.join(folder,'browser-check.json'),JSON.stringify({checks,errors:page.errors,captures,page_sha256:hash(await fs.readFile(path.join(folder,'index.html'))),browser:await page.evaluate('navigator.userAgent')},null,2)+'\n');
 console.log(checks.length+' checks PASS, '+captures.length+' captures');
}finally{
 if(page)page.ws.close();
 if(browser?.pid){const closed=browser.exitCode!==null||browser.signalCode!==null?Promise.resolve():new Promise(resolve=>browser.once('exit',resolve));if(control)control.send('Browser.close').catch(()=>{});let timer;await Promise.race([closed,new Promise(resolve=>{timer=setTimeout(resolve,5000)})]);clearTimeout(timer);try{process.kill(-browser.pid,'SIGKILL')}catch(error){if(error.code!=='ESRCH')throw error}await closed}
 control?.ws.close();if(profile)await fs.rm(profile,{recursive:true,force:true});
}

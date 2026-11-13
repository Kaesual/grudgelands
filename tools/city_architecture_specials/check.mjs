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
  await page.eval('study.fit();true');await delay(70);
  const r=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,...(clip?{clip}: {})});
  const bytes=Buffer.from(r.data,'base64');await fs.writeFile(path.join(here,file),bytes);
  captures.push({file,sha256:createHash('sha256').update(bytes).digest('hex'),building:await page.eval('study.building')});
 }
 await fs.mkdir(path.join(here,'captures'),{recursive:true});
 await size(1200,950);
 await page.send('Page.navigate',{url:pathToFileURL(path.join(here,'viewer.html')).href});
 for(let n=0;n<100;n++){if(await page.eval('typeof window.studyReady!=="undefined"'))break;await delay(50)}
 await page.eval('studyReady');
 const coupled='Object.keys(study.views.before.pose()).every(k=>study.views.before.pose()[k].every((x,i)=>Math.abs(x-study.views.after.pose()[k][i])<1e-8))';
 await check('Every context has a viewer scene','Object.keys(D.buildings).length===154 && Object.keys(D.scenes).length===308');
 const keys=await page.eval('Object.keys(D.buildings).sort((a,b)=>Number(D.buildings[b].implemented)-Number(D.buildings[a].implemented))');
 let shrine;
 for(const key of keys){
  await page.eval(`document.getElementById('angle').value='corner';study.showBuilding(${JSON.stringify(key)})`);
  await check(key+': visible geometry','study.views.after.data.n>0');
  await check(key+': full building fits',`(()=>{const s=D.buildings[study.building],v=study.views.after;v.camera.updateMatrixWorld(true);let m=0;for(const x of [s.bounds[0]-.5,s.bounds[3]+.5])for(const y of [s.bounds[1]-.5,s.bounds[4]+.5])for(const z of [s.bounds[2]-.5,s.bounds[5]+.5]){const p=new THREE.Vector3(x,y,-z).project(v.camera);m=Math.max(m,Math.abs(p.x),Math.abs(p.y))}return m<.9 && m>.65})()`);
  await check(key+': materials load','Promise.all([...document.querySelectorAll(".swatch img")].map(x=>x.decode())).then(()=>true)');
  await check(key+': honest view mode','document.body.classList.contains("single")===!D.buildings[study.building].implemented');
  const spec=await page.eval('D.buildings[study.building]');
  const clip=await page.eval('(()=>{const r=document.getElementById("after").getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,scale:1}})()');
  await shot('captures/'+key+'.png',clip);
  if(spec.implemented){
   const beforeClip=await page.eval('(()=>{const r=document.getElementById("before").getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,scale:1}})()');
   await shot('captures/'+key+'-before.png',beforeClip);
   await shot('captures/'+key+'-pair.png');
   await check(key+': actual material changes','D.buildings[study.building].changed_cells>0');
   if(!key.includes('moon_shrine'))continue;
   shrine=key;await shot('captures/shrine-pair.png');
   await drag('before');await check('Shrine cameras stay coupled',coupled);
   for(const angle of ['front','back','inside']){
    await page.eval(`document.getElementById('angle').value='${angle}';document.getElementById('angle').dispatchEvent(new Event('change'));true`);
    await shot('captures/shrine-'+angle+'.png');
   }
  }
  console.log(key+': captured');
 }
 await size(390,844);
 await page.eval(`study.showBuilding(${JSON.stringify(shrine)})`);
 await check('Phone width has no overflow','document.documentElement.scrollWidth<=innerWidth');
 await check('Phone displays shrine proposal','document.getElementById("after").clientWidth>0');
 await shot('captures/mobile.png');
 await page.eval(`study.showBuilding(${JSON.stringify(await page.eval('Object.keys(D.buildings).find(k=>!D.buildings[k].implemented)'))})`);
 await check('Phone displays single existing building','document.body.classList.contains("single") && document.getElementById("after").clientWidth>0');
 await check('Phone width with single building','document.documentElement.scrollWidth<=innerWidth');
 await size(1200,950);
 await page.send('Page.navigate',{url:pathToFileURL(path.join(here,'viewer.html')).href+'?building='+encodeURIComponent(shrine)});
 await delay(250);await page.eval('studyReady');
 await check('Direct shrine link restores selection',`study.building===${JSON.stringify(shrine)}`);
 assert.deepEqual(errors,[],'Browser JavaScript errors');checks.push('No browser JavaScript exceptions');
 const pageBytes=await fs.readFile(path.join(here,'viewer.html'));
 await fs.writeFile(path.join(here,'browser-check.json'),JSON.stringify({page_sha256:createHash('sha256').update(pageBytes).digest('hex'),checks,captures,errors},null,2)+'\n');
 console.log(`${checks.length} browser checks passed; ${captures.length} captures saved.`);
}finally{
 if(control)await control.send('Browser.close').catch(()=>{});else browser.kill();
 if(browser.exitCode===null)await new Promise(r=>browser.once('exit',r));
 await fs.rm(profile,{recursive:true,force:true});
}

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
 async function size(width,height){await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await delay(100);await page.eval('window.study?.fit();true')}
 async function check(name,expression){assert.equal(await page.eval(expression),true,name);checks.push(name)}
 async function drag(side){
  const p=await page.eval(`(()=>{const r=document.getElementById('${side}').getBoundingClientRect();return {x:r.x+r.width*.5,y:r.y+r.height*.5}})()`);
  await page.send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...p});
  await page.send('Input.dispatchMouseEvent',{type:'mouseMoved',button:'left',buttons:1,x:p.x+90,y:p.y+20});
  await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,x:p.x+90,y:p.y+20});
 }
 async function shot(name){await page.eval('study.fit();true');await delay(100);const r=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});const bytes=Buffer.from(r.data,'base64');await fs.writeFile(path.join(here,name),bytes);captures.push({file:name,sha256:createHash('sha256').update(bytes).digest('hex'),state:await page.eval('({building:study.building,camera:study.views.before.pose(),cut:study.views.before.filter.cut,width:innerWidth,height:innerHeight})')})}
 await size(1600,1150);
 await page.send('Page.navigate',{url:pathToFileURL(path.join(here,'index.html')).href});
 for(let n=0;n<100;n++){if(await page.eval('typeof window.studyReady!=="undefined"'))break;await delay(50)}
 await page.eval('studyReady');
 const coupled='Object.keys(study.views.before.pose()).every(k=>study.views.before.pose()[k].every((x,i)=>Math.abs(x-study.views.after.pose()[k][i])<1e-8))';
 await check('Offline page: six cultures, twelve buildings, twenty-four scenes', 'document.querySelectorAll("canvas").length===2 && Object.keys(D.scenes).length===24 && Object.keys(D.buildings).length===12 && document.querySelectorAll("[data-culture]").length===6');
 const keys=await page.eval('Object.keys(D.buildings)');
 for(const key of keys){
  await page.eval(`document.getElementById('angle').value='corner';study.showBuilding(${JSON.stringify(key)})`);
  await check(key+': equal occupied cells', 'study.views.before.data.n>100 && study.views.before.data.n===study.views.after.data.n');
  await check(key+': all layers shown, including tall roofs', '+document.getElementById("cut").max===D.buildings[study.building].max_y && study.views.before.filter.cut===D.buildings[study.building].max_y && study.views.after.filter.cut===D.buildings[study.building].max_y');
  await check(key+': swatches decode', 'Promise.all([...document.querySelectorAll(".swatch img")].map(x=>x.decode())).then(()=>true)');
  await check(key+': active culture, building and URL match', 'document.querySelector("[data-culture][aria-pressed=true]").dataset.culture===D.buildings[study.building].race && document.querySelector("[data-building][aria-pressed=true]").dataset.building===study.building && new URL(location.href).searchParams.get("building")===study.building');
  await shot(key+'.png');
  await drag('before');await check(key+': camera coupling left to right',coupled);
  await drag('after');await check(key+': camera coupling right to left',coupled);
  for(const angle of ['front','gable','back','inside']){
   await page.eval(`document.getElementById('angle').value=${JSON.stringify(angle)};document.getElementById('angle').dispatchEvent(new Event('change'));true`);
   await check(key+': paired '+angle+' cameras',coupled);
  }
  await check(key+': interior cut follows its floor', 'study.views.before.filter.cut===D.buildings[study.building].inside_cut && study.views.after.filter.cut===D.buildings[study.building].inside_cut');
  if(key==='forge'||key==='troll_home')await shot(key+'-interior.png');
 }
 // Exercise the navigation controls themselves as well as the scene API.
 await page.eval('document.getElementById("angle").value="corner";document.querySelector("[data-culture=human]").click();true');
 await check('Culture button selects its first building','study.building==="human_home"');
 await page.eval('document.querySelector("[data-building=human_hall]").click();true');
 await check('Building button selects its scene','study.building==="human_hall"');
 await page.eval('study.showBuilding("forge")');
 const point=await page.eval('(()=>{const r=document.getElementById("after").getBoundingClientRect();return {x:r.x+r.width*.5,y:r.y+r.height*.56}})()');
 await page.send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...point});
 await page.send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...point});
 await check('Click inspector reports the rendered node', 'document.getElementById("picked").textContent.includes(":")');
 await page.eval('study.setCut(0);true');
 await check('Layer slider changes both scenes','study.views.before.filter.cut===0 && study.views.after.filter.cut===0');
 await page.eval('study.showBuilding("human_home")');
 await size(760,1100);
 await check('Narrow layout: proposal visible, no horizontal overflow','document.getElementById("after").clientWidth>0 && document.getElementById("before").clientWidth===0 && document.documentElement.scrollWidth<=innerWidth');
 await page.eval('document.querySelector("[data-side=before]").click();true');
 await check('Narrow comparison switches to original','document.getElementById("before").clientWidth>0 && document.getElementById("after").clientWidth===0');
 await page.eval('document.querySelector("[data-side=after]").click();true');
 await shot('mobile.png');
 await size(390,844);
 await page.eval('study.showBuilding("human_hall")');
 await check('Phone layout: no horizontal overflow, taller building fully enabled','document.documentElement.scrollWidth<=innerWidth && study.views.after.filter.cut===D.buildings.human_hall.max_y');
 await size(1600,1150);
 await check('Resize restores correct canvas aspect ratios','Object.entries(study.views).every(([k,v])=>Math.abs(v.camera.aspect-document.getElementById(k).clientWidth/document.getElementById(k).clientHeight)<0.001)');
 // A cold load must work for a link to a new culture too.
 await page.send('Page.navigate',{url:pathToFileURL(path.join(here,'index.html')).href+'?building=elf_home'});
 await delay(200);
 await page.eval('studyReady');
 await check('Direct link opens its intended culture and building','study.building==="elf_home" && document.querySelector("[data-culture=elf]").getAttribute("aria-pressed")==="true"');
 assert.deepEqual(errors,[],'Browser JavaScript errors');checks.push('No browser JavaScript exceptions');
 const pageBytes=await fs.readFile(path.join(here,'index.html'));
 await fs.writeFile(path.join(here,'browser-check.json'),JSON.stringify({page_sha256:createHash('sha256').update(pageBytes).digest('hex'),checks,captures,errors},null,2)+'\n');
 console.log(`${checks.length} browser checks passed; ${captures.length} captures saved.`);
}finally{
 if(control)await control.send('Browser.close').catch(()=>{});else browser.kill();
 if(browser.exitCode===null)await new Promise(r=>browser.once('exit',r));
 await fs.rm(profile,{recursive:true,force:true});
}

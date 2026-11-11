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
 async function shot(file,clip){
  await page.eval('study.fit();true');await delay(70);
  const r=await page.send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,...(clip?{clip}: {})});
  const bytes=Buffer.from(r.data,'base64');await fs.writeFile(path.join(here,file),bytes);
  captures.push({file,sha256:createHash('sha256').update(bytes).digest('hex'),building:await page.eval('study.building')});
 }
 await fs.mkdir(path.join(here,'captures'),{recursive:true});
 await size(1200,950);
 await page.send('Page.navigate',{url:pathToFileURL(path.join(here,'compare.html')).href});
 for(let n=0;n<100;n++){if(await page.eval('typeof window.studyReady!=="undefined"'))break;await delay(50)}
 await page.eval('studyReady');
 const coupled='Object.keys(study.views.before.pose()).every(k=>study.views.before.pose()[k].every((x,i)=>Math.abs(x-study.views.after.pose()[k][i])<1e-8))';
 await check('All catalog buildings have two scenes','Object.keys(D.scenes).length===Object.keys(D.buildings).length*2 && Object.keys(D.buildings).length>12');
 const focus=process.argv.includes('--focus');
 const allKeys=await page.eval('Object.keys(D.buildings)');
 const focusNames=['dawnmere__dawnmere_lane_cottage','dawnmere__dawnmere_harvest_inn','highcourt__highcourt_service_store','dur_brannoc__dur_brannoc_lane_house','kapok__kapok_elder_stilt','kezamba__kezamba_shore_store','sunscar__sunscar_bone_lodge','nhal_veyr__nhal_veyr_lane_house','lethariel__dur_brannoc_plaza_house','gor_drazhak__gor_drazhak_warren_round_lodge','dawnmere__dawnmere_smithy'];
 const keys=focus?allKeys.filter(k=>focusNames.includes(k)):allKeys;
 const byRace=new Set();let referenceKey;
 for(const key of keys){
  await page.eval(`document.getElementById('angle').value='corner';study.showBuilding(${JSON.stringify(key)})`);
  await check(key+': same occupied geometry','study.views.before.data.n>100 && study.views.before.data.n===study.views.after.data.n');
  await check(key+': loaded textures','Promise.all([...document.querySelectorAll(".swatch img")].map(x=>x.decode())).then(()=>true)');
  await check(key+': selection and full height','document.getElementById("buildings").value===study.building && new URL(location.href).searchParams.get("building")===study.building && study.views.after.filter.cut===D.buildings[study.building].max_y');
  const spec=await page.eval('D.buildings[study.building]');
  const clip=await page.eval('(()=>{const r=document.getElementById("after").getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,scale:1}})()');
  await shot('captures/'+key+'.png',clip);
  if(focusNames.includes(key)||spec.attention||spec.reference){await shot('captures/'+key+'-pair.png');}
  if(!byRace.has(spec.race)||spec.attention){
   await drag('before');await check(key+': mouse camera coupling',coupled);
   for(const angle of ['front','gable','back','inside']){
    await page.eval(`document.getElementById('angle').value=${JSON.stringify(angle)};document.getElementById('angle').dispatchEvent(new Event('change'));true`);
    await check(key+': paired '+angle,coupled);
   }
   await check(key+': floor-relative cut','study.views.after.filter.cut===D.buildings[study.building].inside_cut');
   byRace.add(spec.race);
  }
  if(spec.reference==='human_home')referenceKey=key;
 }
 await page.eval(`document.getElementById('angle').value='corner';study.showBuilding(${JSON.stringify(referenceKey)})`);
 await size(390,844);
 await check('Phone width: no overflow','document.documentElement.scrollWidth<=innerWidth');
 await check('Phone starts on proposal','document.getElementById("after").clientWidth>0 && document.getElementById("before").clientWidth===0');
 await page.eval('document.querySelector("[data-side=before]").click();true');
 await check('Phone switches to original','document.getElementById("before").clientWidth>0 && document.getElementById("after").clientWidth===0');
 await shot('captures/mobile.png');
 await size(1200,950);
 await page.eval('document.querySelector("[data-culture=elf]").click();true');
 await check('Culture navigation selects an elf building','D.buildings[study.building].race==="elf"');
 await page.eval('document.getElementById("buildings").selectedIndex=1;document.getElementById("buildings").dispatchEvent(new Event("change"));true');
 await check('Building dropdown changes the selection','document.getElementById("buildings").value===study.building');
 await page.send('Page.navigate',{url:pathToFileURL(path.join(here,'compare.html')).href+'?building='+encodeURIComponent(referenceKey)});
 await delay(250);await page.eval('studyReady');
 await check('Direct link restores selection',`study.building===${JSON.stringify(referenceKey)}`);
 assert.deepEqual(errors,[],'Browser JavaScript errors');checks.push('No browser JavaScript exceptions');
 const pageBytes=await fs.readFile(path.join(here,'compare.html'));
 await fs.writeFile(path.join(here,focus?'focus-check.json':'browser-check.json'),JSON.stringify({page_sha256:createHash('sha256').update(pageBytes).digest('hex'),checks,captures,errors},null,2)+'\n');
 console.log(`${checks.length} browser checks passed; ${captures.length} captures saved.`);
}finally{
 if(control)await control.send('Browser.close').catch(()=>{});else browser.kill();
 if(browser.exitCode===null)await new Promise(r=>browser.once('exit',r));
 await fs.rm(profile,{recursive:true,force:true});
}

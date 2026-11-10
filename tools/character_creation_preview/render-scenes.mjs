// Render the saved scenes once through the existing web renderer, using a
// separate headless browser profile. No server or game world is involved.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';

const args=process.argv.slice(2),option=name=>{const n=args.indexOf(name);return n<0?null:args[n+1]};
const folder=option('--directory')||path.dirname(fileURLToPath(import.meta.url));
const chrome=option('--chrome')||process.env.CHROME_BIN||'/home/jan/.cache/puppeteer/chrome/linux-151.0.7922.71/chrome-linux64/chrome';
const width=Number(option('--width')||1200),height=Number(option('--height')||1400),only=option('--race');
if(!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1)throw Error('Invalid capture dimensions');
const html=await fs.readFile(path.join(folder,'scenes.html'),'utf8');
const payload=JSON.parse(html.match(/<script id="payload" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const races=only?[only]:Object.keys(payload.scenes);
for(const race of races)if(!payload.scenes[race])throw Error('Unknown race '+race);
const hash=b=>createHash('sha256').update(b).digest('hex');
const output=path.join(folder,'renders');await fs.mkdir(output,{recursive:true});
const pending=[];
for(const race of races){
 let fresh=false;
 try{const receipt=JSON.parse(await fs.readFile(path.join(output,race+'.json'),'utf8'));const png=await fs.readFile(path.join(output,race+'.png'));fresh=receipt.input===payload.scenes[race].digest&&receipt.width===width&&receipt.height===height&&receipt.output===hash(png)}catch{}
 if(fresh)console.log(race+': saved render is current');else pending.push(race);
}
if(!pending.length)process.exit(0);
class CDP{
 constructor(url){this.ws=new WebSocket(url);this.next=0;this.calls=new Map();this.errors=[];this.open=new Promise((resolve,reject)=>{this.ws.addEventListener('open',resolve,{once:true});const fail=()=>{const error=Error('Browser connection closed');reject(error);for(const call of this.calls.values())call.reject(error);this.calls.clear()};this.ws.addEventListener('error',fail);this.ws.addEventListener('close',fail)});this.ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const call=this.calls.get(m.id);if(!call)return;this.calls.delete(m.id);if(m.error)call.reject(Error(JSON.stringify(m.error)));else call.resolve(m.result)}else if(m.method==='Runtime.exceptionThrown')this.errors.push(m.params.exceptionDetails)});}
 async send(method,params={}){await this.open;if(this.ws.readyState!==WebSocket.OPEN)throw Error('Browser connection is not open');return new Promise((resolve,reject)=>{const id=++this.next;this.calls.set(id,{resolve,reject});this.ws.send(JSON.stringify({id,method,params}))})}
 async evaluate(expression){const r=await this.send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value}
}
let profile,browser,control,page;
try{
 profile=await fs.mkdtemp(path.join(os.tmpdir(),'grug-creation-scenes-'));
 browser=spawn(chrome,['--headless=new','--no-sandbox','--disable-dev-shm-usage','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-gpu-sandbox','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:['ignore','ignore','pipe']});
 let log='';
 const wsURL=await new Promise((resolve,reject)=>{browser.stderr.on('data',data=>{log+=data;const m=log.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(m)resolve(m[1])});browser.once('error',reject);browser.once('exit',code=>reject(Error('Browser exited '+code+': '+log.slice(-2000))))});
 control=new CDP(wsURL);
 const address=new URL(wsURL);const targets=await(await fetch('http://'+address.host+'/json/list')).json();
 page=new CDP(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
 await page.send('Runtime.enable');await page.send('Page.enable');
 await page.send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
 const loaded=new Promise((resolve,reject)=>{page.ws.addEventListener('close',()=>reject(Error('Browser closed while loading scene')),{once:true});page.ws.addEventListener('message',function listener(e){if(JSON.parse(e.data).method==='Page.loadEventFired'){page.ws.removeEventListener('message',listener);resolve()}})});
 await page.send('Page.navigate',{url:pathToFileURL(path.join(folder,'scenes.html')).href});await loaded;await page.evaluate('window.sceneReady');
 for(const race of pending){
  console.log(race+': building shared-renderer geometry');
  const receipt=await page.evaluate(`selectScene(${JSON.stringify(race)},${width},${height})`);
  const encoded=await page.evaluate('view.step(0);view.renderer.domElement.toDataURL("image/png").split(",")[1]');
  const png=Buffer.from(encoded,'base64');
  if(page.errors.length)throw Error(JSON.stringify(page.errors));
  await fs.writeFile(path.join(output,race+'.png'),png);
  await fs.writeFile(path.join(output,race+'.json'),JSON.stringify({input:payload.scenes[race].digest,output:hash(png),width,height,camera:receipt.camera,cells:receipt.cells,renderer:'tools/building_templates/viewer/renderer.js',browser:await page.evaluate('navigator.userAgent')},null,2)+'\n');
  console.log(race+': saved '+png.length+' bytes');
 }
}finally{
 if(page)page.ws.close();
 if(browser?.pid&&browser.exitCode===null&&browser.signalCode===null){
  const closed=new Promise(resolve=>browser.once('exit',resolve));
  if(control)await control.send('Browser.close').catch(()=>{});
  if(browser.exitCode===null&&browser.signalCode===null)browser.kill('SIGTERM');
  await closed;
 }
 control?.ws.close();
 if(profile)await fs.rm(profile,{recursive:true,force:true});
}

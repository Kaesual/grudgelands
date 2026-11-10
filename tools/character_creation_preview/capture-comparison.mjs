// Use the dedicated preview browser on port 9237, after browser-check.mjs.
// Capture the preserved baseline with the same appearance, plus the scene's
// actual reference geometry. This never connects to a game or player browser.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
const folder=path.dirname(fileURLToPath(import.meta.url));
const tabs=await(await fetch('http://127.0.0.1:9237/json/list')).json();
const socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
await new Promise(r=>socket.addEventListener('open',r,{once:true}));
let next=0;const pending=new Map(),errors=[];
socket.addEventListener('message',e=>{const x=JSON.parse(e.data);if(x.id){const p=pending.get(x.id);pending.delete(x.id);x.error?p.reject(Error(JSON.stringify(x.error))):p.resolve(x.result)}else if(x.method==='Runtime.exceptionThrown')errors.push(x.params.exceptionDetails)});
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++next;pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}))})}
async function js(expression){const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value}
async function navigate(name){
 const loaded=new Promise(resolve=>{socket.addEventListener('message',function listener(e){if(JSON.parse(e.data).method==='Page.loadEventFired'){socket.removeEventListener('message',listener);resolve()}})});
 await send('Page.navigate',{url:pathToFileURL(path.join(folder,name)).href});await loaded;
}
try{
 await send('Runtime.enable');await send('Page.enable');
 await send('Emulation.setDeviceMetricsOverride',{width:1600,height:1000,deviceScaleFactor:1,mobile:false});
 await navigate('preview-before.html');await js('window.previewReady');
 await js('chooseRace("human")');
 await js('look={tone:0,hair:0,style:0,eyes:0,feature:0};controls();skin();new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
 const before=await send('Page.captureScreenshot',{format:'png'});
 await fs.writeFile(path.join(folder,'preview-human-before.png'),Buffer.from(before.data,'base64'));
 await navigate('scenes.html');await js('window.sceneReady');
 for(const race of ['human','dwarf','elf','orc','troll','undead']){
  await js(`selectScene(${JSON.stringify(race)},1200,1400)`);
  const hidden=await js('!reference.visible');
  const pixels=await js('(()=>{const maps=new Set();view.root.traverse(o=>{if(o.material?.map)maps.add(o.material.map)});return maps.size>0&&[...maps].every(m=>m.magFilter===THREE.NearestFilter&&m.minFilter===THREE.NearestFilter&&!m.generateMipmaps&&m.anisotropy===1)})()');
  if(!pixels)throw Error('Soft texture sampling in '+race);
  await js('showReference(true)');
  const valid=await js('reference.visible&&Math.abs(reference.scale.y-D.scenes[selected].spec.portrait.stature*.0525)<1e-9');
  const ref=await js('view.renderer.domElement.toDataURL("image/png").split(",")[1]');
  await fs.writeFile(path.join(folder,'renders/'+race+'-reference.png'),Buffer.from(ref,'base64'));
  await js(`selectScene(${JSON.stringify(race)},1200,1400)`);
  if(!hidden||!valid||!await js('!reference.visible&&!$("reference").checked'))throw Error('Reference scale/visibility invalid: '+race);
 }
 await navigate('comparison.html');
 const comparison=await js(`(async()=>{
  await Promise.all([...document.images].map(im=>im.decode()));
  document.getElementById('new').click();const after=split.value==='0';
  document.getElementById('old').click();const before=split.value==='100';
  split.value=50;split.dispatchEvent(new Event('input'));
  return {images:[...document.images].every(im=>im.naturalWidth===1600),buttons:after&&before,slider:document.getElementById('after').style.clipPath==='inset(0px 0px 0px 50%)'};
 })()`);
 if(Object.values(comparison).some(v=>!v)||errors.length)throw Error(JSON.stringify({comparison,errors}));
 await navigate('portraits.html');
 const gallery=await js('(async()=>{await Promise.all([...document.images].map(im=>im.decode()));return document.images.length===6&&[...document.images].every(im=>im.naturalWidth>600&&im.naturalHeight>600)})()');
 if(!gallery||errors.length)throw Error(JSON.stringify({gallery,errors}));
 console.log(JSON.stringify({referenceHiddenInCaptures:true,pixelSamplingAllSix:true,comparison,gallery,errors}));
}finally{socket.close()}

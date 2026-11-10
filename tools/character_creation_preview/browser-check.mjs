import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
if(process.argv.includes('--close')){
 for(const port of [9237]){
  const info=await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
  const ws=new WebSocket(info.webSocketDebuggerUrl);
  await new Promise(r=>ws.addEventListener('open',r,{once:true}));
  ws.send(JSON.stringify({id:1,method:'Browser.close'}));
  await new Promise(r=>ws.addEventListener('close',r,{once:true}));
 }
 console.log('Closed the isolated preview browser.');process.exit(0);
}
const folder=path.dirname(fileURLToPath(import.meta.url));
const tabs=await (await fetch('http://127.0.0.1:9237/json/list')).json();
const socket=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
await new Promise(r=>socket.addEventListener('open',r,{once:true}));
let seq=0;const waiting=new Map(),errors=[];
socket.addEventListener('message',e=>{const x=JSON.parse(e.data);if(x.id){const p=waiting.get(x.id);waiting.delete(x.id);x.error?p.reject(x.error):p.resolve(x.result)}else if(x.method==='Runtime.exceptionThrown')errors.push(x.params.exceptionDetails)});
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;waiting.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}))})}
async function js(expression){const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value}
await send('Runtime.enable');await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride',{width:1600,height:1000,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'file://'+folder+'/preview.html'});
for(let i=0;i<100;i++){if(await js('typeof window.previewReady !== "undefined"'))break;await new Promise(r=>setTimeout(r,100))}
await js('window.previewReady');
const checks=[];
function check(value,label){checks.push({label,pass:!!value});if(!value)console.error('FAIL',label)}
check(await js('race===null && cls==="warrior" && $("create").disabled'),'neutral start; warrior default; creation disabled');
await js('chooseRace("human")');
await js('look={tone:0,hair:0,style:0,eyes:0,feature:0};controls();skin();new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
check(await js('!!renderer && root.visible && cls==="warrior" && !$("create").disabled'),'human model visible; warrior preselected');
let shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile(folder+'/preview-human.png',Buffer.from(shot.data,'base64'));
await js('document.querySelector("[data-class=mage]").click(); chooseRace("orc")');
check(await js('cls==="mage" && race==="orc" && document.querySelector("[data-class=mage]").getAttribute("aria-pressed")==="true"'),'explicit class persists across faction and race change');
const before=await js('look.tone');await js('document.querySelectorAll("[data-look=tone]")[1].click()');
check(await js('look.tone')!==before,'appearance control changes selection');
await fs.mkdir(folder+'/portraits',{recursive:true});
for(const id of ['human','dwarf','elf','orc','troll','undead']){
 await js(`chooseRace(${JSON.stringify(id)})`);
 check(await js('root.visible && material.map.image.width===64'),'model and skin '+id);
 check(await js('$("landscape").querySelector("img").complete && $("landscape").querySelector("img").naturalWidth===1200'),'rendered backdrop '+id);
 check(await js('getComputedStyle($("landscape").querySelector("img")).imageRendering==="pixelated"'),'pixel-preserving backdrop display '+id);
 await js('look={tone:0,hair:0,style:0,eyes:0,feature:0};cls="warrior";controls();skin();showClass();summary();new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
 shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile(folder+'/preview-'+id+'.png',Buffer.from(shot.data,'base64'));
 const clip=await js('(()=>{const r=document.querySelector(".stage").getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,scale:1}})()');
 shot=await send('Page.captureScreenshot',{format:'png',clip});await fs.writeFile(folder+'/portraits/'+id+'.png',Buffer.from(shot.data,'base64'));

}
for(const [w,h] of [[1600,1000],[1366,768],[1920,1080],[1024,768],[390,844]]){
 await send('Emulation.setDeviceMetricsOverride',{width:w,height:h,deviceScaleFactor:1,mobile:false});
 await js('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
 const result=await js(`({overflow:document.documentElement.scrollWidth>innerWidth,create:(()=>{const r=$("create").getBoundingClientRect();return {right:r.right,bottom:r.bottom}})(),skills:$("skills").clientHeight})`);
 check(!result.overflow,`${w}x${h}: no horizontal overflow`);
 if(w>900){check(result.create.bottom<=h && result.skills>50,`${w}x${h}: create visible; skills have room`);check(await js('document.querySelector(".right").getBoundingClientRect().bottom <= document.querySelector(".footer").getBoundingClientRect().top+1'),`${w}x${h}: panels stay above footer`)}
}
for(const id of ['human','dwarf','elf','orc','troll','undead']){
await js(`chooseRace(${JSON.stringify(id)})`);
for(const [w,h] of [[1600,1000],[1366,768],[1920,1080],[1024,768],[390,844]]){
 await send('Emulation.setDeviceMetricsOverride',{width:w,height:h,deviceScaleFactor:1,mobile:false});
 await js('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
 const result=await js(`(()=>{
  draw();const image=$('landscape').getBoundingClientRect(),canvas=$('model').getBoundingClientRect(),p=D.portraits[race];
  const [fx,fy,fz]=p.spec.portrait.feet,stature=p.spec.portrait.stature,height=Math.max(...D.body.map(b=>b.box[4]))*.0525*stature,halfWidth=.42*stature;
  const original=new THREE.PerspectiveCamera(p.spec.camera.fov,p.width/p.height,.05,300);
  original.position.set(...p.spec.camera.eye.map((v,i)=>i===2?-v:v));original.lookAt(...p.spec.camera.target.map((v,i)=>i===2?-v:v));original.updateMatrixWorld();
  const k=Math.max(image.width/p.width,image.height/p.height);let error=0;
  for(const point of [[fx,fy,-fz],[fx,fy+height,-fz],[fx-halfWidth,fy+height/2,-fz],[fx+halfWidth,fy+height/2,-fz]]){
   const a=new THREE.Vector3(...point).project(original),b=new THREE.Vector3(...point).project(camera);
   const ax=(a.x+1)*p.width/2*k-(p.width*k-image.width)/2,ay=(1-a.y)*p.height/2*k-(p.height*k-image.height)/2;
   error=Math.max(error,Math.abs(ax-(b.x+1)*canvas.width/2),Math.abs(ay-(1-b.y)*canvas.height/2));
  }
  const foot=new THREE.Vector3(fx,fy,-fz).project(camera),head=new THREE.Vector3(fx,fy+height,-fz).project(camera);
  const bounds=new THREE.Box3().setFromObject(root),ys=[];
  root.traverse(mesh=>{if(!mesh.isMesh)return;const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){const v=new THREE.Vector3().fromBufferAttribute(positions,i).applyMatrix4(mesh.matrixWorld).project(camera);ys.push(canvas.top+(1-v.y)*canvas.height/2)}});
  const clear=Math.min(...ys)>=document.querySelector('.stage-heading').getBoundingClientRect().bottom+3&&Math.max(...ys)<document.querySelector('.rotate').getBoundingClientRect().top;
  return {error,clear,top:Math.min(...ys),bottom:Math.max(...ys),heading:document.querySelector('.stage-heading').getBoundingClientRect().bottom,rotate:document.querySelector('.rotate').getBoundingClientRect().top,aligned:Math.abs(image.left-canvas.left)<1&&Math.abs(image.top-canvas.top)<1&&Math.abs(image.width-canvas.width)<1&&Math.abs(image.height-canvas.height)<1,size:Math.abs(bounds.max.y-bounds.min.y-height)<1e-6&&Math.abs(bounds.min.y-fy)<1e-6,shadow:groundShadow.visible&&Math.abs(groundShadow.position.y-(fy+.003))<.0001&&groundShadow.position.x===fx&&groundShadow.position.z===-fz,visible:foot.y>-.9&&head.y<.9};
 })()`);
 if(!result.aligned||result.error>=.1||!result.size||!result.shadow||!result.visible||!result.clear)console.error(id,w,h,result);
 check(result.aligned&&result.error<.1,`${id} ${w}x${h}: shared projection matches background crop within 0.1px`);
 check(result.size&&result.shadow&&result.visible&&result.clear,`${id} ${w}x${h}: real race scale, grounded shadow, head and feet clear of labels`);
}
await send('Emulation.setDeviceMetricsOverride',{width:1600,height:1000,deviceScaleFactor:1,mobile:false});
}
await js('chooseRace("elf");');await js('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile(folder+'/preview-elf.png',Buffer.from(shot.data,'base64'));
await js('reset()');await js('new Promise(r=>requestAnimationFrame(r))');shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile(folder+'/preview-start.png',Buffer.from(shot.data,'base64'));
await send('Emulation.setDeviceMetricsOverride',{width:1366,height:768,deviceScaleFactor:1,mobile:false});
for(const mode of ['above','below','side']){
 await js(`document.body.dataset.banner=${JSON.stringify(mode)}`);
 await js('new Promise(r=>requestAnimationFrame(r))');
 check(await js('document.querySelector(".throng").getBoundingClientRect().bottom <= document.querySelector(".footer").getBoundingClientRect().top'),`banner ${mode}: both faction lists fit`);
}
await js('chooseRace("dwarf")');await js('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
shot=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile(folder+'/preview-1366.png',Buffer.from(shot.data,'base64'));
check(errors.length===0,'no uncaught JavaScript exceptions');
await fs.writeFile(folder+'/verification.json',JSON.stringify({browser:'Chromium 151, software rendering; browser preview only, not Luanti',checks,errors},null,2)+'\n');
console.log(JSON.stringify({checks,errors},null,2));socket.close();
if(checks.some(c=>!c.pass))process.exitCode=1;

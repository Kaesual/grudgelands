#!/usr/bin/env node
// Browser verification using an installed Chromium and its DevTools protocol.
// Optional --vendor DIR serves the two pinned CDN scripts from a local cache.
import {spawn} from 'node:child_process';
import {mkdtemp,readFile,writeFile,rm,mkdir} from 'node:fs/promises';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {setTimeout as delay} from 'node:timers/promises';
import assert from 'node:assert/strict';

const here=dirname(fileURLToPath(import.meta.url));
const option=name=>{const i=process.argv.indexOf(name);return i<0?null:process.argv[i+1];};
const executable=option('--chrome')||process.env.CHROME_BIN||'chromium-browser';
const vendor=option('--vendor');
const html=await readFile(join(here,'apple.html'),'utf8');
const nodes=JSON.parse(await readFile(join(here,'apple-nodes.json'),'utf8'));
const inline=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n');
const profile=await mkdtemp(join(tmpdir(),'astree-browser-'));
const scriptPath=join(profile,'viewer.js');
await writeFile(scriptPath,inline);
await new Promise((resolve,reject)=>{
  const p=spawn(process.execPath,['--check',scriptPath],{stdio:'inherit'});
  p.on('error',reject);p.on('exit',code=>code===0?resolve():reject(Error('node --check failed')));
});
const chrome=spawn(executable,['--headless','--no-sandbox','--no-first-run','--no-default-browser-check',
  '--use-angle=swiftshader','--enable-unsafe-swiftshader','--remote-debugging-port=0',
  '--user-data-dir='+profile,'about:blank'],{stdio:['ignore','ignore','pipe']});
let chromeLog='',socket;
chrome.stderr.on('data',chunk=>{chromeLog+=chunk;});
const errors=[],networkFailures=[],external=new Set();
try {
  let port;
  for(let i=0;i<100;i++) {
    try {port=(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break;}
    catch (_) {if(chrome.exitCode!==null||chrome.signalCode!==null)throw Error(chromeLog);await delay(100);}
  }
  assert(port,'Chromium did not start: '+chromeLog);
  const targets=await (await fetch('http://127.0.0.1:'+port+'/json')).json();
  socket=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
  let serial=0;const pending=new Map();
  const cdp=(method,params={})=>new Promise((resolve,reject)=>{
    const id=++serial;pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));
  });
  const pinned={
    'https://cdn.jsdelivr.net/npm/three@0.147.0/build/three.min.js':'three.min.js',
    'https://cdn.jsdelivr.net/npm/three@0.147.0/examples/js/controls/OrbitControls.js':'OrbitControls.js',
  };
  socket.onmessage=async event=>{
    const data=JSON.parse(event.data);
    if(data.id){const p=pending.get(data.id);pending.delete(data.id);data.error?p.reject(data.error):p.resolve(data.result);}
    if(data.method==='Runtime.exceptionThrown')errors.push(data.params.exceptionDetails);
    if(data.method==='Network.loadingFailed')networkFailures.push(data.params.errorText);
    if(data.method==='Network.requestWillBeSent' && data.params.request.url.startsWith('http'))external.add(data.params.request.url);
    if(data.method==='Fetch.requestPaused') {
      const {requestId,request}=data.params;
      try {
        const filename=pinned[request.url];assert(filename,'Unexpected external request: '+request.url);
        const body=(await readFile(join(vendor,filename))).toString('base64');
        await cdp('Fetch.fulfillRequest',{requestId,responseCode:200,responseHeaders:[{name:'Content-Type',value:'application/javascript'}],body});
      } catch(error) {errors.push(String(error));await cdp('Fetch.failRequest',{requestId,errorReason:'Failed'});}
    }
  };
  async function evaluate(expression) {
    const r=await cdp('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
    assert(!r.exceptionDetails,JSON.stringify(r.exceptionDetails));return r.result.value;
  }
  await cdp('Page.enable');await cdp('Runtime.enable');await cdp('Network.enable');
  if(vendor)await cdp('Fetch.enable',{patterns:[{urlPattern:'https://cdn.jsdelivr.net/*'}]});
  await cdp('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
  await cdp('Page.navigate',{url:pathToFileURL(join(here,'apple.html')).href});
  let ready;
  for(let i=0;i<200;i++){ready=await evaluate('document.documentElement.dataset.viewer');if(ready==='ready'||ready==='error')break;await delay(100);}
  assert.equal(ready,'ready',await evaluate('document.getElementById("load-state").textContent'));
  assert.equal(await evaluate('THREE.REVISION'),'147');
  assert.deepEqual(await evaluate('window.treeViewer.nodes'),nodes);
  const geometry=await evaluate(`(()=>{
    const v=treeViewer;
    return {boxes:v.nodes.flatMap(n=>v.nodeBoxes(n).map(b=>({node:n,box:b}))),
      counts:v.count,vertices:Object.fromEntries(Object.entries(v.meshes).map(([k,m])=>[k,m.geometry.attributes.position.count])),
      textureSizes:Object.fromEntries(Object.entries(v.meshes).map(([k,m])=>[k,[m.material.map.image.width,m.material.map.image.height]])),
      filtering:Object.values(v.meshes).every(m=>m.material.map.magFilter===THREE.NearestFilter && m.material.map.minFilter===THREE.NearestFilter)};
  })()`);
  assert(geometry.filtering);assert(Object.values(geometry.textureSizes).every(s=>s[0]===16&&s[1]===16));
  assert.equal(geometry.vertices.leaf,nodes.filter(n=>n.kind==='leaves').length*36);
  assert.equal(geometry.vertices.apple,nodes.filter(n=>n.kind==='fruit').length*12);
  assert.equal(geometry.vertices.bark+geometry.vertices.end,geometry.boxes.filter(r=>r.node.kind!=='leaves').length*36);
  const occupied=new Set();
  for(const n of nodes) {
    assert.deepEqual(Object.keys(n),['x','y','z','kind','rot']);
    assert([n.x,n.y,n.z,n.rot].every(Number.isInteger));
    assert(n.rot>=0&&n.rot<=3);if(n.kind!=='quarter')assert.equal(n.rot,0);
    const key=[n.x,n.y,n.z].join(',');assert(!occupied.has(key));occupied.add(key);
    if(n.kind==='fruit')assert(nodes.some(a=>a.kind==='leaves'&&a.x===n.x&&a.y===n.y+1&&a.z===n.z),'Fruit must hang below leaves');
  }
  for(const {box} of geometry.boxes) {
    assert(box.every(v=>Number.isInteger(v)&&v>=-8&&v<=8));
    assert(box[0]<box[3]&&box[1]<box[4]&&box[2]<box[5]);
  }
  // Physical face contact, not merely occupied neighbouring cells. This catches
  // disconnected quarter/branch interfaces and mismatched rotations.
  const wood=nodes.filter(n=>['quarter','trunk','branch','twig'].includes(n.kind));
  const worldBoxes=n=>geometry.boxes.filter(r=>r.node.x===n.x&&r.node.y===n.y&&r.node.z===n.z)
    .map(r=>r.box.map((v,i)=>v+16*n[['x','y','z'][i%3]]));
  const boxes=wood.map(worldBoxes);
  function touch(a,b) {
    for(let k=0;k<3;k++) if(a[k+3]===b[k]||b[k+3]===a[k]) {
      const other=[0,1,2].filter(i=>i!==k);
      if(other.every(i=>Math.min(a[i+3],b[i+3])>Math.max(a[i],b[i])))return true;
    }
    return false;
  }
  const seen=new Set([0]),queue=[0];
  while(queue.length) {
    const a=queue.pop();
    wood.forEach((_,b)=>{if(!seen.has(b)&&boxes[a].some(x=>boxes[b].some(y=>touch(x,y)))){seen.add(b);queue.push(b);}});
  }
  assert.equal(seen.size,wood.length,'All wood must physically connect');
  for(const n of nodes.filter(n=>n.kind==='leaves'))assert(wood.some(w=>Math.max(Math.abs(w.x-n.x),Math.abs(w.y-n.y),Math.abs(w.z-n.z))<=3),'Unsupported leaf');
  const evidence=join(here,'evidence');await mkdir(evidence,{recursive:true});
  async function screenshot(name) {
    await delay(300);const result=await cdp('Page.captureScreenshot',{format:'png'});
    await writeFile(join(evidence,name+'.png'),Buffer.from(result.data,'base64'));
  }
  await screenshot('perspective');
  await evaluate('document.getElementById("leaves").click();document.getElementById("grid").click();');
  assert.equal(await evaluate('treeViewer.meshes.leaf.visible || treeViewer.meshes.apple.visible'),false);
  assert.equal(await evaluate('treeViewer.grid.visible'),true);
  await screenshot('skeleton');
  for(const name of ['front','top','perspective']) {
    await evaluate(`document.querySelector('[data-view="${name}"]').click()`);
    assert.equal(await evaluate(`document.querySelector('[data-view="${name}"]').getAttribute('aria-pressed')`),'true');
  }
  await evaluate('document.getElementById("leaves").click();document.getElementById("grid").click();document.getElementById("shape-panel").open=true');
  const viewports=[];
  for(const width of [320,390,760,1024,1440]) {
    await cdp('Emulation.setDeviceMetricsOverride',{width,height:900,deviceScaleFactor:1,mobile:false});
    await delay(120);await evaluate('treeViewer.preset("perspective")');
    const metrics=await evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth,canvas:document.getElementById("view").getBoundingClientRect().width})');
    assert(metrics.scroll<=width,JSON.stringify(metrics));assert(metrics.canvas>0);viewports.push(metrics);
    if(width===390)await screenshot('mobile');
  }
  // Exercise the denied-clipboard path and verify its full copyable payload.
  await evaluate(`Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{throw Error('test denial')}}});document.execCommand=()=>false;document.getElementById('copy').click()`);
  await delay(100);
  assert.deepEqual(JSON.parse(await evaluate('document.getElementById("manual-copy").value')),nodes);
  assert.equal(await evaluate('document.getElementById("manual-copy").hidden'),false);
  await evaluate(`window.copiedJSON=null;Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>{window.copiedJSON=text}}});document.getElementById('copy').click()`);
  await delay(100);assert.deepEqual(JSON.parse(await evaluate('window.copiedJSON')),nodes);
  assert.deepEqual(errors,[]);assert.deepEqual(networkFailures,[]);assert.deepEqual([...external].sort(),Object.keys(pinned).sort());
  const receipt={result:'PASS',library:'three.js 0.147.0',librarySource:vendor?'local cache substituted for the two exact CDN URLs':'CDN',
    nodes:nodes.length,counts:geometry.counts,physicalWoodConnections:wood.length,viewports,
    checks:['node --check','external JSON equals rendered node data','integer cells and rotations','box bounds and vertex counts',
      '16px nearest-filtered textures','physical wood connectivity','leaf support and hanging fruit','leaf/grid controls',
      'camera presets','responsive layout','clipboard success and denied fallback','no browser exceptions','only two pinned CDN URLs']};
  await writeFile(join(evidence,'checks.json'),JSON.stringify(receipt,null,2)+'\n');
  console.log(JSON.stringify(receipt,null,2));
} finally {
  socket?.close();chrome.kill('SIGTERM');
  await new Promise(resolve=>{if(chrome.exitCode!==null||chrome.signalCode!==null)resolve();else chrome.once('exit',resolve);});
  await rm(profile,{recursive:true,force:true});
}

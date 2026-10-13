#!/usr/bin/env node
// Geometry/data checks without WebGL; this does not claim a browser test.
import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import {tmpdir} from 'node:os';
import assert from 'node:assert/strict';

const here=dirname(fileURLToPath(import.meta.url));
const html=await readFile(join(here,'apple.html'),'utf8');
const nodes=JSON.parse(await readFile(join(here,'apple-nodes.json'),'utf8'));
const source=html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const scratch=await mkdtemp(join(tmpdir(),'astree-parse-'));
try {
  const path=join(scratch,'viewer.js');await writeFile(path,source);
  assert.equal(spawnSync(process.execPath,['--check',path],{stdio:'inherit'}).status,0);
} finally {await rm(scratch,{recursive:true,force:true});}
const elements=new Map();
const element=()=>({textContent:'',append(){},addEventListener(){}});
for(const match of html.matchAll(/<script id="([^"]+)" type="application\/json">([^<]+)<\/script>/g)) {
  elements.set(match[1],{...element(),textContent:match[2]});
}
const dom={createElement:element,getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id);}};
// Execute the page's actual data-to-box logic, with only the surrounding text
// elements stubbed. Rendering, controls and layout require check.mjs in Chromium.
const logic=new Function('document',source.slice(0,source.indexOf('async function startViewer()'))+
  '\nreturn {NODES,SHAPES,TEXTURES,nodeBoxes,connections,grainAxis,count};')(dom);
assert.deepEqual(logic.NODES,nodes);
assert.deepEqual(Object.keys(logic.SHAPES),['quarter','branch','twig']);
assert.equal(logic.SHAPES.quarter.boxes.length,3);
const cells=new Map(nodes.map(n=>[[n.x,n.y,n.z].join(','),n]));
assert.equal(cells.size,nodes.length);
const isWood=n=>n&&['quarter','trunk','branch','twig'].includes(n.kind);
const directions=[[0,1,0],[0,-1,0],[0,0,-1],[0,0,1],[-1,0,0],[1,0,0]];
for(const n of nodes) {
  assert.deepEqual(Object.keys(n),['x','y','z','kind','rot']);
  assert([n.x,n.y,n.z,n.rot].every(Number.isInteger));
  assert(n.rot>=0&&n.rot<=3);if(n.kind!=='quarter')assert.equal(n.rot,0);
  const boxes=logic.nodeBoxes(n);
  if(n.kind==='branch'||n.kind==='twig') {
    const neighbours=directions.filter(d=>isWood(cells.get([n.x+d[0],n.y+d[1],n.z+d[2]].join(','))));
    assert.equal(boxes.length,1+neighbours.length);
  }
  for(const b of boxes){assert(b.every(v=>Number.isInteger(v)&&v>=-8&&v<=8));for(let i=0;i<3;i++)assert(b[i]<b[i+3]);}
  if(n.kind==='fruit')assert.equal(cells.get([n.x,n.y+1,n.z].join(','))?.kind,'leaves');
}
const wood=nodes.filter(isWood);
const worldBoxes=wood.map(n=>logic.nodeBoxes(n).map(b=>b.map((v,i)=>v+16*n[['x','y','z'][i%3]])));
function touch(a,b) {
  for(let k=0;k<3;k++)if(a[k+3]===b[k]||b[k+3]===a[k]) {
    if([0,1,2].filter(i=>i!==k).every(i=>Math.min(a[i+3],b[i+3])>Math.max(a[i],b[i])))return true;
  }
  return false;
}
const seen=new Set([0]),queue=[0];
while(queue.length) {
  const a=queue.pop();
  wood.forEach((_,b)=>{if(!seen.has(b)&&worldBoxes[a].some(x=>worldBoxes[b].some(y=>touch(x,y)))){seen.add(b);queue.push(b);}});
}
assert.equal(seen.size,wood.length,'Disconnected wood: '+JSON.stringify(wood.filter((_,i)=>!seen.has(i))));
for(const n of nodes.filter(n=>n.kind==='leaves'))assert(wood.some(w=>Math.max(Math.abs(w.x-n.x),Math.abs(w.y-n.y),Math.abs(w.z-n.z))<=3));
const root=here+'/../../..';
for(const [key,file] of Object.entries({bark:'tree',end:'tree_top',leaf:'leaves',apple:'apple',grass:'grass'})) {
  const bytes=await readFile(join(root,'mods/BASE/default/textures/default_'+file+'.png'));
  assert.equal(logic.TEXTURES[key],'data:image/png;base64,'+bytes.toString('base64'));
  assert.equal(bytes.readUInt32BE(16),16);assert.equal(bytes.readUInt32BE(20),16);
}
const external=[...html.matchAll(/<script src="([^"]+)"/g)].map(m=>m[1]);
assert.deepEqual(external,['https://cdn.jsdelivr.net/npm/three@0.147.0/build/three.min.js',
  'https://cdn.jsdelivr.net/npm/three@0.147.0/examples/js/controls/OrbitControls.js']);
console.log('PASS: script parses; HTML = JSON; six-neighbour boxes; all '+wood.length+' wood nodes physically connected; supported leaves; hanging apples; exact embedded 16px repository PNGs; three shapes.');
console.log(JSON.stringify(logic.count));

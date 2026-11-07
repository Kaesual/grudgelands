'use strict';
const plans=JSON.parse(document.getElementById('planner-data').textContent);
const ns='http://www.w3.org/2000/svg';
function node(tag,attrs={},text){const n=document.createElementNS(ns,tag);Object.entries(attrs).forEach(([k,v])=>n.setAttribute(k,v));if(text!==undefined)n.textContent=text;return n;}
function drawCity(host,plan,other){
 const svg=node('svg',{viewBox:'-280 -280 560 560',role:'img','aria-label':'Exported whole-capital planner output, north up'});
 svg.append(node('polygon',{points:plan.outline.map(([x,z])=>`${x},${-z}`).join(' '),class:'city-outline'}));
 for(const r of plan.streets)svg.append(node('polyline',{points:r.pts.map(([x,z])=>`${x},${-z}`).join(' '),class:'city-road','stroke-width':(r.hw||2)*2+1}));
 const districts=[...new Set(plan.plots.map(p=>p.district))].sort();
 for(const p of plan.plots){
  const n=node('rect',{x:p.x1-.5,y:-p.z2-.5,width:p.x2-p.x1+1,height:p.z2-p.z1+1,class:`city-plot district-${districts.indexOf(p.district)}${p.required?' required':''}`});
  n.append(node('title',{},`${p.id} · ${p.district} · (${p.x}, ${p.z}) y=${p.y}, turn=${p.turns}${p.required?' · REQUIRED':''}`));svg.append(n);
 }
 const r=plan.core;
 svg.append(node('rect',{x:-r,y:-r,width:2*r,height:2*r,class:'city-core'}));
 svg.append(node('rect',{x:-plan.keep,y:-plan.keep,width:2*plan.keep,height:2*plan.keep,class:'city-keep'}));
 svg.append(node('text',{x:0,y:4,class:'city-text'},`core ±${r}`));
 if(other)svg.append(node('polygon',{points:other.outline.map(([x,z])=>`${x},${-z}`).join(' '),class:'city-old'}));
 for(const g of plan.gates){const n=node('circle',{cx:g.x,cy:-g.z,r:4,class:'city-gate'});n.append(node('title',{},`${g.name}: (${g.x}, ${g.z})`));svg.append(n);}
 svg.append(node('path',{d:'M-245 244v6h100v-6M-195 244v6',class:'city-scale',fill:'none'}));
 svg.append(node('text',{x:-195,y:238,class:'city-text'},'100 nodes'));
 svg.append(node('text',{x:-235,y:-240,class:'city-text'},'N ↑'));
 host.replaceChildren(svg);
}
function cityUpdate(key,seed){const wrap=document.querySelector(`.city-pair[data-capital="${key}"]`);drawCity(wrap.querySelector('.today'),plans[seed].today[key]);drawCity(wrap.querySelector('.proposed'),plans[seed].proposed[key],plans[seed].today[key]);}
document.querySelectorAll('.seed-select').forEach(select=>{cityUpdate(select.dataset.capital,select.value);select.addEventListener('change',()=>cityUpdate(select.dataset.capital,select.value));});
function highlight(el){const id=el.dataset.building;document.querySelectorAll('[data-building]').forEach(n=>n.classList.toggle('selected',n.dataset.building===id));}
document.querySelectorAll('svg [data-building]').forEach(el=>{el.addEventListener('click',()=>highlight(el));el.addEventListener('focus',()=>highlight(el));el.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();highlight(el);}});});
document.getElementById('show-sockets').addEventListener('change',e=>document.body.classList.toggle('all-sockets',e.target.checked));
document.getElementById('show-range').addEventListener('change',e=>document.body.classList.toggle('show-range',e.target.checked));
document.getElementById('theme').addEventListener('change',e=>{if(e.target.value==='auto')delete document.documentElement.dataset.theme;else document.documentElement.dataset.theme=e.target.value;});
// Evidence links work through the closed accordion as well as without a mouse.
function revealHash(){const id=decodeURIComponent(location.hash.slice(1));const target=document.getElementById(id);if(!target)return;let p=target.parentElement;while(p){if(p.tagName==='DETAILS')p.open=true;p=p.parentElement;}target.scrollIntoView({block:'start'});}
window.addEventListener('hashchange',revealHash);
if(location.hash)revealHash();

const data=JSON.parse(document.getElementById('data').textContent);
const byId=id=>document.getElementById(id);
const camera=byId('camera'), layer=byId('layer'), liveCanvas=byId('live');
let hall='accord', state='after', pose, live=false, boxes=false, model=null, modelKey='', loading=false;
let frame=0, revealBarrier=false;
const colors={'Hall':'#74d8bb','Upper stair':'#ffba73','Balcony':'#9fc9ff'};
const afterText={
  field:'One gate carries the gallery. The standard still hangs between the two ways onto the field.',
  road:'From road level the opening sits above the gate, with the standard beside it and the old towers behind.',
  foot:'The first half-step stands beside the inlaid aisle. The stone and both sills have room around them.',
  turn:'Eye level on the landing. Turn toward the road and follow the second flight under the tower.',
  gallery:'The stair opens at one end of the room. Six spectators can stand at the rail with another six behind.',
  balcony:'At standing eye height, the crossing, stair flights and opposite standard are in view. The pier caps hide parts of the near terrace.',
  rail:'Standing on the timber rail raises the eye one node. The invisible wall immediately in front still closes the opening from floor to canopy.',
  flank:'At the end bay, look along the through-road toward its mouth. The end wall limits the view behind the hall.',
  roof:'From the contested hall roof the back of the gallery is a continuous wall. The stair passes through its own covered opening.',
  cut:'The selected hall’s roofs, towers and upper room walls are lifted. Follow the two flights from the waystone to the rail.'
};
const beforeText={
  field:'The shipped hall, seen across the ruins. The courts sit below the towers on either side of the standard.',
  road:'The old gate has an open court. This is the same road position and lens as the proposal.',
  foot:'The end of the original muster room holds a bench. Both bronze sills open onto screened courts.',
  turn:'The matched camera hangs above the original floor, under a roof beam where the upper flight will run.',
  gallery:'At the proposed gallery entrance the camera hangs over the old return court.',
  balcony:'Matched eye position over the original gate. A spectator standing in the old hall could not reach this position.',
  rail:'The matched camera hangs above the gate at the height of the proposed fence-top view.',
  flank:'The second eye position over the original court, looking along the road.',
  roof:'The roof passage alongside the tower looks over the old return court.',
  cut:'The original room and courts, with the same display cut as the proposal.'
};
function pressed(selector,attr,value) {
  document.querySelectorAll(selector).forEach(b=>b.setAttribute('aria-pressed',String(b.dataset[attr]===value)));
}
function setTheme(dark) {
  document.documentElement.dataset.theme=dark?'dark':'light';
  byId('theme').textContent=dark?'Light theme':'Dark theme';
}
const systemTheme=matchMedia('(prefers-color-scheme: dark)');
setTheme(systemTheme.matches);
systemTheme.addEventListener('change',e=>setTheme(e.matches));
byId('theme').onclick=()=>setTheme(document.documentElement.dataset.theme!=='dark');
for(const [key,title] of Object.entries(data.views))camera.add(new Option(title,key));
function draw() {
  frame=0;
  if(live && model){
    const other=hall==='accord'?'throng':'accord', cut=camera.value==='cut';
    const key=hall+'-'+state+(cut?'-cut':'');
    if(key!==modelKey){
      model.setScene([data.field,data.halls[other+'-'+state],data.halls[key]]);
      modelKey=key;
    }
    model.render(pose, revealBarrier && state==='after'?Object.values(data.barrier):[]);
  }
  const order=hall==='accord'?['throng','accord']:['accord','throng'];
  const list=order.flatMap(f=>Object.entries(data.boxes[f])).filter(([label])=>state==='after'||label==='Hall');
  territory(byId('overlay'),pose,boxes?list.map(([label,b])=>[b,colors[label]]):[]);
}
function schedule(){if(!frame)frame=requestAnimationFrame(draw);}
function resetCamera() {
  const [eye,target,fov]=data.poses[hall][camera.value];
  pose=[eye.slice(),target.slice(),fov];
}
function refresh(keepPose=false) {
  if(keepPose!==true)resetCamera();
  const key=hall+'-'+state+'-', view=camera.value;
  const name=hall==='accord'?'Breachward Hall':'Breakfang Hall';
  byId('hallname').textContent=name;byId('measures').hidden=state==='before';
  byId('description').textContent=state==='before'
    ?'The bronze sills mark the two doors of a single friendly room. Beyond them the old screens turn each approach toward the field.'
    :hall==='accord'
    ?'A slate canopy, pale stone piers and a timber rail carry the tower’s masonry across the gate.'
    :'Pine posts and an acacia deck carry the timber crown over the gate. Bronze pins finish the ends of the roof beam.';
  byId('still').src=data.images[key+view]; byId('still').alt=name+', '+state+', '+data.views[view];
  byId('mode').textContent=(live?'Interactive model':'Field plate')+' · '+state;
  byId('viewtitle').textContent=data.views[view];
  byId('caption').textContent=(state==='after'?afterText:beforeText)[view];
  byId('barrier3d').disabled=state==='before';
  byId('still').hidden=live;liveCanvas.hidden=!live;byId('reset').hidden=!live;
  byId('explore').textContent=live?'Return to plate':'Explore in 3D';
  byId('feedback').textContent=live?'Drag or use arrow keys to turn. Pinch, scroll or use + and − to zoom.':'';
  pressed('[data-hall]','hall',hall);pressed('[data-state]','state',state);pressed('[data-view]','view',view);
  document.querySelectorAll('[data-view]').forEach(b=>{b.querySelector('img').src=data.images[key+b.dataset.view];});
  schedule();
}
async function toggleLive(){
  if(loading)return;
  if(!model){
    loading=true;byId('explore').disabled=true;byId('feedback').textContent='Opening the model…';
    try{model=await canvasView(liveCanvas,data);}
    catch(e){byId('feedback').textContent='The interactive model could not open. The camera plates are available.';return;}
    finally{loading=false;byId('explore').disabled=false;}
  }
  live=!live;refresh();if(live)liveCanvas.focus({preventScroll:true});
}
function turn(dx,dy) {
  const [eye,target]=pose, vector=target.map((v,i)=>v-eye[i]), radius=Math.hypot(...vector);
  const yaw=Math.atan2(vector[0],vector[2])+dx;
  const pitch=Math.max(-1.51,Math.min(1.51,Math.asin(vector[1]/radius)+dy));
  const next=[Math.sin(yaw)*Math.cos(pitch),Math.sin(pitch),Math.cos(yaw)*Math.cos(pitch)];
  if(['field','cut'].includes(camera.value))pose[0]=target.map((v,i)=>v-next[i]*radius);
  else pose[1]=eye.map((v,i)=>v+next[i]*radius);
  schedule();
}
function zoom(factor){pose[2]=Math.max(22,Math.min(100,pose[2]*factor));schedule();}
const pointers=new Map();
liveCanvas.onpointerdown=e=>{
  liveCanvas.setPointerCapture(e.pointerId);pointers.set(e.pointerId,[e.clientX,e.clientY]);
};
liveCanvas.onpointermove=e=>{
  const prev=pointers.get(e.pointerId);if(!prev)return;
  const now=[e.clientX,e.clientY];pointers.set(e.pointerId,now);
  if(pointers.size===2){
    const other=[...pointers.entries()].find(([id])=>id!==e.pointerId)[1];
    const dist=p=>Math.hypot(p[0]-other[0],p[1]-other[1]);
    if(dist(now)>1 && dist(prev)>1)zoom(dist(prev)/dist(now));
  }else turn((prev[0]-now[0])*.006,(now[1]-prev[1])*.006);
};
liveCanvas.onlostpointercapture=e=>pointers.delete(e.pointerId);
liveCanvas.addEventListener('wheel',e=>{e.preventDefault();zoom(Math.exp(Math.sign(e.deltaY)*.09));},{passive:false});
liveCanvas.onkeydown=e=>{
  const direction={ArrowLeft:[-.09,0],ArrowRight:[.09,0],ArrowUp:[0,.09],ArrowDown:[0,-.09]};
  if(direction[e.key]){e.preventDefault();turn(...direction[e.key]);}
  else if(['+','=','-'].includes(e.key)){e.preventDefault();zoom(e.key==='-'?1.1:.91);}
};
function showLayer(){
  const plan=data.plans[hall], y=layer.value;
  byId('count').textContent=plan.counts[y]+' changed cells';
  for(const [stateName,id] of [['before','oldlayer'],['after','newlayer']]){
    const side=plan[stateName][y];
    const other=plan[stateName==='after'?'before':'after'][y];
    byId(id).innerHTML=side.map((row,z)=>String(z).padStart(2,'0')+'  '+[...row].map((c,x)=>
      c===other[z][x]?c:(revealBarrier && stateName==='after' && plan.legend[c]==='grug_mapgen:arena_barrier'
        ?'<mark class="barrier-cell">':'<mark>')+c+'</mark>').join('')).join('\n');
  }
}
function builder(){
  const name=hall==='accord'?'Breachward Hall · The Accord':'Breakfang Hall · The Throng';
  byId('planhall').textContent=name+' · proposal';
  byId('coordinates').replaceChildren();
  for(const [label,[lo,hi]] of Object.entries(data.boxes[hall])){
    const row=document.createElement('div'), term=document.createElement('dt'), desc=document.createElement('dd');
    const dot=document.createElement('i');dot.className='legenddot';dot.style.background=colors[label];
    term.append(dot,label);desc.textContent='('+lo.join(', ')+') … ('+hi.join(', ')+')';
    row.append(term,desc);byId('coordinates').append(row);
  }
  const plan=data.plans[hall], prev=layer.value;
  layer.replaceChildren(...Object.keys(plan.counts).map(y=>new Option('y = '+y,y)));
  layer.value=Object.hasOwn(plan.counts,prev)?prev:'8';
  byId('legend').replaceChildren();
  for(const [k,n] of Object.entries({'.':'air',...plan.legend})){
    const row=document.createElement('div');row.textContent=k+'  '+n;byId('legend').append(row);
  }
  const [lo,hi]=data.barrier[hall];
  byId('barrierCoords').textContent='('+lo.join(', ')+') … ('+hi.join(', ')+')';
  showLayer();diagram();
}
function diagram(){
  // Hall-frame plan: look toward the road, with the gallery wing at right.
  // The two stamps are a half-turn apart in site coordinates.
  const step=10, x=v=>235+step*v, y=u=>228-step*u;
  function rect(u1,v1,u2,v2,fill,stroke='none'){
    return '<rect x="'+(x(v1)-5)+'" y="'+(y(u2)-5)+'" width="'+(step*(v2-v1+1))+
      '" height="'+(step*(u2-u1+1))+'" fill="'+fill+'" stroke="'+stroke+'"/>';
  }
  let content=rect(0,-15,20,15,'var(--bg)','var(--grid)')+
    rect(1,-14,11,14,'var(--tint)')+rect(13,6,18,14,'var(--rail)')+
    rect(19,6,19,14,'var(--selected)')+rect(12,5,12,11,'var(--selected)');
  if(revealBarrier)content+=rect(20,6,20,14,'#36cbd0','#21646b');
  for(const v of [-9,6])content+=rect(12,v,12,v+3,'#b58942');
  for(const [u,v,rise] of data.runs)content+=rect(u,v,u,v,'var(--walk)','var(--panel)');
  const seats=[...Array(6)].map((_,i)=>7+i*1.1);
  for(const u of [16,17.5])for(const v of seats)content+='<circle cx="'+x(v)+'" cy="'+y(u)+'" r="2.8" fill="var(--panel)"/>';
  function label(px,py,text,anchor='start'){
    return '<text x="'+px+'" y="'+py+'" text-anchor="'+anchor+'">'+text+'</text>';
  }
  content+=rect(4,0,4,0,'var(--selected)')+
    label(82,16,'Roadward ↑')+label(388,16,hall==='accord'?'West · toward the road':'East · toward the road','end')+
    label(96,64,'Return court')+label(96,136,'Muster room')+label(137,188,'Waystone')+
    label(220,212,'Start →')+label(397,88,'Deck')+label(397,102,'+8')+
    label(397,190,'Turn')+label(397,204,'+4');
  content+='<path d="M '+x(4)+' '+y(3)+' H '+x(13)+' V '+y(17)+'" stroke="var(--ink)" stroke-width="2.5" fill="none"/>'+
    '<path d="M '+(x(13)-4)+' '+(y(17)+6)+' l 4 -6 4 6" fill="none" stroke="var(--ink)" stroke-width="2.5"/>';
  let px=82, py=315, d='M '+px+' '+py+' h 18';
  for(let leg=0;leg<2;leg++){
    for(let i=0;i<8;i++)d+=' v -5 h 10';
    d+=leg===0?' h 30':' h 50';
  }
  content+=label(82,263,'Unfolded stair section')+'<path d="'+d+'" fill="none" stroke="var(--walk)" stroke-width="3" transform="translate(0 31)"/>'+
    label(82,366,'Floor 0')+label(181,321,'Turn +4')+label(301,286,'Deck +8');
  byId('diagram').innerHTML='<svg viewBox="70 0 380 376" role="img" aria-label="Two flights of eight half-node rises, a three-wide landing and twelve spectator positions">'+content+'</svg>';
}
document.querySelectorAll('[data-hall]').forEach(b=>b.onclick=()=>{hall=b.dataset.hall;refresh();builder();});
document.querySelectorAll('[data-state]').forEach(b=>b.onclick=()=>{state=b.dataset.state;refresh(true);});
document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>{camera.value=b.dataset.view;refresh();});
byId('explore').onclick=toggleLive;
byId('boxes').onclick=()=>{boxes=!boxes;byId('boxes').setAttribute('aria-pressed',String(boxes));schedule();};
function setBarrier(on){
  revealBarrier=on;
  for(const id of ['barrier3d','barrierPlan'])byId(id).setAttribute('aria-pressed',String(on));
  diagram();showLayer();schedule();
}
byId('barrier3d').onclick=async()=>{
  if(!live){
    await toggleLive();
    if(live)setBarrier(true);
  }else setBarrier(!revealBarrier);
};
byId('barrierPlan').onclick=()=>setBarrier(!revealBarrier);
byId('reset').onclick=()=>{resetCamera();schedule();};
camera.onchange=refresh;layer.onchange=showLayer;
new ResizeObserver(schedule).observe(byId('overlay').parentElement);
refresh();builder();

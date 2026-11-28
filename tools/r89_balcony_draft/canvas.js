// Round 84's half-node ray marcher. Both cameras use Luanti world coordinates.
// Fixed node boxes off the half-grid (rail and waystone) get exact face tests.
const dot = (a,b) => a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const unit = a => a.map(v=>v/Math.hypot(...a));
const cross = (a,b) => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
function cameraBasis([eye,target,fov], w, h) {
  const forward=unit(target.map((v,i)=>v-eye[i]));
  const right=unit(cross([0,1,0],forward)), up=cross(forward,right);
  const f=h/(2*Math.tan(fov*Math.PI/360));
  function relative(p) {
    const v=p.map((c,i)=>c-eye[i]);
    return [dot(v,right),dot(v,up),dot(v,forward)];
  }
  function screen([x,y,z]) { return [w/2+f*x/z,h/2-f*y/z]; }
  return {right,up,forward,f,relative,screen};
}
function corners([lo,hi], padded=false) {
  return Array.from({length:8},(_,k)=>lo.map((v,i)=>k&(1<<i)?hi[i]+(padded?.5:0):v-(padded?.5:0)));
}
function territory(canvas, pose, boxes) {
  const rect=canvas.getBoundingClientRect(), scale=Math.min(devicePixelRatio,2);
  const w=canvas.width=Math.max(1,Math.round(rect.width*scale));
  const h=canvas.height=Math.max(1,Math.round(rect.height*scale));
  const ctx=canvas.getContext('2d'), cam=cameraBasis(pose,w,h);
  for(const [box,color] of boxes) {
    const pts=corners(box,true).map(cam.relative);
    ctx.beginPath();
    for(let i=0;i<8;i++) for(const bit of [1,2,4]) {
      if(i&bit) continue;
      let a=pts[i], b=pts[i|bit];
      if(a[2]<.06 && b[2]<.06) continue;
      if(Math.min(a[2],b[2])<.06) {
        if(a[2]>b[2]) [a,b]=[b,a];
        const t=(.06-a[2])/(b[2]-a[2]);
        a=a.map((c,j)=>c+t*(b[j]-c));
      }
      ctx.moveTo(...cam.screen(a)); ctx.lineTo(...cam.screen(b));
    }
    ctx.strokeStyle='#102021'; ctx.lineWidth=4*scale; ctx.stroke();
    ctx.strokeStyle=color; ctx.lineWidth=2*scale; ctx.stroke();
  }
}

async function canvasView(canvas,data) {
  const types=data.types, fx=data.smoke;
  const tiles=await Promise.all(data.textures.map(async src=>{
    const img=new Image(); img.src=src; await img.decode();
    const tile=document.createElement('canvas'); tile.width=tile.height=32;
    const c=tile.getContext('2d'); c.imageSmoothingEnabled=false;
    c.drawImage(img,0,0,32,32);
    return c.getImageData(0,0,32,32).data;
  }));
  const ctx=canvas.getContext('2d',{alpha:false});
  let min,max,grid,nx,ny,details;
  const decoded = new Map();
  function decode(encoded) {
    if(decoded.has(encoded))return decoded.get(encoded);
    const raw=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
    const dv=new DataView(raw.buffer), rows=[];
    for(let i=0;i<raw.length;i+=9)rows.push([dv.getInt16(i,true),dv.getInt16(i+2,true),
      dv.getInt16(i+4,true),dv.getUint16(i+6,true),raw[i+8]]);
    decoded.set(encoded,rows); return rows;
  }
  function setScene(packs) {
    const inputs=packs.map(decode);
    min=[Infinity,Infinity,Infinity];max=[-Infinity,-Infinity,-Infinity];
    for(const rows of inputs)for(const row of rows)for(let j=0;j<3;j++){
      min[j]=Math.min(min[j],2*row[j]);max[j]=Math.max(max[j],2*row[j]+1);
    }
    nx=max[0]-min[0]+1; ny=max[1]-min[1]+1;
    grid=new Int16Array(nx*ny*(max[2]-min[2]+1)).fill(-1);details=[];
    for(const rows of inputs)for(const [x,y,z,id,p2] of rows) {
      const type=types[id], mask=type.octants?.[p2]??255;
      if(type.boxes && !type.octants){
        for(const b of type.boxes)details.push([id,[[x+b[0],y+b[1],z+b[2]],[x+b[3],y+b[4],z+b[5]]]]);
        continue;
      }
      for(let i=0;i<8;i++)if(mask&(1<<i)){
        grid[((2*z+(i>>2)-min[2])*ny+2*y+((i>>1)&1)-min[1])*nx+2*x+(i&1)-min[0]]=id;
      }
    }
  }
  function render(pose, barriers) {
    const box=canvas.getBoundingClientRect();
    const scale=Math.min(1,720/Math.max(1,box.width));
    const w=canvas.width=Math.max(1,Math.round(box.width*scale));
    const h=canvas.height=Math.max(1,Math.round(box.height*scale));
    const img=ctx.createImageData(w,h), depth=new Float32Array(w*h).fill(Infinity), pixels=img.data;
    const cam=cameraBasis(pose,w,h), eye=pose[0], scaled=eye.map(v=>v*2+.5);
    function paint(i,t,id,face,dx,dy,dz) {
      const x=eye[0]+t*dx,y=eye[1]+t*dy,z=eye[2]+t*dz;
      const tu=face<2?x:face===2?z:face===3?-z:face===4?-x:x;
      const tv=face===0?z:face===1?-z:y;
      const j=4*((Math.floor((tu+.5)*32)&31)+32*(Math.floor((.5-tv)*32)&31));
      const type=types[id], tile=tiles[type.tex[face]];
      const light=type.light?1.07:face===0?1:face===1?.63:face<4?.82:.91;
      for(let c=0;c<3;c++)pixels[4*i+c]=tile[j+c]*light;
      depth[i]=t;
    }
    const dirs=[0,1,2].map(()=>new Float32Array(w*h));
    for(let py=0;py<h;py++) {
      const v=(h/2-py-.5)/cam.f;
      for(let px=0;px<w;px++){
        const u=(px+.5-w/2)/cam.f, i=py*w+px;
        for(let a=0;a<3;a++) dirs[a][i]=cam.forward[a]+cam.right[a]*u+cam.up[a]*v;
        const dx=dirs[0][i],dy=dirs[1][i],dz=dirs[2][i];
        const sx=dx>0?1:-1,sy=dy>0?1:-1,sz=dz>0?1:-1;
        const ix=1/(dx||1e-12),iy=1/(dy||1e-12),iz=1/(dz||1e-12);
        const ax=(min[0]-.5-scaled[0])*ix, bx=(max[0]+.5-scaled[0])*ix;
        const ay=(min[1]-.5-scaled[1])*iy, by=(max[1]+.5-scaled[1])*iy;
        const az=(min[2]-.5-scaled[2])*iz, bz=(max[2]+.5-scaled[2])*iz;
        let t=Math.max(.04,Math.min(ax,bx),Math.min(ay,by),Math.min(az,bz));
        const end=Math.min(Math.max(ax,bx),Math.max(ay,by),Math.max(az,bz));
        let x=Math.floor(scaled[0]+dx*(t+.0001)+.5),y=Math.floor(scaled[1]+dy*(t+.0001)+.5);
        let z=Math.floor(scaled[2]+dz*(t+.0001)+.5);
        let tx=(x+sx*.5-scaled[0])*ix,ty=(y+sy*.5-scaled[1])*iy,tz=(z+sz*.5-scaled[2])*iz;
        let side=t===Math.min(ax,bx)?0:t===Math.min(az,bz)?2:1, id=-1;
        while(t<end) {
          id=grid[((z-min[2])*ny+y-min[1])*nx+x-min[0]];
          if(id>=0)break;
          if(tx<ty && tx<tz){t=tx;tx+=Math.abs(ix);x+=sx;side=0;}
          else if(ty<tz){t=ty;ty+=Math.abs(iy);y+=sy;side=1;}
          else{t=tz;tz+=Math.abs(iz);z+=sz;side=2;}
        }
        if(id>=0 && t<end)paint(i,t/2,id,side===0?(sx>0?3:2):side===1?(sy>0?1:0):(sz>0?5:4),dx,dy,dz);
        else{
          const blend=Math.min(1,Math.max(0,dy*1.8));
          pixels[4*i]=dy<0?125:219-95*blend;pixels[4*i+1]=dy<0?126:209-60*blend;
          pixels[4*i+2]=dy<0?104:180-27*blend;
        }
        pixels[i*4+3]=255;
      }
    }
    // Inspect the proposed full cubes after opaque faces have filled the depth
    // buffer. Inclusive node centres extend half a node to either side.
    const surfaces=details.concat(barriers.map(([lo,hi])=>[null,[lo.map(v=>v-.5),hi.map(v=>v+.5)]]));
    for(const [id,bb] of surfaces){
      const pts=corners(bb).map(cam.relative);
      if(pts.every(p=>p[2]<=.02))continue;
      const pr=pts.map(cam.screen);
      function span(axis,limit) {
        if(pts.some(p=>p[2]<=.02))return [0,limit];
        const values=pr.map(p=>p[axis]);
        return [Math.max(0,Math.floor(Math.min(...values))),Math.min(limit,Math.ceil(Math.max(...values)))];
      }
      const [l,r]=span(0,w), [top,bottom]=span(1,h);
      for(let y=top;y<bottom;y++)for(let x=l;x<r;x++){
        const i=y*w+x;
        let start=-Infinity,stop=Infinity,face=0;
        for(let a=0;a<3;a++){
          const d=dirs[a][i]||1e-12;
          const p=(bb[0][a]-eye[a])/d, q=(bb[1][a]-eye[a])/d;
          if(Math.min(p,q)>start){start=Math.min(p,q);face=[2,0,4][a]+Number(d>0);}
          stop=Math.min(stop,Math.max(p,q));
        }
        if(start<=.01 || start>stop || start>=depth[i])continue;
        if(id!==null){
          paint(i,start,id,face,dirs[0][i],dirs[1][i],dirs[2][i]);
        }else{
          const normal=[1,1,0,0,2,2][face];
          const gridEdge=eye.some((v,a)=>{
            const cell=v+start*dirs[a][i]+.5;
            return a!==normal && Math.abs(cell-Math.round(cell))<.035;
          });
          const tint=[44,213,216], alpha=gridEdge?.85:.27;
          for(let c=0;c<3;c++)pixels[4*i+c]+=(tint[c]-pixels[4*i+c])*alpha;
        }
      }
    }
    const cards=fx.puffs.map(p=>[cam.relative(p.at),p]).sort((a,b)=>b[0][2]-a[0][2]);
    for(const [at,p] of cards){
      if(at[2]<=.05)continue;
      const [cx,cy]=cam.screen(at), size=cam.f*p.size/at[2], left=cx-size/2, top=cy-size/2;
      for(let y=Math.max(0,Math.ceil(top-.5));y<Math.min(h,top+size-.5);y++)
        for(let x=Math.max(0,Math.ceil(left-.5));x<Math.min(w,left+size-.5);x++){
          const i=y*w+x;if(depth[i]<=at[2])continue;
          const j=(Math.floor((y+.5-top)*32/size)*32+Math.floor((x+.5-left)*32/size))*4;
          const tile=tiles[fx.texture], alpha=tile[j+3]/255*p.alpha;
          for(let c=0;c<3;c++)pixels[4*i+c]+=(tile[j+c]*fx.tint[c]/255-pixels[4*i+c])*alpha;
        }
    }
    ctx.putImageData(img,0,0);
  }
  return {setScene,render};
}

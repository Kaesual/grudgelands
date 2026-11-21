async function canvasView(stage, types, sources, effect) {
  const tiles = await Promise.all(sources.map(async src => {
    const img = new Image();
    img.src = src;
    await img.decode();
    const tile = document.createElement('canvas');
    tile.width = tile.height = 32;
    const ctx = tile.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(img, 0, 0, 32, 32);
    return ctx.getImageData(0, 0, 32, 32).data;
  }));
  const canvas = document.createElement('canvas');
  stage.append(canvas);
  const ctx = canvas.getContext('2d', {alpha:false});
  const camera = new THREE.PerspectiveCamera(60, 1, .05, 1000);
  const controls = new OrbitControls(camera, canvas);
  let cells, frame, base, pixels, depth;
  function drawSmoke(seconds) {
    if (!base || stage.hidden || frame) return;
    pixels.data.set(base.data);
    const w=canvas.width, h=canvas.height, f=h/(2*Math.tan(camera.fov*Math.PI/360));
    const cards=smokeCards(effect,seconds).map(p=>{
      const v=new THREE.Vector3(p.x,p.y,-p.z).applyMatrix4(camera.matrixWorldInverse);
      return {...p, z:-v.z, sx:w/2-f*v.x/v.z, sy:h/2+f*v.y/v.z};
    }).sort((a,b)=>b.z-a.z);
    const tile=tiles[effect.texture];
    for(const p of cards){
      if(p.z<=.05) continue;
      const size=p.width*f/p.z, left=p.sx-size/2, top=p.sy-size/2;
      for(let y=Math.max(0,Math.ceil(top-.5));y<Math.min(h,top+size-.5);y++){
        for(let x=Math.max(0,Math.ceil(left-.5));x<Math.min(w,left+size-.5);x++){
          const i=y*w+x;
          if(depth[i]<=p.z)continue;
          const j=4*(Math.floor((x+.5-left)*32/size)+32*Math.floor((y+.5-top)*32/size));
          const alpha=p.alpha*tile[j+3]/255;
          for(let c=0;c<3;c++){
            const k=i*4+c;
            pixels.data[k]+=(tile[j+c]*effect.tint[c]/255-pixels.data[k])*alpha;
          }
        }
      }
    }
    ctx.putImageData(pixels,0,0);
  }
  function render() {
    frame = 0;
    if (!cells || stage.hidden) return;
    const w = canvas.width, h = canvas.height;
    base=ctx.createImageData(w,h);
    pixels=ctx.createImageData(w,h);
    depth=new Float32Array(w*h).fill(Infinity);
    controls.update();
    camera.updateMatrixWorld(true);
    const mat = camera.matrix.elements;
    const eye = [camera.position.x,camera.position.y,-camera.position.z].map(v=>v*2+.5);
    const lo = cells.min, hi = cells.max;
    const f = h / (2 * Math.tan(camera.fov * Math.PI / 360));
    for (let py=0; py<h; py++) {
      const v = (h/2-py-.5)/f;
      for (let px=0; px<w; px++) {
        const u = (px+.5-w/2)/f;
        const dx = mat[0]*u+mat[4]*v-mat[8];
        const dy = mat[1]*u+mat[5]*v-mat[9];
        const dz = -(mat[2]*u+mat[6]*v-mat[10]);
        const sx = dx>0?1:-1, sy = dy>0?1:-1, sz = dz>0?1:-1;
        const ix = 1/(dx || 1e-12), iy = 1/(dy || 1e-12), iz = 1/(dz || 1e-12);
        const ax=(lo[0]-.5-eye[0])*ix, bx=(hi[0]+.5-eye[0])*ix;
        const ay=(lo[1]-.5-eye[1])*iy, by=(hi[1]+.5-eye[1])*iy;
        const az=(lo[2]-.5-eye[2])*iz, bz=(hi[2]+.5-eye[2])*iz;
        let t=Math.max(.04, Math.min(ax,bx), Math.min(ay,by), Math.min(az,bz));
        const end=Math.min(Math.max(ax,bx), Math.max(ay,by), Math.max(az,bz));
        let x=Math.floor(eye[0]+dx*(t+.0001)+.5);
        let y=Math.floor(eye[1]+dy*(t+.0001)+.5);
        let z=Math.floor(eye[2]+dz*(t+.0001)+.5);
        let tx=(x+sx*.5-eye[0])*ix, ty=(y+sy*.5-eye[1])*iy, tz=(z+sz*.5-eye[2])*iz;
        let side = t===Math.min(ax,bx)?0:t===Math.min(az,bz)?2:1;
        let i=-1;
        while (t<=end && (i=cells.at(x,y,z))<0) {
          if (tx<ty && tx<tz) {t=tx; tx+=Math.abs(ix); x+=sx; side=0;}
          else if (ty<tz) {t=ty; ty+=Math.abs(iy); y+=sy; side=1;}
          else {t=tz; tz+=Math.abs(iz); z+=sz; side=2;}
        }
        const k=(py*w+px)*4;
        if (i>=0) {
          const face = side===0?(sx>0?3:2):side===1?(sy>0?1:0):(sz>0?5:4);
          depth[k/4]=t/2;
          const a=(eye[0]+t*dx-.5)/2, b=(eye[1]+t*dy-.5)/2, c=(eye[2]+t*dz-.5)/2;
          const tu=face<2?a:face===2?c:face===3?-c:face===4?-a:a;
          const tv=face===0?c:face===1?-c:b;
          const j=4*((Math.floor((tu+.5)*32)&31)+32*(Math.floor((.5-tv)*32)&31));
          const type=types[i], tile=tiles[type.tex[face]];
          const light=type.light?1.07:face===0?1:face===1?.60:face<4?.83:.93;
          for(let channel=0;channel<3;channel++) base.data[k+channel]=tile[j+channel]*light;
        } else {
          const blend=Math.min(1,Math.max(0,dy*1.8));
          base.data[k]=dy<0?106:216-95*blend;
          base.data[k+1]=dy<0?116:207-60*blend;
          base.data[k+2]=dy<0?93:178-27*blend;
        }
        base.data[k+3]=255;
      }
    }
    drawSmoke(smokeTime());
  }
  function step() {if (!frame) frame=requestAnimationFrame(render);}
  controls.addEventListener('change',step);
  return {
    camera, controls, step, drawSmoke,
    renderer:{domElement:canvas,setSize(w,h) {
      const scale=Math.min(1,650/Math.max(1,w),400/Math.max(1,h));
      canvas.width=Math.max(1,Math.round(w*scale)); canvas.height=Math.max(1,Math.round(h*scale));
    }},
    setData(d) {
      // Use the same half-node masks as the plates. Coordinates 2*x and
      // 2*x+1 address the two halves of node x in the ray march.
      const min=d.min.map(n=>2*n), max=d.max.map(n=>2*n+1);
      const [nx,ny,nz]=max.map((n,i)=>n-min[i]+1);
      const grid=new Int16Array(nx*ny*nz).fill(-1);
      const key=(x,y,z)=>((z-min[2])*ny+y-min[1])*nx+x-min[0];
      for(let i=0;i<d.T.length;i++){
        const mask=types[d.T[i]].octants?.[d.P2[i]] ?? 255;
        for(let j=0;j<8;j++)if(mask & 1<<j){
          grid[key(2*d.X[i]+(j&1),2*d.Y[i]+(j>>1&1),2*d.Z[i]+(j>>2))]=d.T[i];
        }
      }
      cells={min,max,at(x,y,z){
        if(x<min[0]||x>max[0]||y<min[1]||y>max[1]||z<min[2]||z>max[2])return -1;
        return grid[key(x,y,z)];
      }};
    },
    lookAt(eye,target) {
      camera.position.set(eye[0],eye[1],-eye[2]);
      controls.target.set(target[0],target[1],-target[2]);
      controls.update();
    }
  };
}

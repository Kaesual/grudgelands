// Small orbit controller for the shared node renderer's offline review pages.
// Original project code. Drag or one finger: orbit; right drag: pan;
// wheel: zoom; two fingers: pan and pinch. No network-loaded controls module.
class OrbitControls extends THREE.EventDispatcher {
  constructor(camera, element) {
    super();
    this.object = camera;
    this.target = new THREE.Vector3();
    this.enabled = true;
    this.minDistance = 2;
    this.maxDistance = 600;
    this.maxPolarAngle = Math.PI * .495;
    const pointers = new Map();
    let oldPair = null;
    const changed = () => { this.update(); this.dispatchEvent({type:'change'}); };
    const pan = (dx, dy) => {
      const distance = camera.position.distanceTo(this.target);
      const k = 2 * distance * Math.tan(camera.fov * Math.PI / 360) / element.clientHeight;
      const right = new THREE.Vector3().setFromMatrixColumn(camera.matrix, 0);
      const up = new THREE.Vector3().setFromMatrixColumn(camera.matrix, 1);
      const delta = right.multiplyScalar(-dx*k).addScaledVector(up,dy*k);
      camera.position.add(delta); this.target.add(delta);
    };
    const zoom = (factor) => {
      const v = camera.position.clone().sub(this.target);
      v.setLength(Math.max(this.minDistance, Math.min(this.maxDistance, v.length()*factor)));
      camera.position.copy(this.target).add(v);
    };
    const pair = () => {
      const [a,b] = [...pointers.values()];
      return {x:(a.x+b.x)/2,y:(a.y+b.y)/2,d:Math.hypot(a.x-b.x,a.y-b.y)};
    };
    element.addEventListener('contextmenu',e=>e.preventDefault());
    element.addEventListener('pointerdown',e=>{
      if(!this.enabled)return;
      element.setPointerCapture(e.pointerId);
      pointers.set(e.pointerId,{x:e.clientX,y:e.clientY,button:e.button});
      oldPair=pointers.size===2?pair():null;
    });
    element.addEventListener('pointermove',e=>{
      if(!this.enabled||!pointers.has(e.pointerId))return;
      const p=pointers.get(e.pointerId), dx=e.clientX-p.x, dy=e.clientY-p.y;
      pointers.set(e.pointerId,{x:e.clientX,y:e.clientY,button:p.button});
      if(pointers.size===2){
        const next=pair();
        if(oldPair){pan(next.x-oldPair.x,next.y-oldPair.y);if(next.d>1)zoom(oldPair.d/next.d);}
        oldPair=next;
      }else if(p.button===2||e.shiftKey){pan(dx,dy);}
      else{
        const s=new THREE.Spherical().setFromVector3(camera.position.clone().sub(this.target));
        s.theta-=dx*.007;
        s.phi=Math.max(.001,Math.min(this.maxPolarAngle,s.phi-dy*.007));
        camera.position.copy(this.target).add(new THREE.Vector3().setFromSpherical(s));
      }
      changed();
    });
    const release=e=>{pointers.delete(e.pointerId);oldPair=null;};
    element.addEventListener('pointerup',release);
    element.addEventListener('pointercancel',release);
    element.addEventListener('wheel',e=>{
      if(!this.enabled)return;e.preventDefault();zoom(Math.exp(e.deltaY*.001));changed();
    },{passive:false});
  }
  update(){this.object.lookAt(this.target);this.object.updateMatrixWorld();}
}

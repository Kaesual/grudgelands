// Static particles baked into this scene's still, using the shipped textures.
// They follow the renderer's world coordinates and never run in the game UI.
function introAtmosphere(spec) {
 const loader=new THREE.TextureLoader();
 const smoke=loader.load(D.textures[D.effects.smoke]);
 const fire=loader.load(D.textures[D.effects.fire]);
 for(const map of [smoke,fire]){map.magFilter=THREE.NearestFilter;map.minFilter=THREE.NearestFilter;map.generateMipmaps=false}
 for(const [index,plume] of spec.smoke.entries()){
  for(let i=0;i<36;i++){
   const t=i/35,size=plume.width*(.45+t*.8);
   const material=new THREE.SpriteMaterial({map:smoke,color:0x9a9b9e,opacity:.26*(1-t*.72),depthWrite:false,rotation:Math.sin(i*5+index)*.4});
   const sprite=new THREE.Sprite(material);
   sprite.position.set(plume.at[0]+t*plume.wind+Math.sin(i*2.1+index)*size*.25,plume.at[1]+t*plume.height,plume.at[2]+Math.cos(i)*size*.1);
   sprite.scale.set(size,size,1);view.root.add(sprite);
  }
 }
 for(const p of spec.fires){
  for(let i=0;i<3;i++){
   const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:fire,color:0xffaa65,opacity:.9,depthWrite:false}));
   sprite.position.set(p[0]+(i-1)*.48,p[1]+1+i*.25,p[2]+i*.13);
   sprite.scale.set(1.1,2.3+i*.2,1);view.root.add(sprite);
  }
 }
}

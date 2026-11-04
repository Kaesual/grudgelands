// Export the shared renderer's actual triangles without a browser or WebGL.
// Three.js is used only for BufferGeometry/Group, never for a render context.
const fs = require('fs'), path = require('path'), vm = require('vm');
const root = path.resolve(__dirname, '../..');
const THREE = require(path.join(root,'tools/r54_armor/vendor/three.min.js'));
const page = fs.readFileSync(path.join(__dirname,'index.html'),'utf8');
const payload = JSON.parse(page.match(/<script id="payload" type="application\/json">([\s\S]*?)<\/script>/)[1]);
let source = fs.readFileSync(path.join(root,'tools/building_templates/viewer/renderer.js'),'utf8');
source = source.replace(/^import [^\n]*\n/gm,'').replace(/^export (?=(?:async )?function |const |let |class )/gm,'');
const split = source.indexOf('  // ------------------------------------------------------- scene ------');
if(split < 0)throw new Error('Shared renderer geometry boundary changed');
source = source.slice(0,split) + '\nreturn {buildGroup};\n}\n';
const context = {THREE, Image:class {set src(value){this.url=value;}},
                 atob:s=>Buffer.from(s,'base64').toString('binary')};
vm.createContext(context);
vm.runInContext(source,context);
const builder = context.createNodeView({types:payload.types,textures:payload.textures,meshes:payload.meshes});
const scenes={};
const requested=process.argv.slice(2);
for(const [key, packed] of Object.entries(payload.scenes)){
  if(requested.length&&!requested.includes(key))continue;
  const group=builder.buildGroup(context.decodeCells(packed.cells,packed.count));
  scenes[key]=group.children.map(m=>({
    position:Array.from(m.geometry.attributes.position.array),
    uv:Array.from(m.geometry.attributes.uv.array),
    color:Array.from(m.geometry.attributes.color.array),
    index:Array.from(m.geometry.index.array),
    texture:payload.textures.indexOf(m.material.map.image.url),
    double:m.material.side===THREE.DoubleSide
  }));
}
process.stdout.write(JSON.stringify({textures:payload.textures,scenes}));

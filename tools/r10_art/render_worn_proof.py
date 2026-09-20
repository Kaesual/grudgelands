import bpy, os
from mathutils import Vector
ROOT=os.environ['GRUG_ROOT']; SCRATCH=os.environ['GRUG_WORN_RENDER']; OUT=os.path.join(ROOT,'docs/research/r10-visuals/worn')
ROWS=[]
for line in ('metal','cloth','leather'):
 for tier in range(1,7): ROWS.append((f'{line}_t{tier}','human',1.0,'front',tier,line))
for race,size in (('human',1.0),('dwarf',.90),('elf',1.06),('undead',.94),('orc',1.08),('troll',1.12)):
 ROWS.append((f'race_{race}','human',size,'front',6,'metal'))
for view in ('front','back','side'):
 ROWS.append((f'pose_{view}','human',1.0,view,4,'leather'))
ROWS.append(('pose_walk','human',1.0,'front',4,'leather'))

def clear():
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 for blocks in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
  for v in list(blocks): blocks.remove(v)
def render(identifier,race,size,view,tier,line):
 clear(); bpy.ops.import_scene.gltf(filepath=os.path.join(SCRATCH,'character.glb'))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 mat=bpy.data.materials.new('character');mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;nodes.clear()
 out=nodes.new('ShaderNodeOutputMaterial');em=nodes.new('ShaderNodeEmission');transparent=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader');im=nodes.new('ShaderNodeTexImage')
 im.image=bpy.data.images.load(os.path.join(SCRATCH,f'{race}_{line}_{tier}.png'),check_existing=False);im.interpolation='Closest'
 links.new(im.outputs['Color'],em.inputs['Color']);links.new(im.outputs['Alpha'],mix.inputs[0]);links.new(transparent.outputs[0],mix.inputs[1]);links.new(em.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs[0]);mat.blend_method='CLIP'
 for o in meshes:o.data.materials.clear();o.data.materials.append(mat);o.scale=(size,size,size)
 bpy.context.scene.frame_set(177 if identifier == 'pose_walk' else 10)
 corners=[]
 for o in meshes: corners += [o.matrix_world@Vector(p) for p in o.bound_box]
 low=Vector(tuple(min(p[i] for p in corners) for i in range(3))); high=Vector(tuple(max(p[i] for p in corners) for i in range(3)));centre=(low+high)/2;extent=max(high[i]-low[i] for i in range(3))
 dirs={'front':Vector((0,2.4,.15)),'back':Vector((0,-2.4,.15)),'side':Vector((2.4,0,.15))};camd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',camd);bpy.context.collection.objects.link(cam);bpy.context.scene.camera=cam;cam.location=centre+dirs[view]*extent;cam.rotation_euler=(centre-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=extent*1.18/(size if identifier.startswith('race_') else 1)
 sc=bpy.context.scene;sc.render.engine='BLENDER_EEVEE';sc.render.resolution_x=96;sc.render.resolution_y=128;sc.render.resolution_percentage=100;sc.render.film_transparent=True;sc.view_settings.view_transform='Standard';sc.render.image_settings.file_format='PNG';sc.render.filepath=os.path.join(OUT,identifier+'.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
only=os.environ.get('GRUG_WORN_ONLY','')
for row in ROWS:
 if not only or row[0].startswith(only): render(*row)
bpy.ops.wm.quit_blender()

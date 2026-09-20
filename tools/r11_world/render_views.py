"""Textured native cutaway evidence; actual cells, authored props and posed mounts.
Roof/front-wall omission is explicit; colored trainer bars are location markers,
not a claim about NPC skins. Full-cell clearance is checked before rendering.
"""
import json
import os
import sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(os.environ["GRUG_ROOT"])/"tools/r10_cap"))
from render_poses import add_mount,models,ROOT,SCRATCH
detail=os.environ.get("R11_DETAIL")=="1"
rooms=json.loads((SCRATCH/'rooms.json').read_text())
clearance=json.loads((SCRATCH/'clearance.json').read_text())['displays']
materials={}
gear=json.loads((SCRATCH/'gear-visuals.json').read_text())

def material(path):
    if path in materials:return materials[path]
    mat=bpy.data.materials.new(path);mat.use_nodes=True;mat.blend_method="CLIP"
    shader=mat.node_tree.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.9
    image=mat.node_tree.nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(path,check_existing=True)
    image.interpolation='Closest'
    mat.node_tree.links.new(image.outputs['Color'],shader.inputs['Base Color'])
    mat.node_tree.links.new(image.outputs['Alpha'],shader.inputs['Alpha'])
    materials[path]=mat;return mat


def xyz(v):return (v[0],-v[2],v[1])


def geometry(room):
    batches={}
    def face(vertices,indices,path,uv=None):
        group=batches.setdefault(path,{'v':[],'f':[],'uv':[]});offset=len(group['v'])
        group['v'].extend(xyz(v) for v in vertices);group['f'].append(tuple(offset+i for i in indices))
        group['uv'].append(uv or [(0,0),(1,0),(1,1),(0,1)])
    for cell in room['cells']:
        p=cell['pos'];tiles=cell['tiles']
        if cell['mesh']:
            verts=[];uvs=[];slot=0
            for line in Path(cell['mesh']).read_text().splitlines():
                words=line.split()
                if not words:continue
                if words[0]=='v':verts.append([float(words[i+1])+p[i] for i in range(3)])
                elif words[0]=='vt':uvs.append(tuple(map(float,words[1:])))
                elif words[0]=='usemtl':slot=1 if words[1]=='hanging' else 0
                elif words[0]=='f':
                    ids=[w.split('/') for w in words[1:]]
                    face([verts[int(i[0])-1] for i in ids],range(len(ids)),tiles[slot],
                         [uvs[int(i[1])-1] for i in ids])
            continue
        for box in cell['boxes']:
            x,y,z,X,Y,Z=box;verts=[(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)]
            verts=[[v[i]+p[i] for i in range(3)] for v in verts]
            # Luanti tiles: top,bottom,+x,-x,+z,-z.
            for side,indices in enumerate([(3,7,6,2),(0,1,5,4),(1,2,6,5),(0,4,7,3),(4,5,6,7),(0,3,2,1)]):
                face([verts[i] for i in indices],range(4),tiles[min(side,len(tiles)-1)],
                     [(0,0),(0,1),(1,1),(1,0)] if side==5 else None)
    for path,batch in batches.items():
        mesh=bpy.data.meshes.new('actual_cells');mesh.from_pydata(batch['v'],[],batch['f']);mesh.update()
        layer=mesh.uv_layers.new()
        for poly,values in zip(mesh.polygons,batch['uv']):
            for index,uv in zip(poly.loop_indices,values):layer.data[index].uv=uv
        obj=bpy.data.objects.new('actual_cells',mesh);bpy.context.collection.objects.link(obj)
        obj.data.materials.append(material(path))


bpy.ops.wm.read_factory_settings(use_empty=True)
for name,room in rooms.items():
    if detail and name.endswith("/riding"):continue
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    geometry(room)
    city,service=name.split('/')
    if service=='riding':
        for row in clearance:
            if row['city']!=city:continue
            before=set(bpy.context.scene.objects);add_mount(models[row['model']])
            for obj in set(bpy.context.scene.objects)-before:
                obj.rotation_euler[2]=3.141592653589793
                obj.location=(row['position'][0],-row['position'][2],.5)
    # Actual registered display artwork at the actual authored sockets. These
    # flat item cards show the binding; engine wielditem extrusion is separate.
    for socket in room['sockets']:
        if socket[3]!='gear_display':continue
        x,y,z=map(float,socket[:3]);definition=gear[socket[4]]
        mesh=bpy.data.meshes.new(definition['item'])
        mesh.from_pydata([(x-.4,-z,y-.4),(x+.4,-z,y-.4),
                          (x+.4,-z,y+.4),(x-.4,-z,y+.4)],[],[(0,1,2,3)])
        layer=mesh.uv_layers.new()
        for i,uv in enumerate([(0,0),(1,0),(1,1),(0,1)]):layer.data[i].uv=uv
        obj=bpy.data.objects.new(definition['item'],mesh);bpy.context.collection.objects.link(obj)
        obj.data.materials.append(material(definition['texture']))
    # Exact authored trainer positions: slender markers preserve visible access.
    for socket in room['sockets']:
        if socket[3] not in ('trainer','riding_trainer'):continue
        x,y,z=map(float,socket[:3])
        bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z,y+.6))
        obj=bpy.context.object;obj.scale=(.4,.4,1.6)
        marker=bpy.data.materials.new('trainer marker');marker.diffuse_color=(.12,.28,.85,1)
        obj.data.materials.append(marker)
    centre=Vector((0,0,1.5));extent=24 if service=='riding' else 20
    if detail:
        centre=Vector((0,9,2)) if service=='forge' else Vector((3,10,2))
        extent=9 if service=='forge' else 4
    camera_data=bpy.data.cameras.new('Camera');camera=bpy.data.objects.new('Camera',camera_data)
    bpy.context.collection.objects.link(camera);bpy.context.scene.camera=camera
    camera.location=centre+Vector((.2,1.2,.15) if detail else (.9,1.2,1.2))*extent
    camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO';camera_data.ortho_scale=extent*1.5
    for title,loc in [('Key',(10,12,25)),('Fill',(-15,-10,20))]:
        data=bpy.data.lights.new(title,'AREA');obj=bpy.data.objects.new(title,data)
        bpy.context.collection.objects.link(obj);obj.location=loc;data.energy=5000;data.size=15
    scene=bpy.context.scene
    if scene.world is None:scene.world=bpy.data.worlds.new('World')
    scene.world.color=(.3,.3,.3);scene.render.engine='BLENDER_EEVEE';scene.cycles.samples=12
    scene.cycles.use_denoising=False;scene.render.resolution_x=960;scene.render.resolution_y=768
    scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard'
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(SCRATCH/(name.replace('/','-')+('-frames.png' if detail else '-cutaway.png')))
    bpy.ops.render.render(write_still=True)
os._exit(0)

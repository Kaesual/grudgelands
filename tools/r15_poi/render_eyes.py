"""Blender eye-level views of exact R15 cells exported by render_gallery.py.
Run: blender -b -noaudio -t 2 -P tools/r15_poi/render_eyes.py
Uses the same texture/shape pipeline as WP13, plus actual fixed decor boxes.
No roof or wall is hidden. NPCs and writer-owned functional roots are omitted.
"""
import json
import tempfile
from pathlib import Path
import bpy
from mathutils import Vector

OUT=Path(__file__).resolve().parent/'gallery'
CACHE=Path(tempfile.gettempdir())/'grug-r15-poi-render'
materials={}
def mat(path):
    if path not in materials:
        m=bpy.data.materials.new(Path(path).stem); m.use_nodes=True
        bsdf=m.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Roughness'].default_value=.9
        tex=m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image=bpy.data.images.load(path,check_existing=True);tex.interpolation='Closest'
        m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        m.node_tree.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
        materials[path]=m
    return materials[path]
def xyz(v):return(v[0],-v[2],v[1])

def geometry(cells):
    batches={}
    def face(vertices,path):
        b=batches.setdefault(path,{'v':[],'f':[]});offset=len(b['v'])
        b['v'].extend(xyz(v) for v in vertices);b['f'].append(tuple(offset+i for i in range(4)))
    for c in cells:
        p=c['pos']
        if c['light']:
            light=bpy.data.lights.new('Authored lamp','POINT');light.energy=65
            light.color=(1,.74,.42);light.shadow_soft_size=.35
            obj=bpy.data.objects.new('Authored lamp',light);bpy.context.collection.objects.link(obj)
            obj.location=xyz((p[0],p[1]+.2,p[2]))
        for box in c['boxes']:
            x,y,z,X,Y,Z=box
            verts=[(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)]
            verts=[[v[i]+p[i]-.5 for i in range(3)] for v in verts]
            for side,ids in enumerate([(3,7,6,2),(0,1,5,4),(1,2,6,5),(0,4,7,3),(4,5,6,7),(0,3,2,1)]):
                face([verts[i] for i in ids],c['tiles'][side])
    for path,b in batches.items():
        mesh=bpy.data.meshes.new('authored cells');mesh.from_pydata(b['v'],[],b['f']);mesh.update()
        layer=mesh.uv_layers.new()
        for poly in mesh.polygons:
            for index,uv in zip(poly.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):layer.data[index].uv=uv
        obj=bpy.data.objects.new('authored cells',mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(mat(path))

bpy.ops.wm.read_factory_settings(use_empty=True)
views={
'goldmead_village': [('arrival',(0,2.1,-11),(-3,3,5)),('workyard',(-6,2.1,-3),(-7,1.7,-6)),('interior',(-5,2.1,2),(-5,2.0,8))],
'redtusk_outpost': [('arrival',(2,2.1,-7),(-3,3.8,3)),('stores',(1,2.1,0),(5,1.6,4))],
'mournfen_bandit_camp': [('arrival',(0,2.1,-9),(-6,2.1,4)),('ruin',(-3,2.1,1),(-7,2.2,6)),('captive',(7,2.1,8),(10,1.8,10))],
}
for name,cameras in views.items():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    geometry(json.loads((CACHE/(name+'.json')).read_text()))
    scene=bpy.context.scene
    scene.world=bpy.data.worlds.new('Overcast daylight');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.58,.68,.8,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
    light=bpy.data.lights.new('Daylight','SUN');light.energy=2;light.angle=.25
    obj=bpy.data.objects.new('Daylight',light);bpy.context.collection.objects.link(obj);obj.rotation_euler=(.5,-.3,-.7)
    data=bpy.data.cameras.new('Eye');camera=bpy.data.objects.new('Eye',data);bpy.context.collection.objects.link(camera)
    scene.camera=camera;data.lens=21
    scene.render.engine='CYCLES';scene.cycles.samples=8
    scene.render.resolution_x=900;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
    for label,eye,target in cameras:
        camera.location=xyz(eye);direction=Vector(xyz(target))-camera.location
        camera.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(CACHE/(name+'-eye-'+label+'.png'))
        bpy.ops.render.render(write_still=True)

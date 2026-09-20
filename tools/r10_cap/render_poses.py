"""Blender native textured proof of catalog stand[1], with world-unit scaling.
Run after clearance.py; outputs are evidence renders, never shipped assets.
"""
import json
import os
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(os.environ['GRUG_ROOT'])
SCRATCH=Path(os.environ['GRUG_CAP_RENDER'])
models=json.loads((SCRATCH/'posed-models.json').read_text())
textures={p.name:p for p in (ROOT/'mods').rglob('*.png')}


def material(name):
    base,*modifiers=name.split('^')
    path=textures[base]
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.blend_method='CLIP'
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    nodes.clear();output=nodes.new('ShaderNodeOutputMaterial')
    shader=nodes.new('ShaderNodeBsdfPrincipled');shader.inputs['Roughness'].default_value=.8
    image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(str(path),check_existing=True)
    image.interpolation='Closest';color=image.outputs['Color']
    for modifier in modifiers:
        if modifier.startswith('[multiply:#'):
            value=modifier.split('#')[1];multiply=nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY'
            multiply.inputs[0].default_value=1
            multiply.inputs[2].default_value=tuple(int(value[i:i+2],16)/255 for i in (0,2,4))+(1,)
            links.new(color,multiply.inputs[1]);color=multiply.outputs[0]
    links.new(color,shader.inputs['Base Color']);links.new(image.outputs['Alpha'],shader.inputs['Alpha'])
    links.new(shader.outputs[0],output.inputs[0]);return mat


def add_mount(model):
    scale=model['scale']/10;foot=model['bounds'][0][1];slot=0
    for source in model['meshes']:
        vertices=[(v[0]*scale,-v[2]*scale,v[1]*scale-foot+.02) for v in source['vertices']]
        for group in source['groups']:
            texture=model['textures'][min(slot,len(model['textures'])-1)];slot+=1
            if texture=='grug_mobs_blank.png':continue
            mesh=bpy.data.meshes.new('stand_pose');mesh.from_pydata(vertices,[],group['triangles']);mesh.update()
            uv=mesh.uv_layers.new(name='UVMap')
            for poly in mesh.polygons:
                for index in poly.loop_indices:
                    u,v=source['uv'][mesh.loops[index].vertex_index]
                    sx,sy=group['uv_scale'];uv.data[index].uv=(u*sx,1-v*sy)
            obj=bpy.data.objects.new(model['key'],mesh);bpy.context.collection.objects.link(obj)
            obj.data.materials.append(material(texture))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for key,model in models.items():
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        add_mount(model)
        lo,hi=model['bounds'];height=hi[1]-lo[1];extent=max(hi[i]-lo[i] for i in range(3))
        centre=Vector(((lo[0]+hi[0])/2,-(lo[2]+hi[2])/2,height/2))
        bpy.ops.mesh.primitive_plane_add(size=extent*2.5,location=(0,0,0))
        ground=bpy.context.object;ground.data.materials.append(material('default_stone.png'))
        camera_data=bpy.data.cameras.new('Camera');camera=bpy.data.objects.new('Camera',camera_data)
        bpy.context.collection.objects.link(camera);bpy.context.scene.camera=camera
        camera.location=centre+Vector((1.2,-1.8,.9))*extent
        camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler()
        camera_data.type='ORTHO';camera_data.ortho_scale=extent*1.9
        for name,location,energy in [('Key',(2,-3,5),1000),('Fill',(-3,1,3),600)]:
            data=bpy.data.lights.new(name,'AREA');light=bpy.data.objects.new(name,data)
            bpy.context.collection.objects.link(light);light.location=centre+Vector(location)*max(1,extent/2)
            data.energy=energy*extent;data.size=extent*2
        scene=bpy.context.scene
        if scene.world is None: scene.world=bpy.data.worlds.new('World')
        scene.world.color=(.3,.3,.3)
        scene.render.engine='BLENDER_EEVEE';scene.cycles.samples=16
        scene.cycles.use_denoising=False
        scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
        scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
        scene.render.filepath=str(SCRATCH/(key+'-stand.png'))
        bpy.ops.render.render(write_still=True)

if __name__ == '__main__':
    main()
    os._exit(0)

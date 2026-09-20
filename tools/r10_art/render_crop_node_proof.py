import bpy, os
from mathutils import Vector

root = os.environ["GRUG_ROOT"]
scratch = os.environ["GRUG_CROP_PROOF"]
textures = os.path.join(root, "mods/ITEMS/grug_farming/textures")

def material(path):
    mat = bpy.data.materials.new(os.path.basename(path)); mat.use_nodes = True
    nodes = mat.node_tree.nodes; links = mat.node_tree.links; nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial"); emission = nodes.new("ShaderNodeEmission")
    transparent = nodes.new("ShaderNodeBsdfTransparent"); mix = nodes.new("ShaderNodeMixShader")
    image = nodes.new("ShaderNodeTexImage"); image.image = bpy.data.images.load(path, check_existing=False)
    image.interpolation = "Closest"
    links.new(image.outputs["Color"], emission.inputs["Color"])
    links.new(image.outputs["Alpha"], mix.inputs[0]); links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2]); links.new(mix.outputs[0], out.inputs[0])
    mat.blend_method = "CLIP"
    return mat

def cube(box, top, side):
    x1,y1,z1,x2,y2,z2 = box
    bpy.ops.mesh.primitive_cube_add(location=((x1+x2)/2, (z1+z2)/2, (y1+y2)/2),
        scale=((x2-x1)/2, (z2-z1)/2, (y2-y1)/2))
    obj = bpy.context.object; obj.data.materials.append(side); obj.data.materials.append(top)
    for polygon in obj.data.polygons:
        polygon.material_index = 1 if polygon.normal.z > 0.5 else 0

def render(family, stage):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if family == "salt_crust":
        top = material(os.path.join(scratch, "salt_top_%d.png" % stage))
        side = material(os.path.join(textures, "grug_farming_salt_crust_%d_side.png" % stage))
        boxes = [
            [(-.5,-.5,-.5,.5,-.375,.5)],
            [(-.5,-.5,-.5,.5,-.375,.5)],
            [(-.5,-.5,-.5,.5,-.375,.5),(-.0625,-.5,-.0625,.0625,-.25,.0625)],
            [(-.5,-.5,-.5,.5,-.375,.5),(-.1875,-.375,-.1875,.1875,-.25,.1875),(-.0625,-.25,-.0625,.0625,-.125,.0625)],
        ]
        for box in boxes[stage-1]: cube(box, top, side)
    else:
        mat = material(os.path.join(textures, "grug_farming_%s_%d.png" % (family, stage)))
        scale = .55 + stage * .15
        for angle in (0, 1.57079632679):
            bpy.ops.mesh.primitive_plane_add(size=1, location=(0,0,(scale-1)/2), rotation=(1.57079632679,0,angle))
            obj=bpy.context.object; obj.scale=(scale,scale,scale); obj.data.materials.append(mat)
    bpy.ops.mesh.primitive_plane_add(size=2, location=(0,0,-.505)); ground=bpy.context.object
    ground.data.materials.append(material(os.path.join(root,"mods/BASE/default/textures/default_dirt.png")))
    cam_data=bpy.data.cameras.new("Camera"); cam=bpy.data.objects.new("Camera",cam_data); bpy.context.collection.objects.link(cam)
    cam.location=(1.7,-2.2,1.55); cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam_data.type="ORTHO"; cam_data.ortho_scale=1.75; bpy.context.scene.camera=cam
    scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE"; scene.render.resolution_x=192; scene.render.resolution_y=192
    scene.render.resolution_percentage=100; scene.view_settings.view_transform="Standard"; scene.render.image_settings.file_format="PNG"
    scene.world=bpy.data.worlds.new("World"); scene.world.color=(.18,.18,.18)
    scene.render.filepath=os.path.join(scratch,"%s_%d.png"%(family,stage))
    bpy.ops.render.render(write_still=True)

for family in ("sugar_cane", "bamboo_shoot", "salt_crust"):
    for stage in range(1,5): render(family, stage)
bpy.ops.wm.quit_blender()

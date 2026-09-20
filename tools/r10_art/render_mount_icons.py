import bpy
import math
import os
from mathutils import Vector

ROOT = os.environ["GRUG_ROOT"]
SCRATCH = os.environ["GRUG_MOUNT_RENDER"]
OUT = os.path.join(ROOT, "mods/PLAYER/grug_mounts/textures")

ROWS = [
    ("t1_accord", "horse", "mods/PLAYER/grug_mounts/textures/grug_mounts_horse_white.png", "91b5ee"),
    ("t1_throng", "horse", "mods/PLAYER/grug_mounts/textures/grug_mounts_horse_brown.png", "c87575"),
    ("human", "horse", "mods/PLAYER/grug_mounts/textures/grug_mounts_horse_white.png", "ead7a0"),
    ("dwarf", "ibex", "mods/ENTITIES/grug_mobs/textures/grug_mobs_ibex.png", "d8c49d"),
    ("elf", "stag", "mods/ENTITIES/grug_mobs/textures/grug_mobs_stag.png", "ffffff"),
    ("orc", "boar", "mods/ENTITIES/grug_mobs/textures/grug_mobs_boar.png", "9a6047"),
    ("undead", "wolf", "mods/ENTITIES/grug_mobs/textures/grug_mobs_wolf_blightfang.png", "b3a6ca"),
    ("troll", "tiger", "mods/PLAYER/grug_mounts/textures/grug_mounts_tiger.png", "d69a52"),
    ("expert_accord", "eagle", "mods/ENTITIES/grug_mobs/textures/grug_mobs_eagle.png", "9eb9dc"),
    ("master_accord", "eagle", "mods/ENTITIES/grug_mobs/textures/grug_mobs_eagle.png", "eee3b6"),
    ("expert_throng", "bat", "mods/ENTITIES/grug_mobs/textures/grug_mobs_cave_bat.png", "856f8e"),
    ("master_throng", "bat", "mods/ENTITIES/grug_mobs/textures/grug_mobs_cave_bat.png", "7d3549"),
]

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                  bpy.data.cameras, bpy.data.lights):
        for value in list(block):
            block.remove(value)

def rgba(hex_value):
    rgb = [int(hex_value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(rgb + [1.0])

def render(identifier, model, texture, tint):
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(SCRATCH, model + ".glb"))
    material = bpy.data.materials.new("mount")
    material.use_nodes = True
    material.blend_method = "CLIP"
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    shader = nodes.new("ShaderNodeMixShader")
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(os.path.join(ROOT, texture), check_existing=False)
    image.interpolation = "Closest"
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs[0].default_value = 1.0
    multiply.inputs[2].default_value = rgba(tint)
    links.new(image.outputs["Color"], multiply.inputs[1])
    links.new(multiply.outputs["Color"], emission.inputs["Color"])
    links.new(image.outputs["Alpha"], shader.inputs[0])
    links.new(transparent.outputs[0], shader.inputs[1])
    links.new(emission.outputs[0], shader.inputs[2])
    links.new(shader.outputs[0], output.inputs[0])
    blank = bpy.data.materials.new("blank")
    blank.use_nodes = True
    blank.blend_method = "BLEND"
    blank_nodes = blank.node_tree.nodes
    blank_links = blank.node_tree.links
    blank_shader = blank_nodes.get("Principled BSDF")
    blank_shader.inputs["Alpha"].default_value = 0.0
    blank_links.new(blank_shader.outputs[0], blank_nodes.get("Material Output").inputs[0])
    meshes = sorted((obj for obj in bpy.context.scene.objects if obj.type == "MESH"),
                    key=lambda obj: obj.name)
    # Preserve the shipped texture-slot semantics. Assimp exposes the horse's
    # three buffers as named mesh objects, while the boar remains one mesh with
    # Skin/Saddle material slots.
    horse_hidden = {"chest_right", "saddle_top"}
    for obj in meshes:
        if model == "horse":
            obj.data.materials.clear()
            obj.data.materials.append(blank if obj.name in horse_hidden else material)
        elif model == "boar":
            for slot in obj.material_slots:
                slot.material = blank if slot.name == "Saddle" else material
        else:
            obj.data.materials.clear()
            obj.data.materials.append(material)
    corners = []
    for obj in meshes:
        corners.extend(obj.matrix_world @ Vector(point) for point in obj.bound_box)
    low = Vector(tuple(min(point[i] for point in corners) for i in range(3)))
    high = Vector(tuple(max(point[i] for point in corners) for i in range(3)))
    centre = (low + high) / 2.0
    extent = max(high[i] - low[i] for i in range(3))
    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    view = Vector((-1.15, 1.65, 0.8)) if model in {"wolf", "tiger"} else \
        Vector((1.15, -1.65, 0.8))
    camera.location = centre + view * extent
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = extent * 1.35
    light_data = bpy.data.lights.new("Key", "AREA")
    light = bpy.data.objects.new("Key", light_data)
    bpy.context.collection.objects.link(light)
    light.location = centre + Vector((extent, -extent, extent * 2.0))
    light_data.energy = 550
    light_data.size = extent
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 64
    scene.render.resolution_y = 64
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = os.path.join(OUT, "grug_mounts_icon_" + identifier + ".png")
    bpy.ops.render.render(write_still=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
for row in ROWS:
    render(*row)
bpy.ops.wm.quit_blender()

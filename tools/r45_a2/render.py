"""Small Pillow renderer of real fixed node boxes and six shared 16px tiles.

GPL-3.0-or-later. No mesh, per-box materials, smoothing or invented detail.
UVs follow Luanti generateCuboidTextureCoords/setupCuboidVertices in
reference_projects/luanti/src/client/content_mapblock.cpp:140-193,345-367.
Faces are divided at texel and box boundaries; hidden interior patches are
removed, then textured patches are painted far-to-near (painter's order).
The camera is perspective, with 30-degree elevation and opposite azimuths.
"""

import math
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw


FACE_NAMES = ("top", "bottom", "right", "left", "back", "front")
# axis, sign, horizontal UV axis/sign, vertical UV axis/sign
FACES = ((1, 1, 0, 1, 2, -1), (1, -1, 0, 1, 2, 1),
         (0, 1, 2, 1, 1, -1), (0, -1, 2, -1, 1, -1),
         (2, 1, 0, -1, 1, -1), (2, -1, 0, 1, 1, -1))
SIZE = 320
BG = (230, 227, 217)


def uv(face, point):
    _, _, u, us, v, vs = FACES[face]
    return .5 + point[u] * us, .5 + point[v] * vs


def point_at(face, u, v, depth):
    axis, _, ua, us, va, vs = FACES[face]
    p = [0., 0., 0.]
    p[axis] = depth
    p[ua] = (u - .5) * us
    p[va] = (v - .5) * vs
    return p


def load_design(path):
    """Read only our generated literal table; malformed output is an error."""
    text = path.read_text()
    body = text.split("boxes = {", 1)[1].split("tiles = {", 1)
    boxes = [tuple(float(v.strip()) for v in row.split(","))
             for row in re.findall(r"\{([^{}]+)\}", body[0])]
    tiles = re.findall(r'"([^"\n]+\.png)"', body[1])
    assert boxes and len(tiles) == 6, path
    for box in boxes:
        assert len(box) == 6 and all(-.5 <= n <= .5 for n in box), path
        assert all(box[i] < box[i + 3] for i in range(3)), path
    images = []
    for name in tiles:
        assert Path(name).name == name, (path, name)
        im = Image.open(path.parent / name).convert("RGB")
        assert im.size == (16, 16), path
        images.append(im)
    return boxes, images


def load_anvil(repo):
    """Load the current forge with LuaJIT; never maintain a second geometry."""
    script = '''
local root = arg[1]
local environment = {default = {}}
local chunk = assert(loadfile(root .. "/mods/PLAYER/grug_jobs/station_visuals.lua"))
setfenv(chunk, environment)
local forge = chunk().forge
for _, b in ipairs(forge.boxes) do print(table.concat(b, ",")) end
print("TILES")
for _, tile in ipairs(forge.tiles) do print(tile) end
'''
    # One short process; the art generator never starts concurrent Lua jobs.
    value = subprocess.run(["luajit", "-", str(repo)], input=script,
                           text=True, capture_output=True, check=True).stdout
    geometry, names = value.strip().split("TILES\n")
    boxes = [tuple(map(float, row.split(","))) for row in geometry.splitlines()]
    images = []
    for name in names.splitlines():
        pieces = name.split("^")
        image = Image.open(repo / "mods/PLAYER/grug_jobs/textures" / pieces[0]).convert("RGB")
        for modifier in pieces[1:]:
            assert modifier == "[transformR90", modifier
            image = image.transpose(Image.Transpose.ROTATE_90)
        images.append(image)
    return boxes, images + [images[-1]] * (6 - len(images))


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def unit(v):
    length = math.sqrt(dot(v, v))
    return tuple(n / length for n in v)


def render(boxes, tiles, view):
    azimuth = math.radians(-135 if view == 1 else 45)
    elevation = math.radians(30)
    outward = (math.cos(elevation) * math.sin(azimuth), math.sin(elevation),
               math.cos(elevation) * math.cos(azimuth))
    target = (0, -.02, 0)
    distance = 4.5
    eye = tuple(target[i] + outward[i] * distance for i in range(3))
    right = unit((outward[2], 0, -outward[0]))
    up = (outward[1] * right[2], outward[2] * right[0] - outward[0] * right[2],
          -outward[1] * right[0])

    def project(point):
        relative = tuple(point[i] - target[i] for i in range(3))
        depth = distance - dot(relative, outward)
        factor = 850 / depth
        return (SIZE / 2 + dot(relative, right) * factor,
                SIZE / 2 - dot(relative, up) * factor, depth)

    image = Image.new("RGB", (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(image)
    # A quiet, one-node ground guide; it is not part of the object.
    floor = [(-.5, -.503, -.5), (.5, -.503, -.5),
             (.5, -.503, .5), (-.5, -.503, .5)]
    draw.polygon([project(p)[:2] for p in floor], fill=(215, 212, 201))
    draw.line([project(p)[:2] for p in floor + floor[:1]], fill=(196, 194, 183), width=1)
    light = unit((-.6, 1, -.4))
    fragments = []
    # Every boundary is included so shared/touching/overlapping boxes can be
    # culled without removing an exposed portion of a larger face.
    cuts = [sorted({n / 16 for n in range(-8, 9)} |
                   {b[i] for b in boxes} | {b[i + 3] for b in boxes}) for i in range(3)]
    for box in boxes:
        for face, (axis, sign, ua, _, va, _) in enumerate(FACES):
            plane = box[axis + (3 if sign > 0 else 0)]
            if (eye[axis] - plane) * sign <= 0:
                continue
            u_cuts = [v for v in cuts[ua] if box[ua] <= v <= box[ua + 3]]
            v_cuts = [v for v in cuts[va] if box[va] <= v <= box[va + 3]]
            shade = .72 + .28 * max(0, light[axis] * sign)
            for lo, hi in zip(u_cuts, u_cuts[1:]):
                for bottom, top in zip(v_cuts, v_cuts[1:]):
                    middle = [0., 0., 0.]
                    middle[axis] = plane + sign * 1e-7
                    middle[ua], middle[va] = (lo + hi) / 2, (bottom + top) / 2
                    if any(all(b[i] < middle[i] < b[i + 3] for i in range(3)) for b in boxes):
                        continue
                    middle[axis] = plane
                    u, v = uv(face, middle)
                    rgb = tiles[face].getpixel((min(15, max(0, int(u * 16))),
                                               min(15, max(0, int(v * 16)))))
                    colour = tuple(round(c * shade) for c in rgb)
                    points = []
                    for a, b in ((lo, bottom), (hi, bottom), (hi, top), (lo, top)):
                        point = list(middle)
                        point[ua], point[va] = a, b
                        points.append(project(point))
                    depth = sum(p[2] for p in points) / 4
                    fragments.append((depth, [p[:2] for p in points], colour))
    for _, polygon, colour in sorted(fragments, key=lambda row: -row[0]):
        draw.polygon(polygon, fill=colour)
    return image


# Original hand-defined five-column caption alphabet; no external font files.
GLYPHS = {
    "A": [14,17,17,31,17,17,17], "B": [30,17,17,30,17,17,30],
    "C": [14,17,16,16,16,17,14], "D": [30,17,17,17,17,17,30],
    "E": [31,16,16,30,16,16,31], "F": [31,16,16,30,16,16,16],
    "G": [14,17,16,23,17,17,15], "H": [17,17,17,31,17,17,17],
    "I": [14,4,4,4,4,4,14], "J": [7,2,2,2,18,18,12],
    "K": [17,18,20,24,20,18,17], "L": [16,16,16,16,16,16,31],
    "M": [17,27,21,21,17,17,17], "N": [17,25,25,21,19,19,17],
    "O": [14,17,17,17,17,17,14], "P": [30,17,17,30,16,16,16],
    "Q": [14,17,17,17,21,18,13], "R": [30,17,17,30,20,18,17],
    "S": [15,16,16,14,1,1,30], "T": [31,4,4,4,4,4,4],
    "U": [17,17,17,17,17,17,14], "V": [17,17,17,17,17,10,4],
    "W": [17,17,17,21,21,21,10], "X": [17,17,10,4,10,17,17],
    "Y": [17,17,10,4,4,4,4], "Z": [31,1,2,4,8,16,31],
    "0": [14,17,19,21,25,17,14], "1": [4,12,4,4,4,4,14],
    "2": [14,17,1,2,4,8,31], "3": [30,1,1,14,1,1,30],
    "4": [2,6,10,18,31,2,2], "5": [31,16,16,30,1,1,30],
    "6": [14,16,16,30,17,17,14], "7": [31,1,2,4,8,8,8],
    "8": [14,17,17,14,17,17,14], "9": [14,17,17,15,1,1,14],
    "-": [0,0,0,31,0,0,0], "/": [1,2,2,4,8,8,16],
    ".": [0,0,0,0,0,12,12], ":": [0,12,12,0,12,12,0],
    "'": [4,4,8,0,0,0,0], "+": [0,4,4,31,4,4,0],
    "(": [2,4,8,8,8,4,2], ")": [8,4,2,2,2,4,8],
    " ": [0,0,0,0,0,0,0],
}


def caption(image, xy, text, scale=2, colour=(44, 59, 58)):
    draw = ImageDraw.Draw(image)
    x, y = xy
    for char in text.upper():
        rows = GLYPHS[char]
        for row, bits in enumerate(rows):
            for col in range(5):
                if bits & (1 << (4 - col)):
                    draw.rectangle((x + col * scale, y + row * scale,
                                    x + (col + 1) * scale - 1,
                                    y + (row + 1) * scale - 1), fill=colour)
        x += scale * 6


def sheet(station, designs, root):
    image = Image.new("RGB", (1088, 910), (244, 240, 229))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 1087, 90), fill=(36, 53, 53))
    caption(image, (24, 17), "GRUDGELANDS / STATION STUDIES", 2, (191, 176, 139))
    title = station.replace("_", " ")
    caption(image, (24, 48), title, 4, (244, 240, 229))
    caption(image, (24, 111), "ROUND 45 A2 / 16 X 16 TILES / ONE NODE / 30 DEGREE CAMERA", 2)
    for index, design in enumerate(designs):
        x = 24 + index * 352
        draw.rectangle((x - 1, 151, x + 321, 853), outline=(200, 194, 177))
        draw.rectangle((x, 152, x + 320, 194), fill=(222, 214, 194))
        caption(image, (x + 10, 165), design.variant + " / " + design.title, 2)
        for view in (1, 2):
            image.paste(Image.open(root / station / design.variant / f"view{view}.png"),
                        (x, 195 + (view - 1) * 330))
        caption(image, (x + 8, 502), "FRONT-LEFT", 1)
        caption(image, (x + 8, 832), "BACK-RIGHT", 1)
    caption(image, (24, 874), "ORIGINAL ART / GPT-6 ASTRA / CC0 1.0 / ACTUAL BOXES AND SHARED TILES", 2)
    return image


def reference_sheet(repo):
    boxes, tiles = load_anvil(repo)
    image = Image.new("RGB", (736, 472), (244, 240, 229))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 735, 71), fill=(36, 53, 53))
    caption(image, (24, 20), "CURRENT ANVIL / REFERENCE", 3, (244, 240, 229))
    for view in (1, 2):
        x = 24 + (view - 1) * 368
        image.paste(render(boxes, tiles, view), (x, 86))
        caption(image, (x, 420), "FRONT-LEFT" if view == 1 else "BACK-RIGHT", 2)
    caption(image, (24, 450), "EXISTING MEDIA / CC BY-SA 4.0 / ATTRIBUTION IN README.MD", 1)
    return image

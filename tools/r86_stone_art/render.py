"""Orthographic daylight studies of the exported boxes and Luanti cuboid tiles."""

import json
import math
from functools import lru_cache
from itertools import product
from PIL import Image, ImageDraw, ImageFilter

from paint import ROOT, uv

AZIMUTH, ELEVATION = map(math.radians, (24, 22))
SA, CA = math.sin(AZIMUTH), math.cos(AZIMUTH)
SE, CE = math.sin(ELEVATION), math.cos(ELEVATION)
RIGHT, UP = (CA, 0, SA), (-SA * SE, CE, CA * SE)
EYE = (SA * CE, SE, -CA * CE)
# DDA traverses the grid away from the eye. Only viewer-facing surfaces enter.
STEPS = (-1, -1, 1)
FACING = (2, 0, 5)
SHADES = (.79, 1., .94)
SCALE = 7
SIZE = (380, 238)
ORIGIN = (189, 195)
PAPER = "#e9e7db"


def project(x, y, z, origin=ORIGIN, scale=SCALE):
    return (origin[0] + scale * (CA * x + SA * z),
            origin[1] - scale * (UP[0] * x + UP[1] * y + UP[2] * z))


def cell_set(boxes):
    cells = set()
    for box in boxes:
        lo_x, lo_y, lo_z, hi_x, hi_y, hi_z = (n + 8 for n in box)
        cells.update(product(range(lo_x, hi_x), range(lo_y, hi_y), range(lo_z, hi_z)))
    return cells


def trace(cells, tiles, start, opacity):
    """Front-to-back ray, stopping at the first opaque hit or the node boundary."""
    entry = [((16 if step < 0 else 0) - p) / -v
             for step, p, v in zip(STEPS, start, EYE)]
    exit_at = min(((0 if step < 0 else 16) - p) / -v
                  for step, p, v in zip(STEPS, start, EYE))
    axis = max(range(3), key=entry.__getitem__)
    t = entry[axis]
    if t >= exit_at - 1e-8:
        return None
    cell = [int(math.floor(p - (t + 1e-7) * v)) for p, v in zip(start, EYE)]
    across = [(cell[i] + int(STEPS[i] > 0) - start[i]) / -EYE[i] for i in range(3)]
    inside = False
    rgb, coverage = [0., 0., 0.], 0.
    while all(0 <= n < 16 for n in cell):
        filled = tuple(cell) in cells
        if filled and not inside:
            face = FACING[axis]
            pixel = tiles[face].getpixel(uv(face, cell))
            colour = [round(c * SHADES[axis]) for c in pixel[:3]]
            if opacity == 255:
                return (*colour, 255)
            weight = (1 - coverage) * opacity / 255
            for i, value in enumerate(colour):
                rgb[i] += value * weight
            coverage += weight
        inside = filled
        axis = min(range(3), key=across.__getitem__)
        cell[axis] += STEPS[axis]
        across[axis] += abs(1 / EYE[axis])
    if coverage:
        return (*[round(value / coverage) for value in rgb], round(255 * coverage))
    return None


def node_sprite(boxes, tiles, opacity=255, scale=SCALE):
    corners = [project(*p, origin=(0, 0), scale=scale) for p in product((0, 16), repeat=3)]
    x0 = math.floor(min(p[0] for p in corners))
    y0 = math.floor(min(p[1] for p in corners))
    width = math.ceil(max(p[0] for p in corners)) - x0
    height = math.ceil(max(p[1] for p in corners)) - y0
    result = Image.new("RGBA", (width, height))
    pixels = result.load()
    cells = cell_set(boxes)
    for y in range(height):
        sy = -(y0 + y + .5) / scale
        for x in range(width):
            sx = (x0 + x + .5) / scale
            start = [sx * right + sy * up + 60 * outward
                     for right, up, outward in zip(RIGHT, UP, EYE)]
            hit = trace(cells, tiles, start, opacity)
            if hit:
                pixels[x, y] = hit
    return result, (x0, y0)


def stone_colour(x, z, flagstone=False):
    # Original study-floor and plain stone cube. Long, quiet chisel marks
    # keep both at the game's texel scale without borrowing a shipped tile.
    if flagstone:
        row = z // 10
        bx, bz = (x + row * 8) % 16, z % 10
        value = (row * 19 + (x + row * 8) // 16 * 7) % 5
        if bx == 0 or bz == 0:
            return (122, 127, 112)
        if bx == 1 or bz == 1:
            return (169, 172, 151)
        base = (157, 161, 142)
    else:
        value = ((x + z) // 5 * 7 + (x - 2 * z) // 8) % 7
        base = (150, 150, 137)
    if (x - 2 * z) % 19 in (1, 2) and z % 5 == 1:
        value -= 11
    return tuple(c + value for c in base)


@lru_cache
def background():
    canvas = Image.new("RGBA", SIZE, PAPER)
    shadow = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(shadow)
    limits = (-24, -2, 17, 22)
    x1, z1, x2, z2 = limits
    corners = [(x1, z1), (x1, z2), (x2, z2), (x2, z1)]
    draw.polygon([project(x, -2, z) for x, z in corners], fill=(62, 61, 47, 62))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(5)))
    draw = ImageDraw.Draw(canvas)
    for a, b, colour in [(corners[2], corners[3], "#73766c"), (corners[3], corners[0], "#919486")]:
        draw.polygon([project(a[0], 0, a[1]), project(b[0], 0, b[1]),
                      project(b[0], -1.5, b[1]), project(a[0], -1.5, a[1])], fill=colour)
    for x in range(x1, x2):
        for z in range(z1, z2):
            quad = [(x, z), (x + 1, z), (x + 1, z + 1), (x, z + 1)]
            draw.polygon([project(a, 0, b) for a, b in quad], fill=stone_colour(x, z, True))
    cube, offset = scale_cube()
    origin = project(-23, 0, 5)
    blob(canvas, -23, 5, 0, 16, 16)
    canvas.alpha_composite(cube, tuple(round(o + d) for o, d in zip(origin, offset)))
    return canvas


@lru_cache
def scale_cube():
    im = Image.new("RGBA", (16, 16))
    im.putdata([stone_colour(x, y) for y in range(16) for x in range(16)])
    return node_sprite([[-8, -8, -8, 8, 8, 8]], [im] * 6)


def blob(canvas, x, z, inset, width, depth, alpha=48):
    overlay = Image.new("RGBA", SIZE)
    b = [(x + inset, z + inset), (x + width, z + inset),
         (x + width + 1, z + depth), (x + inset + 1, z + depth + 1)]
    ImageDraw.Draw(overlay).polygon([project(tx, 0, tz) for tx, tz in b], fill=(47, 45, 35, alpha))
    canvas.alpha_composite(overlay.filter(ImageFilter.GaussianBlur(2)))


def read_node(folder, kind, state, manifest):
    data = manifest["variants"][kind][state]
    source = manifest["variants"][kind][data.get("geometry_and_tiles", state)]
    tiles = [Image.open(folder / name).convert("RGBA") for name in source["tiles"]]
    if "colorize" in data:
        tint = Image.new("RGBA", (16, 16), data["colorize"])
        tiles = [Image.blend(tile, tint, data["colorize_strength"] / 255) for tile in tiles]
    return source["boxes"], tiles, data.get("opacity", 255)


def world_view(boxes, tiles, opacity):
    sprite, offset = node_sprite(boxes, tiles, opacity)
    canvas = background().copy()
    feet = [box for box in boxes if box[1] == -8]
    xmin, zmin = (min(box[i] for box in feet) + 8 for i in (0, 2))
    xmax, zmax = (max(box[i] for box in feet) + 8 for i in (3, 5))
    blob(canvas, xmin, zmin, 0, xmax - xmin, zmax - zmin, 20 if opacity < 255 else 55)
    canvas.alpha_composite(sprite, tuple(o + d for o, d in zip(ORIGIN, offset)))
    return canvas.convert("RGB"), sprite


def studies(design):
    folder = ROOT / "art" / design
    manifest = json.loads((folder / "nodes.json").read_text())
    scenes, subjects, icons = {}, {}, {}
    for kind, states in manifest["variants"].items():
        for state in states:
            boxes, tiles, opacity = read_node(folder, kind, state, manifest)
            scenes[kind, state], sprite = world_view(boxes, tiles, opacity)
            if state == "active":
                subjects[kind] = sprite.crop(sprite.getbbox())
                icons[kind] = Image.open(folder / states[state]["inventory_image"]).convert("RGBA")
    marker = Image.open(folder / manifest["stone_texture"]).convert("RGBA")
    return scenes, subjects, icons, marker

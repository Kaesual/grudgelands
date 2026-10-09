#!/usr/bin/env python3
"""Generate the Round 45 A2 station designs, sheets and the picked game tiles.

Run from any directory: python3 tools/r45_a2/generate.py [--check]
Only Pillow and LuaJIT are needed. No downloads, random seeds or AI image API.
Code GPL-3.0-or-later; generated original art CC0-1.0 (anvil excluded).
The fifteen designs are generated in a scratch folder; the repository keeps
each design.lua, the five proposal sheets and the anvil reference (the record
of the pick), the picked tiles under their game names and final_sheet.png,
rendered from the registered game nodes.
"""

import argparse
from pathlib import Path
import subprocess
import tempfile

from PIL import Image, ImageDraw

from designs import all_designs
from render import FACES, FACE_NAMES, caption, load_design, point_at, reference_sheet, render, sheet, uv


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
# The user's pick per station (2026-10-09); the forge's anvil is unchanged.
# station -> (variant, node, the owning mod's textures folder, tile prefix).
PICKS = {
    "tanning_rack": ("B", "grug_jobs:tanning_rack",
                     "mods/PLAYER/grug_jobs/textures", "grug_jobs_tanning_rack"),
    "tailor_bench": ("B", "grug_jobs:tailor_bench",
                     "mods/PLAYER/grug_jobs/textures", "grug_jobs_tailor_bench"),
    "carving_bench": ("B", "grug_jobs:carving_bench",
                      "mods/PLAYER/grug_jobs/textures", "grug_jobs_carving_bench"),
    "jewellers_bench": ("A", "grug_jobs:jewellers_bench",
                        "mods/PLAYER/grug_jobs/textures", "grug_jobs_jewellers_bench"),
    "brewing_stand": ("B", "grug_brewing:brewing_stand",
                      "mods/ITEMS/grug_brewing/textures", "grug_brewing_stand"),
}
PALETTES = {
    "oak": ("553b2b", "785338", "936b48", "b18a5d"),
    "walnut": ("3f3028", "594030", "77573c", "95764e"),
    "endgrain": ("785335", "a3794b", "be9660", "d2af78"),
    "freshwood": ("916637", "b38b50", "d1ad6a", "e0c589"),
    "bark": ("372c24", "523b2a", "745033", "936b43"),
    "hide": ("856044", "b38a58", "c19864", "d2ad76"),
    "pale_hide": ("96836a", "b6a181", "c3b18e", "d7c5a1"),
    "russet": ("624230", "916044", "9f6e4a", "b7875a"),
    "rope": ("82714c", "bba675", "d5c392", "e5d6b1"),
    "thread": ("a69b7a", "c4bda1", "ddd5bc", "eee7d2"),
    "linen": ("978d71", "bdb59b", "ded3b7", "ede3c9"),
    "cloth": ("2f5156", "426e76", "527e86", "98b6ac"),
    "plum_cloth": ("534058", "735978", "85698a", "bba2b3"),
    "felt": ("263f3b", "3a5d51", "567365", "7a9071"),
    "iron": ("252928", "3e4443", "596261", "7e8986"),
    "steel": ("464e4c", "778580", "a2b0a6", "d4d9c4"),
    "brass": ("6b5130", "a78343", "ceb26d", "e4cf8d"),
    "copper": ("684436", "986346", "bd8659", "dca872"),
    "stone": ("46494a", "666d6d", "858d88", "a0a599"),
    "grindstone": ("555b5a", "7d8680", "a0aaa0", "bfc6b4"),
    "cork": ("775234", "9c7347", "b79561", "d3b37d"),
    "gem_teal": ("183d46", "246c75", "4da6a7", "b0e5da"),
    "gem_ruby": ("562e43", "8e4157", "c16c76", "efd0b6"),
    "gem_violet": ("403451", "665082", "9c7cb8", "decce0"),
    "glass_teal": ("30515a", "488e96", "92c2c1", "d3e5d8"),
    "glass_violet": ("4b3d61", "83668e", "b2a2bc", "e0d9df"),
    "glass_green": ("3e5645", "658a5a", "a4bd82", "dde1b2"),
    "ember": ("7b3729", "be6134", "e59b4e", "f5d587"),
}
PALETTES = {name: tuple(tuple(bytes.fromhex(colour)) for colour in rows)
            for name, rows in PALETTES.items()}


def pigment(material, box, face, u, v, boundary=False):
    """Native pixel painting: subdued grain, stitches, polished edges, facets."""
    a, b = uv(face, box[:3]), uv(face, box[3:])
    left, right = sorted((a[0] * 16, b[0] * 16))
    top, bottom = sorted((a[1] * 16, b[1] * 16))
    local_x, local_y = u + .5 - left, v + .5 - top
    width, height = right - left, bottom - top
    edge = min(local_x, width - local_x, local_y, height - local_y)
    noise = (u * 13 + v * 7 + u * v * 3 + face * 11) % 19
    palette = PALETTES[material]
    colour = 2 if noise in (2, 7, 12) else 1
    if material in ("oak", "walnut"):
        # One long grain line every fourth pixel, with occasional knots.
        grain = (v if face in (0, 1) else u) % 4
        colour = 2 if grain == 1 else 1
        if noise == 0:
            colour = 0
        if edge < .6 and width > 2 and height > 2:
            colour = 3 if local_y < 1 else 0
    elif material in ("endgrain", "freshwood"):
        if face == 0:
            ring = int(max(abs(local_x - width / 2), abs(local_y - height / 2)))
            colour = 1 if ring % 3 == 0 else 2
        else:
            colour = 1 if u % 3 == 0 else 2
        if noise == 1:
            colour = min(3, colour + 1)
    elif material == "bark":
        colour = (0, 2, 1, 1)[u % 4]
        if v % 5 == u % 3:
            colour = max(0, colour - 1)
    elif material in ("hide", "pale_hide", "russet"):
        colour = 2 if noise < 3 else 1
        if boundary:
            colour = 0 if (u + v) % 4 == 0 else 2
    elif material in ("cloth", "plum_cloth", "linen", "felt", "thread", "rope"):
        colour = 2 if (u + v) % 4 == 0 else 1
        if material == "thread":
            colour = 1 if v % 2 else 2
        if material == "rope":
            colour = 2 if (u + v) % 2 else 1
        if material in ("cloth", "plum_cloth"):
            colour = 2 if u % 3 == 0 else 1
            if boundary:
                colour = 3 if (u + v) % 2 == 0 else 2
        if material == "linen" and edge < 1:
            colour = 0 if (u + v) % 2 else 2
    elif material in ("iron", "steel", "copper", "brass"):
        colour = 2 if face == 0 else 1
        if local_x < 1 or local_y < 1:
            colour = 3 if material in ("steel", "brass") else 2
        elif width - local_x < 1 and width > 2:
            colour = 0
        if noise == 3 and colour == 1:
            colour = 2
    elif material.startswith("gem_"):
        colour = 3 if local_x < 1 else (2 if local_y < height / 2 else 1)
        if face == 0:
            colour = 3 if (u + v) % 3 == 0 else 2
    elif material.startswith("glass_"):
        # Opaque, pixel-painted glass: pale reflections, coloured liquid.
        # No alpha blending or transparent-box sorting needed in the game.
        colour = 1 if local_y >= height * .4 else 2
        if local_x < 1:
            colour = 3
        elif width - local_x < 1:
            colour = 0
        if face in (0, 1):
            colour = 3 if edge < 1 else 2
    elif material in ("stone", "grindstone"):
        colour = 2 if noise < 7 else 1
        if material == "grindstone":
            radius = max(abs(local_x - width / 2), abs(local_y - height / 2))
            colour = 1 if int(radius) % 2 else 2
        if edge < .7:
            colour = 0 if local_y > 1 else 3
    elif material == "cork":
        colour = 2 if noise < 8 else 1
    elif material == "ember":
        colour = 3 if local_x <= width / 2 else 2
    return palette[colour]


def bake_tiles(design):
    # Orthographic material projection into the six real Luanti node UVs.
    # A nearer part owns a contested pixel. All boxes subsequently share it;
    # the previews show that constraint, not the richer authoring materials.
    parts = [(tuple(n / 16 for n in box), material) for box, material in design.parts]
    result = []
    for face, (axis, sign, _, _, _, _) in enumerate(FACES):
        tile = Image.new("RGB", (16, 16), PALETTES["oak"][1])
        owners = {}
        for v in range(16):
            for u in range(16):
                candidates = []
                for index, (box, material) in enumerate(parts):
                    depth = box[axis + (3 if sign > 0 else 0)]
                    p = point_at(face, (u + .5) / 16, (v + .5) / 16, depth)
                    if all(box[i] - 1e-8 <= p[i] <= box[i + 3] + 1e-8
                           for i in range(3) if i != axis):
                        candidates.append((sign * depth, index, material, box))
                if candidates:
                    _, _, material, box = max(candidates)
                    owners[u, v] = (material, box)
        for (u, v), (material, box) in owners.items():
            # Stitch only a material's actual silhouette, never the seams
            # between the boxes that construct a single hide or cloth bolt.
            boundary = any(owners.get((u + du, v + dv), (None,))[0] != material
                           for du, dv in ((-1, 0), (1, 0), (0, -1), (0, 1)))
            tile.putpixel((u, v), pigment(material, box, face, u, v, boundary))
        result.append(tile)
    return result


def write_design(design, root):
    folder = root / design.station / design.variant
    folder.mkdir(parents=True, exist_ok=True)
    prefix = "grug_r45_a2_" + design.station + "_" + design.variant.lower()
    names = [prefix + "_" + face + ".png" for face in FACE_NAMES]
    for name, image in zip(names, bake_tiles(design)):
        image.save(folder / name)
    lines = ["-- " + design.title + ": " + design.description,
             "-- Original proposal; generated by tools/r45_a2/generate.py.",
             "-- Front: -Z. Tiles: +Y, -Y, +X, -X, +Z, -Z; node-coordinate UVs.",
             "return {", " boxes = {"]
    for box, _ in design.parts:
        lines.append("  {" + ", ".join(f"{n / 16:.8g}" for n in box) + "},")
    lines.extend([" },", " tiles = {"])
    lines.extend('  "' + name + '",' for name in names)
    lines.extend([" },", "}", ""])
    (folder / "design.lua").write_text("\n".join(lines))
    # Deliberately re-read the deliverables, not the authoring Design.parts.
    boxes, images = load_design(folder / "design.lua")
    for view in (1, 2):
        render(boxes, images, view).save(folder / f"view{view}.png")


def generate(root):
    designs = all_designs()
    assert len(designs) == 15
    for design in designs:
        write_design(design, root)
    stations = sorted({d.station for d in designs})
    for station in stations:
        sheet(station, [d for d in designs if d.station == station], root).save(root / station / "sheet.png")
    reference_sheet(REPO).save(root / "anvil_reference.png")
    return designs


def kept_files(scratch):
    """Repository-relative path -> bytes of everything this generator owns."""
    out = {}
    for path in scratch.rglob("*"):
        rel = path.relative_to(scratch)
        if path.name == "design.lua" or path.name in ("sheet.png", "anvil_reference.png"):
            out[Path("tools/r45_a2") / rel] = path.read_bytes()
    for station, (variant, _, folder, prefix) in PICKS.items():
        source = "grug_r45_a2_" + station + "_" + variant.lower()
        for face in FACE_NAMES:
            out[Path(folder) / (prefix + "_" + face + ".png")] = (
                scratch / station / variant / (source + "_" + face + ".png")).read_bytes()
    return out


def load_shipped(repo):
    """The registered station nodes, read through the stub node registry."""
    script = '''
local root, names = arg[1], {}
for index = 2, #arg do names[#names + 1] = arg[index] end
local registry = dofile(root .. "/tools/wp13/stub_registry.lua").load(root)
for _, name in ipairs(names) do
    local def = registry.nodes[name]
    print("NODE " .. name)
    for _, b in ipairs(def.node_box.fixed) do print(table.concat(b, ",")) end
    print("TILES")
    for _, tile in ipairs(def.tiles) do print(tile) end
end
'''
    stations = list(PICKS)
    value = subprocess.run(["luajit", "-", str(repo)] + [PICKS[s][1] for s in stations],
                           input=script, text=True, capture_output=True, check=True).stdout
    shipped = {}
    for station, block in zip(stations, value.split("NODE ")[1:]):
        lines = block.strip().splitlines()
        assert lines[0] == PICKS[station][1], lines[0]
        split = lines.index("TILES")
        boxes = [tuple(map(float, row.split(","))) for row in lines[1:split]]
        tiles = lines[split + 1:]
        assert len(tiles) == 6 and all("^" not in t for t in tiles), (station, tiles)
        images = [Image.open(repo / PICKS[station][2] / t).convert("RGB") for t in tiles]
        shipped[station] = (boxes, images)
    return shipped


def final_sheet(repo):
    shipped = load_shipped(repo)
    width = 24 + len(shipped) * 352
    image = Image.new("RGB", (width, 910), (244, 240, 229))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width - 1, 90), fill=(36, 53, 53))
    caption(image, (24, 17), "GRUDGELANDS / STATION STUDIES", 2, (191, 176, 139))
    caption(image, (24, 48), "FINAL STATIONS", 4, (244, 240, 229))
    caption(image, (24, 111), "ROUND 45 / THE USER'S PICKS AS REGISTERED IN THE GAME", 2)
    for index, (station, (boxes, tiles)) in enumerate(shipped.items()):
        x = 24 + index * 352
        draw.rectangle((x - 1, 151, x + 321, 853), outline=(200, 194, 177))
        draw.rectangle((x, 152, x + 320, 194), fill=(222, 214, 194))
        caption(image, (x + 10, 165), station.replace("_", " ") + " / " + PICKS[station][0], 2)
        for view in (1, 2):
            image.paste(render(boxes, tiles, view), (x, 195 + (view - 1) * 330))
        caption(image, (x + 8, 502), "FRONT-LEFT", 1)
        caption(image, (x + 8, 832), "BACK-RIGHT", 1)
    caption(image, (24, 874), "ORIGINAL ART / GPT-6 ASTRA / CC0 1.0 / ACTUAL BOXES AND SHARED TILES", 2)
    return image


def png_bytes(image):
    with tempfile.TemporaryDirectory(prefix="grug-r45-a2-png-") as tmp:
        path = Path(tmp) / "out.png"
        image.save(path)
        return path.read_bytes()


def owned_on_disk():
    """Every design/sheet file under tools/r45_a2 and every picked game tile."""
    found = {p.relative_to(REPO) for p in ROOT.rglob("*")
             if p.suffix in (".png", ".lua") and p.name != "final_sheet.png"}
    for _, _, folder, prefix in PICKS.values():
        found |= {p.relative_to(REPO) for p in (REPO / folder).glob(prefix + "_*.png")}
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Regenerate in a temporary directory and compare all bytes")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="grug-r45-a2-") as tmp:
        designs = generate(Path(tmp))
        expected = kept_files(Path(tmp))
    if args.check:
        mismatches = sorted(str(p) for p in expected.keys() | owned_on_disk()
                            if not (REPO / p).is_file() or expected.get(p) != (REPO / p).read_bytes())
        if (ROOT / "final_sheet.png").read_bytes() != png_bytes(final_sheet(REPO)):
            mismatches.append("tools/r45_a2/final_sheet.png")
        if mismatches:
            raise SystemExit("Generated files differ:\n" + "\n".join(mismatches))
        print(f"PASS: {len(expected) + 1} files byte-identical; 15 designs, 6 sheets, "
              f"{len(PICKS) * 6} picked game tiles, the final sheet.")
        return
    for path, data in expected.items():
        (REPO / path).parent.mkdir(parents=True, exist_ok=True)
        (REPO / path).write_bytes(data)
    (ROOT / "final_sheet.png").write_bytes(png_bytes(final_sheet(REPO)))
    for d in designs:
        print(f"{d.station}/{d.variant}: {len(d.parts)} boxes, 6 tiles / {d.title}")
    print(f"Wrote {len(expected)} files and final_sheet.png.")


if __name__ == "__main__":
    main()

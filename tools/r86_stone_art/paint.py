"""Paint six node-coordinate tiles for each carving and export its box manifest."""

import json
import re
from pathlib import Path
from PIL import Image, ImageFilter

from stones import BUILDERS

ROOT = Path(__file__).resolve().parent
KINDS = ("personal", "account")
STATES = ("draft", "active", "empty")
FACE_NAMES = ("top", "bottom", "right", "left", "back", "front")
# +Y, -Y, +X, -X, +Z, -Z. Axis, outward sign, U axis/sign, V axis/sign.
# Same cuboid UVs as the shipped station artwork in tools/r45_a2/render.py.
FACES = ((1, 1, 0, 1, 2, -1), (1, -1, 0, 1, 2, 1),
         (0, 1, 2, 1, 1, -1), (0, -1, 2, -1, 1, -1),
         (2, 1, 0, -1, 1, -1), (2, -1, 0, 1, 1, -1))

RAMPS = {
    # Shadow, body, light, glint. Roof clay, slate, sandstone and oiled wood
    # follow the value ranges of the shipped shingles and workshop benches.
    "clay": "783c30 a04e34 c36c45 df9563",
    "slate": "344751 496675 678891 94aaa8",
    "ridge_red": "874533 b56844 ce8a58 edb780",
    "ridge_blue": "3e545e 587482 84a1a6 b4c6be",
    "sill": "4d4743 766f5f 938873 baab8b",
    "plaster": "9c8d71 c4b494 dccca8 efdfb4",
    "chimney": "463a35 775949 aa8467 d6b48c",
    "timber": "44322e 624338 875d42 b48858",
    "basalt": "343b40 4d5352 68706a 97998a",
    "ochre_glaze": "74482e 966338 b7894a dfb66a",
    "sea_glaze": "284e55 386970 56868a 90b5a9",
    "ivory": "988969 b8ac8b d7caaa e9dbb9",
    "beeswax": "936137 b68044 d7aa62 edc988",
    "wax_cold": "68665d 898676 aaa696 c4beab",
    "flame": "be542e ea8639 f8b953 fff0a8",
    "flame_tip": "b14929 d16430 ed9343 ffc466",
    "wick": "22272a 312d2c 45403b 62605b",
    "blue_pot": "334e5b 476d78 719098 adbbb2",
    "ochre_pot": "744c3b 9c6342 c18758 dfaa7c",
    "bark": "493b33 74533b 976f4c b88b59",
    "olive": "394d42 556e52 77875b a1a56c",
    "juniper": "304f4e 436d66 68897a 9ca88b",
    "pear_neck": "918347 c6a14d dec470 eee2a3",
    "pear_gold": "b67a3f d99f4d f5cb70 fff1b2",
    "pear_base": "936735 b78241 d6a252 e7bd6a",
    "shutter": "343b3f 424949 636964 858879",
    "window": "8d5131 ca8044 f3ba69 ffdfa0",
}
RAMPS = {key: [tuple(bytes.fromhex(s)) for s in values.split()]
         for key, values in RAMPS.items()}


def uv(face, cell):
    _, _, ua, us, va, vs = FACES[face]
    return (cell[ua] if us > 0 else 15 - cell[ua],
            cell[va] if vs > 0 else 15 - cell[va])


def cottage(paint, face, cell, shared, empty):
    x, y, z = cell
    gable = face in (4, 5)
    if paint == "chimney":
        if face == 0 and x in (12, 13) and 9 <= z < 12:
            return paint, 0
        return paint, 3 if y == 15 else 1
    if face in (2, 3, 4, 5) and paint == "plaster":
        u = x if gable else z
        openings = ((2, 7), (9, 14)) if shared and gable else ((5, 11),)
        for left, right in openings:
            if left <= u < right and 2 <= y <= 7:
                off = min(u - left, right - 1 - u)
                if y == 7 and off == 0:
                    return "plaster", 1
                if off == 0 or y == 7:
                    return "timber", 0 if y == 7 or u == left else 2
                if empty:
                    return "shutter", 2 if (u - left + y) % 7 == 0 else 1
                if y == 2:
                    return "timber", 3
                return "window", 3 if y >= 4 and u != right - 2 else 2
        posts = (1, 14) if gable else (3, 12)
        if u in posts:
            return "timber", 1
        return "plaster", 1 if y == 2 or (u + y * 2) % 13 == 0 else 2
    if paint in ("clay", "slate", "ridge_red", "ridge_blue"):
        # The stepped end of the roof is a half-timbered gable. Leave the
        # outer two texels of each slope tiled as the bargeboards.
        band = min(x % 8, 7 - x % 8) if shared else min(x, 15 - x) // 2
        peak = (9, 11, 13, 14)[band] if shared else (10, 12, 14, 15)[band]
        if gable and y <= peak - 2:
            if x in ((3, 4, 11, 12) if shared else (7, 8)) or y == 9:
                return "timber", 2
            return "plaster", 1 if y == peak - 2 else 2
        if gable:
            return paint, 3 if y == peak else 1
        if face == 0:
            if z in (2, 13):
                return paint, 3
            seam = (z + (band % 2) * 2) % 5
            return paint, 0 if seam == 0 else (2 if seam in (1, 2) else 1)
        return paint, 2 if y == peak else 0
    if paint == "sill":
        return paint, (1 if (x + z) % 7 == 0 else 3) if face == 0 else (2 if y == 1 else 0)
    if paint == "timber":
        return paint, 2 if face == 0 else 1
    return paint, 1


def pigment(design, paint, face, cell, shared, empty):
    x, y, z = cell
    u, v = uv(face, cell)
    if design == "roof":
        paint, tone = cottage(paint, face, cell, shared, empty)
    elif paint in ("ochre_pot", "blue_pot", "ochre_glaze", "sea_glaze"):
        if face == 0:
            radius = max(abs(x - 7.5), abs(z - 7.5))
            if design == "pear" and radius < 4.5:
                return RAMPS["bark"][0 if (x + z) % 4 else 1]
            tone = 3 if radius >= 5.5 else (2 if radius >= 4.5 else 1)
        elif y in (1, 3, 5):
            tone = 3 if (u + 1) % 6 in (0, 1) else 2
        else:
            tone = 0 if u % 6 == 0 else 1
    elif paint == "basalt":
        tone = 2 if face == 0 else int(y % 2 == 1)
    elif paint in ("beeswax", "ivory", "wax_cold"):
        if face == 0:
            tone = 1 if (x + z) % 5 < 2 else 3
        else:
            # Fat melted lip with a short trickle on just two sides of a pillar.
            top = (11 if z >= 10 else (9 if x < 6 else 8)) if shared else 11
            if empty:
                base = 4 if shared else 6
                top = base + (top - base) // 2
            drip = (0, 2, 1, 0, 0, 1, 0)[u % 7]
            tone = 3 if y >= top - 1 - drip else (2 if u % 4 == 2 else 1)
    elif paint == "flame":
        tone = 3 if (x + z) % 3 else 2
    elif paint == "flame_tip":
        tone = 2 if face == 0 else 1
    elif paint == "wick":
        tone = 0
    elif paint == "bark":
        tone = 2 if u % 3 == 0 or face == 0 else 1
    elif paint in ("juniper", "olive"):
        # Clusters of lit leaves; the dark undersides stay quite continuous.
        leaf = ((u + v // 3) // 3 + (v - u // 4) // 2) % 5
        tone = (1, 2, 2, 3, 2)[leaf] if face == 0 else (0, 0, 1, 2, 1)[leaf]
    else:
        tone = 3 if face == 0 or (u + 2 * v) % 8 == 1 else (2 if face == 5 else 1)
    return RAMPS[paint][tone]


def bake(design, shared, empty, cells):
    tiles = []
    for face, (axis, sign, *_) in enumerate(FACES):
        tile = Image.new("RGBA", (16, 16))
        for cell in sorted(cells, key=lambda p: p[axis] * sign):
            tile.putpixel(uv(face, cell), pigment(design, cells[cell], face, cell, shared, empty))
        tiles.append(tile)
    return tiles


def house_icon():
    """A cut-out door, off-centre chimney and continuous dark rim in one ochre ramp."""
    rows = [
        "................", ".......kk..kkk..", "......kllk.kok..", ".....kllookkok..",
        "....klloooookk..", "...klloooookok..", "..kllookkoooook.", ".kllookkkkoooook",
        ".kkookloolkookkk", "...kklloollokk..", "...klllooolok...", "...kllkkkkook...",
        "...klok..kook...", "...klok..kook...", "...kkkk..kkkk...", "................",
    ]
    colours = {"k": "#513e2c", "o": "#c59658", "l": "#f5d99a"}
    im = Image.new("RGBA", (16, 16))
    assert len(rows) == 16 and all(len(row) == 16 for row in rows)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), (*bytes.fromhex(colours[ch][1:]), 255))
    return im


def slot_icon(front):
    # A one-texel rim separates the active carving from the inventory slot.
    rim = front.getchannel("A").filter(ImageFilter.MaxFilter(3))
    out = Image.new("RGBA", front.size, "#443830")
    out.putalpha(rim)
    out.alpha_composite(front)
    return out


def export():
    art = ROOT / "art"
    art.mkdir(exist_ok=True)
    house_icon().save(art / "home_name.png")
    for design, builder in BUILDERS.items():
        folder = art / design
        folder.mkdir(exist_ok=True)
        unique = {}
        manifest = {"box_units": "signed sixteenths from the node centre (divide by 16)",
                    "face_order": list(FACE_NAMES), "drawtype": "nodebox",
                    "collision_and_selection": "use the state's fixed boxes", "variants": {}}
        for kind in KINDS:
            states = {}
            manifest["variants"][kind] = states
            for state in ("active", "empty"):
                shared, empty = kind == "account", state == "empty"
                carving = builder(shared, empty)
                tiles = bake(design, shared, empty, carving.cells())
                names = []
                for face, im in zip(FACE_NAMES, tiles):
                    pixels = im.tobytes()
                    if pixels not in unique:
                        unique[pixels] = f"{design}_{kind}_{state}_{face}.png"
                        im.save(folder / unique[pixels])
                    names.append(unique[pixels])
                states[state] = {
                    "boxes": [[n - 8 for n in box] for box, _ in carving.parts],
                    "tiles": names, "light_source": 0 if empty else 4,
                    "use_texture_alpha": "opaque",
                }
                if state == "active":
                    icon = f"{design}_{kind}_item.png"
                    slot_icon(tiles[5]).save(folder / icon)
                    states[state]["inventory_image"] = icon
                    states[state]["wield_image"] = icon
            states["draft"] = {"geometry_and_tiles": "active", "colorize": "#b6b7a8",
                               "colorize_strength": 92, "opacity": 150, "light_source": 2,
                               "use_texture_alpha": "blend"}
        manifest["stone_texture"] = manifest["variants"]["personal"]["active"]["tiles"][5]
        source = json.dumps(manifest, indent=2)
        # Keep all six coordinates of a box on one line for the handoff.
        source = re.sub(r"\[\s*((?:-?\d+,\s*){5}-?\d+)\s*\]",
                        lambda m: "[" + " ".join(m[1].split()) + "]", source)
        (folder / "nodes.json").write_text(source + "\n")


if __name__ == "__main__":
    export()

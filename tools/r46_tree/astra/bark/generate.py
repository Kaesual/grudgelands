#!/usr/bin/env python3
"""Paint twelve original 16 px bark pairs and two comparison sheets. No downloads.

The authored pixel maps and palettes are CC0-1.0; generator/rendering code is
GPL-3.0-or-later. Existing comparison textures retain CC BY-SA 3.0.
Requires Pillow and NumPy. Run with --check to compare without writing.
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageColor, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DEFAULT = ROOT / "mods/BASE/default/textures"
NEAREST = Image.Resampling.NEAREST

# Each map is a hand-placed 15 x 15 set of clusters, not random noise. The
# last row/column repeat the first: explicit, equal opposite edges in 16 px.
# Features were drawn across that join; no outline is put around the tile.
ART = {
    "a": {
        "name": "Kapok ash",
        "idea": "Warm pale-grey bark, broad smooth areas and sparse sage lichen.",
        "palette": {"a": "858a78", "b": "939783", "c": "a0a38f",
                    "d": "777d6b", "e": "636c59", "m": "6f805c", "l": "86966b"},
        "pixels": """
            aabbbbaaaddaaaa
            aabbbbaaaadaaaa
            aabbcbaaaaaaaaa
            aaabcbbaaaaaaaa
            daabbbaaaabaaaa
            daabbbaaabbbbaa
            daabbaaabbbbbaa
            aaabaaaabbbcbaa
            aaaaaaaabbbbbaa
            aaaaaaaabbbbaaa
            aamaaaaabbbaaaa
            ammlaaaabbaaada
            aamlbaaaaaaaada
            aabbbaaaaaaadda
            aabbbbaaaddaaaa
        """,
        "wood": ["b6b094", "cbc2a0", "aea384", "bdb290", "9a9275"],
        "center": (7.2, 7.5),
    },
    "b": {
        "name": "Russet ridges",
        "idea": "Dark red-brown bark with broad overlapping ridges and warm cuts.",
        "palette": {"a": "654735", "b": "79543d", "c": "896148",
                    "d": "523b2f", "e": "44342c", "f": "966d50"},
        "pixels": """
            abbcaddeaabbcda
            abbcaddeaabbcda
            abbcddeaabbccda
            abbcddeaabbccda
            abbcdaeaabbccda
            abbdaaaaabccdda
            abcdaaaabbcddaa
            abcdaaabbccdaaa
            abcdeaabbccdaaa
            abcdeaabccdaaaa
            abcdeaabccdaaaa
            abbdeaaabcdaaaa
            abbddeaaabdaaaa
            abbcdeaaabbadaa
            abbcaddeaabbcda
        """,
        "wood": ["a87850", "c39968", "8a5b3e", "ad7c53", "734d36"],
        "center": (7.5, 7.1),
    },
    "c": {
        "name": "Moss islands",
        "idea": "Cool weathered bark with clustered olive moss in the hollows.",
        "palette": {"a": "58594b", "b": "666757", "c": "767560",
                    "d": "484d40", "e": "3d4438", "m": "5e7042", "l": "798652"},
        "pixels": """
            aabbaaaddaabbba
            aabbaaaddaabbba
            aabcaaadaaabbba
            aabccaaaaaabbba
            aabcbaaaaaabbda
            aabbbadaaammmda
            aaabbadaammlmda
            aaabadaammllmda
            aaabadaammmlmaa
            aaabadadaammmaa
            mmabaadadaaabaa
            mlmbaaadaaabbaa
            lmmbaaaddaabbaa
            mmabbaaedaabbba
            aabbaaaddaabbba
        """,
        "wood": ["99916f", "b4aa82", "7c765a", "a19874", "69654f"],
        "center": (7.2, 7.8),
    },
    "d": {
        "name": "Broad flutes",
        "idea": "Deep narrow furrows between wide, gently turning umber buttress ribs.",
        "palette": {"a": "796b52", "b": "8b7a5c", "c": "9b8865",
                    "d": "625844", "e": "4f493a", "f": "6d614b"},
        "pixels": """
            abbccbfdeefabba
            abbccbfdeefabba
            abbccbfdeefabba
            abbccbfdeefabba
            abbcbafdeefabba
            abbcbaadeefabba
            abbcbafdeefabba
            abbcbafdeefabba
            abcbbafdeefabba
            abcbbafdeefabba
            abcbbafdeefabba
            abcbbafdeefabba
            abcbbafdeefabba
            abbcbafdeefabba
            abbccbfdeefabba
        """,
        "wood": ["b29a70", "ccb487", "93805d", "b9a177", "7e6e51"],
        "center": (7.6, 7.7),
    },
    "e": {
        "name": "Climbing vines",
        "idea": "Quiet cocoa bark crossed by one slender winding green vine.",
        "palette": {"a": "675c49", "b": "786952", "c": "88765c",
                    "d": "594f40", "e": "4b4938", "m": "626e43", "l": "7b8652"},
        "pixels": """
            aabbaaaddaabbba
            aabbaaaddaabbba
            aabbbaadaabbcba
            aabbbbaaaabbcba
            aabbcbaaaaabcba
            aabbcbaaaabbbba
            aabbbaaaaabbbaa
            aabbbaadaabbbaa
            aaabbaaddaabbaa
            aaabbaaddaabbaa
            aaabbaaedaabbaa
            aaabbaaedaabbba
            aaabbaaedaabbba
            aabbaaaddaabbba
            aabbaaaddaabbba
        """,
        "wood": ["ae9470", "c7ad85", "91795b", "b49a76", "79674f"],
        "center": (7.8, 7.2),
    },
    "f": {
        "name": "Quiet olive",
        "idea": "A restrained olive-brown alternative with fewer, softer vertical folds.",
        "palette": {"a": "716b49", "b": "817653", "c": "92835c",
                    "d": "605e42", "e": "505039", "f": "77704d"},
        "pixels": """
            abbcbaaddeaabfa
            abbcbaaddeaabfa
            abbcbaaddeaabfa
            abbcbaaddaabbfa
            abbbbaaddaabbfa
            abbbbaddaaabbfa
            abbbaaddaabbbaa
            abbbaaddaabbbaa
            abbaaaddaabbcaa
            abbaaaddaabbcaa
            abbaaddaabbbcaa
            abbaaddeaabbbaa
            abbaaddeaabbbaa
            abbbaddeaabbfaa
            abbcbaaddeaabfa
        """,
        "wood": ["9d8052", "bca170", "7e6543", "a6895b", "68583d"],
        "center": (7.3, 7.3),
    },
    "g": {
        "name": "Quiet russet",
        "idea": "B refined: calm red-brown ridges with soft, unbroken shoulders.",
        "palette": {"a": "6d4b37", "b": "7d573e", "c": "886146",
                    "d": "5c402f", "e": "51392d"},
        "pixels": """
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadaabbccdaa
            abbcadaabbccdaa
            abbcadaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbccdaa
            abbcadaaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
        """,
        "wood": ["a27650", "b68b5f", "8d6344", "a97e55", "704c35"],
        "center": (7.4, 7.2),
        "crack": [(3, 10), (4, 10)],
    },
    "h": {
        "name": "Deep chestnut",
        "idea": "Darker, warmer chestnut with broad copper-brown raised plates.",
        "palette": {"a": "5e3b2b", "b": "704530", "c": "815339",
                    "d": "4b3026", "e": "3e2b24"},
        "pixels": """
            abbccdaeaabbcda
            abbccdaeaabbcda
            abbccdaeaabbcda
            abbcddaaaabbcda
            abbcdaaaaabbcda
            abbcdaaaabbccda
            abbcdaaaabbccda
            abbccdaaabbcdda
            abbccdaaabbcdaa
            abbccdaaabbcdaa
            abbccdaaaabcdaa
            abbcddaaaabcdaa
            abbcddaeaabcdaa
            abbccdaeaabbcda
            abbccdaeaabbcda
        """,
        "wood": ["966344", "ae7b53", "7c5038", "9f6b49", "603d2c"],
        "center": (7.7, 7.7),
        "crack": [(11, 4), (11, 5), (10, 6)],
    },
    "i": {
        "name": "Moss in the folds",
        "idea": "Russet bark with two tiny, fresh-green moss pockets in the furrows.",
        "palette": {"a": "6d4b37", "b": "7d573e", "c": "886146",
                    "d": "5c402f", "e": "51392d", "m": "507b31", "l": "79a83e"},
        "pixels": """
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadmaabbcdaa
            abbcadlaabbcdaa
            abbcammaabbcdaa
            abbcadaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcmmaa
            abbcdaaabbcldaa
            abbcadaaabbmdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
        """,
        "wood": ["a27650", "b68b5f", "8d6344", "a97e55", "704c35"],
        "center": (7.4, 7.2),
        "crack": [(3, 10), (4, 10)],
    },
    "j": {
        "name": "Single green thread",
        "idea": "Warm brown ridges and one bright, single-pixel climbing liana.",
        "palette": {"a": "6d4b37", "b": "7d573e", "c": "886146",
                    "d": "5c402f", "e": "51392d", "m": "639331", "l": "89b842"},
        "pixels": """
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadaabbccdaa
            abbcadaabbccdaa
            abbcadaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbccdaa
            abbcadaaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
        """,
        "wood": ["a27650", "b68b5f", "8d6344", "a97e55", "704c35"],
        "center": (7.4, 7.2),
        "crack": [(3, 10), (4, 10)],
    },
    "k": {
        "name": "Fine red grain",
        "idea": "Cinnamon-red bark with finer, softly broken vertical grain.",
        "palette": {"a": "78503a", "b": "875d43", "c": "956b4c",
                    "d": "694530", "e": "5a3c2d"},
        "pixels": """
            abcdabdaadbcdaa
            abcdabdaadbcdaa
            abcdabdaadbcdaa
            abdabbdaadbcdaa
            abdabbdaadbcdaa
            abdaabcdaabcdaa
            abdabbcdabbcdaa
            abdaabbdabbdaaa
            abcdaabdabbdaaa
            abcdaabdabcdaaa
            abcdaabdabcdaaa
            abcdaadabbcdaaa
            abcdabdaadbcdaa
            abcdabdaadbcdaa
            abcdabdaadbcdaa
        """,
        "wood": ["ac7b53", "bd9262", "996b49", "b18459", "7c5238"],
        "center": (7.1, 7.6),
        "crack": [(12, 9), (11, 9)],
    },
    "l": {
        "name": "Lichen freckles",
        "idea": "Soft terracotta-brown ridges with just a few green lichen flecks.",
        "palette": {"a": "794d37", "b": "875b41", "c": "95684a",
                    "d": "63402f", "e": "53372b", "m": "699140", "l": "92b653"},
        "pixels": """
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
            abbclmaabbccdaa
            abbcmdaabbccdaa
            abbcadaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabbcdaaa
            abbcdaaabblmaaa
            abbcdaaabbccdaa
            abbcadaaabbcdaa
            abbcadeaabbcdaa
            abbcadeaabbcdaa
        """,
        "wood": ["ac7a53", "bf9263", "966447", "b38058", "754b36"],
        "center": (7.8, 7.3),
        "crack": [(4, 4), (5, 5)],
    },
}


def rgba(value):
    return ImageColor.getrgb("#" + value) + (255,)


def paint_pair(key, art):
    rows = art["pixels"].split()
    assert len(rows) == 15 and all(len(row) == 15 for row in rows), key
    palette = {k: rgba(v) for k, v in art["palette"].items()}
    canvas = [list(row) for row in rows]
    if key == "e":
        # One connected, authored tendril, wrapping through the vertical join.
        vine_x = [3, 3, 4, 4, 5, 6, 7, 7, 7, 6, 5, 5, 4, 3, 3]
        for y, x in enumerate(vine_x):
            canvas[y][x] = "m"
            canvas[y][x + 1] = "l" if y in (2, 3, 6, 7, 10, 11) else "m"
            canvas[y][x + 2] = "e"
    if key == "j":
        # One pixel wide even at the join; brown still occupies 15/16 of the tile.
        vine_x = [5, 5, 5, 6, 6, 6, 7, 7, 7, 6, 6, 6, 5, 5, 5]
        for y, x in enumerate(vine_x):
            canvas[y][x] = "l" if y in (3, 4, 9, 10) else "m"
    side = Image.new("RGBA", (16, 16))
    side.putdata([palette[canvas[y % 15][x % 15]] for y in range(16) for x in range(16)])
    top = side.copy()
    wood = [rgba(c) for c in art["wood"]]
    cx, cy = art["center"]
    for y in range(1, 15):
        for x in range(1, 15):
            dx, dy = abs(x - cx), abs(y - cy)
            # A chamfered growth section with three broad, asymmetric rings.
            r = max(dx, dy) + min(dx, dy) * 0.24
            if r < 6.85:
                index = (1 if r > 5.65 else 2 if r > 4.75 else
                         0 if r > 3.4 else 2 if r > 2.65 else
                         3 if r > 1.25 else 0)
                top.putpixel((x, y), wood[index])
    # A short drying split, kept away from all tile boundaries.
    crack = {"a": [(11, 4), (11, 5)], "b": [(3, 10), (4, 10), (5, 9)],
             "c": [(11, 11), (10, 10)], "d": [(10, 3), (10, 4), (9, 5)],
             "e": [(4, 4), (5, 5)], "f": [(12, 8), (11, 8), (10, 9)]}
    for p in art["crack"] if "crack" in art else crack[key]:
        top.putpixel(p, wood[4])
    return side, top


def tiled(texture, count=4):
    result = Image.new("RGBA", (16 * count, 16 * count))
    for y in range(count):
        for x in range(count):
            result.paste(texture, (16 * x, 16 * y))
    return result


def mockup(side, top, leaves):
    """Orthographic material study, not a screenshot or new tree proposal.

    Stepped 2 x 2 bole, 10/16 limb and 6/16 twig, texture grain following
    each piece. All faces sample at native 16 px/node, with no filtering.
    """
    width, height = 272, 290
    pixels = np.full((height, width, 3), (225, 230, 214), dtype=np.uint8)
    depth = np.full((height, width), -np.inf)
    tex = {"side": np.array(side), "top": np.array(top), "leaf": np.array(leaves)}
    eye = np.array([0.8, 0.62, 1.0]); eye /= np.linalg.norm(eye)
    right = np.cross([0., 1., 0.], eye); right /= np.linalg.norm(right)
    up = np.cross(eye, right)
    target = np.array([2.35, 2.6, 0.8])
    scale = 42

    def quad(points, uv, texture, normal):
        if np.dot(normal, eye) <= 0:
            return
        points = np.array(points)
        relative = points - target
        screen = np.column_stack([width / 2 + relative @ right * scale,
                                  height / 2 - relative @ up * scale])
        depths = relative @ eye
        uv = np.array(uv)
        for ids in ((0, 1, 2), (0, 2, 3)):
            q, z, coords = screen[list(ids)], depths[list(ids)], uv[list(ids)]
            x0, y0 = np.maximum([0, 0], np.floor(q.min(axis=0)).astype(int))
            x1, y1 = np.minimum([width - 1, height - 1], np.ceil(q.max(axis=0)).astype(int))
            if x0 > x1 or y0 > y1:
                continue
            xx, yy = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
            den = (q[1, 1]-q[2, 1])*(q[0, 0]-q[2, 0]) + (q[2, 0]-q[1, 0])*(q[0, 1]-q[2, 1])
            if abs(den) < 1e-9:
                continue
            a = ((q[1, 1]-q[2, 1])*(xx-q[2, 0]) + (q[2, 0]-q[1, 0])*(yy-q[2, 1])) / den
            b = ((q[2, 1]-q[0, 1])*(xx-q[2, 0]) + (q[0, 0]-q[2, 0])*(yy-q[2, 1])) / den
            c = 1-a-b
            znew = a*z[0] + b*z[1] + c*z[2]
            old = depth[y0:y1+1, x0:x1+1]
            mask = (a >= -1e-8) & (b >= -1e-8) & (c >= -1e-8) & (znew > old)
            u = a*coords[0, 0] + b*coords[1, 0] + c*coords[2, 0]
            v = a*coords[0, 1] + b*coords[1, 1] + c*coords[2, 1]
            samples = tex[texture][np.floor(v*16).astype(int) % 16, np.floor(u*16).astype(int) % 16]
            mask &= samples[:, :, 3] >= 128
            # Identical fixed face light for every candidate and reference.
            shade = 1.0 if normal[1] else .88 if normal[2] else .73
            colour = (samples[:, :, :3] * shade).astype(np.uint8)
            pixels[y0:y1+1, x0:x1+1][mask] = colour[mask]
            old[mask] = znew[mask]

    def box(bounds, axis="y", leaf=False):
        x0, y0, z0, x1, y1, z1 = bounds
        faces = [([(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)], (0,1,0), "y"),
                 ([(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)], (1,0,0), "x"),
                 ([(x1,y0,z1),(x1,y1,z1),(x0,y1,z1),(x0,y0,z1)], (0,0,1), "z")]
        for points, normal, face_axis in faces:
            cut = face_axis == axis and not leaf
            uv = []
            for x, y, z in points:
                if leaf:
                    u, v = (x, z) if face_axis == "y" else (z, -y) if face_axis == "x" else (x, -y)
                elif cut:
                    u, v = (x, z) if axis == "y" else (z, -y)
                elif axis == "y":
                    u, v = (z if face_axis == "x" else x), -y
                else:
                    u, v = (z if face_axis == "y" else y), -x
                uv.append((u, v))
            quad(points, uv, "leaf" if leaf else "top" if cut else "side", normal)

    # Four stepped quarter pieces make one continuous 2 x 2 bole.
    profile = [(0,12,16,16), (2,7,16,12), (7,2,16,7), (12,0,16,2)]
    for cx, cz, turns in ((0,0,0), (2,0,1), (2,2,2), (0,2,3)):
        for x0,z0,x1,z1 in profile:
            points = [(x0/16,z0/16),(x1/16,z1/16)]
            for _ in range(turns):
                points = [(-z,x) for x,z in points]
            xs, zs = zip(*points)
            box((min(xs)+cx,0,min(zs)+cz,max(xs)+cx,4,max(zs)+cz))
    # A collar, connected thick limb, rising elbow and finer terminal twig.
    box((1,2,0,2,3,1))
    box((2,2.1875,.1875,3.1875,2.8125,.8125), "x")
    box((2.5625,2.8125,.1875,3.1875,3.1875,.8125))
    box((2.5625,3.1875,.1875,3.5,3.8125,.8125), "x")
    box((3.5,3.3125,.3125,4.125,3.6875,.6875), "x")
    # Existing jungle leaves stay beside the bark so the whole bole is visible.
    for x,y,z in [(3.5,4,.2),(3.5,4,1.2),(4.5,4,.2),(4.5,3,.2)]:
        box((x,y,z,x+1,y+1,z+1), leaf=True)
    return Image.fromarray(pixels).convert("RGBA")


def preview(pairs, round3=False):
    today = Image.open(DEFAULT / "default_jungletree.png").convert("RGBA")
    old_top = Image.open(DEFAULT / "default_jungletree_top.png").convert("RGBA")
    leaves = Image.open(DEFAULT / "default_jungleleaves.png").convert("RGBA")
    # Round 3 keeps the six-card layout, adding a B column to each comparison.
    extra = 502 if round3 else 0
    width, card_w, card_h = 2160 + 2 * extra, 1048 + extra, 488
    sheet = Image.new("RGBA", (width, 1640), "#eeeede")
    draw = ImageDraw.Draw(sheet)
    font = lambda size: ImageFont.truetype("DejaVuSans.ttf", size)
    regular, small, title = font(17), font(14), font(25)
    heading = ("JUNGLE BARK  /  ROUND 3  /  BROWN & RUSSET" if round3 else
               "JUNGLE BARK  /  SIX MATERIAL STUDIES")
    draw.text((32, 25), heading, font=font(34), fill="#263629")
    draw.text((34, 72), "16 x 16 pixels  /  original CC0 candidates  /  same geometry, leaves and lighting in every comparison", font=regular, fill="#58604c")
    old_mock = mockup(today, old_top, leaves)
    if round3:
        b_mock = mockup(*pairs["b"], leaves)

    def paste_tile(im, position, size, background="#d5d9c7"):
        x,y = position
        draw.rectangle((x-1,y-1,x+size,y+size), fill="#b7bea9")
        draw.rectangle((x,y,x+size-1,y+size-1), fill=background)
        tile = im.resize((size,size), NEAREST)
        sheet.alpha_composite(tile, (x,y))

    for i, key in enumerate("ghijkl" if round3 else "abcdef"):
        art = ART[key]
        x, y = 24+(i%2)*(1064 + extra), 114+(i//2)*504
        draw.rounded_rectangle((x,y,x+card_w,y+card_h), radius=10, fill="#f9f8ee", outline="#cdd1bc", width=1)
        draw.text((x+20,y+16), key.upper() + "  /  " + art["name"], font=title, fill="#293a2d")
        draw.text((x+20,y+52), art["idea"], font=small, fill="#657057")
        side, top = pairs[key]
        comparisons = [("CANDIDATE", side, mockup(side, top, leaves))]
        if round3:
            comparisons.append(("B / RUSSET RIDGES", pairs["b"][0], b_mock))
        comparisons.append(("TODAY", today, old_mock))
        mock_x = 658 if round3 else 450
        for column, (label, bark, model) in enumerate(comparisons):
            colour = "#3c573e" if column == 0 else "#777761"
            repeat_label = ("B  /  4 x 4 tiles" if label.startswith("B /") else
                            label + "  /  4 x 4 tiles")
            draw.text((x+20+column*208,y+84), repeat_label, font=small, fill=colour)
            paste_tile(tiled(bark), (x+20+column*208,y+108), 192)
            # Preserve the exact round-2 label positions and pixels.
            label_offset = 12 if column == 0 else 8
            draw.text((x+mock_x+column*294+label_offset,y+84), label, font=small, fill=colour)
            sheet.alpha_composite(model, (x+mock_x+column*294,y+106))
        draw.text((x+20,y+315), "BARK", font=small, fill="#657057")
        draw.text((x+132,y+315), "END GRAIN", font=small, fill="#657057")
        draw.text((x+244,y+315), "LEAVES", font=small, fill="#657057")
        paste_tile(side, (x+20,y+338), 96)
        paste_tile(top, (x+132,y+338), 96)
        paste_tile(leaves, (x+244,y+338), 96)
        draw.text((x+359,y+315), "1:1", font=small, fill="#657057")
        paste_tile(tiled(side), (x+356,y+338), 64)
        if round3:
            draw.text((x+452,y+315), "B / END GRAIN", font=small, fill="#657057")
            paste_tile(pairs["b"][1], (x+452,y+338), 96)
        draw.text((x+mock_x+2,y+412), "2 x 2 stepped column / grain follows the limb", font=regular, fill="#58604c")
        draw.text((x+20,y+456), "Nearest-neighbour only. Software material mock-up; not an engine screenshot.", font=small, fill="#777c66")
    draw.text((34,1620), "Comparison media: Cisoun / paramat / PilzAdam, CC BY-SA 3.0. See LICENSE-media.md. New PNG pairs: CC0 1.0.", font=small, fill="#657057")
    return sheet


def validate(image, name):
    assert image.size == (16, 16), (name, image.size)
    assert image.mode == "RGBA", (name, image.mode)
    assert image.getchannel("A").getextrema() == (255, 255), name
    px = np.array(image)
    assert np.array_equal(px[0], px[-1]), (name, "vertical seam")
    assert np.array_equal(px[:, 0], px[:, -1]), (name, "horizontal seam")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate saved pixels without writing")
    args = parser.parse_args()
    pairs = {key: paint_pair(key, art) for key, art in ART.items()}
    outputs = {}
    for key, pair in pairs.items():
        for suffix, im in zip(("", "_top"), pair):
            name = f"jungle_bark_{key}{suffix}.png"
            validate(im, name)
            outputs[name] = im
    outputs["preview.png"] = preview(pairs)
    outputs["preview-r3.png"] = preview(pairs, round3=True)
    for name, im in outputs.items():
        path = HERE / name
        if args.check:
            with Image.open(path) as saved:
                assert saved.mode == im.mode and saved.size == im.size, name
                assert saved.tobytes() == im.tobytes(), (name, "generated pixels differ")
                if name.startswith("jungle_bark_"):
                    validate(saved, name)
        else:
            # Leave the round-2 files untouched when regenerating round 3.
            if path.exists():
                with Image.open(path) as saved:
                    if (saved.mode == im.mode and saved.size == im.size and
                            saved.tobytes() == im.tobytes()):
                        continue
            im.save(path)
    print(f"{'Checked' if args.check else 'Painted'} {2 * len(pairs)} opaque RGBA "
          "16x16 textures and preview.png / preview-r3.png; "
          "both opposite edges match on every texture.")


if __name__ == "__main__":
    main()

"""Comparison sheets for the Round 24 rock and ore textures.

Offline previews only (nearest-neighbour scaling, Luanti-like face shading on
simple isometric cubes); they approximate, not reproduce, the engine. Called by
`build_rock_ore_textures.py --renders`.
"""

from PIL import Image, ImageDraw, ImageFont

BG = (34, 34, 38, 255)
FG = (230, 230, 230, 255)
DIM = (160, 160, 165, 255)

# today's registrations (main at ab9694a1), emulated for the "before" rows
OLD_ROCKS = {
    "slate": "#4a5a6e:70",
    "basalt": "#2a2a2e:90",
    "granite": "#8a5a52:60",
    "emberrock": "#7a2a10:90",
    "abyssal_rock": "#241830:150",
}
OLD_ORES = {
    "quartz": ("default_mineral_diamond.png", "#eaf6ff:120"),
    "silver": ("default_mineral_iron.png", "#e8edf2:200"),
    "citrine": ("default_mineral_diamond.png", "#d9a21b:190"),
    "garnet": ("default_mineral_diamond.png", "#9e1526:210"),
    "jade": ("default_mineral_diamond.png", "#3d9b65:190"),
    "emberglass": ("default_mineral_mese.png", "#ff7a2e:65"),
    "diamond": ("default_mineral_diamond.png", "#ffffff:20"),
    "sapphire": ("default_mineral_diamond.png", "#235ac7:190"),
    "ruby": ("default_mineral_diamond.png", "#c51d35:195"),
    "abyssal_crystal": ("default_mineral_diamond.png", "#3a1f6e:210"),
}
OLD_NAMES = ("slate", "basalt", "granite", "emberrock", "abyssal_rock")
VENDORED_ORES = ("coal", "copper", "tin", "iron", "gold")
# display order: metal ores (T1..T3), then gems/crystals by tier
ORE_ORDER = ("coal", "copper", "tin", "iron", "quartz", "gold", "silver",
             "citrine", "garnet", "jade", "emberglass", "diamond", "sapphire",
             "ruby", "abyssal_crystal")
ORE_LABEL = {
    "coal": "Coal T1", "copper": "Copper T1", "tin": "Tin T1",
    "iron": "Iron T1", "quartz": "Quartz T1", "gold": "Gold T2",
    "silver": "Silver T3", "citrine": "Citrine T2 G1",
    "garnet": "Garnet T2 G1", "jade": "Jade T2 G1",
    "emberglass": "Emberglass T4", "diamond": "Diamond T4 G2",
    "sapphire": "Sapphire T4 G2", "ruby": "Ruby T4 G2",
    "abyssal_crystal": "Abyssal Cr. T5",
}


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def colorize(img, spec):
    """Luanti `[colorize:#rrggbb:ratio` (alpha kept)."""
    color, ratio = spec.split(":")
    c = tuple(int(color.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    r = int(ratio) / 255
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            px[x, y] = tuple(int(p[i] * (1 - r) + c[i] * r + 0.5)
                             for i in range(3)) + (p[3],)
    return out


def over(base, top):
    out = base.copy()
    out.alpha_composite(top)
    return out


def scale(img, f):
    return img.resize((img.width * f, img.height * f), Image.NEAREST)


def tiled(img, n):
    out = Image.new("RGBA", (img.width * n, img.height * n))
    for i in range(n):
        for j in range(n):
            out.paste(img, (i * img.width, j * img.height))
    return out


def shade(img, f):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            px[x, y] = tuple(int(p[i] * f) for i in range(3)) + (p[3],)
    return out


def cube(tex, a=64):
    """Isometric cube, width 2a, height 2a. tex is a 16x16 tile."""
    out = Image.new("RGBA", (2 * a, 2 * a), (0, 0, 0, 0))
    t = (a, 0)
    r = (2 * a, a // 2)
    c = (a, a)
    lft = (0, a // 2)
    bl = (0, a // 2 + a)
    bc = (a, 2 * a)
    br = (2 * a, a // 2 + a)
    faces = (
        (t, r, lft, (t, r, c, lft), 1.0),       # top: u -> R, v -> L
        (lft, c, bl, (lft, c, bc, bl), 0.8),    # left
        (c, r, bc, (c, r, br, bc), 0.64),       # right
    )
    for origin, pu, pv, poly, light in faces:
        eu = ((pu[0] - origin[0]) / 16, (pu[1] - origin[1]) / 16)
        ev = ((pv[0] - origin[0]) / 16, (pv[1] - origin[1]) / 16)
        det = eu[0] * ev[1] - eu[1] * ev[0]
        # inverse of [[eu.x, ev.x], [eu.y, ev.y]]
        ia, ib = ev[1] / det, -ev[0] / det
        ic, id_ = -eu[1] / det, eu[0] / det
        coeffs = (ia, ib, -(ia * origin[0] + ib * origin[1]),
                  ic, id_, -(ic * origin[0] + id_ * origin[1]))
        face = shade(tex, light).transform((2 * a, 2 * a), Image.AFFINE,
                                           coeffs, resample=Image.NEAREST)
        mask = Image.new("L", (2 * a, 2 * a), 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        out.paste(face, (0, 0), mask)
    return out


class Sheet:
    def __init__(self, w, h, title):
        self.im = Image.new("RGBA", (w, h), BG)
        self.d = ImageDraw.Draw(self.im)
        self.d.text((16, 10), title, fill=FG, font=font(22))

    def put(self, img, x, y):
        self.im.alpha_composite(img, (x, y))

    def text(self, x, y, s, size=15, fill=FG):
        self.d.text((x, y), s, fill=fill, font=font(size))

    def save(self, path):
        self.im.convert("RGB").save(path, optimize=True)


def render_tiers(out, stone, dest):
    names = ["T1 default_stone"] + ["T%d" % t for t in range(2, 7)]
    tiles = [stone] + [out["grug_materials_t%d_stone.png" % t]
                       for t in range(2, 7)]
    old = [stone] + [colorize(stone, OLD_ROCKS[k]) for k in
                     ("slate", "basalt", "granite", "emberrock", "abyssal_rock")]
    col = 200
    s = Sheet(40 + col * 6 + 260, 730,
              "Round 24 tier rocks: same stone, compressed by depth")
    for i, (n, t, o) in enumerate(zip(names, tiles, old)):
        x = 30 + i * col
        s.text(x, 50, n)
        s.put(scale(t, 10), x, 76)
        s.put(scale(tiled(t, 3), 3), x + 8, 250)
        s.put(cube(t, 72), x + 8, 410)
        s.text(x, 575, ("today: " + OLD_NAMES[i - 1]) if i else "(unchanged)",
               fill=DIM)
        s.put(scale(o, 6), x + 32, 600)
    s.text(30, 700, "rows: tile x10, 3x3 tiling, cube, today's stratum "
           "(colorized default_stone)", size=13, fill=DIM)
    # a cliff: 6 bands of 4 blocks, each block 32 px
    x0, y0 = 40 + col * 6 - 10, 50
    s.text(x0, y0, "cliff, T1 top -> T6 bottom")
    for band, t in enumerate(tiles):
        for row in range(2):
            for bx in range(7):
                s.put(scale(t, 2), x0 + bx * 32, y0 + 26 + (band * 2 + row) * 32)
    # a tunnel wall with an ore band crossing T1..T6 is in the ores sheet
    s.save(dest / "tier-rocks.png")


def render_decor(out, stone, dest):
    rows = [("default_stone", stone),
            ("slate", out["grug_materials_slate.png"]),
            ("basalt", out["grug_materials_basalt.png"]),
            ("granite", out["grug_materials_granite.png"]),
            ("T4 (for contrast)", out["grug_materials_t4_stone.png"]),
            ("T6 (for contrast)", out["grug_materials_t6_stone.png"])]
    col = 200
    s = Sheet(40 + col * len(rows), 700,
              "Round 24 decorative rocks (drop themselves, building variety)")
    for i, (n, t) in enumerate(rows):
        x = 30 + i * col
        s.text(x, 50, n)
        s.put(scale(t, 10), x, 76)
        s.put(scale(tiled(t, 3), 3), x + 8, 250)
        s.put(cube(t, 72), x + 8, 410)
    # a small wall: stone with slate/basalt/granite blocks mixed in
    s.text(30, 580, "mixed wall", size=15)
    pattern = ["SSSGSSSSBSSS", "SLLSSSBBSSGS", "SSSSGSSSSLLS"]
    key = {"S": stone, "L": out["grug_materials_slate.png"],
           "B": out["grug_materials_basalt.png"],
           "G": out["grug_materials_granite.png"]}
    for r, line in enumerate(pattern):
        for c, ch in enumerate(line):
            s.put(scale(key[ch], 2), 150 + c * 32, 590 + r * 32)
    s.save(dest / "decorative-rocks.png")


def render_ores(out, stone, mtg_dir, dest):
    col = 128
    s = Sheet(40 + col * len(ORE_ORDER), 700,
              "Round 24 ores vs gems: before (today) and after")
    mtg = lambda n: Image.open(mtg_dir / n).convert("RGBA")
    t5 = out["grug_materials_t5_stone.png"]
    for i, key in enumerate(ORE_ORDER):
        x = 24 + i * col
        s.text(x, 50, ORE_LABEL[key], size=13)
        if key in VENDORED_ORES:
            before = over(stone, mtg("default_mineral_%s.png" % key))
            after = before
        else:
            src, spec = OLD_ORES[key]
            before = over(stone, colorize(mtg(src), spec))
            after = over(stone, out["grug_materials_mineral_%s.png" % key])
        s.put(scale(before, 7), x, 90)
        s.put(scale(after, 7), x, 230)
        s.put(cube(after, 52), x + 4, 366)
        # in dark tier rock: ore block (light background) inside T5
        ctx = Image.new("RGBA", (48, 48))
        for a in range(3):
            for b in range(3):
                ctx.paste(after if (a, b) == (1, 1) else t5, (a * 16, b * 16))
        s.put(scale(ctx, 2), x + 8, 490)
        s.text(x, 594, "unchanged" if key in VENDORED_ORES else "new",
               size=12, fill=DIM)
    s.text(24, 70, "before", size=13, fill=DIM)
    s.text(24, 212, "after", size=13, fill=DIM)
    s.text(24, 470, "after, inside T5 rock (accepted light background)",
           size=13, fill=DIM)
    s.text(24, 640, "Metal ores keep the minetest_game streak language; gems "
           "and crystals take VoxeLibre-style faceted motifs.", size=14)
    s.text(24, 664, "G1 gems: single large cut; G2 gems: cluster cut; "
           "Emberglass/Abyssal Crystal: own crystal shapes; quartz: pale "
           "flecks; silver: relief-shaded blue-white streaks.", size=14)
    s.save(dest / "ores-gems.png")


def render_all(out, stone, mtg_dir, dest):
    dest.mkdir(parents=True, exist_ok=True)
    render_tiers(out, stone, dest)
    render_decor(out, stone, dest)
    render_ores(out, stone, mtg_dir, dest)
    print("wrote renders to", dest)

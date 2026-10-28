#!/usr/bin/env python3
"""Round 66 lane MAP: the camps' map icons in their faction's colour (ruling 8).

Recoloured by palette from the approved 32px masters
(tools/map_icon_rework/drop01/icons); nothing is drawn anew and the alpha
channel is kept, so each variant's alpha mask is its master's.

- war_camp_accord: the war camp's crimson canvas turned blue. The master is
  the Throng's (today's red art, unchanged); the canvas pixels (red hues) get
  the HSV transform that takes the Throng's colour to the Accord's.
- camp_construction_<faction>: the ivory cloth on the scaffold (its pale
  pixels right of the left A-frame) in the faction's colour, its shading
  kept as brightness; the timber is unchanged.

The faction colours are read from grug_core.factions
(mods/CORE/grug_core/init.lua). tools/r64_map/ship.py ships the variants with
the approved icons and writes their masks.

  python3 tools/r66_map/recolor.py [--preview OUT.png]

Without arguments it prints the variants' colour figures; --preview writes
a sheet of the masters and the variants on light and dark ground at 1x and
8x for review.
"""
import argparse
import colorsys
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MASTERS = ROOT / 'tools/map_icon_rework/drop01/icons'
CORE = ROOT / 'mods/CORE/grug_core/init.lua'


def faction_colours():
    text = CORE.read_text()
    found = {}
    for faction in ('accord', 'throng'):
        match = re.search(faction + r'\s*=\s*\{[^}]*?color\s*=\s*"#([0-9a-fA-F]{6})"', text)
        assert match, faction
        hexa = match.group(1)
        found[faction] = tuple(int(hexa[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return found


def hsv(rgb):
    return colorsys.rgb_to_hsv(*rgb)


def to_rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, min(1.0, max(0.0, s)), min(1.0, max(0.0, v)))
    return tuple(int(round(c * 255)) for c in (r, g, b))


def is_canvas_red(x, y, h, s, v):
    # The tent's crimson: red hues (330-6 degrees), clearly saturated. Its
    # lit upper-left slope warms to orange (up to 25 degrees); below the
    # spear tips (row 10 on) such a bright pixel is canvas too. The spears
    # and their brass points are orange to yellow and lie above row 10 or
    # are dark there.
    degrees = h * 360
    if s < 0.5:
        return False
    return degrees >= 330 or degrees <= 6 or (y >= 10 and degrees <= 25 and v >= 0.45)


HUE_SPREAD = 0.25


def war_camp(master, source, target):
    sh, ss, sv = hsv(source)
    th, ts, tv = hsv(target)
    out = master.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = hsv((r / 255, g / 255, b / 255))
            if is_canvas_red(x, y, h, s, v):
                # the canvas's hue spread (crimson to its orange highlights)
                # kept at a quarter, so lit blue stays blue, not violet
                spread = (h - sh + 0.5) % 1.0 - 0.5
                pixels[x, y] = to_rgb(th + HUE_SPREAD * spread, s * ts / ss, v * tv / sv) + (a,)
    return out


# The cloth: the pale pixels right of the left A-frame, inside the scaffold.
CLOTH_BOX = (16, 8, 30, 24)   # x0, y0, x1, y1 (exclusive ends)
CLOTH_WHITE = 0.96            # the cloth's brightest value (its lit fold)


def is_cloth(x, y, h, s, v):
    x0, y0, x1, y1 = CLOTH_BOX
    degrees = h * 360
    return x0 <= x < x1 and y0 <= y < y1 and s < 0.47 and 15 <= degrees <= 60


def construction(master, target):
    th, ts, tv = hsv(target)
    out = master.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = hsv((r / 255, g / 255, b / 255))
            if is_cloth(x, y, h, s, v):
                pixels[x, y] = to_rgb(th, ts, tv * v / CLOTH_WHITE) + (a,)
    return out


def variants():
    """name -> (master name, RGBA image) for every faction variant."""
    colours = faction_colours()
    war = Image.open(MASTERS / 'war_camp.png').convert('RGBA')
    site = Image.open(MASTERS / 'camp_construction.png').convert('RGBA')
    return {
        'war_camp_accord.png': ('war_camp.png', war_camp(war, colours['throng'], colours['accord'])),
        'camp_construction_accord.png': ('camp_construction.png', construction(site, colours['accord'])),
        'camp_construction_throng.png': ('camp_construction.png', construction(site, colours['throng'])),
    }


def changed_pixels(master, variant):
    a, b = master.load(), variant.load()
    return sum(1 for y in range(master.height) for x in range(master.width) if a[x, y] != b[x, y])


def preview(path):
    rows = [('war_camp.png', ['war_camp.png', 'war_camp_accord.png']),
            ('camp_construction.png', ['camp_construction.png', 'camp_construction_accord.png',
                                       'camp_construction_throng.png'])]
    made = variants()

    def image(name):
        if name in made:
            return made[name][1]
        return Image.open(MASTERS / name).convert('RGBA')
    grounds = [(78, 104, 64, 255), (214, 204, 170, 255), (34, 52, 74, 255)]
    cell = 8 * 32 + 16
    sheet = Image.new('RGBA', (len(grounds) * 3 * cell, 2 * (cell + 48)), (0, 0, 0, 255))
    for row, (_, names) in enumerate(rows):
        for gi, ground in enumerate(grounds):
            for ni, name in enumerate(names):
                x0, y0 = (gi * 3 + ni) * cell, row * (cell + 48)
                tile = Image.new('RGBA', (cell, cell + 48), ground)
                big = image(name).resize((256, 256), Image.NEAREST)
                tile.alpha_composite(big, (8, 8))
                tile.alpha_composite(image(name), (8, cell + 8))
                tile.alpha_composite(image(name).resize((16, 16), Image.LANCZOS), (48, cell + 16))
                sheet.alpha_composite(tile, (x0, y0))
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--preview', metavar='OUT.png')
    args = parser.parse_args()
    colours = faction_colours()
    for faction, rgb in colours.items():
        h, s, v = hsv(rgb)
        print(f'{faction}: #{"".join(f"{round(c * 255):02x}" for c in rgb)} '
              f'h {h * 360:.0f} s {s:.2f} v {v:.2f}')
    for name, (master, image) in variants().items():
        source = Image.open(MASTERS / master).convert('RGBA')
        print(f'{name}: {changed_pixels(source, image)} pixels recoloured from {master}')
    if args.preview:
        preview(args.preview)
        print('preview:', args.preview)


if __name__ == '__main__':
    main()

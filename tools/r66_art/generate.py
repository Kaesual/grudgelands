#!/usr/bin/env python3
"""Draw the Round 66 proposals and a self-contained review page.

Run from any directory: python3 tools/r66_art/generate.py [--check]
Requires Python 3, Pillow and numpy. Authored geometry, no external assets.
Code: GPL-3.0-or-later. Original candidate art: CC0-1.0.
"""
from __future__ import annotations

import argparse
from io import BytesIO
from math import cos, pi, sin
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
SIZE = 64
SCALE = 4
WHITE = (255, 255, 249, 255)
IVORY = (255, 247, 220, 255)
GOLD = (250, 225, 164, 255)
SURFACES = (
    ("night", "Night", "#152337"),
    ("cave", "Cave", "#292629"),
    ("snow", "Snow", "#e8edf3"),
    ("sky", "Sky", "#96c9e5"),
    ("sand", "Sand", "#d5bb86"),
)
CANDIDATES = (
    ("smite_hammer_c", "Hammer C", "Crowned mallet", "Flared striking faces, a diamond seal and a ringed grip give the broad descending head a ceremonial weight."),
    ("censure_book_j", "Book J", "J, pass 5", "The user's favourite, unchanged for comparison: gently bowed pages, square gold boards and four curved writing lines per page."),
    ("censure_book_o", "Book O", "The lightest touch", "A slightly lower dome and a trace more width keep this refinement closest to J."),
    ("censure_book_p", "Book P", "A calmer spread", "A gently flattened dome and a little more width give the pages room while keeping their upward bow clear."),
    ("censure_book_q", "Book Q", "A little broader", "The flattest and widest of these close refinements still rises softly from the straight gutter."),
)
PICKED = 'smite_hammer_c'
REFERENCE = 'censure_book_j'
RECOMMENDED = 'censure_book_p'


class Drawing:
    def __init__(self):
        self.image = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE))
        self.draw = ImageDraw.Draw(self.image)

    def polygon(self, points, fill):
        self.draw.polygon([(round(x*SCALE), round(y*SCALE)) for x, y in points], fill=fill)

    def line(self, points, fill, width=1):
        self.draw.line([(round(x*SCALE), round(y*SCALE)) for x, y in points], fill=fill,
                       width=round(width*SCALE), joint="curve")

    def finish(self):
        # Tight halo only: preserve the silhouette, no round aura or trailing particles.
        alpha = self.image.getchannel("A")
        halo = alpha.filter(ImageFilter.GaussianBlur(1.15*SCALE)).point(lambda v: round(v*0.22))
        light = Image.new("RGBA", self.image.size, IVORY)
        light.putalpha(halo)
        out = Image.alpha_composite(light, self.image).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        data = np.array(out)
        data[data[:, :, 3] < 2] = 0
        # Keep RGB bright even on antialiased pixels. Transparent gaps, never dark ink.
        visible = data[:, :, 3] > 0
        data[visible, :3] = np.maximum(data[visible, :3], (245, 218, 155))
        return Image.fromarray(data)


def hammer_c():
    d = Drawing()
    # Straight shaft, diamond pommel, three broad grip rings.
    d.polygon([(29, 11), (35, 11), (35, 35), (29, 35)], IVORY)
    d.line([(31, 13), (31, 33)], WHITE, 2)
    d.polygon([(32, 5), (37, 10), (32, 15), (27, 10)], GOLD)
    d.polygon([(32, 6), (35, 10), (32, 12), (29, 10)], WHITE)
    for y in (17, 23, 29):
        d.polygon([(28, y), (36, y), (36, y+2), (28, y+2)], GOLD)
        d.line([(28, y), (35, y)], WHITE, 0.75)
    d.polygon([(28, 32), (36, 32), (39, 38), (25, 38)], GOLD)
    d.polygon([(30, 33), (34, 33), (36, 38), (28, 38)], WHITE)
    # Flared end faces and a lower central keel are silhouette features;
    # the pale inlaid seal is secondary and may wash out in additive light.
    d.polygon([(9, 35), (12, 32), (19, 32), (22, 37), (42, 37),
               (45, 32), (52, 32), (55, 35), (55, 51), (51, 55),
               (44, 55), (41, 51), (35, 51), (32, 54), (29, 51),
               (23, 51), (20, 55), (13, 55), (9, 51)], GOLD)
    d.polygon([(19, 36), (23, 39), (41, 39), (45, 36), (45, 50),
               (35, 50), (32, 52), (29, 50), (19, 50)], IVORY)
    d.polygon([(10, 36), (13, 34), (17, 34), (17, 52), (14, 52), (10, 49)], WHITE)
    d.polygon([(47, 34), (51, 34), (54, 36), (54, 49), (50, 52), (47, 52)], WHITE)
    d.line([(22, 38), (42, 38)], WHITE, 1.5)
    d.line([(23, 50), (29, 50), (32, 52), (35, 50), (41, 50)], WHITE, 1)
    d.polygon([(32, 39), (37, 44), (32, 49), (27, 44)], GOLD)
    d.polygon([(32, 41), (34, 44), (32, 47), (30, 44)], WHITE)
    return d.finish()


def finish_book(d):
    """Mirror authored left-page geometry about the exact centre of the sprite."""
    half = d.image.crop((0, 0, SIZE*SCALE//2, SIZE*SCALE))
    d.image.paste(ImageOps.mirror(half), (SIZE*SCALE//2, 0))
    return d.finish()


def hardcover_book(dome, page_width=1.0):
    """Bow the leaves above rigid boards in the chosen reclining projection.

    Preserve pass 4's projection (far scale 0.56, far y 25, near y 48).
    Only paper bows: a smooth cross-section rises out of a straight gutter
    and rolls down to the fore edge. Lower leaves settle onto flat boards.
    """
    d = Drawing()
    page_depth, board_depth = 4.5, 0.9

    def project(points, drop=0):
        out = []
        for x, y in points:
            t = (y-15)/37
            scale = 0.56 / (1-0.44*t)
            out.append((32+(x-32)*scale, 25+23*t*scale+drop))
        return out

    def shifted(points, dy):
        return [(x, y+dy) for x, y in points]

    def arch(u):
        return sin(pi*u)

    def leaf(u, v, layer=0):
        # u: gutter -> fore edge; v: far -> near; layer: top -> bottom.
        # The hinge is a constant-width channel, not a perspective wedge.
        y = (19-4*u)*(1-v) + (47-3*u)*v
        t = (y-15)/37
        scale = 0.56 / (1-0.44*t)
        x = 31.65*(1-u) + (32-23*page_width*scale)*u
        bow = dome*arch(u)*scale*(1-layer)
        return (x, 25+23*t*scale + page_depth*layer - bow)

    steps = 96
    across = [i/steps for i in range(steps+1)]

    def cut(layer):
        return [leaf(u, 1, layer) for u in across]

    far = [leaf(u, 0) for u in across]
    near = cut(0)
    top_inner, top_outer = far[0], far[-1]
    near_inner, near_outer = near[0], near[-1]
    # Widen the outer boards with the pages, keeping the hinge untouched.
    outer = 32-26.5*page_width
    board = project([(outer, 13), (31.75, 18), (31.75, 50), (outer, 47)], page_depth)

    # A real slab: gold board top plus its parallel lower edge. Opacity
    # separates volumes in additive light; all source RGB stays luminous.
    d.polygon(shifted(board, board_depth), (*GOLD[:3], 190))
    d.polygon(board, GOLD)
    near_edge = board[2:]
    d.polygon(near_edge + list(reversed(shifted(near_edge, board_depth))),
              (*GOLD[:3], 190))
    d.line(shifted(near_edge, board_depth), IVORY, 0.8)

    # Luminous cut faces. Their reduced opacity preserves paper layering
    # under additive light without painting any dark outline or shadow.
    d.polygon([top_outer, near_outer, leaf(1, 1, 1), leaf(1, 0, 1)],
              (*IVORY[:3], 165))
    d.polygon(near + list(reversed(cut(1))), (*IVORY[:3], 175))
    for fraction in (0.18, 0.36, 0.54, 0.72, 0.9):
        d.line(cut(fraction), (*WHITE[:3], 235), 0.4)
        d.line([leaf(1, 0, fraction), leaf(1, 1, fraction)],
               (*WHITE[:3], 225), 0.4)

    # Page surface with a broad crest highlight, following the dome.
    # Adjacent ruled strips form one continuous surface.
    for i in range(steps):
        u0, u1 = across[i:i+2]
        u = (u0+u1)/2
        crest = arch(u)
        slope = cos(pi*u)
        tone = (255, round(235+20*crest), round(196+53*crest))
        alpha = round(212+43*crest-18*max(0, slope))
        d.polygon([leaf(u0, 0), leaf(u1, 0), leaf(u1, 1), leaf(u0, 1)],
                  (*tone, alpha))
    d.line(far, WHITE, 0.6)
    d.line([top_outer, near_outer], WHITE, 0.65)
    d.line(near, WHITE, 0.65)

    # Constant-v strokes lie on the very same curved surface as the page.
    # Four long marks, no glyphs or tiny dashes. A quiet pale-gold stroke
    # replaces surface pixels at slightly lower opacity for additive light;
    # subpixel width lets it blend away when the icon is reduced to 16 px.
    for v, stop in ((0.25, 0.81), (0.41, 0.77), (0.57, 0.81), (0.73, 0.62)):
        line = [leaf(0.20+(stop-0.20)*i/48, v) for i in range(49)]
        d.line(line, (255, 237, 200, 190), 0.45)

    # Less than one source pixel wide; the centre stays straight even as
    # the page contours curve up on either side. No wide binding band.
    d.polygon([(31.65, top_inner[1]), (32, top_inner[1]),
               (32, near_inner[1]+page_depth+board_depth),
               (31.65, near_inner[1]+page_depth+board_depth)],
              (*GOLD[:3], 115))
    return finish_book(d)


def book_j():
    return hardcover_book(dome=5)


def book_o():
    return hardcover_book(dome=4.6, page_width=1.025)


def book_p():
    return hardcover_book(dome=4.2, page_width=1.05)


def book_q():
    return hardcover_book(dome=3.8, page_width=1.075)


def png_bytes(im):
    out = BytesIO()
    im.save(out, format="PNG", optimize=False)
    return out.getvalue()


def img(name, size, extra=""):
    label = next(c[1] for c in CANDIDATES if c[0] == name)
    return f'<img src="{name}.png" width="{size}" height="{size}" alt="{label}" {extra}>'


def samples(name, blend):
    return '<div class="samples '+blend+'">' + ''.join(
        '<div class="sample">'+img(name, s)+f'<span>{s} px</span></div>' for s in (16, 32, 64)) + '</div>'


def card(candidate, compact=False):
    name, label, title, idea = candidate
    badge = (' · Picked' if name == PICKED else ' · Reference' if name == REFERENCE
             else ' · Recommended' if name == RECOMMENDED else '')
    rows = ''.join(f'<div class="surface-row"><div class="surface-label">{label_bg}</div>'
                   f'<div class="surface {key}">{samples(name, "plain")}</div>'
                   f'<div class="surface {key}">{samples(name, "add")}</div></div>'
                   for key, label_bg, _ in SURFACES)
    views = '<div class="views"><div class="table-head"><span>Ground</span><span>Plain alpha</span><span>Additive light</span></div>'+rows+'</div>'
    if compact:
        views = '<details class="picked-views"><summary>Compare on five grounds · 16 / 32 / 64 px</summary>'+views+'</details>'
    return f"""<article class="candidate{' picked' if compact else ''}" id="{name}">
    <header class="candidate-head"><div class="hero-sprite add">{img(name, 128)}</div>
    <div><p class="eyebrow">{label}{badge}</p>
    <h3>{title}</h3><p>{idea}</p></div></header>
    {views}</article>"""


def figure():
    return '<div class="figure" aria-label="Schematic figure, one node wide and two nodes tall"><i class="head"></i><i class="body"></i><i class="arms"></i><i class="legs"></i></div>'


def context(hammer, book):
    # Reuse the established catalogue preview scale: size * 0.1 node.
    # tools/r52_pfx/template.html uses the same conversion. One node = 64 CSS px.
    cells = []
    for title, name, units, note in (
        ('Smite', f'smite_hammer_{hammer}', 7, '3.2 m fall · about 0.15 s'),
        ('Final Word', f'smite_hammer_{hammer}', 12, 'Same hammer · white column'),
        ('Censure', f'censure_book_{book}', 16, '6 m fall · 0.75 s warning'),
    ):
        side = units * 0.1 * 64
        sprite = img(name, SIZE, f'style="width:{side:g}px;height:{side:g}px"')
        cells.append(f'<div class="scale-cell"><h4>{title}</h4><p>{note}</p>'
                     f'<div class="scene"><div class="symbol add">{sprite}</div>{figure()}'
                     '<div class="ruler">1 node</div></div>'
                     f'<p class="size-note">Size {units} · sprite square {units/10:g} nodes</p></div>')
    badge = ' · recommended pair' if f'censure_book_{book}' == RECOMMENDED else ''
    return f'<article class="context-card"><h3>Hammer {hammer.upper()} + Book {book.upper()}{badge}</h3><div class="scale-strip">'+''.join(cells)+'</div></article>'


def add_strip(sheet, image, x, y, spacing=102):
    icon = np.asarray(image).astype(np.float64)
    for j, (_, _, colour) in enumerate(SURFACES):
        bg = np.array(tuple(bytes.fromhex(colour[1:])), dtype=np.float64)
        rgb = np.rint(np.minimum(255, bg + icon[:, :, :3]*icon[:, :, 3:4]/255)).astype(np.uint8)
        sheet.paste(Image.fromarray(rgb), (x+j*spacing, y))


def overview(images):
    """A static contact sheet for inspection without a browser."""
    sheet = Image.new("RGB", (1448, 724), '#111a24')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=13)
    recommended_label = next(c[1] for c in CANDIDATES if c[0] == RECOMMENDED)
    draw.text((28, 22), f'ROUND 66 / PASS 6     Hammer C picked / {recommended_label} recommended / J, pass 5 reference', font=font, fill='#f8ead1')
    name, label, title, _ = CANDIDATES[0]
    draw.rectangle((24, 66, 1424, 266), fill='#1e2a36')
    draw.text((40, 78), label+' / '+title+' / PICKED', font=font, fill='#f8ead1')
    icon = images[name].resize((128, 128), Image.Resampling.NEAREST)
    sheet.paste(icon, (40, 118), icon)
    for j, size in enumerate((16, 32, 64)):
        icon = images[name].resize((size, size), Image.Resampling.LANCZOS)
        sheet.paste(icon, (232+j*90-size//2, 169-size//2), icon)
        draw.text((216+j*90, 215), str(size)+' px', font=small, fill='#c1cbd4')
    draw.text((580, 106), 'ADD / night     cave           snow           sky             sand', font=small, fill='#c1cbd4')
    add_strip(sheet, images[name], 582, 138)
    draw.text((580, 224), 'Smite 7 / Final Word 12 / unchanged texture', font=small, fill='#c1cbd4')
    for i, (name, label, title, _) in enumerate(CANDIDATES[1:]):
        x, y = 24+i*356, 288
        draw.rectangle((x, y, x+332, y+410), fill='#1e2a36')
        draw.text((x+16, y+12), label+' / '+title, font=font, fill='#f8ead1')
        if name == RECOMMENDED:
            draw.text((x+16, y+35), 'RECOMMENDED', font=small, fill='#e8ca89')
        elif name == REFERENCE:
            draw.text((x+16, y+35), 'REFERENCE / UNCHANGED', font=small, fill='#e8ca89')
        icon = images[name].resize((160, 160), Image.Resampling.NEAREST)
        sheet.paste(icon, (x+86, y+46), icon)
        for j, size in enumerate((16, 32, 64)):
            icon = images[name].resize((size, size), Image.Resampling.LANCZOS)
            sheet.paste(icon, (x+76+j*90-size//2, y+240-size//2), icon)
            draw.text((x+60+j*90, y+282), str(size)+' px', font=small, fill='#c1cbd4')
        draw.text((x+16, y+317), 'ADD / night    cave     snow     sky      sand', font=small, fill='#c1cbd4')
        add_strip(sheet, images[name].resize((52, 52), Image.Resampling.LANCZOS), x+16, y+343, spacing=62)
    return sheet


def build():
    images = dict(zip((c[0] for c in CANDIDATES),
                      (hammer_c(), book_j(), book_o(), book_p(), book_q())))
    outputs = {}
    for name, im in images.items():
        assert im.mode == 'RGBA' and im.size == (64, 64)
        a = np.asarray(im)[:, :, 3]
        assert not a[0].any() and not a[-1].any() and not a[:, 0].any() and not a[:, -1].any(), name
        if name.startswith('censure_book_'):
            assert np.array_equal(np.asarray(im), np.asarray(ImageOps.mirror(im))), name
        data = png_bytes(im)
        outputs[f'candidates/{name}.png'] = data
        outputs[f'preview/{name}.png'] = data
    template = (ROOT / 'preview.html.in').read_text()
    template = template.replace('@@HAMMERS@@', card(CANDIDATES[0], compact=True))
    template = template.replace('@@BOOKS@@', ''.join(card(c) for c in CANDIDATES[1:]))
    template = template.replace('@@CONTEXT@@', ''.join(context('c', c[0].rsplit('_', 1)[1]) for c in CANDIDATES[2:]))
    outputs['preview/index.html'] = template.encode()
    outputs['preview/contact-sheet.png'] = png_bytes(overview(images))
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Compare generated files without writing.')
    args = parser.parse_args()
    outputs = build()
    unexpected = sorted(str(path.relative_to(ROOT))
                        for folder in ('candidates', 'preview')
                        for path in (ROOT / folder).glob('*.png')
                        if str(path.relative_to(ROOT)) not in outputs)
    if unexpected:
        raise SystemExit('Unexpected generated PNGs; remove retired outputs: '+', '.join(unexpected))
    stale = []
    for name, data in outputs.items():
        path = ROOT / name
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                stale.append(name)
        else:
            path.parent.mkdir(exist_ok=True, parents=True)
            path.write_bytes(data)
    if stale:
        raise SystemExit('Stale or missing outputs: '+', '.join(stale))
    print(('Checked' if args.check else 'Wrote')+f' {len(outputs)} files: {len(CANDIDATES)} 64x64 RGBA candidates, preview copies, page and contact sheet.')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Draw the Round 66 proposals and a self-contained review page.

Run from any directory: python3 tools/r66_art/generate.py [--check]
Requires Python 3, Pillow and numpy. Authored geometry, no external assets.
Code: GPL-3.0-or-later. Original candidate art: CC0-1.0.
"""
from __future__ import annotations

import argparse
from io import BytesIO
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
    ("censure_book_g", "Book G", "Gilded boards", "Thick, square gold boards hold a broad ivory page block around a straight, firm central spine."),
    ("censure_book_h", "Book H", "Deep folio", "A deeper page block rests on slimmer gold boards, with clipped outer corners and the same straight spine."),
)
PICKED = 'smite_hammer_c'
RECOMMENDED = 'censure_book_g'


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


def hardcover_book(page_depth, board_depth, clipped):
    """Extrude the spread and rigid boards in the chosen reclining projection.

    The page plane keeps the previous chosen tilt: far scale 0.56, far y 25,
    near y 48. Every long edge is straight. The centre is a parallel strip,
    with no curved lip or flared toe at the bottom of the spine.
    """
    d = Drawing()

    def project(points, drop=0):
        out = []
        for x, y in points:
            t = (y-15)/37
            scale = 0.56 / (1-0.44*t)
            out.append((32+(x-32)*scale, 25+23*t*scale+drop))
        return out

    def shifted(points, dy):
        return [(x, y+dy) for x, y in points]

    # Straight quadrilateral leaves; a slight dip toward the central hinge
    # makes two open halves, without the earlier bent lower page contour.
    page = project([(9, 15), (29.5, 19), (29.5, 47), (9, 44)])
    top_outer, top_inner, near_inner, near_outer = page
    if clipped:
        board = project([(6, 14), (30.5, 18), (30.5, 50),
                         (7.5, 47), (6, 45.5)], page_depth)
    else:
        board = project([(5.5, 13), (30.5, 18), (30.5, 50), (5.5, 47)], page_depth)

    # A real slab: gold board top plus its parallel lower edge. Opacity
    # separates volumes in additive light; all source RGB stays luminous.
    d.polygon(shifted(board, board_depth), (*GOLD[:3], 190))
    d.polygon(board, GOLD)
    near_edge = board[2:]
    d.polygon(near_edge + list(reversed(shifted(near_edge, board_depth))),
              (*GOLD[:3], 190))
    d.line(shifted(near_edge, board_depth), IVORY, 0.8)

    # Page block: outer side and near cut face share the same extrusion.
    d.polygon(shifted(page, page_depth), IVORY)
    d.polygon([top_outer, near_outer, *reversed(shifted([top_outer, near_outer], page_depth))],
              (*IVORY[:3], 210))
    d.polygon([near_outer, near_inner, *reversed(shifted([near_outer, near_inner], page_depth))],
              (*IVORY[:3], 215))
    # Two broad leaf divisions on the cut face, never markings on the page.
    for fraction in (0.38, 0.73):
        d.line(shifted([near_outer, near_inner], page_depth*fraction), WHITE, 0.55)
    d.polygon(page, IVORY)
    d.line([top_outer, top_inner], WHITE, 0.85)
    d.line([top_outer, near_outer], WHITE, 1)
    d.line([near_outer, near_inner], WHITE, 1)

    # Keep a constant-width central spine: straight from head to foot, not
    # a projected wedge. Narrow translucent hinge channels flank its core.
    head = top_inner[1]
    foot = near_inner[1] + page_depth + board_depth
    d.polygon([(30.5, head), (32, head), (32, foot), (30.5, foot)],
              (*GOLD[:3], 95))
    d.polygon([(31.5, head), (32, head), (32, foot), (31.5, foot)], WHITE)
    return finish_book(d)


def book_g():
    return hardcover_book(page_depth=4, board_depth=2.5, clipped=False)


def book_h():
    return hardcover_book(page_depth=6, board_depth=1.25, clipped=True)


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
    badge = ' · Picked' if name == PICKED else ' · Recommended' if name == RECOMMENDED else ''
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
    badge = ' · recommended pair' if (hammer, book) == ('c', 'g') else ''
    return f'<article class="context-card"><h3>Hammer {hammer.upper()} + Book {book.upper()}{badge}</h3><div class="scale-strip">'+''.join(cells)+'</div></article>'


def add_strip(sheet, image, x, y):
    icon = np.asarray(image).astype(np.float64)
    for j, (_, _, colour) in enumerate(SURFACES):
        bg = np.array(tuple(bytes.fromhex(colour[1:])), dtype=np.float64)
        rgb = np.rint(np.minimum(255, bg + icon[:, :, :3]*icon[:, :, 3:4]/255)).astype(np.uint8)
        sheet.paste(Image.fromarray(rgb), (x+j*102, y))


def overview(images):
    """A static contact sheet for inspection without a browser."""
    sheet = Image.new("RGB", (1120, 640), '#111a24')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=13)
    draw.text((28, 22), 'ROUND 66 / PASS 4     Hammer C picked / Book G recommended', font=font, fill='#f8ead1')
    name, label, title, _ = CANDIDATES[0]
    draw.rectangle((24, 66, 1104, 266), fill='#1e2a36')
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
        x, y = 24+i*552, 288
        draw.rectangle((x, y, x+528, y+318), fill='#1e2a36')
        badge = ' / RECOMMENDED' if name == RECOMMENDED else ''
        draw.text((x+16, y+12), label+' / '+title+badge, font=font, fill='#f8ead1')
        icon = images[name].resize((160, 160), Image.Resampling.NEAREST)
        sheet.paste(icon, (x+10, y+53), icon)
        for j, size in enumerate((16, 32, 64)):
            icon = images[name].resize((size, size), Image.Resampling.LANCZOS)
            sheet.paste(icon, (x+208+j*90-size//2, y+100-size//2), icon)
            draw.text((x+192+j*90, y+145), str(size)+' px', font=small, fill='#c1cbd4')
        draw.text((x+16, y+220), 'ADD / night     cave           snow           sky             sand', font=small, fill='#c1cbd4')
        add_strip(sheet, images[name], x+18, y+242)
    return sheet


def build():
    images = dict(zip((c[0] for c in CANDIDATES), (hammer_c(), book_g(), book_h())))
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
    template = template.replace('@@CONTEXT@@', ''.join(context('c', b) for b in ('g', 'h')))
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
    print(('Checked' if args.check else 'Wrote')+f' {len(outputs)} files: three 64x64 RGBA candidates, preview copies, page and contact sheet.')


if __name__ == '__main__':
    main()

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
    ("smite_hammer_d", "Hammer D", "Beaked war hammer", "A broad chamfered face balances a tapered ivory beak beneath a wrapped grip and a faceted pommel."),
    ("censure_book_e", "Book E", "Inclined folio", "The broad, quiet spread leans gently away, with a narrower far edge and a clear central fold."),
    ("censure_book_f", "Book F", "Reclining folio", "A stronger backward tilt shortens the pages and draws the far edge inward, like an open book resting on a low lectern."),
)
RECOMMENDED = ('smite_hammer_c', 'censure_book_e')


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


def hammer_d():
    d = Drawing()
    d.polygon([(29, 10), (35, 10), (35, 38), (29, 38)], IVORY)
    d.polygon([(29, 5), (35, 5), (38, 8), (36, 13), (28, 13), (26, 8)], GOLD)
    d.polygon([(29, 6), (35, 6), (36, 8), (34, 11), (30, 11), (28, 8)], WHITE)
    for y in (16, 22, 28):
        d.polygon([(29, y), (35, y+2), (35, y+4), (29, y+2)], GOLD)
    d.line([(30, 14), (30, 33)], WHITE, 1)
    d.polygon([(27, 33), (37, 33), (37, 37), (27, 37)], WHITE)
    # One broad striking face opposed by a short tapered counter-peen.
    d.polygon([(9, 35), (13, 31), (20, 31), (23, 36), (38, 36),
               (47, 39), (55, 46), (55, 49), (45, 46), (38, 48),
               (23, 49), (20, 55), (13, 55), (9, 51)], GOLD)
    d.polygon([(20, 36), (24, 38), (37, 38), (43, 41), (44, 45),
               (37, 46), (23, 47), (20, 50)], IVORY)
    d.polygon([(10, 36), (14, 33), (17, 33), (17, 53), (14, 53), (10, 50)], WHITE)
    d.polygon([(37, 37), (46, 40), (54, 47), (45, 44), (38, 46)], WHITE)
    d.line([(23, 37), (36, 37)], WHITE, 1.5)
    d.line([(23, 48), (37, 47)], WHITE, 1)
    d.polygon([(29, 38), (34, 38), (34, 47), (29, 47)], GOLD)
    d.line([(30, 39), (30, 46)], WHITE, 1)
    return d.finish()


def finish_book(d):
    """Mirror authored left-page geometry about the exact centre of the sprite."""
    half = d.image.crop((0, 0, SIZE*SCALE//2, SIZE*SCALE))
    d.image.paste(ImageOps.mirror(half), (SIZE*SCALE//2, 0))
    return d.finish()


def tilted_book(far_scale, far_y, near_y):
    """Project the calm open folio onto a plane leaning away from the viewer.

    Far-edge scale controls perspective convergence; the reduced vertical
    extent gives foreshortening. Keep the same blank leaves and shallow fold.
    """
    d = Drawing()

    def project(points):
        out = []
        for x, y in points:
            t = (y-15)/37
            scale = far_scale / (1-(1-far_scale)*t)
            out.append((32+(x-32)*scale, far_y+(near_y-far_y)*t*scale))
        return out

    # The two cover halves join below the transparent central gutter.
    d.polygon(project([(7, 16), (20, 16), (30, 20), (30, 48),
                       (32, 50), (32, 52), (20, 48), (7, 48)]), GOLD)
    d.polygon(project([(9, 15), (20, 15), (30, 19), (30, 47),
                       (20, 44), (9, 44)]), IVORY)
    d.line(project([(10, 16), (20, 16), (28.5, 19.5)]), WHITE, 1)
    d.line(project([(10, 17), (10, 43)]), WHITE, 1.25)
    d.line(project([(10, 46), (20, 46), (29, 49)]), WHITE, 1)
    return finish_book(d)


def book_e():
    return tilted_book(far_scale=0.74, far_y=19, near_y=50)


def book_f():
    return tilted_book(far_scale=0.56, far_y=25, near_y=48)


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


def card(candidate):
    name, label, title, idea = candidate
    badge = ' · Recommended' if name in RECOMMENDED else ''
    rows = ''.join(f'<div class="surface-row"><div class="surface-label">{label_bg}</div>'
                   f'<div class="surface {key}">{samples(name, "plain")}</div>'
                   f'<div class="surface {key}">{samples(name, "add")}</div></div>'
                   for key, label_bg, _ in SURFACES)
    return f"""<article class="candidate" id="{name}">
    <header class="candidate-head"><div class="hero-sprite add">{img(name, 128)}</div>
    <div><p class="eyebrow">{label}{badge}</p>
    <h3>{title}</h3><p>{idea}</p></div></header>
    <div class="views"><div class="table-head"><span>Ground</span><span>Plain alpha</span><span>Additive light</span></div>
    {rows}</div></article>"""


def figure():
    return '<div class="figure" aria-label="Schematic figure, one node wide and two nodes tall"><i class="head"></i><i class="body"></i><i class="arms"></i><i class="legs"></i></div>'


def context(hammer, book):
    # Reuse the established catalogue preview scale: size * 0.1 node.
    # tools/r52_pfx/template.html uses the same conversion. One node = 64 CSS px.
    cells = []
    for title, name, units, note in (
        ('Smite', f'smite_hammer_{hammer}', 5, '3.2 m fall · about 0.15 s'),
        ('Final Word', f'smite_hammer_{hammer}', 12, 'Same hammer · white column'),
        ('Censure', f'censure_book_{book}', 16, '6 m fall · 0.75 s warning'),
    ):
        side = units * 0.1 * 64
        sprite = img(name, SIZE, f'style="width:{side:g}px;height:{side:g}px"')
        cells.append(f'<div class="scale-cell"><h4>{title}</h4><p>{note}</p>'
                     f'<div class="scene"><div class="symbol add">{sprite}</div>{figure()}'
                     '<div class="ruler">1 node</div></div>'
                     f'<p class="size-note">Size {units} · sprite square {units/10:g} nodes</p></div>')
    badge = ' · recommended pair' if (hammer, book) == ('c', 'e') else ''
    return f'<article class="context-card"><h3>Hammer {hammer.upper()} + Book {book.upper()}{badge}</h3><div class="scale-strip">'+''.join(cells)+'</div></article>'


def overview(images):
    """A static contact sheet for inspection without a browser."""
    sheet = Image.new("RGB", (1120, 750), '#111a24')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=13)
    draw.text((28, 22), 'ROUND 66 / PASS 3     Recommended: Hammer C + Book E', font=font, fill='#f8ead1')
    for i, (name, label, title, _) in enumerate(CANDIDATES):
        x, y = 24 + (i % 2)*552, 66 + (i//2)*338
        draw.rectangle((x, y, x+528, y+318), fill='#1e2a36')
        badge = ' / RECOMMENDED' if name in RECOMMENDED else ''
        draw.text((x+16, y+12), label+' / '+title+badge, font=font, fill='#f8ead1')
        sheet.paste(images[name].resize((160, 160), Image.Resampling.NEAREST), (x+10, y+53),
                    images[name].resize((160, 160), Image.Resampling.NEAREST))
        for j, size in enumerate((16, 32, 64)):
            icon = images[name].resize((size, size), Image.Resampling.LANCZOS)
            sheet.paste(icon, (x+208+j*90-size//2, y+100-size//2), icon)
            draw.text((x+192+j*90, y+145), str(size)+' px', font=small, fill='#c1cbd4')
        draw.text((x+16, y+220), 'ADD / night     cave           snow           sky             sand', font=small, fill='#c1cbd4')
        icon = np.asarray(images[name]).astype(np.float64)
        for j, (_, _, colour) in enumerate(SURFACES):
            bg = np.array(tuple(bytes.fromhex(colour[1:])), dtype=np.float64)
            rgb = np.rint(np.minimum(255, bg + icon[:, :, :3]*icon[:, :, 3:4]/255)).astype(np.uint8)
            sheet.paste(Image.fromarray(rgb), (x+18+j*102, y+242))
    return sheet


def build():
    images = dict(zip((c[0] for c in CANDIDATES), (hammer_c(), hammer_d(), book_e(), book_f())))
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
    template = template.replace('@@HAMMERS@@', ''.join(card(c) for c in CANDIDATES[:2]))
    template = template.replace('@@BOOKS@@', ''.join(card(c) for c in CANDIDATES[2:]))
    template = template.replace('@@CONTEXT@@', ''.join(context(h, b) for h in ('c', 'd') for b in ('e', 'f')))
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
    print(('Checked' if args.check else 'Wrote')+f' {len(outputs)} files: four 64x64 RGBA candidates, preview copies, page and contact sheet.')


if __name__ == '__main__':
    main()

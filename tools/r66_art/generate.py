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
    ("smite_hammer_a", "Hammer A", "Square mallet", "A broad, flat striking head and a straight handle make the smallest hit unmistakable."),
    ("smite_hammer_b", "Hammer B", "Stepped hammer", "Raised end caps and a shorter grip give the descending hammer a more ceremonial silhouette."),
    ("censure_book_c", "Book C", "Open folio", "A broad, flat spread faces the viewer, with two quiet ivory pages and a clear central fold."),
    ("censure_book_d", "Book D", "Lifted pages", "Two gently bowed pages rise symmetrically from the spine, giving the open book a taller silhouette."),
)
# Hammer B remains reproducible as pass-1 provenance, outside the active choice.
DISPLAYED = (CANDIDATES[0], *CANDIDATES[2:])


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


def hammer_a():
    d = Drawing()
    d.polygon([(29, 9), (35, 9), (37, 12), (35, 16), (35, 38), (29, 38), (29, 16), (27, 12)], GOLD)
    d.polygon([(30, 12), (33, 12), (33, 38), (30, 38)], WHITE)
    d.polygon([(27, 31), (37, 31), (37, 37), (27, 37)], IVORY)
    d.polygon([(12, 36), (16, 33), (48, 33), (52, 36), (52, 49), (48, 53), (16, 53), (12, 49)], GOLD)
    d.polygon([(16, 37), (48, 37), (48, 49), (16, 49)], IVORY)
    d.polygon([(16, 33), (48, 33), (48, 37), (16, 37)], WHITE)
    d.line([(16, 50), (48, 50)], WHITE, 2)
    d.line([(14, 37), (14, 47)], WHITE, 1.5)
    d.line([(50, 37), (50, 47)], WHITE, 1.5)
    return d.finish()


def hammer_b():
    d = Drawing()
    d.polygon([(28, 10), (36, 10), (38, 14), (35, 17), (35, 35), (29, 35), (29, 17), (26, 14)], GOLD)
    d.line([(31, 13), (31, 34)], WHITE, 3)
    d.polygon([(26, 29), (38, 29), (40, 36), (24, 36)], IVORY)
    d.polygon([(10, 34), (19, 34), (19, 38), (45, 38), (45, 34), (54, 34), (54, 49), (48, 54), (16, 54), (10, 49)], GOLD)
    d.polygon([(20, 39), (44, 39), (44, 48), (20, 48)], WHITE)
    d.polygon([(12, 35), (17, 35), (17, 50), (14, 48), (12, 48)], IVORY)
    d.polygon([(47, 35), (52, 35), (52, 48), (49, 50), (47, 50)], IVORY)
    d.line([(19, 51), (45, 51)], WHITE, 2)
    return d.finish()


def finish_book(d):
    """Mirror authored left-page geometry about the exact centre of the sprite."""
    half = d.image.crop((0, 0, SIZE*SCALE//2, SIZE*SCALE))
    d.image.paste(ImageOps.mirror(half), (SIZE*SCALE//2, 0))
    return d.finish()


def book_c():
    d = Drawing()
    # Frontal spread: level outer edges, a shallow V at the central binding.
    d.polygon([(7, 16), (20, 16), (30, 20), (30, 48), (32, 50),
               (32, 52), (20, 48), (7, 48)], GOLD)
    d.polygon([(9, 15), (20, 15), (30, 19), (30, 47), (20, 44), (9, 44)], IVORY)
    d.line([(10, 16), (20, 16), (28.5, 19.5)], WHITE, 1.5)
    d.line([(10, 17), (10, 43)], WHITE, 1.5)
    d.line([(10, 46), (20, 46), (29, 49)], WHITE, 1)
    # The transparent gutter defines the spine even when additive tones saturate.
    # Blank pages: no lettering or small marks competing with the silhouette.
    return finish_book(d)


def book_d():
    d = Drawing()
    # Taller curved spread, still frontal: both leaves lift by the same amount.
    d.polygon([(7, 17), (16, 14), (24, 16), (30, 21), (30, 49),
               (32, 51), (32, 54), (24, 50), (15, 48), (7, 50)], GOLD)
    d.polygon([(8, 16), (15, 13), (22, 14), (27, 17), (30, 21),
               (30, 50), (26, 47), (22, 45), (15, 44), (8, 47)], IVORY)
    d.polygon([(9, 13), (15, 10), (22, 11), (27, 14), (30, 18),
               (30, 47), (27, 44), (22, 41), (15, 40), (9, 43)], WHITE)
    d.line([(9, 48), (15, 46), (22, 47), (28, 50)], WHITE, 1)
    return finish_book(d)


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
    badge = ' · Picked' if name == 'smite_hammer_a' else ' · Recommended' if name == 'censure_book_c' else ''
    rows = ''.join(f'<div class="surface-row"><div class="surface-label">{label_bg}</div>'
                   f'<div class="surface {key}">{samples(name, "plain")}</div>'
                   f'<div class="surface {key}">{samples(name, "add")}</div></div>'
                   for key, label_bg, _ in SURFACES)
    return f"""<article class="candidate{' picked-card' if name == 'smite_hammer_a' else ''}" id="{name}">
    <header class="candidate-head"><div class="hero-sprite add">{img(name, 128)}</div>
    <div><p class="eyebrow">{label}{badge}</p>
    <h3>{title}</h3><p>{idea}</p></div></header>
    <div class="views"><div class="table-head"><span>Ground</span><span>Plain alpha</span><span>Additive light</span></div>
    {rows}</div></article>"""


def figure():
    return '<div class="figure" aria-label="Schematic figure, one node wide and two nodes tall"><i class="head"></i><i class="body"></i><i class="arms"></i><i class="legs"></i></div>'


def context(variant):
    # Reuse the established catalogue preview scale: size * 0.1 node.
    # tools/r52_pfx/template.html uses the same conversion. One node = 64 CSS px.
    cells = []
    for title, name, units, note in (
        ('Smite', 'smite_hammer_a', 5, '3.2 m fall · about 0.15 s'),
        ('Final Word', 'smite_hammer_a', 12, 'Same hammer · white column'),
        ('Censure', f'censure_book_{variant}', 16, '6 m fall · 0.75 s warning'),
    ):
        side = units * 0.1 * 64
        sprite = img(name, SIZE, f'style="width:{side:g}px;height:{side:g}px"')
        cells.append(f'<div class="scale-cell"><h4>{title}</h4><p>{note}</p>'
                     f'<div class="scene"><div class="symbol add">{sprite}</div>{figure()}'
                     '<div class="ruler">1 node</div></div>'
                     f'<p class="size-note">Size {units} · sprite square {units/10:g} nodes</p></div>')
    return f'<article class="context-card"><h3>Picked Hammer A + Book {variant.upper()}{" · recommended" if variant == "c" else " · alternative"}</h3><div class="scale-strip">'+''.join(cells)+'</div></article>'


def overview(images):
    """A static contact sheet for inspection without a browser."""
    sheet = Image.new("RGB", (1120, 750), '#111a24')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=13)
    draw.text((28, 22), 'ROUND 66 / PASS 2     Picked: Hammer A     Recommended: Book C', font=font, fill='#f8ead1')
    draw.text((600, 100), 'CENSURE / AN OPEN BOOK', font=font, fill='#f8ead1')
    for j, line in enumerate(('Two symmetric spreads, facing the viewer.',
                              'C / Broad and flat. Recommended at 16 px.',
                              'D / Taller, with gently lifted pages.',
                              'Blank ivory pages, a clear central spine.',
                              'Hammer A stays byte-identical to pass 1.')):
        draw.text((600, 145+j*30), line, font=small, fill='#c1cbd4')
    for i, (name, label, title, _) in zip((0, 2, 3), DISPLAYED):
        x, y = 24 + (i % 2)*552, 66 + (i//2)*338
        draw.rectangle((x, y, x+528, y+318), fill='#1e2a36')
        badge = ' / PICKED' if i == 0 else ' / RECOMMENDED' if i == 2 else ''
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
    images = dict(zip((c[0] for c in CANDIDATES), (hammer_a(), hammer_b(), book_c(), book_d())))
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
    template = template.replace('@@HAMMERS@@', card(CANDIDATES[0]))
    template = template.replace('@@BOOKS@@', ''.join(card(c) for c in CANDIDATES[2:]))
    template = template.replace('@@CONTEXT@@', context('c')+context('d'))
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

"""Build the art sources, the three PNG plates and the standalone pick page.

From the repository root: python3 -B tools/r86_stone_art/build.py
Dependencies: Python 3 and Pillow 10.1+ (scalable built-in font on PNG plates).
"""

import base64
import io
import json
from html import escape
from PIL import Image, ImageDraw, ImageFont

from paint import KINDS, ROOT, STATES, export
from render import studies
from stones import TITLES

INK = "#223b33"
MUTED = "#566659"
SLOT = "#1b2429"  # Native #111a24b0 over the same #303933 backing as the page.
HOUSE = "Mara’s Home"
COPY = {
    "roof": ("One gable / two gables", "#425952",
             "A lamp in the window is the first thing you look for when you come home. "
             "One terracotta gable shelters the personal doorway. Two slate gables share a "
             "continuous threshold on the account stone. When the coal runs out, the shutters close."),
    "lights": ("One candle / three candles", "#504944",
               "Leave a candle burning for whoever comes in last. One beeswax pillar stands "
               "in an ochre stone holder. Three ivory candles of different heights gather "
               "on the account stone’s blue saucer. Spent candles keep their black wicks."),
    "pear": ("One bough / two boughs", "#555946",
             "A garden can carry a family’s history as plainly as a hall. One golden pear "
             "hangs above the ochre planter. The account carving forks from a common trunk "
             "into two fruiting boughs above blue stone. Without fuel, both trees stand bare."),
}
PICK = ("I’d choose Under One Roof. The lit doorway reads as home at 16 px, "
        "and the two gables still identify the account stone after the shutters close.")


def png_bytes(im):
    data = io.BytesIO()
    im.save(data, format="PNG")
    return data.getvalue()


def uri(data):
    return "data:image/png;base64," + base64.b64encode(data).decode("ascii")


def img(im, alt, size=None, cls="icon"):
    width, height = (size, size) if size else im.size
    return (f'<img class="{cls}" src="{uri(png_bytes(im))}" '
            f'alt="{escape(alt, quote=True)}" width="{width}" height="{height}">')


def paste_icon(sheet, im, xy, size):
    if size != im.width:
        im = im.resize((size, size), Image.Resampling.NEAREST)
    sheet.paste(im, xy, im)


def sheet(design, scenes, icons, marker, house, technical):
    """A shareable plate with full-scale preview pixels, including the type samples."""
    out = Image.new("RGB", (1280, 886), "#f6f3e9")
    draw = ImageDraw.Draw(out)
    fonts = {n: ImageFont.load_default(size=n) for n in (14, 16, 18, 21, 39)}

    def label(x, y, words, size=16, fill=INK):
        draw.text((x, y), words, font=fonts[size], fill=fill, anchor="lt")

    draw.rectangle((0, 0, 1279, 96), fill=INK)
    paste_icon(out, house, (28, 15), 16)
    label(52, 16, "GRUDGELANDS   /   ROUND 86 HOUSING", 14, "#c7d2bf")
    label(27, 43, TITLES[design], 39, "#fff7e2")
    label(815, 56, COPY[design][0], 21, "#f6e2ae")
    label(22, 115, "Claim Stone", 16)
    for col, (state, desc) in enumerate(zip(STATES, ("Unfinished", "Fuelled", "Out of fuel"))):
        x = 118 + col * 385
        label(x + 8, 113, state.title(), 21)
        label(x + 86, 118, desc, 14, MUTED)
        for row, kind in enumerate(KINDS):
            y = 150 + row * 247
            out.paste(scenes[kind, state], (x, y))
            if col == 0:
                label(18, y + 109, kind.title(), 18)
    label(22, 655, "The plain stone cube is one full node. All views use the same daylight and scale.", 16, MUTED)
    draw.line((22, 687, 1258, 687), fill="#bcbdaf")
    label(24, 704, "Hand and inventory", 21)
    label(393, 704, "Stone waypoint", 21)
    label(678, 704, "Home-name icon", 21)
    label(24, 735, "Active item on the inventory slot", 14, MUTED)
    label(393, 735, "Personal front tile", 14, MUTED)
    label(678, 735, "Dark and light ground", 14, MUTED)
    for row, kind in enumerate(KINDS):
        y = 759 + row * 42
        label(24, y + 10, kind.title(), 16)
        for x, px in [(135, 32), (236, 16)]:
            draw.rectangle((x, y, x + 42, y + 37), fill=SLOT)
            paste_icon(out, icons[kind], (x + (42 - px) // 2, y + (38 - px) // 2), px)
            label(x + 48, y + 11, f"{px} px", 14, MUTED)
    for i, px in enumerate((32, 16)):
        x = 393 + i * 101
        draw.rectangle((x, 759, x + 47, 797), fill="#71816a")
        paste_icon(out, marker, (x + (48 - px) // 2, 759 + (38 - px) // 2), px)
        label(x + 52, 772, f"{px} px", 14, MUTED)
    for row, px in enumerate((32, 16)):
        y = 759 + row * 42
        for col, (bg, fg) in enumerate((("#263a36", "#fbf1d7"), ("#e4dfcf", "#37392e"))):
            x = 678 + col * 215
            draw.rectangle((x, y, x + 208, y + 37), fill=bg)
            paste_icon(out, house, (x + (42 - px) // 2, y + (38 - px) // 2), px)
            label(x + 48, y + 10, HOUSE, 18, fg)
        label(1118, y + 11, f"{px} px", 14, MUTED)
    label(24, 858, technical, 14, MUTED)
    return out


def samples(icons, marker, house):
    items = []
    for kind in KINDS:
        slots = "".join(f'<span class="chip slot">{img(icons[kind], f"{kind} stone at {px} px", px)}</span>'
                        for px in (32, 16))
        items.append(f'<div class="slot-row"><span>{kind.title()}</span>{slots}</div>')
    maps = "".join(f'<span class="chip map">{img(marker, f"Personal face at {px} px", px)}</span>'
                   for px in (32, 16))
    lines = []
    for px in (32, 16):
        grounds = "".join(f'<span class="example {bg}">{img(house, "", px)}{HOUSE}</span>'
                          for bg in ("dark", "light"))
        lines.append(f'<div class="sample-row">{grounds}<small>{px} px</small></div>')
    return f'''
<div class="samples">
 <div class="group"><h3>Hand and inventory</h3><p>32 px and 16 px · active item</p>{"".join(items)}</div>
 <div class="group"><h3>Stone waypoint</h3><p>32 px and 16 px · personal front tile</p><div class="sample-row">{maps}</div></div>
 <div class="group"><h3>Home-name icon</h3><p>House and doorway in ochre</p>{"".join(lines)}</div>
</div>'''


def build():
    export()
    renders = ROOT / "renders"
    renders.mkdir(exist_ok=True)
    house = Image.open(ROOT / "art/home_name.png").convert("RGBA")
    cards, sections = [], []
    for design, title in TITLES.items():
        subtitle, background, story = COPY[design]
        scenes, subjects, icons, marker = studies(design)
        nodes = json.loads((ROOT / "art" / design / "nodes.json").read_text())["variants"]
        face_count = len({tile for states in nodes.values() for state in ("active", "empty")
                          for tile in states[state]["tiles"]})
        counts = [len(nodes[k]["active"]["boxes"]) for k in KINDS]
        technical = (f"Personal and account carvings use {counts[0]} and {counts[1]} fixed boxes "
                     f"when active. Both variants and all states share {face_count} distinct 16 px face tiles.")
        plate = png_bytes(sheet(design, scenes, icons, marker, house, technical))
        (renders / f"{design}.png").write_bytes(plate)
        subjects_html = "".join(img(subjects[k], f"{k.title()} {title}", cls="subject") for k in KINDS)
        cards.append(f'''
<a class="pick" href="#{design}"><div class="pair" style="--back:{background}">{subjects_html}</div>
 <div class="pick-foot"><div><strong>{title}</strong><small>{subtitle}</small></div><span aria-hidden="true">↓</span></div></a>''')
        cells = []
        for kind in KINDS:
            for order, state in enumerate(STATES):
                alt = f"{kind.title()} {title}, {state}, beside a one-node stone cube"
                cells.append(f'<figure style="--state:{order}">{img(scenes[kind,state], alt, cls="world")}'
                             f'<figcaption><b>{kind.title()}</b><small>{state.title()}</small></figcaption></figure>')
        sections.append(f'''
<section class="study" id="{design}" aria-labelledby="{design}-title">
 <div class="study-head"><h2 id="{design}-title">{title}</h2><a class="download" download="{design}.png" href="{uri(plate)}">Download study PNG ↓</a></div>
 <p class="story">{story}</p>
 <div class="stones">{"".join(cells)}</div>
{samples(icons, marker, house)}
 <p class="tech">{technical}</p>
</section>''')
    css = (ROOT / "gallery.css").read_text()
    page = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Claim Stone studies · Grudgelands</title><style>{css}</style></head>
<body id="top"><header><div class="bar-inner"><div class="wordmark">{img(house, "", 24)}Grudgelands</div><span class="round">Housing · Round 86</span></div></header>
<main><div class="intro"><h1>A stone to come home to</h1>
<p>Three Claim Stone designs. Each pair shows a personal home on the left and a shared account home on the right.</p></div>
<nav aria-label="Choose a study">{"".join(cards)}</nav>
<p class="rec"><strong>Artist’s pick.</strong> {PICK}</p>
<p class="tech">Each grey cube below is one full node. The daylight studies use the placed draft’s 150/255 opacity. Light levels are 2 for draft, 4 for active and 0 for empty.</p>
{"".join(sections)}
<footer><span>Claim Stone studies · Original artwork for Grudgelands · CC0 1.0</span><a href="#top">Back to the three designs ↑</a></footer>
</main></body></html>'''
    (ROOT / "index.html").write_text(page + "\n")
    print("Built three PNG plates and index.html")


if __name__ == "__main__":
    build()

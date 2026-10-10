#!/usr/bin/env python3
"""Release 0.45.1 TX: original, AI-assisted pixel art, CC0-1.0.

Authored by GPT-6 Astra at native integer coordinates using Python/Pillow.
No downloads, source images, external fonts, image service or randomness.
The hand-drawn preview lettering and backdrops are also original.
Run from anywhere; writes only this directory. --check writes nothing.
"""

import argparse
import html
import io
import json
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
NEAREST = Image.Resampling.NEAREST
CLEAR = (0, 0, 0, 0)
SIZE = (24, 24)
BOX_SIZE = (232, 44)
# gui_formbg.png's flat interior, not the fullscreen dimmer or inner boxes.
BOX_RGBA = (52, 52, 52, 77)  # #3434344D; 77/255 = 30.20% opacity.
KEYS = ("weaponsmith", "armorsmith", "alchemist", "tailor", "leatherworker",
        "woodcarver", "goldsmith", "mender")
NAMES = ("Weaponsmith", "Armorsmith", "Alchemy", "Tailor", "Leatherworker",
         "Woodcarver", "Goldsmith", "Grudge-Free Repairs")
VOICES = {"A": "Warm and proud", "B": "Brisk and practical", "C": "Playful"}
TAKES = {
    "A": ("Golden eighth note", "A single curled flag and a warm gold face: the clearest, simplest silhouette."),
    "B": ("Silver beamed pair", "Two ivory-silver notes on a rising beam: a wider, rhythmic silhouette."),
    "C": ("Lute and note", "A honey-wood lute beside a small gold note: a travelling musician's touch."),
}

# Original 5 x 7 lettering. Lowercase glyphs used by the track/artist sample
# have a five-pixel x-height. At 2x, glyphs are 14 px high on an 18 px pitch.
# This is a preview stand-in for the client's configurable HUD font.
FONT = {
    "A": "01110/10001/10001/11111/10001/10001/10001",
    "B": "11110/10001/10001/11110/10001/10001/11110",
    "C": "01111/10000/10000/10000/10000/10000/01111",
    "D": "11110/10001/10001/10001/10001/10001/11110",
    "E": "11111/10000/10000/11110/10000/10000/11111",
    "F": "11111/10000/10000/11110/10000/10000/10000",
    "G": "01111/10000/10000/10111/10001/10001/01111",
    "H": "10001/10001/10001/11111/10001/10001/10001",
    "I": "111/010/010/010/010/010/111",
    "J": "00111/00010/00010/00010/10010/10010/01100",
    "K": "10001/10010/10100/11000/10100/10010/10001",
    "L": "10000/10000/10000/10000/10000/10000/11111",
    "M": "10001/11011/10101/10101/10001/10001/10001",
    "N": "10001/11001/10101/10011/10001/10001/10001",
    "O": "01110/10001/10001/10001/10001/10001/01110",
    "P": "11110/10001/10001/11110/10000/10000/10000",
    "Q": "01110/10001/10001/10001/10101/10010/01101",
    "R": "11110/10001/10001/11110/10100/10010/10001",
    "S": "01111/10000/10000/01110/00001/00001/11110",
    "T": "11111/00100/00100/00100/00100/00100/00100",
    "U": "10001/10001/10001/10001/10001/10001/01110",
    "V": "10001/10001/10001/10001/10001/01010/00100",
    "W": "10001/10001/10001/10101/10101/10101/01010",
    "X": "10001/10001/01010/00100/01010/10001/10001",
    "Y": "10001/10001/01010/00100/00100/00100/00100",
    "Z": "11111/00001/00010/00100/01000/10000/11111",
    "0": "01110/10001/10011/10101/11001/10001/01110",
    "1": "010/110/010/010/010/010/111",
    "2": "01110/10001/00001/00010/00100/01000/11111",
    "3": "11110/00001/00001/01110/00001/00001/11110",
    "4": "00010/00110/01010/10010/11111/00010/00010",
    "5": "11111/10000/10000/11110/00001/00001/11110",
    "6": "01110/10000/10000/11110/10001/10001/01110",
    "7": "11111/00001/00010/00100/01000/01000/01000",
    "8": "01110/10001/10001/01110/10001/10001/01110",
    "9": "01110/10001/10001/01111/00001/00001/01110",
    "a": "00000/00000/01110/00001/01111/10001/01111",
    "b": "10000/10000/10110/11001/10001/10001/11110",
    "c": "00000/00000/01110/10000/10000/10000/01110",
    "e": "00000/00000/01110/10001/11111/10000/01110",
    "i": "1/0/1/1/1/1/1",
    "k": "1000/1000/1001/1010/1100/1010/1001",
    "l": "10/10/10/10/10/10/01",
    "o": "00000/00000/01110/10001/10001/10001/01110",
    "s": "00000/00000/01111/10000/01110/00001/11110",
    "t": "010/010/111/010/010/010/001",
    "u": "00000/00000/10001/10001/10001/10011/01101",
    "y": "00000/00000/10001/10001/01111/00001/01110",
    " ": "000/000/000/000/000/000/000",
    ".": "0/0/0/0/0/0/1",
    ":": "0/1/1/0/1/1/0",
    "-": "000/000/000/111/000/000/000",
    "/": "00001/00001/00010/00100/01000/10000/10000",
    "%": "11001/11010/00010/00100/01000/01011/10011",
}


def lettering(image, xy, value, fill="#f5e9ce", scale=2):
    draw = ImageDraw.Draw(image)
    x, y = xy
    for character in value:
        rows = FONT[character].split("/")
        for row, pixels in enumerate(rows):
            for col, bit in enumerate(pixels):
                if bit == "1":
                    px, py = x + col * scale, y + row * scale
                    draw.rectangle((px, py, px + scale - 1, py + scale - 1), fill=fill)
        x += (len(rows[0]) + 1) * scale
    return x


def outlined(image):
    """A single opaque pixel of ink; no smoothing or background matte."""
    alpha = image.getchannel("A").filter(ImageFilter.MaxFilter(3))
    result = Image.new("RGBA", image.size, CLEAR)
    result.paste(ImageColor.getcolor("#241e1c", "RGBA"), mask=alpha)
    result.alpha_composite(image)
    return result


def note(variant):
    im = Image.new("RGBA", SIZE, CLEAR)
    d = ImageDraw.Draw(im)
    if variant == "A":
        # Eighth note: generous oval head, upright stem and curled flag.
        d.polygon([(11, 3), (13, 3), (14, 5), (17, 6), (19, 8), (19, 11),
                   (17, 13), (16, 13), (17, 10), (16, 9), (13, 8),
                   (13, 18), (11, 19)], fill="#e6b64d")
        d.polygon([(5, 17), (8, 15), (12, 15), (13, 16), (13, 19),
                   (10, 21), (5, 21), (4, 20), (4, 18)], fill="#e6b64d")
        d.line((11, 4, 11, 16), fill="#ffe5ab")
        d.line((5, 18, 8, 16), fill="#ffe5ab")
        d.line((8, 16, 10, 16), fill="#ffe5ab")
        d.line((5, 21, 9, 21), fill="#ae7244")
        d.line((12, 19, 10, 20), fill="#ae7244")
        d.line((14, 6, 17, 7), fill="#ffe5ab")
        d.line((18, 9, 18, 11), fill="#ae7244")
    elif variant == "B":
        # Two connected eighth notes, lifted at the right for a rising beat.
        d.polygon([(8, 5), (20, 2), (20, 5), (8, 8)], fill="#d6e7e3")
        d.rectangle((8, 6, 9, 19), fill="#d6e7e3")
        d.rectangle((19, 4, 20, 16), fill="#d6e7e3")
        for x, y in ((3, 18), (14, 15)):
            d.polygon([(x, y), (x + 2, y - 1), (x + 5, y - 1),
                       (x + 6, y), (x + 6, y + 2), (x + 4, y + 3),
                       (x + 1, y + 3), (x, y + 2)], fill="#d6e7e3")
            d.line((x + 1, y, x + 4, y - 1), fill="#fff0c1")
            d.line((x + 1, y + 3, x + 4, y + 3), fill="#738f96")
        d.line((8, 5, 20, 2), fill="#fff0c1")
        d.line((9, 9, 9, 16), fill="#738f96")
        d.line((20, 7, 20, 13), fill="#738f96")
    else:
        # A small pear-shaped lute: angled neck, pegbox, strings and bridge.
        d.polygon([(11, 9), (14, 4), (16, 3), (17, 5), (13, 11)], fill="#ae7244")
        d.line((12, 9, 15, 4), fill="#ffe5ab")
        d.point((13, 4), fill="#e6b64d")
        d.point((17, 4), fill="#e6b64d")
        d.polygon([(9, 9), (12, 9), (15, 12), (15, 16), (13, 19),
                   (10, 21), (6, 21), (3, 19), (2, 16), (3, 13),
                   (6, 11)], fill="#ae7244")
        d.polygon([(8, 11), (11, 10), (13, 12), (14, 15), (12, 18),
                   (9, 20), (6, 20), (4, 18), (3, 15), (5, 13)], fill="#e6b64d")
        d.line((4, 14, 6, 12), fill="#ffe5ab")
        d.line((4, 16, 4, 17), fill="#ffe5ab")
        d.rectangle((9, 12, 11, 14), fill="#604331")
        d.line((12, 9, 7, 18), fill="#ffe5ab")
        d.line((11, 10, 6, 18), fill="#d7bd8a")
        d.line((5, 17, 8, 19), fill="#604331")
        # Separate tiny quaver keeps the music meaning explicit at HUD size.
        d.rectangle((20, 10, 20, 16), fill="#ffe5ab")
        d.line((21, 11, 21, 12), fill="#e6b64d")
        d.polygon([(18, 16), (20, 15), (20, 17), (18, 18), (17, 17)], fill="#e6b64d")
        d.point((18, 16), fill="#ffe5ab")
    return outlined(im)


def backdrop(kind, size):
    """Original pixel studies, not screenshots or imported game textures."""
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    if kind == "BRIGHT SKY":
        for y in range(h):
            t = (y // 6 * 6) / h
            color = tuple(round(a + (b - a) * t) for a, b in
                          zip((133, 192, 226), (224, 239, 232))) + (255,)
            d.line((0, y, w, y), fill=color)
        d.rectangle((18, 9, 96, 18), fill="#f9f9e8")
        d.rectangle((31, 5, 78, 22), fill="#f9f9e8")
        d.rectangle((154, 29, 225, 36), fill="#f9f9e8")
        d.rectangle((171, 24, 202, 38), fill="#f9f9e8")
    elif kind == "GRASSLAND":
        d.rectangle((0, 0, w, h), fill="#668546")
        for y in range(0, h, 8):
            for x in range(0, w, 11):
                offset = (x * 7 + y * 3) % 5
                color = ("#8eaa60", "#77974d", "#536f3e")[(x + y) % 3]
                d.rectangle((x, y + offset, x + 6, y + offset + 2), fill=color)
                d.line((x + 8, y + 6, x + 9, y + 3), fill="#a9b773")
    else:
        d.rectangle((0, 0, w, h), fill="#171e23")
        for row, y in enumerate(range(-10, h, 17)):
            for x in range(-20, w, 31):
                sx = x + (row % 2) * 12
                d.polygon([(sx + 2, y + 3), (sx + 25, y), (sx + 29, y + 11),
                           (sx + 19, y + 16), (sx, y + 14)], fill="#252d32")
                d.line((sx + 2, y + 3, sx + 22, y + 1), fill="#374046")
    return im


def hud(icon, kind):
    scene = backdrop(kind, (252, 56))
    box = Image.new("RGBA", BOX_SIZE, BOX_RGBA)
    box.alpha_composite(icon, (8, 10))
    for value, y in (("Katabasis I", 6), ("Scott Buckley", 24)):
        lettering(box, (43, y + 1), value, "#171411")
        right = lettering(box, (42, y), value, "#f5f1e8")
        assert right < BOX_SIZE[0] - 8, "Track sample overflows its box"
    scene.alpha_composite(box, (10, 6))
    return scene


def preview(icon, variant):
    sheet = Image.new("RGBA", (1072, 1216), "#181d21")
    lettering(sheet, (32, 24), f"{variant} - {TAKES[variant][0].upper()}")
    lettering(sheet, (32, 53), "24 X 24 PIXELS / 30% INVENTORY GREY", "#aebcbf", 1)
    for i, kind in enumerate(("BRIGHT SKY", "GRASSLAND", "DARK CAVE")):
        y = 96 + i * 360
        lettering(sheet, (32, y), kind, "#e6b64d")
        composed = hud(icon, kind)
        sheet.alpha_composite(composed, (32, y + 26))
        lettering(sheet, (304, y + 34), "HUD 1X", "#aebcbf", 1)
        sheet.alpha_composite(composed.resize((1008, 224), NEAREST), (32, y + 98))
        lettering(sheet, (32, y + 332), "4X NEAREST-NEIGHBOUR", "#aebcbf", 1)
    lettering(sheet, (32, 1189), "ORIGINAL BACKDROP STUDIES / HUD FONT IS ILLUSTRATIVE", "#aebcbf", 1)
    return sheet


def review_page(greetings):
    cards = []
    for key, name in zip(KEYS, NAMES):
        choices = []
        for variant, voice in VOICES.items():
            text = greetings[key][variant]
            choices.append(f'''<label class="choice"><span class="choice-top">
<input type="radio" name="{key}" value="{variant}"><b>{variant} · {voice}</b>
<small>{len(text)} characters</small></span><span class="greeting">{html.escape(text)}</span></label>''')
        cards.append(f'<fieldset><legend>{name}</legend><div class="choices">{"".join(choices)}</div></fieldset>')
    icons = []
    for variant, (name, description) in TAKES.items():
        icons.append(f'''<div class="icon-column"><label class="choice icon-choice"><span class="choice-top">
<input type="radio" name="note" value="{variant}"><b>{variant} · {name}</b></span>
<span class="icon-samples"><img width="24" height="24" src="note/{variant}/grug_ambience_note.png" alt="{name} at HUD size">
<img width="96" height="96" src="note/{variant}/grug_ambience_note.png" alt="{name} at four times HUD size"></span>
<span>{description}</span></label>
<details><summary>Preview {variant}: sky, grassland and cave</summary>
<a href="note/{variant}/preview.png"><img class="sheet" src="note/{variant}/preview.png" alt="{name} over all three backgrounds, HUD size and 4x"></a></details></div>''')
    # Inline data is generated from the one greeting source; no fetch/server.
    data = json.dumps(greetings, ensure_ascii=True).replace("<", "\\u003c")
    return PAGE.replace("__TEXT_CARDS__", "\n".join(cards)).replace(
        "__ICON_CARDS__", "\n".join(icons)).replace("__GREETINGS__", data)


PAGE = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Grudgelands · 0.45.1 TX choices</title>
<style>
:root{color-scheme:dark;font:16px/1.55 system-ui,sans-serif;background:#181d21;color:#f5f1e8}
*{box-sizing:border-box}body{max-width:1160px;margin:auto;padding:32px 24px 80px}
h1,h2,legend{font-weight:650;line-height:1.25}h1{font-size:36px;margin:12px 0}
h2{margin-top:48px;font-size:25px}a{color:#ffe5ab}.eyebrow{color:#e6b64d;letter-spacing:.12em;font-size:12px}
.intro{max-width:760px;color:#bfc8c9}.controls{display:flex;flex-wrap:wrap;gap:10px;margin:22px 0}
button{font:inherit;border:1px solid #776044;border-radius:5px;background:#302b26;color:#ffe5ab;padding:9px 14px;cursor:pointer}
button:hover{background:#493b2a}button:disabled{opacity:.5;cursor:default}
button:focus-visible,input:focus-visible,summary:focus-visible{outline:3px solid #e6b64d;outline-offset:4px}
fieldset{border:0;padding:0;margin:28px 0}legend{font-size:19px;margin-bottom:12px}
.choices{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
.choice{display:block;background:#22282c;border:1px solid #41474a;border-radius:6px;padding:16px;cursor:pointer}
.choice:has(input:checked){border-color:#e6b64d;background:#352f25;box-shadow:inset 0 0 0 1px #e6b64d}
.choice-top{display:flex;flex-wrap:wrap;align-items:center;gap:8px;font-size:13px;color:#ffe5ab}
input{accent-color:#e6b64d;margin:0}small{color:#aeb8b9;font-size:11px}.greeting{display:block;margin-top:14px;font-size:15px}
.icons{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;align-items:start}
.icon-column{min-width:0}.icon-samples{display:flex;align-items:center;justify-content:center;gap:36px;min-height:140px}
img{image-rendering:pixelated}.icon-choice>span:last-child{display:block;min-height:76px;font-size:14px;color:#c4cccc}
details{margin:12px 0}summary{cursor:pointer;color:#ffe5ab}.sheet{display:block;width:100%;height:auto;margin-top:16px}
.handover{padding:24px;background:#22282c;border:1px solid #41474a;border-radius:6px}
textarea{width:100%;height:250px;resize:vertical;background:#151a1d;color:#e2e6e5;border:1px solid #41474a;padding:14px;font:13px/1.7 ui-monospace,monospace}
.status{color:#c2cccd;font-size:14px}footer{margin-top:36px;color:#9caaad;font-size:13px}
@media(max-width:800px){.choices,.icons{grid-template-columns:1fr}body{padding:22px 16px 50px}h1{font-size:29px}}
</style>
<header><div class="eyebrow">GRUDGELANDS / RELEASE 0.45.1 / LANE TX</div>
<h1>A welcome and a little music</h1>
<p class="intro">Choose a greeting for each trainer and an icon for the music HUD. A is warm and proud, B is brisk and practical, C is playful. You can choose one voice for all greetings or mix individual favourites.</p></header>
<main><h2>Trainer greetings</h2>
<div class="controls" aria-label="Choose a voice for all greetings">
<button type="button" data-voice="A">All A · Warm and proud</button>
<button type="button" data-voice="B">All B · Brisk and practical</button>
<button type="button" data-voice="C">All C · Playful</button></div>
__TEXT_CARDS__
<h2>Music-note icon</h2>
<p class="intro">Each icon is 24 × 24 pixels with a transparent background. Samples below show 1× and 4×. Open a preview to compare the HUD over bright sky, grassland and a dark cave; click its sheet to inspect it at full size.</p>
<div class="icons" id="icons">__ICON_CARDS__</div>
<p class="intro">Preview boxes use the inventory's #343434 at 77/255 alpha (30.2%). Both text lines use the same illustrative font size. The backdrops are original studies, not engine screenshots; actual HUD text follows client settings.</p>
<h2>Your selections</h2><div class="handover">
<p id="status" class="status" aria-live="polite">0 of 9 choices made.</p>
<textarea id="summary" readonly aria-label="Selection summary for the coordinator"></textarea>
<div class="controls"><button id="download" type="button" disabled>Download selections.json</button>
<button id="reset" type="button">Clear choices</button></div>
<p class="status">Send the downloaded file to the coordinator, or copy the summary above. Choices remain in this tab until you reload or close it. Downloading does not install anything.</p></div></main>
<footer>Original, AI-assisted icons by GPT-6 Astra · CC0 1.0 · <a href="README.md">Provenance and handover</a> · <a href="greetings.json">Greeting source</a></footer>
<script>
"use strict";
const greetings = __GREETINGS__;
const keys = Object.keys(greetings);
const choices = [...keys, "note"];
function selection() {
  return Object.fromEntries(choices.map(key => [key,
    document.querySelector(`input[name="${key}"]:checked`)?.value ?? null]));
}
function update() {
  const picked = selection();
  const count = Object.values(picked).filter(Boolean).length;
  document.getElementById("status").textContent = `${count} of 9 choices made.`;
  document.getElementById("download").disabled = count !== 9;
  document.getElementById("summary").value = choices.map(key => {
    const value = picked[key];
    if (!value) return `${key}: pending`;
    return key === "note" ? `note: ${value}\n  note/${value}/grug_ambience_note.png`
      : `${key}: ${value}\n  ${greetings[key][value]}`;
  }).join("\n\n");
}
document.addEventListener("change", update);
for (const button of document.querySelectorAll("[data-voice]")) {
  button.addEventListener("click", () => {
    for (const key of keys) document.querySelector(`input[name="${key}"][value="${button.dataset.voice}"]`).checked = true;
    update();
  });
}
document.getElementById("reset").addEventListener("click", () => {
  for (const input of document.querySelectorAll("input")) input.checked = false;
  update();
});
document.getElementById("download").addEventListener("click", () => {
  const picked = selection();
  if (Object.values(picked).some(value => value === null)) return;
  const result = {release: "0.45.1", lane: "TX", greetings: {}, note: {variant: picked.note,
    path: `tools/r451_tx/note/${picked.note}/grug_ambience_note.png`}};
  for (const key of keys) result.greetings[key] = {variant: picked[key], text: greetings[key][picked[key]]};
  const url = URL.createObjectURL(new Blob([JSON.stringify(result, null, 2) + "\n"], {type: "application/json"}));
  const link = document.createElement("a"); link.href = url; link.download = "r451-tx-selections.json";
  document.body.append(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
update();
</script></html>
'''


def validate_greetings(greetings):
    assert tuple(greetings) == KEYS, "Expected exactly the eight requested keys"
    for key, variants in greetings.items():
        assert tuple(variants) == ("A", "B", "C"), key
        assert len(set(variants.values())) == 3, key
        for variant, text in variants.items():
            assert isinstance(text, str) and 1 <= len(text) <= 200, (key, variant)
            assert text.isascii() and "\n" not in text, (key, variant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare generated files without writing")
    args = parser.parse_args()
    greetings = json.loads((HERE / "greetings.json").read_text())
    validate_greetings(greetings)
    # Guard the colour claim against the repository's actual inventory image.
    with Image.open(ROOT / "mods/BASE/default/textures/gui_formbg.png") as bg:
        assert bg.convert("RGBA").getpixel((bg.width // 2, bg.height // 2)) == (52, 52, 52, 255)
    outputs = {}
    for variant in VOICES:
        icon = note(variant)
        assert icon.mode == "RGBA" and icon.size == SIZE
        alpha = icon.getchannel("A")
        assert set(alpha.tobytes()) == {0, 255}, "Icons use hard pixel edges"
        assert all(0 < v < 24 for v in alpha.getbbox()), "Transparent margin required"
        assert all(icon.getpixel((x, y)) == CLEAR for y in range(24)
                   for x in range(24) if alpha.getpixel((x, y)) == 0)
        for name, im in (("grug_ambience_note.png", icon), ("preview.png", preview(icon, variant))):
            data = io.BytesIO()
            im.save(data, format="PNG", optimize=False)
            outputs[HERE / "note" / variant / name] = data.getvalue()
    outputs[HERE / "review.html"] = review_page(greetings).encode("utf-8")
    for path, content in outputs.items():
        if args.check:
            assert path.read_bytes() == content, f"Stale generated file: {path.relative_to(ROOT)}"
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    lengths = [len(text) for variants in greetings.values() for text in variants.values()]
    print(f"{'Verified' if args.check else 'Wrote'} {len(outputs)} files; 24 greetings, "
          f"{min(lengths)}-{max(lengths)} characters; 3 transparent 24x24 RGBA icons; "
          "3 opaque 1072x1216 RGBA previews; inventory colour #343434, alpha 77/255.")


if __name__ == "__main__":
    main()

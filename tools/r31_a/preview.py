#!/usr/bin/env python3
"""Round 31 lane A: the character-look preview page for the user's approval.

Every picture is rendered from the texture string the REAL
mods/PLAYER/grug_visuals/looks.lua builds (through look_strings.lua under
LuaJIT), by a small interpreter of the engine modifiers that string uses:
`^` overlay, `(...)` grouping, `[multiply`, `[mask` and `[hsl` -- written
after Luanti's src/client/imagesource.cpp (blit_pixel, apply_multiplication,
apply_mask, apply_hue_saturation).

    python3 tools/r31_a/preview.py OUT.html

Requires Pillow and luajit; run from the repository root after
tools/wp13/gen_character_visuals.py.
"""
import base64
import colorsys
import io
import os
import random
import subprocess
import sys

from PIL import Image

TEX = "mods/PLAYER/grug_visuals/textures"
W, H = 64, 32
HEAD = {"right": (0, 8), "front": (8, 8), "left": (16, 8), "back": (24, 8)}
HAT = {k: (x + 32, y) for k, (x, y) in HEAD.items()}
TORSO = {"right": (16, 20), "front": (20, 20), "left": (28, 20),
         "back": (32, 20)}
ARM = {"right": (40, 20), "front": (44, 20), "left": (48, 20),
       "back": (52, 20)}
LEG = {"right": (0, 20), "front": (4, 20), "left": (8, 20), "back": (12, 20)}

RACES = ["human", "dwarf", "elf", "orc", "troll", "undead"]
RACE_DE = {"human": "Mensch", "dwarf": "Zwerg", "elf": "Elf", "orc": "Ork",
           "troll": "Troll", "undead": "Untoter"}
FACTIONS = [("Accord", ["human", "dwarf", "elf"]),
            ("Throng", ["orc", "troll", "undead"])]
STYLE_DE = {
    "human": ["Kurz", "Seitenscheitel", "Lang", "Zopf"],
    "dwarf": ["Voll", "Halbglatze", "Zopf"],
    "elf": ["Lang", "Hoher Zopf", "Kranzzopf", "Kurz"],
    "orc": ["Haarknoten", "Irokese", "Geschoren", "Zöpfe"],
    "troll": ["Mähne", "Kamm", "Zurückgekämmt", "Zwei Zöpfe"],
    "undead": ["Fleckig", "Strähnig", "Kahl"],
}
FEATURE_DE = {
    "human": ["Stoppeln", "Kurzer Bart", "Schnurrbart"],
    "dwarf": ["Vollbart", "Geflochten", "Gegabelt", "Kurz"],
    "elf": ["Spitze Ohren", "Lange Ohren", "Ohren + Zeichnung"],
    "orc": ["Kleine Hauer", "Große Hauer", "Abgebrochener Hauer",
            "Kriegsbemalung"],
    "troll": ["Hauer klein", "Hauer groß", "Hauer riesig"],
    "undead": ["Freiliegender Kiefer", "Nähte", "Eingefallene Nase"],
}
FEATURE_TITLE = {"human": "Bart", "dwarf": "Bart", "elf": "Ohren / Zeichnung",
                 "orc": "Hauer / Bemalung", "troll": "Hauer",
                 "undead": "Gesicht"}
# Option counts per race, in looks.lua order: tone, hair, style, eyes, feature.
COUNTS = {"human": (4, 6, 4, 3, 3), "dwarf": (3, 5, 3, 3, 4),
          "elf": (3, 5, 4, 3, 3), "orc": (3, 4, 4, 3, 4),
          "troll": (3, 5, 4, 3, 3), "undead": (3, 4, 3, 3, 3)}
HELMETS_SHOWN = [("Stoff", "cloth", 5), ("Leder", "leather", 4),
                 ("Metall", "metal", 3)]


# --------------------------------------------------------------------------
# The modifier interpreter.
# --------------------------------------------------------------------------
_files = {}


def load(name):
    if name not in _files:
        _files[name] = Image.open(os.path.join(TEX, name)).convert("RGBA")
    return _files[name].copy()


def split_top(s):
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "^" and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return parts


def blit(dst, src):
    d, s = dst.load(), src.load()
    for j in range(dst.size[1]):
        for i in range(dst.size[0]):
            sr, sg, sb, sa = s[i, j]
            dr, dg, db, da = d[i, j]
            if sa == 0:
                continue
            if sa == 255 or da == 0:
                d[i, j] = (sr, sg, sb, sa)
                continue
            r = (dr * (255 - sa) + sr * sa) // 255
            g = (dg * (255 - sa) + sg * sa) // 255
            b = (db * (255 - sa) + sb * sa) // 255
            if da != 255:
                da = da + (255 - da) * sa * sa // (255 * 255)
            d[i, j] = (r, g, b, da)
    return dst


def hexcol(text):
    text = text.lstrip("#")
    return tuple(int(text[k:k + 2], 16) for k in (0, 2, 4))


def modifier(img, part):
    name, _, arg = part[1:].partition(":")
    px = img.load()
    if name == "multiply":
        c = hexcol(arg)
        for j in range(img.size[1]):
            for i in range(img.size[0]):
                r, g, b, a = px[i, j]
                px[i, j] = (r * c[0] // 255, g * c[1] // 255,
                            b * c[2] // 255, a)
    elif name == "mask":
        m = load(arg).load()
        for j in range(img.size[1]):
            for i in range(img.size[0]):
                px[i, j] = tuple(a & b for a, b in zip(px[i, j], m[i, j]))
    elif name == "hsl":
        hue, sat, lig = (int(v) for v in arg.split(":"))
        ns, nl = sat / 100.0, lig / 100.0
        for j in range(img.size[1]):
            for i in range(img.size[0]):
                r, g, b, a = px[i, j]
                h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
                l = l * (nl + 1) if nl < 0 else l + nl * (1 - l)
                s = min(1.0, max(0.0, s * (ns + 1)))
                h = (h + hue / 360.0) % 1.0
                r, g, b = colorsys.hls_to_rgb(h, l, s)
                px[i, j] = (int(r * 255 + .5), int(g * 255 + .5),
                            int(b * 255 + .5), a)
    else:
        raise SystemExit("modifier not implemented: " + part)
    return img


_rendered = {}


def render(s):
    if s in _rendered:
        return _rendered[s].copy()
    img = None
    for part in split_top(s):
        if part.startswith("["):
            img = modifier(img, part)
        else:
            layer = render(part[1:-1]) if part.startswith("(") else load(part)
            img = layer if img is None else blit(img, layer)
    _rendered[s] = img.copy()
    return img


# --------------------------------------------------------------------------
# Paper dolls: front and back (16x32) and the right side (8x32).
# --------------------------------------------------------------------------
def crop(img, xy, w, h):
    return img.crop((xy[0], xy[1], xy[0] + w, xy[1] + h))


def doll(skin, side):
    out = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    if side == "side":
        out = Image.new("RGBA", (8, 32), (0, 0, 0, 0))
        out.alpha_composite(crop(skin, HEAD["right"], 8, 8), (0, 0))
        out.alpha_composite(crop(skin, HAT["right"], 8, 8), (0, 0))
        out.alpha_composite(crop(skin, ARM["right"], 4, 12), (2, 8))
        out.alpha_composite(crop(skin, LEG["right"], 4, 12), (2, 20))
        return out
    out.alpha_composite(crop(skin, HEAD[side], 8, 8), (4, 0))
    out.alpha_composite(crop(skin, HAT[side], 8, 8), (4, 0))
    out.alpha_composite(crop(skin, TORSO[side], 8, 12), (4, 8))
    flip = Image.FLIP_LEFT_RIGHT
    arm = crop(skin, ARM[side], 4, 12)
    leg = crop(skin, LEG[side], 4, 12)
    out.alpha_composite(arm.transpose(flip) if side == "front" else arm,
                        (0, 8))
    out.alpha_composite(arm.transpose(flip) if side == "back" else arm,
                        (12, 8))
    out.alpha_composite(leg.transpose(flip) if side == "back" else leg,
                        (4, 20))
    out.alpha_composite(leg.transpose(flip) if side == "front" else leg,
                        (8, 20))
    return out


def triple(skin):
    out = Image.new("RGBA", (16 + 2 + 16 + 2 + 8, 32), (0, 0, 0, 0))
    out.alpha_composite(doll(skin, "front"), (0, 0))
    out.alpha_composite(doll(skin, "back"), (18, 0))
    out.alpha_composite(doll(skin, "side"), (36, 0))
    return out


def face(skin):
    out = crop(skin, HEAD["front"], 8, 8)
    out.alpha_composite(crop(skin, HAT["front"], 8, 8))
    return out


def uri(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def pic(img, scale, alt):
    w, h = img.size
    return ('<img src="%s" width="%d" height="%d" alt="%s">'
            % (uri(img), w * scale, h * scale, alt))


# --------------------------------------------------------------------------
# Requests to the Lua side.
# --------------------------------------------------------------------------
def ask(requests):
    """requests: list of (label, race, look, armour, royal); look is a list of
    five indices, "S<seed>" or "K" (the king's look), armour "-" or
    "<line>:<bracket>[:nohead]"."""
    lines = []
    for label, race, look, armour, royal in requests:
        if not isinstance(look, str):
            look = ",".join(str(v) for v in look)
        lines.append("\t".join([label, race, look, armour or "-",
                                 royal or "-"]))
    out = subprocess.run(["luajit", "tools/r31_a/look_strings.lua", "."],
                         input="\n".join(lines) + "\n", capture_output=True,
                         text=True, check=True).stdout
    result = {}
    for line in out.splitlines():
        label, texture, look = line.split("\t")
        result[label] = (texture, [int(v) for v in look.split(",")])
    return result


def colours():
    """The option colours, read back from looks.lua (for the swatches)."""
    script = ('grug_visuals = {} dofile("mods/PLAYER/grug_visuals/looks.lua") '
              'for _, r in ipairs({"human","dwarf","elf","orc","troll","undead"})'
              ' do local d = grug_visuals.LOOKS[r] '
              'print(r, table.concat(d.tones, ","), table.concat(d.hair, ","),'
              ' table.concat(d.eyes, ",")) end')
    out = subprocess.run(["luajit", "-e", script], capture_output=True,
                         text=True, check=True).stdout
    table = {}
    for line in out.splitlines():
        race, tones, hair, eyes = line.split("\t")
        table[race] = {"tone": tones.split(","), "hair": hair.split(","),
                       "eyes": eyes.split(",")}
    return table


# The 18 helmets: three lines, six material tiers (grug_gear.MATERIALS).
TIERS = {"cloth": ["patch", "woven", "heavy", "silkweave", "silk", "stormweave"],
         "leather": ["light", "cured", "heavy", "scaled", "sleek", "nightscale"],
         "metal": ["bronze", "iron", "steel", "silversteel", "embersteel",
                   "abyssal_steel"]}


def all_helmets():
    return [(line, bracket + 1, TIERS[line][bracket])
            for line in ("cloth", "leather", "metal") for bracket in range(6)]


# --------------------------------------------------------------------------
# The page.
# --------------------------------------------------------------------------
CSS = """
:root { --bg: #f6f4ef; --fg: #24221e; --muted: #6b665c; --card: #ffffff;
  --line: #ddd8cc; --doll: #c9d3de; --accent: #8a4b14; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #1b1c1f; --fg: #e8e5de; --muted: #a39d90; --card: #26282c;
    --line: #3a3c42; --doll: #9aa5b3; --accent: #e0a060; } }
body { background: var(--bg); color: var(--fg); margin: 0;
  font: 15px/1.45 system-ui, sans-serif; }
main { max-width: 1100px; margin: 0 auto; padding: 16px; }
h1 { font-size: 1.5em; margin: .2em 0 .4em; }
h2 { font-size: 1.2em; margin: 1.6em 0 .4em; border-bottom: 1px solid var(--line);
  padding-bottom: .2em; }
h3 { font-size: 1em; margin: 1.1em 0 .3em; color: var(--accent); }
p, li { max-width: 70ch; }
.muted { color: var(--muted); font-size: .9em; }
.decide { background: var(--card); border: 1px solid var(--line);
  border-radius: 8px; padding: 10px 14px 10px 30px; }
.decide li { margin: .3em 0; }
.grid { display: flex; flex-wrap: wrap; gap: 8px; }
.cell { background: var(--card); border: 1px solid var(--line); border-radius: 6px;
  padding: 6px; text-align: center; font-size: .82em; }
.cell img, .wide img { background: var(--doll); border-radius: 3px; display: block;
  margin: 0 auto 4px; image-rendering: pixelated; max-width: 100%; height: auto; }
.cell b { color: var(--accent); }
.sw { display: inline-block; width: .9em; height: .9em; border-radius: 2px;
  vertical-align: -1px; border: 1px solid var(--line); }
code { font-size: .85em; word-break: break-all; }
"""


def cell(img, scale, title, sub="", swatch=None):
    sw = ('<span class="sw" style="background:%s"></span> ' % swatch
          if swatch else "")
    return ('<div class="cell">%s<b>%s</b><br>%s%s</div>'
            % (pic(img, scale, title), title, sw, sub))


def back_side(skin_img, bg):
    """Back and right-side paper dolls of a skin, on a solid `bg`."""
    out = Image.new("RGBA", (16 + 2 + 8, 32), bg)
    out.alpha_composite(doll(skin_img, "back"), (0, 0))
    out.alpha_composite(doll(skin_img, "side"), (18, 0))
    return out


def holes(skin_img):
    """The same crops as a map: magenta where the head would be see-through."""
    out = Image.new("RGBA", (17, 8), (0, 0, 0, 0))
    for index, side in enumerate(("back", "right")):
        part = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        part.alpha_composite(crop(skin_img, HEAD[side], 8, 8))
        part.alpha_composite(crop(skin_img, HAT[side], 8, 8))
        px = part.load()
        for j in range(8):
            for i in range(8):
                ok = px[i, j][3] == 255
                out.putpixel((index * 9 + i, j),
                             (60, 160, 80, 255) if ok else (255, 0, 255, 255))
    return out


def main():
    out_path = sys.argv[1]
    cols = colours()
    helmets = all_helmets()
    html = []
    add = html.append

    # ---- requests -------------------------------------------------------
    reqs = []
    for race in RACES:
        counts = COUNTS[race]
        for cat, n in enumerate(counts):
            for k in range(1, n + 1):
                look = [1, 1, 1, 1, 1]
                look[cat] = k
                reqs.append(("%s-%d-%d" % (race, cat, k), race, look, None,
                             None))
        for name, line, bracket in HELMETS_SHOWN:
            reqs.append(("%s-helm-%s" % (race, name), race, [1, 1, 1, 1, 1],
                         "%s:%d" % (line, bracket), None))
    window_races = [("human", [1, 3, 1, 1, 2]), ("dwarf", [2, 1, 1, 1, 1]),
                    ("troll", [1, 1, 1, 1, 3])]
    for race, look in window_races:
        reqs.append(("win-%s-plain" % race, race, look, None, None))
        for line, bracket, tier in helmets:
            reqs.append(("win-%s-%s-%d" % (race, line, bracket), race, look,
                         "%s:%d" % (line, bracket), None))
    steps_look = [2, 1, 1, 1, 3]
    reqs.append(("steps-nohelm", "dwarf", steps_look, "metal:3:nohead", None))
    reqs.append(("steps-helm", "dwarf", steps_look, "metal:3", None))
    rng = random.Random(31)
    npc = {}
    for faction, races in FACTIONS:
        for race in races:
            for k in range(8):
                label = "town-%s-%s-%d" % (faction, race, k)
                armour = None
                if k >= 6:
                    armour = "metal:%d" % rng.randrange(1, 7)
                reqs.append((label, race, "S%d" % rng.randrange(1, 2 ** 31 - 1),
                             armour, None))
                npc.setdefault(("town", faction), []).append(
                    (label, race, armour is not None))
        for k in range(24):
            race = races[rng.randrange(len(races))]
            label = "guard-%s-%d" % (faction, k)
            reqs.append((label, race, "S%d" % rng.randrange(1, 2 ** 31 - 1),
                         "metal:%d" % rng.randrange(1, 7), None))
            npc.setdefault(("guard", faction), []).append((label, race, True))
    for race in RACES:
        reqs.append(("king-%s" % race, race, "K", None, "king"))
        for k in range(3):
            reqs.append(("royal-%s-%d" % (race, k), race,
                         "S%d" % rng.randrange(1, 2 ** 31 - 1), None, "guard"))
    for line, bracket, tier in helmets:
        reqs.append(("check-%s-%d" % (line, bracket), "human", [1, 1, 1, 1, 1],
                     "%s:%d" % (line, bracket), None))
    got = ask(reqs)

    def skin(label):
        return render(got[label][0])

    # ---- header -------------------------------------------------------------
    add("<title>Charakter-Aussehen Stufe 2</title>")
    add("<style>%s</style>" % CSS)
    add("<main>")
    add("<h1>Charakter-Aussehen: Stufe 2</h1>")
    add('<p class="muted">Runde 31, Lane A. Die Ebenen aus Stufe 1 sind '
        "freigegeben und jetzt im Spiel verdrahtet. Jedes Bild ist der echte "
        "Textur-String aus <code>grug_visuals.compose</code>, mit den "
        "Engine-Modifikatoren nachgerechnet (vorne · hinten · rechte "
        "Seite).</p>")
    add('<h2>Neu in Stufe 2</h2><ol class="decide">')
    add("<li><b>Hinterkopf mit Helm</b> (Abschnitt 0): keine Lücke im Skin. "
        "Das dunkle Kettengeflecht der Metallhelme sah auf dem dunklen "
        "Vorschau-Hintergrund wie durchsichtig aus; der Hintergrund ist jetzt "
        "hell.</li>")
    add("<li><b>Erstellungsdialog</b> nach der Klassenwahl: ◀/▶ je Kategorie, "
        "Zufall, drehende Vorschau, einmaliges Bestätigen.</li>")
    add("<li><b>NPCs</b> würfeln ihr Aussehen einmal und behalten es; Wachen "
        "haben das Volk ihrer Siedlung, Könige ein festes Aussehen mit Krone "
        "und Wappenrock, Königswachen den Wappenrock (Abschnitt 4).</li>")
    add("</ol>")

    # ---- 0. the head check ----------------------------------------------------
    add("<h2>0. Prüfung: Hinterkopf und Seite mit Helm</h2>")
    add("<p>Mensch mit jedem Metall- und zwei Lederhelmen, von hinten und von "
        "rechts. Links auf dem alten dunklen Vorschau-Hintergrund (vorher), "
        "rechts auf dem neuen hellen (nachher), darunter die Karte jedes "
        "Kopfpixels von hinten und rechts: grün = deckend, magenta = "
        "durchsichtig. Kein Pixel ist durchsichtig: unter dem Helm liegt "
        "immer die Haut. Was durchsichtig wirkte, ist das dunkle Kettengeflecht "
        "unten am Helm (z. B. Stahl), fast so dunkel wie der alte "
        "Hintergrund.</p>")
    cells = []
    for line, bracket, tier in helmets:
        if line == "cloth" or (line == "leather" and bracket not in (1, 6)):
            continue
        img = skin("check-%s-%d" % (line, bracket))
        stack = Image.new("RGBA", (26 * 2 + 3, 32 + 2 + 8), (0, 0, 0, 0))
        stack.alpha_composite(back_side(img, (74, 77, 85, 255)), (0, 0))
        stack.alpha_composite(back_side(img, (201, 211, 222, 255)), (29, 0))
        stack.alpha_composite(holes(img), (0, 34))
        cells.append(cell(stack, 4, "%s %s" % (line, tier)))
    add('<div class="grid">%s</div>' % "".join(cells))

    # ---- 1. layer order -------------------------------------------------------
    add("<h2>1. Ebenenreihenfolge</h2>")
    add("<p>Haut → Augen → Frisur → (Rüstung am Körper) → Helm mit Fenster → "
        "Merkmal. Beispiel Zwerg, Vollbart, Stahlrüstung.</p>")
    for label, steps in (("steps-nohelm", {1: "Haut (Ton + Körper)",
                                           2: "Augen", 4: "Frisur",
                                           7: "Rüstung", 9: "Merkmal"}),
                         ("steps-helm", {1: "Haut (Ton + Körper)", 2: "Augen",
                                         5: "Rüstung (Frisur entfällt)",
                                         6: "Helm mit Fenster",
                                         8: "Merkmal über dem Helm"})):
        acc, cells = "", []
        for idx, part in enumerate(split_top(got[label][0])):
            acc = part if not acc else acc + "^" + part
            if idx in steps:
                cells.append(cell(triple(render(acc)), 4, "%d. %s"
                                  % (len(cells) + 1, steps[idx])))
        add('<p class="muted">%s</p><div class="grid">%s</div>'
            % ("Ohne Helm" if label == "steps-nohelm" else "Mit Helm",
               "".join(cells)))

    # ---- 2. face window ---------------------------------------------------------
    add("<h2>2. Helm-Fenster an allen Helmen</h2>")
    add("<p>Gesicht von vorn, links der Helm einfach darübergelegt (Frisur "
        "darunter, Merkmal verdeckt), rechts wie das Spiel ihn jetzt "
        "zusammensetzt.</p>")
    for race, look in window_races:
        fname = FEATURE_DE[race][look[4] - 1]
        add("<h3>%s, %s</h3>" % (RACE_DE[race], fname))
        cells = []
        for line, bracket, tier in helmets:
            base = render(got["win-%s-%s-%d" % (race, line, bracket)][0])
            helmet = "grug_visuals_%s_head_%s.png" % (line, tier)
            if tier == "silversteel":
                helmet += "^[hsl:0:-90:5"
            before = blit(render(got["win-%s-plain" % race][0]),
                          render(helmet))
            pair = Image.new("RGBA", (8 * 2 + 1, 8), (0, 0, 0, 0))
            pair.alpha_composite(face(before), (0, 0))
            pair.alpha_composite(face(base), (9, 0))
            cells.append(cell(pair, 7, "%s %s" % (line, tier)))
        add('<div class="grid">%s</div>' % "".join(cells))

    # ---- 3. races -----------------------------------------------------------
    add("<h2>3. Optionen je Volk</h2>")
    add('<p class="muted">In jeder Zeile ändert sich nur eine Kategorie, alle '
        "anderen stehen auf Option 1.</p>")
    cat_names = ["Hautton", "Haarfarbe", "Frisur", "Augen", None]
    for race in RACES:
        counts = COUNTS[race]
        add("<h3>%s</h3>" % RACE_DE[race])
        for cat, n in enumerate(counts):
            title = cat_names[cat] or FEATURE_TITLE[race]
            if race == "undead" and cat == 3:
                title = "Augen (Leuchtfarbe)"
            cells = []
            for k in range(1, n + 1):
                img = skin("%s-%d-%d" % (race, cat, k))
                sub, sw = "", None
                if cat == 0:
                    sw = cols[race]["tone"][k - 1]
                elif cat == 1:
                    sw = cols[race]["hair"][k - 1]
                elif cat == 2:
                    sub = STYLE_DE[race][k - 1]
                elif cat == 3:
                    sw = cols[race]["eyes"][k - 1]
                else:
                    sub = FEATURE_DE[race][k - 1]
                if cat == 3:
                    big = face(img).resize((32, 32), Image.NEAREST)
                    shot = Image.new("RGBA", (32 + 2 + 16, 32), (0, 0, 0, 0))
                    shot.alpha_composite(big, (0, 0))
                    shot.alpha_composite(doll(img, "front"), (34, 0))
                    cells.append(cell(shot, 4, "%s %d" % (title, k), sub, sw))
                else:
                    cells.append(cell(triple(img), 4, "%s %d" % (title, k),
                                      sub, sw))
            add('<p class="muted">%s (%d)</p><div class="grid">%s</div>'
                % (title, n, "".join(cells)))
        cells = [cell(triple(skin("%s-helm-%s" % (race, name))), 4,
                      "mit Helm: " + name) for name, _, _ in HELMETS_SHOWN]
        add('<p class="muted">Mit Helm (Option 1 überall)</p>'
            '<div class="grid">%s</div>' % "".join(cells))

    # ---- 4. NPCs --------------------------------------------------------------
    add("<h2>4. NPCs</h2>")
    add("<p>Jeder NPC würfelt einmal eine Zahl und behält sie; sein Aussehen "
        "folgt daraus (<code>grug_visuals.npc_look</code>). Stadt-NPCs und "
        "Wachen haben das Volk ihrer Siedlung (die letzten zwei je Volk hier "
        "als Wachen in Metall), Festungswachen ein gewürfeltes Volk ihrer "
        "Fraktion.</p>")
    for faction, races in FACTIONS:
        for kind, title in (("town", "Siedlungen (je 8 pro Volk)"),
                            ("guard", "Festungswachen (gemischt)")):
            cells = []
            for label, race, armed in npc[(kind, faction)]:
                img = doll(skin(label), "front")
                cells.append(cell(img, 3, RACE_DE[race] +
                                  (" (Wache)" if armed and kind == "town"
                                   else "")))
            add("<h3>%s: %s</h3><div class=\"grid\">%s</div>"
                % (faction, title, "".join(cells)))
    add("<h3>Könige und Königswachen</h3>")
    cells = []
    for race in RACES:
        cells.append(cell(triple(skin("king-%s" % race)), 3,
                          "König " + RACE_DE[race]))
        for k in range(3):
            cells.append(cell(doll(skin("royal-%s-%d" % (race, k)), "front"),
                              3, "Wache"))
    add('<div class="grid">%s</div>' % "".join(cells))

    # ---- 5. technical -------------------------------------------------------
    add("<h2>5. Technik</h2>")
    add("<p>%s</p>" % TECH_NOTE)
    add("</main>")
    with open(out_path, "w") as handle:
        handle.write("\n".join(html) + "\n")
    print(out_path, os.path.getsize(out_path))


TECH_NOTE = os.environ.get("R31A_TECH_NOTE", "")

if __name__ == "__main__":
    main()

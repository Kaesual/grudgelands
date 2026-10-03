#!/usr/bin/env python3
"""Round 31 lane B stage 1: the enchant-colour preview page (German, for the
user's approval). Writes one self-contained HTML file (pictures as data: URIs).

Every gear picture is rendered from the texture strings that
grug_gear.enchant_image builds (tools/r31_b/portable_test.lua in `emit`
mode), through texmod.py's model of the engine's texture modifiers.

    python3 tools/r31_b/build_preview.py OUT.html [OLD_REV]

Design round 2 (round31-plan.md §6 item 7): the page compares the shipped
masks at 50 % with the round-1 masks at full strength (read from git at
OLD_REV, if given) and with a smaller variant generated in memory.
"""
import base64
import io
import itertools
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import colorsci  # noqa: E402
import gen_enchant_masks  # noqa: E402
import texmod  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
QUALITY = (ROOT / "mods/ITEMS/grug_quality/init.lua").read_text()
COLORS_LUA = (ROOT / "mods/ITEMS/grug_gear/enchant_colors.lua").read_text()

STATS = ["str", "dex", "int", "max_hp_percent", "max_mana_percent", "crit_percent",
         "attack_speed_percent", "dodge_percent", "armor_rating"]
GERMAN = {"str": "Stärke", "dex": "Geschick", "int": "Intelligenz",
          "max_hp_percent": "max. Leben", "max_mana_percent": "max. Mana",
          "crit_percent": "Krit", "attack_speed_percent": "Angriffstempo",
          "dodge_percent": "Ausweichen", "armor_rating": "Rüstungswert"}
COLOR_WORD = {"str": "Tiefrot", "dex": "Mintgrün", "int": "Indigo", "max_hp_percent": "Rosé",
              "max_mana_percent": "Himmelblau", "crit_percent": "Gelb",
              "attack_speed_percent": "Orange", "dodge_percent": "Lavendel",
              "armor_rating": "Weiß"}
COLORS = dict(re.findall(r"\n\t(\w+) = \"(#[0-9a-f]{6})\"", COLORS_LUA))
AFFIX = {m[0]: (m[1], m[2]) for m in re.findall(
    r"\n\t(\w+) = \{label = \"[^\"]+\", short = \"[^\"]+\",\s*prefix = \"([^\"]+)\",\s*"
    r"suffix = \"([^\"]+)\"", QUALITY)}
POOLS = {k: re.findall(r"\"(\w+)\"", v) for k, v in re.findall(
    r"\n\t(\w+) = \{([^}]*)\}", QUALITY[QUALITY.index("local POOLS"):QUALITY.index("local BANDS")])}
assert set(COLORS) == set(STATS) and set(AFFIX) == set(STATS), (COLORS, AFFIX)

METALS = ["bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"]
GRADES = {"metal": METALS,
          "leather": ["light", "cured", "heavy", "scaled", "sleek", "nightscale"],
          "cloth": ["patch", "woven", "heavy", "silkweave", "silk", "stormweave"]}
METAL_DE = ["Bronze", "Eisen", "Stahl", "Silberstahl", "Glutstahl", "Abyssstahl"]
FAMILIES = [  # (title, item prefix or pattern, pool)
    ("Schwerter", "sword", "sword"), ("Dolche", "dagger", "dagger"),
    ("Streitäxte", "greataxe", "greataxe"), ("Stäbe", "staff", "caster_weapon"),
    ("Zauberstäbe", "wand", "caster_weapon"), ("Bögen", "bow", "bow"),
    ("Schilde", "shield", "shield"), ("Zauberbücher", "spellbook", "spellbook")]
SLOT_DE = {"head": "Kopf", "chest": "Brust", "legs": "Beine", "feet": "Füße"}
LINE_DE = {"cloth": "Stoff", "leather": "Leder", "metal": "Metall"}


def sample_pairs(pool):
    """Three prefix/suffix pairs from the family's pool, every stat used."""
    out = []
    for i in range(3):
        a, b = pool[(2 * i) % len(pool)], pool[(2 * i + 1) % len(pool)]
        out.append((a, b))
    return out


def all_pairs():
    pairs = {("-", "-")}
    for pool in POOLS.values():
        pairs.update(sample_pairs(pool))
    pairs.update(d[3] for d in DOLLS)
    pairs.update(c[1] for c in COMPARE)
    pairs.update((s, "-") for s in STATS)
    pairs.update(("-", s) for s in STATS)
    return sorted(pairs)




def emit(opacity, pairs):
    bodies = sorted({"body=%s:%s:%d" % (d[0], d[1], d[2]) for d in DOLLS})
    args = ["luajit", str(ROOT / "tools/r31_b/portable_test.lua"), str(ROOT), "emit",
            str(opacity)] + ["%s:%s" % p for p in pairs] + bodies
    lines = subprocess.run(args, check=True, capture_output=True, text=True).stdout.splitlines()
    items, worn = {}, {}
    for line in lines:
        parts = line.split("\t")
        if parts[0] == "item":
            items[(parts[1], tuple(parts[2].split(":")))] = parts[3]
        elif parts[0] == "body":
            worn[("body", parts[1], parts[2], int(parts[3]), tuple(parts[4].split(":")))] = parts[5]
        else:
            worn[(parts[1], parts[2], int(parts[3]), tuple(parts[4].split(":")))] = parts[5]
    return items, worn


def scaled(img, factor):
    pil = texmod.to_pil(img) if not isinstance(img, Image.Image) else img
    return pil.resize((pil.width * factor, pil.height * factor), Image.NEAREST)


def data_uri(pil):
    buffer = io.BytesIO()
    pil.save(buffer, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode()


def grid(cells, cols, factor, pad=4, bg=(0, 0, 0, 0)):
    """cells: list of rendered arrays (or None), row-major."""
    tile = max(c.shape[1] for c in cells if c is not None) * factor
    tile_h = max(c.shape[0] for c in cells if c is not None) * factor
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (tile + pad) - pad, rows * (tile_h + pad) - pad), bg)
    for i, cell in enumerate(cells):
        if cell is None:
            continue
        sheet.alpha_composite(scaled(cell, factor), ((i % cols) * (tile + pad),
                                                     (i // cols) * (tile_h + pad)))
    return sheet


def item_names(key):
    if key == "bow":
        return ["grug_gear:bow_" + m for m in METALS]
    if key in ("shield", "spellbook"):
        return ["grug_gear:%s_%s" % (key, m) for m in METALS]
    return ["grug_gear:%s_%s" % (key, m) for m in METALS]


def display_name(base, pair):
    prefix = AFFIX[pair[0]][0] + " " if pair[0] != "-" else ""
    suffix = " " + AFFIX[pair[1]][1] if pair[1] != "-" else ""
    return prefix + base + suffix


# --- paper doll: front and back of the 64x32 character skin -----------------
def doll(skin):
    """Front and back views (16x32 each, 2 px apart) of a composed skin."""
    s = texmod.to_pil(skin)
    out = Image.new("RGBA", (34, 32), (0, 0, 0, 0))

    def put(box, dest, mirror=False, x0=0):
        part = s.crop(box)
        if mirror:
            part = part.transpose(Image.FLIP_LEFT_RIGHT)
        out.alpha_composite(part, (dest[0] + x0, dest[1]))
    # front
    put((8, 8, 16, 16), (4, 0)); put((40, 8, 48, 16), (4, 0))
    put((20, 20, 28, 32), (4, 8))
    put((44, 20, 48, 32), (0, 8)); put((44, 20, 48, 32), (12, 8), True)
    put((4, 20, 8, 32), (4, 20)); put((4, 20, 8, 32), (8, 20), True)
    # back
    x0 = 18
    put((24, 8, 32, 16), (4, 0), x0=x0); put((56, 8, 64, 16), (4, 0), x0=x0)
    put((32, 20, 40, 32), (4, 8), x0=x0)
    put((52, 20, 56, 32), (12, 8), x0=x0); put((52, 20, 56, 32), (0, 8), True, x0=x0)
    put((12, 20, 16, 32), (8, 20), x0=x0); put((12, 20, 16, 32), (4, 20), True, x0=x0)
    return out


def body(race, line, bracket, pair, worn):
    """The composed skin of a full set, as grug_visuals.compose builds it."""
    text = worn[("body", race, line, bracket, pair)]
    return texmod.render(text), text


# --- page ----------------------------------------------------------------------
CSS = """
:root{--bg:#f6f4ef;--fg:#1d1b18;--muted:#6b665c;--card:#ffffff;--line:#ddd7cc;
--accent:#7a4b12;--tile:#4a4f5a}
@media (prefers-color-scheme: dark){:root{--bg:#17181b;--fg:#ece8df;--muted:#a39d92;
--card:#202226;--line:#34373d;--accent:#e2a65a;--tile:#3a3e47}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;margin:0;
padding:16px;max-width:1100px;margin-inline:auto}
h1{font-size:1.6em;margin:.2em 0}h2{margin-top:2em;border-bottom:1px solid var(--line);
padding-bottom:.2em}h3{margin:1.2em 0 .3em;font-size:1.05em}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 16px;
margin:12px 0}
.decide li{margin:.4em 0}.muted{color:var(--muted);font-size:.9em}
img{max-width:100%;image-rendering:pixelated;image-rendering:crisp-edges}
.tile{background:var(--tile);border-radius:8px;padding:8px;display:inline-block;max-width:100%;
box-sizing:border-box}
table{border-collapse:collapse;width:100%;font-size:.92em}
td,th{border-bottom:1px solid var(--line);padding:4px 6px;text-align:left;vertical-align:middle}
.sw{display:inline-block;width:28px;height:20px;border-radius:4px;border:1px solid var(--line)}
.scroll{overflow-x:auto}.row{display:flex;flex-wrap:wrap;gap:12px;align-items:flex-start}
code{font-size:.85em;word-break:break-all}
"""


def old_masks(rev):
    """The round-1 masks, read from git at `rev`."""
    out = {}
    for directory, stem, _ in gen_enchant_masks.sources():
        path = (directory / (stem + "_ench.png")).relative_to(ROOT)
        data = subprocess.run(["git", "-C", str(ROOT), "show", "%s:%s" % (rev, path)],
                              check=True, capture_output=True).stdout
        out[stem + "_ench.png"] = np.array(Image.open(io.BytesIO(data)).convert("RGBA"),
                                           dtype=np.int64)
    return out


def scaled_masks(scale):
    """Masks of the smaller variant, generated in memory."""
    out = {}
    for directory, stem, kind in gen_enchant_masks.sources():
        result = gen_enchant_masks.split(directory, stem, kind, scale)
        mask = gen_enchant_masks.render(directory, stem, result)
        out[stem + "_ench.png"] = np.array(mask.convert("RGBA"), dtype=np.int64)
    return out


SMALLER = 0.6
DOLLS = [("human", "metal", 6, ("str", "armor_rating"), "Mensch, Abyssstahl: Heavy … of the Tortoise"),
         ("orc", "metal", 3, ("max_hp_percent", "str"), "Ork, Stahl: Stout … of the Bear"),
         ("elf", "leather", 4, ("dex", "dodge_percent"), "Elf, Schuppenleder: Quick … of the Cat"),
         ("dwarf", "cloth", 5, ("int", "max_mana_percent"), "Zwerg, Seide: Clever … of the Raven"),
         ("troll", "leather", 2, ("crit_percent", "max_hp_percent"), "Troll, gegerbtes Leder: Lucky … of the Ox"),
         ("undead", "cloth", 3, ("max_mana_percent", "crit_percent"), "Untoter, schwerer Stoff: Attuned … of the Eagle")]
COMPARE = [("grug_gear:chest_metal_iron", ("str", "armor_rating")),
           ("grug_gear:legs_metal_iron", ("str", "armor_rating")),
           ("grug_gear:chest_metal_steel", ("max_hp_percent", "str")),
           ("grug_gear:legs_metal_steel", ("max_hp_percent", "str")),
           ("grug_gear:chest_metal_abyssal_steel", ("armor_rating", "max_hp_percent")),
           ("grug_gear:legs_metal_abyssal_steel", ("armor_rating", "max_hp_percent")),
           ("grug_gear:chest_leather_cured", ("dex", "dodge_percent")),
           ("grug_gear:legs_leather_cured", ("dex", "dodge_percent")),
           ("grug_gear:chest_leather_scaled", ("crit_percent", "max_mana_percent")),
           ("grug_gear:legs_leather_scaled", ("crit_percent", "max_mana_percent")),
           ("grug_gear:chest_cloth_heavy", ("int", "max_mana_percent")),
           ("grug_gear:legs_cloth_heavy", ("int", "max_mana_percent")),
           ("grug_gear:chest_cloth_silk", ("max_mana_percent", "crit_percent")),
           ("grug_gear:legs_cloth_silk", ("max_mana_percent", "crit_percent")),
           ("grug_gear:sword_steel", ("str", "crit_percent")),
           ("grug_gear:greataxe_iron", ("attack_speed_percent", "max_hp_percent")),
           ("grug_gear:staff_bronze", ("int", "max_mana_percent")),
           ("grug_gear:bow_iron", ("dex", "attack_speed_percent")),
           ("grug_gear:shield_bronze", ("str", "armor_rating")),
           ("grug_gear:dagger_embersteel", ("dex", "crit_percent"))]


def doll_pair(race, line, bracket, pair, worn):
    """Front and back of the plain set and of the enchanted set."""
    plain, _ = body(race, line, bracket, ("-", "-"), worn)
    enchanted, _ = body(race, line, bracket, pair, worn)
    return doll(plain), doll(enchanted)


def strip(images, gap=6):
    width = sum(i.width for i in images) + gap * (len(images) - 1)
    out = Image.new("RGBA", (width, max(i.height for i in images)), (0, 0, 0, 0))
    x = 0
    for image in images:
        out.alpha_composite(image, (x, 0))
        x += image.width + gap
    return out


def main():
    out_path = Path(sys.argv[1])
    old_rev = sys.argv[2] if len(sys.argv) > 2 else None
    pairs = all_pairs()
    opacity = int(re.search(r"ENCHANT_OPACITY = (\d+)", COLORS_LUA).group(1))
    items, worn = emit(opacity, pairs)
    variants = [("N", "Neu (Vorschlag)", {}, items, worn),
                ("K", "Kleiner", scaled_masks(SMALLER), items, worn)]
    if old_rev:
        old_items, old_worn = emit(255, pairs)
        variants.insert(0, ("A", "Alt (Runde 1, volle Farbe)", old_masks(old_rev),
                            old_items, old_worn))

    def render_in(variant, text):
        texmod.use_variant(variant[2])
        try:
            return texmod.render(text)
        finally:
            texmod.use_variant(None)

    html = ["<title>Verzauberungsfarben Runde 2</title>", "<style>" + CSS + "</style>"]
    add = html.append
    add("<h1>Verzauberungsfarben, zweite Runde</h1>")
    add("<p class='muted'>Runde 31, Lane B, Stufe 1, zweiter Entwurf nach deiner Rückmeldung "
        "(„zu bunt gepixelt“): kleinere, ruhige Akzente statt gefärbter Flächen, 50 % Stärke. "
        "Noch nichts im Spiel; alle Bilder mit genau den Textur-Modifikatoren gerendert, die "
        "das Spiel später benutzt.</p>")

    # --- decisions -------------------------------------------------------------------
    add("<div class='card decide'><h2 style='margin-top:0'>Was du entscheiden sollst</h2><ol>"
        "<li><b>Variante</b> (Abschnitte 1 und 2): <b>N</b> „Neu“ (Vorschlag) oder "
        "<b>K</b> „Kleiner“? <b>A</b> „Alt“ steht nur zum Vergleich daneben.</li>"
        "<li><b>Gegenstände</b>, bei denen der Akzent noch stört oder zu schwach ist: "
        "bitte mit Nummer aus Abschnitt 5 (E1–E20) nennen.</li>"
        "<li><b>Die neun Farben</b> (Abschnitt 3, unverändert): bleiben sie so?</li>"
        "<li><b>Schwache Grafiken</b> (Abschnitt 6): reicht es, oder eine eigene Kunstrunde?</li>"
        "</ol></div>")
    add("<div class='card'><b>Was sich geändert hat:</b> Eine Gruppe ist jetzt ein schmaler "
        "Streifen: nur zusammenhängende Läufe aus mindestens zwei Pixeln, eine gefärbte Fläche "
        "behält nur ihren Rand, einzelne verstreute Pixel nie. Präfix (A) = ein Glanzlicht- "
        "oder Kantenstreifen, Suffix (B) = ein Beschlag (Griffwicklung, Riemen, Saum, Rand). "
        "Je Gruppe höchstens etwa 7 % des Inventarbilds und 4 % der Körperüberlagerung "
        "(Runde 1: 14–25 % bzw. 10–18 %); <b>K</b> nimmt davon 60 %. Die Farbe liegt mit "
        "50 % über dem Material.</div>")

    # --- 1: body -----------------------------------------------------------------------
    names = [v[0] for v in variants]
    add("<h2>1. Am Körper: %s</h2>" % " / ".join(names))
    add("<p>Je Figur von links: unverzaubert, dann %s, jeweils vorne und hinten, mit "
        "der Standard-Optik des Volks.</p>" %
        ", ".join("<b>%s</b> %s" % (v[0], v[1]) for v in variants))
    add("<div class='row'>")
    for race, line, bracket, pair, title in DOLLS:
        shown = None
        images = []
        for variant in variants:
            texmod.use_variant(variant[2])
            try:
                plain, enchanted = doll_pair(race, line, bracket, pair, variant[4])
            finally:
                texmod.use_variant(None)
            if shown is None:
                shown = plain
                images.append(plain)
            images.append(enchanted)
        picture = strip(images)
        add("<figure style='margin:0'><div class='tile'><img src='%s' alt='%s' width='%d'>"
            "</div><figcaption class='muted'>%s<br>unverzaubert · %s</figcaption></figure>" % (
                data_uri(scaled(picture, 5)), title, picture.width * 5, title,
                " · ".join(names)))
    add("</div>")

    # --- 2: inventory -----------------------------------------------------------------
    add("<h2>2. Im Inventar: unverzaubert / %s</h2>" % " / ".join(names))
    add("<p>Spalten: unverzaubert, dann die Varianten. Zeilen: Brust und Beine je Material, "
        "dann sechs Waffen und ein Schild. Links etwa Inventargröße, rechts groß.</p>")
    cells, captions = [], []
    for name, pair in COMPARE:
        cells.append(texmod.render(items[(name, ("-", "-"))]))
        for variant in variants:
            cells.append(render_in(variant, variant[3][(name, pair)]))
        base = name.split(":")[1].replace("_", " ")
        captions.append(display_name(base, pair))
    cols = 1 + len(variants)
    half = (len(COMPARE) + 1) // 2
    for part in (slice(0, half), slice(half, len(COMPARE))):
        sub = cells[part.start * cols:part.stop * cols]
        add("<div class='row'><div class='tile'><img src='%s' alt='Inventar klein'></div>"
            "<div class='tile scroll'><img src='%s' alt='Inventar groß'></div></div>" % (
                data_uri(grid(sub, cols, 3, pad=6)), data_uri(grid(sub, cols, 7, pad=8))))
        add("<p class='muted'>Zeilen: %s</p>" % "; ".join(
            "%d %s" % (i + 1 + part.start, c) for i, c in enumerate(captions[part])))

    # --- 3: colour table ----------------------------------------------------------------
    add("<h2>3. Die neun Farben (unverändert)</h2>")
    add("<p>Präfix färbt Gruppe A, Suffix Gruppe B. Rechts die Simulation für Rot-Grün-Schwäche "
        "(Deuteranopie, Protanopie) und Blau-Gelb-Schwäche (Tritanopie), nach Machado 2009.</p>"
        "<div class='scroll'><table><tr><th>#</th><th>Wert</th><th>Präfix / Suffix</th>"
        "<th>Farbe</th><th>normal</th><th>Deuteranopie</th><th>Protanopie</th>"
        "<th>Tritanopie</th></tr>")
    for i, stat in enumerate(STATS, 1):
        rgb = colorsci.hex2rgb(COLORS[stat])
        swatches = "".join("<td><span class='sw' style='background:%s'></span></td>" %
                           colorsci.rgb2hex(colorsci.cvd(rgb, k))
                           for k in ("normal", "deutan", "protan", "tritan"))
        add("<tr><td>%d</td><td>%s</td><td>%s / %s</td><td>%s <code>%s</code></td>%s</tr>" % (
            i, GERMAN[stat], AFFIX[stat][0], AFFIX[stat][1], COLOR_WORD[stat],
            COLORS[stat], swatches))
    add("</table></div>")
    worst = {}
    for kind in ("normal", "deutan", "protan", "tritan"):
        best = None
        for a, b in itertools.combinations(STATS, 2):
            d = min(colorsci.de2000(colorsci.cvd(colorsci.hex2rgb(COLORS[a]) * t, kind),
                                    colorsci.cvd(colorsci.hex2rgb(COLORS[b]) * t, kind))
                    for t in (1.0, 0.7))
            if best is None or d < best[0]:
                best = (d, a, b)
        worst[kind] = best
    add("<p class='muted'>Kleinster Farbabstand (CIEDE2000): " +
        "; ".join("%s %.0f (%s/%s)" % ({"normal": "normal", "deutan": "Deuteranopie",
                                        "protan": "Protanopie", "tritan": "Tritanopie"}[k],
                                       v[0], GERMAN[v[1]], GERMAN[v[2]])
                  for k, v in worst.items()) +
        ". Ab etwa 10 klar unterscheidbar; Ziel waren normal und Rot-Grün-Schwäche (die sehr "
        "seltene Tritanopie bringt 2 und 5 nah zusammen).</p>")
    probe = ["grug_gear:sword_steel", "grug_gear:chest_leather_cured",
             "grug_gear:chest_metal_abyssal_steel", "grug_gear:staff_bronze"]
    add("<h3>Jede Farbe an vier Gegenständen (Variante N)</h3><p class='muted'>Je Farbe zwei "
        "Spalten: links als Präfix (A), rechts als Suffix (B); Spaltenpaare = Farbnummern "
        "1–9. Zeilen: Stahlschwert, Leder-Brust, Abyssstahl-Brust, Bronzestab.</p>")
    cells = []
    for name in probe:
        for stat in STATS:
            cells.append(texmod.render(items[(name, (stat, "-"))]))
            cells.append(texmod.render(items[(name, ("-", stat))]))
    sheet = grid(cells, 18, 5, pad=3)
    add("<div class='tile scroll'><img src='%s' alt='Farben an Gegenständen'></div>" %
        data_uri(sheet))
    arr = np.array(sheet)
    for kind, title in (("deutan", "Deuteranopie"), ("protan", "Protanopie")):
        sim = arr.copy()
        sim[..., :3] = colorsci.cvd_image(arr[..., :3], kind)
        add("<p class='muted'>Dasselbe mit %s</p><div class='tile scroll'><img src='%s' "
            "alt='%s'></div>" % (title, data_uri(Image.fromarray(sim, "RGBA")), title))

    # --- 4: technique -------------------------------------------------------------------
    add("<h2>4. Technik (kurz)</h2><div class='card'>")
    add("<p>Je Textur eine Maskendatei <code>&lt;textur&gt;_ench.png</code> (oben Gruppe A, "
        "unten Gruppe B). Das Spiel hängt nur bei Verzauberung etwas an das Bild an:</p>")
    add("<p><code>%s</code></p>" % items[("grug_gear:sword_steel", ("str", "crit_percent"))])
    add("<p>Ohne Verzauberung bleibt das Bild Byte für Byte gleich. Die Masken leitet ein "
        "Skript aus den Farbgruppen jeder Textur ab, ohne Handarbeit (185 Dateien).</p></div>")

    # --- 5: every item ------------------------------------------------------------------
    add("<h2>5. Alle Gegenstände (Variante N)</h2><p>Spalten = die sechs Stufen, Zeilen = "
        "unverzaubert und drei Beispiele aus den Werten der Familie. Links etwa "
        "Inventargröße, rechts groß.</p>")
    groups = []
    for title, key, pool in FAMILIES:
        groups.append((title, item_names(key), POOLS[pool]))
    for line in ("metal", "leather", "cloth"):
        for slot in ("head", "chest", "legs", "feet"):
            names_ = ["grug_gear:%s_%s_%s" % (slot, line, g) for g in GRADES[line]]
            groups.append(("%s: %s" % (LINE_DE[line], SLOT_DE[slot]), names_,
                           POOLS[line + "_armor"]))
    for number, (title, names_, pool) in enumerate(groups, 1):
        rows = [("-", "-")] + sample_pairs(pool)
        cells = [texmod.render(items[(name, pair)]) for pair in rows for name in names_]
        labels = ", ".join(display_name("…", p) for p in rows[1:])
        add("<h3>E%d %s</h3><p class='muted'>Beispiele: %s</p>" % (number, title, labels))
        add("<div class='row'><div class='tile'><img src='%s' alt='%s klein'></div>"
            "<div class='tile scroll'><img src='%s' alt='%s groß'></div></div>" % (
                data_uri(grid(cells, 6, 3, pad=6)), title,
                data_uri(grid(cells, 6, 6, pad=8)), title))

    # --- 6: weak items ------------------------------------------------------------------
    add("<h2>6. Grenzen der automatischen Masken</h2><div class='card'><ul>"
        "<li>Alle 185 Texturen teilt die neue Regel automatisch; keine Ausnahme-Tabelle "
        "mehr nötig.</li>"
        "<li><b>Stoffkapuze <i>Woven Hood</i></b> (Inventarbild nur ein 16-Pixel-Streifen) "
        "und die flachen <b>Stoffschuhe</b>: der Akzent ist nur 4 Pixel lang.</li>"
        "<li><b>Sturmgewebe-Brust (Stoff 6) am Körper</b>: nur ein kleines Medaillon, der "
        "Akzent fällt kaum auf.</li>"
        "<li>Auf <b>Kettenhemden</b> (Stahl) und verrauschtem <b>Stoff</b> findet die Regel "
        "nur kurze Stücke; der Akzent sitzt dort, wo die Grafik eine hellste Kante hat, "
        "nicht immer an der „schönsten“ Stelle. Genau gesetzte Streifen (z. B. ein "
        "Gürtel, eine Klingenkante) bräuchten eine kleine Kunstrunde: je Textur zwei "
        "handgemalte Masken.</li>"
        "<li><b>Weiß</b> (Rüstungswert) ist auf hellem Stahl schwach, <b>Tiefrot</b> und "
        "<b>Indigo</b> auf Abyssstahl.</li></ul></div>")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(html), encoding="utf-8")
    print("wrote %s (%d bytes)" % (out_path, out_path.stat().st_size))


if __name__ == "__main__":
    main()

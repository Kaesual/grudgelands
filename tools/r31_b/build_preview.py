#!/usr/bin/env python3
"""Round 31 lane B stage 1: the enchant-colour preview page (German, for the
user's approval). Writes one self-contained HTML file (pictures as data: URIs).

Every gear picture is rendered from the texture strings that
grug_gear.enchant_image builds (tools/r31_b/portable_test.lua in `emit`
mode), through texmod.py's model of the engine's texture modifiers.

    python3 tools/r31_b/build_preview.py OUT.html
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
    pairs.update(DOLL_PAIRS)
    pairs.update(INTENSITY_PAIRS)
    pairs.update((s, "-") for s in STATS)
    pairs.update(("-", s) for s in STATS)
    return sorted(pairs)


DOLL_PAIRS = [("str", "armor_rating"), ("dex", "dodge_percent"), ("int", "max_mana_percent")]
INTENSITY_PAIRS = [("str", "crit_percent"), ("dodge_percent", "max_mana_percent")]


def emit(opacity, pairs):
    args = ["luajit", str(ROOT / "tools/r31_b/portable_test.lua"), str(ROOT), "emit",
            str(opacity)] + ["%s:%s" % p for p in pairs]
    lines = subprocess.run(args, check=True, capture_output=True, text=True).stdout.splitlines()
    items, worn = {}, {}
    for line in lines:
        parts = line.split("\t")
        if parts[0] == "item":
            items[(parts[1], tuple(parts[2].split(":")))] = parts[3]
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
    text = "grug_visuals_skin_%s.png" % race
    for slot in ["head", "chest", "legs", "feet"]:
        text += "^" + worn[(line, slot, bracket, pair)]
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


def main():
    out_path = Path(sys.argv[1])
    pairs = all_pairs()
    items, worn = emit(255, pairs)
    html = ["<title>Verzauberungsfarben Vorschau</title>", "<style>" + CSS + "</style>"]
    add = html.append
    add("<h1>Verzauberungsfarben an Waffen und Rüstung</h1>")
    add("<p class='muted'>Runde 31, Lane B, Stufe 1: nur Bilder, noch nichts im Spiel. "
        "Alle Bilder sind mit genau den Textur-Modifikatoren gerendert, die das Spiel "
        "später benutzt.</p>")

    # --- decisions -----------------------------------------------------------------
    add("<div class='card decide'><h2 style='margin-top:0'>Was du entscheiden sollst</h2><ol>"
        "<li><b>Die neun Farben</b> (Abschnitt A): passt jede, oder welche Nummer (1–9) "
        "soll anders werden? Besonders <b>9 Weiß</b> (Rüstungswert): auf hellem Stahl kaum "
        "zu sehen.</li>"
        "<li><b>Stärke</b> (Abschnitt C): <b>I</b> volle Farbe (Vorschlag, alle Bilder), "
        "<b>II</b> 75 % oder <b>III</b> 50 % (Material scheint durch).</li>"
        "<li><b>Welche Pixel</b>: Präfix färbt die <b>Glanzlichter</b> (Gruppe A), Suffix "
        "die <b>Beschläge</b> (Griff, Riemen, Saum; Gruppe B). Passt das, oder bei welchen "
        "Gegenständen soll es anders sein?</li>"
        "<li><b>Schwache Gegenstände</b> (Abschnitt F): Stoffkapuze <i>Woven Hood</i> "
        "(nur 16 Pixel), die dünnen Stoffschuhe, Sturmgewebe-Brust am Körper (nur ein "
        "Medaillon). Reicht das, oder brauchen sie neue Grafik (eigene Runde)?</li>"
        "<li><b>Körper</b> (Abschnitt D): Farben am getragenen Set so in Ordnung?</li>"
        "</ol></div>")

    # --- A: colour table -----------------------------------------------------------
    add("<h2>A. Die neun Farben</h2>")
    add("<p>Jeder Wert hat eine feste Farbe: das <b>Präfix</b> färbt Gruppe A, das "
        "<b>Suffix</b> Gruppe B. Die Spalten rechts zeigen, wie Menschen mit Rot-Grün-Schwäche "
        "(Deuteranopie, Protanopie) und Blau-Gelb-Schwäche (Tritanopie) die Farbe sehen "
        "(Simulation nach Machado 2009).</p><div class='scroll'><table><tr><th>#</th>"
        "<th>Wert</th><th>Präfix / Suffix</th><th>Farbe</th><th>normal</th><th>Deuteranopie</th>"
        "<th>Protanopie</th><th>Tritanopie</th></tr>")
    for i, stat in enumerate(STATS, 1):
        rgb = colorsci.hex2rgb(COLORS[stat])
        cells = "".join("<td><span class='sw' style='background:%s'></span></td>" %
                        colorsci.rgb2hex(colorsci.cvd(rgb, k))
                        for k in ("normal", "deutan", "protan", "tritan"))
        add("<tr><td>%d</td><td>%s</td><td>%s / %s</td><td>%s <code>%s</code></td>%s</tr>" % (
            i, GERMAN[stat], AFFIX[stat][0], AFFIX[stat][1], COLOR_WORD[stat],
            COLORS[stat], cells))
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
    add("<p class='muted'>Kleinster Farbabstand (CIEDE2000, volle und 70-%-Helligkeit): " +
        "; ".join("%s %.0f (%s/%s)" % ({"normal": "normal", "deutan": "Deuteranopie",
                                        "protan": "Protanopie", "tritan": "Tritanopie"}[k],
                                       v[0], GERMAN[v[1]], GERMAN[v[2]])
                  for k, v in worst.items()) +
        ". Ab etwa 10 sind zwei Farben nebeneinander klar unterscheidbar. Ziel war "
        "normal und Rot-Grün-Schwäche; bei der sehr seltenen Tritanopie liegen 2 und 5 "
        "nah beieinander.</p>")

    # Every colour on three items, as prefix (A) and as suffix (B).
    probe = ["grug_gear:sword_steel", "grug_gear:chest_leather_cured",
             "grug_gear:chest_metal_abyssal_steel", "grug_gear:staff_bronze"]
    add("<h3>Jede Farbe an vier Gegenständen</h3><p class='muted'>Je Farbe zwei Spalten: "
        "links als Präfix (Glanzlichter), rechts als Suffix (Beschläge). Zeilen: Stahlschwert, "
        "Leder-Brust, Abyssstahl-Brust, Bronzestab.</p>")
    cells = []
    for name in probe:
        for stat in STATS:
            cells.append(texmod.render(items[(name, (stat, "-"))]))
            cells.append(texmod.render(items[(name, ("-", stat))]))
    sheet = grid(cells, 18, 4, pad=2)
    add("<div class='tile scroll'><img src='%s' alt='Farben an Gegenständen'></div>" % data_uri(sheet))
    add("<p class='muted'>Nummern der Spaltenpaare = Farbnummern 1–9 der Tabelle.</p>")
    add("<h3>Dieselben Gegenstände mit Rot-Grün-Schwäche</h3>")
    arr = np.array(sheet)
    for kind, title in (("deutan", "Deuteranopie"), ("protan", "Protanopie")):
        sim = arr.copy()
        sim[..., :3] = colorsci.cvd_image(arr[..., :3], kind)
        add("<p class='muted'>%s</p><div class='tile scroll'><img src='%s' alt='%s'></div>" % (
            title, data_uri(Image.fromarray(sim, "RGBA")), title))

    # --- B: technique ----------------------------------------------------------------
    add("<h2>B. Technik (kurz)</h2><div class='card'>")
    add("<p>Jede Textur bekommt eine Maskendatei <code>&lt;textur&gt;_ench.png</code> "
        "(doppelt so hoch: oben Gruppe A, unten Gruppe B, Graustufen = Schattierung). "
        "Das Spiel hängt nur bei Verzauberung an das Bild an:</p>")
    example = items[("grug_gear:sword_steel", ("str", "crit_percent"))]
    add("<p><code>%s</code></p>" % example)
    add("<p>Ohne Verzauberung bleibt das Bild Byte für Byte gleich. Masken wurden "
        "automatisch aus den Farbgruppen jeder Textur abgeleitet (185 Dateien, 33 KB).</p></div>")

    # --- C: intensity --------------------------------------------------------------
    add("<h2>C. Stärke der Farbe</h2><p>Zeilen: <b>I</b> volle Farbe, <b>II</b> 75 %, "
        "<b>III</b> 50 %. Spalten: Stahlschwert, Glutstahl-Dolch, Leder-Brust, Stahl-Helm, "
        "Bronzeschild, Silberstahl-Beine.</p>")
    show = ["grug_gear:sword_steel", "grug_gear:dagger_embersteel", "grug_gear:chest_leather_cured",
            "grug_gear:head_metal_steel", "grug_gear:shield_bronze", "grug_gear:legs_metal_silversteel"]
    cells = []
    for opacity in (255, 191, 128):
        its, _ = emit(opacity, INTENSITY_PAIRS)
        for name in show:
            for pair in INTENSITY_PAIRS:
                cells.append(texmod.render(its[(name, pair)]))
    add("<div class='tile scroll'><img src='%s' alt='Stärke'></div>" %
        data_uri(grid(cells, len(show) * 2, 6, pad=4)))
    add("<p class='muted'>Je Gegenstand zwei Beispiele: <i>Heavy … of the Eagle</i> "
        "(Tiefrot/Gelb) und <i>Elusive … of the Raven</i> (Lavendel/Himmelblau).</p>")

    # --- D: paper dolls --------------------------------------------------------------
    add("<h2>D. Am Körper</h2><p>Aktuelle Haut (die neuen Ebenen aus Lane A sind noch nicht "
        "dabei), vorne und hinten, jeweils unverzaubert und mit einem ganz verzauberten Set "
        "(alle vier Teile dieselben zwei Farben).</p>")
    dolls = [("human", "metal", 6, ("str", "armor_rating"), "Mensch, Abyssstahl: Heavy … of the Tortoise"),
             ("orc", "metal", 3, ("str", "armor_rating"), "Ork, Stahl: Heavy … of the Tortoise"),
             ("elf", "leather", 4, ("dex", "dodge_percent"), "Elf, Schuppenleder: Quick … of the Cat"),
             ("dwarf", "cloth", 5, ("int", "max_mana_percent"), "Zwerg, Seide: Clever … of the Raven"),
             ("undead", "cloth", 3, ("int", "max_mana_percent"), "Untoter, schwerer Stoff: Clever … of the Raven"),
             ("troll", "leather", 2, ("dex", "dodge_percent"), "Troll, gegerbtes Leder: Quick … of the Cat")]
    add("<div class='row'>")
    for race, line, bracket, pair, title in dolls:
        plain, _ = body(race, line, bracket, ("-", "-"), worn)
        enchanted, _ = body(race, line, bracket, pair, worn)
        both = Image.new("RGBA", (34 * 2 + 6, 32), (0, 0, 0, 0))
        both.alpha_composite(doll(plain), (0, 0))
        both.alpha_composite(doll(enchanted), (40, 0))
        add("<figure style='margin:0'><div class='tile'><img src='%s' alt='%s' width='%d'>"
            "</div><figcaption class='muted'>%s<br>links unverzaubert, rechts verzaubert"
            "</figcaption></figure>" % (data_uri(scaled(both, 6)), title, 74 * 6, title))
    add("</div>")

    # --- E: every item -----------------------------------------------------------------
    add("<h2>E. Alle Gegenstände</h2><p>Je Familie: Spalten = die sechs Stufen "
        "(Bronze … Abyssstahl bzw. die sechs Stoff-/Ledergrade), Zeilen = unverzaubert und "
        "drei Beispiele aus den Werten, die diese Familie wirklich bekommen kann. Links etwa "
        "Inventargröße, darunter groß.</p>")
    groups = []
    for title, key, pool in FAMILIES:
        groups.append((title, item_names(key), POOLS[pool]))
    for line in ("metal", "leather", "cloth"):
        for slot in ("head", "chest", "legs", "feet"):
            names = ["grug_gear:%s_%s_%s" % (slot, line, g) for g in GRADES[line]]
            groups.append(("%s: %s" % (LINE_DE[line], SLOT_DE[slot]), names,
                           POOLS[line + "_armor"]))
    for title, names, pool in groups:
        rows = [("-", "-")] + sample_pairs(pool)
        cells = [texmod.render(items[(name, pair)]) for pair in rows for name in names]
        labels = ", ".join(display_name("…", p) for p in rows[1:])
        add("<h3>%s</h3><p class='muted'>Beispiele: %s</p>" % (title, labels))
        add("<div class='row'><div class='tile'><img src='%s' alt='%s klein'></div>"
            "<div class='tile scroll'><img src='%s' alt='%s groß'></div></div>" % (
                data_uri(grid(cells, 6, 3, pad=6)), title, data_uri(grid(cells, 6, 7, pad=8)), title))

    # --- F: weak items ---------------------------------------------------------------
    add("<h2>F. Auffällig und schwach</h2><div class='card'><ul>"
        "<li><b>Automatisch nicht teilbar, per Tabelle festgelegt</b> (keine neue Grafik): "
        "die sechs Streitäxte (A = Glanzlicht der Klinge, B = Schaft und Klingenrand), der "
        "Glutstahl-Schild, die Lederbeine und -schuhe der Stufe 1 (Light), die Stoffkapuze "
        "der Stufe 2.</li>"
        "<li><b>Stoffkapuze <i>Woven Hood</i></b>: das Inventarbild ist nur ein 16-Pixel-"
        "Streifen; jede Gruppe hat 4 Pixel.</li>"
        "<li><b>Stoffschuhe</b>: flache Streifen von 3–4 Pixeln Höhe; die Farbe ist sichtbar, "
        "aber klein.</li>"
        "<li><b>Sturmgewebe-Brust (Stoff 6) am Körper</b>: die Überlagerung ist nur ein "
        "kleines Medaillon, die Farbe fällt am Körper kaum auf.</li>"
        "<li><b>Weiß (Rüstungswert)</b> verschwindet auf hellem Stahl/Silberstahl, "
        "<b>Tiefrot</b> und <b>Indigo</b> sind auf Abyssstahl und Nachtschuppe dunkel.</li>"
        "</ul></div>")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(html), encoding="utf-8")
    print("wrote %s (%d bytes)" % (out_path, out_path.stat().st_size))


if __name__ == "__main__":
    main()

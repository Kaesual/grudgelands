#!/usr/bin/env python3
"""Build the self-contained, review-only before/after report from draft assets."""
from pathlib import Path
import base64
from functools import lru_cache
from io import BytesIO
import hashlib
import html
import json
import subprocess
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DROP = HERE / "drop01"
MAP = ROOT / "mods/PLAYER/grug_map"
OUT = ROOT / "docs/planning/map-icon-rework.html"
BASELINE = "0cb190ff"  # Last runtime before the approved map-art integration.


@lru_cache(maxsize=None)
def image_bytes(path):
    if path.is_relative_to(ROOT / "mods"):
        return subprocess.check_output(["git", "show", f"{BASELINE}:{path.relative_to(ROOT)}"], cwd=ROOT)
    return path.read_bytes()


def image_width(path):
    with Image.open(BytesIO(image_bytes(path))) as image:
        return image.width


def uri(path):
    return "data:image/png;base64," + base64.b64encode(image_bytes(path)).decode()


def img(path, cls="", alt=""):
    return f'<img src="{uri(path)}" class="{cls}" alt="{html.escape(alt)}" width="32" height="32">'


def old(key):
    return MAP / "textures" / ("grug_map_" + key + ".png")


def new(key):
    return DROP / "icons" / (key + ".png")


def rows():
    catalog = json.loads((DROP / "catalog.json").read_text())
    result = []
    def add(ident, key, title, desc, previous=None):
        result.append(dict(id=ident, key=key, title=title, desc=desc,
                           old=previous or [old(key)]))
    add("A01", "heading_gold_00", "Eigener Spieler", "Goldener Richtungspfeil; 16 Richtungen. Helle Kante und dunkle Silhouette statt zusätzlicher Fläche.")
    add("A02", "heading_cyan_00", "Gruppenmitglied", "Türkiser Richtungspfeil; 16 Richtungen. Gleiche Formensprache wie der eigene Spieler.")
    add("A03", "rim_cyan_00", "Gruppe außerhalb der Minimap", "Kompakter türkisfarbener Winkel am Kartenrand; ebenfalls 16 Richtungen.")
    states = [("available", "Verfügbar", "Ausrufezeichen in Gold: neue Quest annehmbar."),
              ("active", "In Arbeit", "Fragezeichen in Silber: angenommene Quest noch nicht abgabebereit."),
              ("ready", "Abgabebereit", "Fragezeichen in Gold: erfüllte Quest hier abgeben."),
              ("locked", "Gesperrt", "Ausrufezeichen in Grau: Quest noch nicht annehmbar.")]
    for story in (False, True):
        for i, (status, title, desc) in enumerate(states, 1):
            add(f"B{i+(4 if story else 0):02}", "quest_" + ("story_" if story else "") + status,
                ("Storyquest · " if story else "Quest · ") + title,
                desc + (" Der violette Stern kennzeichnet die Hauptgeschichte, ohne Kreisrahmen." if story else " Ohne Kreisrahmen."))
    notes = {
        "trainer_weaponsmith": "Ein einzelnes breites Schwert für den Waffenschmied.",
        "trainer_armorsmith": "Eine stählerne Brustplatte für den Rüstungsschmied.",
        "trainer_alchemist": "Grüner Trank als klarer Alchemie-Marker.",
        "trainer_tailor": "Rote Garnspule und Nadel für den Schneider.",
        "trainer_leatherworker": "Ockerfarbene Tierhaut für die Lederverarbeitung.",
        "trainer_woodcarver": "Holz und Stechbeitel für den Holzschnitzer, ohne losen Holzspan.",
        "trainer_goldsmith": "Goldring mit blauem Stein für den Goldschmied.",
        "housing_steward": "Haus und Schlüssel als Ansprechpartner für Housing und Claim Stone.",
        "repair": "Hammer und Amboss für Grudge-Free Repairs; reparierende Berufslehrer behalten ihr Berufssymbol.",
        "crownbinder": "Goldkrone über Amboss: Aufwertung von Ausrüstung mit einer Fallen Crown.",
        "decor_merchant": "Warme Laterne für den Händler kultureller Dekoration.",
        "innkeeper": "Holzkrug für einen Gastwirt als möglichen Heimatort.",
        "home": "Goldenes Dach für den aktuell gebundenen Heimatort, beim Gastwirt oder Claim Stone.",
        "waypoint": "Heller Stein mit cyanfarbener Rune für einen entdeckten Waystone.",
        "claim": "Violetter Obsidianstein für den eigenen Claim Stone als Reiseziel.",
        "start": "Einzelnes Haus mit türkisem Wimpel für eine Startsiedlung.",
        "capital": "Helle Burg mit blauen Dächern für eine Hauptstadt.",
        "village": "Drei kleine Häuser als Dorfgruppe.",
        "outpost": "Hölzerner Wachturm für einen Außenposten.",
        "fortress": "Schweres steinernes Tor mit roten Akzenten für eine PvP-Festung.",
        "war_camp": "Rotes Zelt mit Speeren für die Battlegrounds-Lager; diese sind inzwischen ebenfalls Bergbaulager.",
        "bandit": "Rote Kapuze, helle Augenpartie und dunkler Gesichtsschleier als Warnzeichen für ein Banditenlager.",
        "mirefolk": "Türkiser Fischmenschenkopf mit orangefarbener Flosse für ein Mirefolk-Lager.",
        "mine": "Dunkler Stolleneingang und Spitzhacke für Mine und Edelsteinlager.",
        "clash": "Gekreuzte Schwerter für Kampfplätze und den Rift-Boss-Marker.",
        "rare_den": "Große goldene Tierspur für den Unterschlupf eines seltenen Gegners; markiert den Ort, nicht dessen aktuelle Position.",
        "king": "Dreizackige Goldkrone für einen König.",
        "dragon": "Roter Drachenkopf im Profil: klare Schnauze, helle Hörner und geöffnetes Maul.",
        "mining_camp": "Dunkelbraunes Arbeitszelt mit einer hellen Spitzhacke im Vordergrund für ein Gilden-Bergbaulager.",
        "camp_construction": "Offenes Zeltgerüst mit wenig Stoff für ein Lager im Aufbau.",
    }
    for row in sorted(catalog["illustrative"], key=lambda r:r["id"]):
        if row["id"].startswith("E") and not any(r["id"].startswith("D") for r in result):
            previous = [ROOT / f"mods/PLAYER/grug_mounts/textures/grug_mounts_icon_{race}.png"
                        for race in ("human", "dwarf", "elf", "orc", "undead", "troll")]
            add("D01–D06", "riding", "Ein Reitlehrer-Icon für alle", "Ein braunes Pferd in Seitenansicht ersetzt die bisherigen sechs Reittier-Icons. Gemeinsames Motiv für alle Völker und beide Karten.", previous)
        previous = None
        if row["key"] == "claim":
            previous = [ROOT / "mods/BASE/default/textures/default_obsidian_block.png"]
        add(row["id"], row["key"], row["title"], notes[row["key"]], previous)
    add("G01", "crosshair", "Genaues Questziel", "Vier offene Zielwinkel mit einem kleinen Mittelpunkt für Gesprächs-, Gegner- und Benutzungsziele einer ausgewählten Quest.")
    add("G02", "ring", "Quest-Zielgebiet", "Schlanke orange Kontur für das Zielgebiet. Dieser Kreis beschreibt eine Fläche auf der Karte; er ist kein Hintergrundrahmen um ein Icon.")
    return result


def main():
    items = rows()
    assert len(items) == 44
    absent = [r["key"] for r in items if not new(r["key"]).exists()]
    if absent:
        print("Pending:", ", ".join(absent))
    groups = {"A": "Spieler & Gruppe", "B": "Quests", "C": "Berufslehrer", "D": "Reitlehrer",
              "E": "Dienste & Reise", "F": "Orte & Bosse", "G": "Questziele"}
    cards, overview = [], []
    def current(row, cls=""):
        return img(new(row["key"]), cls, row["title"]) if new(row["key"]).exists() else '<span class="pending">In Arbeit</span>'
    for row in items:
        ident = row["id"]
        tint = " claim-tint" if row["key"] == "claim" else " ring-tint" if row["key"] == "ring" else ""
        olds = "".join(img(p, "large old" + tint, row["title"] + " vorher") for p in row["old"])
        native = "".join(img(p, "native" + (" old" if image_width(p) <= 32 else "") + tint, "Vorher") for p in row["old"])
        sizes = ", ".join(str(image_width(p)) for p in row["old"])
        extra = ""
        if ident.startswith("F"):
            key = {"mining_camp": "mine", "camp_construction": "war_camp"}.get(row["key"], row["key"])
            small = MAP / "art" / f"baked_{key}_mini.png"
            extra = f'<div class="mini-old">Bisherige Minimap-Grafik {img(small, "mini-source", "Altes 6-Pixel-Motiv")} <span>6 × 6 px → künftig dasselbe neue Motiv wie auf der Weltkarte</span></div>'
        frames = ""
        if ident.startswith("A"):
            family = row["key"][:-3]
            frames = '<details><summary>Alle 16 Richtungen</summary><div class="directions terrain">' + "".join(img(new(f"{family}_{i:02}"), "native", f"Richtung {i}") for i in range(16)) + '</div></details>'
        card = f'''<article id="{ident}" data-group="{ident[0]}" data-search="{html.escape((ident+' '+row['title']+' '+row['desc']).lower())}">
<div class="card-head"><a href="#{ident}" class="id">{ident}</a><span>{groups[ident[0]]}</span></div><h3>{row['title']}</h3>
<div class="comparison"><div><div class="caption">VORHER <small>Quelle: {sizes} px</small></div><div class="big-stage terrain old-stage">{olds}</div><div class="at-size terrain">{native}</div></div>
<div><div class="caption new-caption">ENTWURF 01 <small>Quelle: 32 × 32 px</small></div><div class="big-stage terrain">{current(row,'large')}</div><div class="at-size terrain">{current(row,'native')}</div></div></div>
<p>{row['desc']}</p><div class="surfaces">''' + "".join(f'<div class="surface {kind}">{current(row,"native")}<small>{label}</small></div>' for kind,label in [("grass","Gras"),("snow","Schnee"),("sand","Sand"),("water","Dunkel")]) + f'''</div>{extra}{frames}<details><summary>Datei &amp; Ausgangsbild</summary><p><a href="../../tools/map_icon_rework/drop01/icons/{row['key']}.png">32×32-PNG öffnen</a>'''
        if (DROP / "svg" / (row["key"] + ".svg")).exists():
            card += f' · <a href="../../tools/map_icon_rework/drop01/svg/{row["key"]}.svg">SVG-Quelle</a>'
        card += '</p></details></article>'
        cards.append(card)
        overview.append(f'<a class="overview-item" href="#{ident}" data-group="{ident[0]}" title="{html.escape(row["title"])}">{current(row,"native")}<small>{ident}</small><span>{row["title"]}</span></a>')
    nav=''.join(f'<button data-filter="{key}">{label}</button>' for key,label in groups.items())
    css=(HERE/'review.css').read_text()
    script=(HERE/'review.js').read_text()
    sha=BASELINE
    preserved=''.join(f'<div>{img(path,"native",title)}<span>{title}</span></div>' for path,title in [
        (old('mail_1'),'Postsymbol'), (ROOT/'mods/CORE/grug_ambience/textures/grug_ambience_note.png','Musiknote'),
        (old('daytime_00'),'Tageszeitband'),(old('minimap_bezel'),'Minimap-Rahmen')])
    # Match the runtime recipes in sRGB: Claim Stone colorize 70/255,
    # quest ring multiply #ff8c1a and opacity 190/255.
    claim_mix = 70 / 255
    claim_channels = "".join(f'<feFunc{c} type="linear" slope="{1-claim_mix}" intercept="{claim_mix*v/255}"/>' for c,v in zip("RGB", (122,92,192)))
    filters = f'<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" style="position:absolute"><defs><filter id="claim-tint" color-interpolation-filters="sRGB"><feComponentTransfer>{claim_channels}</feComponentTransfer></filter><filter id="ring-tint" color-interpolation-filters="sRGB"><feComponentTransfer><feFuncR type="linear" slope="1"/><feFuncG type="linear" slope="{140/255}"/><feFuncB type="linear" slope="{26/255}"/><feFuncA type="linear" slope="{190/255}"/></feComponentTransfer></filter></defs></svg>'
    doc=f'''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Grudgelands · Map-Icons · Vorher / Nachher</title><style>{css}</style><body data-bg="grass">{filters}<main>
<header><div class="eyebrow">GRUDGELANDS / MAP-ICONS / ENTWURF 01 / 27.10.2026</div><h1>Eine gemeinsame<br><em>Bildsprache für die Karte.</em></h1><p class="lead">44 neue Motive. Durchgehend 32 × 32 Pixel. Transparente Silhouetten statt Kreis- und Kastenrahmen. Hier vergleichst du den bisherigen Bestand mit dem vollständigen ersten Entwurf.</p><div class="intro-note"><strong>Für die erste Integration freigegeben — noch nicht im Spiel.</strong><span>Die kleinen Ansichten zeigen die tatsächlichen 32×32-Dateien. Die großen Bilder vergrößern genau diese Dateien auf 96 px, nicht die hochauflösenden Ausgangsbilder.</span></div><div class="highlights"><span>01 · Ein braunes Pferd für alle Reitlehrer</span><span>02 · Neuer Drachenkopf im Profil</span><span>03 · Ein Motiv für Weltkarte &amp; Minimap</span></div></header>
<div class="toolbar"><div class="controls"><label>Hintergrund <select id="background"><option value="grass">Gras</option><option value="snow">Schnee</option><option value="sand">Sand</option><option value="water">Dunkel / Wasser</option><option value="checker">Transparenzraster</option></select></label><label>Kleine Ansicht <select id="scale"><option value="32">32 px · 1:1</option><option value="24">24 px</option><option value="16">16 px · Belastungsprobe</option></select></label><label class="search">Suchen <input id="search" type="search" placeholder="ID, Motiv oder Verwendung …"></label></div><div class="filters"><button data-filter="all" class="active">Alle <span>44</span></button>{nav}</div><p class="tool-note">Die Hintergründe sind Vergleichsflächen, keine Spielaufnahme. Die Auswahl verändert nur diese Vorschau.</p></div>
<section id="overview"><div class="section-title"><h2>Das Set im Zusammenhang</h2><p>Ein Klick springt zum Vergleich.</p></div><div class="overview terrain">{''.join(overview)}</div></section>
<section id="comparisons"><div class="section-title"><h2>Vorher / Nachher</h2><p>Feedback gern mit den bisherigen IDs, z. B. „F13“ oder „B01–B08“.</p></div><p id="empty" hidden>Keine passenden Einträge.</p><div class="cards">{''.join(cards)}</div></section>
<section class="closing"><h2>Was bleibt — und was als Nächstes kommt</h2><p>Postsymbol, Musiknote und Tageszeit-Anzeige bleiben auf deinen Wunsch unverändert. Der Minimap-Rahmen ist ebenfalls kein neu entworfenes Kartenmotiv.</p><div class="preserved">{preserved}</div><p>Die alten ungenutzten Dateien für Kochlehrer und Zonenmarker bekommen keinen Ersatz. Die sechs Reitlehrer-Icons werden zu einem gemeinsamen Motiv zusammengeführt.</p><div class="next"><strong>Schritt 2: Anordnung</strong><p>Deine Idee ist festgehalten: Icons möglichst nahe an ihren tatsächlichen Orten so verschieben, dass sich ihre gefüllten Pixel nicht überlappen; transparente Bereiche dürfen sich überdecken. Diese Seite verändert keine Kartenpositionen. Die vereinbarte Umsetzung mit maximal 16 Pixel Verschiebung ist im <a href="round64-plan.md">Plan für Runde 64</a> festgehalten.</p></div></section>
<footer><p>Vergleichsstand: 0.63.0 / {sha}. Vollständige Bestandsaufnahme: <a href="map-icon-inventory.html">bisherige Icon-Übersicht</a>. Die Umsetzung der gemeinsamen Marker auf Weltkarte und Minimap steht noch aus.</p><p>Erstellung: OpenAI built-in Imagegen, ein Auftrag je illustrativem Motiv; geometrische Symbole als eigene SVGs. Export als transparente 32×32-PNGs. <a href="../../tools/map_icon_rework/drop01/generated.json">Prompts &amp; Herkunft</a> · <a href="../../tools/map_icon_rework/drop01/catalog.json">Motivkatalog</a> · <a href="../../tools/map_icon_rework/drop01/license.txt">Lizenzhinweise</a>. Die freigegebenen 32×32-Dateien liegen im Repository; große Originale und frühere Varianten sind nur lokal archiviert. Diese Seite dokumentiert die Freigabe vor der Integration.</p></footer></main><script>{script}</script></body></html>'''
    OUT.write_text(doc)
    print(f'{OUT}: {len(items)} comparisons, {len(absent)} pending, {len(doc.encode())} bytes')
    manifest={r['id']:{'key':r['key'],'file':str(new(r['key']).relative_to(ROOT)),
                        'sha256':hashlib.sha256(new(r['key']).read_bytes()).hexdigest() if new(r['key']).exists() else None} for r in items}
    (DROP/'review-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    main()

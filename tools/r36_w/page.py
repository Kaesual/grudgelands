#!/usr/bin/env python3
"""Round 36 lane W phase 1: the German preview page of the decor pass.

    python3 tools/r36_w/page.py OUT_DIR

Reads OUT_DIR/items.json (tools/r36_w/render.py) and writes OUT_DIR/index.html:
the theme table, per sample the picture (before left, after right, the plans
underneath) with what changed, and the bench fix. No form; the user answers
in chat.
"""
import html
import json
import os
import sys

THEMES = [
    ("Dorf", "Bewohnter Weiler",
     "Brunnen mit Laterne, Bank am Brunnen, Werkecke (Werkbank, Holzstapel, Fass, Tisch), "
     "Blumenbeet, Vorräte, Laternenpfahl"),
    ("Außenposten", "Wachposten",
     "Bannerstange mit Fackel, Waffenständer, Vorräte, Laternenpfahl, Bank"),
    ("Mine", "Laufender Abbau",
     "Erzhaufen und Erzkarren vor dem Stollen, Stützholz-Stapel, Werkecke, Geräteständer, "
     "Laterne, Vorräte"),
    ("Banditenlager", "Räuberversteck",
     "Beutestapel, Unterstand mit Schlafmatten, Waffenständer, Palisadenrest mit "
     "umgestürzten Pfählen, Trockengestell (das Lagerfeuer bleibt die Mitte)"),
    ("Moorvolk-Lager", "Lager im Moor",
     "Trockengestelle (Seile beim Troll, sonst eine Haut), Körbe auf Schlamm, Totem, "
     "kalte Feuerstelle, Laterne"),
    ("Schlachtfeld", "Überreste einer Schlacht",
     "zerbrochene Palisade, Bannerstange, umgeworfenes Banner, Waffenständer, frische Gräber "
     "(eins mit Kerze), verbrannter Karren auf Asche, Trümmer. Die Mitte bleibt frei "
     "(Questobjekt, Kampf); Tombroad Ambush (Riss) bleibt in Phase 1 unberührt"),
    ("Rare-Platz", "Lager der Bestie",
     "Bau aus Felsen, Nest, Knochen, Kratzspuren im Boden, Reste eines Reisenden; je Tier "
     "passend (Spinne: Netze, Vogel: Nest, Wolf: Bau)"),
    ("Apex-Lager", "Edelsteinsucher-Camp",
     "Unterstände, Feuerstelle mit Bank, Sortiertisch, Erzhaufen und Karren vor dem Stollen, "
     "Werkecke, Vorräte, Laternen am Weg; die Probenwand bleibt"),
    ("Jedes Haus", "Kleine Handgriffe",
     "Fackel neben der Tür (wo noch keine hängt), Fass, zwei Fässer oder ein Topf neben der "
     "Tür, Blumen unter dem Fenster, Holzstapel oder Fass an einer Seitenwand"),
]

ITEMS = {
    "r20_anchor_016": ("Dorf", "Whitebridge Market Close", "Mensch",
                       "Presse und Blumen-Klötze weg; Brunnen, Bank, Werkecke an der Werkstatt, "
                       "Holzstapel am Backhaus, Blumenbeet, Vorräte, Laterne; die Häuser mit "
                       "Fackel, Fass und Blumen."),
    "r20_anchor_036": ("Außenposten", "Glassroot Gate", "Elf",
                       "Menhir und Steinbogen weg; Bannerstange, Waffenständer, Vorräte, "
                       "Laterne (Elfen-Hängelampe), Bank."),
    "r20_anchor_061": ("Mine", "Tarncut Mine", "Zwerg",
                       "Schutthaufen und liegende Stämme weg; Erzhaufen und Karren vor dem "
                       "Stollen, Stützholz, Werkecke, Geräteständer, Vorräte, Laterne."),
    "r20_anchor_060": ("Banditenlager", "Rainchar Camp", "Troll",
                       "Kisten-Block und Trog weg; Beutestapel, Unterstand, Waffenständer, "
                       "Palisadenrest am Rand, Trockengestell mit Seilen."),
    "r20_anchor_069": ("Moorvolk-Lager", "Blackreed Enclosure", "Untote",
                       "Grabstein und Kessel weg; Trockengestell mit Haut, Totem, Körbe auf "
                       "Schlamm, kalte Feuerstelle, Laterne."),
    "r20_anchor_073": ("Schlachtfeld", "Redcut Breach", "Ork",
                       "Ruine, Rampe, Gestell und Krüge weg; Palisadenrest, Bannerstange, "
                       "umgeworfenes Banner, Gräber, verbrannter Karren, Waffenständer, Trümmer."),
    "r20_anchor_092": ("Rare-Platz", "Whitefang's Cold Den", "Mensch",
                       "Steinhaufen, Felszahn, Stamm und Knochenreihe weg; Felsbau, Nest, "
                       "Knochen, Kratzspuren, Reste eines Reisenden."),
    "r20_anchor_089": ("Apex-Lager", "Wyrmglass Fault Camp", "Zwerg",
                       "Die Probenwand bleibt; zwei Unterstände, Feuerstelle mit Bank, "
                       "Sortiertisch, Erzhaufen, Karren, Werkecke, Vorräte, drei Laternen."),
    "start:dawnmere:-32,-32,34,-12": ("Startstadt, eine Straße", "Dawnmere, die Hütten-Gasse",
                                      "Mensch",
                                      "Die vier Hütten der Südgasse: Fass oder Topf an der Tür, "
                                      "Blumen unter den Fenstern, Holzstapel oder Fass an der "
                                      "Seitenwand. Die Türfackeln hatten sie schon."),
    "plot:highcourt:homes_house_gable,homes_house_hip,homes_house_lane,homes_tenement,"
    "homes_bakehouse": ("Hauptstadt, ein Häuserblock", "Highcourt, Wohnviertel", "Mensch",
                        "Die fünf Wohnhäuser (oben vorher, unten nachher), dieselben "
                        "Handgriffe. Die Bauplätze stehen im Spiel nebeneinander an der Gasse."),
}

BENCHES = {
    "start:dawnmere:-14,-5,14,5@4": ("Dawnmere", "Die beiden Bänke an den Enden der Wiese lagen "
                                     "quer: drei Stufen hintereinander, die entlang der Bank "
                                     "schauten. Jetzt laufen sie entlang der Wiese und schauen auf "
                                     "sie."),
    "start:stillgrave:-13,-1,13,6@4": ("Stillgrave", "Derselbe Fehler bei zwei Steinbänken am Hof; "
                                       "eine läuft jetzt quer, die andere schaut auf den Platz, an "
                                       "dem ein Bewohner wartet."),
    "plot:dur_brannoc:deep_hall_of_record@3": ("Tempel aller Hauptstädte",
                                               "Die Bänke im Tempel (Dur Brannoc, Lethariel, Nhal "
                                               "Veyr, Kezamba) schauten zum Mittelgang, also "
                                               "hintereinander. Jetzt schauen sie zum Altar "
                                               "(Dach abgeschnitten, oben vorher, unten nachher). "
                                               "Dazu eine Hofbank in Dur Brannoc, Nhal Veyr und Gor "
                                               "Drazhak, die entlang ihrer Länge schaute."),
}

DECISIONS = [
    "Passen die Themen je Art (Tabelle)? Was soll anders werden?",
    "Licht: eine Fackel an jeder Haustür ohne Licht plus ein bis drei Laternen je Ort. "
    "Genug, zu viel, zu wenig?",
    "Banner sind ein ganzer Wollblock am Mast (ein dünnes Tuch gibt es nicht). So lassen?",
    "Für Phase 2: dieselben Hausdetails auch an allen Häusern der Startstädte und Hauptstädte "
    "und an den Startgebiet-Orten (Runde 14/15)?",
]

MISSING = [
    "ein dünnes Banner- oder Fahnentuch (jetzt ein Wollblock)",
    "Waffen für Waffenständer (Speere, Schwerter, Schilde; jetzt Zaunpfosten als Schäfte)",
    "ein echtes Zelt (das Zelttuch der Cottages ist ein flacher Teppich)",
    "Schienen und ein Erzkarren (jetzt zwei liegende Stämme mit Schutt)",
    "Glut oder ein glimmendes Feuer (das Lagerfeuer ist der Aktivierungsblock der Banditenlager)",
    "ein Grabkreuz aus Holz und ein Blumenkasten fürs Fenster",
]

CSS = """
:root{--bg:#f6f4ef;--fg:#1d1c1a;--muted:#5e5a52;--card:#fff;--line:#ddd7cb;--pic:#181a1e;--acc:#7a4b1c}
@media (prefers-color-scheme:dark){:root{--bg:#141517;--fg:#ebe7df;--muted:#a59f94;--card:#1d1f22;
--line:#33363b;--pic:#181a1e;--acc:#d9a35f}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);
font:16px/1.55 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:1180px;margin:0 auto;padding:24px 16px 64px}
h1{font-size:1.7rem;margin:.2em 0}h2{font-size:1.25rem;margin:2.2em 0 .6em;border-bottom:1px solid var(--line);
padding-bottom:.3em}h3{margin:0 0 .2em;font-size:1.05rem}.lead{color:var(--muted);max-width:60em}
table{border-collapse:collapse;width:100%;background:var(--card);border:1px solid var(--line)}
th,td{text-align:left;vertical-align:top;padding:8px 10px;border-bottom:1px solid var(--line)}
th{font-size:.85rem;color:var(--muted);font-weight:600}td:first-child{font-weight:600;white-space:nowrap}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px;margin:18px 0;overflow:hidden}
.card .txt{padding:12px 14px}.meta{color:var(--muted);font-size:.9rem}
.card a{display:block;background:var(--pic)}.card img{display:block;width:100%;height:auto}
.legend{display:flex;justify-content:space-around;color:#cfc8bb;background:var(--pic);font-size:.85rem;padding:4px 0}
ol li,ul li{margin:.3em 0}.tag{display:inline-block;font-size:.8rem;color:var(--acc);font-weight:600;
letter-spacing:.02em;text-transform:uppercase}
@media (max-width:640px){td:first-child{white-space:normal}}
"""


def esc(text):
    return html.escape(str(text), quote=True)


def card(entry, kind, name, race, text, legend=True):
    w, h = entry["size"]
    return ('<section class="card"><div class="txt"><span class="tag">%s</span><h3>%s</h3>'
            '<div class="meta">%s</div><p>%s</p></div>%s<a href="%s" target="_blank" rel="noopener">'
            '<img loading="lazy" src="%s" width="%d" height="%d" alt="%s vorher und nachher"></a>'
            '</section>' % (esc(kind), esc(name), esc(race), esc(text),
                            '<div class="legend"><span>vorher</span><span>nachher</span></div>'
                            if legend else "", esc(entry["image"]), esc(entry["image"]), w, h,
                            esc(name)))


def main():
    out = sys.argv[1]
    with open(os.path.join(out, "items.json"), encoding="utf-8") as fh:
        items = {e["item"]: e for e in json.load(fh)}
    body = ['<h1>Runde 36 · Deko-Durchgang, Phase 1</h1>',
            '<p class="lead">Ein Deko-Baukasten (Stücke je Rasse aus den Paletten der Startstädte, '
            'dazu Regeln für kleine Handgriffe an jedem Haus) und ein Thema je Art. Hier je Art '
            'ein Beispiel in seiner eigenen Rasse, links vorher, rechts nachher, darunter der '
            'Grundriss. Größe, Lage, Wege, Schutzbereich und NPC-Plätze bleiben gleich; die '
            'sinnlosen Steinformationen sind weg. Die Bilder sind Vorschauen aus den Bauplänen '
            '(Matten, Töpfe und Laternen sehen im Spiel feiner aus). Klick öffnet groß.</p>',
            '<h2>Themen je Art</h2><table><tr><th>Art</th><th>Thema</th><th>Stücke</th></tr>']
    for kind, theme, pieces in THEMES:
        body.append('<tr><td>%s</td><td>%s</td><td>%s</td></tr>' % (esc(kind), esc(theme), esc(pieces)))
    body.append('</table><h2>Beispiele</h2>')
    for key, (kind, name, race, text) in ITEMS.items():
        if key in items:
            body.append(card(items[key], kind, name, "Rasse: " + race, text,
                             legend=not key.startswith("plot:")))
    body.append('<h2>Bänke aus Treppenstufen</h2><p class="lead">Alle Startstädte und Hauptstädte '
                'automatisch geprüft (jede Sitzstufe, die entlang ihrer eigenen Bank schaut). '
                'Gefunden und behoben:</p>')
    for key, (name, text) in BENCHES.items():
        if key in items:
            body.append(card(items[key], "Bankfix", name, "", text,
                             legend=not key.startswith("plot:")))
    body.append('<h2>Was es als Block nicht gibt</h2><ul>%s</ul>'
                % "".join('<li>%s</li>' % esc(m) for m in MISSING))
    body.append('<h2>Deine Entscheidungen</h2><ol>%s</ol><p class="lead">Antwort bitte im Chat, '
                'gern mit Nummer.</p>' % "".join('<li>%s</li>' % esc(d) for d in DECISIONS))
    page = ('<!doctype html><html lang="de"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>Deko-Durchgang Phase 1</title><style>%s</style></head><body><main>%s</main>'
            '</body></html>' % (CSS, "\n".join(body)))
    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as fh:
        fh.write(page)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Build the implementation review from actual-template captures and core exports."""
from pathlib import Path
import base64
import hashlib
import html
import json
import math
import re
HERE = Path(__file__).resolve().parent
DATA = json.loads((HERE / 'registrar/cores.json').read_text())
TITLES = {'highcourt': 'Highcourt', 'dur_brannoc': 'Dur Brannoc', 'lethariel': 'Lethariel',
          'gor_drazhak': 'Gor Drazhak', 'nhal_veyr': 'Nhal Veyr', 'kezamba': 'Kezamba'}
COLORS = {'built': '#59636a', 'paving': '#9b967d', 'ground': '#3b6447',
          'tree': '#284b37', 'water': '#254b69', 'empty': '#18212a'}

def embed(path, caption):
    kind = 'svg+xml' if path.suffix == '.svg' else 'png'
    return (f'<figure><img alt="{html.escape(caption)}" src="data:image/{kind};base64,'
            + base64.b64encode(path.read_bytes()).decode() + '"><figcaption>'
            + html.escape(caption) + '</figcaption></figure>')

def capture(lane, key, caption):
    path = HERE / lane / 'renders' / (key + '.png')
    receipt = json.loads(path.with_suffix('.json').read_text())
    scene = (HERE / lane / 'scenes.html').read_text()
    payload = json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>', scene, re.S)[1])
    assert receipt['input'] == payload['scenes'][key]['digest']
    assert receipt['output'] == hashlib.sha256(path.read_bytes()).hexdigest()
    return embed(path, caption)

rows = {}
for key, title in TITLES.items():
    city = DATA[key]
    lo, hi = city['bounds']['min'], city['bounds']['max']
    sockets = city['landmarks']['sockets']
    registrar = next(s for s in sockets if s['id'] == 'expedition_registrar')
    waypoint = next(s for s in sockets if s['id'] == 'travel_waypoint')
    plaza = city['landmarks']['waypoint_plaza']
    rects = []
    for iz, row in enumerate(city['raster']):
        for ix, (kind, *_) in enumerate(row):
            rects.append(f'<rect x="{ix}" y="{hi["z"]-lo["z"]-iz}" width="1.02" height="1.02" fill="{COLORS[kind]}"/>')
    def pos(x, z): return x-lo['x'], hi['z']-z
    px, pz = pos(plaza['min']['x']-1.5, plaza['max']['z']+1.5)
    rects.append(f'<rect x="{px}" y="{pz}" width="{plaza["max"]["x"]-plaza["min"]["x"]+3}" height="{plaza["max"]["z"]-plaza["min"]["z"]+3}" fill="none" stroke="#f7dba1" stroke-width=".5"/>')
    for label, point, color in [('W', waypoint, '#83e3ef'), ('R', registrar, '#f0c275')]:
        x, z = pos(point['x'], point['z'])
        rects.append(f'<circle cx="{x}" cy="{z}" r="2.5" fill="{color}" stroke="#101820" stroke-width=".35"/><text x="{x}" y="{z+1.2}" text-anchor="middle" font-family="sans-serif" font-weight="bold" font-size="3.4" fill="#101820">{label}</text>')
    path = HERE / 'registrar' / (key + '-map.svg')
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2 {hi["x"]-lo["x"]+5} {hi["z"]-lo["z"]+5}">'+''.join(rects)+'</svg>')
    rows[key] = {'registrar': [registrar[a] for a in ('x','y','z')], 'face': registrar['face'],
                 'waystone': [waypoint[a] for a in ('x','y','z')],
                 'straight_distance': round(math.hypot(registrar['x']-waypoint['x'], registrar['z']-waypoint['z']),2)}
(HERE/'registrar/locations.json').write_text(json.dumps(rows,indent=2)+'\n')
page = '''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hauptstädte · umgesetzt</title><style>*{box-sizing:border-box}body{margin:0;background:#151e24;color:#e6ded0;font:17px/1.55 system-ui}main{max-width:1500px;margin:auto;padding:30px}h1,h2{font-family:Georgia;color:#e1be80}section{padding:24px 0;border-top:1px solid #435058}.pair,.maps{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}.maps{grid-template-columns:repeat(3,minmax(0,1fr))}figure{margin:0 0 20px;background:#28353c}img{width:100%;display:block}figcaption{padding:14px}a{color:#e1be80}p{max-width:1100px}.single{max-width:1100px}.note{color:#b7c5ca}@media(max-width:850px){.pair,.maps{grid-template-columns:1fr}main{padding:18px}}</style><main><h1>Hauptstädte · im Worktree umgesetzt</h1><p>Die freigegebenen Änderungen sind in den Spielvorlagen gespeichert. Diese Bilder stammen aus den tatsächlich installierten Templates im gemeinsamen Webrenderer. Die Geometrie ist für alle sechs Hauptstädte geprüft; die Detailbilder zeigen Highcourt.</p><p><strong>Neue Ergänzung:</strong> <a href="all_tables/index.html">Tischfix in allen weiteren Gebäuden</a> · <a href="beds/index.html">Dawnmere: Betten und Rückwand korrigiert</a></p><section><h2>1 · Dachanschlüsse geschlossen</h2><p>Auch die zusätzlich gemeldeten Lücken sind behoben: je 36 obere Platten an den beiden Giebelwänden wurden durch passende Dachblöcke ersetzt. Die Dachoberfläche bleibt gleich hoch.</p><div class="pair">'''
page += capture('castle','roof-before','Vorher · Lücken über der Giebelwand und unter dem First')
page += capture('castle','roof-final','Umgesetzt · geschlossene Anschlüsse und abgesenkter First')
page += '</div><p class="note">Identische Detailkamera; vordere Türme und hintere Dachabschnitte sind für den Blick auf den Giebel ausgeblendet.</p></section><section><h2>2 · Thron abgesenkt</h2><p>Die Sitzfläche liegt einen Block über dem Podest, die Armlehnen einen Block über dem Sitz.</p><div class="single">'
page += capture('castle','throne','Gespeicherte Thron-Geometrie')
page += '</div></section><section><h2>3 · Offene Säulenfelder</h2><p>Breite Öffnungen ersetzen die inneren Seitenwände. Die Pfeiler schließen an die äußeren Stützen an; die schmalen Durchgänge dahinter sind gefüllt. Lampen sitzen an den erhaltenen Pfeilern.</p><div class="single">'
page += capture('castle','pillars','Gespeicherte Seitenwand-Geometrie')
page += '</div><p class="note">Geometrie und Körperfreiraum geprüft. Das Verfolgen eines Spielers durch König und Wachen bleibt Teil des Tests im Spiel.</p></section><section><h2>4 · Torbögen richtig gedreht</h2><p>Je 14 Bogenstufen in fünf Hauptstadt-Torvorlagen sind umgedreht. Die seitlichen Aufgänge bleiben unverändert; Kezambas anders aufgebautes Tor brauchte keine Korrektur.</p><div class="single">'
page += capture('gates','gate-installed','Gespeicherter Torbogen')
page += '</div></section><section><h2>5 · Dünne Gildentische</h2><p>Vorhandene Holztische mit dünner Platte und verbundenen Beinen ersetzen die hohen beziehungsweise schwebenden Konstruktionen in allen sechs Gildenhäusern.</p><div class="single">'
page += capture('tables','human_actual','Gespeichertes Gildenhaus · Tische und Clerk')
page += '</div></section><section><h2>6 · Registrar am Waystone-Zugang</h2><p><strong>R</strong> = neuer Registrar · <strong>W</strong> = Waystone. Die helle Umrandung zeigt den freigehaltenen Ankunftsplatz einschließlich seiner Einfassung. Standfläche, Blickrichtung und Erreichbarkeit sind anhand der erzeugten Hauptstadt-Geometrie geprüft. Der Clerk im Gildenhaus bleibt ein gewöhnlicher Bewohner.</p><div class="maps">'
for key,title in TITLES.items():
    page += embed(HERE/'registrar'/(key+'-map.svg'), title+' · '+str(rows[key]['straight_distance']).replace('.',',')+' Blöcke Luftlinie zum Waystone')
page += '</div></section><p class="note">Nur im Worktree character-creation. Map Reset für das spätere Deployment deklariert. Kein Merge, Push oder Eingriff in main. Desktop- und Web-Spieltests bleiben offen.</p><p><a href="castle/scenes.html">Interaktive Schlossansichten</a> · <a href="../index.html">Freigegebener ursprünglicher Entwurf</a></p></main></html>'
(HERE/'index.html').write_text(page)
print('Implementation gallery: checked six actual-template captures; six actual core maps.')

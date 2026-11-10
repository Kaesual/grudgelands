#!/usr/bin/env python3
"""Embed checked captures of the installed castles in an offline evidence page."""
from pathlib import Path
import base64
import hashlib
import json
import re
HERE=Path(__file__).resolve().parent
payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',(HERE/'scenes.html').read_text(),re.S)[1])
def image(key,caption):
    path=HERE/'renders'/(key+'.png')
    receipt=json.loads(path.with_suffix('.json').read_text())
    assert receipt['input']==payload['scenes'][key]['digest']
    assert receipt['output']==hashlib.sha256(path.read_bytes()).hexdigest()
    return '<figure><img alt="'+caption+'" src="data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()+'"><figcaption>'+caption+'</figcaption></figure>'
page='''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Schlösser · umgesetzt</title><style>body{margin:30px;background:#172127;color:#e8dfce;font:17px/1.5 system-ui}h1,h2{font-family:Georgia;color:#e1be80}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0 0 24px;background:#28353c}img{width:100%;display:block}figcaption{padding:14px}a{color:#e1be80}.wide{max-width:1280px}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style><h1>Schlösser · im Worktree umgesetzt</h1><p>Aufnahmen aus den gespeicherten Gebäude-Templates im gemeinsamen Webrenderer.<br>Die Änderungen gelten für alle sechs Hauptstädte; gezeigt ist Highcourt.</p><p><a href="scenes.html">Interaktive Ansichten</a></p><h2>Dachanschlüsse und First</h2><p>Links die frühere Geometrie, rechts die Umsetzung bei gleicher Kamera. Für den Blick auf den Giebel sind die vorderen Türme und hinteren Dachabschnitte ausgeblendet.</p><div class="pair">'''
page+=image('roof-before','Vorher · halbe Blocklücken über der Giebelwand und unter dem First.')
page+=image('roof-final','Umgesetzt · Dachabschluss geschlossen, First um einen halben Block abgesenkt.')
page+='</div><h2>Thron und Seitenwände</h2><div class="pair">'
page+=image('throne','Sitzfläche einen Block über dem Podest, Armlehnen einen Block über dem Sitz.')
page+=image('pillars','Offene Seitenbuchten, angeschlossene Säulen und versetzte Lampen.')
page+='</div><h2>Gesamtansicht</h2><div class="wide">'+image('roof-overview','Repariertes Dach am vollständig gespeicherten Schloss.')+'</div><p>Dies sind Geometrie-Aufnahmen, keine Luanti-Client-Screenshots oder Wegfindungstests.</p></html>'
(HERE/'index.html').write_text(page)
print('Five capture input/output receipts checked; offline gallery saved.')

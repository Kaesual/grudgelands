#!/usr/bin/env python3
"""Embed receipt-checked bed fix captures."""
from pathlib import Path
import base64,hashlib,json,re
HERE=Path(__file__).resolve().parent
payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',(HERE/'scenes.html').read_text(),re.S)[1])
def fig(key,title):
 p=HERE/'renders'/(key+'.png');r=json.loads(p.with_suffix('.json').read_text())
 assert r['input']==payload['scenes'][key]['digest'] and r['output']==hashlib.sha256(p.read_bytes()).hexdigest()
 return '<figure><img alt="'+title+'" src="data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode()+'"><figcaption>'+title+'</figcaption></figure>'
html='''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dawnmere · Betten korrigiert</title><style>body{margin:30px;background:#162128;color:#e8decd;font:17px/1.6 system-ui}h1,h2{font-family:Georgia;color:#dfbd7f}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0;background:#27343c}img{width:100%;display:block}figcaption{padding:14px}a{color:#dfbd7f}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style><h1>Dawnmere · Die Betten bleiben im Gasthaus</h1><p>Beide Bettköpfe lagen bislang in der Rückwand. Die vollständigen Betten sind jetzt einen Block nach innen gerückt; die Wand und ihr Fensterrahmen sind wieder geschlossen.</p><p><a href="scenes.html">Interaktive Ansicht öffnen</a></p><h2>Außenansicht</h2><div class="pair">'''
html+=fig('before-outside','Vorher · Zwei Bettköpfe ersetzen Wandzellen und sind von außen sichtbar.')+fig('after-outside','Nachher · Rückwand und senkrechter Fensterrahmen wiederhergestellt.')
html+='</div><h2>Blick ins Zimmer</h2><p>Die obere Wand und das Dach sind für diesen Schnitt ausgeblendet. Jeweils die gleiche Kamera.</p><div class="pair">'
html+=fig('before-inside','Vorher · Die beiden Kopfenden belegen die Außenwand.')+fig('after-inside','Nachher · Beide Betten vollständig innen, gleicher Abstand zwischen den Betten.')
html+='</div><p>Direkt aus den gespeicherten Gebäudezellen gerendert. Sechs Zellen geändert; Türen, NPC-Punkte und Gebäudeabmessungen bleiben gleich. Die Aufnahmen zeigen den Bettfix vor der anschließenden allgemeinen Tischüberarbeitung.</p></html>'
(HERE/'index.html').write_text(html)
print('Four capture input/output hashes verified; gallery saved.')

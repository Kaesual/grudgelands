#!/usr/bin/env python3
"""Receipt-checked standalone actual-template table comparison gallery."""
import base64,hashlib,json,re
from pathlib import Path
HERE=Path(__file__).resolve().parent
payload=json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',(HERE/'scenes.html').read_text(),re.S)[1])
labels=[('dawnmere_field_cottage','Wohnhaus · Dawnmere'),('highcourt_homes_tavern','Taverne · Highcourt'),('dur_brannoc_deep_scriptorium','Schreibsaal · Dur Brannoc'),('highcourt_market','Markt · Highcourt'),('kezamba_moot_house','Erhöhte Tische · Kezamba'),('nhal_veyr_market_bonesmith','Werkstatt · Nhal Veyr')]
parts=['''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Gebäude · dünne Tische</title><style>*{box-sizing:border-box}body{margin:0;background:#142126;color:#dfddd0;font:16px/1.55 system-ui}main{max-width:1600px;margin:auto;padding:35px}h1,h2{font-family:Georgia;font-weight:400}h1{font-size:42px}p{max-width:90ch;color:#b9c5c2}a{color:#e5bd75}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin:20px 0 45px}figure{margin:0;background:#263338;border:1px solid #687570}img{width:100%;display:block}figcaption{padding:14px}b{color:#e7c992}small{color:#b9c5c2}nav{display:flex;gap:16px;flex-wrap:wrap}@media(max-width:850px){.pair{grid-template-columns:1fr}main{padding:20px}}</style><main><small>GRUDGELANDS · UMSETZUNG IM WORKTREE</small><h1>Dünne Tische in den Gebäuden</h1><p>575 weitere Tischzellen in 153 Gebäudevorlagen: Die hohen Kombinationen aus Zaun und halber Platte sind durch den bewährten vollständigen Holztisch ersetzt. Die sechs Gildenhäuser waren bereits korrigiert. Hier sechs Beispiele aus den tatsächlich gespeicherten Vorlagen.</p><p>Jedes Paar verwendet dieselbe Kamera und denselben Ausschnitt. Dach, obere Wände und teilweise der Rand des Gebäudes sind ausgeblendet, damit die Tischhöhe und die Stützen sichtbar werden. Andere Möbel, Gerüste und NPC-Plätze bleiben erhalten.</p><p><a href="scenes.html">Interaktive Szenen öffnen und frei drehen</a> · <a href="../beds/index.html">Dawnmere: Betten bleiben jetzt im Gasthaus</a></p><nav>''']
for key,label in labels:parts.append(f'<a href="#{key}">{label}</a>')
parts.append('</nav>')
for key,label in labels:
 parts.append(f'<h2 id="{key}">{label}</h2><div class="pair">')
 for variant,title in [('before','Vorher'),('after','Umgesetzt')]:
  name=key+'_'+variant;data=(HERE/'renders'/(name+'.png')).read_bytes();receipt=json.loads((HERE/'renders'/(name+'.json')).read_text())
  assert receipt['input']==payload['scenes'][name]['digest']
  assert receipt['output']==hashlib.sha256(data).hexdigest()
  assert (receipt['width'],receipt['height'])==(1280,900)
  parts.append(f'<figure><figcaption><b>{title}</b></figcaption><img loading="lazy" src="data:image/png;base64,{base64.b64encode(data).decode()}" alt="{label} – {title}"></figure>')
 parts.append('</div>')
parts.append('<p>Bei den erhöhten Gebäuden bleiben die Tischfüße auf ihrem vorhandenen Geschossboden. Die großen Plattenflächen auf den Baugerüsten wurden ausdrücklich nicht als Tische behandelt.</p><small>Rendering aus dem gemeinsamen Gebäude-Renderer; kein nativer Client-Screenshot. Quellen und Prüfbericht liegen neben dieser Galerie.</small></main></html>')
(HERE/'index.html').write_text(''.join(parts))
print('12 capture receipts verified; standalone gallery ready.')

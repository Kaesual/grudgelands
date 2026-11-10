#!/usr/bin/env python3
"""Layer the opening study onto the existing offline character preview."""
import base64
import hashlib
import json
import re
from pathlib import Path

HERE=Path(__file__).resolve().parent
OUT=HERE/'intro'
png=(OUT/'renders/intro.png').read_bytes()
receipt=json.loads((OUT/'renders/intro.json').read_text())
build=json.loads((OUT/'scene-build.json').read_text())['intro']
assert receipt['output']==hashlib.sha256(png).hexdigest()
assert receipt['input']==build['render_input']
page=(HERE/'preview.html').read_text()
# Preserve the accepted layout and all six character scenes. Only the opening
# state and review controls differ; the game files are deliberately untouched.
start=page.index('\nconst D=')+len('\nconst D=')
data,end=json.JSONDecoder().raw_decode(page[start:])
data['images']['background_intro']='data:image/png;base64,'+base64.b64encode(png).decode()
page=page[:start]+json.dumps(data,ensure_ascii=False,separators=(',',':'))+page[start+end:]
css='''
/* Opening state: a wide shared scene with no class or appearance controls. */
body[data-opening="true"] .stage{grid-column:2/-1}
body[data-opening="true"] .right,
body[data-opening="true"] .classes,
body[data-opening="true"] .stage-heading,
body[data-opening="true"] .rotate,
body[data-opening="true"] .footer .create,
body[data-opening="true"] .footer .summary{display:none}
body[data-opening="true"] .stage:after{background:linear-gradient(180deg,#08101505 40%,#08101535 66%,#081015ef 100%)}
body[data-opening="true"] #model{visibility:hidden}
body[data-opening="true"] .empty{justify-content:flex-end;padding:0 30px 40px;z-index:2;pointer-events:none;gap:12px}
body[data-opening="true"] .empty h3{font:clamp(32px,3.5vw,62px)/1.15 Georgia,serif;letter-spacing:.07em;color:#f0dfb9;text-shadow:0 3px 8px #000}
body[data-opening="true"] .empty p{font-size:12px;letter-spacing:.12em;color:#d1d3c8;max-width:none}
body[data-opening="true"] .empty .eyebrow{font-size:10px;letter-spacing:.3em;color:#d4be8f}
body[data-opening="true"] .art-note{display:none}
@media(max-width:900px){body[data-opening="true"] .stage{min-height:500px}body[data-opening="true"] .empty{padding:0 16px 30px}body[data-opening="true"] .landscape img{object-fit:contain!important;background:#182126}}
@media(max-width:560px){body[data-opening="true"] .stage{grid-column:1/-1;min-height:420px}}
'''
page=page.replace('</style></head>',css+'</style></head>')
page=page.replace('<body data-banner="side">','<body data-banner="side" data-opening="true">')
page=page.replace('Layout study 06','Opening study 03').replace('LAYOUTSTUDIE 06','AUFTAKT · ENTWURF 03')
page=re.sub(r'<a href="portraits.html">.*?<button id="notes">',
    '<a href="previous-v2/preview-1600.png">Voriger Auftakt</a><a href="scenes.html">Szene in 3D</a>'
    '<select hidden id="banner-mode"><option value="side">Side</option></select>'
    '<button hidden id="reset">Startansicht</button><button id="notes">',page,count=1)
page=page.replace('<div class="sigil">◇</div><h3>Who will you become?</h3><p>Choose a people on the left to see your character.</p>',
    '<div class="eyebrow">TWO FACTIONS · ONE WORLD</div><h3>Choose your fate</h3><p>Choose your people. Begin your story.</p>')
page=page.replace('async function chooseRace(id){if(id===race)return;race=id;',
    'async function chooseRace(id){if(id===race)return;document.body.dataset.opening="false";race=id;')
page=page.replace('function reset(){race=null;',
    'function reset(){if(race)return;document.body.dataset.opening="true";race=null;')
page=page.replace('else{$("landscape").innerHTML="";$("landscape").style.background="radial-gradient(ellipse at 50% 35%,#52665c,#152725 70%)"}',
    'else{$("landscape").innerHTML=`<img src="${D.images.background_intro}" alt="The Accord and The Throng strongholds with faction banners" style="width:100%;height:100%;object-fit:cover;display:block">`}')
page=re.sub(r'<dialog id="notes-dialog".*?</dialog>',
    '<dialog id="notes-dialog" lang="de"><h2>Auftakt · Entwurf 03</h2>'
    '<p>Volk anklicken: Die Szene wechselt zur Charaktererstellung. Danach führt keine Auswahl zum Auftakt zurück; zum erneuten Betrachten die Browserseite neu laden.</p>'
    '<p>Zwei eigenständige Wehrbauten aus vorhandenen Spielmaterialien: Steinbastion und hölzerne Kampfplattformen. Graben, beschädigte Sperren und Rauch zeigen eine Front. Die Lagerbanner sind dreifach vergrößert; die Partikelbilder für Rauch und Feuer stammen ebenfalls aus dem Spiel.</p>'
    '<p>Der Auftakt ist auch nativ im Worktree umgesetzt. Echte Luanti-Aufnahmen sind in ../native/index.html zu sehen.</p>'
    '<button id="close-notes">Schließen</button></dialog>',page,count=1,flags=re.S)
(OUT/'preview.html').write_text(page)
print('Built opening preview:',OUT/'preview.html')

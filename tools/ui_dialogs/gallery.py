#!/usr/bin/env python3
"""Build an offline, filterable index of the inspected real-client captures."""
import html
from pathlib import Path
import sys
root = Path(sys.argv[1])
cards = []
resolutions = sorted({path.parent.name for path in root.glob("*/*.png")})
options = "".join("<option>" + html.escape(value) + "</option>" for value in resolutions)
for path in sorted(root.glob('*/*.png')):
    resolution = path.parent.name
    scene, _, name = path.stem.partition('_')
    rel = path.relative_to(root).as_posix()
    cards.append(f'<a class="card" data-size="{html.escape(resolution)}" data-scene="{scene}" '
                 f'data-name="{name}" href="{rel}" target="_blank">'
                 f'<img loading="lazy" src="{rel}" alt="{html.escape(name)}">'
                 f'<span>{html.escape(name.replace("_", " "))}<small>{resolution} · {scene}</small></span></a>')
(root / 'index.html').write_text('''<!doctype html><html lang="de"><meta charset="utf-8">
<title>Grudgelands · Dialogreview im Client</title><meta name="viewport" content="width=device-width">
<style>body{background:#0b1217;color:#eeeae1;font:16px system-ui;margin:32px}h1{font-size:28px;font-weight:500;color:#d4b77d}p{max-width:900px;line-height:1.6;color:#b9c1bd}.filters{position:sticky;top:0;background:#0b1217ee;padding:16px 0;display:flex;gap:12px;z-index:1}select,input{background:#172127;color:#eeeae1;border:1px solid #59615c;border-radius:6px;padding:10px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(380px,1fr));gap:20px}.card{background:#101a20;border:1px solid #303d42;border-radius:8px;overflow:hidden;color:inherit;text-decoration:none}.card img{display:block;width:100%}.card span{display:block;padding:14px}.card small{float:right;color:#b9c1bd}[hidden]{display:none}</style>
<h1>Grudgelands · Dialogreview im Luanti-Client</h1>
<p>Echte Client-Aufnahmen des Atlas-Polish. Verschiedene Fenstergrößen bei GUI-Skalierung 1; zusätzliche Zustände und helle Aufnahmen bei GUI-Skalierung 1,5. Anklicken öffnet das Original in voller Auflösung. Testfiguren, Briefe und Inventare stammen aus isolierten Testwelten. Native Schriftgrößen bleiben von den Client-Einstellungen abhängig.</p><p>Diese Galerie belegt die Darstellung im Desktop-Client. Die abschließende Bedienungsprüfung im Desktop- und Web-Client bleibt beim Nutzer. Details zu Prüfläufen und verbleibenden Grenzen stehen im Implementierungsbericht.</p>
<div class="filters"><select id="size"><option value="">Alle Größen</option>''' + options + '''</select><select id="scene"><option value="">Hell und dunkel</option><option value="dark">Dunkel</option><option value="bright">Hell</option></select><input id="name" placeholder="Ansicht suchen …"></div><main>''' + '\n'.join(cards) + '''</main><script>
const size=document.querySelector('#size'),scene=document.querySelector('#scene'),name=document.querySelector('#name');
function filter(){document.querySelectorAll('.card').forEach(c=>c.hidden=(size.value&&c.dataset.size!==size.value)||(scene.value&&c.dataset.scene!==scene.value)||!c.dataset.name.includes(name.value.toLowerCase().replaceAll(' ','_')))}
[size,scene,name].forEach(el=>el.addEventListener('input',filter));</script></html>''')

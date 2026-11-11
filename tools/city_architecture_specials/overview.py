#!/usr/bin/env python3
"""Build the filterable editorial overview and visual review contact sheets."""
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from proposals import LABELS
HERE=Path(__file__).resolve().parent
catalog=json.loads((HERE/'catalog.json').read_text())
esc=html.escape
cards=[]
groups={"done":[],"pending":[],"keep":[]}
headings={"done":"Bereits überarbeitet – zur Abnahme", "pending":"Noch nicht überarbeitet", "keep":"So lassen – meine Empfehlung"}
order=sorted(catalog,key=lambda k:(not catalog[k]['implemented'],list(LABELS).index(catalog[k]['race']),catalog[k]['town'],catalog[k]['title']))
for key in order:
    s=catalog[key];p=s['placement'];href='viewer.html?building='+key
    image='captures/'+key+'.png'
    assert (HERE/image).is_file()
    current=', '.join(m['label'] for m in s['current_materials'][:4])
    detail=''.join('<li>'+esc(t)+'</li>' for t in s['details'])
    status='Überarbeitet · zur Abnahme' if s['implemented'] else 'So lassen' if s['status']=='keep' else 'Bestand · Textvorschlag darunter'
    before_image='<img loading="lazy" src="captures/'+key+'-before.png" alt="Vorher">' if s['implemented'] else ''
    pair_class=' pair' if s['implemented'] else ''
    source=f'{p["layout"]}:{p["line"]} · {p["count"]}× platziert · '+p['reason']
    cards.append(f'''<article class="card" id="{key}" data-status="{s['status']}" data-race="{s['race']}" data-kind="{s['kind']}" data-priority="{s['priority']}" data-search="{esc((s['town']+' '+s['title']+' '+s['template']+' '+s['category']).lower())}">
<a class="picture{pair_class}" href="{href}">{before_image}<img loading="lazy" src="{image}" alt="{esc(s['title'])} in {esc(s['town'])}"><span>{"Vorher / Nachher · " if s["implemented"] else ""}{status} · 3D öffnen ↗</span></a>
<div class="body"><div class="meta">{LABELS[s['race']]} · {esc(s['town'].replace('_',' ').title())} <b>{s['priority']}</b></div><h2><a href="{href}">{esc(s['title'])}</a></h2><div class="category">{s['category']}</div>
<p class="proposal">{esc(s['description'])}</p><ul>{detail}</ul>
<details><summary>Bestand und Herkunft</summary><p>Häufige vorhandene Vollblock-Materialien: {esc(current)}.</p><p>{esc(s['preview_note'])}</p><code>{esc(s['template'])}</code><p>{esc(source)}</p></details></div></article>''')
    groups[s['status']].append(cards[-1])
page='''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Grudgelands · Die übrigen Stadtgebäude</title>
<style>:root{color-scheme:dark;--bg:#152125;--line:#3b4e52;--accent:#dfb878;--ink:#eee6d8;--muted:#bdc8c7}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 system-ui}header,main,footer{padding:28px 4vw}header{border-bottom:1px solid var(--line)}header p{max-width:1000px;color:var(--muted)}h1{font:clamp(28px,4vw,44px)/1.15 Georgia;margin:9px 0 18px}h2{font:24px/1.2 Georgia;margin:12px 0 5px}.eyebrow,.category{color:var(--accent);font-size:12px;letter-spacing:.06em}.stats{display:flex;flex-wrap:wrap;gap:12px;margin:20px 0}.stats span{background:#213338;border:1px solid var(--line);padding:10px 14px;border-radius:5px}.stats strong{color:var(--accent);font-size:21px}a{color:var(--accent);text-underline-offset:3px}nav{position:sticky;top:0;z-index:2;display:flex;gap:8px;flex-wrap:wrap;align-items:center;padding:15px 4vw;background:#152125f5;border-bottom:1px solid var(--line)}button,input,select{font:inherit;font-size:13px;color:var(--ink);background:#23363b;border:1px solid #61716c;border-radius:4px;padding:9px;max-width:100%}button{cursor:pointer}button[aria-pressed=true]{background:var(--accent);color:var(--bg)}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:2px solid var(--accent);outline-offset:3px}label{display:flex;gap:6px;align-items:center;font-size:12px}#count{color:var(--muted);font-size:13px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,370px),1fr));gap:24px;align-items:start}.card{background:#1c2b30;border:1px solid var(--line);border-radius:6px;overflow:hidden;scroll-margin-top:150px}.card:hover{border-color:#7f8b7b}.picture{display:block;position:relative;text-decoration:none}.picture img{display:block;width:100%;aspect-ratio:1.7;object-fit:contain;background:#9ec3ea}.pair{display:grid;grid-template-columns:1fr 1fr}.pair span{grid-column:1/-1}.group-title{margin:12px 0 24px}.status-group{margin-bottom:48px}.picture span{display:block;background:#24393e;color:var(--muted);font-size:12px;padding:7px 16px}.body{padding:18px}.body h2 a{color:var(--ink);text-decoration:none}.meta{font-size:11px;color:var(--muted);display:flex;gap:10px;flex-wrap:wrap;justify-content:space-between}.meta b{color:var(--accent)}.proposal{font-size:15px;line-height:1.6}ul{padding-left:20px;color:var(--muted);font-size:13px}li{padding:5px 0}details{border-top:1px solid var(--line);margin-top:20px;padding-top:12px;color:var(--muted);font-size:12px}summary{cursor:pointer}code{overflow-wrap:anywhere}footer{color:var(--muted);font-size:12px}.steps{max-width:1000px;color:var(--muted)}[hidden]{display:none!important}@media(max-width:600px){nav{position:static}header,main,footer{padding:20px}h2{font-size:22px}.grid{gap:20px}}</style>
<header><div class="eyebrow">Grudgelands / Architektur · Zweiter Durchgang</div><h1>Ein gemeinsamer Stil.<br>Platz für besondere Gebäude.</h1>
<p>Hier stehen alle Gebäude und Freianlagen, die beim ersten Durchgang zurückgestellt wurden. Jede Ansicht zeigt die echte Vorlage mit ihrer örtlichen Materialpalette, samt Vorschlag für die weitere Überarbeitung. Ein Klick öffnet die drehbare 3D-Ansicht.</p>
<div class="stats"><span><strong>154</strong> Standort- und Palettenansichten</span><span><strong>130</strong> Gebäudeteile / Vorlagen</span><span><strong>6</strong> Völker</span><span><strong>138</strong> überarbeitet</span><span><strong>0</strong> noch offen</span><span><strong>16</strong> so lassen</span></div>
<p>Der <a href="viewer.html?building=silverleaf__silverleaf_moon_shrine__8">Mondschrein in Silverleaf</a> verbindet jetzt Marmorpfeiler, Silberholz und ein durchgehendes Serpentinenband. Dach und Dachaufsatz bleiben erhalten. <a href="../character_creation_preview/architecture-refresh/">Aktualisierten Charakter-Hintergrund ansehen →</a></p>
<p><strong>Neu: auch die übrigen freigegebenen Sonderbauten sind angeglichen.</strong> Die erste Gruppe zeigt 138 überarbeitete Ansichten einschließlich der Gilden und des Mondschreins, jeweils Vorher und Nachher. Die Abnahme steht noch aus. Ein Klick öffnet den Vergleich mit gemeinsam drehbarer Kamera.</p>
<p>Es sind keine Vorschläge dieser Liste mehr offen. Bei 16 Grünanlagen und Denkmälern empfehle ich, sie so zu lassen. Diese Einteilung betrifft die bisher zurückgestellten Bauten; die <a href="../city_architecture_rollout/">145 Ansichten des ersten Durchgangs</a> bleiben separat erreichbar. Lager außerhalb der Städte bleiben ausgenommen.</p></header>
<nav aria-label="Gebäude filtern"><label>Stand <select id="status"><option value="done">Bereits überarbeitet (138)</option><option value="pending">Noch nicht überarbeitet (0)</option><option value="keep">So lassen (16)</option><option value="">Alle drei Gruppen</option></select></label><button data-race="" aria-pressed="true">Alle Völker</button>__RACES__<input id="search" type="search" placeholder="Ort oder Gebäude" aria-label="Ort oder Gebäude suchen"><label>Art <select id="kind"><option value="">Alle Arten</option>__KINDS__</select></label><label>Empfehlung <select id="priority"><option value="">Alle Empfehlungen</option>__PRIORITIES__</select></label><span id="count" aria-live="polite"></span><button id="reset">Filter zurücksetzen</button></nav>
<main>__GROUPS__<p id="empty" hidden>Keine passenden Gebäude. Passe die Filter an.</p></main>
<footer>Die 154 Ansichten decken genau die Ausschlussliste der bisherigen Stadtstudie ab: zwölf Startstädte und Hauptstädte, einschließlich mehrfach genutzter Vorlagen mit unterschiedlichen Paletten. Sie sind keine vollständige Liste aller Weltstrukturen. Bäume und Unterwuchs stammen aus dem echten Gebäude-Loader. Umgebung, NPCs und nachträgliche Stadtdekorationen sind nicht eingeblendet. Three.js-Vorschau mit Spieltexturen; Beleuchtung angenähert, keine Luanti-Aufnahme.</footer>
<script>let race='';const cards=[...document.querySelectorAll('.card')],buttons=[...document.querySelectorAll('[data-race]')].filter(x=>x.tagName==='BUTTON'),search=document.getElementById('search'),kind=document.getElementById('kind'),priority=document.getElementById('priority'),status=document.getElementById('status');
function filter(){let n=0;const q=search.value.trim().toLowerCase();for(const c of cards){c.hidden=!!((status.value&&c.dataset.status!==status.value)||(race&&c.dataset.race!==race)||(kind.value&&c.dataset.kind!==kind.value)||(priority.value&&c.dataset.priority!==priority.value)||(q&&!c.dataset.search.includes(q)));if(!c.hidden)n++}document.getElementById('count').textContent=n+' / '+cards.length+' Ansichten';document.getElementById('empty').hidden=n!==0;for(const g of document.querySelectorAll('.status-group'))g.hidden=![...g.querySelectorAll('.card')].some(c=>!c.hidden);for(const b of buttons)b.setAttribute('aria-pressed',b.dataset.race===race)}
for(const b of buttons)b.onclick=()=>{race=b.dataset.race;filter()};search.oninput=filter;kind.onchange=filter;priority.onchange=filter;status.onchange=filter;document.getElementById('reset').onclick=()=>{race='';search.value=kind.value=priority.value=status.value='';filter()};filter();window.catalogReady=true;</script></html>'''
kinds={s['kind']:s['category'] for s in catalog.values()}
priorities=['Umgesetzt','Als Nächstes','Gezielt entwerfen','Abstimmen','Behutsam erhalten','Beibehalten']
page=page.replace('__RACES__',''.join(f'<button data-race="{r}" aria-pressed="false">{v}</button>' for r,v in LABELS.items())).replace('__KINDS__',''.join(f'<option value="{k}">{v}</option>' for k,v in sorted(kinds.items(),key=lambda x:x[1]))).replace('__PRIORITIES__',''.join(f'<option>{v}</option>' for v in priorities)).replace('__GROUPS__',''.join('<section class="status-group" data-group="'+k+'"><h2 class="group-title">'+headings[k]+' ('+str(len(v))+')</h2><div class="grid">'+''.join(v)+'</div></section>' for k,v in groups.items()))
(HERE/'index.html').write_text(page)
(HERE/'contact_sheets').mkdir(exist_ok=True)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',11)
for race in LABELS:
    rows=[(k,s) for k,s in catalog.items() if s['race']==race]
    for start in range(0,len(rows),12):
        subset=rows[start:start+12];image=Image.new('RGB',(1400,((len(subset)+3)//4)*260),'#152125');draw=ImageDraw.Draw(image)
        for i,(key,s) in enumerate(subset):
            capture=Image.open(HERE/'captures'/(key+'.png')).convert('RGB');capture.thumbnail((350,220))
            x=(i%4)*350;y=(i//4)*260;image.paste(capture,(x+(350-capture.width)//2,y))
            draw.text((x+5,y+221),s['town']+' / '+s['title'][:35],font=font,fill='#eee6d8')
            draw.text((x+5,y+238),s['category']+' · '+s['priority'],font=font,fill='#dfb878')
        image.save(HERE/'contact_sheets'/(race+'_'+str(start//12+1)+'.jpg'),quality=90)
print('154 cards and',len(list((HERE/'contact_sheets').glob('*.jpg'))),'contact sheets written')

#!/usr/bin/env python3
"""Offline contact sheets and a filterable thumbnail index of the transfer."""
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
catalog=json.loads((HERE/'catalog.json').read_text())
audit=json.loads((HERE/'audit.json').read_text())
labels={'dwarf':'Zwerge','human':'Menschen','elf':'Elfen','orc':'Orks','troll':'Trolle','undead':'Untote'}
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',11)
for race in labels:
    rows=[(k,s) for k,s in catalog.items() if s['race']==race]
    for page in range(0,len(rows),12):
        subset=rows[page:page+12];out=Image.new('RGB',(1200,((len(subset)+3)//4)*310),'#152125');d=ImageDraw.Draw(out)
        for i,(key,s) in enumerate(subset):
            im=Image.open(HERE/'captures'/(key+'.png')).convert('RGB');im.thumbnail((300,275))
            x=(i%4)*300;y=(i//4)*310;out.paste(im,(x+(300-im.width)//2,y))
            name=s['town']+' / '+s['title']
            d.text((x+4,y+278),name[:43],font=font,fill='#eee1cb')
            d.text((x+4,y+293),('REFERENCE' if s['reference'] else 'INSPECT' if s['attention'] else 'TRANSFER'),font=font,fill='#dfb878')
        out.save(HERE/'contact_sheets'/(race+'_'+str(page//12+1)+'.jpg'),quality=90)
card=[]
for key,s in catalog.items():
    href='compare.html?building='+key
    tag='Referenz' if s['reference'] else 'Besondere Form' if s['attention'] else 'Übertragung'
    previous = (f'<figure class="previous"><img loading="lazy" src="previous/{key}.png" alt="Vorige Übertragung"><figcaption>Vorige Übertragung</figcaption></figure>' if s['review_focus'] else '')
    card.append(f'<a class="card" href="{href}" data-race="{s["race"]}" data-attention="{str(s["attention"]).lower()}" data-focus="{str(s["review_focus"]).lower()}" data-search="{html.escape((s["town"]+" "+s["title"]).lower())}"><div class="comparison">{previous}<figure><img loading="lazy" src="captures/{key}.png" alt="{html.escape(s["title"])}"><figcaption>Klare Rahmen und Füllfelder</figcaption></figure></div><span class="town">{html.escape(s["town"])} · {tag}</span><h2>{html.escape(s["title"])}</h2><span class="typology">{html.escape(s["typology"])}</span></a>')

excluded=''.join('<tr><td>'+html.escape(x['town'])+'</td><td>'+html.escape(x['template'])+'</td><td>'+html.escape(x['reason'])+'</td></tr>' for x in audit['excluded'])
page='''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Grudgelands · Stadtgebäude</title>
<style>:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#152125;color:#e9e2d4;font:15px/1.5 system-ui}header,nav,main,footer{padding:20px 4vw}header{border-bottom:1px solid #384447}h1{font:34px Georgia;margin:7px 0}p{max-width:880px;color:#b9c5c4}.eyebrow,.town{color:#dfb878;font-size:12px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:16px}.card{color:inherit;text-decoration:none;border:1px solid #384447;padding:10px;border-radius:5px;background:#1c2a2e}.card:hover{border-color:#dfb878}.card img{width:100%;aspect-ratio:1.1;object-fit:contain;background:#9ec3ea}.comparison{display:grid;gap:4px}figure{margin:0;min-width:0}figcaption{font-size:12px;color:#b9c5c4}.previous{display:none}.focus-mode{grid-template-columns:repeat(auto-fit,minmax(min(100%,520px),1fr))}.focus-mode .comparison{grid-template-columns:1fr 1fr}.focus-mode .previous{display:block}.typology{font-size:13px;color:#b9c5c4}.card h2{font:20px Georgia;margin:5px 0}.town{display:block;margin-top:10px}button,input{font:inherit;padding:9px;border:1px solid #61716c;border-radius:4px;background:#233136;color:inherit}button[aria-pressed=true]{background:#dfb878;color:#152125}nav{display:flex;flex-wrap:wrap;gap:8px;align-items:center;position:sticky;top:0;background:#152125ee;z-index:1}label{padding:4px}a{color:#dfb878}details{margin-top:30px;overflow:auto}td,th{padding:7px;border-bottom:1px solid #384447;text-align:left;font-size:12px}#count{color:#b9c5c4}[hidden]{display:none!important}</style>
<header><div class="eyebrow">Grudgelands / Wohn- und Berufsgebäude</div><h1>Klare Rahmen, ruhige Wandfelder.</h1><p>Vier Bauformen zeigen die neue Ordnung: durchgehende Stützen, schmale Querbalken und zusammenhängende Füllflächen. Hier siehst du die vorige Übertragung neben dem neuen Entwurf. Ein Klick öffnet den drehbaren Vergleich mit der Spielvorlage.</p><p>Unsere Maßstäbe bleiben das <a href="compare.html?building=dawnmere__dawnmere_lane_cottage">Fachwerk-Wohnhaus</a> und das <a href="compare.html?building=dawnmere__dawnmere_meeting_hall">Versammlungshaus</a>. Die zwölf Referenzgebäude bleiben unverändert. Über die Völkerfilter erreichst du alle 145 Ansichten; du musst sie nicht einzeln kommentieren.</p><p>Die Markierung „Besondere Form“ weist auf erhöhte Böden, mehrere Dachflächen oder andere Übergänge hin. Tore, Königshallen, Wehr- und Sakralbauten, offene Anlagen und Ruinen sind zurückgestellt. Lager außerhalb der Städte gehören nicht zu diesem Durchgang.</p></header>
<nav><button data-race="" aria-pressed="true">Alle</button>__BUTTONS__<input id="search" placeholder="Ort oder Gebäude suchen" aria-label="Ort oder Gebäude suchen"><label><input type="checkbox" id="focus" checked> Vier Bauformen</label><label><input type="checkbox" id="attention"> Nur besondere Formen</label><span id="count"></span></nav>
<main><div class="grid">__CARDS__</div><details><summary>Zurückgestellte Gebäude und Freianlagen</summary><table><thead><tr><th>Ort</th><th>Vorlage</th><th>Grund</th></tr></thead><tbody>__EXCLUDED__</tbody></table></details></main>
<footer>Lokale Browserstudie. Spielvorlagen und Spielwelt wurden nicht verändert. Die Darstellung nähert Luanti an; Schilf-Dachformen sind weiterhin Vorschauformen.</footer>
<script>
let race='';const buttons=[...document.querySelectorAll('button[data-race]')],cards=[...document.querySelectorAll('.card')],focus=document.getElementById('focus'),attention=document.getElementById('attention'),search=document.getElementById('search');
function filter(){let n=0;const term=search.value.trim().toLowerCase();document.querySelector('.grid').classList.toggle('focus-mode',focus.checked);for(const c of cards){c.hidden=!!((race&&c.dataset.race!==race)||(term&&!c.dataset.search.includes(term))||(attention.checked&&c.dataset.attention!=='true')||(focus.checked&&c.dataset.focus!=='true'));if(!c.hidden)n++}document.getElementById('count').textContent=n+' / '+cards.length+' Ansichten'}
function selectRace(value){race=value;for(const b of buttons)b.setAttribute('aria-pressed',b.dataset.race===race)}
for(const b of buttons)b.onclick=()=>{selectRace(b.dataset.race);focus.checked=false;filter()};
search.oninput=()=>{focus.checked=false;filter()};attention.onchange=()=>{focus.checked=false;filter()};
focus.onchange=()=>{if(focus.checked){selectRace('');attention.checked=false;search.value=''}filter()};filter();
</script></html>'''
page=page.replace('__BUTTONS__',''.join(f'<button data-race="{r}" aria-pressed="false">{label}</button>' for r,label in labels.items())).replace('__CARDS__',''.join(card)).replace('__EXCLUDED__',excluded)
(HERE/'index.html').write_text(page)
print('Overview and',len(list((HERE/'contact_sheets').glob('*.jpg'))),'contact sheets written.')

#!/usr/bin/env python3
"""Round 36 lane P: the POI review page (German) from render.py's pois.json.

    python3 tools/r36_p/page.py OUT_DIR WORK/pois.json

(render.py calls `write` itself.)

Writes OUT_DIR/index.html next to OUT_DIR/img/. Per POI: name, zone, race,
anchor, the in-game view large, the plan and the two other palettes small
(all four cut from the POI's one picture), a verdict (gut / langweilig /
andere Rasse with the race) and a note; the four rift-site candidates carry
a pick. State lives in one object, kept in localStorage; "Ergebnis kopieren"
copies one line per POI with a verdict other than "gut" or a note, plus the
rift pick.
"""
import html
import json
import os
import sys

RACE_DE = {"dwarf": "Zwerg", "human": "Mensch", "elf": "Elf", "undead": "Untote",
           "orc": "Ork", "troll": "Troll"}
FACTION_RACES = {"accord": ["dwarf", "elf", "human"], "throng": ["orc", "troll", "undead"]}
RIFT = {"Saltgate Remnant", "Tombroad Ambush", "Skyroot Crossing", "Cloudwatch Fall"}

GROUPS = [
    ("village", "Dörfer", "Die Dörfer der 21–30-Zonen (Runde 20)."),
    ("outpost", "Außenposten", "Wachposten mit Banner, 21–40 (Runde 20)."),
    ("bandit_frontier", "Banditenlager", "Grenzland-Banditenlager mit Lagerfeuer, 31–40 (Runde 20)."),
    ("mine", "Minen", "Abbaustellen der 21–30-Zonen (Runde 20)."),
    ("mirefolk", "Moorvolk-Lager", "Lager des Moorvolks (Runde 20)."),
    ("clash", "Schlachtfelder", "Offene Kampfplätze ohne Gebäude (Runde 20). Die vier markierten Orte "
     "sind die Kandidaten für den Riss, das Finale der Hauptquestreihe: dort wählst du einen."),
    ("apex_mine", "Apex-Lager", "Die Edelstein-Lager auf den beiden Dracheninseln (Runde 20)."),
    ("rare_route", "Rare-Plätze", "Kleine Plätze am Weg der benannten seltenen Gegner (Runde 20)."),
    ("r14_village", "Startgebiet: Dörfer (Runde 14/15)", "Eigene Komposition je Rasse, 11–20."),
    ("r14_outpost", "Startgebiet: Außenposten (Runde 14/15)", "Eigene Komposition je Rasse, 11–20."),
    ("r14_bandit", "Startgebiet: Banditenlager (Runde 14/15)", "Eigene Komposition je Rasse, 11–20."),
    ("pvp_fortress", "Festungen", "Je Fraktion eine Festung (Runde 31). Sie hat keine Rassenpalette, "
     "sondern das Material ihrer Fraktion; klein siehst du sie im Material der anderen Fraktion."),
    ("pvp_camp_low", "Battlegrounds: Vorposten (Picket)", "Das niedrigere Lager je Zone und Fraktion "
     "(Runde 31). Seine Rasse wird pro Welt aus dem Seed gewürfelt (eine der drei Rassen der Fraktion): "
     "groß die Rasse auf Seed 42, klein die beiden anderen möglichen."),
    ("pvp_camp_high", "Battlegrounds: Kriegslager (War Camp)", "Das höhere Lager je Zone und Fraktion "
     "(Runde 31), mit Wachtürmen; Rasse wie bei den Vorposten pro Welt gewürfelt."),
    ("dragon", "Drachenarenen", "Die beiden Arenen (Runde 31). Ihr Boden ist Gelände; hier liegen die "
     "Gefahren (Eis, Frostterrassen, Glutspalten, Stämme, Randsteine) auf flachem Ersatzboden. "
     "Keine Rassenpalette."),
]


def esc(text):
    return html.escape(str(text), quote=True)


def view(poi, rect, caption, cls=""):
    iw, ih = poi["size"]
    x, y, w, h = rect
    style = "width:%.4f%%;left:%.4f%%;top:%.4f%%" % (iw / w * 100, -x / w * 100, -y / h * 100)
    return ('<figure class="view %s"><a href="%s" target="_blank" rel="noopener" '
            'style="aspect-ratio:%d/%d" aria-label="Bild in voller Größe öffnen">'
            '<img decoding="async" data-src="%s" width="%d" height="%d" alt="" style="%s"></a>'
            '<figcaption>%s</figcaption></figure>'
            % (cls, esc(poi["image"]), w, h, esc(poi["image"]), iw, ih, style, caption))


def seed_line(poi):
    parts = []
    for item in poi["seed_races"].split(","):
        seed, race = item.split("=")
        parts.append("%s: %s" % (seed, RACE_DE[race]))
    return " · ".join(parts)


def card(poi):
    group = poi["group"]
    key = poi["key"]
    rift = poi["label"] in RIFT
    zone = "%s (Stufe %d–%d)" % (poi["zone_name"], poi["level_min"], poi["level_max"]) \
        if poi["level_min"] != poi["level_max"] else "%s (Stufe %d)" % (poi["zone_name"], poi["level_min"])
    if group == "pvp_fortress":
        faction = "Accord" if key.endswith("accord") else "Throng"
        race_text = "Fraktion %s (Material der Fraktion, geführt als %s)" % (faction, RACE_DE[poi["race"]])
        main_cap = "Im Spiel"
    elif group.startswith("pvp_camp"):
        race_text = "je Welt gewürfelt; Seed %s" % seed_line(poi)
        main_cap = "Im Spiel auf Seed 42: %s" % RACE_DE[poi["race"]]
    elif group == "dragon":
        race_text = "keine Palette (Inselthema)"
        main_cap = "Gefahren auf flachem Ersatzboden"
    else:
        race_text = RACE_DE[poi["race"]]
        main_cap = "Im Spiel (%s)" % RACE_DE[poi["race"]]
    meta = ("<span>%s</span><span>Rasse: %s</span><span>Anker %d (%d, %d)</span>"
            % (esc(zone), esc(race_text), poi["numeric_id"], poi["x"], poi["z"]))
    views = [view(poi, poi["main"], esc(main_cap), "main")]
    small = [view(poi, poi["plan"], "Grundriss (Dach ab, Norden oben)")]
    for alt in poi["alts"]:
        pal = alt["palette"]
        cap = "mit %s-Material" % pal.capitalize() if pal in ("accord", "throng") else "als %s" % RACE_DE[pal]
        small.append(view(poi, alt["rect"], esc(cap)))
    # The race choice for "andere Rasse": a camp keeps to its faction's races.
    if group.startswith("pvp_camp"):
        faction = "accord" if "_accord_" in key else "throng"
        choices = FACTION_RACES[faction]
    else:
        choices = [r for r in RACE_DE if r != poi["race"]]
    options = "".join('<option value="%s">%s</option>' % (r, RACE_DE[r]) for r in choices)
    race_choice = "" if group == "dragon" else (
        '<label class="opt"><input type="radio" name="v_%s" value="rasse"> andere Rasse</label>'
        '<select data-race aria-label="Rasse"><option value="">Rasse wählen …</option>%s</select>'
        % (key, options))
    rift_html = ('<label class="rift-pick"><input type="radio" name="rift" value="%s"> '
                 '<b>Hier soll der Riss hin</b></label>' % key) if rift else ""
    badge = '<span class="badge">Riss-Kandidat</span>' if rift else ""
    return ('<article class="poi%s" id="%s" data-key="%s" data-label="%s">'
            '<header><h3>%s %s</h3><p class="meta">%s</p></header>%s'
            '<div class="smalls">%s</div>'
            '<div class="verdict" role="group" aria-label="Urteil">'
            '<label class="opt"><input type="radio" name="v_%s" value="gut"> gut</label>'
            '<label class="opt"><input type="radio" name="v_%s" value="langweilig"> langweilig</label>'
            '%s</div>%s'
            '<input class="note" type="text" maxlength="300" placeholder="Notiz (optional)" aria-label="Notiz">'
            '</article>'
            % (" rift" if rift else "", esc(key), esc(key), esc(poi["label"]), esc(poi["label"]), badge,
               meta, views[0], "".join(small), key, key, race_choice, rift_html))


CSS = """
:root{--bg:#f1efe9;--card:#fcfbf8;--ink:#22201b;--muted:#625c50;--line:#dcd6c8;--accent:#7a4b12;--soft:#ece3d1;--chip:#e9e3d6;--rift:#8a2be2;--ok:#2f7a3a;--warn:#a0521a}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){color-scheme:dark;--bg:#171512;--card:#211e1a;--ink:#ebe6dc;--muted:#a79f90;--line:#38332b;--accent:#e0a75a;--soft:#2a241b;--chip:#2b2721;--rift:#c39bff;--ok:#7fd08a;--warn:#f0a868}}
:root[data-theme="dark"]{color-scheme:dark;--bg:#171512;--card:#211e1a;--ink:#ebe6dc;--muted:#a79f90;--line:#38332b;--accent:#e0a75a;--soft:#2a241b;--chip:#2b2721;--rift:#c39bff;--ok:#7fd08a;--warn:#f0a868}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:980px;margin:0 auto;padding:16px 16px 64px}
h1{font-size:1.9rem;line-height:1.15;margin:.6rem 0 .4rem}
h2{font-size:1.35rem;margin:2.2rem 0 .3rem;scroll-margin-top:64px}
h2 .count{color:var(--muted);font-weight:400;font-size:1rem}
h3{font-size:1.05rem;margin:0;display:flex;gap:8px;align-items:center;flex-wrap:wrap}
p{margin:.4rem 0;max-width:72ch}
.lead{color:var(--muted)}
.ask{background:var(--soft);border:1px solid var(--line);border-radius:10px;padding:14px 16px;margin:18px 0}
.ask ul{margin:.3rem 0 .2rem;padding-left:1.2rem}
.ask li{margin:.2rem 0}
.note-s{color:var(--muted);font-size:.92rem}
code{background:var(--chip);padding:1px 6px;border-radius:4px;font-size:.92em}
.bar{position:sticky;top:0;z-index:5;background:var(--bg);border-bottom:1px solid var(--line);padding:8px 0;display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.bar .stat{color:var(--muted);font-size:.92rem;font-variant-numeric:tabular-nums}
.bar .grow{flex:1}
button{font:inherit;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:8px;padding:6px 12px;cursor:pointer}
button.primary{background:var(--accent);border-color:var(--accent);color:var(--bg);font-weight:600}
button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
nav.groups{display:flex;flex-wrap:wrap;gap:6px;margin:10px 0}
nav.groups a{background:var(--chip);color:var(--ink);text-decoration:none;border-radius:999px;padding:2px 10px;font-size:.88rem}
.legend{display:flex;flex-wrap:wrap;gap:4px 14px;font-size:.88rem;color:var(--muted);margin:.4rem 0}
.dot{display:inline-block;width:.8em;height:.8em;border-radius:50%;border:1px solid #000;vertical-align:-.05em;margin-right:4px}
.poi{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px;margin:12px 0;display:grid;gap:8px;min-width:0}
.poi.rift{border:2px solid var(--rift)}
.poi.judged-gut{border-left:6px solid var(--ok)}
.poi.judged-langweilig,.poi.judged-rasse{border-left:6px solid var(--warn)}
.meta{margin:0;color:var(--muted);font-size:.9rem;display:flex;flex-wrap:wrap;gap:2px 14px}
.badge{background:var(--rift);color:var(--card);border-radius:999px;padding:0 8px;font-size:.78rem;font-weight:600}
.view{margin:0;min-width:0}
.view a{display:block;position:relative;overflow:hidden;border-radius:6px;background:#181a1e}
.view img{position:absolute;max-width:none;height:auto;display:block}
.view figcaption{font-size:.8rem;color:var(--muted);margin-top:2px}
.smalls{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px}
.verdict{display:flex;flex-wrap:wrap;gap:6px 8px;align-items:center}
.opt{display:inline-flex;gap:5px;align-items:center;background:var(--chip);border-radius:8px;padding:4px 10px;cursor:pointer}
select,.note{font:inherit;color:var(--ink);background:var(--bg);border:1px solid var(--line);border-radius:8px;padding:4px 8px}
.note{width:100%}
.rift-pick{display:inline-flex;gap:6px;align-items:center;color:var(--rift)}
textarea{width:100%;min-height:8em;font:13px/1.4 ui-monospace,Menlo,Consolas,monospace;background:var(--card);color:var(--ink);border:1px solid var(--line);border-radius:8px;padding:8px}
@media (max-width:600px){.bar .detail{display:none}.bar{gap:6px}.bar button{padding:4px 9px;font-size:.9rem}}
footer{margin-top:44px;font-size:.85rem;color:var(--muted);max-width:72ch}
"""

JS = r"""
(function(){
var KEY='r36-poi-review-v1';
var state={verdicts:{},rift:''};
try{var raw=localStorage.getItem(KEY);if(raw){var s=JSON.parse(raw);if(s&&s.verdicts){state=s;}}}catch(e){}
function save(){try{localStorage.setItem(KEY,JSON.stringify(state));}catch(e){}}
var cards=[].slice.call(document.querySelectorAll('article.poi'));
var RACE={dwarf:'Zwerg',human:'Mensch',elf:'Elf',undead:'Untote',orc:'Ork',troll:'Troll'};
function entry(k){return state.verdicts[k]||(state.verdicts[k]={v:'',race:'',note:''});}
function paint(card){
  var k=card.dataset.key,e=state.verdicts[k]||{};
  card.classList.remove('judged-gut','judged-langweilig','judged-rasse');
  if(e.v)card.classList.add('judged-'+e.v);
  [].forEach.call(card.querySelectorAll('input[type=radio][name^="v_"]'),function(r){r.checked=(r.value===e.v);});
  var sel=card.querySelector('select[data-race]');if(sel)sel.value=e.race||'';
  card.querySelector('.note').value=e.note||'';
  var rp=card.querySelector('input[name=rift]');if(rp)rp.checked=(state.rift===k);
}
function stats(){
  var n=cards.length,c={gut:0,langweilig:0,rasse:0};
  cards.forEach(function(card){var e=state.verdicts[card.dataset.key];if(e&&c.hasOwnProperty(e.v))c[e.v]++;});
  var done=c.gut+c.langweilig+c.rasse;
  var rift=state.rift?document.getElementById(state.rift):null;
  document.getElementById('stat').innerHTML='';
  var st=document.getElementById('stat');
  st.appendChild(document.createTextNode('Bewertet '+done+'/'+n));
  var d=document.createElement('span');d.className='detail';d.textContent=' · gut '+c.gut+' · langweilig '+c.langweilig+' · andere Rasse '+c.rasse;st.appendChild(d);
  st.appendChild(document.createTextNode(' · Riss: '+(rift?rift.dataset.label:'offen')));
  return {n:n,c:c,done:done,rift:rift};
}
cards.forEach(function(card){
  var k=card.dataset.key;
  card.addEventListener('change',function(ev){
    var t=ev.target,e=entry(k);
    if(t.name==='v_'+k){e.v=t.value;if(e.v!=='rasse')e.race='';}
    else if(t.matches('select[data-race]')){e.race=t.value;if(t.value)e.v='rasse';}
    else if(t.name==='rift'){state.rift=k;cards.forEach(paint);}
    save();paint(card);stats();
  });
  card.querySelector('.note').addEventListener('input',function(ev){entry(k).note=ev.target.value;save();});
  paint(card);
});
function result(){
  var s=stats(),lines=['POI-Durchsicht Runde 36: bewertet '+s.done+'/'+s.n+' (gut '+s.c.gut+', langweilig '+s.c.langweilig+', andere Rasse '+s.c.rasse+')',
    'Riss: '+(s.rift?s.rift.dataset.key+' '+s.rift.dataset.label:'keine Wahl')];
  cards.forEach(function(card){
    var k=card.dataset.key,e=state.verdicts[k];if(!e)return;
    var note=(e.note||'').trim();
    if(e.v==='gut'&&!note)return;if(!e.v&&!note)return;
    var v=e.v==='rasse'?'andere Rasse '+(e.race?e.race+' ('+RACE[e.race]+')':'(keine gewählt)'):(e.v||'ohne Urteil');
    lines.push(k+' '+card.dataset.label+': '+v+(note?' | Notiz: '+note:''));
  });
  return lines.join('\n');
}
var out=document.getElementById('out');
document.getElementById('copy').addEventListener('click',function(){
  var text=result();out.value=text;out.hidden=false;
  function fallback(){out.focus();out.select();try{document.execCommand('copy');}catch(e){}}
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(text).then(function(){flash('Kopiert');},function(){fallback();flash('Text markiert, bitte kopieren');});}
  else{fallback();flash('Text markiert, bitte kopieren');}
});
document.getElementById('reset').addEventListener('click',function(){
  if(!confirm('Alle Urteile, Notizen und die Riss-Wahl löschen?'))return;
  state={verdicts:{},rift:''};save();cards.forEach(paint);stats();out.hidden=true;
});
function flash(t){var b=document.getElementById('copy'),o=b.textContent;b.textContent=t;setTimeout(function(){b.textContent=o;},1600);}
// Pictures load when their frame nears the screen (one file per POI; the
// frame has its size before the picture arrives).
var frames=[].slice.call(document.querySelectorAll('.view a'));
function load(frame){var img=frame.querySelector('img[data-src]');if(img){img.src=img.dataset.src;img.removeAttribute('data-src');}}
if('IntersectionObserver' in window){
  var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){load(e.target);io.unobserve(e.target);}});},{rootMargin:'800px 0px'});
  frames.forEach(function(f){io.observe(f);});
}else{frames.forEach(load);}
var root=document.documentElement,TK='r36-poi-theme';
function theme(t){if(t)root.setAttribute('data-theme',t);else root.removeAttribute('data-theme');}
try{theme(localStorage.getItem(TK)||'');}catch(e){}
document.getElementById('theme').addEventListener('click',function(){
  var cur=root.getAttribute('data-theme')||'',dark=cur?cur==='dark':matchMedia('(prefers-color-scheme: dark)').matches;
  var next=dark?'light':'dark';theme(next);try{localStorage.setItem(TK,next);}catch(e){}
});
stats();
})();
"""


def write(out, pois):
    by_group = {}
    for poi in pois:
        by_group.setdefault(poi["group"], []).append(poi)
    known = {g[0] for g in GROUPS}
    missing = sorted(set(by_group) - known)
    if missing:
        raise SystemExit("groups without a section: %s" % ", ".join(missing))
    nav, sections = [], []
    for gid, title, intro in GROUPS:
        items = by_group.get(gid, [])
        if not items:
            continue
        nav.append('<a href="#g-%s">%s (%d)</a>' % (gid, esc(title), len(items)))
        sections.append('<h2 id="g-%s">%s <span class="count">%d</span></h2><p class="note-s">%s</p>%s'
                        % (gid, esc(title), len(items), esc(intro), "".join(card(p) for p in items)))
    legend = "".join('<span><span class="dot" style="background:%s"></span>%s</span>' % (c, t) for c, t in [
        ("rgb(250,220,40)", "Questgeber"), ("rgb(230,60,50)", "Torwache"),
        ("rgb(240,150,40)", "Wache"), ("rgb(170,60,220)", "Hauptmann / General"),
        ("rgb(200,120,240)", "Leibwache"), ("rgb(60,200,90)", "Händler"),
        ("rgb(40,200,230)", "Wegstein"), ("rgb(255,255,255)", "Bewohner")])
    page = """<!doctype html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>POI-Durchsicht</title>
<style>%s</style></head>
<body><main>
<div class="bar"><span class="stat grow" id="stat"></span><button id="theme" type="button" title="Hell/Dunkel">Hell/Dunkel</button><button class="primary" id="copy" type="button">Ergebnis kopieren</button></div>
<h1>POI-Durchsicht</h1>
<p class="lead">Runde 36, Teil P: alle %d Orte der Welt außerhalb der Städte, so wie die Kartengenerierung sie baut &ndash; jeder groß im Spiel, darunter klein der Grundriss und dieselbe Komposition im Material von zwei anderen Rassen (die beiden, die sich am stärksten von der eigenen unterscheiden). Ein Klick auf ein Bild öffnet es in voller Größe.</p>
<div class="ask"><b>Was du entscheiden solltest</b>
<ul>
<li>Pro Ort ein Urteil: <b>gut</b>, <b>langweilig</b> (wird in Teil W innerhalb derselben Fläche neu gestaltet) oder <b>andere Rasse</b> (mit der Rasse; dann tauscht Teil W nur das Material). Eine kurze Notiz ist optional.</li>
<li>Bei den Schlachtfeldern: einer der vier <b>Riss-Kandidaten</b> (Saltgate Remnant, Tombroad Ambush, Skyroot Crossing, Cloudwatch Fall) als Ort für das Finale.</li>
<li>Am Ende <b>&bdquo;Ergebnis kopieren&ldquo;</b> und den Text in den Chat einfügen. Es kommt eine Zeile pro Ort mit &bdquo;langweilig&ldquo;, &bdquo;andere Rasse&ldquo; oder einer Notiz, dazu die Riss-Wahl. Unbewertete Orte gelten als gut.</li>
</ul>
<p class="note-s">Deine Auswahl bleibt in diesem Browser gespeichert, auch wenn du die Seite schließt.</p>
</div>
<p class="note-s"><b>Wie genau die Bilder sind:</b> Jedes Bild ist aus genau den Blöcken gebaut, die das Spiel für den Ort setzt (dieselbe Bauplan-Funktion, im Spiel geprüft), mit den echten Texturen, plus Banner bzw. Lagerfeuer an den Außenposten und Banditenlagern. Nicht zu sehen sind das umliegende Gelände und seine Anpassung an den Ort, Wege von außen, Pflanzen, NPCs und Gegner. Die Zeichnung vereinfacht: keine Schatten oder Beleuchtung, Zäune, Stufen, Fackeln und Pflanzen nur angenähert. Die Ansicht schaut von Südwesten (bei Festungen und Lagern auf das Tor). Im Grundriss sind die Dächer abgeschnitten (alles bis 3 Blöcke über dem Boden), Norden ist oben, die Punkte sind die festen Plätze für Figuren:</p>
<div class="legend">%s</div>
<nav class="groups">%s</nav>
%s
<h2 id="ergebnis">Ergebnis</h2>
<p class="note-s">&bdquo;Ergebnis kopieren&ldquo; oben legt den Text in die Zwischenablage und zeigt ihn hier. Mit &bdquo;Alles zurücksetzen&ldquo; löschst du deine Auswahl.</p>
<textarea id="out" hidden readonly aria-label="Ergebnis"></textarea>
<p><button id="reset" type="button">Alles zurücksetzen</button></p>
<footer>%d Orte aus dem Siedlungs-Verzeichnis der Kartengenerierung (ohne die sechs Startorte und sechs Hauptstädte). Gebaut mit <code>tools/r36_p/</code> (dump.lua, render.py, page.py) auf den Werkzeugen <code>tools/wp13/render_blueprint.py</code> und <code>tools/r31_s/render.py</code>.</footer>
</main>
<script>%s</script>
</body></html>
""" % (CSS, len(pois), legend, "".join(nav), "".join(sections), len(pois), JS)
    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as fh:
        fh.write(page)
    sys.stderr.write("index.html: %d POIs, %d bytes\n" % (len(pois), len(page.encode("utf-8"))))


def main():
    out, data = sys.argv[1], sys.argv[2]
    with open(data, encoding="utf-8") as fh:
        write(out, json.load(fh))
    return 0


if __name__ == "__main__":
    sys.exit(main())

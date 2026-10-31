"""Static, offline Pass 3 comparison: choose one hart and one boar independently."""


def image_tag(src, size, alt, cls=''):
    return f'<img src="{src}" width="{size}" height="{size}" alt="{alt}" class="{cls}">'


def faction_panel(faction, variant, ideas):
    reference = variant in ('current', 'pass2')
    name = 'The '+faction.title()
    prefix = 'ref_pass2_' if variant=='pass2' else 'ref_'
    icon = prefix+f'emblem_{faction}.png' if reference else f'emblem_{faction}_{variant}.png'
    flat = prefix+f'banner_{faction}.png' if reference else f'banner_{faction}_{variant}.png'
    if reference:
        label = 'PASS 2 A' if variant=='pass2' else 'SHIPPED'
        title = ('The Oathhart' if faction=='accord' else 'The Unbowed Boar') if variant=='pass2' else 'Current emblem'
        sentence = 'Unchanged comparison: approved direction, superseded drawing.' if variant=='pass2' else 'Shipped art, copied unchanged for comparison.'
    else:
        label, title, sentence = ideas[faction][variant]
    sizes = ''.join(f'<div>{image_tag(icon,s,label+" "+name)}<span>{s} px</span></div>' for s in (16,24,32,64))
    people = ([('Elian','warrior','human',32),('Bera','scout','dwarf',48),('Saren','mage','elf',60)]
              if faction=='accord' else [('Dagra','warrior','orc',32),('Uro','priest','troll',48),('Vess','mage','undead',60)])
    rows = ''
    for player, job, race, level in people:
        rows += f'<tr><td>{image_tag(icon,26,label+" "+name)}</td><td>{player}</td><td>{image_tag("ref_class_"+job+".png",28,job,"pixel")}</td><td>{image_tag("ref_race_"+race+".png",28,race,"pixel")}</td><td>{level}</td></tr>'
    badge = '<span class="pick">Recommended</span>' if variant=='1' else ''
    return f'''<article class="faction {faction}" id="{faction}-{variant}">
    <div class="caption"><span class="faction-name">{name}</span>{badge}<h3><b>{label}</b> {title}</h3><p>{sentence}</p></div>
    <div class="sizes">{sizes}</div>
    <div class="mock-header">{image_tag(icon,54,label+" "+name)}<div><strong>GRUDGELANDS <b>/</b></strong><span>{name.upper()}</span></div><span class="close">×</span></div>
    <div class="table-wrap"><div class="table-title">SOCIAL <span>Online players</span></div><table><thead><tr><th>Faction</th><th>Name</th><th>Class</th><th>Race</th><th>Level</th></tr></thead><tbody>{rows}</tbody></table></div>
    <div class="banner-views"><figure><img src="{flat}" width="128" height="256" alt="{label} {name} flat 128 by 256 banner texture"><figcaption>Flat · 128 × 256</figcaption></figure>
    <figure class="projected"><img src="view_{faction}_{variant}.png" width="420" height="340" alt="{label} {name} banner projected on the existing mesh and a support pole"><figcaption>Existing mesh · camera ≈ 5 m away</figcaption></figure></div>
    </article>'''


def html_page(ideas, factions):
    sections = ''
    for faction in factions:
        animal = 'Harts' if faction=='accord' else 'Boars'
        sentence = ('Branching antlers, fine muzzles, quiet bearing.' if faction=='accord' else
                    'Long snouts, curved tusks, strong shoulders and ordered bristles.')
        sections += f'<section id="{faction}"><div class="section-heading"><span class="letter">'+('A' if faction=='accord' else 'B')+f'</span><div><h2>The {faction.title()} · {animal}</h2><p>{sentence} Choose one.</p></div></div><div class="gallery"><div class="trio">'+''.join(faction_panel(faction,key,ideas) for key in ('1','2','3'))+'</div></div></section>'
    for variant, title, sentence in (
        ('pass2', 'Pass 2 · Hart & Boar', 'The earlier A pair: palette and heraldic direction retained; drawings replaced.'),
        ('current', 'Current game art', 'The shipped motifs and cloth, copied unchanged.')):
        sections += f'<section id="{variant}"><div class="section-heading"><span class="letter">REF</span><div><h2>{title}</h2><p>{sentence}</p></div></div><div class="gallery"><div class="pair">'+''.join(faction_panel(f,variant,ideas) for f in factions)+'</div></div></section>'
    return ('''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Grudgelands · Hart & Boar · Pass 3</title><style>
:root{color-scheme:dark;--bg:#10151c;--panel:#181e28;--edge:#35404e;--ink:#e6e4df;--muted:#a8b4c4;--gold:#d7bf8b}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.6 system-ui,sans-serif}
main{max-width:1580px;margin:auto;padding:48px 24px 60px}h1,h2,h3,p{margin:0}h1{font:normal clamp(32px,4vw,54px)/1.13 Georgia,serif;letter-spacing:-.025em;margin:12px 0 20px}h2{font:normal 28px/1.3 Georgia,serif}h3{font:normal 21px/1.3 Georgia,serif;margin:9px 0}h3 b{font:700 13px system-ui,sans-serif;color:var(--gold);margin-right:7px}.eyebrow{color:var(--gold);font-size:12px;letter-spacing:.18em;text-transform:uppercase}.intro{max-width:850px;color:var(--muted);font-size:17px}
.recommendation{display:flex;gap:24px;align-items:center;border:1px solid #53647a;border-left:3px solid var(--gold);background:#1b2531;padding:24px;margin:28px 0 20px}.hero-icons{display:flex;gap:10px;flex-shrink:0}.recommendation strong{font-size:20px}.recommendation p{color:#c2ccd9;max-width:950px;margin-top:7px}
nav{display:flex;gap:9px;flex-wrap:wrap;margin:24px 0 42px}nav a{color:var(--ink);text-decoration:none;border:1px solid var(--edge);padding:8px 17px}nav a:hover,nav a:focus-visible{background:#293547}section{scroll-margin-top:20px;margin:0 0 48px}.section-heading{display:flex;gap:17px;align-items:center;margin-bottom:20px}.letter{display:grid;place-items:center;min-width:50px;height:50px;border:1px solid var(--edge);color:var(--gold);font-weight:700;font-size:17px}.section-heading p{color:var(--muted)}
.gallery{overflow-x:auto;padding-bottom:10px}.trio{display:grid;grid-template-columns:repeat(3,minmax(350px,1fr));gap:18px}.pair{display:grid;grid-template-columns:repeat(2,minmax(350px,1fr));gap:18px;max-width:1040px}.faction{background:var(--panel);border:1px solid var(--edge);overflow:hidden}.caption{padding:20px 20px 0;min-height:162px}.caption p{color:var(--muted);font-size:14px}.faction-name{text-transform:uppercase;letter-spacing:.13em;font-weight:700;font-size:11px}.accord .faction-name{color:#b1c5cc}.throng .faction-name{color:#cea69b}.pick{float:right;font-size:10px;color:var(--gold);text-transform:uppercase;letter-spacing:.08em}
.sizes{display:flex;align-items:end;justify-content:space-around;height:124px;margin:0 20px 22px;border-bottom:1px solid var(--edge);padding-bottom:18px;background:#181e28}.sizes>div{display:flex;flex-direction:column;align-items:center;gap:12px}.sizes span{font:11px ui-monospace,monospace;color:var(--muted)}img{object-fit:contain;vertical-align:middle}.pixel{image-rendering:pixelated}
.mock-header{height:86px;display:flex;gap:10px;align-items:center;margin:0 14px 20px;border:1px solid #4b4943;border-bottom:2px solid #847456;background:#202630;padding:10px}.mock-header>img{flex-shrink:0}.mock-header strong{font:700 14px/1.2 Georgia,serif;letter-spacing:.07em;color:#e3d6b7;white-space:nowrap}.mock-header b{color:#817766;margin-left:4px}.mock-header div>span{display:block;font-size:10px;letter-spacing:.17em;color:#bcc4cf;margin-top:5px}.close{margin-left:auto;color:#b7b3a7;font-size:20px}
.table-wrap{margin:0 14px 22px;border:1px solid var(--edge);background:#181e28}.table-title{font-size:11px;letter-spacing:.12em;padding:10px;background:#222c39;color:var(--gold)}.table-title span{color:var(--muted);margin-left:10px;letter-spacing:0}table{width:100%;border-collapse:collapse}th{color:#9caabc;text-transform:uppercase;font-size:9px;letter-spacing:.06em;font-weight:600}td,th{text-align:center;padding:7px 4px;border-bottom:1px solid #2c3541}td:nth-child(2),th:nth-child(2){text-align:left}td{font-size:13px}tbody tr:last-child td{border:0}
.banner-views{display:grid;grid-template-columns:128px minmax(0,1fr);gap:4px;align-items:center;margin:12px 12px 20px}figure{margin:0;text-align:center}.banner-views figure>img{max-width:100%;height:auto}.banner-views figure:first-child{background:repeating-conic-gradient(#242d38 0% 25%,#202833 0% 50%) 0/16px 16px}figcaption{font-size:10px;color:var(--muted);padding:8px 2px;background:var(--panel)}
.notes{max-width:1050px;border-top:1px solid var(--edge);padding-top:24px;color:var(--muted)}.notes p{margin-bottom:12px}.palette{display:flex;flex-wrap:wrap;gap:16px;margin:20px 0}.swatch{display:inline-block;width:17px;height:17px;border:1px solid #8c8270;vertical-align:middle;margin-right:7px}.notes a{color:var(--gold)}
@media(max-width:750px){main{padding:28px 12px}.recommendation{align-items:flex-start;flex-direction:column;padding:18px}.hero-icons img{width:76px;height:76px}.section-heading p{font-size:13px}h2{font-size:24px}}
</style></head><body><main>
<header><div class="eyebrow">Round 67 · EMBLEM · Pass 3 · independent choices</div><h1>A hart for The Accord.<br>A boar for The Throng.</h1><p class="intro">Six new drawings in one heraldic language: deliberate contours, open antler branches, clear animal anatomy. Old ivory on muted cloth, with a fine tarnished-gold shield rim. Choose any hart with any boar.</p></header>
<aside class="recommendation"><div class="hero-icons">'''+image_tag('emblem_accord_1.png',100,'Recommended A1 hart')+image_tag('emblem_throng_1.png',100,'Recommended B1 boar')+'''</div><div><strong>Recommendation: A1 + B1</strong><p>The front-facing hart gives The Accord an upright, balanced silhouette; the boar's long profile gives The Throng a forward thrust. Both put the animal's identifying features into the largest possible area of the shield. A2 and B2 offer full-body heraldry; A3 and B3 give alternative head treatments.</p></div></aside>
<div class="palette"><span><i class="swatch" style="background:#344b5a"></i>Slate blue</span><span><i class="swatch" style="background:#683e39"></i>Wine red</span><span><i class="swatch" style="background:#d6c59b"></i>Old ivory</span><span><i class="swatch" style="background:#aa9164"></i>Tarnished gold</span></div>
<nav aria-label="Preview sections"><a href="#accord">A1 / A2 / A3 · Harts</a><a href="#throng">B1 / B2 / B3 · Boars</a><a href="#pass2">Pass 2 A</a><a href="#current">Current art</a><a href="contact.png">Contact sheet</a></nav>
'''+sections+'''
<footer class="notes"><p>All icon samples use the same 100 × 100 RGBA file, scaled to the labelled CSS size. The header uses 54 px; Social rows use 26 px faction icons alongside the unchanged class and race icons. At 16 px, fine engraving and tines soften; judge the silhouette and faction field. The full-body alternatives necessarily give less space to the head. At narrow window widths, scroll each animal row sideways to retain the side-by-side comparison.</p><p>Each 128 × 256 banner preserves the shipped alpha exactly. The camera is approximately 5 m from the existing B3D mesh at rest; the post and beam provide illustrative context. These projections are offline comparisons, not game captures. Fabric, faded edges, gold corner vines and the worn hem retain Pass 2's treatment. The ornaments may disappear at distance.</p><p>All images are beside this page. No network requests, web fonts or scripts. Proposals only; desktop and web game acceptance follows the user's pick and coordinator integration.</p></footer>
</main></body></html>
''').encode()

"""Static, offline Pass 4 comparison: three pairs of frontal animal heads."""


def image_tag(src, size, alt, cls=''):
    return f'<img src="{src}" width="{size}" height="{size}" alt="{alt}" class="{cls}">'


def faction_panel(faction, variant, ideas):
    reference = variant in ('current', 'pass3')
    name = 'The '+faction.title()
    prefix = 'ref_pass3_' if variant=='pass3' else 'ref_'
    icon = prefix+f'emblem_{faction}.png' if reference else f'emblem_{faction}_{variant}.png'
    flat = prefix+f'banner_{faction}.png' if reference else f'banner_{faction}_{variant}.png'
    if reference:
        label = 'PASS 3' if variant=='pass3' else 'SHIPPED'
        title = ('A1 / The Watchful Hart' if faction=='accord' else 'B3 / The Defiant Boar') if variant=='pass3' else 'Current emblem'
        sentence = 'Unchanged Pass 3 choice: frontal direction retained, drawing superseded.' if variant=='pass3' else 'Shipped art, copied unchanged for comparison.'
    else:
        label, title, sentence = ideas[faction][variant]
    sizes = ''.join(f'<div>{image_tag(icon,s,label+" "+name)}<span>{s} px</span></div>' for s in (16,24,32,64))
    people = ([('Elian','warrior','human',32),('Bera','scout','dwarf',48),('Saren','mage','elf',60)]
              if faction=='accord' else [('Dagra','warrior','orc',32),('Uro','priest','troll',48),('Vess','mage','undead',60)])
    rows = ''
    for player, job, race, level in people:
        rows += f'<tr><td>{image_tag(icon,26,label+" "+name)}</td><td>{player}</td><td>{image_tag("ref_class_"+job+".png",28,job,"pixel")}</td><td>{image_tag("ref_race_"+race+".png",28,race,"pixel")}</td><td>{level}</td></tr>'
    badge = '<span class="pick">Recommended</span>' if variant=='1' else ''
    enlarged = '' if reference else f'<figure class="enlarged">{image_tag("large_"+faction+"_"+variant+".png",300,label+" enlarged drawing")}<figcaption>300 px drawing study · from the same master</figcaption></figure>'
    return f'''<article class="faction {faction}" id="{faction}-{variant}">
    <div class="caption"><span class="faction-name">{name}</span>{badge}<h3><b>{label}</b> {title}</h3><p>{sentence}</p></div>
{enlarged}
    <div class="sizes">{sizes}</div>
    <div class="mock-header">{image_tag(icon,54,label+" "+name)}<div><strong>GRUDGELANDS <b>/</b></strong><span>{name.upper()}</span></div><span class="close">×</span></div>
    <div class="table-wrap"><div class="table-title">SOCIAL <span>Online players</span></div><table><thead><tr><th>Faction</th><th>Name</th><th>Class</th><th>Race</th><th>Level</th></tr></thead><tbody>{rows}</tbody></table></div>
    <div class="banner-views"><figure><img src="{flat}" width="128" height="256" alt="{label} {name} flat 128 by 256 banner texture"><figcaption>Flat · 128 × 256</figcaption></figure>
    <figure class="projected"><img src="view_{faction}_{variant}.png" width="420" height="340" alt="{label} {name} banner projected on the existing mesh and a support pole"><figcaption>Existing mesh · camera ≈ 5 m away</figcaption></figure></div>
    </article>'''


def html_page(ideas, factions, pairs):
    sections = ''
    for key, (title, sentence) in pairs.items():
        sections += f'<section id="pair-{key}"><div class="section-heading"><span class="letter">{key}</span><div><h2>H{key} + K{key} · {title}</h2><p>{sentence}</p></div></div><div class="gallery"><div class="pair">'+''.join(faction_panel(f,key,ideas) for f in factions)+'</div></div></section>'
    for variant, title, sentence in (
        ('pass3', 'Pass 3 · A1 + B3', 'The selected frontal direction, unchanged for direct comparison.'),
        ('current', 'Current game art', 'The shipped motifs and cloth, copied unchanged.')):
        sections += f'<section id="{variant}"><div class="section-heading"><span class="letter">REF</span><div><h2>{title}</h2><p>{sentence}</p></div></div><div class="gallery"><div class="pair">'+''.join(faction_panel(f,variant,ideas) for f in factions)+'</div></div></section>'
    return ('''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Grudgelands · Hart & Boar · Pass 4</title><style>
:root{color-scheme:dark;--bg:#10151c;--panel:#181e28;--edge:#35404e;--ink:#e6e4df;--muted:#a8b4c4;--gold:#d7bf8b}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.6 system-ui,sans-serif}
main{max-width:1180px;margin:auto;padding:48px 24px 60px}h1,h2,h3,p{margin:0}h1{font:normal clamp(32px,4vw,54px)/1.13 Georgia,serif;letter-spacing:-.025em;margin:12px 0 20px}h2{font:normal 28px/1.3 Georgia,serif}h3{font:normal 21px/1.3 Georgia,serif;margin:9px 0}h3 b{font:700 13px system-ui,sans-serif;color:var(--gold);margin-right:7px}.eyebrow{color:var(--gold);font-size:12px;letter-spacing:.18em;text-transform:uppercase}.intro{max-width:850px;color:var(--muted);font-size:17px}
.recommendation{display:flex;gap:24px;align-items:center;border:1px solid #53647a;border-left:3px solid var(--gold);background:#1b2531;padding:24px;margin:28px 0 20px}.hero-icons{display:flex;gap:10px;flex-shrink:0}.recommendation strong{font-size:20px}.recommendation p{color:#c2ccd9;max-width:950px;margin-top:7px}
nav{display:flex;gap:9px;flex-wrap:wrap;margin:24px 0 42px}nav a{color:var(--ink);text-decoration:none;border:1px solid var(--edge);padding:8px 17px}nav a:hover,nav a:focus-visible{background:#293547}section{scroll-margin-top:20px;margin:0 0 48px}.section-heading{display:flex;gap:17px;align-items:center;margin-bottom:20px}.letter{display:grid;place-items:center;min-width:50px;height:50px;border:1px solid var(--edge);color:var(--gold);font-weight:700;font-size:17px}.section-heading p{color:var(--muted)}
.gallery{overflow-x:auto;padding-bottom:10px}.pair{display:grid;grid-template-columns:repeat(2,minmax(350px,1fr));gap:18px;max-width:1120px}.faction{background:var(--panel);border:1px solid var(--edge);overflow:hidden}.caption{padding:20px 20px 0;min-height:145px}.enlarged{padding:4px 0 8px;background:#181e28}.enlarged img{width:300px;height:300px}.enlarged figcaption{font-size:10px;color:var(--muted)}.caption p{color:var(--muted);font-size:14px}.faction-name{text-transform:uppercase;letter-spacing:.13em;font-weight:700;font-size:11px}.accord .faction-name{color:#b1c5cc}.throng .faction-name{color:#cea69b}.pick{float:right;font-size:10px;color:var(--gold);text-transform:uppercase;letter-spacing:.08em}
.sizes{display:flex;align-items:end;justify-content:space-around;height:124px;margin:0 20px 22px;border-bottom:1px solid var(--edge);padding-bottom:18px;background:#181e28}.sizes>div{display:flex;flex-direction:column;align-items:center;gap:12px}.sizes span{font:11px ui-monospace,monospace;color:var(--muted)}img{object-fit:contain;vertical-align:middle}.pixel{image-rendering:pixelated}
.mock-header{height:86px;display:flex;gap:10px;align-items:center;margin:0 14px 20px;border:1px solid #4b4943;border-bottom:2px solid #847456;background:#202630;padding:10px}.mock-header>img{flex-shrink:0}.mock-header strong{font:700 14px/1.2 Georgia,serif;letter-spacing:.07em;color:#e3d6b7;white-space:nowrap}.mock-header b{color:#817766;margin-left:4px}.mock-header div>span{display:block;font-size:10px;letter-spacing:.17em;color:#bcc4cf;margin-top:5px}.close{margin-left:auto;color:#b7b3a7;font-size:20px}
.table-wrap{margin:0 14px 22px;border:1px solid var(--edge);background:#181e28}.table-title{font-size:11px;letter-spacing:.12em;padding:10px;background:#222c39;color:var(--gold)}.table-title span{color:var(--muted);margin-left:10px;letter-spacing:0}table{width:100%;border-collapse:collapse}th{color:#9caabc;text-transform:uppercase;font-size:9px;letter-spacing:.06em;font-weight:600}td,th{text-align:center;padding:7px 4px;border-bottom:1px solid #2c3541}td:nth-child(2),th:nth-child(2){text-align:left}td{font-size:13px}tbody tr:last-child td{border:0}
.banner-views{display:grid;grid-template-columns:128px minmax(0,1fr);gap:4px;align-items:center;margin:12px 12px 20px}figure{margin:0;text-align:center}.banner-views figure>img{max-width:100%;height:auto}.banner-views figure:first-child{background:repeating-conic-gradient(#242d38 0% 25%,#202833 0% 50%) 0/16px 16px}figcaption{font-size:10px;color:var(--muted);padding:8px 2px;background:var(--panel)}
.notes{max-width:1050px;border-top:1px solid var(--edge);padding-top:24px;color:var(--muted)}.notes p{margin-bottom:12px}.palette{display:flex;flex-wrap:wrap;gap:16px;margin:20px 0}.swatch{display:inline-block;width:17px;height:17px;border:1px solid #8c8270;vertical-align:middle;margin-right:7px}.notes a{color:var(--gold)}
@media(max-width:750px){main{padding:28px 12px}.recommendation{align-items:flex-start;flex-direction:column;padding:18px}.hero-icons img{width:76px;height:76px}.section-heading p{font-size:13px}h2{font-size:24px}}
</style></head><body><main>
<header><div class="eyebrow">Round 67 · EMBLEM · Pass 4 · frontal heraldry</div><h1>The watchful hart.<br>The defiant boar.</h1><p class="intro">Three matched pairs of frontal heads. Broad brows and flared ears for The Accord; long snouts and great curved tusks for The Throng. Symmetrical contours, old ivory and tarnished gold on weathered blue and wine-red shields.</p></header>
<aside class="recommendation"><div class="hero-icons">'''+image_tag('emblem_accord_1.png',100,'Recommended H1 hart')+image_tag('emblem_throng_1.png',100,'Recommended K1 boar')+'''</div><div><strong>Recommendation: H1 + K1</strong><p>The painted pair gives the ears, antlers and tusks the most space. Its calm ivory faces read best in the small Social rows. H2 + K2 adds carved detail; H3 + K3 adds stitched edges. All three pairs share the muted cloth, shield and scale, so individual choices also fit together.</p></div></aside>
<div class="palette"><span><i class="swatch" style="background:#344b5a"></i>Slate blue</span><span><i class="swatch" style="background:#683e39"></i>Wine red</span><span><i class="swatch" style="background:#d6c59b"></i>Old ivory</span><span><i class="swatch" style="background:#aa9164"></i>Tarnished gold</span></div>
<nav aria-label="Preview sections"><a href="#pair-1">H1 + K1 · Painted</a><a href="#pair-2">H2 + K2 · Engraved</a><a href="#pair-3">H3 + K3 · Stitched</a><a href="#pass3">Pass 3 A1 + B3</a><a href="#current">Current art</a><a href="heads.png">All six heads</a><a href="contact.png">Usage contact sheet</a></nav>
'''+sections+'''
<footer class="notes"><p>All icon samples use the same 100 × 100 RGBA file, scaled to the labelled CSS size. The header uses 54 px; Social rows use 26 px faction icons alongside the unchanged class and race icons. At 16 px, fine engraving and tines soften; judge the silhouette and faction field. The 300 px views are reduced directly from the same 600 px drawing master, without enlarging the delivered 100 px icon. At narrow window widths, scroll each pair sideways to retain the side-by-side comparison.</p><p>Each 128 × 256 banner preserves the shipped alpha exactly. The camera is approximately 5 m from the existing B3D mesh at rest; the post and beam provide illustrative context. These projections are offline comparisons, not game captures. Fabric, faded edges, gold corner vines and the worn hem retain the accepted Pass 2/3 treatment. The ornaments may disappear at distance.</p><p>All images are beside this page. No network requests, web fonts or scripts. Proposals only; desktop and web game acceptance follows the user's pick and coordinator integration.</p></footer>
</main></body></html>
''').encode()

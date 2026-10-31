"""Static HTML for the Round 67 emblem proposal generator."""


def image_tag(src, size, alt, cls=''):
    return f'<img src="{src}" width="{size}" height="{size}" alt="{alt}" class="{cls}">'


def faction_panel(faction, variant, ideas):
    current = variant == 'current'
    name = 'The '+faction.title()
    icon = f'ref_emblem_{faction}.png' if current else f'emblem_{faction}_{variant}.png'
    flat = f'ref_banner_{faction}.png' if current else f'banner_{faction}_{variant}.png'
    title = 'Current emblem' if current else ideas[variant][1 if faction=='accord' else 2]
    sentence = ('Shipped art, copied unchanged for comparison.' if current else
                ideas[variant][3 if faction=='accord' else 4])
    sizes = ''.join(f'<div>{image_tag(icon,s,name)}<span>{s} px</span></div>' for s in (16,24,32,64))
    people = ([('Elian','warrior','human',32),('Bera','scout','dwarf',48),('Saren','mage','elf',60)]
              if faction=='accord' else [('Dagra','warrior','orc',32),('Uro','priest','troll',48),('Vess','mage','undead',60)])
    rows=''
    for player,job,race,level in people:
        rows+=f'<tr><td>{image_tag(icon,26,name)}</td><td>{player}</td><td>{image_tag("ref_class_"+job+".png",28,job,"pixel")}</td><td>{image_tag("ref_race_"+race+".png",28,race,"pixel")}</td><td>{level}</td></tr>'
    return f"""<article class="faction {faction}">
    <div class="caption"><span class="faction-name">{name}</span><h3>{title}</h3><p>{sentence}</p></div>
    <div class="sizes">{sizes}</div>
    <div class="mock-header">{image_tag(icon,54,name)}<div><strong>GRUDGELANDS <b>/</b></strong><span>{name.upper()}</span></div><span class="close">×</span></div>
    <div class="table-wrap"><div class="table-title">SOCIAL <span>Online players</span></div><table><thead><tr><th>Faction</th><th>Name</th><th>Class</th><th>Race</th><th>Level</th></tr></thead><tbody>{rows}</tbody></table></div>
    <div class="banner-views"><figure><img src="{flat}" width="128" height="256" alt="{name} flat 128 by 256 banner atlas"><figcaption>Flat texture · 128 × 256</figcaption></figure>
    <figure class="projected"><img src="view_{faction}_{variant}.png" width="420" height="340" alt="{name} banner on the existing mesh with a mock support pole"><figcaption>Existing mesh · camera ≈ 5 m away</figcaption></figure></div>
    </article>"""


def html_page(ideas,factions):
    sections=''
    for key in (*ideas,'current'):
        title=ideas[key][0] if key!='current' else 'Current emblems'
        label=key.upper() if key!='current' else 'NOW'
        subtitle=('Recommended · strongest open silhouettes' if key=='a' else
                  'Homeland and collective strength' if key=='b' else
                  'Martial symbols · closer to equipment iconography' if key=='c' else
                  'Unchanged reference files from the game')
        sections+=f'<section id="{key}"><div class="section-heading"><span class="letter">{label}</span><div><h2>{title}</h2><p>{subtitle}</p></div></div><div class="pair">'+''.join(faction_panel(f,key,ideas) for f in factions)+'</div></section>'
    return ("""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Grudgelands · faction emblem study</title><style>
:root{color-scheme:dark;--bg:#10151c;--panel:#181e28;--edge:#35404e;--ink:#e6e4df;--muted:#a8b4c4;--gold:#d7bf8b}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.6 system-ui,sans-serif}
main{max-width:1320px;margin:auto;padding:54px 32px 70px}h1,h2,h3,p{margin:0}h1{font-size:clamp(32px,4vw,54px);line-height:1.12;letter-spacing:-.045em;margin:12px 0 20px;max-width:820px}h2{font-size:27px;letter-spacing:-.025em}h3{font-size:23px;margin:6px 0}.eyebrow{color:var(--gold);font-size:12px;letter-spacing:.18em;text-transform:uppercase}.intro{max-width:790px;color:var(--muted);font-size:17px}
.recommendation{display:flex;gap:26px;align-items:center;border:1px solid #53647a;border-left:4px solid var(--gold);background:#1b2531;padding:25px 28px;margin:30px 0 20px;border-radius:3px}.hero-icons{display:flex;gap:15px;flex-shrink:0}.recommendation strong{font-size:20px}.recommendation p{color:#c2ccd9;max-width:830px;margin-top:6px}
nav{display:flex;gap:9px;flex-wrap:wrap;margin:24px 0 42px}nav a{color:var(--ink);text-decoration:none;border:1px solid var(--edge);padding:8px 17px;border-radius:4px}nav a:hover{background:#293547}section{scroll-margin-top:20px;margin:0 0 50px}.section-heading{display:flex;gap:17px;align-items:center;margin-bottom:20px}.letter{display:grid;place-items:center;min-width:50px;height:50px;border:1px solid var(--edge);color:var(--gold);font-weight:700;font-size:20px}.section-heading p{color:var(--muted)}
.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}.faction{background:var(--panel);border:1px solid var(--edge);border-radius:5px;overflow:hidden}.caption{padding:24px 24px 0;min-height:150px}.caption p{color:var(--muted);max-width:490px}.faction-name{text-transform:uppercase;letter-spacing:.13em;font-weight:700;font-size:11px}.accord .faction-name{color:#9fbfff}.throng .faction-name{color:#ffa8b4}
.sizes{display:flex;align-items:end;justify-content:space-around;height:126px;margin:0 24px 22px;border-bottom:1px solid var(--edge);padding-bottom:18px;background:#181e28}.sizes>div{display:flex;flex-direction:column;align-items:center;gap:12px}.sizes span{font:11px ui-monospace,monospace;color:var(--muted)}img{object-fit:contain;vertical-align:middle}.pixel{image-rendering:pixelated}
.mock-header{height:88px;display:flex;gap:15px;align-items:center;margin:0 20px 22px;border:1px solid #4b4943;border-bottom:2px solid #847456;background:#202630;padding:12px 14px}.mock-header strong{font:700 16px/1.2 Georgia,serif;letter-spacing:.12em;color:#e3d6b7}.mock-header b{color:#817766;margin-left:5px}.mock-header div>span{display:block;font-size:10px;letter-spacing:.18em;color:#bcc4cf;margin-top:5px}.close{margin-left:auto;color:#b7b3a7;font-size:22px}
.table-wrap{margin:0 20px 24px;border:1px solid var(--edge);background:#181e28}.table-title{font-size:11px;letter-spacing:.12em;padding:10px 12px;background:#222c39;color:var(--gold)}.table-title span{color:var(--muted);margin-left:12px;letter-spacing:0}table{width:100%;border-collapse:collapse}th{color:#9caabc;text-transform:uppercase;font-size:9px;letter-spacing:.08em;font-weight:600}td,th{text-align:center;padding:7px 5px;border-bottom:1px solid #2c3541}td:nth-child(2),th:nth-child(2){text-align:left}td{font-size:13px}tbody tr:last-child td{border:0}
.banner-views{display:grid;grid-template-columns:128px minmax(0,1fr);gap:8px;align-items:center;margin:12px 16px 22px}figure{margin:0;text-align:center}.banner-views figure>img{max-width:100%;height:auto}.banner-views figure:first-child{background:repeating-conic-gradient(#242d38 0% 25%,#202833 0% 50%) 0/16px 16px}.projected{align-self:center}figcaption{font-size:10px;color:var(--muted);padding:9px 3px;background:var(--panel)}
.notes{max-width:1000px;border-top:1px solid var(--edge);padding-top:25px;color:var(--muted);font-size:13px}.notes p+p{margin-top:12px}.notes strong{color:var(--ink)}.swatch{display:inline-block;width:11px;height:11px;border-radius:2px;margin-right:5px}footer{margin-top:24px;color:#8290a2;font-size:11px}
@media(max-width:900px){main{padding:30px 18px}.pair{grid-template-columns:1fr}.caption{min-height:0}.sizes{margin-top:20px}.recommendation{align-items:flex-start;padding:20px;flex-direction:column}.hero-icons img{width:64px;height:64px}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
</style></head><body><main><header><div class="eyebrow">Grudgelands / Round 67 / Emblem proposals</div>
<h1>Two standards.<br>One old rivalry.</h1>
<p class="intro">Three original motif pairs for The Accord and The Throng. Each pair shares a bold, cut-metal construction; the silhouette carries the identity from a small player row to a camp banner.</p>
<div class="recommendation"><div class="hero-icons"><img src="emblem_accord_a.png" width="88" height="88" alt="Recommended Accord Oathwing"><img src="emblem_throng_a.png" width="88" height="88" alt="Recommended Throng Oathjaw"></div><div><strong>Recommendation: A · Wing &amp; Tusk</strong><p>The wide, descending wing and the open, rising jaw are the clearest opposites at 24 px. Both remain distinct as 16 px colour shapes, without depending on tiny interior lines. Blue and red carry the UI; light ink carries the same silhouettes on the cloth.</p></div></div>
<nav aria-label="Variants"><a href="#a">A · Wing &amp; Tusk</a><a href="#b">B · Root &amp; Horn</a><a href="#c">C · Lance &amp; Maul</a><a href="#current">Current art</a></nav></header>
""" + sections + """
<div class="notes"><p><strong>Read at 100% browser zoom.</strong> The size strips use 16, 24, 32 and 64 CSS pixels on #181e28; headers use 54 px and player rows 26 px. All sizes use the same 100 × 100 master. Browser display scaling and game filtering can differ. Class and race pictures are the shipped files.</p>
<p><strong>Faction colour:</strong> <span class="swatch" style="background:#3f6fce"></span>The Accord #3f6fce · <span class="swatch" style="background:#c41e3a"></span>The Throng #c41e3a. UI symbols use two flat colours plus edge antialiasing. Banner ink uses the identical motif outline in warm ivory, on faction cloth with a dark edge and a simple sewn hem.</p>
<p><strong>Banner study:</strong> the 128 × 256 textures retain the shipped alpha silhouette exactly. The projections read the existing B3D cloth, rod, straps and UV coordinates, at rest; only the support post and beam are illustrative. One node is treated as one metre; camera distance is approximately 5 m. These are offline projections with a common camera and light, not game captures or a desktop/web acceptance test.</p>
<p><strong>Choice:</strong> pick A, B or C as a pair, or name one variant per faction. These are proposals; no game assets have been replaced.</p></div>
<footer>Original emblem artwork · CC0-1.0 · Local assets only · No scripts, fonts or images fetched from the network</footer></main></body></html>
""").encode('utf-8')

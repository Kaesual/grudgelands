#!/usr/bin/env python3
"""Bake original paintings, authored frames and the offline review gallery."""
import html
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MOD = ROOT / "mods/ITEMS/grug_decor"
rows = json.loads((HERE / "manifest.json").read_text())


def frame(size):
    lines = ["# Original Grudgelands frame; node coordinates; wood then canvas.",
             "vt 0 0", "vt 1 0", "vt 1 1", "vt 0 1"]
    # Irrlicht changes OBJ handedness: negate X and reverse faces for game coordinates.
    count = 0

    def box(x0, y0, z0, x1, y1, z1):
        nonlocal count
        verts = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
                 (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
        lines.extend("v %g %g %g" % (-x,y,z) for x,y,z in verts)
        for face in [(1,4,3,2),(5,6,7,8),(1,5,8,4),(2,3,7,6),(4,8,7,3),(1,2,6,5)]:
            lines.append("f " + " ".join(f"{count+i}/{uv}" for i,uv in reversed(list(zip(face,[1,4,3,2])))))
        count += 8

    lo, hi, rim = -.46, size-.54, .065
    lines.extend(["g wood", "usemtl wood"])
    box(lo,lo,.43,lo+rim,hi,.495)
    box(hi-rim,lo,.43,hi,hi,.495)
    box(lo+rim,lo,.43,hi-rim,lo+rim,.495)
    box(lo+rim,hi-rim,.43,hi-rim,hi,.495)
    box(lo+rim,lo+rim,.475,hi-rim,hi-rim,.495)
    lines.extend(["g canvas", "usemtl canvas"])
    # Front faces -Z. As seen from the room, local +X is image-right.
    for v in [(lo+rim,lo+rim,.44),(lo+rim,hi-rim,.44),
              (hi-rim,hi-rim,.44),(hi-rim,lo+rim,.44)]:
        lines.append("v %g %g %g" % (-v[0],v[1],v[2]))
    lines.append("f " + " ".join(f"{count+i}/{uv}" for i,uv in reversed(list(zip([1,2,3,4],[1,4,3,2])))))
    return "\n".join(lines)+"\n"


for size in (1, 2):
    (MOD / "models" / f"grug_decor_painting_{size}.obj").write_text(frame(size))

catalog = ["-- Original paintings. Prices in copper; nil means reward-only.", "return {"]
cards = []
for row in rows:
    ident = row["id"]
    size = 1 if ident in {"silverwood", "marsh", "savanna", "still_life", "tavern"} else 2
    price = None if row["expedition"] else (5000 if size == 1 else 10000)
    texture = f"grug_decor_painting_{ident}.png"
    subprocess.run(["magick", str(HERE / "source" / f"{ident}.png"),
                    "-resize", "256x256!", "-strip", str(MOD / "textures" / texture)], check=True)
    title = row["title"].replace("’", "'")
    fields = f'id = "{ident}", title = {json.dumps(title)}, size = {size}'
    fields += f', expedition = "{row["expedition"]}"' if row["expedition"] else f", price = {price}"
    catalog.append("\t{" + fields + "},")
    source = f"Reward Chest: {row['expedition']} · 2%" if row["expedition"] else f"Decoration Merchant · {price/100:g} Silber"
    cards.append(f'<article><a href="source/{ident}.png"><img src="../../mods/ITEMS/grug_decor/textures/{texture}" alt="{html.escape(title)}" loading="lazy"></a>'
                 f'<h2>{html.escape(title)}</h2><p>{size} × {size} Blöcke · {html.escape(source)}</p></article>')
catalog.append("}")
(MOD / "paintings_catalog.lua").write_text("\n".join(catalog)+"\n")
(HERE / "index.html").write_text('''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Grudgelands — Wandbilder</title><style>
*{box-sizing:border-box}body{margin:0;background:#191d1b;color:#e9e2cf;font:17px/1.5 system-ui,sans-serif}header,main{max-width:1400px;margin:auto;padding:28px}h1{font:40px Georgia,serif;margin:0}header p{max-width:850px;color:#c1bfaf}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:24px}article{background:#282e29;border:1px solid #505449;padding:16px}img{display:block;width:100%;aspect-ratio:1;image-rendering:auto;border:10px solid #594331;box-shadow:0 3px 8px #0008}h2{font:23px Georgia,serif}article p{color:#c1bfaf;font-size:14px}a{color:#b9ceaf}
</style><header><h1>Bilder aus Grudgelands</h1><p>16 eigene Motive für die Häuser der Spieler und ausgewählte Stadtgebäude. Hier siehst du die tatsächlichen 256-Pixel-Spieltexturen; ein Klick öffnet den großen Entwurf. Die drei Expeditionsbilder gibt es ausschließlich mit 2% Chance in der jeweiligen persönlichen Reward Chest, einmal pro Durchlauf.</p><p>Stadtansichten sind gemalte Interpretationen. Die Handelskarte ist ein dekoratives Motiv, keine Navigationskarte. In Stadtgebäuden nutzen wir kleinere, nicht erbeutbare Fassungen.</p><a href="../decoration_study/dist/index.html">Zur ursprünglichen Dekorationsübersicht</a></header><main>'''+"\n".join(cards)+"</main></html>\n")
print(f"Built {len(rows)} paintings, two frames and the offline gallery")

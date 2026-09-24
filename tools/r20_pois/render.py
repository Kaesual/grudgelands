#!/usr/bin/env python3
"""Draw reviewable top-down/isometric SVGs from final emitted voxel TSVs.

This is a schematic geometry review, not an engine/media screenshot. Actual
node names are retained in tooltips; colors are deterministic material hints.
"""
from pathlib import Path
import html
import sys

output = Path(sys.argv[1])

def color(name):
    families = [
        (("air",), "#dce5ee"), (("candle", "lantern", "lamp"), "#ffc66f"),
        (("glass",), "#95c9db"), (("leaves", "flower", "viola", "fern"), "#537652"),
        (("desert", "acacia", "clay"), "#a56a43"), (("grave", "bone"), "#747277"),
        (("silver",), "#bbbda6"), (("jungle",), "#725438"),
        (("slate",), "#555b70"), (("pine", "tree", "wood", "bench"), "#976e42"),
        (("dirt", "grass", "litter"), "#758062"), (("loam",), "#d1bb94"),
        (("stone", "cobble",), "#929393"), (("barrel", "straw",), "#b89759"),
    ]
    for tokens, value in families:
        if any(token in name for token in tokens):
            return value
    return "#b68d6d"

def shade(value, factor):
    return "#" + "".join(f"{int(int(value[n:n+2],16)*factor):02x}" for n in (1,3,5))

def polygon(points, fill, title=""):
    coords = " ".join(f"{x:.1f},{y:.1f}" for x,y in points)
    return f'<polygon points="{coords}" fill="{fill}" stroke="#2229" stroke-width=".3"><title>{html.escape(title)}</title></polygon>'

entries = []
for path in sorted(output.glob("anchor_*.tsv")):
    rows = path.read_text().splitlines()
    label = rows[0].removeprefix("# ")
    cells = {(int(x),int(y),int(z)): name for row in rows[1:]
             for x,y,z,name,_ in [row.split("\t")]}
    lo = min(x for x,_,_ in cells); hi = max(x for x,_,_ in cells)
    size = hi-lo+1
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="620" viewBox="0 0 1100 620">',
           '<rect width="1100" height="620" fill="#f3f0e7"/>',
           f'<text x="25" y="32" font-family="sans-serif" font-size="23">{html.escape(path.stem+" — "+label)}</text>',
           '<text x="25" y="57" font-family="sans-serif" font-size="14">Actual emitted cells; schematic colors, no engine textures. Top-down north is up.</text>']
    top = {}
    for (x,y,z),name in cells.items():
        if (x,z) not in top or y>top[x,z][0]:
            top[x,z]=(y,name)
    scale = min(15,430/size)
    for (x,z),(y,name) in sorted(top.items()):
        sx,sy=25+(x-lo)*scale,100+(hi-z)*scale
        svg.append(polygon([(sx,sy),(sx+scale,sy),(sx+scale,sy+scale),(sx,sy+scale)],color(name),f"{x},{y},{z}: {name}"))
    def project(x,y,z):
        return 785+(x-z)*9,390+(x+z)*4.5-y*12
    for (x,y,z),name in sorted(cells.items(), key=lambda pair:(sum((pair[0][0],pair[0][2])),pair[0][1])):
        c=color(name)
        title=f"{x},{y},{z}: {name}"
        faces=[([(x,y,z+1),(x+1,y,z+1),(x+1,y+1,z+1),(x,y+1,z+1)],.72,(x,y,z+1)),
               ([(x+1,y,z),(x+1,y,z+1),(x+1,y+1,z+1),(x+1,y+1,z)],.86,(x+1,y,z)),
               ([(x,y+1,z),(x+1,y+1,z),(x+1,y+1,z+1),(x,y+1,z+1)],1,(x,y+1,z))]
        for face,factor,neighbor in faces:
            if neighbor not in cells:
                svg.append(polygon([project(*p) for p in face],shade(c,factor),title))
    svg.append('</svg>')
    target=path.with_suffix('.svg'); target.write_text('\n'.join(svg))
    entries.append(f'<article><h2>{html.escape(label)}</h2><img src="{target.name}" style="max-width:100%"/></article>')
(output/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Round 20 emitted geometry</title><style>body{font-family:sans-serif;background:#dedbd1;margin:2rem}article{margin-bottom:2rem}</style><h1>Round 20 emitted geometry</h1>'+''.join(entries))
print(f"Rendered {len(entries)} actual-cell schematic views")

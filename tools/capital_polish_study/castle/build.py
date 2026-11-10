#!/usr/bin/env python3
"""Preview side-wall alternatives using the shipped templates; never edit mods."""
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / 'tools/r70_castle'))
import build as C
V, G, T = C.V, C.G, C.T
registry = json.loads(Path(V.NODES_JSON).read_text())
nodes = registry['nodes']
palettes = T.Palettes(G.load_palettes(V.find_lua(), set(nodes) | set(registry.get('aliases', {}))))
original, sockets = C.current(palettes, 'human')
variants = {'current': dict(original), 'closed': dict(original), 'pillars': dict(original)}
# Local template coordinates, mirrored on both sides. The original structural
# material at the portal jamb supplies the replacement, not a guessed palette.
for x, outside in [(4, 2), (40, 42)]:
    material = original[(x, 4, 17)]
    for z in range(19, 22):
        for y in range(3, 7):
            variants['closed'][x, y, z] = material
    # Open four bays to the hall and join each retained pier to its outer
    # buttress. Fill the one-cell front pocket rather than preserving a slot.
    for z in range(9, 30):
        pier = z in (9, 10, 16, 22, 27)
        for y in range(3, 11):
            variants['pillars'][x, y, z] = material if pier else ('air', 0)
            if pier:
                for xx in range(min(x, outside), max(x, outside) + 1):
                    variants['pillars'][xx, y, z] = material
    # Reattach lamps to the retained piers; their old brackets would float.
    for old_z, new_z in zip((11,17,23,29), (10,16,22,27)):
        xx = x + (1 if x == 4 else -1)
        for y in (6,7):
            variants['pillars'][xx,y,new_z] = original[xx,y,old_z]
            variants['pillars'][xx,y,old_z] = ('air',0)
    # Existing benches project into the new arcades; remove their two seats.
    for z in (14, 20):
        variants['pillars'][(x + (2 if x == 4 else -2), 3, z)] = ('air', 0)

edits = {}
for variant, cells in variants.items():
    edits[variant] = [{'pos': list(p), 'before': list(original.get(p, ('air', 0))), 'after': list(v)}
                      for p, v in sorted(cells.items()) if original.get(p, ('air', 0)) != v]
(HERE/'variants.json').write_text(json.dumps(edits, indent=2)+'\n')

# At y=4, show the exact solid-cell plan. This is a geometry slice, not a path
# simulation: it neither proves reachability nor models other moving bodies.
colors = {'current':'#b18b6c','closed':'#bb7474','pillars':'#79ad9b'}
for key, cells in variants.items():
    marks = []
    for z in range(35):
        for x in range(45):
            solid = cells.get((x, 4, z), ('air', 0))[0] != 'air'
            changed = original.get((x,4,z), ('air',0)) != cells.get((x,4,z), ('air',0))
            col = colors[key] if solid else '#182328'
            if changed and not solid: col = '#395952'
            marks.append(f'<rect x="{x*12}" y="{(34-z)*12}" width="11" height="11" fill="{col}"/>')
    marks.append('<text x="270" y="444" fill="#ded7c8" text-anchor="middle" font-size="16">Eingang · Schnitt y=4 · ein Kästchen = ein Block</text>')
    (HERE/(key+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-10 -10 560 466"><rect x="-10" y="-10" width="560" height="466" fill="#0d171c"/>'+''.join(marks)+'</svg>')

tex, meshes, names, indices, packed = V.Textures(), {}, [], {}, {}
for key, cells in variants.items():
    # Identical camera from the hall toward the west service arch. The roof
    # remains present; bright study lighting makes inner geometry legible.
    spec = {'title': key, 'description': 'Actual Highcourt template / unshipped design variant',
            'camera': {'eye':[14,6.2,13], 'target':[3,5,21], 'fov':65},
            'sky':'#a3b7bd', 'fog':[120,200], 'tint':'#ffffff'}
    visible = [(*p,*v) for p,v in sorted(cells.items()) if v[0]!='air']
    packed[key] = V.pack_cells({'spec':spec}, visible, indices, names)
types, report = V.build_types(names, nodes, registry.get('aliases',{}), tex, meshes)
assert not report['skipped'] and not report['missing_mesh'] and not tex.missing, (report,tex.missing)
payload = {'scenes':packed, 'types':types, 'textures':tex.images, 'meshes':meshes, 'body':[]}
page = V.inline_renderer((ROOT/'tools/character_creation_preview/scenes.html.in').read_text())
page = page.replace('__PORTRAIT__', (ROOT/'tools/character_creation_preview/portrait.js').read_text())
page = page.replace("let selected='human'", "let selected='current'").replace("||'human'", "||'current'")
page = page.replace('t.colorSpace = THREE.SRGBColorSpace;', 't.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;', 'renderer.outputEncoding = THREE.sRGBEncoding;')
for token, file in {'__THREE__':'tools/r54_armor/vendor/three.min.js','__ORBIT__':'tools/r69_camp_art/orbit.js','__LICENSE__':'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
    page = page.replace(token,(ROOT/file).read_text().replace('</','<\\/'))
digest = hashlib.sha256(json.dumps({'payload':payload,'page':page,'builder':Path(__file__).read_text()},sort_keys=True).encode()).hexdigest()
for scene in packed.values(): scene['digest'] = digest
page = page.replace('__PAYLOAD__', json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
(HERE/'scenes.html').write_text(page)
print('Castle studies built; edited cells:', {k:len(v) for k,v in edits.items()})

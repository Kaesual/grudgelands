#!/usr/bin/env python3
"""Transfer the reviewed facade study to ordinary town buildings, offline only."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
STUDY = ROOT / 'tools/dwarf_architecture_study'
sys.path.insert(0, str(ROOT / 'tools/building_templates/viewer'))
sys.path.insert(0, str(STUDY))
import build_gallery as G
import build_viewer as V
import templates as T
from cultures import CULTURES
from preview_materials import install
from rules import profile, scope, transfer, roles_of, SHELL, facade_cells


FOCUS = {
    'dawnmere__dawnmere_harvest_inn': 'Lange Fassade: schmale Stützen und verbundene Querbalken',
    'dur_brannoc__dur_brannoc_lane_house': 'Hohe Seitenwand: Mauerwerk bis zum Dach, Holz nur im Giebel',
    'kapok__kapok_elder_stilt': 'Stelzenhaus: dunkler Holzrahmen mit umbrabraunem Lehm',
    'dawnmere__dawnmere_smithy': 'Verwinkelter Bau: dieselbe Rahmenordnung über mehrere Fassaden',
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    reg = json.loads((ROOT / 'tools/building_templates/nodes.json').read_text())
    nodes = reg['nodes']
    palettes = T.Palettes(G.load_palettes('luajit', set(nodes)))
    preview = install(nodes)
    base = ROOT / 'mods/MAPGEN/grug_mapgen/building_templates'
    templates, layouts = G.read_sources(str(base))
    by_name = {t.name: t for t in templates}
    original_study = json.loads(re.search(r'<script id="payload" type="application/json">(.*?)</script>',
                               (STUDY / 'index.html').read_text(), re.S)[1])
    reference = json.loads((STUDY / 'audit.json').read_text())
    accepted = {(s['template'], s['race'], s['layout']): k for k, s in original_study['buildings'].items()}
    names, indices, scenes, buildings, audit, excluded = [], {}, {}, {}, {}, []
    seen = {}
    for layout in layouts:
        for rec in layout.places + layout.uses:
            tpl = by_name[rec['template']]
            binding = G.placement_binding(palettes, layout, rec)
            race = layout.race
            ref = accepted.get((tpl.name, race, Path(layout.path).name))
            placement = dict(layout=str(Path(layout.path).relative_to(ROOT)), line=rec['line'],
                             town=layout.town, race=race, template=tpl.name, count=rec.get('count', 1),
                             id=rec.get('id'), main=rec.get('main'), channels=rec['channels'])
            reason = None if ref else scope(tpl)
            if reason:
                excluded.append(dict(placement, reason=reason)); continue
            before, bad = T.resolved_cells(tpl, T.resolve(tpl, palettes, binding), palettes)
            assert not bad, bad
            fingerprint = (tpl.name, race, json.dumps(binding, sort_keys=True))
            if fingerprint in seen:
                audit[seen[fingerprint]]['placements'].append(placement); continue
            key = layout.town + '__' + tpl.name
            if key in buildings:
                key += '__' + hashlib.sha256(fingerprint[2].encode()).hexdigest()[:6]
            try:
                shape = profile(tpl)
                if ref:
                    after = dict(before)
                    source = reference['buildings'][ref]
                    assert sha(Path(tpl.path)) == source['sha256']
                    for c in source['changes']:
                        p = tuple(c['position'])
                        assert before[p] == tuple(c['before']), (key, p, 'Reference binding changed')
                        after[p] = tuple(c['after'])
                else:
                    after = transfer(tpl, before, nodes, race, shape)
            except ValueError as e:
                excluded.append(dict(placement, reason=str(e), exception=True)); continue
            seen[fingerprint] = key
            roles = roles_of(tpl)
            changes = []
            for p in sorted(before):
                if before[p] == after[p]:
                    continue
                assert roles.get(p) in SHELL | {'foundation'} or roles.get(p, '').startswith('roof_')
                assert before[p][1] == after[p][1]
                assert all(nodes[before[p][0]].get(f) == nodes[after[p][0]].get(f)
                           for f in ('drawtype', 'node_box', 'collision_box', 'walkable', 'buildable_to'))
                changes.append(dict(position=p, role=roles[p], before=before[p], after=after[p]))
            assert before.keys() == after.keys()
            assert changes, key
            flags = [] if ref else shape['flags'][:]
            # Existing literal wall materials do not participate in a palette pass.
            literals = [p for p in before if shape['floor'] < p[1] < shape['eave'] and
                        tpl.legend.get(tpl.cells[p], {}).get('kind') == 'node' and
                        nodes[before[p][0]]['drawtype'] == 'normal']
            if len(literals) > 12 and not ref:
                flags.append('Fest eingebaute Vollblöcke bleiben erhalten; Materialübergänge ansehen.')
            short_name = tpl.name
            for town in sorted({l.town for l in layouts}, key=len, reverse=True):
                if short_name.startswith(town + '_'):
                    short_name = short_name[len(town)+1:]; break
            title = short_name.replace('_', ' ').title()
            if ref:
                title = original_study['buildings'][ref]['title']
            doors = [p for p in tpl.points if p['group'] == 'doors']
            front = int(doors[0].get('face') or 0) if doors else 0
            desc = ('Unverändertes Referenzgebäude aus der gemeinsam ausgearbeiteten Studie.' if ref else
                    'Durchgehende Stützen und ein Block breite Abschlüsse gliedern die Wand; ruhige Füllfelder schließen die Zwischenräume. Die Rahmen folgen den Fassaden und Dachhöhen, nicht den alten Materialflecken.')
            buildings[key] = dict(key=key, race=race, town=layout.town, title=title, label=title,
                template=tpl.name, template_races=tpl.races, pivot=tpl.pivot, size=tpl.size,
                floor=shape['floor'], max_y=tpl.origin[1]+tpl.size[1]-1, inside_cut=shape['floor']+3,
                front=front, gable=(front+1)%4, description=desc, details=(flags + (['Hohe Seitenwände bleiben gemauert; Holz beginnt erst im eigentlichen Giebelfeld.'] if race == 'dwarf' else
                    ['Umbrabrauner Lehm ersetzt die rote Rinde in den Füllfeldern. Stelzen und Plattform bleiben erhalten.'] if race == 'troll' else
                    ['Stützen bleiben durchgehend; Fenster und Türen unterbrechen keine neu gesetzten Stützen.'])),
                attention=bool(flags), reference=ref, review_focus=key in FOCUS, typology=FOCUS.get(key,''), materials=[],
                profile='Wohnhaus' if shape['residential'] else 'Werkstatt / Nutzgebäude')
            if ref:
                buildings[key]['details'] = original_study['buildings'][ref]['details']
            material_names = sorted({after[tuple(c['position'])][0] for c in changes})
            audit[key] = dict(template=str(Path(tpl.path).relative_to(ROOT)), sha256=sha(Path(tpl.path)),
                placements=[placement], race=race, reference=ref, changes=changes, changed_cells=len(changes),
                profile={k: v for k, v in shape.items() if k not in ('roof','corners')},
                roof_cells=sorted(shape['roof']), corners=sorted(shape['corners']), flags=flags,
                facade_classes=[] if ref else [dict(position=p,kind=k) for p,k in sorted(facade_cells(shape,roles).items())],
                geometry_preserved=True, protected_cells_unchanged=True)
            buildings[key]['material_names'] = material_names
            if race == 'orc' and not ref and any(roles[q] != 'roof_ridge' for q in shape['roof']):
                buildings[key]['description'] += ' Das vorhandene rote Ziegeldach bleibt bei dieser geneigten Dachform erhalten.'
            for variant, cells in [('before', before), ('after', after)]:
                visible = [(*p, *v) for p, v in sorted(cells.items()) if nodes[v[0]]['drawtype'] != 'airlike']
                scenes[key+'_'+variant] = V.pack_cells({}, visible, indices, names)
    assert {s['reference'] for s in buildings.values() if s['reference']} == set(reference['buildings'])
    textures, meshes = V.Textures(), {}
    common = Path(subprocess.check_output(['git','rev-parse','--git-common-dir'],cwd=ROOT,text=True).strip())
    engine = (ROOT/common).resolve().parent/'reference_projects/luanti/textures/base/pack'
    textures.bank.index['blank.png'] = str(engine/'blank.png')
    types, report = V.build_types(names, nodes, reg.get('aliases',{}), textures, meshes)
    assert not report['skipped'] and not report['missing_mesh'] and not textures.missing, report
    for s in buildings.values():
        # One swatch per actual cube material; shaped roofs share their texture.
        swatches = {}
        for node in s.pop('material_names'):
            tile = nodes[node]['tiles'][0]
            texture = textures.index(tile)
            label = nodes[node].get('description',node).split('\n')[0]
            swatches.setdefault(texture, dict(label=label,node=node,image=textures.images[texture]))
        s['materials'] = list(swatches.values())
    assert not textures.missing and not textures.bank.warnings
    payload = dict(scenes=scenes, types=types, textures=textures.images, meshes=meshes,
                   buildings=buildings, cultures={k:dict(v, **({'line':'Dunkles Holz, ruhiger Lehm, braunes Schilf.'} if k == 'troll' else {})) for k,v in CULTURES.items()}, exclusions=excluded)
    page = V.inline_renderer((HERE/'page.html.in').read_text())
    page = page.replace('t.colorSpace = THREE.SRGBColorSpace;', 't.encoding = THREE.sRGBEncoding;')
    page = page.replace('renderer.outputColorSpace = THREE.SRGBColorSpace;', 'renderer.outputEncoding = THREE.sRGBEncoding;')
    for token,path in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js',
                       '__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js',
                       '__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
        page=page.replace(token,path.read_text().replace('</','<\\/'))
    page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
    (HERE/'compare.html').write_text(page)
    manifest=dict(classification='compatible, tools-only transfer preview',
        base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        reference_sha256=sha(STUDY/'audit.json'), buildings=audit, excluded=excluded,
        layouts={str(Path(l.path).relative_to(ROOT)):sha(Path(l.path)) for l in layouts},
        shared_inputs={str(p.relative_to(ROOT)):sha(p) for p in [ROOT/'mods/MAPGEN/grug_mapgen/wp13/palette.lua',
            ROOT/'tools/building_templates/nodes.json', ROOT/'tools/building_templates/viewer/renderer.js']},
        preview_only_nodes=preview, page_sha256=sha(HERE/'compare.html'),
        missing_textures=sorted(textures.missing))
    (HERE/'audit.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (HERE/'catalog.json').write_text(json.dumps(buildings,indent=2)+'\n')
    print('Built',len(buildings),'comparisons;',sum(s['attention'] for s in buildings.values()),
          'with inspection notes;',len(excluded),'excluded placement rows.')
    for race in CULTURES:
        print(race, sum(s['race']==race for s in buildings.values()))
    print('Exceptions:',[(x['template'],x['reason']) for x in excluded if x.get('exception')])

if __name__ == '__main__':
    main()

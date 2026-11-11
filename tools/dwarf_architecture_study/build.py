#!/usr/bin/env python3
"""Build a tools-only, actual-node facade study; never write shipped templates."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools/building_templates/viewer'))
import build_gallery as G
import build_viewer as V
import templates as T
from cultures import CULTURES, EXAMPLES, replacement
from preview_materials import install as install_preview_materials

BASE = ROOT / 'mods/MAPGEN/grug_mapgen/building_templates'
STONE = 'default:stone_block'
WALL = 'grug_decor:darkage_stone_brick'
WOOD = 'default:wood'
DARK_WOOD = WOOD  # User iteration 2: one warm timber tone for gable and head course.
ROOF = 'grug_decor:darkage_slate'
SHELL = {'wall', 'wall_accent', 'wall_infill', 'window_frame', 'post', 'beam'}
ROOFS = {'roof_stair': ROOF + '_stair', 'roof_stair_inner': ROOF + '_stair_inner',
         'roof_stair_outer': ROOF + '_stair_outer', 'roof_slab': ROOF + '_slab',
         'roof_ridge': ROOF}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def proposed(tpl, before, kind):
    """Hand-scoped elevations for these two buildings, not a global palette swap."""
    after = dict(before)
    for pos, key in tpl.cells.items():
        entry = tpl.legend.get(key, {})
        role = entry.get('name') if entry.get('kind') == 'role' else None
        x, y, z = pos
        material = None
        if role in ROOFS:
            material = ROOFS[role]
        elif role == 'foundation':
            material = STONE
        elif role in SHELL:
            if y == 1:
                material = STONE  # A continuous plinth, including former timber feet.
            elif kind == 'home':
                if y == 4:
                    material = DARK_WOOD  # Tie course at the head of all window bays.
                elif y >= 5:
                    material = WOOD  # The gable is one calm, warmer timber surface.
                elif (x, z) in {(0, 0), (8, 0), (0, 8), (8, 8)}:
                    material = STONE
                elif role == 'wall':
                    material = WALL  # Masonry around the entrance, below the timber course.
                else:
                    material = WALL
            else:
                corners = {(0, 0), (10, 0), (0, 14), (10, 14),
                           (15, 4), (15, 10), (10, 4), (10, 10)}
                if y == 4:
                    material = STONE  # Masonry lintel course, including the workshop wing.
                elif y >= 5:
                    material = WOOD if y >= 6 else DARK_WOOD
                else:
                    material = STONE if (x, z) in corners else WALL
        if material:
            after[pos] = (material, before[pos][1])
    return after


def main():
    reg = json.loads((ROOT / 'tools/building_templates/nodes.json').read_text())
    palettes = T.Palettes(G.load_palettes('luajit', set(reg['nodes'])))
    previews = install_preview_materials(reg['nodes'])
    previous = json.loads((HERE / 'iterations/iteration5-audit.json').read_text())
    dwarf_materials = [('Sockel & Einfassungen', STONE), ('Mauerwerk', WALL),
                       ('Einheitliches warmes Holz', WOOD), ('Dunkler Schiefer', ROOF)]
    dwarf_specs = [
        dict(key='home', race='dwarf', layout='hearthpine.layout', template='hearthpine_west_home',
             title='Das Wohnhaus', label='Wohnhaus', town='Hearthpine', floor=0, eave=4,
             front=0, gable=1, swatches=dwarf_materials,
             description='Ein ruhiger Steinsockel verbindet die Fassade. Die Fenster sitzen in gemauerten Wandfeldern; Giebel und Abschluss verwenden jetzt denselben warmen Holzton. Dunkler Schiefer ersetzt das hellblaue Dach.',
             details=['Der Sockel läuft auch unter den bisherigen Holzpfosten weiter.',
                      'Auch die Holzfelder um die Eingangstür werden zu Mauerwerk; die Tür bleibt erhalten.',
                      'Ein durchgehendes Holzband verbindet die Fensterfelder auf gleicher Höhe.',
                      'Dunkler Schiefer und ein einheitlicher Holzton ergeben einen ruhigeren Kontrast.']),
        dict(key='forge', race='dwarf', layout='hearthpine.layout', template='hearthpine_forge_hall',
             title='Die Schmiede', label='Schmiede', town='Hearthpine', floor=0, eave=5,
             front=2, gable=0, swatches=dwarf_materials,
             description='Die Werkstatt bekommt einen massiven, gemauerten Unterbau. Ein gemeinsamer Sturzabschluss ordnet die Fenster; Holz bleibt im oberen Dachbereich. Hauptbau und Anbau sprechen dieselbe Materialsprache.',
             details=['Stein ersetzt die verstreuten Baumstämme und hellen Wandstreifen.',
                      'Ecksteine, Sockel und Sturzlage gehören sichtbar zusammen.',
                      'Der Dachabschluss trennt Mauerwerk und hölzerne Giebelfelder.',
                      'Dunkler Schiefer ersetzt die hellblaue Deckung; Giebel und Holzabschluss haben denselben Farbton.'])]
    specs = dwarf_specs + EXAMPLES
    names, indices, scenes, audit, layouts, buildings, iteration_changes = [], {}, {}, {}, {}, {}, {}
    for spec in specs:
        kind, name = spec['key'], spec['template']
        layout_path = BASE / 'layouts' / spec['layout']
        layout = T.parse_layout(str(layout_path))
        layouts[str(layout_path.relative_to(ROOT))] = digest(layout_path)
        path = BASE / 'templates' / (name + '.tpl')
        tpl = T.parse_template(str(path))
        rec = next(r for r in layout.places + layout.uses if r['template'] == name)
        binding = G.placement_binding(palettes, layout, rec)
        before, bad = T.resolved_cells(tpl, T.resolve(tpl, palettes, binding), palettes)
        assert not bad, bad
        if spec['race'] == 'dwarf':
            after = proposed(tpl, before, kind)
        else:
            after = dict(before)
            for pos, key in tpl.cells.items():
                entry = tpl.legend.get(key, {})
                if entry.get('kind') != 'role':
                    continue
                material = replacement(spec, tpl, pos, entry['name'])
                if material:
                    after[pos] = (material, before[pos][1])
        # User feedback constrains this iteration, including the approved elf scenes.
        old = previous['buildings'][kind]
        assert old['sha256'] == digest(path), 'Study source changed between iterations'
        prior = dict(before)
        for c in old['changes']:
            prior[tuple(c['position'])] = tuple(c['after'])
        delta = [{'position': p, 'previous': prior[p], 'current': after[p],
                  'role': tpl.legend.get(tpl.cells[p], {}).get('name')}
                 for p in sorted(before) if prior[p] != after[p]]
        if kind == 'orc_home':
            expected = ({(x, y, 2) for x in (0, 8) for y in (2, 3, 4)} |
                        {(2, y, 8) for y in (2, 3, 4)})
            assert {c['position'] for c in delta} == expected
            assert all(c['previous'][0] == 'grug_decor:darkage_ors_block' and
                       c['current'][0] == 'grug_decor:darkage_adobe' for c in delta)
        else:
            assert not delta, 'Approved proposal changed: ' + kind
        if kind in ('human_home', 'human_hall', 'undead_home', 'undead_hall', 'elf_hall'):
            assert all(after[p] == before[p] for p, k in tpl.cells.items()
                       if tpl.legend.get(k, {}).get('name') in ROOFS), 'Original roof not restored exactly'
        iteration_changes[kind] = delta
        buildings[kind] = {k: v for k, v in spec.items() if k != 'swatches'}
        buildings[kind].update(pivot=tpl.pivot, size=tpl.size,
                              max_y=tpl.origin[1] + tpl.size[1] - 1,
                              inside_cut=spec['floor'] + 3,
                              template_races=tpl.races)
        changes = [{'position': p, 'entry': tpl.legend[tpl.cells[p]]['text'],
                    'before': before[p], 'after': after[p]}
                   for p in sorted(before) if before[p] != after[p]]
        assert changes, 'No proposal changes produced'
        assert before.keys() == after.keys(), 'Footprint or air cells changed'
        for p in before:
            entry = tpl.legend.get(tpl.cells[p], {})
            if entry.get('kind') != 'role' or entry.get('name') not in SHELL | set(ROOFS) | {'foundation'}:
                assert before[p] == after[p], ('Protected non-shell cell changed', p)
        for change in changes:
            old, new = change['before'], change['after']
            assert old[1] == new[1], 'Orientation changed'
            a, b = reg['nodes'][old[0]], reg['nodes'][new[0]]
            assert a['drawtype'] == b['drawtype'], (old, new)
            assert a.get('node_box') == b.get('node_box'), (old, new)
            assert a.get('collision_box') == b.get('collision_box'), (old, new)
        audit[kind] = {'template': str(path.relative_to(ROOT)),
                       'sha256': digest(path), 'changed_cells': len(changes),
                       'race': spec['race'], 'layout': str(layout_path.relative_to(ROOT)),
                       'template_races': tpl.races,
                       'changes': changes, 'geometry_preserved': True,
                       'doors_windows_furniture_unchanged': True}
        for variant, cells in [('before', before), ('after', after)]:
            visible = [(*p, *v) for p, v in sorted(cells.items())
                       if reg['nodes'][v[0]]['drawtype'] != 'airlike']
            scenes[kind + '_' + variant] = V.pack_cells({}, visible, indices, names)

    assert len(buildings) == 12 and all(sum(s['race'] == race for s in specs) == 2 for race in CULTURES)
    textures, meshes = V.Textures(), {}
    # Engine-owned transparent tile: references are shared from the main checkout
    # when this study is built in a worktree without initialized submodules.
    common = Path(subprocess.check_output(['git', 'rev-parse', '--git-common-dir'],
                                         cwd=ROOT, text=True).strip())
    common = (ROOT / common).resolve()
    engine_pack = common.parent / 'reference_projects/luanti/textures/base/pack'
    assert (engine_pack / 'blank.png').is_file(), 'Initialize the Luanti reference checkout first'
    textures.bank.index['blank.png'] = str(engine_pack / 'blank.png')
    types, report = V.build_types(names, reg['nodes'], reg.get('aliases', {}), textures, meshes)
    assert not report['skipped'] and not report['missing_mesh'] and not textures.missing, (report, textures.missing)
    assert not textures.bank.warnings, textures.bank.warnings
    for spec in specs:
        materials = []
        for label, node in spec['swatches']:
            texture = textures.index(reg['nodes'][node]['tiles'][0])
            materials.append({'label': label, 'node': node, 'image': textures.images[texture]})
        buildings[spec['key']]['materials'] = materials
    assert not textures.bank.warnings and not textures.missing
    payload = {'scenes': scenes, 'types': types, 'textures': textures.images,
               'meshes': meshes, 'buildings': buildings, 'cultures': CULTURES,
               'counts': {k: v['changed_cells'] for k, v in audit.items()}}
    page = V.inline_renderer((HERE / 'page.html.in').read_text())
    # Match the existing offline study bundle's vendored Three.js API.
    page = page.replace('t.colorSpace = THREE.SRGBColorSpace;', 't.encoding = THREE.sRGBEncoding;')
    page = page.replace('renderer.outputColorSpace = THREE.SRGBColorSpace;',
                        'renderer.outputEncoding = THREE.sRGBEncoding;')
    for token, path in {'__THREE__': ROOT / 'tools/r54_armor/vendor/three.min.js',
                        '__ORBIT__': ROOT / 'tools/r69_camp_art/orbit.js',
                        '__LICENSE__': ROOT / 'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
        page = page.replace(token, path.read_text().replace('</', '<\\/'))
    page = page.replace('__PAYLOAD__', json.dumps(payload, separators=(',', ':')).replace('</', '<\\/'))
    (HERE / 'index.html').write_text(page)
    evidence = {'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'classification': 'compatible, tools-only proposal',
                'layouts': layouts, 'buildings': audit,
                'iteration': 6, 'approved_elf_home_unchanged': True,
                'approved_troll_proposals_unchanged': True,
                'feedback_constraints_passed': True, 'iteration_changes': iteration_changes,
                'previous_iteration_sha256': digest(HERE / 'iterations/iteration5-audit.json'),
                'preview_only_nodes': previews,
                'shared_inputs': {str(p.relative_to(ROOT)): digest(p) for p in [
                    ROOT / 'mods/MAPGEN/grug_mapgen/wp13/palette.lua',
                    ROOT / 'tools/building_templates/nodes.json',
                    ROOT / 'tools/building_templates/viewer/renderer.js',
                    ROOT / 'tools/r69_camp_art/orbit.js']},
                'media_report': {k: sorted(v) if isinstance(v, set) else v for k, v in report.items()},
                'missing_textures': sorted(textures.missing),
                'page_sha256': digest(HERE / 'index.html')}
    (HERE / 'audit.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print('Built 24 scenes:', {k: v['changed_cells'] for k, v in audit.items()},
          '; no geometry changes or missing assets')


if __name__ == '__main__':
    main()

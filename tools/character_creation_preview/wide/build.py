#!/usr/bin/env python3
"""Build wide-only layers and paired game-camera scenes, never game files."""
import copy
import base64
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import sys
import struct

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent
ROOT = SOURCE.parents[1]
WORK = HERE / '.build'
RACES = ('dwarf', 'elf', 'human', 'orc', 'troll', 'undead')
sys.path.insert(0, str(SOURCE))
import scenery
import native


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True) + '\n')


def project(point, camera, aspect):
    """Luanti frame; same perspective as the viewer's reflected-Z camera."""
    eye, target = camera['eye'], camera['target']
    forward = [b-a for a, b in zip(eye, target)]
    length = math.sqrt(sum(v*v for v in forward))
    forward = [v/length for v in forward]
    right = [forward[2], 0, -forward[0]]
    length = math.hypot(right[0], right[2])
    right = [v/length for v in right]
    up = [forward[1]*right[2]-forward[2]*right[1],
          forward[2]*right[0]-forward[0]*right[2],
          forward[0]*right[1]-forward[1]*right[0]]
    delta = [p-e for p, e in zip(point, eye)]
    depth = sum(d*f for d, f in zip(delta, forward))
    tangent = math.tan(math.radians(camera['fov']/2))
    return (.5 + sum(d*r for d, r in zip(delta, right))/(2*depth*tangent*aspect),
            .5 - sum(d*u for d, u in zip(delta, up))/(2*depth*tangent), depth)


def outside_game_box(low, high, camera):
    # All eight corners must be beyond the SAME horizontal frustum plane,
    # with a margin. Accept whole columns/trees, never clipped tree shapes.
    corners = [project(p, camera, 1.1) for p in
               itertools.product(*zip(low, high))]
    return (all(p[2] < -.1 for p in corners) or
            (all(p[2] > .1 for p in corners) and
             (max(p[0] for p in corners) < -.02 or min(p[0] for p in corners) > 1.02)))


def ground_height(x, z):
    # The unchanged base height formula, continued laterally at its edge.
    edge = max(-42, min(42, x))
    rim = max(0, abs(edge)-23)*.28 + max(0, z-45)*.24
    return max(0, math.floor(rim*(1+.22*math.sin(edge*.17+z*.13))))


def variants(spec, cells):
    race = spec['race']
    layer = json.loads((SOURCE / 'scenes/wide' / (race+'.json')).read_text())
    game = json.loads((SOURCE / 'architecture-refresh/native/scenes' / (race+'.json')).read_text())
    unchanged = copy.deepcopy(game)
    unchanged['camera'] = spec['camera']
    assert unchanged == spec, (race, 'base recipe differs from installed refresh')
    extended = cells.copy()
    terrain = layer['terrain']
    for x in range(terrain['x_min'], terrain['x_max']+1):
        if -42 <= x <= 42:
            continue
        for z in range(terrain['z_min'], terrain['z_max']+1):
            # Continue each existing edge height laterally, without a new ridge.
            h = ground_height(x, z)
            if not outside_game_box((x-.5, -2.5, z-.5), (x+.5, h+.5, z+.5), game['camera']):
                continue
            for y in range(-2, h+1):
                name = spec['soil'] if y < h else spec['ground']
                if y == h and race == 'dwarf' and h > 3:
                    name = 'default:stone'
                assert (x, y, z) not in cells
                extended[x, y, z] = (name, 0)
    terrain_cells = len(extended)-len(cells)
    tree_proofs = []
    species = {tree['species'] for tree in spec['trees']}
    for tree in layer['trees']:
        assert tree['species'] in species, (race, 'foreign tree species', tree)
        x, offset, z = tree['at']
        assert offset == 0, (race, 'tree must stand on the ground', tree)
        y = ground_height(x, z)+1
        assert extended.get((x, y-1, z), (None,))[0] in (spec['ground'], 'default:stone'), (race, 'tree support', tree)
        stamp = tree_shapes[f"{tree['species']}:{tree['seed']}"]
        # Authored hillside seeds have no flat-ground roots or buried trunk
        # layer; keep the generator's complete shape and all existing cells.
        assert all(not root and dy >= 0 for dx, dy, dz, name, p2, root in stamp), (race, 'hillside seed', tree)
        placed = {(x+dx, y+dy, z+dz): (name, p2) for dx, dy, dz, name, p2, root in stamp}
        low = [min(p[i] for p in placed)-.5 for i in range(3)]
        high = [max(p[i] for p in placed)+.5 for i in range(3)]
        assert outside_game_box(low, high, game['camera']), (race, 'tree enters game frustum', tree)
        overlap = placed.keys() & extended.keys()
        assert not overlap, (race, 'tree collision', tree, sorted(overlap)[:5])
        extended.update(placed)
        tree_proofs.append({'species': tree['species'], 'seed': tree['seed'],
                            'base': [x, y, z], 'cells': len(placed), 'bounds': [low, high]})
    assert all(extended[pos] == node for pos, node in cells.items())
    proofs[race] = {'base_cells': len(cells), 'added_cells': len(extended)-len(cells),
                    'added_terrain_cells': terrain_cells, 'trees': tree_proofs,
                    'changed_base_cells': 0, 'added_columns_inside_game_frustum': 0,
                    'added_trees_inside_game_frustum': 0,
                    'frustum_margin_fraction': .02, 'layer': layer}
    wide = copy.deepcopy(spec)
    wide['wide_layer'] = layer
    return {race: (spec, cells), race+'-wide': (wide, extended)}


def source_files(payload):
    files = set(HERE.glob('*.py')) | set(HERE.glob('*.mjs'))
    files.update(SOURCE / name for name in ('scenery.py', 'native.py', 'render-scenes.mjs',
                 'scenes.html.in', 'portrait.js', 'export-trees.lua'))
    files.update((SOURCE / 'scenes').glob('*.json'))
    files.update((SOURCE / 'scenes/wide').glob('*.json'))
    files.update((SOURCE / 'architecture-refresh/native/scenes').glob('*.json'))
    viewer = ROOT / 'tools/building_templates/viewer'
    files.update(viewer / name for name in ('renderer.js', 'build_viewer.py', 'build_gallery.py',
                                           'templates.py', 'palettes.lua'))
    files.update(ROOT / name for name in ('tools/building_templates/nodes.json',
                 'tools/wp13/render_blueprint.py', 'tools/wp13/node_tiles.json',
                 'tools/r54_armor/vendor/three.min.js', 'tools/r69_camp_art/orbit.js',
                 'tools/r69_camp_art/THREE-LICENSE.txt', 'tools/r54_armor/data/catalog.json',
                 'tools/r33_c3/gen_cloak_model.py', 'mods/PLAYER/grug_visuals/compose.lua',
                 'mods/ENTITIES/grug_mobs/textures/grug_mobs_blank.png',
                 'mods/MAPGEN/grug_mapgen/wp40/treegen.lua',
                 'mods/MAPGEN/grug_mapgen/wp40/tree_templates.lua'))
    files.add(native.mesh.SOURCE)
    files.update((ROOT / 'mods/MAPGEN/grug_mapgen/wp13').glob('*.lua'))
    bank = scenery.V.Textures().bank
    files.add(Path(scenery.V.render_blueprint.DEFAULT_TILES))
    registry = json.loads((ROOT / 'tools/building_templates/nodes.json').read_text())['nodes']
    for node in payload['types']:
        definition = registry[node['name']]
        for name in set(re.findall(r'[a-zA-Z0-9_.-]+\.png', json.dumps(definition))):
            if name != 'blank.png':
                path = bank.find_file(name)
                assert path, name
                files.add(Path(path))
        if definition.get('mesh'):
            files.add(Path(scenery.V.find_model(definition['mesh'])))
    for race in RACES:
        spec = json.loads((SOURCE / 'scenes' / (race+'.json')).read_text())
        for place in spec['buildings']:
            templates = ROOT / 'mods/MAPGEN/grug_mapgen/building_templates'
            files.add(templates / 'templates' / (place['template']+'.tpl'))
            files.add(templates / 'layouts' / (place['template'].split('_')[0]+'.layout'))
    return sorted(files)


def main():
    tree_shapes.update(scenery.load_trees([
        json.loads((SOURCE/'scenes/wide'/(race+'.json')).read_text()) for race in RACES]))
    scenery.main(WORK/'combined', variants=variants, extra_sources=[Path(__file__)])
    native.build(source=WORK/'combined', output=WORK/'native', write_camera=False)
    page = (WORK/'native/scenes.html').read_text()
    pattern = r'(<script id="payload" type="application/json">)(.*?)(</script>)'
    payload = json.loads(re.search(pattern, page, re.S)[2])
    archived_page = (SOURCE/'architecture-refresh/native/scenes.html').read_text()
    archived = json.loads(re.search(pattern, archived_page, re.S)[2])
    def decoded(data, race):
        return [(x, y, z, data['types'][kind]['name'], p2) for x, y, z, kind, p2 in
                struct.iter_unpack('<hhhHB', base64.b64decode(data['scenes'][race]['cells']))]
    for race in RACES:
        assert decoded(payload, race) == decoded(archived, race), (race, 'base geometry changed')
        proofs[race]['base_geometry_matches_installed_refresh'] = True
        # Material ids follow the first encountered texture bucket. Keep base
        # cells first so off-camera trees cannot reorder coplanar base faces
        # (notably jungle branches). No renderer or lighting setting changes.
        original = base64.b64decode(payload['scenes'][race]['cells'])
        positions = {row[:3] for row in struct.iter_unpack('<hhhHB', original)}
        wide = payload['scenes'][race+'-wide']
        additions = b''.join(struct.pack('<hhhHB', *row) for row in
                            struct.iter_unpack('<hhhHB', base64.b64decode(wide['cells']))
                            if row[:3] not in positions)
        wide['cells'] = base64.b64encode(original+additions).decode('ascii')
        wide['digest'] = scenery.digest({'source': wide['digest'], 'cells': wide['cells']})
        proofs[race]['base_cells_first'] = True
    for mode in ('wide', 'base', 'layered'):
        data = copy.deepcopy(payload)
        data['scenes'] = {}
        for race in RACES:
            key = race if mode == 'base' else race+'-wide'
            scene = copy.deepcopy(payload['scenes'][key])
            expected = json.loads((SOURCE/'architecture-refresh/native/scenes'/(race+'.json')).read_text())['camera']
            assert scene['spec']['camera'] == expected, (race, 'native camera changed')
            if mode == 'wide':
                scene['spec']['camera'] = proofs[race]['layer']['camera']
            scene['digest'] = scenery.digest({'source': scene['digest'], 'spec': scene['spec']})
            data['scenes'][race] = scene
        encoded = json.dumps(data, separators=(',', ':')).replace('</', '<\\/')
        destination = HERE if mode == 'wide' else HERE/'proof'/mode
        destination.mkdir(parents=True, exist_ok=True)
        # Large intermediate HTML is disposable; PNGs and receipts are retained.
        (destination/'scenes.html').write_text(re.sub(pattern, lambda m: m[1]+encoded+m[3], page, flags=re.S))
        write_json(destination/'scene-build.json', {r: {'render_input': s['digest'], 'camera': s['spec']['camera']}
                                                  for r, s in data['scenes'].items()})
    sources = {str(p.relative_to(ROOT)): sha(p) for p in source_files(payload)}
    protected = sorted((ROOT/'mods/PLAYER/grug_classes/textures').glob('grug_creation_*.png'))
    write_json(HERE/'build.json', {'sources': sources, 'source_digest': scenery.digest(sources),
               'protected_game_images': {str(p.relative_to(ROOT)): sha(p) for p in protected},
               'geometry': proofs})
    print('Wide and paired game cameras prepared; all base cells retained.')


proofs = {}
tree_shapes = {}
if __name__ == '__main__':
    main()

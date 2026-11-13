"""Offline facade transfer. No game palette or template is mutated.

Roles identify editable fabric, never the new frame pattern. Exterior wall runs
define continuous piers and roof-level ties. The twelve
reviewed examples are supplied separately as exact reference deltas.
"""
from collections import Counter
import re

SHELL = {'wall', 'wall_accent', 'wall_infill', 'window_frame', 'post', 'beam'}
ENVELOPE = SHELL | {'window', 'door', 'door_hidden', 'chimney'}
EXCLUDE = re.compile(r'kings_hall|warlord_hall|mausoleum|gate|watch|tower|tollhouse|shrine|chapel|'
                     r'ancestor|star_hall|skull_hall|vigil_hall|spirit_hall|moot|'
                     r'barracks|muster|drill|quartermaster|serjeant|guard_house|captain|'
                     r'miners_guild|ossuary|ruin|fallen|charnel')
RESIDENTIAL = re.compile(r'home|house|cottage|lodge|stilt|tenement')
TRADE = re.compile(r'guild|counting|shroud|herb|bake|chapter')
PALE = 'default:silver_sandstone_block'
BASALT = 'grug_decor:darkage_basalt_block'
WOOD = 'default:wood'
DARK = 'grug_trees:gravewood_wood'
JUNGLE = 'default:junglewood'
RED = 'default:desert_stonebrick'
ORS = 'grug_decor:darkage_ors_block'
ADOBE = 'grug_decor:darkage_adobe'
LOAM = 'grug_decor:cottages_loam'
MOSS = 'default:mossycobble'
STONE = 'default:stone_block'
WALL = 'grug_decor:darkage_stone_brick'
DUNGEON = 'grug_decor:castle_dungeon_stone'


def roles_of(tpl):
    return {p: e['name'] for p, k in tpl.cells.items()
            if (e := tpl.legend.get(k, {})).get('kind') == 'role'}


def scope(tpl):
    if EXCLUDE.search(tpl.name):
        return 'Sonderbau / Tor / Wehrbau – zurückgestellt'
    roles = set(roles_of(tpl).values())
    if not ({'floor', 'door'} <= roles and any(r.startswith('roof_') for r in roles)):
        return 'Freianlage, offener Unterstand oder Bau ohne normales Dach'
    return None


def profile(tpl):
    roles = roles_of(tpl)
    floors = Counter(p[1] for p, r in roles.items() if r == 'floor')
    floor = min(floors)  # Upper galleries can be larger than the ground floor.
    # Connected roof groups separate true roof surfaces from bed canopies,
    # little indoor shelves and entrance steps reusing the same palette roles.
    pending = {p for p, r in roles.items() if r.startswith('roof_') and p[1] >= floor + 3}
    groups = []
    while pending:
        seed = min(pending); pending.remove(seed); component = {seed}; queue = [seed]
        while queue:
            x, y, z = queue.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        q = (x + dx, y + dy, z + dz)
                        if q in pending:
                            pending.remove(q); component.add(q); queue.append(q)
        if len(component) >= 8:
            groups.append(component)
    if not groups:
        raise ValueError('Kein zusammenhängendes Hauptdach erkannt')
    groups.sort(key=lambda g: (-len(g), min(g)))
    roof = set().union(*groups)
    eave = min(p[1] for p in groups[0])
    footprint = {(x, z) for (x, y, z), r in roles.items()
                 if r in ENVELOPE and y == floor + 1}
    # Fill exterior air in this horizontal slice. A thick wall's inner cells
    # must not become extra corner piers merely because they have two neighbours.
    xmin, xmax = min(x for x, z in footprint)-1, max(x for x, z in footprint)+1
    zmin, zmax = min(z for x, z in footprint)-1, max(z for x, z in footprint)+1
    exterior = {(xmin,zmin)}; queue = [(xmin,zmin)]
    while queue:
        x,z = queue.pop()
        for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
            q = (x+dx,z+dz)
            if xmin <= q[0] <= xmax and zmin <= q[1] <= zmax and q not in footprint and q not in exterior:
                exterior.add(q); queue.append(q)
    corners = {(x,z) for x,z in footprint
               if any((x+dx,z) in exterior for dx in (-1,1)) and
                  any((x,z+dz) in exterior for dz in (-1,1))}
    # A facade is a straight, outward-facing run, including protected openings
    # and chimneys. Existing window-frame/post labels do not define its pattern.
    faces = []
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        lines = {}
        for x, z in footprint:
            if (x+dx, z+dz) in exterior:
                fixed, along = (x, z) if dx else (z, x)
                lines.setdefault(fixed, []).append(along)
        for fixed, positions in sorted(lines.items()):
            runs = []
            for v in sorted(positions):
                if not runs or v != runs[-1][-1]+1:
                    runs.append([])
                runs[-1].append(v)
            for run in runs:
                if len(run) < 3:
                    continue
                columns = [(fixed, v) if dx else (v, fixed) for v in run]
                tops = [max(y for (xx,y,zz), r in roles.items()
                            if (xx,zz)==q and r in ENVELOPE and r != 'chimney')
                        if any((xx,zz)==q and r in ENVELOPE and r != 'chimney'
                               for (xx,y,zz), r in roles.items()) else floor+1
                        for q in columns]
                # Chimneys must not pull a roofline down or introduce a fake corner.
                for i, q in enumerate(columns):
                    if roles.get((q[0],floor+1,q[1])) == 'chimney':
                        tops[i] = tops[i-1] if i else tops[i+1]
                cap = max(tops[0], tops[-1])
                # The endpoints of a gable may have different eave heights.
                # Only the triangular part above the higher endpoint is timber.
                candidates = [i for i,q in enumerate(columns) if all(
                    roles.get((q[0],y,q[1])) in SHELL
                    for y in range(floor+1, min(cap,tops[i])+1))]
                # Equal bays where openings allow them; a window/door is never
                # overwritten to force a post. Min. 2 infill cells between posts.
                selected = [0]
                last = len(columns)-1
                while last-selected[-1] > 6:
                    options = [i for i in candidates if 3 <= i-selected[-1] <= 6 and last-i >= 3]
                    if not options:
                        break
                    target = selected[-1] + (last-selected[-1]) / round((last-selected[-1])/4)
                    selected.append(min(options, key=lambda i:(abs(i-target),i)))
                selected.append(last)
                # Corners interrupted by an opening remain that opening; do not
                # manufacture a dangling frame segment above it.
                selected = [i for i in selected if i in candidates]
                faces.append(dict(columns=columns, tops=tops, cap=cap,
                                  posts=[columns[i] for i in selected], normal=[dx,dz]))
    residential = bool(RESIDENTIAL.search(tpl.name) and not TRADE.search(tpl.name))
    flags = []
    if floor > 0:
        flags.append('Erhöhter Wohnboden: Stelzen und Treppe bleiben erhalten.')
    if len(groups) > 1:
        flags.append('Mehrere getrennte Dachflächen: Anbau und Hauptbau gemeinsam prüfen.')
    if len(floors) > 1:
        flags.append('Mehrere Bodenhöhen: Übergänge und obere Wandfelder ansehen.')
    if eave - floor > 6:
        flags.append('Hohe Wandflächen: Wirkung der langen Stützen ansehen.')
    return dict(floor=floor, eave=eave, roof=roof, corners=corners, faces=faces,
                belt=min(f['cap'] for f in faces), residential=residential, flags=flags)


def facade_cells(shape, roles):
    """Classify entire facade columns before selecting any culture material."""
    result = {}
    for face in shape['faces']:
        posts = set(face['posts'])
        for (x,z), top in zip(face['columns'], face['tops']):
            for y in range(shape['floor']+1, top+1):
                p = (x,y,z)
                if roles.get(p) not in SHELL:
                    continue
                kind = ('pier' if (x,z) in posts else 'tie' if y == face['cap'] else
                        'gable' if y > face['cap'] else 'infill')
                # A shared corner pier wins over the neighbouring wall's tie.
                if result.get(p) != 'pier':
                    result[p] = kind
    return result


def shaped(material, role):
    if role == 'roof_ridge':
        return 'grug_decor:cottages_reet' if material == 'study:reed' else material
    shape = role.removeprefix('roof_')
    return ('stairs:' + shape + '_' + material.split(':')[1]
            if material.startswith('default:') else material + '_' + shape)


def transfer(tpl, before, nodes, race, shape):
    roles = roles_of(tpl)
    floor, eave = shape['floor'], shape['eave']
    facade = facade_cells(shape, roles)
    home = shape['residential']
    base = {'human': 'default:brick' if home else STONE, 'dwarf': STONE,
            'elf': PALE, 'orc': RED, 'troll': JUNGLE if floor else 'grug_decor:darkage_basalt_brick',
            'undead': MOSS}[race]
    after = dict(before)
    for p, (old, param2) in sorted(before.items()):
        x, y, z = p; role = roles.get(p); material = None
        if p in shape['roof']:
            # Both approved human roofs and both approved elf roofs retain
            # their existing family; preserve each placement's roof binding.
            if race not in ('human', 'elf') and not (race == 'orc' and any(
                    roles[q] != 'roof_ridge' for q in shape['roof'])):
                family = {'dwarf': 'grug_decor:darkage_slate', 'orc': 'default:desert_sandstone',
                          'troll': 'study:reed', 'undead': 'default:obsidianbrick'}[race]
                if race == 'orc' and role == 'roof_ridge' and any(
                    (x + dx, y, z + dz) not in shape['roof']
                    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    family = RED
                material = shaped(family, role)
        elif role == 'foundation':
            material = base
        elif role in SHELL and y > floor and nodes[old]['drawtype'] == 'normal':
            kind = facade.get(p)
            if kind is None:
                # Upper open roof lanterns retain their explicit posts/beams;
                # interior fabric and unrelated freestanding supports stay put.
                if y > eave and role in ('post', 'beam'):
                    material = {'human': DARK, 'troll': JUNGLE, 'dwarf': WOOD,
                                'elf': 'grug_decor:darkage_marble', 'orc': ORS,
                                'undead': BASALT}[race]
            elif y == floor + 1:
                material = base
            elif race == 'human':
                material = DARK if kind in ('pier', 'tie') or y == shape['belt'] else LOAM
            elif race == 'dwarf':
                material = WOOD if kind == 'gable' else STONE if kind in ('pier', 'tie') else WALL
            elif race == 'elf':
                material = ('grug_decor:darkage_serpentine' if y == shape['belt'] else
                            'grug_decor:darkage_marble' if kind in ('pier', 'tie') else 'grug_trees:silverwood_wood')
            elif race == 'orc':
                material = RED if kind == 'tie' else ORS if kind == 'pier' else ADOBE
            elif race == 'troll':
                material = JUNGLE if kind in ('pier', 'tie') or y == shape['belt'] else 'grug_nodes:clay_band_umber'
            elif race == 'undead':
                material = BASALT if kind in ('pier', 'tie') else DARK if home and kind == 'gable' else DUNGEON
        if material:
            new = nodes[material]
            old_def = nodes[old]
            # Empty conditional infill, steps and unusual boxes are preserved.
            # The caller reports any unsupported shape instead of changing it.
            if any(old_def.get(k) != new.get(k) for k in ('drawtype', 'node_box', 'collision_box')):
                raise ValueError('Materialform passt nicht: ' + old + ' -> ' + material)
            after[p] = (material, param2)
    return after

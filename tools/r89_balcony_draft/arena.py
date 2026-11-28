"""Read the shipped field's column data and place both stamps as breach_model does."""
import re

from halls import BARRIER, BASALT, LAMP, ROOT, WAYSTONE, place

VIEWS = {
    'field': ('From the field', (53, 15, 33), (12, 7, 3), 40),
    'road': ('From the road', (42, -4.03, 24), (16, 6.8, 6), 55),
    'foot': ('Foot of the stair', (7.2, 1.97, 0.5), (3, 2.6, 8), 67),
    'turn': ('On the stair', (3.3, 5.97, 13), (12, 8.6, 13), 70),
    'gallery': ('Inside the gallery', (13.6, 9.97, 13.2), (20, 9.8, 9), 70),
    'balcony': ('At the parapet', (18.54, 9.97, 8.5), (44, -4.3, 4), 73),
    'rail': ('Standing on the rail', (19, 10.97, 9), (42, -3.7, 5), 72),
    'flank': ('Along the road', (18.54, 9.97, 11.4), (42, -4.5, 32), 64),
    'roof': ('From the hall roof', (10, 9.97, 0), (12, 10, 9), 67),
    'cut': ('Roofs lifted', (-8, 42, 23), (10, 4, 2), 46),
}


def poses(faction):
    return {key: (place(faction, *eye), place(faction, *target), fov)
            for key, (_, eye, target, fov) in VIEWS.items()}


def field():
    source = (ROOT / 'mods/MAPGEN/grug_mapgen/wp40/breach_field.lua').read_text()
    codes = re.search(r'chars = "([^"]+)"', source)[1]
    table = source.split('entries = {\n')[1].split('columns = [[')[0]
    lookup = dict(zip(codes, re.findall(r'\{"([^"]+)", (\d+)\}', table)))
    columns = source.split('columns = [[\n')[1].split(']]')[0]
    cells, rotations = {}, {}
    for line in columns.splitlines():
        x, z, stack = line.split()
        x, z = int(x), int(z)
        woodland = x < 0
        roles = {'@accent': 'grug_nodes:dirt_with_forest_litter' if woodland else 'grug_nodes:mesa_clay',
                 '@base': 'default:dirt' if woodland else 'default:dry_dirt',
                 '@path': 'default:dirt' if woodland else 'default:dry_dirt'}
        for y, code in enumerate(stack):
            if code == '-':
                continue
            node, p2 = ('@accent', 0) if code == '=' else lookup[code]
            cells[x, y, z] = roles.get(node, node)
            if int(p2):
                rotations[x, y, z] = int(p2)
    groups = re.findall(
            r'\{x = (-?\d+), z = (-?\d+),\s+trunk = \{(.*?)\},\s+rock = \{([^\n]*)\}\},', source)
    assert len(groups) == 4
    for x, z, trunks, rocks in groups:
        x, z = int(x), int(z)
        for dx, y, dz in re.findall(r'\{(-?\d+), (\d+), (-?\d+)\}', trunks if x < 0 else rocks):
            cells[x + int(dx), int(y), z + int(dz)] = 'default:tree' if x < 0 else 'grug_materials:basalt'
    assert len({(x, z) for x, _, z in cells}) == 6907
    return cells, rotations


def placed(faction, cells):
    solids = {place(faction, *p): n for p, n in cells.items() if n != BARRIER}
    for y, expected in ((1, BASALT), (2, LAMP), (3, BASALT)):
        assert solids.pop(place(faction, 4, y, 0)) == expected
    solids[place(faction, 4, 1, 0)] = WAYSTONE
    return solids

"""Drafts in the hall frame of Round 84. u runs toward the road, y starts at the hall floor."""
from collections import Counter
from pathlib import Path
import sys
import string

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools/building_templates/viewer'))
import templates

FACTIONS = ('accord', 'throng')
BASELINE = HERE / 'baseline'
BRICK = 'default:stonebrick'
STONE = 'default:stone_block'
PALE = 'default:silver_sandstone_block'
SLATE = 'grug_decor:darkage_slate_tile'
BASALT = 'grug_decor:darkage_basalt_brick'
LOG = 'default:pine_tree'
PLANK = 'default:acacia_wood'
OAK = 'default:wood'
GOLD = 'grug_materials:bronze_block'
LAMP = 'grug_materials:emberglass_lamp'
RAIL = 'grug_decor:capital_rail'
BARRIER = 'grug_mapgen:arena_barrier'
BARRIER_BOX = ((20, 8, 6), (20, 12, 14))
WAYSTONE = 'grug_mapgen:waystone'

# Inclusive node centres, in u/y/v. The lower flight is already inside the room.
BOXES = {
    'Hall': ((1, 1, -14), (11, 7, 14)),
    'Upper stair': ((5, 8, 12), (12, 12, 14)),
    'Balcony': ((13, 9, 6), (19, 12, 14)),
}


def place(faction, u, y, v):
    sign = 1 if faction == 'accord' else -1
    return sign * (42 - u), y + 6, -sign * v


def template_pos(faction, u, y, v):
    return (20 - u, y, 15 - v) if faction == 'accord' else (u, y, 15 + v)


def hall_pos(faction, x, y, z):
    return (20 - x, y, 15 - z) if faction == 'accord' else (x, y, z - 15)


def bounds(faction):
    return {name: layout_box(faction, box) for name, box in BOXES.items()}


def layout_box(faction, box):
    first, last = (place(faction, *p) for p in box)
    return [[fn(a, b) for a, b in zip(first, last)] for fn in (min, max)]


def read(faction, text):
    t = templates.parse_template(str(BASELINE / f'breach_{faction}.tpl'), text)
    assert t.size == (21, 19, 31) and t.pivot == (21, 31) and t.origin == (0, 0, 0)
    assert all(e['kind'] == 'node' and not e.get('o') for e in t.legend.values())
    solids = {hall_pos(faction, *pos): t.legend[key]['name'] for pos, key in t.cells.items()
              if key != templates.FORCE_AIR}
    return t, solids


def flights():
    """Walking surface measured in half-nodes above the room's floor surface."""
    steps = {(u, v): v - 3 for u in range(2, 5) for v in range(4, 12)}
    steps.update({(u, v): 8 for u in range(2, 5) for v in range(12, 15)})
    steps.update({(u, v): u + 4 for u in range(5, 13) for v in range(12, 15)})
    return steps


def gallery(faction, original):
    m = original.copy()
    east = faction == 'accord'
    wall, floor, post, roof = (BRICK, STONE, PALE, SLATE) if east else (OAK, PLANK, LOG, OAK)
    edge = PALE if east else OAK

    # The closed cheek of the stair hood meets the back of the gate gallery.
    # Keep tower masonry above its ceiling. Tower tops retain their silhouettes.
    for u in range(4, 13):
        for v in range(11, 16):
            for y in range(8, 14):
                if y == 13:
                    m[u, y, v] = roof
                elif u == 4 or v in (11, 15):
                    m[u, y, v] = post if u in (4, 8, 12) else wall
                    if (u, y, v) == (8, 10, 15):
                        m[u, y, v] = LAMP
                else:
                    m.pop((u, y, v), None)

    # A solid bearing under each tread lets the same stamp work with param2=0
    # in both halls. Keep the old hall ceiling over the first flight and turn.
    for (u, v), rise in flights().items():
        top = (rise + 1) // 2
        for y in range(1, top):
            m.setdefault((u, y, v), wall if east else (LOG if u in (2, 8, 12) else OAK))
        # A continuous outer string in pale sandstone or oak turns with the stair.
        edging = u == 4 and v < 12 or v == 12 and u >= 4
        tread = edge if edging else floor
        m[u, top, v] = 'stairs:slab_' + tread.split(':')[1] if rise % 2 else tread
        for y in range(top + 1, 13 if u >= 5 else 8):
            m.pop((u, y, v), None)

    for u in range(12, 21):
        for v in range(5, 16):
            m[u, 8, v] = floor
            m[u, 13, v] = roof
            for y in range(9, 13):
                # The stair meets the back wall in a three-wide portal.
                if u == 12 and 12 <= v <= 14:
                    continue
                if v in (5, 15) or u == 12:
                    timber = u in (12, 16, 20) or (u == 12 and v in (5, 8, 11, 15))
                    mat = post if timber else wall
                    if y == 9:
                        mat = STONE if east else BASALT
                    if y == 11 and ((u == 12 and v == 8) or (u == 16 and v in (5, 15))):
                        mat = LAMP
                    m[u, y, v] = mat
                elif u == 19 and y == 9:
                    m[u, y, v] = RAIL
                else:
                    m.pop((u, y, v), None)
            # Pale fascia over slate, or a pine tie with two bronze end caps.
            if u == 20 or v in (5, 15):
                m[u, 13, v] = (PALE if east else LOG) if u != 20 or v not in (5, 15) else GOLD
            if u == 19:
                m[u, 8, v] = STONE if east else PLANK
                # Corbels stop above the outer gate's original clearance.
                if v in (5, 6, 14, 15):
                    m[u, 7, v] = post
    # The returned ends are masonry/timber. Only the road face needs a seal.
    (front, bottom, left), (_, top, right) = BARRIER_BOX
    for v in range(left, right + 1):
        for y in range(bottom, top + 1):
            m[front, y, v] = BARRIER
    return m


def draft(faction):
    path = BASELINE / f'breach_{faction}.tpl'
    source = path.read_text()
    t, before = read(faction, source)
    after = gallery(faction, before)
    keys = {entry['name']: key for key, entry in t.legend.items()}
    additions = dict(zip(sorted(set(after.values()) - keys.keys()), (c for c in string.ascii_uppercase if c not in t.legend)))
    keys.update(additions)
    header, layers = source.split('layer 0\n')
    header = header.replace('\nend\n', '\n' + ''.join(f'{k} node {n}\n' for n, k in additions.items()) + 'end\n')
    points = 'points\n' + layers.split('\npoints\n')[1]
    rows = []
    for y in range(19):
        rows.append(f'layer {y}')
        for z in range(31):
            rows.append('|' + ''.join(keys.get(after.get(hall_pos(faction, x, y, z)), '.')
                                      for x in range(21)) + '|')
        rows.append('')
    text = header + '\n'.join(rows) + '\n' + points
    _, actual = read(faction, text)
    assert actual == after and text.split("points\n")[-1] == source.split("points\n")[-1]
    counts = Counter(y for (u, y, v) in before.keys() | after.keys()
                     if before.get((u, y, v)) != after.get((u, y, v)))
    return before, after, text, counts


def cutaway(cells, after):
    # Lift the overhead construction from the selected hall, keeping the stair
    # and the new balcony floor and rail. This is a display operation only.
    cut = {}
    runs = flights() if after else {}
    for (u, y, v), name in cells.items():
        if (y <= (6 if u >= 12 else 1) or (u == 4 and v == 0 and y <= 3) or
                y <= (runs.get((u, v), 0) + 1) // 2 or
                (after and u >= 12 and v >= 5 and (y == 8 or (u == 19 and y == 9)))):
            cut[u, y, v] = name
    return cut

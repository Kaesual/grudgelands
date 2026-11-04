#!/usr/bin/env python3
"""Build Round 69 camp studies; --check verifies templates, inventory and page.

Tooling only. Reuses the template parsers, game palettes and building viewer.
No server, game-file mutation, new node registration or runtime fixture.
"""
import argparse
import base64
from collections import deque
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VIEWER = ROOT / 'tools/building_templates/viewer'
sys.path.insert(0, str(VIEWER))
sys.path.insert(0, str(ROOT / 'tools/building_templates/editor'))
import build_viewer as V
import build_gallery as G
import templates as T
import tplfile

_spec = importlib.util.spec_from_file_location('template_gate', ROOT / 'tools/building_templates/check.py')
GATE = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(GATE)

RACES = ('dwarf', 'human', 'elf', 'orc', 'undead', 'troll')
FACTION = {r: ('accord' if r in RACES[:3] else 'throng') for r in RACES}
SOCKETS = {'gate_west': (-2, 1, -9, 1), 'gate_east': (2, 1, -9, 3),
           'yard_west': (-4, 1, 1, 2), 'yard_east': (4, 1, 1, 2),
           'captain': (0, 1, 3, 2)}
VARIANTS = {
    'wallwright': {'name': 'Wallwright', 'tag': 'A / The wall goes up',
        'rationale': 'A finished gate and west wall meet an east wall still on its scaffold. '
        'Full panels, first courses and pegged footings make a readable sequence around the ring.',
        'detail': 'The scaffold is the silhouette: a long working deck, uprights above it and a ladder. '
        'Two small canvas shelters and the command tent occupy the completed half.'},
    'first_lift': {'name': 'First Lift', 'tag': 'B / The mine takes shape',
        'rationale': 'A half-height headframe rises behind the completed gate. One upper portal is up; '
        'its matching posts stop at a straight working deck. A rope hoist, covered shaft collar '
        'and prepared wall foundations make the next building steps visible.',
        'detail': 'Recommended. The tall open frame reads from a distance and identifies the site '
        'as an earlier mining camp. The finished gate, command tent and two worker tents establish '
        'the military foothold; the rear ring is still being laid out.'},
    'panel_yard': {'name': 'Panel Yard', 'tag': 'C / An army building in batches',
        'rationale': 'Two long canvas barracks flank the parade route. At the back, complete wall '
        'panels wait in tidy racks beside timber and masonry stacks. Paired survey stakes '
        'outline the next wall bays.',
        'detail': 'The lowest, widest silhouette. Repeated panel racks and measured foundations '
        'make the work look organized; the central command shelter anchors the guarded courtyard.'},
}


def role(name, facedir=None):
    return 'role ' + name + (f' o=facedir:{facedir}' if facedir is not None else '')


def node(name, facing=None, kind='facedir'):
    return 'node ' + name + (f' o={kind}:{facing}' if facing is not None else '')


class Camp:
    def __init__(self):
        self.cells = {}
        self.fill(-11, 0, -11, 11, 0, 11, role('ground'))
        self.fill(-2, 0, -11, 2, 0, 4, role('path'))
        self.fill(-8, 0, -1, 8, 0, 2, role('path'))

    def put(self, x, y, z, entry):
        assert -11 <= x <= 11 and -11 <= z <= 11 and 0 <= y <= 9, (x, y, z)
        self.cells[x, y, z] = entry

    def fill(self, x0, y0, z0, x1, y1, z1, entry):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                for x in range(x0, x1 + 1):
                    self.put(x, y, z, entry)

    def banner(self, x, y, z, facing=0):
        assert self.cells.get((x, y+1, z)) in (role('beam'), role('roof_slab'))
        self.put(x, y, z, node('grug_mapgen:faction_banner_{faction}', facing))

    def wall(self, side, a, b, stage='done'):
        """Ordered construction bays: finished, first course, footing, survey."""
        for u in range(a, b+1):
            x, z = (u, -10) if side == 'front' else ((u, 10) if side == 'back' else
                    ((-10, u) if side == 'west' else (10, u)))
            facing = 1 if side in ('west', 'east') else 0
            self.put(x, 0, z, role('foundation'))
            if stage == 'survey':
                if u % 4 == 2 or u in (a, b):
                    self.put(x, 1, z, role('fence'))
                else:
                    self.put(x, 0, z, role('ground_bare'))
                continue
            self.put(x, 1, z, role('foundation'))
            if stage == 'footing':
                if u % 4 == 2:
                    self.put(x, 2, z, role('fence'))
                continue
            post = u % 4 == 2 or u in (-10, 10)
            if post:
                self.fill(x, 2, z, x, 4, z, role('post'))
            else:
                self.fill(x, 2, z, x, 3 if stage == 'done' else 2, z,
                          node('grug_mapgen:camp_stockade_{race}', facing))
                if stage == 'done':
                    self.put(x, 4, z, node('grug_mapgen:camp_wall_cap_{race}', facing))

    def gate(self):
        self.wall('front', -10, -4)
        self.wall('front', 4, 10)
        for x in (-3, 3):
            for z in (-10, -9):
                self.put(x, 1, z, role('foundation'))
                self.fill(x, 2, z, x, 5, z, role('post'))
        self.fill(-5, 5, -10, 5, 5, -10, role('beam'))
        self.fill(-3, 5, -9, 3, 5, -9, role('beam'))
        self.fill(-4, 6, -11, 4, 6, -9, role('roof_slab'))
        self.banner(-5, 4, -10)
        self.banner(5, 4, -10)

    def tent(self, cx, z0, z1, half=2, command=False):
        self.fill(cx-half, 0, z0, cx+half, 0, z1, role('floor'))
        for z in range(z0, z1+1):
            for dx in range(-half, half+1):
                name = 'camp_trim_{faction}' if abs(dx) == half else 'camp_canvas'
                self.put(cx+dx, half+1-abs(dx), z,
                         node('grug_mapgen:'+name, 0 if dx <= 0 else 2))
            self.put(cx, half+1, z, node('grug_mapgen:camp_ridge', 0))
        for x in (cx-half, cx+half):
            for z in (z0, z1):
                self.put(x, 0, z, role('foundation'))
        # The rear support and low canvas back leave a real entrance at -z.
        self.fill(cx, 1, z1, cx, half, z1, role('post'))
        for dx in (-1, 1):
            self.put(cx+dx, 1, z1-1, node('grug_decor:cottages_straw_mat', 0))
        if command:
            self.put(cx, 1, z1-2, node('grug_decor:cottages_table', 0))

    def command(self):
        self.tent(0, 5, 9, 3, True)
        # A supported standard beside the tent; the captain's cell stays open.
        self.fill(4, 1, 5, 4, 5, 5, role('post'))
        self.fill(3, 5, 5, 5, 5, 5, role('beam'))
        self.banner(3, 4, 5)
        self.fill(-2, 0, 3, 2, 0, 5, role('path'))

    def timber(self, x, z, length=4):
        # Cut timber stock, supported from the ground, with a smaller top row.
        for zz in (z, z+1):
            self.fill(x, 1, zz, x+length-1, 1, zz, role('tree_log'))
        self.fill(x+1, 2, z, x+length-2, 2, z, role('tree_log'))

    def stone(self, x, z):
        self.fill(x, 1, z, x+1, 1, z+1, role('foundation'))
        self.put(x, 2, z+1, role('foundation'))

    def scaffold(self):
        # A working platform parallel to the unfinished east wall.
        for x in (8, 10):
            for z in (2, 5, 8):
                self.put(x, 0, z, role('foundation'))
                self.fill(x, 1, z, x, 6, z, role('fence'))
        self.fill(8, 4, 2, 10, 4, 8, role('roof_slab', 20))
        for z in range(2, 9):
            self.put(8, 5, z, role('fence'))
        for x in (9, 10):
            for z in (2, 8):
                self.put(x, 5, z, role('fence'))
        for y in range(1, 5):
            self.put(9, y, 1, node('default:ladder_wood', 5, 'wallmounted'))
        self.fill(9, 1, 2, 9, 3, 2, role('post'))
        self.put(9, 5, 6, role('roof_slab'))


def composition(variant):
    """One symbolic composition per variant, shared without race shape branches."""
    c = Camp()
    c.gate()
    c.command()
    if variant == 'wallwright':
        c.wall('west', -9, 10)
        c.wall('back', -9, -2)
        c.wall('back', -1, 9, 'survey')
        c.wall('east', -9, -2)
        c.wall('east', -1, 2, 'course')
        c.wall('east', 3, 10, 'footing')
        c.scaffold()
        c.tent(-7, -7, -3)
        c.tent(-7, 3, 7)
        c.timber(5, -6)
        c.stone(6, -3)
        c.stone(6, 8)
    elif variant == 'first_lift':
        c.wall('west', -9, -2)
        c.wall('east', -9, -2)
        c.wall('west', -1, 10, 'footing')
        c.wall('east', -1, 10, 'course')
        c.wall('back', -9, 9, 'survey')
        c.tent(-7, -7, -3)
        c.tent(7, -7, -3)
        # The mine's first structural lift: a complete lower ring, one upper portal.
        c.fill(-9, 0, 4, -5, 0, 8, role('foundation'))
        for x in (-9, -5):
            for z in (4, 8):
                c.fill(x, 1, z, x, 8 if z == 8 else 5, z, role('post'))
        for z in (4, 8):
            c.fill(-9, 5, z, -5, 5, z, role('beam'))
        for x in (-9, -5):
            c.fill(x, 5, 4, x, 5, 8, role('beam'))
        c.fill(-9, 9, 8, -5, 9, 8, role('beam'))
        # Open working deck, supported hoist and covered shaft: no pit and no lift.
        c.fill(-9, 5, 6, -5, 5, 7, role('roof_slab'))
        c.fill(-7, 9, 6, -7, 9, 7, role('beam'))
        c.fill(-7, 3, 6, -7, 8, 6, node('grug_decor:xdecor_rope'))
        c.fill(-8, 1, 5, -6, 1, 7, role('foundation'))
        c.fill(-8, 1, 5, -6, 1, 6, node('grug_decor:darkage_iron_grille'))
        c.put(-7, 2, 6, role('roof_slab'))
        for y in range(1, 6):
            c.put(-5, y, 3, node('default:ladder_wood', 5, 'wallmounted'))
        c.fill(-4, 0, 4, -3, 0, 9, role('path'))
        c.timber(6, 6)
        c.stone(6, 3)
        # Survey bay pairs: the posts stand beside the unfilled rear foundation line.
        for x in (-2, 2, 6):
            c.put(x, 1, 10, role('fence'))
    elif variant == 'panel_yard':
        c.wall('west', -9, -2)
        c.wall('east', -9, -2)
        c.wall('west', -1, 10, 'survey')
        c.wall('east', -1, 10, 'footing')
        c.wall('back', -9, 9, 'survey')
        c.tent(-7, -7, 0)
        c.tent(7, -7, 0)
        # Three complete wall bays on timber pads: awaiting installation.
        for z in (4, 6, 8):
            c.fill(-9, 0, z, -5, 0, z, role('floor'))
            for x in (-9, -5):
                c.fill(x, 1, z, x, 3, z, role('fence'))
            c.fill(-8, 1, z, -6, 2, z, node('grug_mapgen:camp_stockade_{race}', 0))
            c.fill(-8, 3, z, -6, 3, z, node('grug_mapgen:camp_wall_cap_{race}', 0))
        c.timber(6, 7)
        c.stone(6, 3)
        c.put(8, 1, 4, node('grug_decor:cottages_table', 0))
        # Parallel stakes mark complete bays, rather than a broken wall edge.
        for z in (2, 6, 10):
            c.put(-9, 1, z, role('fence'))
    else:
        raise ValueError(variant)
    return c.cells


def template(variant, race):
    cells = {p: e.format(race=race, faction=FACTION[race]) for p, e in composition(variant).items()}
    name = 'camp_site_' + race
    m = tplfile.Model()
    m.name, m.cell = name, 1
    m.origin, m.size, m.pivot = (-11, 0, -11), (23, 10, 23), (23, 23)
    m.races = [race]
    m.head = [f'# Round 69 proposal {variant}; generated by tools/r69_camp_art/build.py.',
              'name '+name, 'pivot 23 23', 'origin -11 0 -11', 'size 23 10 23', 'cell 1',
              'meta extent=[-11,-11,11,11] peak=9 top=9', 'races '+race]
    entries = sorted(set(cells.values()))
    assert len(entries) <= len(tplfile.ALPHABET)
    keys = {e: tplfile.ALPHABET[i] for i, e in enumerate(entries)}
    m.legend = [[keys[e], e] for e in entries]
    for y in range(10):
        m.layers.append([''.join(keys[cells[x,y,z]] if (x,y,z) in cells else '.'
                                for x in range(-11,12)) for z in range(-11,12)])
    for key, (x,y,z,face) in SOCKETS.items():
        m.points.append(['camp_points', x, y, z, f'face={face} id={key}'])
    m.points += [['doors', 0, 1, -11, 'face=2 id=gate'], ['inside', 0, 1, 0, 'id=yard']]
    return tplfile.dump(m)


def write(path, data, check):
    data = data.encode('utf-8') if isinstance(data, str) else data
    if check:
        assert path.is_file() and path.read_bytes() == data, 'stale output: '+str(path.relative_to(ROOT))
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def validate(text, path, palettes, registry):
    GATE.parse_template(text, str(path), path.stem)
    t = T.parse_template(str(path), text)
    assert t.origin == (-11,0,-11) and t.size == (23,10,23)
    assert t.meta['extent'] == [-11,-11,11,11]
    assert T.UNCHANGED not in t.cells.values()
    cells, bad = T.resolved_cells(t, T.resolve(t, palettes, {'main': palettes.bind(t.races[0])}), palettes)
    assert not bad, bad
    for pos, (name, p2) in cells.items():
        assert name == 'air' or name in registry, name
        if name == 'air':
            continue
        assert registry[name].get('liquidtype', 'none') == 'none'
        assert not any(s in name for s in ('guild_lift', 'chest', 'barrel', 'furnace', 'fire:', 'lava', 'water'))
        assert not registry[name].get('groups', {}).get('falling_node') or pos[1] == 0
        assert 0 <= p2 <= 23
    def air(x,y,z):
        return cells.get((x,y,z), ('air',0))[0] == 'air'
    def solid(x,y,z):
        n = cells.get((x,y,z), ('air',0))[0]
        return n != 'air' and registry[n].get('walkable', True)
    assert all(solid(x,0,z) for x in range(-11,12) for z in range(-11,12))
    assert all(air(x,y,z) for x in range(-2,3) for z in range(-2,3) for y in range(1,4))
    actual = {dict(p['attrs'])['id']: (p['x'],p['y'],p['z'],p['face'])
              for p in t.points if p['group'] == 'camp_points'}
    assert actual == SOCKETS, actual
    for x,y,z,_ in SOCKETS.values():
        assert air(x,y,z) and air(x,y+1,z) and solid(x,y-1,z)
    # A stricter flat, all-air walk suffices; no jumps or shape-dependent gaps.
    seen, queue = {(0,-11)}, deque([(0,-11)])
    while queue:
        x,z = queue.popleft()
        for nx,nz in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
            if not (-11<=nx<=11 and -11<=nz<=11) or (nx,nz) in seen:
                continue
            if solid(nx,0,nz) and air(nx,1,nz) and air(nx,2,nz):
                seen.add((nx,nz)); queue.append((nx,nz))
    assert all((x,z) in seen for x,_,z,_ in SOCKETS.values())
    # Check orientation compatibility and physical reach of authored assets.
    for x,y,z in cells:
        name,p2 = cells[x,y,z]
        if 'faction_banner_' in name:
            assert cells.get((x,y+1,z), ('air',0))[0] != 'air'
    return t, cells


def lua_parse(lua, outputs):
    # Existing game loader, parse only; temporary templates directory is never a world.
    with tempfile.TemporaryDirectory(prefix='r69-camp-parser-') as tmp:
        directory = Path(tmp)
        (directory/'templates').mkdir()
        for variant in VARIANTS:
            names = []
            for race in RACES:
                name = f'templates/camp_site_{race}.tpl'
                (directory/name).write_text(outputs[variant,race], encoding='utf-8')
                names.append(name)
            result = subprocess.run([lua, str(ROOT/'tools/building_templates/loader_check.lua'),
                                     str(ROOT), tmp], input='\n'.join(names)+'\n',
                                    text=True, capture_output=True, cwd=ROOT, check=True)
            assert not result.stdout.strip(), result.stdout
            # Exercise the existing loader/resolver and stamp, including all four
            # orientations. A centred camp needs the footprint's pivot offset
            # removed; r63_camp_blueprint.lua likewise turns about the origin.
            script = '''
local wp = "mods/MAPGEN/grug_mapgen/wp13"
local parts = dofile(wp.."/parts.lua")
local templates = dofile(wp.."/templates.lua")(wp)
local palette = dofile(wp.."/palette.lua")
for path in io.read("*a"):gmatch("%S+") do
 local file=assert(io.open(path,"rb")); local text=file:read("*a"); file:close()
 local t=templates.parse_template(text,path,path:match("([^/]+)%.tpl$"))
 local p=palette.new(t.races[1])
 local part=templates.part(t,"camp",t.races[1],function() return p end)
 for turn=0,3 do
  local ox,oz=parts.rotate_footprint(0,0,23,23,turn)
  local buf=parts.buffer()
  local moved=parts.stamp(buf,part,-ox,0,-oz,turn)
  local cells,n=buf:cells(); assert(n==5290,"incomplete rewrite box")
  for _,c in ipairs(cells) do
   assert(c.x>=-11 and c.x<=11 and c.z>=-11 and c.z<=11 and c.y>=0 and c.y<=9)
   if c.y==0 then assert(c.name~="air","floor") end
   if math.abs(c.x)<=2 and math.abs(c.z)<=2 and c.y>=1 and c.y<=3 then
    assert(c.name=="air","yard")
   end
  end
  for i,s in ipairs(moved.camp_points) do
   assert(buf:at(s.x,1,s.z).name=="air" and buf:at(s.x,2,s.z).name=="air")
   assert(buf:at(s.x,0,s.z).name~="air")
   assert(s.face==(part.points.camp_points[i].face+turn)%4)
  end
 end
end
'''
            subprocess.run([lua, '-e', script], cwd=ROOT,
                           input='\n'.join(str(directory/n) for n in names)+'\n',
                           text=True, capture_output=True, check=True)


def current(lua, race):
    # Adapter for the existing blueprint exporter; no new committed Lua.
    script = '''return function()
local bp = dofile("mods/MAPGEN/grug_mapgen/wp40/r58_camp_blueprint.lua")({}, {
 blueprint_schema=1, art={kind="camp_construction",race="RACE",faction="FACTION",turns=0}})
local points={}
for _,s in ipairs(bp.landmarks.sockets) do points[s.id]=s end
bp.landmarks=points
return bp
end
'''.replace('RACE', race).replace('FACTION', FACTION[race])
    with tempfile.TemporaryDirectory(prefix='r69-camp-current-') as tmp:
        path = Path(tmp)/'export.lua'
        path.write_text(script)
        proc = subprocess.run([lua, str(VIEWER/'export_blueprint.lua'), str(path)],
                              cwd=ROOT, capture_output=True, text=True, check=True)
    cells = {}
    for line in proc.stdout.splitlines():
        if not line.startswith('#'):
            x,y,z,name,p2 = line.split('\t')
            cells[int(x),int(y),int(z)] = (name,int(p2))
    return cells


def build_page(scenes, registry, aliases, check):
    textures, meshes, names, indices = V.Textures(), {}, [], {}
    packed = {}
    for key, cells in scenes.items():
        packed[key] = V.pack_cells({'points':{k:list(v[:3]) for k,v in SOCKETS.items()}},
                                   [(*p,*v) for p,v in sorted(cells.items()) if v[0]!='air'], indices, names)
    types, report = V.build_types(names, registry, aliases, textures, meshes)
    assert not report['skipped'] and not report['missing_mesh'] and not textures.missing, (report,textures.missing)
    # The shared static B3D reader groups TRIS by brush id and keeps raw units.
    # R63's animated camp meshes use ten engine units per node and one tile per
    # TRIS chunk, all with brush -1 (tools/r63_camp_art/build.py:b3d). Give those
    # chunks distinct reader keys in a temporary copy, then convert xyz only.
    # This is a page export correction; the shared reader and game stay intact.
    for name, count in (('grug_mapgen_camp_canvas.b3d', 1),
                        ('grug_mapgen_faction_banner.b3d', 3)):
        data = bytearray(Path(V.find_model(name)).read_bytes())
        found = []
        def chunks(start, end):
            while start < end:
                tag = bytes(data[start:start+4])
                length = struct.unpack_from('<i', data, start+4)[0]
                body, finish = start+8, start+8+length
                assert finish <= end
                if tag == b'BB3D':
                    chunks(body+4, finish)
                elif tag == b'NODE':
                    chunks(data.index(0, body)+41, finish)
                elif tag == b'MESH':
                    chunks(body+4, finish)
                elif tag == b'TRIS':
                    struct.pack_into('<i', data, body, len(found))
                    found.append(body)
                start = finish
        chunks(0, len(data))
        assert len(found) == count
        with tempfile.TemporaryDirectory(prefix='r69-mesh-reader-') as tmp:
            path = Path(tmp)/name
            path.write_bytes(data)
            buffers = V.parse_b3d(str(path))
        assert len(buffers) == count
        meshes[name] = [[round(v/10 if i%5<3 else v, 6) for i,v in enumerate(b)] for b in buffers]
    payload = {'scenes':packed, 'types':types, 'textures':textures.images, 'meshes':meshes,
               'variants':VARIANTS, 'races':RACES, 'factions':FACTION}
    page = (HERE/'page.html').read_text()
    page = V.inline_renderer(page)
    # The repository already vendors r147 for offline tools. These two property
    # spellings bridge the shared renderer's r160 color API to that library.
    page = page.replace('t.colorSpace = THREE.SRGBColorSpace;', 't.encoding = THREE.sRGBEncoding;')
    page = page.replace('renderer.outputColorSpace = THREE.SRGBColorSpace;',
                        'renderer.outputEncoding = THREE.sRGBEncoding;')
    page = page.replace('__THREE__', (ROOT/'tools/r54_armor/vendor/three.min.js').read_text().replace('</','<\\/'))
    page = page.replace('__ORBIT__', (HERE/'orbit.js').read_text().replace('</','<\\/'))
    page = page.replace('__THREE_LICENSE__', (HERE/'THREE-LICENSE.txt').read_text())
    overview = HERE/'renders/overview.png'
    image = ('<img class="sheet" alt="Three views of each proposal in Human and Orc materials" '
             'src="data:image/png;base64,'+base64.b64encode(overview.read_bytes()).decode()+'">') if overview.exists() else '<p>Still overview pending render.py.</p>'
    page = page.replace('__OVERVIEW__', image)
    page = page.replace('__PAYLOAD__', json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
    write(HERE/'index.html', page, check)
    return len(names)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--templates-only', action='store_true', help='Skip viewer and baseline export')
    args = ap.parse_args()
    lua = V.find_lua()
    reg = json.loads(Path(V.NODES_JSON).read_text())
    palettes = T.Palettes(G.load_palettes(lua, set(reg['nodes']) | set(reg.get('aliases',{}))))
    outputs, scenes, inventory = {}, {}, {}
    for variant in VARIANTS:
        inventory[variant] = {}
        for race in RACES:
            text = template(variant, race)
            path = HERE/'candidates'/variant/f'camp_site_{race}.tpl'
            _, cells = validate(text, path, palettes, reg['nodes'])
            outputs[variant,race] = text
            write(path, text, args.check)
            scenes[race+'/'+variant] = cells
            inventory[variant][race] = sorted({n for n,p in cells.values() if n!='air'})
    lua_parse(lua, outputs)
    write(HERE/'nodes.json', json.dumps(inventory,indent=2)+'\n', args.check)
    if not args.templates_only:
        for race in RACES:
            scenes[race+'/current'] = current(lua, race)
        count = build_page(scenes, reg['nodes'], reg.get('aliases',{}), args.check)
        print(f'Offline comparison: 24 scenes, {count} node types; no missing textures or meshes.')
    print(f'Round 69 CAMPART: 18 templates {"verified" if args.check else "written"}; '
          'both Python parsers and the game Lua parser PASS; 72 native rotated stamps PASS; '
          'box, floor, yard, sockets and flat routes PASS.')

if __name__ == '__main__':
    main()

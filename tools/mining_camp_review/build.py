#!/usr/bin/env python3
"""Build a proposal-only comparison using the existing template renderer."""
import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools/building_templates/viewer'))
import build_viewer as V
import build_gallery as G
import templates as T

RACES = {'accord': [('human', 'Highcourt'), ('dwarf', 'Dur Brannoc'), ('elf', 'Lethariel')],
         'throng': [('orc', 'Gor Drazhak'), ('undead', 'Nhal Veyr'), ('troll', 'Kezamba')]}
KINDS = ['pvp_camp_low', 'pvp_camp_high', 'mining_camp']


def uri(svg):
    return 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode()


def artwork(faction, icon=False):
    """Original vector heraldry; deliberately simple enough for a small UI icon."""
    bg, ink = ('#344b5a', '#d6c59b') if faction == 'accord' else ('#683e39', '#d1ba91')
    # Accord: three joined pillars under one arch. Throng: three rising tusks.
    symbol = ('<path d="M30 83V49L50 34L70 49V83M40 80V53M50 80V48M60 80V53" '
              'fill="none" stroke="%s" stroke-width="6" stroke-linejoin="miter"/>' % ink
              if faction == 'accord' else
              '<path d="M26 40L36 48L41 74L46 37L50 29L54 37L59 74L64 48L74 40L69 80L50 91L31 80Z" fill="%s"/>' % ink)
    if icon:
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="20 22 60 76">{symbol}</svg>'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="256" viewBox="0 0 100 160">
+<defs><pattern id="weave" width="4" height="4" patternUnits="userSpaceOnUse"><path d="M0 0H4M0 2H4" stroke="#fff" opacity=".035"/></pattern></defs>
+<path d="M6 3H94V142L50 157L6 142Z" fill="{bg}"/>
+<path d="M12 8H88V138L50 151L12 138Z" fill="none" stroke="{ink}" stroke-width="2"/>
+<path d="M6 3H94V142L50 157L6 142Z" fill="url(#weave)"/>
+<path d="M17 5V138M83 5V138" stroke="#000" opacity=".12" stroke-width="5"/>
+{symbol}<path d="M38 111H62M44 117H56" stroke="{ink}" stroke-width="2"/>
+</svg>'''.replace('\n+', '\n')


def cloth(color, trim=False):
    stripe = '<path d="M0 6H32M0 26H32" stroke="#b3a183" stroke-width="2"/>' if trim else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><defs><pattern id="w" width="4" height="4" patternUnits="userSpaceOnUse"><path d="M0 0H4M0 2H4" stroke="#fff" opacity=".09"/><path d="M0 0V4M2 0V4" stroke="#000" opacity=".08"/></pattern></defs><path fill="{color}" d="M0 0H32V32H0Z"/><path fill="url(#w)" d="M0 0H32V32H0Z"/>{stripe}<path d="M1 0V32M31 0V32" stroke="#312f29" opacity=".3"/></svg>'


def box_mesh(x0, y0, z0, x1, y1, z1):
    """A small hardware box in the shared renderer's xyzuv triangle format."""
    vertices = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
                (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    faces = [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]
    uv = [(0,0),(1,0),(1,1),(0,1)]
    return [v for face in faces for i in (0,1,2,0,2,3)
            for v in (*vertices[face[i]], *uv[i])]


def current(lua, race, faction, kind):
    env = dict(os.environ, CAMP_REVIEW_RACE=race, CAMP_REVIEW_FACTION=faction, CAMP_REVIEW_KIND=kind)
    result = subprocess.run([lua, str(Path(V.HERE) / 'export_blueprint.lua'), str(HERE / 'export.lua')],
                            cwd=ROOT, env=env, capture_output=True, text=True, check=True)
    cells, points = {}, {}
    for line in result.stdout.splitlines():
        row = line.split('\t')
        if row[0] == '#point':
            points[row[1]] = [int(v) for v in row[2:5]]
        elif not row[0].startswith('#'):
            x, y, z, name, p2 = row
            cells[int(x), int(y), int(z)] = (name, int(p2))
    return cells, points


def proposal(palette, hall, faction, kind):
    """An isolated cell proposal: same footprint, clear centre, reused headframe."""
    p = palette['roles']
    r = 13 if kind == 'pvp_camp_high' else 11
    cells = {}
    def put(x, y, z, name, p2=0): cells[x, y, z] = (name, p2)
    def fill(x0, y0, z0, x1, y1, z1, name, p2=0):
        for z in range(z0, z1+1):
            for y in range(y0, y1+1):
                for x in range(x0, x1+1): put(x, y, z, name, p2)
    def banner(x, y, z):
        assert cells.get((x,y,z), ('air',0))[0] != p['post'], 'banner would replace a post'
        put(x, y, z, 'proposal:banner_'+faction)
    fill(-r, 0, -r, r, 0, r, p['ground'])
    fill(-3, 0, -r, 3, 0, r, p['path'])
    fill(-r+1, 0, -2, r-1, 0, 2, p['path'])
    fill(-4, 0, 3, 4, 0, 10, p['path'])
    # A closed timber stockade on a stone plinth. Recessed panels and
    # projecting posts break up the silhouette without openings at eye level.
    race = palette['race']
    for z in range(-r, r+1):
        for x in range(-r, r+1):
            if max(abs(x), abs(z)) == r and not (z == -r and abs(x) <= 2):
                put(x, 1, z, p['foundation'])
                side = abs(x) == r
                if (abs(x) == r and abs(z) == r) or (z if side else x) % 4 == 0:
                    fill(x, 2, z, x, 4, z, p['post'])
                else:
                    fill(x, 2, z, x, 3, z, 'proposal:stockade_'+race, 1 if side else 0)
                    put(x, 4, z, 'proposal:wall_cap_'+race, 1 if side else 0)
    # Deep gate frame with a lintel and a small roof; five clear columns.
    for x in (-3, 3):
        for z in (-r, -r+1):
            put(x, 1, z, p['foundation'])
            fill(x, 2, z, x, 5, z, p['post'])
    fill(-5, 5, -r, 5, 5, -r, p['beam'])
    fill(-3, 5, -r+1, 3, 5, -r+1, p['beam'])
    fill(-3, 6, -r, 3, 6, -r+1, p['roof_slab'])
    for x in (-4, 4):
        put(x, 6, -r, 'grug_decor:xdecor_lantern')
    for x in (-5, 5):
        banner(x, 4, -r)
    # Exact headframe cells from the current capital template (translation only).
    # Four legs x=12/15,z=9/12, beam rings y=5/10/15, head y=16.
    for (x,y,z),(name,p2) in hall.items():
        if 12 <= x <= 15 and 8 <= z <= 12 and 0 <= y <= 16 and name != 'air':
            put(x-14,y,z-3,name,p2)
    put(-1,1,7,'grug_mapgen:guild_lift',0)  # replaces the tub, directly under the rope
    fill(-2,0,4,1,0,9,p['floor'])
    for z in range(6,9): put(-1,0,z,'grug_decor:darkage_iron_grille')
    # Short ore rail beside the pedestrian approach.
    for z in range(3,7): put(2,1,z,'grug_mapgen:mine_rail',0)
    put(2,1,4,'grug_mapgen:mine_cart',0)
    # Tents have thin sloping canvas, a wooden ridge and low stone feet.
    def tent(cx, z0, z1):
        fill(cx-2,0,z0,cx+2,0,z1,p['floor'])
        for z in range(z0,z1+1):
            for dx in range(-2,3):
                name = 'proposal:canvas' if abs(dx) < 2 else 'proposal:trim_'+faction
                put(cx+dx, 3-abs(dx), z, name, 0 if dx <= 0 else 2)
            put(cx,3,z,'proposal:ridge')
        for dx in (-2,2):
            for z in (z0,z1): put(cx+dx,0,z,p['foundation'])
        for y in (1,2): put(cx,y,z1,p['post'])
        put(cx-1,1,z1-1,'grug_decor:cottages_straw_mat')
        put(cx+1,1,z1-1,p['storage'])
    tent(-7,-7,-3)
    tent(-7,3,8)
    put(-7,1,5,'grug_decor:cottages_table')
    fill(-4,1,3,-4,5,3,p['post'])
    fill(-5,5,3,-3,5,3,p['beam'])
    banner(-5,4,3)
    # Covered counter on the east, with the work stores behind it.
    for x in (5,9):
        for z in (-6,-2): fill(x,1,z,x,3,z,p['post'])
    fill(5,4,-6,9,4,-2,p['roof_slab'])
    for z in (-5,-3): put(5,1,z,p['storage'])
    put(5,1,-4,'grug_decor:cottages_table')
    banner(7,3,-6)
    put(8,1,-3,'grug_decor:xdecor_barrel')
    for x,z in ((6,6),(7,6),(8,6),(7,7)):
        put(x,1,z,p['rubble'])
    put(7,2,6,'grug_materials:copper_block')
    for z in (8,9):
        fill(6,1,z,9,1,z,p['beam'])
        fill(7,2,z,8,2,z,p['beam'])
    for x,z in ((4,9),(-4,-8),(9,2)):
        fill(x,1,z,x,2,z,p['post']); put(x,3,z,'grug_decor:xdecor_lantern')
    # Higher-band camp keeps lookout decks, with lower roofs than the headframe.
    if kind == 'pvp_camp_high':
        for cx in (-10,10):
            for dx in (-1,1):
                for dz in (-1,1): fill(cx+dx,1,-10+dz,cx+dx,6,-10+dz,p['post'])
            fill(cx-1,4,-11,cx+1,4,-9,p['floor'])
            fill(cx-1,7,-11,cx+1,7,-9,p['roof_slab'])
            for y in range(1,5): put(cx,y,-8,'default:ladder_wood',5)
    assert all(abs(x)<=r and abs(z)<=r for x,y,z in cells)
    assert not any((x,y,z) in cells for x in range(-2,3) for z in range(-2,3) for y in range(1,4))
    assert sum(v[0]=='grug_mapgen:guild_lift' for v in cells.values()) == 1
    # Every new faction banner hangs below a beam or the vendor's roof,
    # never in place of a structural post. The mesh's two brackets reach
    # into that support, while its rod holds the cloth's upper edge.
    for (x, y, z), (name, _) in cells.items():
        if name.startswith('proposal:banner_'):
            assert cells.get((x, y+1, z), ('air', 0))[0] in (p['beam'], p['roof_slab'])
    return cells, {'lift':[-1,1,7], 'quest_foreman':[-7,1,2], 'vendor_camp':[6,1,-4], 'held_load':[8,1,4]}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('-o','--out', type=Path, default=HERE/'index.html')
    args = ap.parse_args()
    lua = V.find_lua()
    reg = json.loads(Path(V.NODES_JSON).read_text())
    registry = reg['nodes']
    pal = T.Palettes(G.load_palettes(lua, set(registry)|set(reg.get('aliases',{}))))
    textures, meshes, names, indices = V.Textures(), {}, [], {}
    scenes, art = {}, {}
    for faction, races in RACES.items():
        art[faction] = {'banner':uri(artwork(faction)), 'icon':uri(artwork(faction, True))}
        for race, capital in races:
            tpl = T.parse_template(str(ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'/ (capital.lower().replace(' ','_')+'_miners_guild.tpl')))
            binding = pal.bind(race)
            hall, bad = T.resolved_cells(tpl, T.resolve(tpl,pal,{'main':binding}), pal)
            assert not bad, bad
            for kind in KINDS:
                before, bp = current(lua,race,faction,kind)
                after, apoints = proposal(binding,hall,faction,kind)
                key = race+'/'+kind
                scenes[key] = {}
                for mode,cells,points in [('current',before,bp),('proposal',after,apoints)]:
                    rows = [(*pos,*value) for pos,value in sorted(cells.items()) if value[0]!='air']
                    scenes[key][mode] = V.pack_cells({'points':points},rows,indices,names)
    # Proposal definitions exist only in this page, never in the game registry.
    custom = {'proposal:canvas':cloth('#99917b'), 'proposal:ridge':cloth('#635a46')}
    for faction in RACES:
        custom['proposal:trim_'+faction] = cloth('#465967' if faction=='accord' else '#754c45',True)
        custom['proposal:banner_'+faction] = art[faction]['banner']
    realnames = [n for n in names if not n.startswith('proposal:')]
    # Hardware and stockade materials use existing game textures.
    for n in ['default:wood', 'grug_materials:steel_block'] + [p['floor'] for p in pal.races.values()]:
        if n not in realnames:
            realnames.append(n)
    realtypes, report = V.build_types(realnames,registry,reg.get('aliases',{}),textures,meshes)
    assert not report['skipped'] and not report['missing_mesh'] and not textures.missing, (report,textures.missing)
    types_by_name = dict(zip(realnames,realtypes))
    for race, palette in pal.races.items():
        for piece, boxes in (
            ('stockade', [[-.5,-.5,-.18,.5,.5,.18],
                         [-.5,-.42,-.28,.5,-.25,.28],[-.5,.25,-.28,.5,.42,.28]]),
            ('wall_cap', [[-.5,-.5,-.35,.5,-.28,.35]]),
        ):
            name = 'proposal:'+piece+'_'+race
            base = dict(types_by_name[palette['floor']])
            base.update(name=name, dt='nodebox', p2='facedir', boxes=boxes)
            types_by_name[name] = base
    for name,svg in custom.items():
        ti = len(textures.images); textures.images.append(svg if svg.startswith('data:') else uri(svg))
        banner = 'banner' in name
        ridge = name.endswith('ridge')
        base = {'name':name,'dt':'nodebox','p2':'facedir','tex':[ti]*6,'world':[False]*6,
                'alpha':'clip','vs':1,'light':0}
        if ridge:
            base['boxes'] = [[-.5,-.5,-.5,.5,-.38,.5]]
        else:
            # Explicit UVs keep the entire banner on one face. Thin sloped
            # canvas avoids gaps between stepped nodeboxes. Preview meshes
            # only, not imported or registered game assets.
            if banner:
                verts = [(-.48,.5,-.52,0,1),(.48,.5,-.52,1,1),
                         (.48,-1.5,-.52,1,0),(-.48,-1.5,-.52,0,0)]
                triangles = [(0,1,2),(0,2,3),(2,1,0),(3,2,0)]
            else:
                verts = [(-.5,-.5,-.5,0,0),(.5,.5,-.5,1,0),
                         (.5,.5,.5,1,1),(-.5,-.5,.5,0,1)]
                triangles = [(0,1,2),(0,2,3),(2,1,0),(3,2,0)]
            meshes[name] = [[v for tri in triangles for i in tri for v in verts[i]]]
            base.update(dt='mesh',mesh=name)
            if banner:
                # A wooden crossbar grips the cloth. Two iron straps climb
                # to y=.72 and turn back into the beam/roof above (y>=.5).
                # The SVG's centered viewBox leaves its visible cloth edge
                # at y=.27; extend the straps to .24 for a slight overlap.
                rod = box_mesh(-.65,.43,-.59,.65,.56,-.45)
                brackets = []
                for x in (-.32,.32):
                    brackets += box_mesh(x-.045,.24,-.61,x+.045,.72,-.43)
                    brackets += box_mesh(x-.045,.63,-.61,x+.045,.72,.10)
                meshes[name].extend([rod,brackets])
                base['tex'] = [ti, types_by_name['default:wood']['tex'][0],
                               types_by_name['grug_materials:steel_block']['tex'][0]]
        types_by_name[name] = base
    payload = {'scenes':scenes,'art':art,'types':[types_by_name[n] for n in names],
               'textures':textures.images,'meshes':meshes}
    V.write_page(str(args.out),str(HERE/'page.html'),'Grudgelands · Mining camps',payload,True)
    print(f'{args.out}: {len(scenes)} pairs, {len(names)} types; no missing textures or meshes')

if __name__ == '__main__': main()

#!/usr/bin/env python3
"""Build three castle studies with the existing template readers and viewer.

Tools only. No server, fixtures, runtime registration or writes outside this lane.
"""
import argparse
import base64
from collections import deque
import importlib.util
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import light

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VIEWER = ROOT / 'tools/building_templates/viewer'
sys.path[:0] = [str(VIEWER), str(ROOT/'tools/building_templates/editor')]
import build_viewer as V
import build_gallery as G
import templates as T
import tplfile
spec = importlib.util.spec_from_file_location('gate', ROOT/'tools/building_templates/check.py')
GATE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(GATE)
RACES = ('dwarf', 'human', 'elf', 'orc', 'undead', 'troll')
TOWNS = dict(zip(RACES, ('dur_brannoc', 'highcourt', 'lethariel', 'gor_drazhak', 'nhal_veyr', 'kezamba')))
OLD = dict(zip(RACES, ('dur_brannoc_kings_hall', 'highcourt_kings_hall', 'lethariel_kings_hall',
                      'gor_drazhak_warlord_hall', 'nhal_veyr_mausoleum', 'kezamba_kings_hall')))
FORMS = {
 'crownward': {'name': 'Crownward', 'letter': 'A', 'peak': 33,
  'rationale': 'Four towers hold a long, rising hall. A low gate gives way to a vaulted chamber and a high rear crown framing the throne. The layered silhouette reads as a royal castle from several streets.',
  'tradeoff': 'Recommended: the strongest balance of fortress, ceremonial approach and a clear, spacious battle floor. The rear towers are solid architectural turrets, not extra playable storeys.'},
 'high_seat': {'name': 'High Seat', 'letter': 'B', 'peak': 38,
  'rationale': 'One monumental keep rises in three setbacks above a low enclosing wall. A deep front portal compresses the approach before a tall, bright hall opens beneath the central lantern.',
  'tradeoff': 'The most dominant skyline and the tallest interior. Its broad stepped mass is more severe; the upper tiers are a roof lantern, not additional rooms.'},
 'gate_crown': {'name': 'Gate Crown', 'letter': 'C', 'peak': 34,
  'rationale': 'Two tall gate towers frame a low entrance bridge. Beyond them, a broad hall spreads beneath a long ridge and ends at a raised rear crown. The skyline announces the entrance before the throne.',
  'tradeoff': 'The most dramatic arrival. More of the visible mass sits at the front, so the throne relies on its rear screen and overhead light to reclaim attention.'},
}
DRESS = {
 'dwarf': 'Dur Brannoc: stone-block piers, slate roofs and brown/red cloth. Later: restrained carvers’ reliefs and metal clan seals on the outer buttresses.',
 'human': 'Highcourt: marble, slate and red/white cloth. Later: The Accord’s hart standards and carved civic shields above the foyer.',
 'elf': 'Lethariel: marble, pale sandstone and green/white cloth. Later: serpentine inlays and leaf reliefs at the window heads, without changing the castle form.',
 'orc': 'Gor Drazhak: adobe, red sandstone, acacia and red/brown cloth. Later: The Throng’s boar standards and iron bands on the gate piers.',
 'undead': 'Nhal Veyr: obsidian, dungeon stone, gravewood and black/grey cloth. Later: incised memorial panels and silver funerary emblems.',
 'troll': 'Kezamba: basalt, junglewood and green cloth with straw edging. Later: woven valances, carved masks and rope bindings high on the piers; the form stays the same.',
}
# Preserve the existing socket order, faces, ids, roles and idle tags.
SOCKETS = [
 ('king', 22,5,27,2,'king',''),
 ('throne_guard_west',19,5,27,2,'guard_post',''),
 ('throne_guard_east',25,5,27,2,'guard_post',''),
 ('door_guard_west',18,3,4,0,'guard_post',''),
 ('door_guard_east',26,3,4,0,'guard_post',''),
 ('hall_waypoint',22,3,6,0,'waypoint',''),
 ('hall_idle_west',7,3,17,1,'idle',' tags=[bench]'),
 ('hall_idle_east',37,3,17,3,'idle',' tags=[bench]'),
 ('hall_idle_service',7,3,23,3,'idle',' tags=[door]'),
]
ORNAMENTS = ('iron','steel','silversteel','embersteel','abyssal_steel')


def role(name, facing=None):
    return 'role '+name+(' channel=roof' if name.startswith('roof_') else '')+(f' o=facedir:{facing}' if facing is not None else '')


def node(name, facing=None):
    return 'node '+name+(f' o=facedir:{facing}' if facing is not None else '')


class Castle:
    def __init__(self):
        self.cells = {}
    def put(self,x,y,z,e):
        assert 0<=x<=44 and 0<=z<=34 and 0<=y<=38, (x,y,z)
        self.cells[x,y,z]=e
    def fill(self,x0,y0,z0,x1,y1,z1,e):
        for y in range(y0,y1+1):
            for z in range(z0,z1+1):
                for x in range(x0,x1+1): self.put(x,y,z,e)
    def ring(self,x0,z0,x1,z1,y0,y1,e):
        self.fill(x0,y0,z0,x1,y1,z0,e); self.fill(x0,y0,z1,x1,y1,z1,e)
        self.fill(x0,y0,z0,x0,y1,z1,e); self.fill(x1,y0,z0,x1,y1,z1,e)
    def battlement(self,x0,z0,x1,z1,y):
        self.ring(x0,z0,x1,z1,y,y,role('castle_wall'))
        for x in range(x0,x1+1):
            for z in range(z0,z1+1):
                if (x in (x0,x1) or z in (z0,z1)) and (x+z)%3!=1:
                    self.put(x,y+1,z,role('signature'))
    def tower(self,x0,z0,x1,z1,top,start=3):
        self.ring(x0,z0,x1,z1,start,top-3,role('signature'))
        for y in (9,17,top-4):
            if start<=y<top-2: self.ring(x0,z0,x1,z1,y,y,role('castle_wall'))
        self.fill(x0,top-2,z0,x1,top-2,z1,role('castle_paving'))
        self.battlement(x0,z0,x1,z1,top-1)
        cx=(x0+x1)//2
        for y in range(max(start+2,top-10),top-6):
            self.put(cx,y,z0,role('castle_slit',0))
    def roof(self,x0,z0,x1,z1,eave):
        # Stepped pitched vault: underside is open; the roof has no hidden floor.
        half=(x1-x0)//2
        for x in (x0,x1): self.fill(x,17,z0,x,eave-1,z1,role('signature'))
        for x in range(x0,x1+1):
            rise=min(x-x0,x1-x)//2
            y=eave+rise
            self.fill(x,y,z0,x,y,z1,role('roof_slab',20))
            if (x-x0)%2==0 and x<(x0+x1)//2:
                self.fill(x,y,z0,x,y,z1,role('roof_stair',1))
            elif (x1-x)%2==0 and x>(x0+x1)//2:
                self.fill(x,y,z0,x,y,z1,role('roof_stair',3))
            self.fill(x,17,z0,x,y-1,z0,role('signature'))
            self.fill(x,17,z1,x,y-1,z1,role('signature'))
        self.fill((x0+x1)//2,eave+half//2+1,z0,(x0+x1)//2,eave+half//2+1,z1,role('roof_ridge'))
    def portal(self,z):
        # Seven open lanes. This is an arch, with no non-closing door leaves.
        self.fill(19,3,z,25,8,z,'.')
        for x in (18,26): self.fill(x,3,z,x,8,z,role('signature'))
        self.fill(19,9,z,25,9,z,role('signature'))
        self.fill(20,10,z,24,10,z,role('castle_wall'))
    def throne(self):
        # Full-width shallow steps, then a flat dais with two side approaches.
        self.fill(15,3,25,29,3,31,role('castle_paving'))
        self.fill(15,4,26,29,4,31,role('castle_paving'))
        self.fill(15,3,25,29,3,25,role('signature_stair',0))
        self.fill(15,4,26,29,4,26,role('signature_stair',0))
        # A freestanding, bronze-framed chair, not masonry against the wall.
        # Raise the deep seat above the approach eye line. Its back is inset cloth;
        # the open gaps under the arms make the seat/back/arm silhouette explicit.
        bronze=node('grug_materials:bronze_block')
        cap=node('grug_materials:slab_bronze_block')
        self.fill(19,5,28,25,5,30,bronze)
        self.fill(20,6,28,24,6,29,role('rug_accent'))
        self.fill(19,6,30,25,12,30,bronze)
        self.fill(20,7,30,24,11,30,role('rug_accent'))
        for x in (19,25):
            self.fill(x,6,28,x,8,28,bronze)
            self.fill(x,8,29,x,8,29,bronze)
            self.fill(x,9,28,x,9,29,cap)
            self.put(x,13,30,cap)
        for x,metal in zip(range(20,25),ORNAMENTS):
            self.put(x,12,30,node('grug_guild:ornamented_'+metal))
            self.put(x,13,30,cap)
        self.fill(21,13,30,23,13,30,bronze)
        self.put(22,14,30,cap)
        for x in (18,26):
            self.fill(x,5,30,x,9,30,role('castle_wall'))
            self.put(x,10,30,'role light_beacon else=LAMP')
        # No node at the king or either guard's feet/head. The chair is behind them.


def composition(form):
    c=Castle()
    c.fill(0,0,0,44,2,34,role('foundation'))
    c.fill(2,2,2,42,2,32,role('castle_paving'))
    c.fill(19,1,0,25,2,1,'.')
    c.fill(19,1,1,25,1,1,role('castle_paving'))
    # A recessed woven runner never adds a collision step.
    c.fill(19,2,2,25,2,24,role('rug'))
    c.fill(20,2,2,24,2,24,role('rug_accent'))
    c.fill(19,1,1,25,1,1,role('signature_stair',0))
    c.fill(19,2,2,25,2,2,role('signature_stair',0))
    for z in (10,23): c.fill(19,2,z,25,2,z,role('signature'))
    c.ring(0,0,44,34,3,6,role('castle_wall'))
    c.ring(1,1,43,33,3,5,role('castle_wall'))
    c.battlement(0,0,44,34,7)
    # The reserved 35 x 23 hall, with its own one-node wall band.
    c.ring(4,8,40,32,3,16,role('signature'))
    for y in (3,11,16): c.ring(4,8,40,32,y,y,role('castle_wall'))
    # Windows and engaged outer buttresses; none occupies the battle floor.
    for z in (12,18,24,29):
        for x in (4,40):
            c.fill(x,7,z-1,x,10,z+1,node('default:glass'))
            c.fill(x,12,z-1,x,14,z+1,node('default:glass'))
        for x in (2,42): c.fill(x,3,z-2,x,17,z-2,role('signature'))
    # Clerestory behind the crown, five tall lights.
    for x in (10,16,22,28,34): c.fill(x,8,32,x,14,32,node('default:glass'))
    c.fill(17,7,32,27,15,32,node('default:glass'))
    for x in (18,22,26): c.fill(x,7,32,x,15,32,role('window_frame'))
    if form=='crownward':
        for x in (0,36): c.tower(x,0,x+8,7,25)
        for x in (0,40): c.tower(x,30,x+4,34,33)
        c.roof(4,8,40,32,18)
        c.tower(16,0,28,6,18)
        c.fill(17,3,1,27,8,6,'.')
    elif form=='high_seat':
        for x in (0,37): c.tower(x,0,x+7,7,17)
        c.ring(4,8,40,32,17,23,role('signature'))
        for x in (4,40):
            for z in (12,18,24,29): c.fill(x,18,z-1,x,21,z+1,node('default:glass'))
        # Continuous roof transition rings; no upper playable floors.
        c.fill(4,24,8,40,24,32,role('roof_ridge'))
        c.fill(10,24,12,34,24,29,'.')
        c.ring(9,11,35,30,24,30,role('signature'))
        for z in (11,30):
            for x in (13,18,23,28,32): c.fill(x,26,z,x,28,z,node('default:glass'))
        c.fill(9,31,11,35,31,30,role('roof_ridge'))
        c.fill(17,31,16,27,31,25,'.')
        c.ring(16,15,28,26,31,35,role('signature'))
        for x in range(18,27,2): c.fill(x,32,15,x,34,15,node('default:glass'))
        c.fill(16,36,15,28,36,26,role('roof_ridge'))
        c.battlement(16,15,28,26,37)
        c.tower(16,0,28,6,20)
        c.fill(17,3,1,27,8,6,'.')
    elif form=='gate_crown':
        for x in (6,30): c.tower(x,0,x+8,7,34)
        c.fill(15,12,0,29,12,7,role('castle_paving'))
        c.battlement(15,0,29,7,13)
        c.roof(4,8,40,32,17)
        # Rear crown is a narrow vertical screen, supported by the rear wall.
        c.ring(13,31,31,34,17,25,role('signature'))
        c.fill(13,26,31,31,26,34,role('roof_ridge'))
        c.battlement(13,31,31,34,27)
        for x in (17,22,27): c.fill(x,19,31,x,23,31,node('default:glass'))
    else: raise ValueError(form)
    # Enclosed foyer ceiling and side service pockets. Lower than the throne room.
    c.fill(2,10,2,42,10,7,role('ceiling'))
    for z in (0,1,8): c.portal(z)
    for x in (4,40): c.fill(x,3,19,x,6,21,'.')
    for x in (6,38):
        for z in (14,20): c.put(x,3,z,role('seat',3 if x==6 else 1))
    # Static placed lamps, with supports. No flame, timer or construction callback.
    for x in (5,39):
        for z in (11,17,23,29):
            c.put(x,6,z,role('signature_slab',20))
            c.put(x,7,z,'role light_beacon else=LAMP')
    for x in (17,27):
        c.fill(x,3,3,x,5,3,role('signature'))
        c.put(x,6,3,'role light_beacon else=LAMP')
    # High cross-beams carry lamps over the carpet without floor pillars.
    for z in (13,21):
        c.fill(4,12,z,40,12,z,role('beam'))
        for x in (13,22,31): c.put(x,11,z,'role light_beacon else=LAMP')
    for z in (17,26):
        c.fill(4,9,z,40,9,z,role('beam'))
        for x in (7,12,17,22,27,32,37): c.put(x,8,z,'role light_beacon else=LAMP')
    c.throne()
    # The rear light brackets stop beside the throne's sightline. The seventh
    # rear light is flush with the dais under the king, not across the chair.
    c.fill(18,9,26,26,9,26,'.')
    c.put(22,8,26,'.')
    c.put(22,4,27,'role light_beacon else=LAMP')
    return c


def template(form,race):
    c=composition(form)
    m=tplfile.Model(); m.name='castle_'+race; m.cell=1
    peak=FORMS[form]['peak']
    m.origin,m.size,m.pivot=(0,0,0),(45,peak+1,35),(45,35)
    m.races=[race]
    m.head=[f'# Round 70 {form}; generated by tools/r70_castle/build.py.', 'name '+m.name,
            'pivot 45 35','origin 0 0 0',f'size 45 {peak+1} 35','cell 1',
            f'meta extent=[0,0,44,34] peak={peak} top={peak}','races '+race]
    entries=sorted((set(c.cells.values())-{'.'})|{node('grug_materials:emberglass_lamp')}); assert len(entries)<=len(tplfile.ALPHABET)
    keys={e:tplfile.ALPHABET[i] for i,e in enumerate(entries)}
    m.legend=[[keys[e],e.replace('else=LAMP','else='+keys[node('grug_materials:emberglass_lamp')])] for e in entries]
    m.layers=[[''.join(keys.get(c.cells.get((x,y,z)),'.') for x in range(45))
               for z in range(35)] for y in range(peak+1)]
    m.points=[['doors',22,1,0,'face=2 id=approach'],['doors',22,3,8,'face=2 id=hall_arch'],
              ['doors',4,3,20,'face=3 id=service_west'],['doors',40,3,20,'face=1 id=service_east'],
              ['inside',22,3,12,'id=hall'],['room_corner',5,2,9,f'top={23 if form=="high_seat" else 16} closed=true id=hall'],
              ['room_corner',39,2,31,'']]
    m.points += [['sockets',x,y,z,f'face={f} id={key} role={r}{tags}'] for key,x,y,z,f,r,tags in SOCKETS]
    return tplfile.dump(m)


def write(path,data,check):
    data=data.encode() if isinstance(data,str) else data
    if check: assert path.exists() and path.read_bytes()==data, 'stale: '+str(path.relative_to(ROOT))
    else:
        path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)


def standing(cells,registry,p):
    x,y,z=p
    def passable(q):
        n=cells.get(q,('air',0))[0]
        return n=='air' or n.startswith('doors:door_') or n=='doors:hidden' or not registry[n].get('walkable',True)
    n=cells.get((x,y-1,z),('air',0))[0]
    return passable(p) and passable((x,y+1,z)) and n!='air' and registry[n].get('walkable',True)


def validate(text,path,palettes,registry):
    GATE.parse_template(text,str(path),path.stem)
    t=T.parse_template(str(path),text)
    palette_roles,palette_nodes=GATE.editor_palette(ROOT)
    pending={'grug_guild:ornamented_'+m for m in ORNAMENTS}
    for entry in t.legend.values():
        assert ((entry['kind']=='role' and entry['name'] in palette_roles) or
                (entry['kind']=='node' and entry['name'] in palette_nodes|pending)), entry
    assert t.pivot==(45,35) and t.origin==(0,0,0) and t.size[0::2]==(45,35)
    cells,bad=T.resolved_cells(t,T.resolve(t,palettes,capital_binding(palettes,t.races[0])),palettes)
    assert not bad,bad
    assert T.UNCHANGED not in t.cells.values()
    for (x,y,z),(n,p2) in cells.items():
        assert n in registry or n=='air',n
        assert 0<=x<=44 and 0<=z<=34 and 0<=y<=38
        if n=='air': continue
        assert not n.startswith('doors:'), 'open arches must have no door leaves'
        assert registry[n].get('liquidtype','none')=='none'
        assert not any(s in n for s in ('chest','furnace','fire:','water','lava','torch','candle','lantern'))
        assert not registry[n].get('groups',{}).get('falling_node')
    actual=[(dict(p['attrs'])['id'],p['x'],p['y'],p['z'],p['face'],dict(p['attrs'])['role'])
            for p in t.points if p['group']=='sockets']
    assert actual==[s[:6] for s in SOCKETS],actual
    old=T.parse_template(str(ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'/(OLD[t.races[0]]+'.tpl')))
    old_points=[(p['group'],p['face'],p['attrs']) for p in old.points if p['group']=='sockets']
    new_points=[(p['group'],p['face'],p['attrs']) for p in t.points if p['group']=='sockets']
    assert old_points==new_points, 'socket identity/order/face/role/tags changed'
    assert 'node air' not in text, 'force-air cells must use the reserved dot'
    for z,y,xs in ((1,1,range(19,26)),(2,2,range(19,26)),
                   (25,3,range(15,30)),(26,4,range(15,30))):
        for x in xs:
            n,p2=cells[x,y,z]
            assert p2==0 and registry[n].get('groups',{}).get('stair')
            assert not any(s in n for s in ('wall','fence','gate')), n
    for x in (4,40):
        assert any(p['group']=='doors' and (p['x'],p['y'],p['z'])==(x,3,20) for p in t.points)
    assert all(cells[x,y,8][0]=='air' for x in range(19,26) for y in range(3,9))
    start=(22,1,0); assert standing(cells,registry,start)
    seen={start}; queue=deque([start])
    while queue:
        x,y,z=queue.popleft()
        for nx,nz in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
            if not (0<=nx<=44 and 0<=nz<=34): continue
            for ny in (y,y+1,y-1):
                q=(nx,ny,nz)
                if q in seen or not 1<=ny<=38: continue
                # Ascending requires head clearance over the current cell too.
                if ny>y and cells.get((x,y+2,z),('air',0))[0]!='air': continue
                if standing(cells,registry,q): seen.add(q); queue.append(q)
    for _,x,y,z,*_ in SOCKETS:
        assert (x,y,z) in seen,('unreachable socket',path,x,y,z)
        assert cells[x,y,z][0]=='air' and cells[x,y+1,z][0]=='air'
    # Unique reachable columns on hall floor or dais only, not furniture/roofs.
    def floor_feet(x,z):
        if 15<=x<=29 and 25<=z<=31: return 4 if z==25 else 5
        return 3
    hall={(x,z) for x,y,z in seen if 5<=x<=39 and 9<=z<=31 and y==floor_feet(x,z)}
    assert len(hall)>684,(path,len(hall))
    assert all((x,3,z) in seen for x in range(8,37) for z in range(10,25)), 'battle rectangle'
    bank=light.propagate(cells,registry)
    lighting=light.measure(bank,[(x,floor_feet(x,z)+1,z) for x,z in sorted(hall)],(22,6,27))
    return t,cells,{'hall_gross':805,'hall_reachable':len(hall),'night_light':lighting,'clear_battle_rectangle':'29 x 15 = 435',
                    'reachable_total_columns':len({(x,z) for x,y,z in seen if y== (z+1 if 19<=x<=25 and z<=1 else floor_feet(x,z))}),
                    'peak':t.meta['peak'],'sockets':actual}


def capital_profile(race):
    base=ROOT/'mods/MAPGEN/grug_mapgen/building_templates'
    lay=T.parse_layout(str(base/'layouts'/(TOWNS[race]+'.roster')))
    rec=next(r for r in lay.uses if r['template']==OLD[race])
    main=lay.palettes[rec.get('main') or 'town'][1]
    roof=lay.palettes[rec['channels']['roof']][1] if 'roof' in rec['channels'] else main
    return {'main':main,'roof':roof}


def capital_binding(palettes,race):
    return {channel:palettes.bind(race,roles) for channel,roles in capital_profile(race).items()}


def lua_check(lua,outputs):
    with tempfile.TemporaryDirectory(prefix='r70-castle-') as tmp:
        base=Path(tmp); (base/'templates').mkdir()
        for form in FORMS:
            names=[]
            for race in RACES:
                name='templates/castle_'+race+'.tpl'; names.append(name)
                (base/name).write_text(outputs[form,race])
            p=subprocess.run([lua,str(ROOT/'tools/building_templates/loader_check.lua'),str(ROOT),tmp],
                             input='\n'.join(names)+'\n',text=True,capture_output=True,check=True,cwd=ROOT)
            assert not p.stdout.strip(),p.stdout
            script='''
local wp="mods/MAPGEN/grug_mapgen/wp13"
local parts=dofile(wp.."/parts.lua")
local loader=dofile(wp.."/templates.lua")(wp)
local pal=dofile(wp.."/palette.lua")
for path in io.read("*a"):gmatch("%S+") do
 local f=assert(io.open(path,"rb")); local text=f:read("*a"); f:close()
 local t=loader.parse_template(text,path,path:match("([^/]+)%.tpl$"))
 local profiles=PROFILES
 local profile=profiles[t.races[1]]
 local p=pal.new(t.races[1],profile.main)
 local roof=pal.new(t.races[1],profile.roof)
 local part=loader.part(t,"castle",t.races[1],function(channel) return channel=="roof" and roof or p end)
 for turn=0,3 do
  local b=parts.buffer(); local moved=parts.stamp(b,part,0,0,0,turn)
  local cells,n=b:cells(); assert(n==45*35*(part.peak+1), tostring(n).." count vs "..tostring(part.peak))
  for _,c in ipairs(cells) do
   assert(c.x>=0 and c.z>=0 and c.x<(turn%2==0 and 45 or 35) and c.z<(turn%2==0 and 35 or 45))
   assert(c.y>=0 and c.y<=38)
  end
  for i,s in ipairs(moved.sockets) do
   local a=part.points.sockets[i]; local x,z=parts.rotate_footprint(a.x,a.z,45,35,turn)
   assert(s.x==x and s.z==z and s.face==(a.face+turn)%4)
   assert(b:at(s.x,s.y,s.z).name=="air" and b:at(s.x,s.y+1,s.z).name=="air")
   assert(b:at(s.x,s.y-1,s.z).name~="air")
  end
 end
end
'''
            def lua_table(d):
                return '{'+','.join('['+json.dumps(k)+']='+ (lua_table(v) if isinstance(v,dict) else json.dumps(v)) for k,v in sorted(d.items()))+'}'
            script=script.replace('PROFILES',lua_table({r:capital_profile(r) for r in RACES}))
            p=subprocess.run([lua,'-e',script],cwd=ROOT,input='\n'.join(str(base/n) for n in names),
                             text=True,capture_output=True)
            assert p.returncode==0,p.stderr


def current(palettes,race):
    base=ROOT/'mods/MAPGEN/grug_mapgen/building_templates'
    t=T.parse_template(str(base/'templates'/(OLD[race]+'.tpl')))
    lay=T.parse_layout(str(base/'layouts'/(TOWNS[race]+'.roster')))
    rec=next(r for r in lay.uses if r['template']==OLD[race])
    binding=G.placement_binding(palettes,lay,rec)
    cells,bad=T.resolved_cells(t,T.resolve(t,palettes,binding),palettes); assert not bad,bad
    # Centred on the same entry axis. Keep baseline scale, local y and approach.
    dx=22-t.pivot[0]//2
    points={dict(p['attrs']).get('id',p['group']):[p['x']+dx,p['y'],p['z']]
            for p in t.points if p['group']=='sockets'}
    return {(x+dx,y,z):v for (x,y,z),v in cells.items()},points


def render_digest(payload,key):
    content={'scene':payload['scenes'][key],'types':payload['types'],'light_nodes':payload['light_nodes'],
             'textures':payload['textures'],'meshes':payload['meshes']}
    h=hashlib.sha256(json.dumps(content,sort_keys=True,separators=(',',':')).encode())
    for p in (HERE/'render.py',HERE/'light.py',HERE/'geometry.js',VIEWER/'renderer.js',HERE.parent/'r69_camp_art/render.py'):
        h.update(p.read_bytes())
    return h.hexdigest()


def page(scenes,registry,aliases,check,metrics):
    tex=V.Textures(); meshes={}; names=[]; indices={}; packed={}
    # Export the picked ART faces without copying or changing their originals.
    original=tex.bank.texture
    def texture(name):
        if name.startswith('grug_guild_ornamented_'):
            from PIL import Image
            return Image.open(ROOT/'tools/r70_art/candidates/final'/name).convert('RGBA')
        return original(name)
    tex.bank.texture=texture
    for key,(cells,points) in scenes.items():
        packed[key]=V.pack_cells({'points':points},[(*p,*v) for p,v in sorted(cells.items()) if v[0]!='air' and registry[v[0]].get('drawtype')!='airlike'],indices,names)
    types,report=V.build_types(names,registry,aliases,tex,meshes)
    assert not report['skipped'] and not report['missing_mesh'] and not tex.missing,(report,tex.missing)
    payload={'scenes':packed,'types':types,'textures':tex.images,'meshes':meshes,'forms':FORMS,
             'races':RACES,'dress':DRESS,'metrics':metrics,
             'light_nodes':{n:{'paramtype':registry[n].get('paramtype','none'),
                                'light_source':registry[n].get('light_source',0)} for n in ['air']+names}}
    html=V.inline_renderer((HERE/'page.in.html').read_text())
    html=html.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;')
    html=html.replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
    html=html.replace('__THREE__',(ROOT/'tools/r54_armor/vendor/three.min.js').read_text().replace('</','<\\/'))
    html=html.replace('__ORBIT__',(ROOT/'tools/r69_camp_art/orbit.js').read_text())
    html=html.replace('__LICENSE__',(ROOT/'tools/r69_camp_art/THREE-LICENSE.txt').read_text())
    html=html.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
    if check:
        for form in FORMS:
            receipt=json.loads((HERE/'renders'/f'{form}_human.receipt.json').read_text())
            assert receipt['inputs']==render_digest(payload,'human/'+form), 'stale render inputs: '+form
            for filename,digest in receipt['files'].items():
                assert hashlib.sha256((HERE/'renders'/filename).read_bytes()).hexdigest()==digest, filename
    stills=''
    for form in FORMS:
        stills+='<h3>'+FORMS[form]['name']+'</h3><div class="stills">'
        for view,label in (('hall','Hall · bright study (not daylight)'),
                           ('night','Hall · night light model, same camera'),
                           ('entrance','Open entrance arch · viewed from the foyer'),
                           ('throne','Throne · seat, arms and back'),
                           ('approach','Approach · bright study'),('top','Roof removed · bright study')):
            p=HERE/'renders'/f'{form}_human_{view}.png'
            if p.exists():
                from PIL import Image
                compressed=io.BytesIO()
                Image.open(p).save(compressed,format='WEBP',quality=90,method=6)
                stills+='<figure><img loading="lazy" alt="'+form+' '+view+'" src="data:image/webp;base64,'+base64.b64encode(compressed.getvalue()).decode()+'"><figcaption>'+label+'</figcaption></figure>'
        stills+='</div>'
    html=html.replace('__STILLS__',stills)
    assert len(html.encode())<=15_000_000, 'page exceeds 15 MB'
    write(HERE/'page.html',html,check)
    return len(names)


def main():
    ap=argparse.ArgumentParser(description=__doc__); ap.add_argument('--check',action='store_true')
    ap.add_argument('--templates-only',action='store_true'); a=ap.parse_args()
    reg=json.loads(Path(V.NODES_JSON).read_text())
    additions={f'grug_guild:ornamented_{m}':{'drawtype':'normal','walkable':True,
        'tiles':[f'grug_guild_ornamented_{m}.png'],'groups':{},'paramtype2':'none','light_source':0}
        for m in ORNAMENTS}
    reg['nodes'].update(additions)
    write(HERE/'palettes.json',json.dumps({r:capital_profile(r) for r in RACES},indent=2)+'\n',a.check)
    write(HERE/'preview_nodes.json',json.dumps(additions,indent=2)+'\n',a.check)
    lua=V.find_lua(); palettes=T.Palettes(G.load_palettes(lua,set(reg['nodes'])|set(reg.get('aliases',{}))))
    scenes={}; outputs={}; metrics={}; inventory={}
    for form in FORMS:
        metrics[form]={}; inventory[form]={}
        for race in RACES:
            text=template(form,race); path=HERE/'candidates'/form/f'castle_{race}.tpl'
            t,cells,stats=validate(text,path,palettes,reg['nodes'])
            outputs[form,race]=text; write(path,text,a.check)
            scenes[race+'/'+form]=(cells,{s[0]:list(s[1:4]) for s in SOCKETS})
            metrics[form][race]=stats; inventory[form][race]=sorted({n for n,p in cells.values() if n!='air'})
    lua_check(lua,outputs)
    write(HERE/'metrics.json',json.dumps(metrics,indent=2)+'\n',a.check)
    write(HERE/'nodes.json',json.dumps(inventory,indent=2)+'\n',a.check)
    if not a.templates_only:
        for race in RACES: scenes[race+'/current']=current(palettes,race)
        count=page(scenes,reg['nodes'],reg.get('aliases',{}),a.check,metrics)
        print(f'24 viewer scenes; {count} node types; no missing media.')
    print('18 templates: both Python parsers and native LuaJIT reader PASS; 72 native rotated stamps PASS.')
    print('Bounds, socket air/head/support, open arches, approach flood fill and 435-node clear battle rectangle PASS.')
    for form in FORMS: print(form, {r:metrics[form][r]['hall_reachable'] for r in RACES})
    print('Byte reproduction PASS.' if a.check else 'Outputs written.')

if __name__=='__main__': main()

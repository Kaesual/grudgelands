#!/usr/bin/env python3
"""Build a self-contained review page from the real exports and design reservations."""
import copy
import hashlib
import html
import json
import math
import re
from collections import defaultdict
import geometry as G
from pathlib import Path
from proposals import CAPITALS, TOWNS, NAMES, FACTION, P, FURNITURE
from claims import Claims, ROOT, WP, W40, MOBS, HOME, QUEST

HERE = Path(__file__).resolve().parent
BP = json.loads((HERE/'data/blueprints.json').read_text())
BIND = json.loads((HERE/'data/bindings.json').read_text())
SEEDS = ['12345', '3684797457838814663', '17713522922938657774']
PLANS = {seed:{v:json.loads((HERE/f'data/{seed}-{v}.json').read_text())['capitals']
              for v in ['today','proposed']} for seed in SEEDS}
LAKES = json.loads((HERE/'data/lakes.json').read_text())
LAKE_PLANS = {seed:{v:json.loads((HERE/f'data/{seed}-{v}.json').read_text())['capitals']
                   for v in ['lake0','lake_shift']} for seed in SEEDS}
for seed in SEEDS:
    for key in LAKES:
        PLANS[seed]['proposed'][key] = LAKE_PLANS[seed]['lake_shift'][key]
FLEET = json.loads((HERE/'data/checker-fleet.json').read_text())
LAKE_FLEET = json.loads((HERE/'data/checker-lake-fleet.json').read_text())
SHORE_CHECK = json.loads((HERE/'data/shore-check.json').read_text())
C = Claims()
E = html.escape

def fmt(v):
    return str(round(v,2)).rstrip('0').rstrip('.') if isinstance(v,float) else str(v)

def point(x,z):
    return f'({fmt(x)}, {fmt(z)})'

def ref(c):
    return f'<a class="ref" href="#claim-{c["id"]}">{c["id"]}</a>'

def cost(c):
    return f'<li>{E(c["text"])} {ref(c)}</li>'

def box(b):
    return [b['x'], b['z'], b['x']+b['w']-1, b['z']+b['d']-1]

def area(r):
    return (r[2]-r[0]+1)*(r[3]-r[1]+1)

def overlap(a,b):
    return max(a[0],b[0])<=min(a[2],b[2]) and max(a[1],b[1])<=min(a[3],b[3])

def buildings(key, proposed=False):
    out=[]
    for n,b in enumerate(BP[key]['buildings'],1):
        q=copy.deepcopy(b); q['number']=n
        q['removed']=b['id'] in P[key].get('remove',[])+P[key].get('replace',[])
        if proposed and q['removed']: continue
        dx,dz=P[key]['shifts'].get(b['id'],[0,0]) if proposed else [0,0]
        q['x']+=dx; q['z']+=dz
        for c in ['x1','x2']:q['cells_box'][c]+=dx
        for c in ['z1','z2']:q['cells_box'][c]+=dz
        q['changed']=dx!=0 or dz!=0
        out.append(q)
    return out

# Determine template-owned sockets from the exported stamp, including unnamed
# standing markers which templates.sockets gives a role in the composition.
def sockets(key, proposed=False):
    rows=copy.deepcopy(BP[key]['landmarks']['sockets'])
    if key in TOWNS:
        # Read the projection adapter's literal trainer table; these three
        # sockets are added after the composition, not part of its blueprint.
        src=(ROOT/W40/'r7_settlement.lua').read_text()
        block=src.split('local START_TRAINERS = {',1)[1].split('\n}',1)[0]
        match=re.search(r'\b'+key+r' = \{x = (-?\d+), y = (-?\d+), z = (-?\d+)',block)
        x,y,z=map(int,match.groups()); cz=13 if z>0 else -13
        rows += [dict(id='trainer_cooking',role='trainer',x=x,y=y,z=z),
            dict(id='quest_cook',role='quest',x=2,y=1,z=cz),
            dict(id='cook_oven',role='public_station',x=4,y=1,z=cz)]
    if not proposed:return rows
    p=P[key]
    owner={s['id']:b['id'] for b in BP[key]['buildings'] for s in b['sockets']}
    for s in rows:
        sid=s['id']
        s['origin']='template' if sid in owner else 'Lua / adapter'
        # Generated gate-watch loops and booth aliases are not template points.
        if sid not in owner:
            for b in BP[key]['buildings']:
                if sid.startswith(b['id']+'_watch_') or sid.startswith(b['id']+'_booth_'):
                    owner[sid]=b['id']
            if sid not in owner and s['role'] not in ['guard_patrol','waypoint','vendor'] and sid not in ['trainer_cooking','quest_cook','cook_oven']:
                near=sorted((G.distance(box(b),s['x'],s['z']),b['id']) for b in BP[key]['buildings'])
                if near and near[0][0]<=2: owner[sid]=near[0][1]
        s['owner']=owner.get(sid)
        s['affected_by']=', '.join(sorted({b['id'] for pr in [False,True] for b in buildings(key,pr)
            if (b['id'] in p['shifts'] or b['id'] in p.get('replace',[])+p.get('remove',[]))
            and G.contains(box(b),s['x'],s['z'],2)} | ({'castle'} if key in CAPITALS and G.contains(p['castle'],s['x'],s['z'],2) else set())))
    for s in rows:
        sid=s['id']
        shift=p.get('sockets',{}).get(sid, p['shifts'].get(owner.get(sid),[0,0]))
        s['x']+=shift[0];s['z']+=shift[1]
        if sid=='travel_waypoint' and p.get('waypoint'):s['x'],s['z']=p['waypoint']
        if key in CAPITALS:
            if sid in p['castle_sockets']: s['x'],s['z']=p['castle_sockets'][sid]
            if sid in p['watch_ids']:s['x'],s['z']=p['watch'][p['watch_ids'].index(sid)]
        elif s['role']=='guard_patrol':
            s['x'],s['z']=p['watch'][s['order']-1]
        if sid in p.get('socket_positions',{}): s['x'],s['z']=p['socket_positions'][sid]
        nearby=set(filter(None,s['affected_by'].split(', ')))
        for pr in [False,True]:
            for b in buildings(key,pr):
                if (b['id'] in p['shifts'] or b['id'] in p.get('replace',[])+p.get('remove',[])) and G.contains(box(b),s['x'],s['z'],2):nearby.add(b['id'])
        if key in CAPITALS and G.contains(p['castle'],s['x'],s['z'],2):nearby.add('castle')
        s['affected_by']=', '.join(sorted(nearby))
    return rows


def clearance_errors(key, check_sockets=True):
    p=P[key];bs=buildings(key,True);errors=[]
    old_boxes=[[b['cells_box'][n] for n in ['x1','z1','x2','z2']] for b in buildings(key)]
    # Full street widths, not just the centreline. Only actual gate tunnels
    # may cross a template footprint; their cell clearance is checked too.
    for road in G.road_boxes(p['roads']):
        for b in bs:
            if not overlap(road,box(b)):continue
            if b['id'] not in ['gate_north','gate_south','gate_east','gate_west']:
                errors.append((key,'road crosses footprint',road,b['id']));continue
            r=box(b)
            for x in range(max(road[0],r[0]),min(road[2],r[2])+1):
                for z in range(max(road[1],r[1]),min(road[3],r[3])+1):
                    if any(G.blocked(key,b,x,y,z,p['shifts']) for y in [1,2]):
                        errors.append((key,'road crosses gate wall',b['id'],x,z))
        if key in CAPITALS and overlap(road,p['castle']):
            # A road ends immediately outside the future great door.
            errors.append((key,'road crosses castle',road))
    for b in bs:
        dx,dz=p['shifts'].get(b['id'],(0,0))
        for d in b['doors']:
            ux,uz=[(0,-1),(-1,0),(0,1),(1,0)][d['face']]
            for step in [1,2]:
                x,z=d['x']+dx+step*ux,d['z']+dz+step*uz
                if key in CAPITALS and G.contains(p['castle'],x,z):
                    errors.append((key,'door opens into castle wall',b['id'],x,z))
                for other in bs:
                    if other['id']==b['id']:continue
                    if any(G.blocked(key,other,x,y,z,p['shifts']) for y in [d['y'],d['y']+1]):
                        errors.append((key,'door opens into wall',b['id'],other['id'],x,z))
    for s in sockets(key,True) if check_sockets else []:
        x,y,z=s['x'],s['y'],s['z']
        # Existing loose fences/walls/furniture remain evidence outside the
        # re-authored template boxes, castle, old perimeter and cleared pad.
        # This catches the Hearthpine fence, absent from template geometry.
        if (s['id'] not in p.get('castle_sockets',{}) and s['id'] not in ['travel_waypoint','cook_oven']
                and not any(G.contains(b,x,z) for b in old_boxes)
                and not (key in CAPITALS and max(abs(x),abs(z))>=47)):
            for yy in [y,y+1]:
                node=G.composition(key).get((x,yy,z))
                if G.solid(node):errors.append((key,'socket in retained composition wall/fence',s['id'],x,yy,z,node))
        if key in CAPITALS and G.contains(p['castle'],x,z):
            if s['id'] not in p['castle_sockets']:
                errors.append((key,'socket in castle footprint',s['id'],x,z))
            else:
                # Two-node outer walls; room wall ring and service/foyer budget.
                r=p['castle'];inside=[r[0]+2,r[1]+2,r[2]-2,r[3]-2]
                rm=p['room'];ring=[rm[0]-1,rm[1]-1,rm[2]+1,rm[3]+1]
                if not G.contains(inside,x,z) or (G.contains(ring,x,z) and not G.contains(rm,x,z)):
                    errors.append((key,'socket in reserved castle wall',s['id'],x,z))
        for b in bs:
            if G.contains(box(b),x,z) and s['owner']!=b['id']:
                errors.append((key,'foreign socket in footprint',s['id'],b['id'],x,z))
            for yy in [y,y+1]:
                node=G.blocked(key,b,x,yy,z,p['shifts'])
                if node:errors.append((key,'socket in wall/fence',s['id'],b['id'],x,yy,z,node))
    return errors


def validate_geometry():
    count=0
    for key in NAMES:
        bs=buildings(key,True)
        boxes=[(b['id'],[b['cells_box'][k] for k in ['x1','z1','x2','z2']]) for b in bs]
        if key in CAPITALS:boxes.append(('castle',P[key]['castle']))
        for i,(name,b) in enumerate(boxes):
            limit=57 if key in CAPITALS else 63
            assert max(abs(n) for n in b)<=limit,(key,name,'envelope',b)
            for name2,c in boxes[i+1:]:
                assert not overlap(b,c),(key,name,name2,'written-column envelopes overlap')
        if P[key].get('waypoint'):
            x,z=P[key]['waypoint'];pad=[x-6,z-6,x+6,z+6]
            for name,b in boxes:assert not overlap(pad,b),(key,name,'13x13 arrival reservation')
        if P[key].get('waypoint'):
            x,z=P[key]['waypoint']
            for socket in sockets(key,True):
                if socket['role'] != 'waypoint':
                    assert not(abs(socket['x']-x)<=6 and abs(socket['z']-z)<=6),(key,socket['id'],'socket in clear arrival reservation')
        if key in CAPITALS:
            b=P[key]['castle']; assert sorted([b[2]-b[0]+1,b[3]-b[1]+1])==[35,45]
            assert area(P[key]['room'])==805
            # Sample the *existing* fitted terrain under the proposed castle
            # on all three seeds. New earthwork is explicitly not simulated.
            for seed in SEEDS:
                t=PLANS[seed]['today'][key]['terrain']
                for z in range(math.ceil(b[1]/2)*2,b[3]+1,2):
                    for x in range(math.ceil(b[0]/2)*2,b[2]+1,2):
                        h,w=t[(z+76)//2][(x+76)//2]
                        assert w is False or w<=h,(key,seed,x,z,'castle reaches sampled water')
        else:
            assert BP[key]['landmarks']['spawn']=={'x':0,'y':1,'z':0}
        errors=clearance_errors(key)
        assert not errors, errors[:8]
        count+=1
    return count

# Every implementation-cost assertion is registered here or in place_claims.
shared=[]
shared.append(C.add('The enlarged core consumes district land: CORE/CORE_GATE/CORE_KEEP change from 48/49/52 to 56/57/60. The buildable mask also excludes wet, bank-adjacent and rough samples. The nominal civic square gains 3,328 square nodes (+36.1%); the outer 512-node reservation is unchanged.',
    [(W40+'capital_planner.lua','CORE = 48'),(W40+'capital_planner.lua','BUILD[k] = not WET[k]'),('tools/r70_design/export.lua','opt.CORE, opt.CORE_GATE')]))
shared.append(C.add('The original MASK-ONLY study, retained in the other four city views, runs real world assembly and capital planning with only those three options enlarged. Existing civic_width=96, terrain, buildings and the old core_landing detector remain in that study; the two lake amendments separately measure civic_width=112 and shifted water. Final earthwork, landing heights, collision-free generated streets and performance are not verified.',
    [('tools/r70_design/export.lua','Sensitivity experiment ONLY'),(W40+'r7_capitals.lua','along >= 46 and along <= 49'),(W40+'source/simple_map.lua','id="capital_dwarf"')], 'Measured scope / limitations'))
shared.append(C.add('Implementation of radius 56 must coordinate civic_width 96→112; CORE/CORE_GATE/CORE_KEEP 48/49/52→56/57/60; RADIUS=49 in all six Lua compositions; precinct_ring.RADIUS=48; the ±47 corner towers in Dur Brannoc, Gor Drazhak and Nhal Veyr; city_green.CORE_HALF=49; the flat-core/collar and road fitting; BOUNDS.capital_core ±49→±57 and the separate ±49 plot-collar exclusion; r7_capitals core_landing 46…49 and built=96*96. The river keep-out formula grows from 99.9 to 111.2 nodes and can change rivers world-wide. The accepted radius 56 joins Round 70’s map reset; the river consequence needs one full seed-fleet run within that work, with no additional reset. The outer capital reservation stays 512 nodes.',
    [(W40+'source/simple_map.lua','id="capital_dwarf"'),(W40+'height.lua','profile.civic_width)'),(W40+'height.lua','local reach = fitting.profile.civic_width / 2 + 1'),(W40+'r7_settlement.lua','capital_core ='),(W40+'r7_settlement.lua','math.abs(lx) > 49'),(WP+'precinct_ring.lua','M.RADIUS = 48'),(WP+'city_green.lua','CORE_HALF = 49'),(W40+'r7_capitals.lua','local built = 96 * 96'),(W40+'height.lua','r = profiles[a.template_id].civic_width / 2'),(W40+'terrain_data.lua','capital_keepout_margin = 32'),*[(WP+k+'.lua','local RADIUS = 49') for k in CAPITALS],*[(WP+k+'.lua','for _, corner in ipairs({{-47') for k in ['dur_brannoc','gor_drazhak','nhal_veyr']]]))
shared.append(C.add('All six cities have four planned OUTER gates. Core entries differ: four authored gatehouses in Dur Brannoc, Highcourt, Gor Drazhak and Nhal Veyr; three in Lethariel; no such gatehouse kit in Kezamba. Extend the dry core entries by eight nodes, rebuild boundary rings and connect each avenue; do not add a northern gatehouse across Lethariel’s lake.',
    [(W40+'capital_planner.lua','for c = 1, 4 do'),(WP+'gate_watch.lua','open core has no gatehouse'),(WP+'lethariel.lua','id = "gate_east"'),(WP+'precinct_ring.lua','function')]))
shared.append(C.add('The avenue starts at CORE_GATE+1; when its core landing is wet it searches for a dry shore start. core_landing still scans along 46…49 and y −1…1. New dry thresholds and Kezamba’s deck extensions need a corresponding landing scan and height check; the lake edge must not silently acquire a land bridge.',
    [(W40+'capital_planner.lua','local a0 = {dx * (P.CORE_GATE + 1)'),(W40+'capital_planner.lua','if not landed then'),(W40+'r7_capitals.lua','along >= 46 and along <= 49')]))
shared.append(C.add('Patrol routes cache each fixed leg by settlement and body class in memory. Longer capital patrol legs may follow generated streets (street reach 24, rise 6); failed legs can remain unavailable until restart. Re-author waypoint groups/order and test doors, stairs and clear walking corridors; there is no saved route-cache migration to design.',
    [(MOBS+'routes.lua','Kept in memory only'),(MOBS+'routes.lua','STREET_REACH = 24'),(MOBS+'routes.lua','until the server restarts'),(MOBS+'routes.lua','function grug_mobs.route_settlement')]))
shared.append(C.add('Exactly two royal guards is deliberate, since commit 494a6073: only throne_guard_west/east bind to the king. door_guard_west/east remain ordinary guard posts at the great door; all four positions are shown. There are no unbound spare guards. Later documentation cleanup must correct world.md:497–498, world_zones.md:1869/1876/1886–1888/1898, biomes_mobs.md:849 and the comment in start_npcs.lua:921. These stale four-guard and five-NPC statements do not authorize changing the encounter.',
    [(MOBS+'start_npcs.lua','local ROYAL_GUARD_SOCKET'),('tools/r70_design/data/royal-binding.txt','door guard still resolves as a royal guard'),('docs/design/world.md','rules are implemented by the six'),('docs/design/world_zones.md','king has exactly four'),('docs/design/world_zones.md','five-NPC royal encounter'),('docs/design/biomes_mobs.md','four fixed L60 elite royal guards'),(MOBS+'start_npcs.lua',"A royal group: a capital's king and his four")], 'Verified code / stale documentation'))
shared.append(C.add('The 60-node rule is a 3D reward-participation distance to the king’s death position (with a separate 60-second death grace). king_def instead sets a 30-node chase leash; aggro measures it from the chase anchor. Royal guards have no independent leash and use a 5-node follow distance. The new room is an 805-node² floor reservation, not a combat boundary: the king can chase out of it and the chase anchor can move between pulls. No existing mechanism keeps combat in the room; this proposal changes neither leash nor encounter rules.',
    [(MOBS+'bosses.lua','local LEDGER_RANGE = 60'),(MOBS+'bosses.lua','near = dx * dx + dy * dy'),(MOBS+'bosses.lua','_grug_tier = "elite", _grug_leash_range = 30'),(MOBS+'aggro.lua','vector.distance(pos, anchor) > range'),(MOBS+'bosses.lua','local ROYAL_FOLLOW_DISTANCE = 5'),(MOBS+'bosses.lua','guard._grug_no_leash = true')]))
shared.append(C.add('Required capital plots are the eight service plots, the inn and miners_guild. Moving a plot moves its rotated sockets with it; ids keep the plot_id/socket_id prefix. The service annexes list the concrete bindings to preserve, including guild leader/exchange/clerk/sorter/porter, innkeeper, Housing Steward, Crownbinder and Decor Merchant.',
    [(W40+'r7_capitals.lua','local function required_of'),(W40+'r7_settlement.lua','prefix = descriptor.plot_id'),(WP+'capital_services.lua','M.PLOTS ='),(WP+'capital_services.lua','M.GUILD_HALL ='),(HOME+'locations.lua','id="dur_brannoc"'),('docs/design/settlements.md','## Housing Stewards'),('docs/design/settlements.md','## Crownbinders')]))
shared.append(C.add('Start towns keep the same 128-node fitting/protection pad, rounded 12-node protected band and authored ±63 building limits. The proposed centres use existing town land; spawn stays at (0,1,0), and the main_street gate axis stays. Foundations, stairs, doorsteps, vegetation and ground patterns displaced by the moves must be re-authored inside that envelope.',
    [(W40+'source/simple_map.lua','id="start",shape="flat"'),(W40+'source/simple_map.lua','id="hard_start_town_v1"'),(W40+'r7_settlement.lua','start = {min'),(WP+'hearthpine.lua','spawn = {x = 0'),('docs/design/settlements.md','The road reaches a start')]))
shared.append(C.add('Each proposed start waystone keeps the reach-3 pad, inside a new 13×13 clear arrival reservation. Move travel_waypoint, the stone, its paving and mailbox together. Mail is at (+2,+1) from the stone; arrival tries the authored side or +x first, then the other sides. Keep all four neighbouring standing cells and the lane connection open.',
    [(WP+'dressing.lua','function M.waypoint_pad'),(WP+'dressing.lua','function M.waystone'),(HOME+'waypoints.lua','local function arrival_at'),('docs/design/settlements.md','(+2, +1)')]))
shared.append(C.add('Quest identities bind to settlement/socket, and registry validation requires role=quest. Every start has both hall_quest and the projection adapter’s quest_cook/cook_oven; the latter are at (2,±13)/(4,±13), not in the town .layout. Preserve them, the Quartermaster id, home socket and spare standing spots when re-authoring the centre.',
    [(QUEST+'registry.lua','local key = def.settlement'),(QUEST+'registry.lua','sockets[key].role == "quest"'),(W40+'r7_settlement.lua','local cook_z='),(QUEST+'npcs.lua','"r20_dwarf_start_cook"'),(HOME+'locations.lua','id="hearthpine"')]))
shared.append(C.add('Socket y, facing and free feet/head/floor must be checked on the final built geometry. The runtime tries the socket and up to two cells above it before postponing placement; a 2D reservation does not prove standing or walking clearance. No Luanti server or desktop/web runtime was run here.',
    [(MOBS+'start_npcs.lua','local function standing'),('docs/design/settlements.md','An NPC is placed only where it can stand')], 'Read / runtime unverified'))
shared.append(C.add('This lane is tools-only and changes no world state. Building the selected cores or towns changes map generation and belongs to Round 70’s map reset. No migration step, online rewrite or production deployment is supplied by this design.',
    [('docs/planning/round70-plan.md','classification **map reset**'),('docs/planning/round70-plan.md','Builds nothing.')], 'Classification'))


def place_claims(key):
    p=P[key];v=BP[key]
    source=WP+key+'.lua'
    refs=[(source,'local PLOTS =')] if key in CAPITALS else [(source,'local TOWN ='),(source,'local SOCKETS =')]
    costs=[]
    moved=[b['id'] for b in buildings(key,True) if b['changed']]
    if key in CAPITALS:
        costs.append(C.add(f'{NAMES[key]}: reserve the shared castle at {point(*p["castle"][:2])}–{point(*p["castle"][2:])}, facing {p["facing"]}. Relocate {len(moved)} core templates; '+
            ('retire '+', '.join(p['remove'])+' as freestanding strips; ' if p['remove'] else '')+
            f'the full export also contains {len([s for s in sockets(key,True) if s["origin"]=="Lua / adapter"])} Lua-authored or generated sockets outside template ownership, among {len(sockets(key))} exported points, in a {len((ROOT/source).read_text().splitlines())}-line composition. Those points, their furniture and duplicate coordinates all need review; this is not merely a template translation. The schedule includes every exported socket. Template envelopes, door exits, full road widths and socket collisions against exported template cells are checked; final 3D routes remain unverified.',refs+[('tools/r70_design/proposals.py',f"P['{key}']"),('tools/r70_design/build.py','def validate_geometry')], 'Proposal / 2D checked'))
        gate='four inner gatehouses' if key not in ['lethariel','kezamba'] else ('three inner gatehouses and the open lake shore' if key=='lethariel' else 'south/west ground posts, the east ground threshold and north boardwalk threshold')
        costs.append(C.add(f'{NAMES[key]}: move the {gate} with the expanded boundary. The four outer gates and their avenues are replanned per seed; their measured positions are in the city views. Update core_landing, boundary masking and the road/collar exclusions together.',refs+[(W40+'r7_capitals.lua','local function core_landing'),(W40+'capital_planner.lua','local a0 = {dx * (P.CORE_GATE + 1)')]))
        costs.append(C.add(f'{NAMES[key]}: re-author {", ".join(p["watch_ids"])} in {key}_watch; the proposed points are in the socket schedule. '+
            ('Regenerate each moved gate_watch rectangle and tower post from its stamped gate.' if key not in ['lethariel','kezamba'] else
             'Keep Lethariel’s quay patrol dry and regenerate the three gate watches.' if key=='lethariel' else
             'Keep the quay walk on dry ground and the north deck crossing; rebuild the now-dry east avenue as ground paving.')+
            ' Rebuild the in-memory route legs after restart and test them on the finished geometry.',[(source,'local WATCH ='),(source,'id = "watch_south_west"'),(MOBS+'routes.lua','STREET_REACH = 24'),(WP+'gate_watch.lua','function M.apply')]))
        old=next(s for s in v['landmarks']['sockets'] if s['id']=='king')
        hall=next(b for b in v['buildings'] if b['id'] in p['replace'])
        hall_file='mods/MAPGEN/grug_mapgen/building_templates/templates/'+hall['template']+'.tpl'
        costs.append(C.add(f'{NAMES[key]}: king moves from {point(old["x"],old["z"])} to {point(*p["throne"])}; throne_guard_west/east follow to posts three nodes away. Preserve their ids and royal binding, then author their y and facing from the actual throne floor. The 60-node reward sphere follows the death position; it is not a core boundary. Keep door_guard_west/east as ordinary guards at the great door, and carry hall_idle_west/east/service and hall_waypoint into the new floor allocation; add no guard slots.',[(source,'id = "'+hall['id']+'"'),(hall_file,'id=king role=king'),(hall_file,'id=throne_guard_west'),(MOBS+'start_npcs.lua','local ROYAL_GUARD_SOCKET'),(MOBS+'bosses.lua','near = dx * dx + dy * dy')]))
        qs=next(s for s in v['landmarks']['sockets'] if s['role']=='quest')
        wp=next(s for s in sockets(key,True) if s['id']=='travel_waypoint')
        costs.append(C.add(f'{NAMES[key]}: preserve {qs["id"]} at its named public building and {('keep vendor_race/vendor_general at their unchanged positions' if key=='lethariel' else 'carry vendor_race/vendor_general with their stalls where moved')}. travel_waypoint is proposed at {point(wp["x"],wp["z"])}; keep its mailbox and arrival cells with it. All ten required district plots and the concrete service sockets listed below must survive replanning; no service is transferred to the castle.',refs+[(WP+'capital_services.lua',key+' ='),(W40+'r7_capitals.lua','local function required_of'),(QUEST+'npcs.lua',f'"{key}"')]))
        if key=='lethariel':
            text='Lethariel: shift every crown-lake capsule point 14 nodes north (+z), leaving anchor_009 at (1800,−1500). Recut MERE through ±57 from that same water function; MERE_FIRST and CAUSEWAY_FROM become 36, and the quay head moves from z=18…21 to 32…35. Narrow that head from x=−6…6 to −3…3 so it clears the relocated colonnades. Reserve a three-node marble quay outside the one-node shore margin. There is no north crossing today: pad() leaves the band empty, core_landing fails, and the planner starts the avenue on dry shore (about (−28,80) today, (−30,86) in lake0, (−42,62) shifted, on seed 12345). Remove the drawn crossing from this proposal. The existing quay loop steps inward into SHORE_MARGIN and dry() retains only its first column; write the proposed three-column band outward instead. A crossing is a separate open option, requiring a new deck and landing scan: at least 34 nodes west from the axis to shore on z=57, or 131 north along the axis. These are geometric lower bounds; the build, bank connection and walkability are unmeasured. Correct the stale CAUSEWAY comments (also water_authored.lua) and settlements.md:400 in the later implementation lane. Move mere_shrine 14 north with its sockets; the generated mere precinct retains its pin to the same lake id, but that is not a fixed shore distance. The checker reports its plot centres moving from 19–32 to 32–44 nodes off shore on two seeds. A separate exact wet-column spot check here spans 18–35 → 38–46 on seeds 12345 and 3684797457838814663; both show the inland drift. The pin is not tuned in this proposal, and accepting that cost is part of the question. Six templates move (three gates, two colonnades, the shrine), versus three gates and two retired colonnades in the accepted plan: this saves both colonnades, not relocation work. Keep the accepted western castle: the small shift does not make a 45×35 northern castle with its court fit without moving the public quarter.'
            r=[(WP+'lethariel.lua','local MERE_FIRST = 22'),(WP+'lethariel.lua','local CAUSEWAY_FROM = 22'),(WP+'lethariel.lua','local QUAY_WIDTH = 3'),(W40+'water_authored.lua','id = "lethariel_crown_lake"'),(W40+'r7_capital_blueprint.lua','lake = "lethariel_crown_lake"'),(WP+'lethariel.lua','local function pad'),(W40+'capital_planner.lua','a0 = best'),(W40+'r7_capitals.lua','local function core_landing'),('tools/r70_design/data/design-check-pass4.md','Mere precinct drifts inland'),('tools/r70_design/data/shore-check.json','method'),('tools/r70_design/proposals.py','lake_shift=[0,14]')]
        elif key=='kezamba':
            text='Kezamba: shift every cenote capsule point 18 nodes north (+z), leaving anchor_012 at (1800,1500). Recut kezamba_lagoon from the same water function, including its pad/shore helpers; the ravine stays empty. Five buildings move instead of six: stable (−32,+48), granary (−35,+20), lane_house (0,+10), gate_house_south (−36,−13), moot_house (0,+15). Both western houses and the original waystone plaza stay. The moot house still straddles land and water with all four western landing columns dry; its written envelope ends at z=55. The north deck follows the new shore (first wet columns in its five-wide band at z=30, centre at 32); the east avenue is now dry inside the core. This loses the east boardwalk: two avenues over water become one, changing settlements.md’s two-avenue character rule. The current composition has 627 non-template deck, rail and pier cells over water (263 on the east avenue). Recut quay, boardwalk piers, rails and landings; replace the east deck with ground paving. A four-node shift would keep both avenues over water and return 300 dry columns, 1,036 fewer than the proposed 18; 101 written columns of the proposed stable would still be wet (131 with its buffer), so that alternative needs a new stable site and a revised layout. At about 12 north or more the east avenue is entirely dry. Fish and quay sockets follow the shore; cenote_fish_3 instead moves to (−8,41), facing east into water at (−7,41) at reach one. The previous (−10,44) looked through cenote_fish_2 at (−9,44); nearby water alone did not certify a clear view. The new row clears both the other anglers and the moved moot house’s rope/pier cells. The accepted southern castle still fits best: the recovered northern strip is too shallow for it, and a western move would displace the market and shrine quarter.'
            r=[(WP+'kezamba.lua','local mask ='),(WP+'kezamba.lua','local rows = plot.land_rows'),(WP+'kezamba.lua','socket("cenote_fish_"'),(WP+'kezamba_lagoon.lua','function M.shore'),(WP+'kezamba.lua','The third angler stood'),('docs/design/settlements.md','great avenues leave the crossing'),('tools/r70_design/data/design-check-pass4.md','627 deck'),(W40+'water_authored.lua','id = "kezamba_cenote"'),('tools/r70_design/proposals.py','lake_shift=[0,18]')]
        else:
            text=f'{NAMES[key]}: carry the larger core onto the fitted civic ground, keeping its own boundary character. civic_width, authorized core bounds and road/plot-collar exclusions must change together; the three-seed comparison does not include this earthwork.'
            r=refs+[(W40+'source/simple_map.lua','civic_width=96'),(W40+'r7_settlement.lua','capital_core =')]
        costs.append(C.add(text,r))
        if key in LAKES:
            costs.append(C.add(f'{NAMES[key]}: moving the lake chain is the smaller implementation change. Its anchor supplies water HEIGHT; capsule points supply horizontal position. Moving the anchor would also move the city fitting, core origin, road endpoints and district frame; moving only the core would require a second origin throughout those consumers. Keep the anchor, level_offset=−2, radii, depth and lake id; translate the points only, with the calm/warp and bank-suppression square centred on the unchanged anchor and expanded from half=47 to 57. This relocates the complete lake rather than shrinking or filling it. The authored lake bounds also move the POI exclusion box read by placement.lua:365; keeping the city anchor fixed does not keep that exclusion fixed. Regenerate the core mask, dry-edge wall ends and water-side furniture together. Kezamba’s old mask generator was deleted (kezamba_lagoon.lua:4): a new generator against the current water function is needed, including shore/pad helpers; recutting is not an available one-command job. The real planner reads fitted_values_at and the shifted lake indicator for shore distance, district pinning and outer wall runs; rerun its bridges and quays too. The proposal changes settlements.md’s city-specific lake/core paragraphs, dry-edge boundary table and old 96×96 wording in the implementation lane. The current study runs the real planner against shifted water and civic_width=112, but retains today’s core cells and 46…49 landing scan: final writer seams, piers, bank geometry, route reachability and full-fleet feasibility are unbuilt.',
                [(W40+'water_authored.lua','local sdf = chain(spec.points)'),(W40+'water_authored.lua','spec.keep'),(W40+'r7_capitals.lua','sample = session.fitted_values_at'),(W40+'r7_capitals.lua','shore_distance = function'),(W40+'capital_planner.lua','M.shore_flags'),(W40+'placement.lua','for _, row in ipairs(authored or {})'),(WP+'kezamba_lagoon.lua','GENERATED by'),(W40+'r7_capitals.lua','along >= 46 and along <= 49'),('docs/design/settlements.md','a marble quay'),('docs/design/settlements.md','half over the lake'),('tools/r70_design/lake_variant.lua','spec.keep.half = 57')], 'Read / proposed coordinated change, real planner sensitivity'))

    else:
        costs.append(C.add(f'{NAMES[key]}: move {", ".join(moved)} with their stairs, doors and attached standing points. Keep the authored ±63 bounds, the same 128-node pad and 12-node protected band. Spawn remains (0,1,0); the main_street and gate axis remain. Move intersecting furniture and vegetation to the margins before paving the enlarged centre.',refs+[(f'mods/MAPGEN/grug_mapgen/building_templates/layouts/{key}.layout','place '),(W40+'source/simple_map.lua','id="hard_start_town_v1"')]))
        old=next(s for s in v['landmarks']['sockets'] if s['id']=='travel_waypoint')
        wp=p['waypoint']
        costs.append(C.add(f'{NAMES[key]}: travel_waypoint moves {point(old["x"],old["z"])} → {point(*wp)}. Its reach-3 pad gains a 13×13 clear reservation; the mailbox moves to {point(wp[0]+2,wp[1]+1)}. Preserve all four arrival sides and leave the Quartermaster at its current vendor socket.',[(source,'local WAYPOINT ='),(source,'id = "travel_waypoint"'),(WP+'dressing.lua','function M.waystone'),(HOME+'waypoints.lua','local function arrival_at')]))
        qs=next(s for s in sockets(key,True) if s['id']=='hall_quest')
        home=re.search(r'\{id="'+key+r'"[^\n]*socket="([^"]+)"',(ROOT/HOME/'locations.lua').read_text()).group(1)
        costs.append(C.add(f'{NAMES[key]}: {("hall_quest stays at (−28,26); the workyard is kept south of its doorstep, with two clear rows before the hall" if key=="hearthpine" else "hall_quest follows its host to "+point(qs["x"],qs["z"]))}; quest_cook and cook_oven keep their projection-adapter positions. Keep the inn/home binding {home}, both quest giver ids and their quest data. Recheck the oven, home arrival and all idle_spare_* points; listed displaced spares move to the clearing’s edge.',refs+[(W40+'r7_settlement.lua','rows[#rows+1]={id="quest_cook"'),(HOME+'locations.lua',f'id="{key}"'),(QUEST+'npcs.lua',f'"{key}", "hall_quest"')]))
        watches=[s['id'] for s in sockets(key) if s['role']=='guard_patrol']
        costs.append(C.add(f'{NAMES[key]}: retain the five-point patrol group and order ({", ".join(watches)}), re-author its centre points as listed, and rebuild its cached legs after restart. Keep gate guards at their existing posts. Door routes, furniture clearance and the moved building approaches need desktop/web walking checks; no runtime path is certified by the lines on this page.',refs+[(MOBS+'routes.lua','Kept in memory only'),(MOBS+'start_npcs.lua','local function standing')]))
        costs.append(C.add(FURNITURE[key],refs+[(WP+key+'.lua','local SOCKETS ='),('tools/r70_design/proposals.py','FURNITURE =')], 'Proposal / source geometry read'))
    return costs

# SVG coordinates map +z upward; every main map has the same 160-node window.
def rect(r,css,extra=''):
    x1,z1,x2,z2=r
    return f'<rect x="{x1-.5}" y="{-z2-.5}" width="{x2-x1+1}" height="{z2-z1+1}" class="{css}" {extra}/>'

def label(x,z,s,css='map-label'):
    return f'<text x="{x}" y="{-z}" class="{css}">{E(str(s))}</text>'

def poly(points,css,extra=''):
    return f'<polyline points="'+ ' '.join(f'{x},{-z}' for x,z in points)+f'" class="{css}" {extra}/>'

def raster_paths(key):
    v=BP[key]; xs=v['bounds']['min']['x']; zs=v['bounds']['min']['z'];paths=defaultdict(list)
    for iz,row in enumerate(v['raster']):
        n=0
        while n<len(row):
            end=n+1
            while end<len(row) and row[end][0]==row[n][0]:end+=1
            kind=row[n][0]
            if kind not in ['empty','ground']:
                x,z=xs+n,zs+iz
                paths[kind].append(f'M{x-.5},{-z-.5}h{end-n}v1h-{end-n}z')
            n=end
    return ''.join(f'<path d="{"".join(path)}" class="raster {kind}"/>' for kind,path in paths.items())

def retained_land(key):
    """Preserve exported surroundings; suppress all areas touched by this proposal."""
    p=P[key];v=BP[key];blocked=[]
    for proposed in [False,True]:
        for b in buildings(key,proposed):
            a=b['cells_box'];blocked.append([a['x1']-1,a['z1']-1,a['x2']+1,a['z2']+1])
    blocked.append(p.get('centre',p.get('court')))
    if key in CAPITALS:blocked.append(p['castle'])
    if p.get('waypoint'):
        x,z=p['waypoint'];blocked.append([x-7,z-7,x+7,z+7])
    def changed(x,z):
        if any(a<=x<=c and b<=z<=d for a,b,c,d in blocked):return True
        for flat,width in p['roads']:
            pts=list(zip(flat[::2],flat[1::2]))
            for (ax,az),(bx,bz) in zip(pts,pts[1:]):
                if min(ax,bx)-width/2-1<=x<=max(ax,bx)+width/2+1 and min(az,bz)-width/2-1<=z<=max(az,bz)+width/2+1:return True
        return False
    paths=defaultdict(list);xs=v['bounds']['min']['x'];zs=v['bounds']['min']['z']
    for iz,row in enumerate(v['raster']):
        z=zs+iz
        for ix,item in enumerate(row):
            x=xs+ix;kind=item[0]
            if kind in ['ground','empty','water'] or (key in CAPITALS and kind!='tree'):continue
            if changed(x,z):continue
            if key in LAKES and z>=14:continue # Shore furniture/planting is re-authored.
            paths[kind].append(f'M{x-.5},{-z-.5}h1v1h-1z')
    return ''.join(f'<path d="{"".join(path)}" class="raster retained {kind}"/>' for kind,path in paths.items())


def water_paths(key, proposed=False):
    if key not in ['lethariel','kezamba']:return ''
    if proposed:
        return '<path class="water-land" d="'+''.join(f'M{x-.5},{-z-.5}h1v1h-1z' for x,z in LAKES[key]['shifted'])+'"/>'
    t=PLANS['12345']['today'][key]['terrain'];path=[]
    for iz,row in enumerate(t):
        for ix,(h,w) in enumerate(row):
            if w is not False and w>h:
                x,z=-76+ix*2,-76+iz*2;path.append(f'M{x-1},{-z-1}h2v2h-2z')
    return '<path class="water-land" d="'+''.join(path)+'"/>'

def lake_overlay(key):
    wet=set(map(tuple,LAKES[key]['shifted'])); paving=set()
    if key=='lethariel':
        for z in range(36,58):
            row=[x for x,zz in wet if zz==z]
            for edge,side in [(min(row)-2,-1),(max(row)+2,1)]:
                for step in range(3):
                    x=edge+side*step
                    if abs(x)<=57 and abs(x)>3:paving.add((x,z))
        paving.update((x,z) for x in range(-3,4) for z in range(32,36))
    else:
        for z in range(-57,58):
            for x in range(-57,58):
                if (x,z) not in wet and any((x+dx,z+dz) in wet for dx in [-1,0,1] for dz in [-1,0,1]):
                    if not any(G.contains(box(b),x,z) for b in buildings(key,True)):paving.add((x,z))
    return '<path class="court" d="'+''.join(f'M{x-.5},{-z-.5}h1v1h-1z' for x,z in sorted(paving))+'"/>'

def lake_metrics(key):
    wet0=set(map(tuple,LAKES[key]['unshifted']));wet=set(map(tuple,LAKES[key]['shifted']))
    within=lambda cells,r:sum(max(abs(x),abs(z))<=r for x,z in cells)
    chosen=P[key]['lake_shift'][1]
    focus=['colonnade_west','colonnade_east'] if key=='lethariel' else ['stable']
    occupied=set()
    for b in buildings(key,True):
        if b['id'] in focus:
            r=b['cells_box']
            occupied.update((x,z) for x in range(r['x1'],r['x2']+1) for z in range(r['z1'],r['z2']+1))
    margin={(x+dx,z+dz) for x,z in occupied for dx in [-1,0,1] for dz in [-1,0,1]}
    candidates=[]
    for n in sorted({0,8,12,chosen-2,chosen-1,chosen,24} | ({4} if key=='kezamba' else set())):
        shifted={(x,z+n) for x,z in wet0}
        candidates.append(dict(shift=n,dry_gain=within(wet0,57)-within(shifted,57),
            wet_columns=len(occupied&shifted),wet_with_margin=len(margin&shifted)))
    north_box=[-22,10,22,44] if key=='lethariel' else [5,5,49,39]
    reserve={(x,z) for x in range(north_box[0]-1,north_box[2]+2) for z in range(north_box[1]-1,north_box[3]+2)}
    north_min=next(n for n in range(65) if not reserve&{(x,z+n) for x,z in wet0})
    collisions=[b['id'] for b in buildings(key) if b['id'] not in P[key]['replace'] and
                overlap(north_box,[b['cells_box'][n] for n in ['x1','z1','x2','z2']])]
    return dict(shift=chosen,core_columns=115*115,today_dry=99*99-within(wet0,49),
        unshifted_dry=115*115-within(wet0,57),shifted_dry=115*115-within(wet,57),
        gain=within(wet0,57)-within(wet,57),candidates=candidates,
        northern_castle_probe=dict(box=north_box,minimum_shift_with_buffer=north_min,buildings_hit=collisions))

def validate_lakes():
    for key in LAKES:
        assert LAKES[key]['baseline_mask_mismatches']==0
        wet=set(map(tuple,LAKES[key]['shifted']));m=lake_metrics(key)
        candidate=next(c for c in m['candidates'] if c['shift']==m['shift'])
        previous=next(c for c in m['candidates'] if c['shift']==m['shift']-1)
        assert candidate['wet_with_margin']==0 and previous['wet_with_margin']>0,(key,candidate,previous)
        for seed in SEEDS:
            for variant,field in [('lake0','unshifted_dry'),('lake_shift','shifted_dry')]:
                p=LAKE_PLANS[seed][variant][key]
                assert p['core']==56 and not p['missing_required']
                assert p['core_columns']-p['core_wet']==m[field],(key,seed,variant)
                assert p['castle_wet']==0
        for b in buildings(key,True):
            r=b['cells_box'];cols={(x,z) for x in range(r['x1'],r['x2']+1) for z in range(r['z1'],r['z2']+1)}
            if b['id']=='moot_house':
                assert cols&wet and cols-wet
                assert not any((x,z) in wet for x in range(b['x'],b['x']+4) for z in range(b['z'],b['z']+b['d']))
            else:assert not cols&wet,(key,b['id'],'written columns over shifted water')
        proposed_sockets=sockets(key,True)
        for s in proposed_sockets:
            fish=s['id'].startswith('cenote_fish_')
            if s['owner']=='moot_house' and not fish:continue # Its platform carries these points.
            assert (s['x'],s['z']) not in wet,(key,s['id'],'standing in shifted water')
            if fish:
                # Facing matters: nearby water behind another angler or a pier
                # is not an open fishing column. Test every step to the water.
                dx,dz=s['dir']['x'],s['dir']['z']
                for reach in range(1,4):
                    x,z=s['x']+dx*reach,s['z']+dz*reach
                    assert not any(t['id']!=s['id'] and (t['x'],t['z'])==(x,z)
                                   for t in proposed_sockets),(s['id'],'fishing ray hits socket')
                    assert not any(G.blocked(key,b,x,y,z,P[key]['shifts'])
                                   for b in buildings(key,True) for y in range(0,4)),(s['id'],'fishing ray hits template')
                    if (x,z) in wet:break
                else:raise AssertionError((s['id'],'no water ahead within three nodes'))
    return {key:lake_metrics(key) for key in LAKES}

def map_svg(key,proposed=False):
    p=P[key]; v=BP[key]; capital=key in CAPITALS
    ident=f'{key}-'+('proposal' if proposed else 'today')
    out=[f'<svg class="plan" viewBox="-80 -80 160 160" role="img" aria-labelledby="{ident}-title">',
        f'<title id="{ident}-title">{NAMES[key]} — {"proposed land reservation" if proposed else "exported current plan"}. North is +z; coordinates in nodes.</title>',
        '<defs><pattern id="grid-'+ident+'" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M10 0H0V10" class="gridline"/></pattern></defs>',
        '<rect x="-80" y="-80" width="160" height="160" class="map-ground"/>',
        f'<rect x="-80" y="-80" width="160" height="160" fill="url(#grid-{ident})"/>']
    if capital:
        out+=[rect([-56,-56,56,56],'expansion' if proposed else 'future-boundary'),rect([-48,-48,48,48],'old-boundary')]
        out+=[water_paths(key,proposed)]
    else:
        out+=['<rect x="-76" y="-76" width="152" height="152" rx="12" class="protection"/>',rect([-63,-63,63,63],'town-edge')]
    if not proposed:out += [raster_paths(key)]
    else:
        out += [retained_land(key)]
        if key in LAKES: out += [lake_overlay(key)]
        if capital:
            out += [rect(p['court'],'court')]
        else:out += [rect(p['centre'],'court garden' if key=='dawnmere' else 'court')]
        for flat,width in p['roads']:
            pts=list(zip(flat[::2],flat[1::2]));css='road'
            out += [poly(pts,css,f'style="stroke-width:{width}"')]
        if key=='kezamba':
            out += [poly([(0,30),(0,57)],'road deck','style="stroke-width:5"')]
        elif key=='lethariel':
            out += [label(0,47,'No crossing','small-label')]
    if key=='silverleaf':
        # Exact authored crescent, read from its one source.
        src=(ROOT/WP/'silverleaf.lua').read_text()
        match=re.search(r'local CRESCENT = \{x = (-?\d+), z = (-?\d+), outer = (\d+), inner = (\d+), offset = (\d+),\s*reach = (\d+)',src)
        cx,cz,outer,inner,offset,reach=map(int,match.groups())
        for dz in range(-reach,reach+1):
            for dx in range(-reach,reach+1):
                if dx*dx+dz*dz<=outer and (dx+offset)*(dx+offset)+dz*dz>inner:
                    out += [rect([cx+dx,cz+dz,cx+dx,cz+dz],'crescent')]
    if key=='dawnmere':
        wx,wz=(-10,7) if proposed else (-6,-3)
        out += [f'<circle cx="{wx}" cy="{-wz}" r="1.5" class="well"/>',label(wx,wz-3,'well','small-label')]
    # Physical building pivots are solid; written-column extents include eaves
    # and template ground, shown as faint outlines. Neither is a landmark box.
    for b in buildings(key,proposed):
        cls='building'+(' changed' if b['changed'] else '')
        if b['id'] in p.get('replace',[]):cls+=' old-royal'
        a=b['cells_box']; out += [rect([a['x1'],a['z1'],a['x2'],a['z2']],'eaves')]
        details=f'{b["number"]}. {b["id"]}: {b["w"]}×{b["d"]}, {point(b["x"],b["z"])}'
        out += [f'<g data-building="{key}:{b["id"]}" tabindex="0" role="button" aria-label="{E(details)}"><title>{E(details)}</title>',rect(box(b),cls)]
        out += [label(b['x']+(b['w']-1)/2,b['z']+(b['d']-1)/2,str(b['number']),'building-number'),'</g>']
        # Exported door points follow the same translation as their template.
        orig=next(a for a in BP[key]['buildings'] if a['id']==b['id']); dx=b['x']-orig['x']; dz=b['z']-orig['z']
        for d in b['doors']:
            out += [f'<circle cx="{d["x"]+dx}" cy="{-d["z"]-dz}" r=".9" class="door"><title>{E(b["id"])} door</title></circle>']
    if proposed and capital:
        r=p['castle'];rm=p['room'];out += [rect(r,'castle'),rect([r[0]+2,r[1]+2,r[2]-2,r[3]-2],'castle-inner'),rect([rm[0]-1,rm[1]-1,rm[2]+1,rm[3]+1],'room-wall'),rect(rm,'throne-room')]
        out += [label((r[0]+r[2])/2,r[1]+1 if p['facing']=='north' else r[3]-3,'CASTLE','castle-label')]
        rm=p['room'];out += [label((rm[0]+rm[2])/2,(rm[1]+rm[3])/2-2,'THRONE','room-label')]
        x,z=p['throne'];out += [f'<circle cx="{x}" cy="{-z}" r="60" class="reward-radius"><title>60-node reward radius if the king dies at the proposed seat; horizontal slice, not a leash.</title></circle>']
        # Entry marker only, no architecture.
        ex,ez=((r[0]+r[2])/2,r[1]) if p['facing']=='south' else (((r[0]+r[2])/2,r[3]) if p['facing']=='north' else (r[2],(r[1]+r[3])/2))
        out += [f'<circle cx="{ex}" cy="{-ez}" r="1.5" class="entry"/>',label(ex,ez+3 if p['facing']=='north' else ez-3,'entry','small-label')]
    if not capital:
        out += [f'<circle cx="0" cy="0" r="1.5" class="spawn"/><path d="M-2 0H2M0 -2V2" class="spawn-cross"/>']
        out += [label(0,-5,'spawn','small-label')]
    ss=sockets(key,proposed);wp=next(s for s in ss if s['id']=='travel_waypoint');wx,wz=wp['x'],wp['z']
    if proposed and p.get('waypoint'):
        out += [rect([wx-6,wz-6,wx+6,wz+6],'arrival-clear')]
    reach=3 if not capital else (5 if key=='lethariel' else 6)
    out += [poly([(wx,wz+reach),(wx+reach,wz),(wx,wz-reach),(wx-reach,wz),(wx,wz+reach)],'pad')]
    out += [f'<circle cx="{wx}" cy="{-wz}" r="1.4" class="waystone"><title>travel_waypoint {point(wx,wz)}</title></circle>',
        rect([wx+2,wz+1,wx+2,wz+1],'mailbox'),label(wx,wz-5,'WAYSTONE','way-label')]
    for s in ss:
        x,z=s['x'],s['z'];role=s['role'];sid=s['id']
        if role=='king':
            out += [f'<path d="M{x-1.5},{-z+1}v-2l1,1 .5,-2 .5,2 1,-1v2z" class="king"><title>king {point(x,z)}; y/facing need final throne</title></path>']
        elif role in ['quest','vendor','public_station']:
            txt='Q' if role=='quest' else ('O' if role=='public_station' else 'V')
            out += [f'<g class="service-mark"><title>{E(sid)} {point(x,z)}</title><circle cx="{x}" cy="{-z}" r="1.7" class="service {role}"/>',label(x,z-.7,txt,'socket-letter'),'</g>']
        elif role!='waypoint':
            royal=sid.startswith('throne_guard_');door_guard=sid.startswith('door_guard_')
            out += [f'<circle cx="{x}" cy="{-z}" r="{.85 if royal else 1.05 if door_guard else .65}" class="socket-dot {"royal" if royal else "door-guard" if door_guard else "optional-socket"}"><title>{E(sid)} · {role} {point(x,z)} y={s["y"]}'+(' (proposed x/z; y not designed)' if proposed else '')+'</title></circle>']
    out += [label(-72,69,'N ↑ +z','axis'), label(65,-69,'+x →','axis'),
        '<path d="M-70 67v2h20v-2M-60 67v2" class="scale"/>',label(-60,-65,'20 nodes','scale-label')]
    if key in ['lethariel','kezamba']:
        out += [label(31,61,'water −2 / dry terrace 0','water-label')]
        if proposed:
            if key=='kezamba':out += [label(7,53,'deck','small-label')]
            out += [label(31,68,'lake +'+str(p['lake_shift'][1])+' north','water-label')]
    out += ['</svg>']
    return ''.join(out)


def schedule(key):
    p=P[key];rows=[]
    for b in buildings(key):
        id=b['id']; before=point(b['x'],b['z'])
        if id in p.get('replace',[]):after='replaced by castle reservation'
        elif id in p.get('remove',[]):after='open court; no separate strip'
        else:
            dx,dz=p['shifts'].get(id,[0,0]);after=point(b['x']+dx,b['z']+dz)
        rows.append(f'<tr data-building="{key}:{id}"><td>{b["number"]}</td><td><code>{id}</code></td><td>{b["w"]}×{b["d"]}</td><td>{before}</td><td>{E(after)}</td></tr>')
    out='<details><summary>Every building · exact coordinate schedule</summary><p>Anchor of the rotated template footprint, x/z in nodes. The plan uses the exported pivot size; faint outlines include all written non-air columns. Castle reservation includes its future overhangs.</p><div class="table-scroll"><table><thead><tr><th>#</th><th>Template placement</th><th>Footprint</th><th>Today</th><th>Proposed</th></tr></thead><tbody>'+''.join(rows)+'</tbody></table></div></details>'
    before={s['id']:s for s in sockets(key)}; sr=[]
    for s in sockets(key,True):
        old=before[s['id']]; changed=old['x']!=s['x'] or old['z']!=s['z']
        note=('MOVE; ' if changed else 'retain; ')+(s['affected_by'] or 'outside moved footprints')
        if s['id'] in p.get('castle_sockets',{}):note='new castle floor; '+note
        sr.append(f'<tr data-socket="{key}:{s["id"]}"><td><code>{s["id"]}</code></td><td>{s["role"]}<br>{s["origin"]}</td><td>{point(old["x"],old["z"])}</td><td>{point(s["x"],s["z"])}</td><td>{E(note)}</td></tr>')
    out+=f'<details><summary>All {len(sr)} exported sockets · complete horizontal schedule</summary><p>Every exported point and the three start cooking points, including unchanged ones. The last column finds old/new footprints within two nodes; nothing is filtered out. Template points, gate-watch loops and booth aliases follow their hosts. Other loose points within two nodes follow the nearest host unless explicitly placed; these are proposed furniture attachments, not new runtime bindings. Retain ids and roles. Re-author y, facing and attached furniture with the final floor; no runtime route is implied.</p><div class="table-scroll"><table><thead><tr><th>Socket</th><th>Role / origin</th><th>Today</th><th>Proposed</th><th>Change / nearby footprint</th></tr></thead><tbody>'+''.join(sr)+'</tbody></table></div></details>'
    return out


def service_annex(key):
    # Exported actual district socket ids, including authored plot sockets.
    mapping=BIND['plots'][key]; relevant=set(mapping.values())|{BIND['inns'][key],'miners_guild'}
    rows=[]
    for plot in sorted(relevant):
        services=[name for name,v in mapping.items() if v==plot]
        if plot==BIND['inns'][key]:services+=['innkeeper']
        if plot==mapping['tailor']:services+=['Housing Steward']
        if plot==mapping['goldsmith']:services+=['Crownbinder']
        if plot==mapping['woodcarver']:services+=['Decor Merchant']
        if plot=='miners_guild':services+=['Miner’s Guild; Stonewright/registrar decisions belong to their lanes']
        ss=[s for s in BIND['sockets'][key] if s['plot']==plot and (s['role'] in ['trainer','public_station','riding_trainer','shipwright','quest'] or 'gate_idle' in s['id'] or 'miners_guild/' in s['id'])]
        rows.append('<tr><td>'+E(', '.join(services))+'</td><td><code>'+plot+'</code></td><td>'+ '<br>'.join('<code>'+E(s['id'])+'</code>' for s in ss)+'</td></tr>')
    return '<details><summary>Required district plots · exact service bindings</summary><div class="table-scroll"><table><thead><tr><th>Service</th><th>Required plot</th><th>Preserve these socket ids</th></tr></thead><tbody>'+''.join(rows)+'</tbody></table></div></details>'


def seed_metrics(key,seed):
    a=PLANS[seed]['today'][key];b=PLANS[seed]['proposed'][key]
    aa={x['id']:x for x in a['plots']};bb={x['id']:x for x in b['plots']}
    moved=[id for id in aa.keys()&bb.keys() if any(aa[id][n]!=bb[id][n] for n in ['x','z','y','turns'])]
    return dict(before=len(aa),after=len(bb),moved=len(moved),lost=sorted(aa.keys()-bb.keys()),gained=sorted(bb.keys()-aa.keys()),
        lost_area=a['lost_band_buildable']*4,required=b['required'],missing=b['missing_required'],
        area_before=round(a['area']),area_after=round(b['area']),
        no_route_before=(a['failures'] or {}).get('no_route','none'),no_route_after=(b['failures'] or {}).get('no_route','none'))


def seed_section(key):
    if key in LAKES:return lake_section(key)
    metrics=[seed_metrics(key,s) for s in SEEDS]
    c=C.add(f'{NAMES[key]}: the three seeds {", ".join(SEEDS)} placed all {metrics[0]["required"]} required district plots in the MASK-ONLY experiment (civic_width=96 and today’s terrain). Plot totals changed '+
        ', '.join(f'{m["before"]}→{m["after"]}' for m in metrics)+', and '+', '.join(str(m['moved']) for m in metrics)+
        ' surviving plots changed x/z, y or orientation. The removed buildable band is approximately '+str(metrics[0]['lost_area'])+
        ' square nodes on the 2-node sample grid; this is sampled eligible ground, not a sum of lost building footprints.',
        [('tools/r70_design/export.lua','out.lost_band_buildable ='),('tools/r70_design/build.py','def seed_metrics')]+[(f'tools/r70_design/data/{s}-proposed.json','"capitals"') for s in SEEDS], 'Measured / mask only, three seeds')
    rows=[];lost=[]
    for seed,m in zip(SEEDS,metrics):
        rows.append(f'<tr><td><code>{seed}</code></td><td>{m["before"]} → {m["after"]}</td><td>{m["moved"]}</td><td>{m["required"]}/{m["required"]}</td><td>{m["area_before"]:,} → {m["area_after"]:,}</td></tr>')
        lost.append(f'<li><code>{seed}</code><br>Removed from this result: '+E(', '.join(m['lost']) or 'none')+'<br>Newly placed: '+E(', '.join(m['gained']) or 'none')+f'<br>Unrouted street labels: {E(m["no_route_before"])} → {E(m["no_route_after"])}</li>')
    out=f'<div class="seed-study"><h4>What moves outside the core</h4><p>{E(c["text"])} {ref(c)}</p><label>Show seed <select class="seed-select" data-capital="{key}">'+''.join(f'<option>{s}</option>' for s in SEEDS)+'</select></label>'
    out+=f'<div class="city-pair" data-capital="{key}"><figure><figcaption>Today · whole capital</figcaption><div class="city-map today"></div></figure><figure><figcaption>Larger core mask · sensitivity only</figcaption><div class="city-map proposed"></div></figure></div>'
    out+='<p class="small">Core in gold; required plots outlined; four colours distinguish the four district roles. Outer dots are the four city gates. The outline, streets and plot rectangles are planner output. Lake colour is shown only in the core plans above.</p>'
    out+='<div class="table-scroll"><table><thead><tr><th>Seed (exact string)</th><th>Plots</th><th>Moved*</th><th>Required</th><th>City area, nodes²</th></tr></thead><tbody>'+''.join(rows)+'</tbody></table></div><p class="small">*Surviving plots whose position, height or quarter turn changes. A larger reserved core can place more plots on one seed: the whole street/district allocation changes.</p>'
    out+='<details><summary>Which plots disappear or appear · unresolved street labels</summary><ul>'+''.join(lost)+'</ul><p>These are differences between planner results, not instructions to delete any named building. A missing street label is not a new failure by itself: compare today and proposed, then check the finished routes.</p></details></div>'
    return out


def lake_section(key):
    m=lake_metrics(key)
    fleet=LAKE_FLEET['summary'][key]
    wet0=m['core_columns']-m['unshifted_dry'];wet1=m['core_columns']-m['shifted_dry']
    counts=lambda v:', '.join(str(len(LAKE_PLANS[s][v][key]['plots'])) for s in SEEDS)
    c=C.add(f'{NAMES[key]}: the shifted-water experiment gives {m["gain"]:,} additional dry columns inside the same ±57 cell boundary: {m["unshifted_dry"]:,} → {m["shifted_dry"]:,}, out of 13,225. Today’s ±49 boundary has {m["today_dry"]:,} dry columns. These are land columns, including streets and occupied land, not empty building plots. All three seeds agree with the exact authored-water mask. Real planner totals with radius 56, civic_width=112 and the calm square at half=57 are {counts("lake0")} before the shift and {counts("lake_shift")} after it, in the listed seed order; every required plot survives. Both castle boxes have zero wet columns on all three seeds. These gains depend on the unbuilt lake change; the current game has not gained land. The chosen north shift is the smallest integer shift clearing the illustrated new colonnades (Lethariel) or stable (Kezamba), their full written-column envelopes and a one-node shore buffer. It is a minimum for this layout and axis, not a global optimum over every possible rearrangement.',
        [('tools/r70_design/export.lua','out.core_wet, out.castle_wet'),('tools/r70_design/lake_variant.lua','M.shifts'),('tools/r70_design/build.py','def lake_metrics'),('tools/r70_design/data/design-check-pass4.md','Three-seed unrouted'),('tools/r70_design/data/checker-lake-fleet.json','scope'),*[(f'tools/r70_design/data/{s}-lake_shift.json','"core_wet"') for s in SEEDS]], 'Measured / shifted-water sensitivity, unbuilt core')
    c['text']+=f' The displacement is small by distance ({m["shift"]}/112 = {m["shift"]/112:.1%} of the nominal core width), but wet columns inside the same ±57 core fall {wet0:,} → {wet1:,}, a {100*(wet0-wet1)/wet0:.1f}% reduction. The complete capsule chain moves with unchanged radii and lengths; outside the calm square the existing shore warp still applies. The independent 40-seed lake0 versus lake_shift comparison is the better figure for planner sensitivity: {fleet["new_unrouted_cases"]} unrouted cases new, {fleet["gone_unrouted_cases"]} gone; plots {fleet["mean_delta"]:+g} mean ({fleet["min_delta"]:+d}…{fleet["max_delta"]:+d}).'
    c['text']+=(' The original three-seed lake comparison found Lethariel 1 new unrouted case and 1 gone, plots +0.33 mean (−1…+1).' if key=='lethariel' else ' The original three-seed lake comparison found Kezamba 1 new unrouted case and none gone, plots −0.33 mean (−2…+1).')
    c['text']+=' Cases count changed capital/seed/street labels. All required plots placed without load failure across 40 seeds; the other four capitals planned identically. These exports retain old core cells and the landing scan, so they do not certify a recut core, bank geometry or full-fleet feasibility.'
    out='<div class="seed-study"><h4>The lake amendment · measured land and planner costs</h4><p>'+E(c['text'])+' '+ref(c)+'</p>'
    out+='<div class="table-scroll"><table><thead><tr><th>Lake shift north</th><th>Dry land returned at radius 56</th><th>Wet building columns*</th><th>Wet columns including buffer*</th></tr></thead><tbody>'
    for row in m['candidates']:
        out+=f'<tr><td>{row["shift"]}'+(' · proposed' if row['shift']==m['shift'] else '')+f'</td><td>+{row["dry_gain"]:,}</td><td>{row["wet_columns"]}</td><td>{row["wet_with_margin"]}</td></tr>'
    out+='</tbody></table></div><p class="small">*The two moved colonnades in Lethariel; the new stable position in Kezamba. Other dry buildings also clear the shifted water. Larger shifts buy more land but are unnecessary for these placements. These counts use the real capsule indicator inside its calm square.</p>'
    if key=='lethariel':
        out+='<p><strong>The mere precinct moves inland; its pin is unchanged.</strong> The checker reports plot centres 19–32 → 32–44 nodes off shore on two seeds. The table below checks the three actual plot centres (excluding two dressings) against the nearest integer wet column of the full authored-water function, including its outer warp. This explicit metric gives 18–35 → 38–46 overall; the checker does not record its estimator or seed pair. Neither measurement supports a promise that the precinct stays equally close to the lake.</p><div class="table-scroll"><table><thead><tr><th>Seed</th><th>Unshifted lake, centre-to-water range</th><th>Shifted lake, centre-to-water range</th></tr></thead><tbody>'
        for row in SHORE_CHECK['rows']:
            ranges=[]
            for variant in ['lake0','lake_shift']:
                distances=[p['distance'] for p in row[variant]]
                ranges.append(f'{min(distances):.1f}–{max(distances):.1f} nodes')
            out+=f'<tr><td>{row["seed"]}</td><td>{ranges[0]}</td><td>{ranges[1]}</td></tr>'
        out+='</tbody></table></div>'
    probe=m['northern_castle_probe']
    out+=f'<p><strong>Can the castle take a better place?</strong> A northern 45×35 reservation at {point(*probe["box"][:2])}–{point(*probe["box"][2:])} only clears water and a one-node buffer after a {probe["minimum_shift_with_buffer"]}-node north shift.'
    out+=(' It also overlaps '+E(', '.join(probe['buildings_hit']))+'.' if probe['buildings_hit'] else '')
    out+=' That land test does not include a new court or service schedule. Keep the accepted castle position and use the smaller lake move to loosen the civic quarter.</p>'
    water_source=(ROOT/W40/'water_authored.lua').read_text()
    lake_id='lethariel_crown_lake' if key=='lethariel' else 'kezamba_cenote'
    block=water_source.split('lake({id = "'+lake_id+'"',1)[1].split('warp =',1)[0]
    chain=[tuple(map(int,p)) for p in re.findall(r'\{(\d+), (-?\d+), (\d+)\}',block)]
    az=-1500 if key=='lethariel' else 1500
    out+='<details><summary>Exact lake-chain schedule · coordinates relative to the unchanged city anchor</summary><div class="table-scroll"><table><thead><tr><th>Point</th><th>Today x/z</th><th>Proposed x/z</th><th>Radius retained</th></tr></thead><tbody>'
    for i,(x,z,r) in enumerate(chain,1):
        out+=f'<tr><td>{i}</td><td>{point(x-1800,z-az)}</td><td>{point(x-1800,z-az+m["shift"])}</td><td>{r}</td></tr>'
    out+='</tbody></table></div><p>Anchor, lake id, depth and level_offset=−2 stay. The calm square remains at the city anchor and grows to half=57 in both comparison runs. Recut the composition mask from the shifted shape through ±57; the exported mask lives in data/lakes.json. Outside that square the existing warp still applies, so this is a translated capsule chain, not a byte-identical translation of every distant shore cell.</p></details>'
    out+=f'<label>Show seed <select class="seed-select" data-capital="{key}">'+''.join(f'<option>{seed}</option>' for seed in SEEDS)+'</select></label>'
    out+=f'<div class="city-pair" data-capital="{key}"><figure><figcaption>Today · whole capital</figcaption><div class="city-map today"></div></figure><figure><figcaption>Radius 56 + shifted lake · real planner sensitivity</figcaption><div class="city-map proposed"></div></figure></div>'
    out+='<div class="table-scroll"><table><thead><tr><th>Seed</th><th>Today plots</th><th>56, lake unshifted</th><th>56, lake shifted</th><th>Moved since today*</th><th>Required</th></tr></thead><tbody>'
    details=[]
    for seed in SEEDS:
        a=PLANS[seed]['today'][key];b=LAKE_PLANS[seed]['lake0'][key];c=LAKE_PLANS[seed]['lake_shift'][key]
        out+=f'<tr><td><code>{seed}</code></td><td>{len(a["plots"])}</td><td>{len(b["plots"])}</td><td>{len(c["plots"])}</td><td>{seed_metrics(key,seed)["moved"]}</td><td>{c["required"]}/{c["required"]}</td></tr>'
        details.append(f'<li><code>{seed}</code>: '+E(' → '.join(str(q['failures']) for q in [a,b,c]))+'</li>')
    out+='</tbody></table></div><p class="small">*Position, height or orientation of surviving plots. The middle column isolates the lake change: both new runs expand all six civic_width profiles and the two calm squares equally. Current core cells and the old landing scan remain. The other ten place proposals and their page inputs are unchanged; the older 40-seed table above does not validate these shifted lakes.</p>'
    out+='<details><summary>Unrouted, connector and infeasible labels · today → 56 unshifted → shifted</summary><ul>'+''.join(details)+'</ul></details>'
    out+='<h4>Independent checker · 40 seeds with shifted lakes</h4><p><strong>This is the better figure than our three-seed sample.</strong> It compares lake0 with lake_shift at the same expanded core, unlike the earlier historical civic-width table. The aggregates were rechecked from the checker’s existing exports; no fleet was rerun.</p><div class="table-scroll"><table><thead><tr><th>Capital</th><th>Unrouted cases new</th><th>Gone</th><th>Mean plot change</th><th>Range</th></tr></thead><tbody>'
    for capital in ['lethariel','kezamba']:
        f=LAKE_FLEET['summary'][capital]
        out+=f'<tr><td>{NAMES[capital]}</td><td>{f["new_unrouted_cases"]}</td><td>{f["gone_unrouted_cases"]}</td><td>{f["mean_delta"]:+g}</td><td>{f["min_delta"]:+d}…{f["max_delta"]:+d}</td></tr>'
    out+='</tbody></table></div><p class="small">A case is a changed street label on one capital/seed, not a failed capital. Every required plot was placed, no load failed, and the other four capitals planned identically. Old core cells and landing scan remain; full fleet, recut core and bank geometry are unverified.</p></div>'
    return out


def section(key,n):
    p=P[key]; capital=key in CAPITALS
    costs=place_claims(key)
    h=f'<section class="place" id="{key}"><div class="eyebrow">{n:02} / {"CAPITAL" if capital else "START TOWN"} · {FACTION[key]}</div><h2>{NAMES[key]}</h2><h3>{E(p["title"])}</h3><p class="lead">{E(p["lead"])}</p><p class="character">{E(p["character"])}</p>'
    h+='<div class="pair">'+''.join('<figure><figcaption><span>'+('PROPOSED' if pr else 'TODAY')+'</span>'+(('Lake amendment · decision pending' if key in LAKES else 'Land reservation · accepted') if pr else '0.69.0 · exported from code')+'</figcaption>'+map_svg(key,pr)+'</figure>' for pr in [False,True])+'</div>'
    if capital:
        old=next(b for b in BP[key]['buildings'] if b['id'] in p['replace']);a=old['w']*old['d']
        h+=f'<div class="metrics"><span><b>{old["w"]}×{old["d"]} → 45×35</b>royal footprint · {a:,} → 1,575 nodes²</span><span><b>+8 nodes / side</b>nominal civic radius 48 → 56</span><span><b>35×23 = 805</b>hall-floor reservation · walls separate</span></div>'
        baseline=('Today’s reachable hall floor (checker): 402 nodes²; the new gross reservation of 805 is 100.2% larger, before furnishing.' if key=='kezamba' else 'Today’s gross hall: 29 × 25 = 725 nodes² → 35 × 23 = 805 (+80, about 11%); depth shrinks from 25 to 23. Against the checker’s 684 reachable nodes², the 17.7% compares new gross with old net floor, not a measured gain in reachable space.')
        h+=f'<p class="small">{baseline} The former 345-node² reservation is replaced. Walls, foyer and service circulation have separate budgets above.</p>'
    else:
        w=p['centre'][2]-p['centre'][0]+1;d=p['centre'][3]-p['centre'][1]+1
        h+=f'<div class="metrics"><span><b>13×13</b>clear waystone pocket · pad stays 7×7</span><span><b>{w}×{d}</b>proposed centre envelope · mixed paving/ground</span><span><b>+0</b>growth of the town’s total envelope</span></div>'
    h+='<p>'+E(p['intent'])+'</p>'
    if capital and key not in ['lethariel','kezamba']:
        h+='<p>The western market shifts five nodes outward, its edge house shifts seven, and the statue moves three nodes east so the wider colonnades have room.</p>'
    h+='<div class="legend"><span class="legend-castle">Castle reserve</span><span class="legend-move">Moved building</span><span class="legend-pad">Waystone / arrival</span><span>Q quest · V vendor · O oven · dark royal posts · red door guards</span></div>'
    h+='<div class="building-key">'+''.join(f'<span><b>{b["number"]}</b> {E(b["id"].replace("_"," "))}</span>' for b in buildings(key))+'</div>'
    h+=schedule(key)
    h+='<div class="cost-card"><h4>What this commits the implementation to</h4><ul>'+''.join(cost(c) for c in costs)+'</ul></div>'
    if capital:h+=service_annex(key)+seed_section(key)
    h+=(f'<div class="decision"><span>LAKE AMENDMENT FOR YOUR DECISION</span><p>{E(p["question"])}</p></div>' if key in LAKES else '<div class="decision"><span>ACCEPTED</span><p>The user accepted this recommendation on 07 November 2026.</p></div>')+'</section>'
    return h


def comparisons():
    room=C.add('The shared castle stays 45×35 = 1,575 nodes². The former proposal reserved only 23×15 = 345 for its throne room. The new hall-floor reservation is 35×23 = 805 in every castle. Today’s gross hall in five capitals is 29×25 = 725: the new reservation adds 80 nodes² (about 11%), while depth shrinks from 25 to 23. The checker measured today’s reachable floor as 684 in those five capitals and 402 in Kezamba. Comparing 805 with those net areas gives +121 (+17.7%) and +403 (+100.2%); these compare new gross with old net floor, not measured gains in reachable space. The new hall’s walls are outside its reservation: 304 nodes² for the two-node outer wall band, 120 for the one-node hall wall ring, and 346 for foyer, stairs, service space and circulation. Together they use exactly 1,575. This is a compact hall-led castle; no separate ground-level courtyard is promised. The later architecture must keep this room reservation and provide more reachable floor than today after placing the throne and furnishings; 805 is the reserved floor area, not a measured furnished result.',
        [('tools/r70_design/data/design-check.md','reachable hall floor'),*[(f'mods/MAPGEN/grug_mapgen/building_templates/templates/{name}.tpl','pivot 31 27') for name in ['dur_brannoc_kings_hall','highcourt_kings_hall','lethariel_kings_hall','gor_drazhak_warlord_hall','nhal_veyr_mausoleum']],('tools/r70_design/proposals.py','one common internal allocation'),('tools/r70_design/build.py','assert area(P[key]')], 'Proposal / gross dimensions checked, reported net measurement')
    template=C.add('The castle requires new templates and roster use entries, preserving all live socket ids and roles. Format §6.1 fixes an existing template’s box, pivot and point ids/groups/order/faces against BASELINE; the larger castle cannot be delivered by silently resizing the old hall. Plan the BASELINE move with the coordinator under §6.2 and run the full building-template gate (format, nodes/palettes, point structure, standing/reachability and all compositions). Update tools/r58_townfix/portable_test.lua HALLS for the replacement templates; keeping only the old hall tests would miss the castles.',
        [('docs/technical/building-template-format.md','### 6.1'),('docs/technical/building-template-format.md','moves it with the coordinator'),('tools/building_templates/check.py','def validate('),('tools/r58_townfix/portable_test.lua','local HALLS =')])
    height=C.add('The castle must stay within BOUNDS.capital_core y=−2…40; today’s highest core top is 31 (Kezamba: 30). Growing horizontally grants no extra height. The 96×96 rule needs coordinated documentation changes in settlements.md and world_zones.md:721/810/1741/1765 (also the 96-node wording at 1865). Duplicated composition coordinates need updating too: for example Sunscar’s BREASTWORKS still names the original hall and armoury boxes separately from their layout placements.',
        [(W40+'r7_settlement.lua','capital_core ='),(WP+'highcourt.lua','it reaches y 31'),('docs/design/settlements.md','96'),('docs/design/world_zones.md','flat 96-node civic core'),('docs/design/world_zones.md','capital only the 96'),('docs/design/world_zones.md','dry capital-owned 96'),('docs/design/world_zones.md','A fixed 96'),(WP+'sunscar.lua','local BREASTWORKS =')])
    fleet=C.add('The checker measured 40 fleet seeds with all six capitals at radius 56: civic_width=112 and CORE/CORE_GATE/CORE_KEEP=56/57/60, using today’s authored cores and landing detector. This historical table uses the unshifted lakes; it does not predict the pass-4 lake amendments. All 240 proposed capitals placed every required plot, with no load failure; castle samples were dry and flat. Seven capital/seed unrouted-street cases appeared and three disappeared. Infeasible seeds: Kezamba 3→3, Lethariel 0→2, Gor Drazhak 2→0; the others 0→0. This differs from the three-seed MASK-ONLY experiment, which retains civic_width=96. On seed 12345 the proposed plot totals are Dur Brannoc 50 (mask only) versus 47 (civic112), and Kezamba 49 versus 51. Neither experiment builds the new cores. The implementation must run tools/seed_fleet/run.sh full, not just these 40 seeds, because civic_width changes terrain and river planning for every seed.',
        [('tools/r70_design/data/design-check.md','New measurement'),('tools/r70_design/data/checker-fleet.json','scope'),('tools/r70_design/export.lua','Sensitivity experiment ONLY'),('tools/seed_fleet/run.sh','full')], 'Measured by checker / aggregates rechecked, today’s cores')
    choice=C.add('Accepted by the user on 2026-11-07: radius 56 for all six capitals and every pass-3 per-place recommendation. Only the two lake amendments below await a new decision. Historical note: radius 48 was considered and not selected; its compact drawings are retired.',
        [('tools/r70_design/REPORT.md','radius 56')], 'User decision / pass 4 brief')
    out='<section class="comparisons"><div class="eyebrow">THE ACCEPTED RESERVATIONS</div><h2>A larger hall. Space around it.</h2><p>'+E(room['text'])+' '+ref(room)+'</p>'
    out+='<div class="table-scroll"><table><thead><tr><th>Capital</th><th>Old royal footprint</th><th>New footprint</th><th>Today’s reachable hall*</th><th>New floor reservation</th></tr></thead><tbody>'
    for key in CAPITALS:
        out+=f'<tr><td>{NAMES[key]}</td><td>{529 if key=="kezamba" else 837}</td><td>1,575</td><td>{402 if key=="kezamba" else 684}</td><td>805</td></tr>'
    out+='</tbody></table></div><p class="small">Areas in nodes². *The checker’s flood-fill measurement is net reachable floor. Today’s gross hall in five capitals is 29 × 25 = 725; the new 35 × 23 = 805 is about 11% larger and two nodes shallower. The 805 is reserved room floor before furnishing; future reachable floor must exceed today. Architecture and headroom are not yet built.</p>'
    out+='<div class="cost-card"><ul>'+cost(template)+cost(height)+'</ul></div>'
    out+='<h3>40 fleet seeds · all six at 56, with today’s cores</h3><p>'+E(fleet['text'])+' '+ref(fleet)+'</p><div class="table-scroll"><table><thead><tr><th>Capital</th><th>Mean plot change</th><th>Worst seed</th><th>Unrouted cases new / gone</th><th>Seeds reporting infeasible</th></tr></thead><tbody>'
    for key in ['gor_drazhak','highcourt','kezamba','nhal_veyr','dur_brannoc','lethariel']:
        m=FLEET['summary'][key]
        # Preserve the check report’s rounded mean; exact means in the data ledger.
        mean=format(m['mean_delta'],'.2f' if key=='nhal_veyr' else '.1f')
        out+=f'<tr><td>{NAMES[key]}</td><td>{mean}</td><td>{m["worst_delta"]}</td><td>{m["new_unrouted_cases"]} / {m["removed_unrouted_cases"]}</td><td>{m["infeasible"]["today"]} → {m["infeasible"]["civic112"]}</td></tr>'
    out+='</tbody></table></div><details><summary>The 40 exact seed strings</summary><p>'+', '.join('<code>'+r['seed']+'</code>' for r in FLEET['rows'])+'</p></details></section>'
    return out


def main():
    count=validate_geometry()
    lake_evidence=validate_lakes()
    sections=''.join(section(key,n+1) for n,key in enumerate(CAPITALS+TOWNS))
    comparison=comparisons()
    source_cards=''.join(f'<article id="claim-{c["id"]}"><h4>{c["id"]} · {E(c["status"])}</h4><p>{E(c["text"])}</p><ul>'+''.join(f'<li><code>{E(s["file"])}:{s["line"]}</code></li>' for s in c['sources'])+'</ul></article>' for c in C.rows)
    nav=''.join(f'<a href="#{key}">{NAMES[key]}</a>' for key in CAPITALS+TOWNS)
    data={seed:{variant:{key:{field:p[field] for field in ['outline','streets','plots','gates','core','keep']} for key,p in vals.items()} for variant,vals in runs.items()} for seed,runs in PLANS.items()}
    intro='''<header class="hero"><div class="eyebrow">GRUDGELANDS / ROUND 70 / LAND USE STUDY</div><h1>Room for a crown.<br><em>Room to arrive.</em></h1><p class="lead">Six capital cores. Six start towns. One shared castle reservation, twelve places with their own character.</p><div class="hero-bottom"><span>2D proposal · GPT-6 Astra</span><span>07 November 2026</span><span>Base 55aa7708</span></div></header>
    <section class="reading" id="decision-record"><h2>Decision recorded · 07 November 2026</h2><p><strong>The user accepted the page: radius 56 for all six capitals and every per-place recommendation.</strong> The other ten places remain unchanged. This pass proposes only the two lake amendments below.</p><p class="small">Historical note: radius 48 was considered and not selected. Its compact alternatives are retired.</p></section>
    <section class="intro"><div><h2>Reserve the land.<br>Decide the buildings later.</h2><p>The accepted plan is a 45 × 35-node castle reservation, turned to suit each capital, inside a civic core expanded by eight nodes per side. Lethariel keeps the castle on its dry western shoulder; Kezamba keeps it on the dry southern terrace.</p><p>At the starts, give each waystone a clear 13 × 13 pocket near the centre. Move the closest buildings and furniture to make space, while keeping the town envelope, spawn and gate axis.</p></div><aside><strong>Land use accepted; lake amendments proposed</strong><p>No castle architecture is designed here. Gold shapes reserve land, including future overhangs. Existing buildings and sockets come from the real template/composition code.</p><p>An independent check covered the prior layouts. The independent pass-4 check confirmed the shifts and found costs corrected here in pass 5; these corrections await its re-check and the user’s two decisions. Desktop and web walking, final heights, future 3D geometry and combat remain unverified.</p><p>Shared footprint: 1,575 square nodes. Hall-floor reservation: 35 × 23 = 805 within it. Two royal posts beside the throne and two ordinary door guards at the great door. No extra guards.</p></aside></section>
    <section class="reading"><h3>Reading the plans</h3><p>North (+z) is up; +x is right. All twelve plan pairs use the same 160-node window and a 20-node scale bar. Solid blocks are exported template pivots; faint outlines include eaves and other written columns. Numbers match the coordinate schedules. Q marks a quest giver, V a vendor, O the public oven. Click or focus a numbered building to highlight it in both views.</p><p>Today’s background is a schematic projection of actual authored cells, with trees and paving. The proposed background keeps surrounding planting schematically and shows land reservations and principal walking connections; it is not a new voxel blueprint. Today’s lake samples are from seed 12345. The two proposed lakes use the real authored-water function with shifted capsule chains and an expanded calm square; their full core wet-column counts agree with fitted terrain on three seeds. New shore paving is a 2D reservation. The old composition and landing detector still run in the planner experiment.</p></section>'''
    constraints='<section class="constraints" id="constraints"><div class="eyebrow">BEFORE A BUILD</div><h2>The dependencies behind the lines</h2><div class="conflict"><strong>Verified encounter rules</strong><p>Two royal guards are deliberate. Both door guards are ordinary guards. The four-guard documentation is stale. The 60-node distance concerns rewards; the king’s 30-node leash starts where a chase began and cannot confine combat to this room.</p></div><details><summary>Read the 14 shared dependencies and evidence links</summary><ul>'+''.join(cost(c) for c in shared)+'</ul></details></section>'
    footer='<section id="sources" class="sources"><div class="eyebrow">EVIDENCE LEDGER</div><h2>Claims and source locations</h2><p>Game-code locations are pinned to base 55aa7708; design-tool citations refer to this revision. The accompanying claims.md repeats every numbered cost claim. Source inspection is not an independent review.</p><details><summary>Open all '+str(len(C.rows))+' claims</summary>'+source_cards+'</details></section><footer>Grudgelands · Round 70 DESIGN · Nothing built. Nothing published by this lane.</footer>'
    template=(HERE/'shell.html').read_text()
    page=template.replace('@@CSS@@',(HERE/'style.css').read_text()).replace('@@NAV@@',nav).replace('@@BODY@@',intro+comparison+constraints+sections+footer).replace('@@DATA@@',json.dumps(data,separators=(',',':')).replace('<','\\u003c')).replace('@@JS@@',(HERE/'page.js').read_text())
    (HERE/'page.html').write_text(page)
    C.write(HERE/'claims.md')
    (HERE/'data/socket-schedules.json').write_text(json.dumps({k:sockets(k,True) for k in NAMES},indent=2)+'\n')
    (HERE/'data/lake-metrics.json').write_text(json.dumps(lake_evidence,indent=2)+'\n')
    (HERE/'data/metrics.json').write_text(json.dumps({k:{s:seed_metrics(k,s) for s in SEEDS} for k in CAPITALS},indent=2)+'\n')
    print(f'Built {len(page):,} characters; {len(C.rows)} cited claims; {count} geometry schedules checked.')

if __name__=='__main__':main()

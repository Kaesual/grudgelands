#!/usr/bin/env python3
"""Build a self-contained review page from the real exports and design reservations."""
import copy
import hashlib
import html
import json
import math
import re
from collections import defaultdict
from pathlib import Path
from proposals import CAPITALS, TOWNS, NAMES, FACTION, P, FURNITURE
from claims import Claims, ROOT, WP, W40, MOBS, HOME, QUEST

HERE = Path(__file__).resolve().parent
BP = json.loads((HERE/'data/blueprints.json').read_text())
BIND = json.loads((HERE/'data/bindings.json').read_text())
SEEDS = ['12345', '3684797457838814663', '17713522922938657774']
PLANS = {seed:{v:json.loads((HERE/f'data/{seed}-{v}.json').read_text())['capitals']
              for v in ['today','proposed']} for seed in SEEDS}
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
        shift=p.get('sockets',{}).get(sid, p['shifts'].get(owner.get(sid),[0,0]))
        s['x']+=shift[0];s['z']+=shift[1]
        if sid=='travel_waypoint' and p.get('waypoint'):s['x'],s['z']=p['waypoint']
        if key in CAPITALS:
            if sid=='king': s['x'],s['z']=p['throne']
            if sid.startswith('throne_guard_'):
                side=-3 if sid.endswith('west') else 3
                x,z=p['throne'];s['x'],s['z']=(x,z+side) if p['facing']=='east' else (x+side,z)
            if sid in p['watch_ids']:s['x'],s['z']=p['watch'][p['watch_ids'].index(sid)]
        elif s['role']=='guard_patrol':
            s['x'],s['z']=p['watch'][s['order']-1]
    return rows


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
            assert area(P[key]['room'])==345
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
        count+=1
    return count

# Every implementation-cost assertion is registered here or in place_claims.
shared=[]
shared.append(C.add('The enlarged core consumes district land: CORE/CORE_GATE/CORE_KEEP change from 48/49/52 to 56/57/60. The buildable mask also excludes wet, bank-adjacent and rough samples. The nominal civic square gains 3,328 square nodes (+36.1%); the outer 512-node reservation is unchanged.',
    [(W40+'capital_planner.lua','CORE = 48'),(W40+'capital_planner.lua','BUILD[k] = not WET[k]'),('tools/r70_design/export.lua','opt.CORE, opt.CORE_GATE')]))
shared.append(C.add('This is a planner sensitivity experiment: real world assembly and capital planning, with only those three options enlarged. Existing civic_width=96, terrain, buildings and the old core_landing detector remain. Final earthwork, landing heights, collision-free generated streets and performance are not verified.',
    [('tools/r70_design/export.lua','Sensitivity experiment ONLY'),(W40+'r7_capitals.lua','along >= 46 and along <= 49'),(W40+'source/simple_map.lua','id="capital_dwarf"')], 'Measured scope / limitations'))
shared.append(C.add('Implementation must coordinate civic_width (96 to 112), the flat-core/collar fitting and road exclusion, BOUNDS.capital_core (currently ±49), and the separate hard-coded ±49 exclusion in plot-collar writing. Changing the planner alone does not enlarge a buildable civic core.',
    [(W40+'source/simple_map.lua','id="capital_dwarf"'),(W40+'height.lua','profile.civic_width)'),(W40+'height.lua','local reach = fitting.profile.civic_width / 2 + 1'),(W40+'r7_settlement.lua','capital_core ='),(W40+'r7_settlement.lua','math.abs(lx) > 49')]))
shared.append(C.add('All six cities have four planned OUTER gates. Core entries differ: four authored gatehouses in Dur Brannoc, Highcourt, Gor Drazhak and Nhal Veyr; three in Lethariel; no such gatehouse kit in Kezamba. Extend the dry core entries by eight nodes, rebuild boundary rings and connect each avenue; do not add a northern gatehouse across Lethariel’s lake.',
    [(W40+'capital_planner.lua','for c = 1, 4 do'),(WP+'gate_watch.lua','open core has no gatehouse'),(WP+'lethariel.lua','id = "gate_east"'),(WP+'precinct_ring.lua','function')]))
shared.append(C.add('The avenue starts at CORE_GATE+1; when its core landing is wet it searches for a dry shore start. core_landing still scans along 46…49 and y −1…1. New dry thresholds and Kezamba’s deck extensions need a corresponding landing scan and height check; the lake edge must not silently acquire a land bridge.',
    [(W40+'capital_planner.lua','local a0 = {dx * (P.CORE_GATE + 1)'),(W40+'capital_planner.lua','if not landed then'),(W40+'r7_capitals.lua','along >= 46 and along <= 49')]))
shared.append(C.add('Patrol routes cache each fixed leg by settlement and body class in memory. Longer capital patrol legs may follow generated streets (street reach 24, rise 6); failed legs can remain unavailable until restart. Re-author waypoint groups/order and test doors, stairs and clear walking corridors; there is no saved route-cache migration to design.',
    [(MOBS+'routes.lua','Kept in memory only'),(MOBS+'routes.lua','STREET_REACH = 24'),(MOBS+'routes.lua','until the server restarts'),(MOBS+'routes.lua','function grug_mobs.route_settlement')]))
shared.append(C.add('Source conflict for Opus: world_zones.md specifies FOUR royal guards, but ROYAL_GUARD_SOCKET binds only throne_guard_west and throne_guard_east. The maps reserve those two posts three nodes from king and two unbound spare positions; they do not claim four current royal slots or authorize an encounter change.',
    [('docs/design/world_zones.md','king has exactly four'),(MOBS+'start_npcs.lua','local ROYAL_GUARD_SOCKET'),(MOBS+'start_npcs.lua','ROYAL_GUARD_SOCKET[socket.id]')], 'Verified source conflict'))
shared.append(C.add('The 60-node rule is a 3D reward-participation distance to the king’s death position (with a separate 60-second death grace). king_def instead sets a 30-node chase leash; aggro measures it from the chase anchor. Royal guards have no independent leash and use a 5-node follow distance. Keep combat within the reserved 23×15 throne room; neither a whole-core arena nor a larger leash is approved.',
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
            'the coordinate schedule gives every move. Existing template cell envelopes are checked for overlap; future castle cells and route clearance remain unverified.',refs+[('tools/r70_design/proposals.py',f"P['{key}']"),('tools/r70_design/build.py','def validate_geometry')], 'Proposal / 2D checked'))
        gate='four inner gatehouses' if key not in ['lethariel','kezamba'] else ('three inner gatehouses and the open lake shore' if key=='lethariel' else 'south/west ground posts and east/north boardwalk thresholds')
        costs.append(C.add(f'{NAMES[key]}: move the {gate} with the expanded boundary. The four outer gates and their avenues are replanned per seed; their measured positions are in the city views. Update core_landing, boundary masking and the road/collar exclusions together.',refs+[(W40+'r7_capitals.lua','local function core_landing'),(W40+'capital_planner.lua','local a0 = {dx * (P.CORE_GATE + 1)')]))
        costs.append(C.add(f'{NAMES[key]}: re-author {", ".join(p["watch_ids"])} in {key}_watch; the proposed points are in the socket schedule. '+
            ('Regenerate each moved gate_watch rectangle and tower post from its stamped gate.' if key not in ['lethariel','kezamba'] else
             'Keep Lethariel’s quay patrol dry and regenerate the three gate watches.' if key=='lethariel' else
             'Keep the quay walk on dry ground and the existing deck crossings; do not draw a ground loop across the cenote.')+
            ' Rebuild the in-memory route legs after restart and test them on the finished geometry.',[(source,'local WATCH ='),(source,'id = "watch_south_west"'),(MOBS+'routes.lua','STREET_REACH = 24'),(WP+'gate_watch.lua','function M.apply')]))
        old=next(s for s in v['landmarks']['sockets'] if s['id']=='king')
        hall=next(b for b in v['buildings'] if b['id'] in p['replace'])
        hall_file='mods/MAPGEN/grug_mapgen/building_templates/templates/'+hall['template']+'.tpl'
        costs.append(C.add(f'{NAMES[key]}: king moves from {point(old["x"],old["z"])} to {point(*p["throne"])}; throne_guard_west/east follow to posts three nodes away. Preserve their ids and royal binding, then author their y and facing from the actual throne floor. The 60-node reward sphere follows the death position; it is not a core boundary. Resolve the two-versus-four guard conflict before adding slots.',[(source,'id = "'+hall['id']+'"'),(hall_file,'id=king role=king'),(hall_file,'id=throne_guard_west'),(MOBS+'start_npcs.lua','local ROYAL_GUARD_SOCKET'),(MOBS+'bosses.lua','near = dx * dx + dy * dy')]))
        qs=next(s for s in v['landmarks']['sockets'] if s['role']=='quest')
        wp=next(s for s in sockets(key,True) if s['id']=='travel_waypoint')
        costs.append(C.add(f'{NAMES[key]}: preserve {qs["id"]} at its named public building and preserve vendor_race/vendor_general when their stalls move. travel_waypoint is proposed at {point(wp["x"],wp["z"])}; keep its mailbox and arrival cells with it. All ten required district plots and the concrete service sockets listed below must survive replanning; no service is transferred to the castle.',refs+[(WP+'capital_services.lua',key+' ='),(W40+'r7_capitals.lua','local function required_of'),(QUEST+'npcs.lua',f'"{key}"')]))
        if key=='lethariel':
            text='Lethariel: preserve the MERE wedge and its one-node shore margin, including the tip at (0,22); enlarge on the dry south-west. The mere district remains pinned toward lethariel_crown_lake. Extend the authored mask from the water source if the core boundary changes; do not extrapolate the present finite MERE table blindly.'
            r=[(WP+'lethariel.lua','local MERE_FIRST = 22'),(WP+'lethariel.lua','local SHORE_MARGIN = 1'),(W40+'r7_capital_blueprint.lua','lake = "lethariel_crown_lake"')]
        elif key=='kezamba':
            text='Kezamba: preserve the cenote below the dry terrace and its supported decks; do not flatten the whole square. The lagoon mask distinguishes pad, water and ravine (the current ravine mask is empty). Extend dry south/west land only, recheck new deck landings, and keep the shore district pinned toward kezamba_cenote. The sampled castles are dry on all three existing terrains; final grading is unverified.'
            r=[(WP+'kezamba.lua','local mask ='),(WP+'kezamba_lagoon.lua','M.RAVINE_COLUMNS = 0'),(W40+'r7_capital_blueprint.lua','lake = "kezamba_cenote"'),('tools/r70_design/build.py','castle reaches sampled water')]
        else:
            text=f'{NAMES[key]}: carry the larger core onto the fitted civic ground, keeping its own boundary character. civic_width, authorized core bounds and road/plot-collar exclusions must change together; the three-seed comparison does not include this earthwork.'
            r=refs+[(W40+'source/simple_map.lua','civic_width=96'),(W40+'r7_settlement.lua','capital_core =')]
        costs.append(C.add(text,r))
    else:
        costs.append(C.add(f'{NAMES[key]}: move {", ".join(moved)} with their stairs, doors and attached standing points. Keep the authored ±63 bounds, the same 128-node pad and 12-node protected band. Spawn remains (0,1,0); the main_street and gate axis remain. Move intersecting furniture and vegetation to the margins before paving the enlarged centre.',refs+[(f'mods/MAPGEN/grug_mapgen/building_templates/layouts/{key}.layout','place '),(W40+'source/simple_map.lua','id="hard_start_town_v1"')]))
        old=next(s for s in v['landmarks']['sockets'] if s['id']=='travel_waypoint')
        wp=p['waypoint']
        costs.append(C.add(f'{NAMES[key]}: travel_waypoint moves {point(old["x"],old["z"])} → {point(*wp)}. Its reach-3 pad gains a 13×13 clear reservation; the mailbox moves to {point(wp[0]+2,wp[1]+1)}. Preserve all four arrival sides and leave the Quartermaster at its current vendor socket.',[(source,'local WAYPOINT ='),(source,'id = "travel_waypoint"'),(WP+'dressing.lua','function M.waystone'),(HOME+'waypoints.lua','local function arrival_at')]))
        qs=next(s for s in sockets(key,True) if s['id']=='hall_quest')
        home=re.search(r'\{id="'+key+r'"[^\n]*socket="([^"]+)"',(ROOT/HOME/'locations.lua').read_text()).group(1)
        costs.append(C.add(f'{NAMES[key]}: hall_quest follows its host to {point(qs["x"],qs["z"])}; quest_cook and cook_oven keep their projection-adapter positions. Keep the inn/home binding {home}, both quest giver ids and their quest data. Recheck the oven, home arrival and all idle_spare_* points; listed displaced spares move to the clearing’s edge.',refs+[(W40+'r7_settlement.lua','rows[#rows+1]={id="quest_cook"'),(HOME+'locations.lua',f'id="{key}"'),(QUEST+'npcs.lua',f'"{key}", "hall_quest"')]))
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
            paths[kind].append(f'M{x-.5},{-z-.5}h1v1h-1z')
    return ''.join(f'<path d="{"".join(path)}" class="raster retained {kind}"/>' for kind,path in paths.items())


def water_paths(key):
    if key not in ['lethariel','kezamba']:return ''
    t=PLANS['12345']['today'][key]['terrain'];path=[]
    for iz,row in enumerate(t):
        for ix,(h,w) in enumerate(row):
            if w is not False and w>h:
                x,z=-76+ix*2,-76+iz*2;path.append(f'M{x-1},{-z-1}h2v2h-2z')
    return '<path class="water-land" d="'+''.join(path)+'"/>'

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
        out+=[water_paths(key)]
    else:
        out+=['<rect x="-76" y="-76" width="152" height="152" rx="12" class="protection"/>',rect([-63,-63,63,63],'town-edge')]
    if not proposed:out += [raster_paths(key)]
    else:
        out += [retained_land(key)]
        if capital:
            out += [rect(p['court'],'court')]
        else:out += [rect(p['centre'],'court garden' if key=='dawnmere' else 'court')]
        for flat,width in p['roads']:
            pts=list(zip(flat[::2],flat[1::2]));css='road deck' if key=='kezamba' and flat in [[0,0,0,57],[0,0,57,0]] else 'road'
            out += [poly(pts,css,f'style="stroke-width:{width}"')]
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
        r=p['castle'];out += [rect(r,'castle'),rect(p['room'],'throne-room')]
        out += [label((r[0]+r[2])/2,r[3]-4 if p['facing']=='east' else (r[1]+r[3])/2,'CASTLE','castle-label')]
        rm=p['room'];out += [label((rm[0]+rm[2])/2,(rm[1]+rm[3])/2-2,'THRONE','room-label')]
        x,z=p['throne'];out += [f'<circle cx="{x}" cy="{-z}" r="60" class="reward-radius"><title>60-node reward radius if the king dies at the proposed seat; horizontal slice, not a leash.</title></circle>']
        # Two explicitly unbound possible posts, not invented live NPC sockets.
        for sx,sz in [(x,z-3),(x,z+3)] if p['facing']!='east' else [(x-3,z),(x+3,z)]:
            out += [f'<circle cx="{sx}" cy="{-sz}" r=".9" class="spare-guard"><title>Unbound spare guard position; resolve guard count first.</title></circle>']
        # Entry marker only, no architecture.
        ex,ez=((r[0]+r[2])/2,r[1]) if p['facing']=='south' else (((r[0]+r[2])/2,r[3]) if p['facing']=='north' else (r[2],(r[1]+r[3])/2))
        out += [f'<circle cx="{ex}" cy="{-ez}" r="1.5" class="entry"/>',label(ex,ez-3,'entry','small-label')]
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
            royal=sid.startswith('throne_guard_')
            out += [f'<circle cx="{x}" cy="{-z}" r="{.85 if royal else .65}" class="socket-dot {"royal" if royal else "optional-socket"}"><title>{E(sid)} · {role} {point(x,z)} y={s["y"]}'+(' (proposed x/z; y not designed)' if proposed else '')+'</title></circle>']
    out += [label(-72,69,'N ↑ +z','axis'), label(65,-69,'+x →','axis'),
        '<path d="M-70 67v2h20v-2M-60 67v2" class="scale"/>',label(-60,-65,'20 nodes','scale-label')]
    if key in ['lethariel','kezamba']:
        out += [label(31,61,'water −2 / dry terrace 0','water-label')]
        if key=='kezamba' and proposed:out += [label(7,53,'deck','small-label'),label(53,-5,'deck','small-label')]
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
        if changed or s['role'] in ['quest','king','waypoint'] or s['id'] in ['cook_oven','home_innkeeper']:
            sr.append(f'<tr><td><code>{s["id"]}</code></td><td>{s["role"]}</td><td>{point(old["x"],old["z"])}</td><td>{point(s["x"],s["z"])}</td></tr>')
    out+='<details><summary>Named sockets · moves and retained services</summary><p>Horizontal reservations only. Retain stable ids; re-author y, facing and the associated furniture with the final floor. Small dots on the maps show every exported point; no runtime route is implied.</p><div class="table-scroll"><table><thead><tr><th>Socket</th><th>Role</th><th>Today</th><th>Proposed</th></tr></thead><tbody>'+''.join(sr)+'</tbody></table></div></details>'
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
    metrics=[seed_metrics(key,s) for s in SEEDS]
    c=C.add(f'{NAMES[key]}: the three seeds {", ".join(SEEDS)} placed all {metrics[0]["required"]} required district plots in the enlarged-mask experiment. Plot totals changed '+
        ', '.join(f'{m["before"]}→{m["after"]}' for m in metrics)+', and '+', '.join(str(m['moved']) for m in metrics)+
        ' surviving plots changed x/z, y or orientation. The removed buildable band is approximately '+str(metrics[0]['lost_area'])+
        ' square nodes on the 2-node sample grid; this is sampled eligible ground, not a sum of lost building footprints.',
        [('tools/r70_design/export.lua','out.lost_band_buildable ='),('tools/r70_design/build.py','def seed_metrics')]+[(f'tools/r70_design/data/{s}-proposed.json','"capitals"') for s in SEEDS], 'Measured / limited to three seeds')
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


def section(key,n):
    p=P[key]; capital=key in CAPITALS
    costs=place_claims(key)
    h=f'<section class="place" id="{key}"><div class="eyebrow">{n:02} / {"CAPITAL" if capital else "START TOWN"} · {FACTION[key]}</div><h2>{NAMES[key]}</h2><h3>{E(p["title"])}</h3><p class="lead">{E(p["lead"])}</p><p class="character">{E(p["character"])}</p>'
    h+='<div class="pair">'+''.join('<figure><figcaption><span>'+('PROPOSED' if pr else 'TODAY')+'</span>'+('Land reservation · decision pending' if pr else '0.69.0 · exported from code')+'</figcaption>'+map_svg(key,pr)+'</figure>' for pr in [False,True])+'</div>'
    if capital:
        old=next(b for b in BP[key]['buildings'] if b['id'] in p['replace']);a=old['w']*old['d']
        h+=f'<div class="metrics"><span><b>{old["w"]}×{old["d"]} → 45×35</b>royal footprint · {a:,} → 1,575 nodes²</span><span><b>+8 nodes / side</b>nominal civic radius 48 → 56</span><span><b>23×15</b>throne-room land inside castle</span></div>'
    else:
        w=p['centre'][2]-p['centre'][0]+1;d=p['centre'][3]-p['centre'][1]+1
        h+=f'<div class="metrics"><span><b>13×13</b>clear waystone pocket · pad stays 7×7</span><span><b>{w}×{d}</b>proposed centre envelope · mixed paving/ground</span><span><b>+0</b>growth of the town’s total envelope</span></div>'
    h+='<p>'+E(p['intent'])+'</p>'
    if capital and key not in ['lethariel','kezamba']:
        h+='<p>The western market shifts five nodes outward, its edge house shifts seven, and the statue moves three nodes east so the wider colonnades have room.</p>'
    h+='<div class="legend"><span class="legend-castle">Castle reserve</span><span class="legend-move">Moved building</span><span class="legend-pad">Waystone / arrival</span><span>Q quest · V vendor · O oven · dots: sockets</span></div>'
    h+='<div class="building-key">'+''.join(f'<span><b>{b["number"]}</b> {E(b["id"].replace("_"," "))}</span>' for b in buildings(key))+'</div>'
    h+=schedule(key)
    h+='<div class="cost-card"><h4>What this commits the implementation to</h4><ul>'+''.join(cost(c) for c in costs)+'</ul></div>'
    if capital:h+=service_annex(key)+seed_section(key)
    h+=f'<div class="decision"><span>FOR YOUR DECISION</span><p>{E(p["question"])}</p></div></section>'
    return h


def main():
    count=validate_geometry()
    sections=''.join(section(key,n+1) for n,key in enumerate(CAPITALS+TOWNS))
    source_cards=''.join(f'<article id="claim-{c["id"]}"><h4>{c["id"]} · {E(c["status"])}</h4><p>{E(c["text"])}</p><ul>'+''.join(f'<li><code>{E(s["file"])}:{s["line"]}</code></li>' for s in c['sources'])+'</ul></article>' for c in C.rows)
    nav=''.join(f'<a href="#{key}">{NAMES[key]}</a>' for key in CAPITALS+TOWNS)
    data={seed:{variant:{key:{field:p[field] for field in ['outline','streets','plots','gates','core','keep']} for key,p in vals.items()} for variant,vals in runs.items()} for seed,runs in PLANS.items()}
    intro='''<header class="hero"><div class="eyebrow">GRUDGELANDS / ROUND 70 / LAND USE STUDY</div><h1>Room for a crown.<br><em>Room to arrive.</em></h1><p class="lead">Six capital cores. Six start towns. One shared castle reservation, twelve places with their own character.</p><div class="hero-bottom"><span>2D proposal · GPT-6 Astra</span><span>07 November 2026</span><span>Base 55aa7708</span></div></header>
    <section class="intro"><div><h2>Reserve the land.<br>Decide the buildings later.</h2><p>The recommendation is a 45 × 35-node castle reservation, turned to suit each capital, inside a civic core expanded by eight nodes per side. Lethariel keeps the castle on its dry western shoulder; Kezamba keeps it on the dry southern terrace.</p><p>At the starts, give each waystone a clear 13 × 13 pocket near the centre. Move the closest buildings and furniture to make space, while keeping the town envelope, spawn and gate axis.</p></div><aside><strong>Proposal, not an approved build</strong><p>No castle architecture is designed here. Gold shapes reserve land, including future overhangs. Existing buildings and sockets come from the real template/composition code.</p><p>The coordinator’s Opus cost check is pending. Desktop and web walking, final heights, 3D collisions and combat are not verified.</p><p>Shared footprint: 1,575 square nodes. Throne room: 23 × 15 within it. Two actual royal posts, plus two unbound spare positions pending the source conflict below.</p></aside></section>
    <section class="reading"><h3>Reading the plans</h3><p>North (+z) is up; +x is right. All twelve plan pairs use the same 160-node window and a 20-node scale bar. Solid blocks are exported template pivots; faint outlines include eaves and other written columns. Numbers match the coordinate schedules. Q marks a quest giver, V a vendor, O the public oven. Click or focus a numbered building to highlight it in both views.</p><p>Today’s background is a schematic projection of actual authored cells, with trees and paving. The proposed background keeps surrounding planting schematically and shows land reservations and principal walking connections; it is not a new voxel blueprint. Existing lake samples are from seed 12345; all three seeds were checked beneath the castle reservations.</p></section>'''
    constraints='<section class="constraints" id="constraints"><div class="eyebrow">BEFORE A BUILD</div><h2>The dependencies behind the lines</h2><div class="conflict"><strong>Two points for the independent checker</strong><p>The documents describe four royal guards; the current binding table names two. The 60-node distance concerns reward participation; the king’s chase leash is 30. The design keeps the current ids and exposes the discrepancy.</p></div><details><summary>Read the 14 shared dependencies and evidence links</summary><ul>'+''.join(cost(c) for c in shared)+'</ul></details></section>'
    footer='<section id="sources" class="sources"><div class="eyebrow">EVIDENCE LEDGER</div><h2>Claims and source locations</h2><p>These are exact repository locations for the checker, pinned to base 55aa7708. The accompanying claims.md repeats every numbered cost claim. Source inspection is not an independent review.</p><details><summary>Open all '+str(len(C.rows))+' claims</summary>'+source_cards+'</details></section><footer>Grudgelands · Round 70 DESIGN · Nothing built. Nothing published by this lane.</footer>'
    template=(HERE/'shell.html').read_text()
    page=template.replace('@@CSS@@',(HERE/'style.css').read_text()).replace('@@NAV@@',nav).replace('@@BODY@@',intro+constraints+sections+footer).replace('@@DATA@@',json.dumps(data,separators=(',',':')).replace('<','\\u003c')).replace('@@JS@@',(HERE/'page.js').read_text())
    (HERE/'page.html').write_text(page)
    C.write(HERE/'claims.md')
    (HERE/'data/metrics.json').write_text(json.dumps({k:{s:seed_metrics(k,s) for s in SEEDS} for k in CAPITALS},indent=2)+'\n')
    print(f'Built {len(page):,} characters; {len(C.rows)} cited claims; {count} geometry schedules checked.')

if __name__=='__main__':main()

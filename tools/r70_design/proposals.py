"""Design reservations only. Inclusive node coordinates, +z north, no game writes."""
CAPITALS = ['dur_brannoc', 'highcourt', 'lethariel', 'gor_drazhak', 'nhal_veyr', 'kezamba']
TOWNS = ['hearthpine', 'dawnmere', 'silverleaf', 'stillgrave', 'sunscar', 'kapok']
NAMES = dict(zip(CAPITALS + TOWNS, ['Dur Brannoc', 'Highcourt', 'Lethariel', 'Gor Drazhak', 'Nhal Veyr', 'Kezamba',
    'Hearthpine', 'Dawnmere', 'Silverleaf', 'Stillgrave', 'Sunscar', 'Kapok Cradle']))
FACTION = {k: ('The Accord' if k in CAPITALS[:3]+TOWNS[:3] else 'The Throng') for k in NAMES}
P = {}
for key, hall, east1, east2, west in [
    ('dur_brannoc','kings_hall','great_forge','smelting_yard','ancestor_hall'),
    ('highcourt','kings_hall','service_yard','service_store','chapel'),
    ('gor_drazhak','warlord_hall','host_store','beast_shed','skull_hall'),
    ('nhal_veyr','mausoleum','bone_works','charnel_yard','vigil_hall')]:
    P[key] = dict(castle=[-22,10,22,44], facing='south',
        replace=[hall], remove=[], shifts={east1:[8,0], east2:[8,0], 'colonnade_west':[-3,0], 'colonnade_east':[3,0],
        'gate_south':[0,-8], 'gate_north':[0,8], 'gate_west':[-8,0], 'gate_east':[8,0]},
        sockets={'vendor_race':[8,0], 'vendor_general':[8,0], 'colonnade_west_walk':[-3,0], 'colonnade_east_walk':[3,0]},
        roads=[([0,-49,0,8],9), ([0,-57,0,-49],5), ([-57,0,57,0],5), ([-27,0,-27,48,27,48,27,0],5), ([0,48,0,57],5)],
        court=[-18,3,18,8], watch=[[-27,-35],[-27,48],[50,39],[24,-40]],
        watch_ids=['watch_south_west','watch_north_west','watch_north_east','watch_south_east'],
        waypoint=None, quest_building=west)
for key in ['dur_brannoc','highcourt','gor_drazhak','nhal_veyr']:
    P[key]['shifts']['bazaar_square' if key == 'gor_drazhak' else 'market'] = [-5,0]
    P[key]['shifts']['bazaar_house' if key == 'gor_drazhak' else 'market_house'] = [-7,0]
    P[key]['shifts']['statue'] = [3,0]
P['nhal_veyr']['shifts']['fallen_house'] = [-8,-11]
P['dur_brannoc'].update(title='A citadel above the forge court',
    lead='A broad castle closes the northern view. The working court shifts east; the ancestor hall keeps its quiet western edge.',
    intent='The castle nearly doubles the old hall’s land reservation while the forge remains visible from the central crossing. Two flank lanes carry through traffic behind the castle.',
    character='Granite court · slate halls · western ancestor precinct',
    question='Keep the forge beside the royal court, as proposed, or reserve that eastern land for a quieter civic garden?')
P['highcourt'].update(title='A royal front, with a usable city behind it',
    lead='A wider approach and an open forecourt make the castle the destination of the south avenue. The chapel and southern orchards frame the civic quarter.',
    intent='The service yard and store move east by eight nodes. The rear bypass preserves the north gate without sending everyday traffic through the throne room.',
    character='Royal axis · chapel quarter · orchards and canal city',
    question='Keep both southern orchards as proposed, or later use one as an open gathering ground?')
P['gor_drazhak'].update(title='A stronghold commanding an open muster',
    lead='The castle occupies the northern head of the core. Stores and beasts move to the east, leaving the broad approach legible from the bazaar.',
    intent='Keep the earth bank and timber character. The shared castle footprint sets the hierarchy; its later architecture can express that character without changing the land plan.',
    character='Earth bank · timber watch · bazaar and muster',
    question='Is the broad southern approach sufficient muster space, while the eastern beast yard stays active?')
P['nhal_veyr'].update(title='A sovereign precinct in the necropolis',
    lead='The small mausoleum gives way to the shared castle reservation. A rear processional walk separates the royal precinct from the northern gate.',
    intent='Bone Works and the Charnel Yard move east. The existing close patrol around the mausoleum must be replaced by a loop around the enlarged precinct.',
    character='Funerary court · iron boundary · western vigil hall',
    question='Keep the vigil hall separate from the castle, as proposed, to retain a distinct public quest destination?')
P['lethariel'] = dict(castle=[-52,-51,-18,-7], facing='east',
    replace=['kings_hall'], remove=['colonnade_west','colonnade_east'],
    shifts={'gate_south':[0,-8],'gate_west':[-8,0],'gate_east':[8,0]},
    sockets={'colonnade_west_walk':[-7,-12], 'colonnade_east_walk':[0,-12]},
    roads=[([0,-57,0,14],5), ([-57,0,57,0],5), ([-16,-29,0,-29],7), ([-14,-45,-14,-3],3)],
    court=[-16,-42,-3,-16], watch=[[-11,-44],[-36,2],[2,16],[36,-2]],
    watch_ids=['watch_south_west','watch_west','watch_quay','watch_south_east'],
    waypoint=None, quest_building='star_hall', title='A castle on the dry western shoulder',
    lead='Turn the same castle a quarter turn and enlarge it toward the south-west. Its front opens east onto a court; the lake keeps its full northern bite.',
    intent='Retire the two narrow colonnades as freestanding strips and give their land to the arrival court. The star hall, sacred grove and lake shrines keep their places. No new north gatehouse or causeway is proposed.',
    character='Lake edge · dry western castle · open grove',
    question='Approve the western castle and east-facing court, with the lake and open northern shore kept intact?')
P['kezamba'] = dict(castle=[5,-52,49,-18], facing='north',
    replace=['kings_hall'], remove=[],
    shifts={'stable':[-60,-8], 'lane_house':[-61,-10], 'west_house':[-20,15], 'granary':[-59,21],
        'shore_house':[15,-1], 'gate_house_south':[-36,-13]},
    sockets={'watch_south_west':[4,0], 'gate_post_south':[0,-8], 'gate_post_west':[-8,0]},
    roads=[([0,-57,0,0],5), ([-57,0,0,0],5), ([0,-12,27,-12,27,-18],5),
        ([-20,0,-20,44],3), ([0,0,0,57],5), ([0,0,57,0],5)],
    court=[6,-16,28,-4], watch=[[-30,-44],[0,-44],[-8,-8],[-24,20]],
    watch_ids=['watch_south_west','watch_south_east','watch_crossing','watch_quay'],
    waypoint=[-12,8], quest_building='shrine', title='A castle on the southern terrace',
    lead='The royal land stays on the dry southern side. The cenote remains open, with its current boardwalk crossings; the waystone moves to the inner quay clearing.',
    intent='The stable and lane house form a western service strip. The granary and shore house shift along the dry western edge. The south avenue passes beside the castle, then turns into its forecourt.',
    character='Dry terrace · lower cenote · decks and stilt access',
    question='Approve the southern castle and the waystone near the quay, accepting six civic building relocations?')

P['hearthpine'] = dict(waypoint=[-9,7], centre=[-16,-12,18,16],
    shifts={'forge_hall':[0,-4],'west_home':[-7,-2],'east_home':[6,0],'east_gable_home':[8,-4],'workyard':[-7,1]},
    roads=[([0,63,0,-12],5), ([-29,0,23,0],3), ([-9,0,-9,7],3), ([-29,27,0,27],3)],
    watch=[(0,52),(0,24),(-17,0),(0,-11),(16,0)],
    title='A breathing space between homes and forge',
    lead='Pull the two closest homes apart and set the waystone in a western pocket of the arrival square. The forge steps back four nodes.',
    intent='Keep the market stall and Quartermaster to the east. The direct gate-to-spawn route stays clear; the western workyard moves with the home beside it.',
    character='Pine craft town · working northern edge',
    question='Keep the waystone west of the main route, with the Quartermaster on the opposite side?')
P['dawnmere'] = dict(waypoint=[-9,-8], centre=[-17,-16,17,12],
    shifts={'meeting_hall':[-7,4],'harvest_inn':[7,4]},
    roads=[([0,63,0,-16],5), ([-18,12,18,12],3), ([-18,0,18,0],3), ([-9,0,-9,-8],3)],
    watch=[(0,52),(0,28),(-18,0),(0,-15),(18,0)],
    title='A village green, not a traffic island',
    lead='The hall and inn spread apart and step back. A waystone pocket at the green’s south-west edge gives arrivals their own place beside the grass.',
    intent='Only two buildings move. Keep the green mostly planted, the eastern stall active and a straight central route between gate and spawn.',
    character='Open green · facing hall and inn',
    question='Keep the expanded centre mostly grass, with paving limited to the waystone pocket and connecting walks?')
P['silverleaf'] = dict(waypoint=[11,7], centre=[-13,-12,19,14],
    shifts={'terrace_house_west':[-6,-5],'terrace_house_east':[6,-5],'lore_hall':[6,6]},
    roads=[([0,63,0,-9],5), ([0,10,26,10,26,20],3), ([0,7,11,7],3), ([-20,14,0,14],3)],
    watch=[(0,52),(0,24),(-12,0),(0,-9),(19,0)],
    title='A clearing beside the crescent',
    lead='The waystone moves into its own eastern clearing. The lore hall steps north-east, and the raised houses spread out to release the centre.',
    intent='Keep the crescent and the western shrine as recognisable destinations. The raised homes retain their +3 level; their supporting terraces and steps must move with them.',
    character='Crescent court · raised homes · shrine walk',
    question='Accept moving the two raised house terraces, to keep the crescent untouched and the waystone outside it?')
P['stillgrave'] = dict(waypoint=[-12,-2], centre=[-20,-12,18,16],
    shifts={'crypt_chapel':[0,6],'bone_works':[6,0], 'keepers_house':[0,6],
        'warden_house':[0,6],'hollow_ruin':[0,6],'sunken_ruin':[0,6]},
    roads=[([0,-63,0,16],5), ([-20,0,29,0],3), ([-12,0,-12,-2],3), ([-29,37,23,37],3)],
    watch=[(0,-52),(0,-24),(-20,0),(0,14),(18,0)],
    title='A calm court before the chapel',
    lead='Set the waystone to the west and draw the chapel six nodes back. The northern homes and ruins follow, within the same town envelope.',
    intent='Keep the southern gate axis and spawn. Bone Works shifts east; grave furniture in the new western pocket moves to the memorial margin.',
    character='Western memorials · clear chapel axis',
    question='Approve moving the chapel and the northern row back six nodes, while retaining the burial margins?')
P['sunscar'] = dict(waypoint=[-11,2], centre=[-19,-13,20,18],
    shifts={'warlord_hall':[0,8],'armoury':[8,0],'beast_pen':[-8,10]},
    roads=[([0,-63,0,20],5), ([-33,0,29,0],3), ([-11,0,-11,2],3)],
    watch=[(0,-40),(0,-22),(-20,0),(-1,17),(20,0)],
    title='An open yard between gate and hall',
    lead='Move the hall back, spread the armoury and beast pen, and give the waystone a western pocket. The route from the twin towers remains straight.',
    intent='The central yard stays useful for gathering; the Quartermaster remains east of it. The hall’s quest doorstep follows the hall by eight nodes.',
    character='Twin gate towers · open yard · separate beast pen',
    question='Keep the waystone on the quiet western side and the eastern edge for trade and equipment?')
P['kapok'] = dict(waypoint=[-10,-7], centre=[-18,-15,17,19],
    shifts={'weaver_stilt':[-9,3],'reed_stilt':[9,3],'spirit_lodge':[0,6],
        'fish_smoker':[8,5],'drying_shed':[-8,5]},
    roads=[([0,-63,0,23],5), ([-20,0,21,0],3), ([-10,0,-10,-7],3), ([-29,23,30,23],3)],
    watch=[(0,-44),(0,-24),(-19,0),(0,20),(19,0)],
    title='A clearing with the boardwalk through it',
    lead='The waystone gets a dry pocket west of the boardwalk. The two near stilt houses spread apart; the lodge and work buildings frame a wider northern clearing.',
    intent='Keep the boardwalk’s gate axis. Move the footprints together with their stairs and landings, leaving the first arrival off the main walking line.',
    character='Boardwalk spine · stilt-house clearing',
    question='Accept moving the northern work buildings to make one clear gathering space before the spirit lodge?')
# Explicit re-authoring of standing spots displaced by the clear pad.
P['hearthpine']['sockets'] = {'idle_spare_2':[-9,3]}
P['silverleaf']['sockets'] = {'idle_spare_1':[13,1]}
P['stillgrave']['sockets'] = {'idle_spare_1':[-14,-2]}
P['kapok']['sockets'] = {'idle_spare_1':[-12,-6]}
P['stillgrave']['sockets']['idle_court_settle'] = [-10,0]
P['sunscar']['sockets'] = {'work_acacia':[-10,0]}
P['kezamba']['sockets'].update({'quay_idle_south':[-4,3], 'crossing_idle_west':[0,-8], 'shore_walk_south':[-1,10]})
P['silverleaf']['waypoint'] = [13,8]
P['silverleaf']['centre'] = [-13,-12,21,16]
P['silverleaf']['roads'][2] = ([0,8,13,8],3)
FURNITURE = {
 'hearthpine': 'Hearthpine: move the west plaza bench at (−8,0) to the new western edge near (−18,12), with idle_spare_2 beside it; clear the old pad paving and reconnect the market/forge walks.',
 'dawnmere': 'Dawnmere: the new arrival pocket displaces the well at (−6,−3), the handcart near (−10,−3), the south-west flower bed and western/southern benches. Reserve (−10,7) for the well and re-author the cart, beds and seating along the green’s outer edge; keep the green mostly turf.',
 'silverleaf': 'Silverleaf: preserve the actual crescent cells (centre (0,−2), squared radii 40/30, cut offset 4). The proposed 13×13 waystone clearing starts at x=7, beyond the crescent’s x=6 maximum. Move the displaced eastern corner lamp/flower furniture and idle_spare_1 to the new eastern edge; carry both +3 house podiums and their stairs with the houses.',
 'stillgrave': 'Stillgrave: move the court’s western settle and idle_court_settle to the outer western edge, and idle_spare_1 south-west of the pocket. Re-author any grave furniture that falls under the larger court, keeping the burial margins readable.',
 'sunscar': 'Sunscar: move the acacia work feature and work_acacia from (−14,−1) to the west near (−24,−1). All eight drill posts at x=−11/−9/−7/−5, z=3/6 also occupy the new pocket: move both ranks to x=−31/−29/−27/−25, z=5/8. Keep their approach clear of the relocated beast pen. The new west yard edge owns the tree, posts, work spot and approach together.',
 'kapok': 'Kapok Cradle: move idle_spare_1 from the arrival pocket to (−19,−13). Re-author the lodge terrace, its stall and benches with the six-node lodge move; the moved stilt-house approaches on the western/eastern margins still need final stair and headroom checks.'}

# Pass 2: one common internal allocation, rotated with the outer reservation.
# Local u is across the front; v runs from the great door into the castle.
def castle_point(key, u, v):
    x1,z1,x2,z2=P[key]['castle']
    if P[key]['facing']=='south': return [(x1+x2)//2+u,z1+v]
    if P[key]['facing']=='north': return [(x1+x2)//2-u,z2-v]
    return [x2-v,(z1+z2)//2+u]

for key in CAPITALS:
    a=castle_point(key,-17,8); b=castle_point(key,17,30)
    P[key]['room']=[min(a[0],b[0]),min(a[1],b[1]),max(a[0],b[0]),max(a[1],b[1])]
    P[key]['throne']=castle_point(key,0,28)
    P[key]['castle_sockets']={sid:castle_point(key,u,v) for sid,u,v in [
        ('king',0,28),('throne_guard_west',-3,28),('throne_guard_east',3,28),
        ('door_guard_west',-3,3),('door_guard_east',4,3),('hall_waypoint',0,4),
        ('hall_idle_west',-16,12),('hall_idle_east',16,12),('hall_idle_service',-16,25)]}
P['highcourt']['shifts'].update(chapel=[-8,0],north_house=[-8,0],chapel_house=[-8,0])
P['highcourt']['intent']='The service yard and store move eight nodes east; chapel, north house and chapel house move eight west, carrying chapel_quest and leaving its east doors clear. A five-node west bypass now passes between chapel and castle and joins the north gate behind the castle.'

# Explicit destinations for loose points swallowed by new reservations; the
# complete schedule and automatic nearby/owned translations come from export.
P['dur_brannoc']['socket_positions']={'citadel_walk_north':[20,47]}
P['highcourt']['socket_positions']={'core_spare_hall_green':[25,13],
    'core_spare_west_lane':[-27,16],'core_spare_north_court':[20,47]}
P['highcourt']['watch'][0]=[-27,-32]
P['highcourt']['watch'][3]=[34,-31]
P['gor_drazhak']['socket_positions']={'court_work_fire':[45,19],'precinct_walk_north':[-27,46]}
P['nhal_veyr']['socket_positions']={'core_spare_hall_green':[25,13],'core_spare_north_court':[20,47]}
P['lethariel']['socket_positions']={'colonnade_west_idle_a':[-15,-42],
    'colonnade_west_idle_b':[-15,-16],'colonnade_east_idle_a':[-4,-42],'colonnade_east_idle_b':[-4,-16]}
P['kezamba']['socket_positions']={'forecourt_idle':[7,-16]}
P['kezamba']['watch'][2]=[-4,-8]
P['kezamba']['roads'][2]=([0,-12,27,-12,27,-17],5)
P['kezamba']['roads'][3]=([-18,15,-18,26,-1,26,-1,44],3)
P['hearthpine']['roads'][1]=([-17,0,19,0],3)
P['hearthpine']['roads'][3]=([-29,26,0,26],3)


# The radius-48 alternative keeps the same castle but brings it six nodes
# toward the crossing; the three-node bypass then fits before the old north gate.
COMPACT={}
import copy
for key in ['dur_brannoc','highcourt','gor_drazhak','nhal_veyr']:
    q=copy.deepcopy(P[key]);COMPACT[key]=q
    q['castle']=[-22,4,22,38]
    q['room']=[-17,12,17,34]
    q['shifts']={ident:[6,0] for ident in P[key]['shifts']
                 if ident in ['great_forge','smelting_yard','service_yard','service_store',
                              'host_store','beast_shed','bone_works','charnel_yard']}
    q['roads']=[([0,-49,0,3],5),([-49,0,49,0],5),
                ([-27,0,-27,40,27,40,27,0],3),([0,40,0,49],5)]
    q['court']=[-18,3,18,3]
    if key=='highcourt':
        q['shifts']['chapel']=[-8,0]
        q['remove']=['north_house','chapel_house']
COMPACT['highcourt']['shifts']['service_yard']=[6,1]
P['gor_drazhak']['socket_positions'].update(court_work_spar_a=[38,25],court_work_spar_b=[39,25])

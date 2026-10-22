grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:vigil_mausoleum_east
name nhal_veyr_vigil_mausoleum_east
pivot 9 13
origin -1 -1 -1
size 11 11 15
cell 1
meta candles=2 extent=[-1,-1,9,13] peak=7 plinth=0 top=9
races undead

legend
A node grug_decor:xdecor_potted_tulip_black
B node grug_decor:xdecor_potted_viola
C role castle_paving else=R
D role castle_paving else=air
E role castle_wall else=air
F role chimney
G role chimney_cap
H role door variant=_a
I role door_hidden
J role floor
K role foundation
L role hearth o=facedir:1
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role low_wall
R role path
S role plaza
T role plaza_edge
U role post
V role roof_slab
W role roof_slab channel=roof
X role roof_stair channel=roof
Y role roof_stair channel=roof o=facedir:1
Z role roof_stair channel=roof o=facedir:2
a role roof_stair channel=roof o=facedir:3
b role roof_stair_outer channel=roof
c role roof_stair_outer channel=roof o=facedir:1
d role roof_stair_outer channel=roof o=facedir:2
e role roof_stair_outer channel=roof o=facedir:3
f role seat o=facedir:1
g role seat o=facedir:3
h role shelf o=facedir:1
i role shelf o=facedir:3
j role shelf_vessels o=facedir:1
k role shelf_vessels o=facedir:3
l role storage
m role wall
n role wall_accent
o role window
p role window o=facedir:3
q role window_frame
end

layer -1
|           |
|           |
|           |
|           |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|           |
|           |
|           |
|           |
layer 0
|RRRRCCCRRRR|
|RKKKKKKKKKR|
|RKJJJJJJJKR|
|RKJTTTTTJKR|
|RKJTDDDTJKR|
|RKJTQDQTJKR|
|RKJTQDQTJKR|
|RKJTDDDTJKR|
|RKJTQDQTJKR|
|RKJTQDQTJKR|
|RKJKKKKKJKR|
|RKJTTTTTJKR|
|RKJJJJJJJKR|
|RKKKKKKKKKR|
|RRRRRRRRRRR|
layer 1
|...E...E...|
|.UnnnHnnnU.|
|.q......Lq.|
|.n.......nA|
|.ng.....fnB|
|.q..V.V..qA|
|.qg.V.V.fq.|
|.n.......n.|
|.ng.V.V.fn.|
|.q..V.V..q.|
|.q.MGGGM.q.|
|.ni.....hn.|
|.nk.....jn.|
|.qqnnqqnnq.|
|...ABA.l...|
layer 2
|...M...M...|
|.UmmmImmmU.|
|.q......Mq.|
|.p.......p.|
|.p.......p.|
|.q.......q.|
|.q.......q.|
|.p.......p.|
|.p.......p.|
|.q.......q.|
|.q.......q.|
|.p.......p.|
|.p.......p.|
|.qqooqqooq.|
|...........|
layer 3
|...P...P...|
|.UmmmmmmmU.|
|.q......Fq.|
|.p.......p.|
|.p.......p.|
|.qO.....Nq.|
|.q.......q.|
|.p.......p.|
|.p.......p.|
|.q.......q.|
|.qO.....Nq.|
|.p.......p.|
|.p.......p.|
|.qqooqqooq.|
|...........|
layer 4
|cXXXXXXXXXb|
|YUmmmmmmmUa|
|Yq......Fqa|
|Ym.......ma|
|Ym.......ma|
|Yq.......qa|
|Yq.......qa|
|Ym.......ma|
|Ym.......ma|
|Yq.......qa|
|Yq.......qa|
|Ym.......ma|
|Ym.......ma|
|Yqqmmqqmmqa|
|dZZZZZZZZZe|
layer 5
|...........|
|.cXXXXXXXb.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.Y.......a.|
|.dZZZZZZZe.|
|...........|
layer 6
|...........|
|...........|
|..cXXXXXb..|
|..Y.....a..|
|..Y.....a..|
|..Y.....a..|
|..Y.....a..|
|..Y.....a..|
|..Y.....a..|
|..Y.....a..|
|..Y.....a..|
|..Y.....a..|
|..dZZZZZe..|
|...........|
|...........|
layer 7
|...........|
|...........|
|...........|
|...WWWWW...|
|...WWWWW...|
|...WWWWW...|
|...WWWWW...|
|...WWWWW...|
|...WWWWW...|
|...WWWWW...|
|...WWWWW...|
|...WWWWW...|
|...........|
|...........|
|...........|
layer 8
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 4 1 0 face=0
inside 4 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 11
lights 2 3 -1
lights 6 3 -1
lights 2 1 9
lights 6 1 9
lights 7 2 1
lights 1 3 4
lights 7 3 4
lights 1 3 9
lights 7 3 9
lights 2 2 -1
lights 6 2 -1
sockets 4 1 -1 face=0 id={id}_mourn role=idle tags=[door]
end

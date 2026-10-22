grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:vigil_mausoleum_west
name nhal_veyr_vigil_mausoleum_west
pivot 11 13
origin -1 -1 -1
size 13 11 15
cell 1
meta candles=2 extent=[-1,-1,11,13] peak=7 plinth=0 top=9
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
|             |
|             |
|             |
|             |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|             |
|             |
|             |
|             |
layer 0
|RRRRRCCCRRRRR|
|RKKKKKKKKKKKR|
|RKJJJJJJJJJKR|
|RKJTTTTTTTJKR|
|RKJTDDDDDTJKR|
|RKJTQDDDQTJKR|
|RKJTQDDDQTJKR|
|RKJTDDDDDTJKR|
|RKJTQDDDQTJKR|
|RKJTQDDDQTJKR|
|RKJTKKKKKTJKR|
|RKJTTTTTTTJKR|
|RKJJJJJJJJJKR|
|RKKKKKKKKKKKR|
|RRRRRRRRRRRRR|
layer 1
|....E...E....|
|.UnnnnHnqnnq.|
|.q........Lq.|
|.n.........nA|
|.ng.......fnB|
|.q..V...V..qA|
|.qg.V...V.fq.|
|.n.........n.|
|.ng.V...V.fn.|
|.q..V...V..q.|
|.q..MGGGM..q.|
|.ni.......hn.|
|.nk.......jn.|
|.qqnnqqnnqnq.|
|...ABA...l...|
layer 2
|....M...M....|
|.UmmmmImqooq.|
|.q........Mq.|
|.p.........p.|
|.p.........p.|
|.q.........q.|
|.q.........q.|
|.p.........p.|
|.p.........p.|
|.q.........q.|
|.q.........q.|
|.p.........p.|
|.p.........p.|
|.qqooqqooqmq.|
|.............|
layer 3
|....P...P....|
|.Ummmmmmqooq.|
|.q........Fq.|
|.p.........p.|
|.p.........p.|
|.qO.......Nq.|
|.q.........q.|
|.p.........p.|
|.p.........p.|
|.q.........q.|
|.qO.......Nq.|
|.p.........p.|
|.p.........p.|
|.qqooqqooqmq.|
|.............|
layer 4
|cXXXXXXXXXXXb|
|YUmmmmmmqmmqa|
|Yq........Fqa|
|Ym.........ma|
|Ym.........ma|
|Yq.........qa|
|Yq.........qa|
|Ym.........ma|
|Ym.........ma|
|Yq.........qa|
|Yq.........qa|
|Ym.........ma|
|Ym.........ma|
|Yqqmmqqmmqmqa|
|dZZZZZZZZZZZe|
layer 5
|.............|
|.cXXXXXXXXXb.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.Y.........a.|
|.dZZZZZZZZZe.|
|.............|
layer 6
|.............|
|.............|
|..cXXXXXXXb..|
|..Y.......a..|
|..Y.......a..|
|..Y.......a..|
|..Y.......a..|
|..Y.......a..|
|..Y.......a..|
|..Y.......a..|
|..Y.......a..|
|..Y.......a..|
|..dZZZZZZZe..|
|.............|
|.............|
layer 7
|.............|
|.............|
|.............|
|...WWWWWWW...|
|...WWWWWWW...|
|...WWWWWWW...|
|...WWWWWWW...|
|...WWWWWWW...|
|...WWWWWWW...|
|...WWWWWWW...|
|...WWWWWWW...|
|...WWWWWWW...|
|.............|
|.............|
|.............|
layer 8
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 9
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|

points
doors 5 1 0 face=0
inside 5 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 9 0 11
lights 3 3 -1
lights 7 3 -1
lights 3 1 9
lights 7 1 9
lights 9 2 1
lights 1 3 4
lights 9 3 4
lights 1 3 9
lights 9 3 9
lights 3 2 -1
lights 7 2 -1
sockets 5 1 -1 face=0 id={id}_mourn role=idle tags=[door]
end

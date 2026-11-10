grudgelands-building-template 1
# Frozen from the building generators (Round 56): stillgrave:warden_house
name stillgrave_warden_house
pivot 11 9
origin -1 0 -2
size 13 11 12
cell 1
meta peak=8
races undead

legend
A node grug_decor:xdecor_potted_tulip_black
B node grug_decor:xdecor_potted_viola
C role bed variant=_bottom
D role bed variant=_top
E role chimney
F role chimney_cap
G role door variant=_a
H role door_hidden
I role floor
J role foundation
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
Q role post
R role roof_slab
S role roof_stair
T role roof_stair o=facedir:1
U role roof_stair o=facedir:2
V role roof_stair o=facedir:3
W role roof_stair_outer
X role roof_stair_outer o=facedir:1
Y role roof_stair_outer o=facedir:2
Z role roof_stair_outer o=facedir:3
a role rug
b role rug_accent
c role seat
d role seat o=facedir:2
e role seat o=facedir:3
f role shelf o=facedir:1
g role shelf o=facedir:3
h role shelf_vessels o=facedir:1
i role storage
j role storage o=facedir:3
k role table_leg
l role table_top
m role wall
n role wall_accent
o role window
p role window o=facedir:3
q role window_frame
end

layer 0
|             |
|PPPPPPPPPPPPP|
|PJJJJJJJJJJJP|
|PJIIIIIIIbIJP|
|PJIIIIIIIbIJP|
|PJIIIaaIIIIJP|
|PJIIIaaIIIIJP|
|PJIIIIIIIIIJP|
|PJIIIIIIIIIJP|
|PJIIIIIIIIIJP|
|PJJJJJJJJJJJP|
|PPPPPPPPPPPPP|
layer 1
|             |
|....B....BA..|
|.QnnnnGnqnnq.|
|.qC.......KE.|
|.nD......e.nB|
|.nj...d....nA|
|.qg...kk...qB|
|.q....c....q.|
|.n........fni|
|.n........hn.|
|.qqnnqqnnqnq.|
|.............|
layer 2
|             |
|.............|
|.QmmmmHmqooq.|
|.q........LE.|
|.p.........p.|
|.p.........p.|
|.qg...ll...q.|
|.q.........q.|
|.p........hp.|
|.p.........p.|
|.qqooqqooqmq.|
|.............|
layer 3
|             |
|....O...O....|
|.Qmmmmmmqooq.|
|.q........EE.|
|.p.........p.|
|.p.........p.|
|.qN.......Mq.|
|.q.........q.|
|.p.........p.|
|.p.........p.|
|.qqooqqooqmq.|
|.............|
layer 4
|             |
|.............|
|.Qmmmmmmqmmq.|
|.q........EE.|
|.m.........m.|
|.m.........m.|
|.q.........q.|
|.q.........q.|
|.m.........m.|
|.m.........m.|
|.qqmmqqmmqmq.|
|.............|
layer 5
|             |
|XSSSSSSSSSSSW|
|TQmmmmmmqmmqV|
|Tq........EEV|
|Tm.........mV|
|Tm.........mV|
|Tq.........qV|
|Tq.........qV|
|Tm.........mV|
|Tm.........mV|
|TqqmmqqmmqmqV|
|YUUUUUUUUUUUZ|
layer 6
|             |
|.............|
|.XSSSSSSSSSW.|
|.T.........E.|
|.T.........V.|
|.T.........V.|
|.T.........V.|
|.T.........V.|
|.T.........V.|
|.T.........V.|
|.YUUUUUUUUUZ.|
|.............|
layer 7
|             |
|.............|
|.............|
|..XSSSSSSSWE.|
|..T.......V..|
|..T.......V..|
|..T.......V..|
|..T.......V..|
|..T.......V..|
|..YUUUUUUUZ..|
|.............|
|.............|
layer 8
|             |
|.............|
|.............|
|...........E.|
|...RRRRRRR...|
|...RRRRRRR...|
|...RRRRRRR...|
|...RRRRRRR...|
|...RRRRRRR...|
|.............|
|.............|
|.............|
layer 9
|             |
|.............|
|.............|
|...........E.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 10
|             |
|.............|
|.............|
|...........F.|
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
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 9 0 7
lights 3 3 -1
lights 7 3 -1
lights 9 2 1
lights 1 3 4
lights 9 3 4
sockets 5 1 -2 face=0 id=idle_warden_door
end

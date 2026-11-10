grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:orchard_house
name highcourt_orchard_house
pivot 9 9
origin -1 0 -1
size 11 14 11
cell 1
meta extent=[-1,-1,9,9] peak=11 top=13
races human

legend
A role bed variant=_bottom
B role bed variant=_top
C role chimney
D role chimney_cap
E role door variant=_a
F role door_hidden
G role floor
H role foundation
I role hearth o=facedir:1
J role light_post o=wallmounted:1
K role light_wall o=wallmounted:2
L role light_wall o=wallmounted:3
M role light_wall o=wallmounted:4
N role path
O role post
P role roof_slab
Q role roof_stair
R role roof_stair o=facedir:2
S role rug
T role rug_accent
U role seat
V role seat o=facedir:2
W role seat o=facedir:3
X role shelf o=facedir:1
Y role shelf o=facedir:3
Z role shelf_vessels o=facedir:1
a role shutter else=air
b role shutter o=facedir:1 else=air
c role shutter o=facedir:2 else=air
d role shutter o=facedir:3 else=air
e role storage o=facedir:3
f role table_leg
g role table_top
h role wall_accent
i role wall_infill else=air
j role window
k role window o=facedir:3
l role window_frame
end

layer 0
|NNNNNNNNNNN|
|NHHHHHHHHHN|
|NHGGGGGTGHN|
|NHGGGGGTGHN|
|NHGGSSGGGHN|
|NHGGSSGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHHHHHHHHHN|
|NNNNNNNNNNN|
layer 1
|...........|
|.OhEhhlhhl.|
|.lA.....IC.|
|.hB....W.h.|
|.he..V...h.|
|.lY..ff..l.|
|.l...U...l.|
|.h......Xh.|
|.h......Zh.|
|.llhhllhhl.|
|...........|
layer 2
|.......aa..|
|.OiFOiljjl.|
|.l......JC.|
|bk.......kd|
|bk.......kd|
|.lY..gg..l.|
|.l.......l.|
|bk......Zkd|
|bk.......kd|
|.lljjlljjl.|
|...cc..cc..|
layer 3
|.M...M.aa..|
|.OiiOiljjl.|
|.l......CC.|
|bk.......kd|
|bk.......kd|
|.lL.....Kl.|
|.l.......l.|
|bk.......kd|
|bk.......kd|
|.lljjlljjl.|
|...cc..cc..|
layer 4
|...........|
|.OiiOilOil.|
|.l......CC.|
|.i.......i.|
|.O.......O.|
|.l.......l.|
|.l.......l.|
|.O.......O.|
|.i.......i.|
|.lliOllOil.|
|...........|
layer 5
|...........|
|.OiiOilOil.|
|.l......CC.|
|.i.......i.|
|.O.......O.|
|.l.......l.|
|.l.......l.|
|.O.......O.|
|.i.......i.|
|.lliOllOil.|
|RRRRRRRRRRR|
layer 6
|...........|
|.OiiOiiOiO.|
|.i.......C.|
|.i.......i.|
|.O.......O.|
|.i.......i.|
|.i.......i.|
|.O.......O.|
|.i.......i.|
|RRRRRRRRRRR|
|...........|
layer 7
|QQQQQQQQQQQ|
|.OiiOiiOiO.|
|.i.......C.|
|.i.......i.|
|.O.......O.|
|.i.......i.|
|.i.......i.|
|.O.......O.|
|RRRRRRRRRRR|
|...........|
|...........|
layer 8
|...........|
|QQQQQQQQQQQ|
|.i.......C.|
|.i.......i.|
|.O.......O.|
|.i.......i.|
|.i.......i.|
|RRRRRRRRRRR|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|QQQQQQQQQCQ|
|.i.......i.|
|.O.......O.|
|.i.......i.|
|RRRRRRRRRRR|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........C.|
|QQQQQQQQQQQ|
|.O.......O.|
|RRRRRRRRRRR|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 11
|...........|
|...........|
|.........C.|
|...........|
|PPPPPPPPPPP|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|.........C.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 13
|...........|
|...........|
|.........D.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 2 1 0 face=0
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 7 0 7
lights 0 3 -1
lights 4 3 -1
lights 7 2 1
lights 1 3 4
lights 7 3 4
end

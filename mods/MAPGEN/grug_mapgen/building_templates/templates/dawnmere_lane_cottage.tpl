grudgelands-building-template 1
# Frozen from the building generators (Round 56): dawnmere:lane_cottage
name dawnmere_lane_cottage
pivot 9 9
origin -1 0 -1
size 11 11 11
cell 1
meta peak=8
races human

legend
A role bed variant=_bottom
B role bed variant=_top
C role bed_fancy variant=_bottom else=A
D role bed_fancy variant=_top else=B
E role chimney
F role chimney_cap
G role door variant=_a o=facedir:2
H role door_hidden o=facedir:2
I role floor
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:5
P role path
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
l role storage
m role storage o=facedir:3
n node grug_decor:xdecor_table
q role wall_accent
r role window
s role window o=facedir:3
J role facade_home_base
Q role facade_frame
i role facade_infill
end

layer 0
|PPPPPPPPPPP|
|PJJJJJJJJJP|
|PJIIIIIbIJP|
|PJIIIIIbIJP|
|PJIIaaIIIJP|
|PJIIaaIIIJP|
|PJIIIIIIIJP|
|PJIIIIIIIJP|
|PJIIIIIIIJP|
|PJJJJJJJJJP|
|PPPPPPPPPPP|
layer 1
|...........|
|.JJqqJJqqJ.|
|.JC.....KE.|
|.qD....e.q.|
|.qm..d...q.|
|.Jg..nn..J.|
|.J...c...J.|
|.q......fq.|
|.q......hq.|
|.JqqqGqqqJ.|
|.......l...|
layer 2
|...........|
|.QirriirrQ.|
|.i......LE.|
|.s.......s.|
|.s.......s.|
|.ig......i.|
|.i.......i.|
|.s......hs.|
|.s.......s.|
|.QiiiHiiiQ.|
|.......l...|
layer 3
|...........|
|.QirriirrQ.|
|.i......EE.|
|.s.......s.|
|.s.......s.|
|.iN.....Mi.|
|.i.......i.|
|.s.......s.|
|.s.......s.|
|.QiiiQiiiQ.|
|...O...O...|
layer 4
|...........|
|.QQQQQQQQQ.|
|.Q......EE.|
|.Q.......Q.|
|.Q.......Q.|
|.Q.......Q.|
|.Q.......Q.|
|.Q.......Q.|
|.Q.......Q.|
|.QQQQQQQQQ.|
|...........|
layer 5
|XSSSSSSSSSW|
|TQQQQQQQQQV|
|TQ......EEV|
|TQ.......QV|
|TQ.......QV|
|TQ.......QV|
|TQ.......QV|
|TQ.......QV|
|TQ.......QV|
|TQQQQQQQQQV|
|YUUUUUUUUUZ|
layer 6
|...........|
|.XSSSSSSSW.|
|.T.......E.|
|.T.......V.|
|.T.......V.|
|.T.......V.|
|.T.......V.|
|.T.......V.|
|.T.......V.|
|.YUUUUUUUZ.|
|...........|
layer 7
|...........|
|...........|
|..XSSSSSWE.|
|..T.....V..|
|..T.....V..|
|..T.....V..|
|..T.....V..|
|..T.....V..|
|..YUUUUUZ..|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........E.|
|...RRRRR...|
|...RRRRR...|
|...RRRRR...|
|...RRRRR...|
|...RRRRR...|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........E.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........F.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 4 1 8 face=2
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 7 0 7
lights 2 3 9
lights 6 3 9
lights 7 2 1
lights 1 3 4
lights 7 3 4
end

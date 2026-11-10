grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:lane_house
name highcourt_lane_house
pivot 9 9
origin -1 0 -1
size 11 11 11
cell 1
meta extent=[-1,-1,9,9] peak=8 top=10
races human

legend
A role bed variant=_bottom
B role bed variant=_top
C role bed_fancy variant=_bottom else=A
D role bed_fancy variant=_top else=B
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
i role storage o=facedir:3
j role table_leg
k role table_top
l role wall_accent
m role wall_infill else=air
n role window
o role window o=facedir:3
p role window_frame
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
|.QlGllpllp.|
|.pC.....KE.|
|.lD....e.l.|
|.li..d...l.|
|.pg..jj..p.|
|.p...c...p.|
|.l......fl.|
|.l......hl.|
|.ppllppllp.|
|...........|
layer 2
|...........|
|.QmHQmpnnp.|
|.p......LE.|
|.o.......o.|
|.o.......o.|
|.pg..kk..p.|
|.p.......p.|
|.o......ho.|
|.o.......o.|
|.ppnnppnnp.|
|...........|
layer 3
|.O...O.....|
|.QmmQmpnnp.|
|.p......EE.|
|.o.......o.|
|.o.......o.|
|.pN.....Mp.|
|.p.......p.|
|.o.......o.|
|.o.......o.|
|.ppnnppnnp.|
|...........|
layer 4
|...........|
|.QmmQmpQmp.|
|.p......EE.|
|.m.......m.|
|.Q.......Q.|
|.p.......p.|
|.p.......p.|
|.Q.......Q.|
|.m.......m.|
|.ppmQppQmp.|
|...........|
layer 5
|XSSSSSSSSSW|
|TQmmQmpQmpV|
|Tp......EEV|
|Tm.......mV|
|TQ.......QV|
|Tp.......pV|
|Tp.......pV|
|TQ.......QV|
|Tm.......mV|
|TppmQppQmpV|
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

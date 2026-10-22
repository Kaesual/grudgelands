grudgelands-building-template 1
# Frozen from the building generators (Round 56): hearthpine:east_home
name hearthpine_east_home
pivot 11 9
origin -1 0 -1
size 13 10 11
cell 1
meta peak=7
races dwarf

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
l role wall
m role wall_accent
n role window
o role window o=facedir:3
p role window_frame
end

layer 0
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
|.............|
|.QmmGmpmmpmQ.|
|.pC.......KE.|
|.mD......e.m.|
|.mi...d....m.|
|.pg...jj...p.|
|.p....c....p.|
|.m........fm.|
|.m........hm.|
|.ppmmppmmpmp.|
|.............|
layer 2
|.............|
|.QllHlpnnplQ.|
|.p........LE.|
|.o.........o.|
|.o.........o.|
|.pg...kk...p.|
|.p.........p.|
|.o........ho.|
|.o.........o.|
|.ppnnppnnplp.|
|.............|
layer 3
|..O...O......|
|.QllllpnnplQ.|
|.p........EE.|
|.o.........o.|
|.o.........o.|
|.pN.......Mp.|
|.p.........p.|
|.o.........o.|
|.o.........o.|
|.ppnnppnnplp.|
|.............|
layer 4
|XSSSSSSSSSSSW|
|TQllllpllplQV|
|Tp........EEV|
|Tl.........lV|
|Tl.........lV|
|Tp.........pV|
|Tp.........pV|
|Tl.........lV|
|Tl.........lV|
|TppllppllplpV|
|YUUUUUUUUUUUZ|
layer 5
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
layer 6
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
layer 7
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
layer 8
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
layer 9
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
doors 3 1 0 face=0
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 9 0 7
lights 1 3 -1
lights 5 3 -1
lights 9 2 1
lights 1 3 4
lights 9 3 4
end

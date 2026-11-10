grudgelands-building-template 1
# Frozen from the building generators (Round 56): dawnmere:tollhouse, silverleaf:gate_lookout
name dawnmere_tollhouse
pivot 9 9
origin -1 0 -1
size 11 13 11
cell 1
meta peak=12
races human elf

legend
A role beam
B role bed variant=_bottom
C role bed variant=_top
D role door variant=_a o=facedir:1
E role door_hidden o=facedir:1
F role floor
G role flower_alt else=air
H role foundation
I role light_post o=wallmounted:1
J role light_wall o=wallmounted:2
K role light_wall o=wallmounted:3
L role path
M role post
N role railing
O role roof_slab channel=roof
P role roof_stair
Q role roof_stair channel=roof
R role roof_stair channel=roof o=facedir:1
S role roof_stair channel=roof o=facedir:2
T role roof_stair channel=roof o=facedir:3
U role roof_stair_outer channel=roof
V role roof_stair_outer channel=roof o=facedir:1
W role roof_stair_outer channel=roof o=facedir:2
X role roof_stair_outer channel=roof o=facedir:3
Y role seat
Z role seat o=facedir:2
a role storage
b role storage o=facedir:1
c role table_leg
d role table_top
e role wall
f role wall_accent
g role window
h role window o=facedir:3
i role window_frame
end

layer 0
|LLLLLLLLLLL|
|LHHHHHHHHHL|
|LHFFFFFFFHL|
|LHFFFFFFFHL|
|LHFFFFFFFHL|
|LHFFFFFFFHL|
|LHFFFFFFFHL|
|LHFFFFFFFHL|
|LHFFFFFFFHL|
|LHHHHHHHHHL|
|LLLLLLLLLLL|
layer 1
|.......a...|
|.MifififiM.|
|.iB.....bi.|
|GfCP.....f.|
|.i.......i.|
|.D.......f.|
|.i.....Z.i.|
|.f.....ccf.|
|.i.....Y.i.|
|.MifififiM.|
|...........|
layer 2
|...........|
|.MifififiM.|
|.i.......i.|
|.f.......f.|
|.i.P.....i.|
|.E.......f.|
|.i.......i.|
|.f.....ddf.|
|.i.......i.|
|.MifififiM.|
|...........|
layer 3
|...........|
|.MigieigiM.|
|Ji.......i.|
|.h.......h.|
|.i.......i.|
|.eKP.....e.|
|.i.......i.|
|.h.......h.|
|Ji.......i.|
|.MigieigiM.|
|...........|
layer 4
|...........|
|.MigieigiM.|
|.i.......i.|
|.h.......h.|
|.i.......i.|
|.e.......e.|
|.i.P.....i.|
|.h.......h.|
|.i.......i.|
|.MigieigiM.|
|...........|
layer 5
|...........|
|.FFFFFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FFPFFFFFF.|
|.FFFFFFFFF.|
|.FFFFFFFFF.|
|...........|
layer 6
|...........|
|.fffffffff.|
|.fI.....If.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.fI.....If.|
|.fffffffff.|
|...........|
layer 7
|...........|
|.M.N.N.N.M.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.M.N.N.N.M.|
|...........|
layer 8
|VQQQQQQQQQU|
|RAAAAAAAAAT|
|RA.......AT|
|RA.......AT|
|RA.......AT|
|RA.......AT|
|RA.......AT|
|RA.......AT|
|RA.......AT|
|RAAAAAAAAAT|
|WSSSSSSSSSX|
layer 9
|...........|
|.VQQQQQQQU.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.WSSSSSSSX.|
|...........|
layer 10
|...........|
|...........|
|..VQQQQQU..|
|..R.....T..|
|..R.....T..|
|..R.....T..|
|..R.....T..|
|..R.....T..|
|..WSSSSSX..|
|...........|
|...........|
layer 11
|...........|
|...........|
|...........|
|...VQQQU...|
|...R...T...|
|...R...T...|
|...R...T...|
|...WSSSX...|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|...........|
|...........|
|....OOO....|
|....OOO....|
|....OOO....|
|...........|
|...........|
|...........|
|...........|

points
doors 0 1 4 face=1
inside 5 6 4 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 7
lights -1 3 1
lights -1 3 7
lights 1 3 4
lights 1 6 1
lights 7 6 1
lights 1 6 7
lights 7 6 7
end

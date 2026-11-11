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
B role bed variant=_bottom
C role bed variant=_top
D role door variant=_a o=facedir:1
E role door_hidden o=facedir:1
F role floor
G role flower_alt else=air
I role light_post o=wallmounted:1
J role light_wall o=wallmounted:2
K role light_wall o=wallmounted:3
L role path
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
c node grug_decor:xdecor_table
g role window
h role window o=facedir:3
A role facade_base
H role facade_frame
M role facade_infill
d role facade_band
end

layer 0
|LLLLLLLLLLL|
|LAAAAAAAAAL|
|LAFFFFFFFAL|
|LAFFFFFFFAL|
|LAFFFFFFFAL|
|LAFFFFFFFAL|
|LAFFFFFFFAL|
|LAFFFFFFFAL|
|LAFFFFFFFAL|
|LAAAAAAAAAL|
|LLLLLLLLLLL|
layer 1
|.......a...|
|.AAAAAAAAA.|
|.AB.....bA.|
|GACP.....A.|
|.A.......A.|
|.D.......A.|
|.A.....Z.A.|
|.A.....ccA.|
|.A.....Y.A.|
|.AAAAAAAAA.|
|...........|
layer 2
|...........|
|.HMMMHMMMH.|
|.M.......M.|
|.M.......M.|
|.H.P.....M.|
|.E.......H.|
|.M.......M.|
|.M.......M.|
|.M.......M.|
|.HMMMHMMMH.|
|...........|
layer 3
|...........|
|.HMgMHMgMH.|
|JM.......M.|
|.h.......h.|
|.H.......M.|
|.MKP.....H.|
|.M.......M.|
|.h.......h.|
|JM.......M.|
|.HMgMHMgMH.|
|...........|
layer 4
|...........|
|.ddgdddgdd.|
|.d.......d.|
|.h.......h.|
|.d.......d.|
|.d.......d.|
|.d.P.....d.|
|.h.......h.|
|.d.......d.|
|.ddgdddgdd.|
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
|.HMMMMMMMH.|
|.MI.....IM.|
|.M.......M.|
|.M.......M.|
|.M.......M.|
|.M.......M.|
|.M.......M.|
|.MI.....IM.|
|.HMMMMMMMH.|
|...........|
layer 7
|...........|
|.H.N.N.N.H.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.H.N.N.N.H.|
|...........|
layer 8
|VQQQQQQQQQU|
|RdddddddddT|
|Rd.......dT|
|Rd.......dT|
|Rd.......dT|
|Rd.......dT|
|Rd.......dT|
|Rd.......dT|
|Rd.......dT|
|RdddddddddT|
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

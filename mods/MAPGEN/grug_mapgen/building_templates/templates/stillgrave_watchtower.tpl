grudgelands-building-template 1
# Frozen from the building generators (Round 56): stillgrave:watchtower
name stillgrave_watchtower
pivot 9 9
origin -1 0 -1
size 11 13 11
cell 1
meta peak=12
races undead

legend
B role bed variant=_bottom
C role bed variant=_top
D role door variant=_a o=facedir:1
E role door_hidden o=facedir:1
F role floor
H role light_post o=wallmounted:1
I role light_wall o=wallmounted:2
J role light_wall o=wallmounted:3
K role path
M role railing
N role roof_slab
O role roof_stair
P role roof_stair o=facedir:1
Q role roof_stair o=facedir:2
R role roof_stair o=facedir:3
S role roof_stair_outer
T role roof_stair_outer o=facedir:1
U role roof_stair_outer o=facedir:2
V role roof_stair_outer o=facedir:3
W role seat
X role seat o=facedir:2
Y role storage
Z role storage o=facedir:1
a node grug_decor:xdecor_table
d role wall_accent
e role window
f role window o=facedir:3
A role facade_base
G role facade_frame
L role facade_infill
end

layer 0
|KKKKKKKKKKK|
|KAAAAAAAAAK|
|KAFFFFFFFAK|
|KAFFFFFFFAK|
|KAFFFFFFFAK|
|KAFFFFFFFAK|
|KAFFFFFFFAK|
|KAFFFFFFFAK|
|KAFFFFFFFAK|
|KAAAAAAAAAK|
|KKKKKKKKKKK|
layer 1
|...........|
|.AAdAdAdAA.|
|.AB.....ZA.|
|.dCO.....d.|
|.A.......A.|
|.D.......d.|
|.A.....X.A.|
|Yd.....aadY|
|.A.....W.A.|
|.AAdAdAdAA.|
|...........|
layer 2
|...........|
|.GLLLGLLLG.|
|.L.......L.|
|.L.......L.|
|.G.O.....L.|
|.E.......G.|
|.L.......L.|
|YL.......L.|
|.L.......L.|
|.GLLLGLLLG.|
|...........|
layer 3
|...........|
|.GLeLGLeLG.|
|IL.......L.|
|.f.......f.|
|.G.......L.|
|.LJO.....G.|
|.L.......L.|
|.f.......f.|
|IL.......L.|
|.GLeLGLeLG.|
|...........|
layer 4
|...........|
|.GGeGGGeGG.|
|.G.......G.|
|.f.......f.|
|.G.......G.|
|.G.......G.|
|.G.O.....G.|
|.f.......f.|
|.G.......G.|
|.GGeGGGeGG.|
|...........|
layer 5
|...........|
|.FFFFFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FFOFFFFFF.|
|.FFFFFFFFF.|
|.FFFFFFFFF.|
|...........|
layer 6
|...........|
|.GLLLLLLLG.|
|.LH.....HL.|
|.L.......L.|
|.L.......L.|
|.L.......L.|
|.L.......L.|
|.L.......L.|
|.LH.....HL.|
|.GLLLLLLLG.|
|...........|
layer 7
|...........|
|.G.M.M.M.G.|
|...........|
|.M.......M.|
|...........|
|.M.......M.|
|...........|
|.M.......M.|
|...........|
|.G.M.M.M.G.|
|...........|
layer 8
|TOOOOOOOOOS|
|PGGGGGGGGGR|
|PG.......GR|
|PG.......GR|
|PG.......GR|
|PG.......GR|
|PG.......GR|
|PG.......GR|
|PG.......GR|
|PGGGGGGGGGR|
|UQQQQQQQQQV|
layer 9
|...........|
|.TOOOOOOOS.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.UQQQQQQQV.|
|...........|
layer 10
|...........|
|...........|
|..TOOOOOS..|
|..P.....R..|
|..P.....R..|
|..P.....R..|
|..P.....R..|
|..P.....R..|
|..UQQQQQV..|
|...........|
|...........|
layer 11
|...........|
|...........|
|...........|
|...TOOOS...|
|...P...R...|
|...P...R...|
|...P...R...|
|...UQQQV...|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|...........|
|...........|
|....NNN....|
|....NNN....|
|....NNN....|
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

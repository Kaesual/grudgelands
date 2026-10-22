grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:warren_house_bone
name gor_drazhak_warren_house_bone
pivot 9 11
origin -1 0 -1
size 11 9 13
cell 1
meta extent=[-1,-1,9,11] parapet_columns=44 peak=6 top=8
races orc

legend
A node grug_decor:xdecor_potted_rose
B node grug_decor:xdecor_potted_tulip
C role bed variant=_bottom
D role bed variant=_top
E role bed_fancy variant=_bottom else=C
F role bed_fancy variant=_top else=D
G role chimney
H role chimney_cap
I role door variant=_a
J role door_hidden
K role floor
L role foundation
M role hearth o=facedir:1
N role light_post o=wallmounted:1
O role light_wall o=wallmounted:2
P role light_wall o=wallmounted:3
Q role light_wall o=wallmounted:4
R role low_wall
S role path
T role post
U role roof_ridge
V role roof_slab
W role rug
X role rug_accent
Y role seat
Z role seat o=facedir:2
a role seat o=facedir:3
b role shelf o=facedir:1
c role shelf o=facedir:3
d role shelf_vessels o=facedir:1
e role signature else=air
f role storage o=facedir:3
g role table_leg
h role table_top
i role tree_log
j role wall_accent
k role wall_infill else=air
l role window
m role window o=facedir:3
n role window_frame
end

layer 0
|SSSSSSSSSSS|
|SLLLLLLLLLS|
|SLKKKKKXKLS|
|SLKKKKKXKLS|
|SLKKKKKKKLS|
|SLKKWWKKKLS|
|SLKKWWKKKLS|
|SLKKKKKKKLS|
|SLKKKKKKKLS|
|SLKKKKKKKLS|
|SLKKKKKKKLS|
|SLLLLLLLLLS|
|SSSSSSSSSSS|
layer 1
|.......AB..|
|.TjIjjnjjn.|
|.nE.....MG.|
|.jF....a.jA|
|.jf......jB|
|.nc..Z...nA|
|.n...gg..n.|
|.j...Y...j.|
|.j.......j.|
|in......bn.|
|ij......dj.|
|.Tnjjnnjjn.|
|...........|
layer 2
|...........|
|.TkJTknlln.|
|.n......NG.|
|.m.......m.|
|.m.......m.|
|.nc......n.|
|.n...hh..n.|
|.m.......m.|
|.m.......m.|
|in......dn.|
|iT.......T.|
|.Tnllnnlln.|
|...........|
layer 3
|.Q...Q.....|
|.TkkTknlln.|
|.n......GG.|
|.m.......m.|
|.m.......m.|
|.n.......n.|
|.nP.....On.|
|.m.......m.|
|.m.......m.|
|Vn.......n.|
|VT.......T.|
|.Tnllnnlln.|
|...........|
layer 4
|...........|
|.TkkTknTkn.|
|.n......GG.|
|.k.......k.|
|.T.......T.|
|.n.......n.|
|.n.......n.|
|.T.......T.|
|.k.......k.|
|.n.......n.|
|.T.......T.|
|.TnkTnnTkn.|
|...........|
layer 5
|...........|
|.TkkTknTkn.|
|.n......GG.|
|.k.......k.|
|.T.......T.|
|.n.......n.|
|.n.......n.|
|.T.......T.|
|.k.......k.|
|.n.......n.|
|.T.......T.|
|.TnkTnnTkn.|
|...........|
layer 6
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUGU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
|UUUUUUUUUUU|
layer 7
|RRRRRRRRRRR|
|R.........R|
|R........GR|
|R.........R|
|R.........R|
|R.........R|
|R.........R|
|R.........R|
|R.........R|
|R.........R|
|R.........R|
|R.........R|
|RRRRRRRRRRR|
layer 8
|.e.e.e.e.e.|
|e.........e|
|.........H.|
|e.........e|
|...........|
|e.........e|
|...........|
|e.........e|
|...........|
|e.........e|
|...........|
|e.........e|
|.e.e.e.e.e.|

points
doors 2 1 0 face=0
inside 2 1 8 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 7 0 9
lights 0 3 -1
lights 4 3 -1
lights 7 2 1
lights 1 3 5
lights 7 3 5
end

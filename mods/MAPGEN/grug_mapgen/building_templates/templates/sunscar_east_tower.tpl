grudgelands-building-template 1
# Frozen from the building generators (Round 56): sunscar:east_tower
name sunscar_east_tower
pivot 9 9
origin -1 0 -1
size 11 10 11
cell 1
meta peak=9
races orc

legend
A node grug_decor:xdecor_potted_rose
C role bed variant=_bottom
D role bed variant=_top
E role door variant=_a o=facedir:1
F role door_hidden o=facedir:1
G role floor
I role light_post o=wallmounted:1
J role light_wall o=wallmounted:2
K role light_wall o=wallmounted:3
L role path
N role railing
O role roof_ridge
P role roof_stair
Q role seat
R role seat o=facedir:2
S role storage
T role storage o=facedir:1
U node grug_decor:xdecor_table
W role wall
X role wall_accent
Y role window
Z role window o=facedir:3
B role facade_base
H role facade_frame
M role facade_infill
V role facade_roof_ridge
end

layer 0
|LLLLLLLLLLL|
|LBBBBBBBBBL|
|LBGGGGGGGBL|
|LBGGGGGGGBL|
|LBGGGGGGGBL|
|LBGGGGGGGBL|
|LBGGGGGGGBL|
|LBGGGGGGGBL|
|LBGGGGGGGBL|
|LBBBBBBBBBL|
|LLLLLLLLLLL|
layer 1
|.......S...|
|.BBXBXBXBB.|
|.BC.....TB.|
|.XDP.....X.|
|.B.......B.|
|.E.......X.|
|.B.....R.B.|
|AX.....UUX.|
|.B.....Q.B.|
|.BBXBXBXBB.|
|...........|
layer 2
|...........|
|.HMMMHMMMH.|
|.M.......M.|
|.M.......M.|
|.H.P.....M.|
|.F.......H.|
|.M.......M.|
|.M.......M.|
|.M.......M.|
|.HMMMHMMMH.|
|...........|
layer 3
|...........|
|.HMYMHMYMH.|
|JM.......M.|
|.Z.......Z.|
|.H.......M.|
|.WKP.....H.|
|.M.......M.|
|.Z.......Z.|
|JM.......M.|
|.HMYMHMYMH.|
|...........|
layer 4
|...........|
|.HBYBHBYBH.|
|.B.......B.|
|.Z.......Z.|
|.H.......B.|
|.B.......H.|
|.B.P.....B.|
|.Z.......Z.|
|.B.......B.|
|.HBYBHBYBH.|
|...........|
layer 5
|...........|
|.GGGGGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GGPGGGGGG.|
|.GGGGGGGGG.|
|.GGGGGGGGG.|
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
|...........|
|.BBBBBBBBB.|
|.B.......B.|
|.B.......B.|
|.B.......B.|
|.B.......B.|
|.B.......B.|
|.B.......B.|
|.B.......B.|
|.BBBBBBBBB.|
|...........|
layer 9
|OOOOOOOOOOO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OVVVVVVVVVO|
|OOOOOOOOOOO|

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

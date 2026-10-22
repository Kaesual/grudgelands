grudgelands-building-template 1
# Frozen from the building generators (Round 56): stillgrave:hollow_ruin
name stillgrave_hollow_ruin
pivot 9 9
origin -1 0 -1
size 11 9 11
cell 1
meta cobwebs=2 ivy=6 peak=6 standing=24
races undead

legend
A node grug_nodes:bone_pile o=facedir:1
B node grug_nodes:bone_pile o=facedir:3
C node grug_nodes:skull_horned o=facedir:2
D role cobweb else=air
E role floor
F role foundation
G role grass_tuft
H role ivy o=wallmounted:2 else=air
I role ivy o=wallmounted:3 else=air
J role ivy o=wallmounted:4 else=air
K role ivy o=wallmounted:5 else=air
L role path
M role post
N role rubble
O role wall
P role wall_accent
end

layer 0
|LLLLLLLLLLL|
|LFFFFFFFFFL|
|LFEEEEEEEFL|
|LFEEEEEEEFL|
|LFEEEEEEEFL|
|LFEEEEEEEFL|
|LFNNNNNNNFL|
|LFEEEEEEEFL|
|LFEEEEEEEFL|
|LFFFFFFFFFL|
|LLLLLLLLLLL|
layer 1
|...........|
|.M..PPPPPM.|
|....N....P.|
|........NP.|
|.P.N.GCN.P.|
|.PN...N..P.|
|.P.......P.|
|.P...N.GB..|
|.PGAN...N..|
|.MPPPPP..M.|
|...........|
layer 2
|...........|
|.M..OOOOOM.|
|.........O.|
|.........O.|
|.......N.O.|
|..N......O.|
|.........O.|
|.OI........|
|.O.JN......|
|.OOO.....M.|
|...........|
layer 3
|...........|
|....OOOOOM.|
|.........O.|
|.........O.|
|.........O.|
|.........O.|
|.........O.|
|.O.........|
|.O.........|
|.OOO.....M.|
|...........|
layer 4
|...........|
|....OOOOOM.|
|.......K.O.|
|........HO.|
|.........O.|
|.........O.|
|.........O.|
|...........|
|...........|
|.........M.|
|...........|
layer 5
|...........|
|....OOOOOM.|
|....K....O.|
|.........O.|
|.........O.|
|.........O.|
|........HO.|
|...........|
|...........|
|.........M.|
|...........|
layer 6
|...........|
|....OOO..M.|
|.....D.....|
|...........|
|.........O.|
|........DO.|
|.........O.|
|...........|
|...........|
|.........M.|
|...........|
layer 7
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 8
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
room_corner 1 0 1 closed=false id={id} ruin=true top=6
room_corner 7 0 7
end

grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:bough_west, lethariel:martial_bough
name lethariel_bough_west
pivot 11 11
origin 0 0 0
size 11 15 11
cell 1
meta extent=[0,0,10,10] peak=11 rails=26 steps=7 top=14
races elf

legend
A role beam
B role floor
C role grass_tuft
D role ground
E role light_wall o=wallmounted:5
F role path
G role railing
H role signature else=C
I role signature else=D
J role signature else=air
K role signature_slab else=air
L role signature_stair o=facedir:2 else=air
M role tree_log
N role undergrowth
O role wall
P role window o=facedir:3
end

layer 0
|DDDDDDDDDDD|
|DDDDDDDDDDD|
|DDDDDDDDDID|
|DDDFFFFFDID|
|DDDFFFFFDID|
|DDDFFFFFDID|
|DDDFFFFFDID|
|DDDFFFFFDID|
|DDDDDDDDDID|
|DDDDDDDDDDD|
|DDDDDDDDDDD|
layer 1
|...C.....N.|
|.C.....N...|
|.........J.|
|.C.......H.|
|....MM...J.|
|N...MM...J.|
|.........JC|
|C........J.|
|....N...NLC|
|C.N...C....|
|....N.....C|
layer 2
|...........|
|...........|
|.........J.|
|.........J.|
|....MM...J.|
|....MM...J.|
|.........J.|
|.........L.|
|...........|
|...........|
|...........|
layer 3
|...........|
|...........|
|.........J.|
|.........J.|
|....MM...J.|
|....MM...J.|
|.........L.|
|...........|
|...........|
|...........|
|...........|
layer 4
|...........|
|...........|
|.........J.|
|.........J.|
|....MM...J.|
|....MM...L.|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 5
|...........|
|...........|
|.........J.|
|.........J.|
|....MM...L.|
|....MM.....|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 6
|...........|
|...........|
|.........J.|
|.........L.|
|....MM.....|
|....MM.....|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 7
|...........|
|.....A.....|
|..BBBBBBBL.|
|..BBBBBBB..|
|..BBBBBBB..|
|.ABBBBBBBA.|
|..BBBBBBB..|
|..BBBBBBB..|
|..BBBBBBB..|
|.....A.....|
|...........|
layer 8
|...........|
|...........|
|..GGGGGG...|
|..GOOOOOG..|
|..GO...OG..|
|..GO....G..|
|..GO...OG..|
|..GOOOOOG..|
|..GGGGGGG..|
|...........|
|...........|
layer 9
|...........|
|...........|
|...........|
|...OOOOO...|
|...PE..O...|
|...O.......|
|...P...O...|
|...OOOOO...|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|...........|
|...OOOOO...|
|...O...O...|
|...O.......|
|...O...O...|
|...OOOOO...|
|...........|
|...........|
|...........|
layer 11
|...........|
|...........|
|..KKKKKKK..|
|..KKKKKKK..|
|..KKKKKKK..|
|..KKKKKKK..|
|..KKKKKKK..|
|..KKKKKKK..|
|..KKKKKKK..|
|...........|
|...........|
layer 12
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
layer 13
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
layer 14
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
doors 7 8 5 face=3
inside 5 8 5
room_corner 4 8 4 closed=false top=10
room_corner 6 8 6
lights 4 9 4
sockets 6 8 5 face=3 id={id}_deck role=idle tags=[door]
sockets 5 1 7 face=0 id={id}_foot role=idle tags=[bench]
end

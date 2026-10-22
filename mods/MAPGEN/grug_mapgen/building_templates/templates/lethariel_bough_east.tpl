grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:bough_east, lethariel:homes_bough
name lethariel_bough_east
pivot 11 11
origin 0 0 0
size 11 14 11
cell 1
meta extent=[0,0,10,10] peak=10 rails=27 steps=6 top=13
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
|DDDDDDDDDDD|
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
|...........|
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
|...........|
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
|...........|
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
|...........|
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
|...........|
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
|.....A.....|
|..BBBBBBB..|
|..BBBBBBBL.|
|..BBBBBBB..|
|.ABBBBBBBA.|
|..BBBBBBB..|
|..BBBBBBB..|
|..BBBBBBB..|
|.....A.....|
|...........|
layer 7
|...........|
|...........|
|..GGGGGGG..|
|..GOOOOO...|
|..GO...OG..|
|..GO....G..|
|..GO...OG..|
|..GOOOOOG..|
|..GGGGGGG..|
|...........|
|...........|
layer 8
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
layer 9
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
layer 10
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
layer 11
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

points
doors 7 7 5 face=3
inside 5 7 5
room_corner 4 7 4 closed=false top=9
room_corner 6 7 6
lights 4 8 4
sockets 6 7 5 face=3 id={id}_deck role=idle tags=[door]
sockets 5 1 7 face=0 id={id}_foot role=idle tags=[bench]
end

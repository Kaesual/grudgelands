grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:bough_east, lethariel:homes_bough
name lethariel_bough_east
pivot 11 11
origin 0 0 0
size 11 14 11
cell 1
meta extent=[0,0,10,10] peak=10 rails=27 steps=6 top=13 undergrowth=[0,0,10,10,5]
races elf

legend
A node air late
B role beam late
C role floor late
D role ground
E role light_wall o=wallmounted:5 late
F role path
G role railing late
H role signature else=D late
I role signature else=air late
J role signature_slab else=air late
K role signature_stair o=facedir:2 else=air late
L role tree_log late
M role wall late
N role window o=facedir:3 late
end

layer 0
|DDDDDDDDDDD|
|DDDDDDDDDDD|
|DDDDDDDDDDD|
|DDDFFFFFDHD|
|DDDFFFFFDHD|
|DDDFFFFFDHD|
|DDDFFFFFDHD|
|DDDFFFFFDHD|
|DDDDDDDDDHD|
|DDDDDDDDDDD|
|DDDDDDDDDDD|
layer 1
|...........|
|...........|
|...........|
|.........I.|
|....LL...I.|
|....LL...I.|
|.........I.|
|.........I.|
|.........K.|
|...........|
|...........|
layer 2
|...........|
|...........|
|...........|
|.........I.|
|....LL...I.|
|....LL...I.|
|.........I.|
|.........K.|
|...........|
|...........|
|...........|
layer 3
|...........|
|...........|
|...........|
|.........I.|
|....LL...I.|
|....LL...I.|
|.........K.|
|...........|
|...........|
|...........|
|...........|
layer 4
|...........|
|...........|
|...........|
|.........I.|
|....LL...I.|
|....LL...K.|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 5
|...........|
|...........|
|...........|
|.........I.|
|....LL...K.|
|....LL.....|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 6
|...........|
|.....B.....|
|..CCCCCCC..|
|..CCCCCCCK.|
|..CCCCCCC..|
|.BCCCCCCC..|
|..CCCCCCC..|
|..CCCCCCC..|
|..CCCCCCC..|
|.....B.....|
|...........|
layer 7
|...........|
|...........|
|..GGGGGGG..|
|..GMMMMM.A.|
|..GMAAAM...|
|..GMAAA....|
|..GMAAAMG..|
|..GMMMMMG..|
|..GGGGGGG..|
|...........|
|...........|
layer 8
|...........|
|...........|
|...........|
|...MMMMM.A.|
|...NEAAM...|
|...MAAA....|
|...NAAAM...|
|...MMMMM...|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|...........|
|...MMMMM.A.|
|...MAAAM...|
|...MAAA....|
|...MAAAM...|
|...MMMMM...|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|..JJJJJJJ..|
|..JJJJJJJ..|
|..JJJJJJJ..|
|..JJJJJJJ..|
|..JJJJJJJ..|
|..JJJJJJJ..|
|..JJJJJJJ..|
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

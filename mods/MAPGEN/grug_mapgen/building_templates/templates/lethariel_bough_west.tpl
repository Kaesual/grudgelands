grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:bough_west, lethariel:martial_bough
name lethariel_bough_west
pivot 11 11
origin 0 0 0
size 11 15 11
cell 1
meta extent=[0,0,10,10] peak=11 rails=26 steps=7 top=14 undergrowth=[0,0,10,10,5]
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
|DDDDDDDDDHD|
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
|.........I.|
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
|.........I.|
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
|.........I.|
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
|.........I.|
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
|.........I.|
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
|...........|
|.........I.|
|.........K.|
|....LL.....|
|....LL.....|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 7
|...........|
|.....B.....|
|..CCCCCCCK.|
|..CCCCCCC..|
|..CCCCCCC..|
|.BCCCCCCCB.|
|..CCCCCCC..|
|..CCCCCCC..|
|..CCCCCCC..|
|.....B.....|
|...........|
layer 8
|...........|
|...........|
|..GGGGGG.A.|
|..GMMMMM...|
|..GMAAAM...|
|..GMAAA....|
|..GMAAAMG..|
|..GMMMMMG..|
|..GGGGGGG..|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........A.|
|...MMMMM...|
|...NEAAM...|
|...MAAA....|
|...NAAAM...|
|...MMMMM...|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........A.|
|...MMMMM...|
|...MAAAM...|
|...MAAA....|
|...MAAAM...|
|...MMMMM...|
|...........|
|...........|
|...........|
layer 11
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

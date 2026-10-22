grudgelands-building-template 1
# Frozen from the building generators (Round 56): stillgrave:sunken_ruin
name stillgrave_sunken_ruin
pivot 11 9
origin -1 0 -1
size 13 9 11
cell 1
meta cobwebs=5 ivy=7 peak=6 standing=31
races undead

legend
A node grug_nodes:bone_pile o=facedir:1
B node grug_nodes:bone_pile o=facedir:2
C node grug_nodes:skull_horned
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
|LLLLLLLLLLLLL|
|LFFFFFFFFFFFL|
|LFEEEEEEEEEFL|
|LFEEEEEEEEEFL|
|LFEEEEEEEEEFL|
|LFNNNNNNNNNFL|
|LFEEEEEEEEEFL|
|LFEEEEEEEEEFL|
|LFEEEEEEEEEFL|
|LFFFFFFFFFFFL|
|LLLLLLLLLLLLL|
layer 1
|.............|
|.M..PPPPPPPM.|
|..N........P.|
|......N.GBNP.|
|.P.GCN...N.P.|
|.P..N......P.|
|.P......N.GP.|
|.P.N.GAN...P.|
|.PN...N....P.|
|.MPPPPP...PM.|
|.............|
layer 2
|.............|
|.M..OOOOOOOM.|
|..........KO.|
|..........NO.|
|.....N.....O.|
|...........O.|
|...........O.|
|.OI....N...O.|
|.ONJ.......O.|
|.MOO......OM.|
|.............|
layer 3
|.............|
|.M..OOOOOOOM.|
|..........DO.|
|...........O.|
|...........O.|
|...........O.|
|...........O.|
|.O.........O.|
|.OD........O.|
|.MOO......OO.|
|.............|
layer 4
|.............|
|.M..OOOOOO...|
|.......K.....|
|.............|
|...........O.|
|..........HO.|
|...........O.|
|...........O.|
|...........O.|
|.M........OO.|
|.............|
layer 5
|.............|
|.M..OOOOOO...|
|....K........|
|.............|
|..........DO.|
|...........O.|
|...........O.|
|...........O.|
|..........HO.|
|.M........OO.|
|.............|
layer 6
|.............|
|.M..OOO......|
|......D......|
|.............|
|.............|
|.............|
|.............|
|...........O.|
|..........DO.|
|.M........OO.|
|.............|
layer 7
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 8
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|

points
room_corner 1 0 1 closed=false id={id} ruin=true top=6
room_corner 9 0 7
end

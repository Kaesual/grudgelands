grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:fallen_house
name nhal_veyr_fallen_house
pivot 9 7
origin -1 0 -1
size 11 8 9
cell 1
meta cobwebs=4 extent=[-1,-1,9,7] ivy=3 peak=5 standing=32 top=7
races undead

legend
A node grug_nodes:bone_pile o=facedir:2
B node grug_nodes:skull_human o=facedir:3
C role cobweb else=air
D role floor
E role foundation
F role grass_tuft
G role ivy o=wallmounted:3 else=air
H role ivy o=wallmounted:4 else=air
I role path
J role post
K role rubble
L role wall
M role wall_accent
end

layer 0
|IIIIIIIIIII|
|IEEEEEEEEEI|
|IEDDDDDDDEI|
|IEDDDDDDDEI|
|IEKKKKKKKEI|
|IEDDDDDDDEI|
|IEDDDDDDDEI|
|IEEEEEEEEEI|
|IIIIIIIIIII|
layer 1
|...........|
|.JMMMMMMMJ.|
|.M.FAK...M.|
|.M..K....M.|
|.M......KM.|
|.M.K.FBK.M.|
|.MK...K..M.|
|.JMMMMMMMJ.|
|...........|
layer 2
|...........|
|.JLL...LLL.|
|.L...K...L.|
|.L.......L.|
|.L.........|
|.L.....K...|
|.LK........|
|.JLLLLLLLJ.|
|...........|
layer 3
|...........|
|.J.....LLL.|
|.........L.|
|.........L.|
|.L.........|
|.LG........|
|.L....H....|
|.JLLLLL..J.|
|...........|
layer 4
|...........|
|.J.....LLL.|
|.........L.|
|.........L.|
|.LC........|
|.L.........|
|.L.H..C....|
|.JLLLLL....|
|...........|
layer 5
|...........|
|.J.....LLL.|
|........CL.|
|.........L.|
|...........|
|...........|
|..C........|
|.JLL.......|
|...........|
layer 6
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
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

points
room_corner 1 0 1 closed=false id={id} ruin=true top=5
room_corner 7 0 5
end

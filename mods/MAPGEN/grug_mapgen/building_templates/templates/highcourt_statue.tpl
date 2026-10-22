grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:statue, highcourt:homes_monument, dur_brannoc:statue, lethariel:statue, nhal_veyr:statue, gor_drazhak:statue
name highcourt_statue
pivot 9 9
origin 0 0 0
size 9 10 9
cell 1
meta extent=[0,0,8,8] peak=9 top=9
races dwarf human elf undead orc

legend
A role castle_paving
B role castle_wall else=air
C role castle_wall_stair else=air
D role castle_wall_stair o=facedir:1 else=air
E role castle_wall_stair o=facedir:2 else=air
F role castle_wall_stair o=facedir:3 else=air
G role light_post o=wallmounted:1
H role plaza_edge
I role post
J role rug_accent
K role signature else=air
L role signature_slab else=air
M role signature_stair o=facedir:1 else=air
N role signature_stair o=facedir:3 else=air
end

layer 0
|HHHHHHHHH|
|HAAAAAAAH|
|HAAAAAAAH|
|HAAAAAAAH|
|HAAAAAAAH|
|HAAAAAAAH|
|HAAAAAAAH|
|HAAAAAAAH|
|HHHHHHHHH|
layer 1
|.........|
|.GCCCCCG.|
|.DBBBBBF.|
|.DBBBBBF.|
|.DBBBBBF.|
|.DBBBBBF.|
|.DBBBBBF.|
|.GEEEEEG.|
|.........|
layer 2
|.........|
|.........|
|.........|
|...BBB...|
|...BBB...|
|...BBB...|
|.........|
|.........|
|.........|
layer 3
|.........|
|.........|
|.........|
|....K....|
|...KKK...|
|....K....|
|.........|
|.........|
|.........|
layer 4
|.........|
|.........|
|.........|
|.........|
|...KK....|
|.........|
|.........|
|.........|
|.........|
layer 5
|.........|
|.........|
|.........|
|.........|
|...NKM...|
|.........|
|.........|
|.........|
|.........|
layer 6
|.........|
|.........|
|.........|
|.........|
|....KI...|
|.........|
|.........|
|.........|
|.........|
layer 7
|.........|
|.........|
|.........|
|.........|
|....LIJ..|
|.........|
|.........|
|.........|
|.........|
layer 8
|.........|
|.........|
|.........|
|.........|
|.....IJ..|
|.........|
|.........|
|.........|
|.........|
layer 9
|.........|
|.........|
|.........|
|.........|
|.....L...|
|.........|
|.........|
|.........|
|.........|

points
lights 1 1 1
lights 7 1 1
lights 1 1 7
lights 7 1 7
sockets 4 1 0 face=0 id={id}_idle role=idle tags=[bench]
end

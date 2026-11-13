grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:garrison_stable
name dur_brannoc_garrison_stable
pivot 15 13
origin -1 0 -1
size 17 12 15
cell 1
meta extent=[-1,-1,15,13] peak=9 top=11
races dwarf

legend
A node grug_decor:xdecor_potted_dandelion_white
B node grug_decor:xdecor_potted_geranium
C role door variant=_a
D role door variant=_b
E role door_hidden
F role door_hidden o=facedir:3
G role fence
H role floor
I role foundation
J role hearth o=facedir:1
K role hearth o=facedir:3
L role light_wall o=wallmounted:2
M role light_wall o=wallmounted:3
N role light_wall o=wallmounted:4
O role path
T role storage
W role window
X role window o=facedir:3
P role facade_roof_stair o=facedir:0
Q role facade_roof_stair o=facedir:2
R role facade_roof_slab o=facedir:0
S role facade_base
U role facade_infill
V role facade_gable
end

layer 0
|OOOOOOOOOOOOOOOOO|
|OIIIIIIIIIIIIIIIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIIIIIIIIIIIIIIIO|
|OOOOOOOOOOOOOOOOO|
layer 1
|...BABT..........|
|.SSSSSSSCDSSSSSS.|
|.S.............S.|
|.SK...........JSB|
|.S.G.........G.SA|
|.SK...........JSB|
|.S.G.........G.S.|
|.SK...........JS.|
|.S.G.........G.S.|
|.SK...........JS.|
|.S.G.........G.S.|
|.SK...........JST|
|.S.G...TTT...G.S.|
|.SSSSSSSSSSSSSSS.|
|.................|
layer 2
|......T..........|
|.SUWWSUUEFSWWUUS.|
|.U.............U.|
|.X.............X.|
|.X.............X.|
|.S.............S.|
|.U.............U.|
|.X.............X.|
|.X.............X.|
|.S.............S.|
|.U.............U.|
|.X.............X.|
|.X.............X.|
|.SUWWSUWWUSWWUUS.|
|.................|
layer 3
|......N...N......|
|.SUWWSUUUUSWWUUS.|
|.U.............U.|
|.X.............X.|
|.X.............X.|
|.SM...........LS.|
|.U.............U.|
|.X.............X.|
|.X.............X.|
|.S.............S.|
|.UM...........LU.|
|.X.............X.|
|.X.............X.|
|.SUWWSUWWUSWWUUS.|
|.................|
layer 4
|.................|
|.SUUUSUUUUSUUUUS.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.S.............S.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.S.............S.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.SUUUSUUUUSUUUUS.|
|.................|
layer 5
|PPPPPPPPPPPPPPPPP|
|.SSSSSSSSSSSSSSS.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.S.............S.|
|.SSSSSSSSSSSSSSS.|
|QQQQQQQQQQQQQQQQQ|
layer 6
|.................|
|PPPPPPPPPPPPPPPPP|
|.V.............V.|
|.V.............V.|
|.V.............V.|
|.S.............S.|
|.V.............V.|
|.V.............V.|
|.V.............V.|
|.S.............S.|
|.V.............V.|
|.V.............V.|
|.V.............V.|
|QQQQQQQQQQQQQQQQQ|
|.................|
layer 7
|.................|
|.................|
|PPPPPPPPPPPPPPPPP|
|.V.............V.|
|.V.............V.|
|.S.............S.|
|.V.............V.|
|.V.............V.|
|.V.............V.|
|.S.............S.|
|.V.............V.|
|.V.............V.|
|QQQQQQQQQQQQQQQQQ|
|.................|
|.................|
layer 8
|.................|
|.................|
|.................|
|PPPPPPPPPPPPPPPPP|
|.V.............V.|
|.S.............S.|
|.V.............V.|
|.V.............V.|
|.V.............V.|
|.S.............S.|
|.V.............V.|
|QQQQQQQQQQQQQQQQQ|
|.................|
|.................|
|.................|
layer 9
|.................|
|.................|
|.................|
|.................|
|RRRRRRRRRRRRRRRRR|
|RRRRRRRRRRRRRRRRR|
|RRRRRRRRRRRRRRRRR|
|RRRRRRRRRRRRRRRRR|
|RRRRRRRRRRRRRRRRR|
|RRRRRRRRRRRRRRRRR|
|RRRRRRRRRRRRRRRRR|
|.................|
|.................|
|.................|
|.................|
layer 10
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
layer 11
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|

points
doors 7 1 0 face=0
doors 8 1 0 face=0
inside 7 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 13 0 11
lights 5 3 -1
lights 9 3 -1
lights 1 3 4
lights 13 3 4
lights 1 3 9
lights 13 3 9
sockets 7 1 10 face=2 id={id}_groom role=idle tags=[work]
sockets 7 1 2 face=2 id={id}_gate role=idle tags=[door]
end

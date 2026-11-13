grudgelands-building-template 1
# Frozen from the building generators (Round 56): kezamba:stable
name kezamba_stable
pivot 15 11
origin -1 0 -1
size 17 12 13
cell 1
meta extent=[-1,-1,15,11] peak=9 top=11
races troll

legend
A role door variant=_a
B role door variant=_b
C role door_hidden
D role door_hidden o=facedir:3
E role fence
F role floor
G role foundation
H role hearth o=facedir:1
I role hearth o=facedir:3
J role light_wall o=wallmounted:2
K role light_wall o=wallmounted:3
L role light_wall o=wallmounted:4
M role mat else=air
N role path
S role storage
T role wall
V role window
O role facade_roof_stair o=facedir:0
P role facade_roof_stair o=facedir:2
Q role facade_roof_slab o=facedir:0
R role facade_base
U role facade_home_base
W role facade_infill
end

layer 0
|NNNNNNNNNNNNNNNNN|
|NGGGGGGGGGGGGGGGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGFFFFFFFFFFFFFGN|
|NGGGGGGGGGGGGGGGN|
|NNNNNNNNNNNNNNNNN|
layer 1
|.................|
|.RRRRRRRABRRRRRR.|
|.R.............R.|
|.RIM.........MHR.|
|.R.E.........E.R.|
|.RIM.........MHR.|
|.R.E.........E.R.|
|.RIM.........MHR.|
|.R.E.........E.R.|
|.RIM.........MHR.|
|.R.E...SSS...E.R.|
|.RRRRRRRRRRRRRRR.|
|.................|
layer 2
|.................|
|.UWVVUWWCDUVVWWU.|
|.W.............W.|
|.V.............V.|
|.V.............V.|
|.W.............W.|
|.U.............U.|
|.V.............V.|
|.V.............V.|
|.W.............W.|
|.W.............W.|
|.UWVVUWVVWUVVWWU.|
|.................|
layer 3
|......L...L......|
|.UWVVUWWWWUVVWWU.|
|.W.............W.|
|.V.............V.|
|.V.............V.|
|.WK...........JW.|
|.U.............U.|
|.V.............V.|
|.V.............V.|
|.WK...........JW.|
|.W.............W.|
|.UWVVUWVVWUVVWWU.|
|.................|
layer 4
|.................|
|.UWWWUWWWWUWWWWU.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.U.............U.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.UWWWUWWWWUWWWWU.|
|.................|
layer 5
|OOOOOOOOOOOOOOOOO|
|.UUTTUTTTTUTTUTU.|
|.U.............U.|
|.T.............T.|
|.T.............T.|
|.U.............U.|
|.U.............U.|
|.T.............T.|
|.T.............T.|
|.U.............U.|
|.T.............T.|
|.UUTTUUTTUUTTUTU.|
|PPPPPPPPPPPPPPPPP|
layer 6
|.................|
|OOOOOOOOOOOOOOOOO|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.T.............T.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|PPPPPPPPPPPPPPPPP|
|.................|
layer 7
|.................|
|.................|
|OOOOOOOOOOOOOOOOO|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|.T.............T.|
|.W.............W.|
|.W.............W.|
|.W.............W.|
|PPPPPPPPPPPPPPPPP|
|.................|
|.................|
layer 8
|.................|
|.................|
|.................|
|OOOOOOOOOOOOOOOOO|
|.W.............W.|
|.W.............W.|
|.T.............T.|
|.W.............W.|
|.W.............W.|
|PPPPPPPPPPPPPPPPP|
|.................|
|.................|
|.................|
layer 9
|.................|
|.................|
|.................|
|.................|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
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

points
doors 7 1 0 face=0
doors 8 1 0 face=0
inside 7 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 13 0 9
lights 5 3 -1
lights 9 3 -1
lights 1 3 4
lights 13 3 4
lights 1 3 8
lights 13 3 8
sockets 7 1 8 face=2 id={id}_groom role=idle tags=[work]
sockets 7 1 2 face=2 id={id}_gate role=idle tags=[door]
end

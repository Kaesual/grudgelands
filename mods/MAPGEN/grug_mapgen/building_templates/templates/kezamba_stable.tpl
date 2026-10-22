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
O role post
P role roof_slab
Q role roof_stair
R role roof_stair o=facedir:2
S role storage
T role wall
U role wall_accent
V role window
W role window_frame
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
|.OWUUWUUABWUUWUO.|
|.W.............W.|
|.UIM.........MHU.|
|.U.E.........E.U.|
|.WIM.........MHW.|
|.W.E.........E.W.|
|.UIM.........MHU.|
|.U.E.........E.U.|
|.WIM.........MHW.|
|.U.E...SSS...E.U.|
|.OWUUWWUUWWUUWUO.|
|.................|
layer 2
|.................|
|.OWVVWTTCDWVVWTO.|
|.W.............W.|
|.V.............V.|
|.V.............V.|
|.W.............W.|
|.W.............W.|
|.V.............V.|
|.V.............V.|
|.W.............W.|
|.T.............T.|
|.OWVVWWVVWWVVWTO.|
|.................|
layer 3
|......L...L......|
|.OWVVWTTTTWVVWTO.|
|.W.............W.|
|.V.............V.|
|.V.............V.|
|.WK...........JW.|
|.W.............W.|
|.V.............V.|
|.V.............V.|
|.WK...........JW.|
|.T.............T.|
|.OWVVWWVVWWVVWTO.|
|.................|
layer 4
|.................|
|.OWTTWTTTTWTTWTO.|
|.W.............W.|
|.T.............T.|
|.T.............T.|
|.W.............W.|
|.W.............W.|
|.T.............T.|
|.T.............T.|
|.W.............W.|
|.T.............T.|
|.OWTTWWTTWWTTWTO.|
|.................|
layer 5
|QQQQQQQQQQQQQQQQQ|
|.OWTTWTTTTWTTWTO.|
|.W.............W.|
|.T.............T.|
|.T.............T.|
|.W.............W.|
|.W.............W.|
|.T.............T.|
|.T.............T.|
|.W.............W.|
|.T.............T.|
|.OWTTWWTTWWTTWTO.|
|RRRRRRRRRRRRRRRRR|
layer 6
|.................|
|QQQQQQQQQQQQQQQQQ|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|RRRRRRRRRRRRRRRRR|
|.................|
layer 7
|.................|
|.................|
|QQQQQQQQQQQQQQQQQ|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|RRRRRRRRRRRRRRRRR|
|.................|
|.................|
layer 8
|.................|
|.................|
|.................|
|QQQQQQQQQQQQQQQQQ|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|.T.............T.|
|RRRRRRRRRRRRRRRRR|
|.................|
|.................|
|.................|
layer 9
|.................|
|.................|
|.................|
|.................|
|PPPPPPPPPPPPPPPPP|
|PPPPPPPPPPPPPPPPP|
|PPPPPPPPPPPPPPPPP|
|PPPPPPPPPPPPPPPPP|
|PPPPPPPPPPPPPPPPP|
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

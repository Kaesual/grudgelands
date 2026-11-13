grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:martial_stables
name highcourt_martial_stables
pivot 15 13
origin -1 0 -1
size 17 12 15
cell 1
meta extent=[-1,-1,15,13] peak=9 top=11
races human

legend
A role door variant=_a
B role door variant=_b
C role door_hidden
D role door_hidden o=facedir:3
E role fence
F role floor
G role flower else=air
H role flower_alt else=air
J role hearth o=facedir:1
K role hearth o=facedir:3
L role light_wall o=wallmounted:2
M role light_wall o=wallmounted:3
N role light_wall o=wallmounted:4
O role mat else=air
P role path
R role roof_slab
S role roof_stair
T role roof_stair o=facedir:2
U role storage
W role wall_infill else=air
X role window
Y role window o=facedir:3
I role facade_base
Q role facade_frame
V role facade_infill
end

layer 0
|PPPPPPPPPPPPPPPPP|
|PIIIIIIIIIIIIIIIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIFFFFFFFFFFFFFIP|
|PIIIIIIIIIIIIIIIP|
|PPPPPPPPPPPPPPPPP|
layer 1
|...GHGU..........|
|.IIIIIIIABIIIIII.|
|.I.............I.|
|.IKO.........OJIG|
|.I.E.........E.IH|
|.IKO.........OJIG|
|.I.E.........E.I.|
|.IKO.........OJI.|
|.I.E.........E.I.|
|.IKO.........OJI.|
|.I.E.........E.I.|
|.IKO.........OJIU|
|.I.E...UUU...E.I.|
|.IIIIIIIIIIIIIII.|
|.................|
layer 2
|......U..........|
|.QVXXQWVCDQXXVWQ.|
|.V.............V.|
|.Y.............Y.|
|.Y.............Y.|
|.Q.............Q.|
|.V.............V.|
|.Y.............Y.|
|.Y.............Y.|
|.Q.............Q.|
|.V.............V.|
|.Y.............Y.|
|.Y.............Y.|
|.QVXXQVXXVQXXVWQ.|
|.................|
layer 3
|......N...N......|
|.QVXXQWVWWQXXVWQ.|
|.V.............V.|
|.Y.............Y.|
|.Y.............Y.|
|.QM...........LQ.|
|.V.............V.|
|.Y.............Y.|
|.Y.............Y.|
|.Q.............Q.|
|.VM...........LV.|
|.Y.............Y.|
|.Y.............Y.|
|.QVXXQVXXVQXXVWQ.|
|.................|
layer 4
|.................|
|.QVWVQWVWWQWWVWQ.|
|.V.............V.|
|.W.............W.|
|.V.............V.|
|.Q.............Q.|
|.V.............V.|
|.V.............V.|
|.W.............W.|
|.Q.............Q.|
|.V.............V.|
|.W.............W.|
|.W.............W.|
|.QVWVQVVWVQWWVWQ.|
|.................|
layer 5
|SSSSSSSSSSSSSSSSS|
|.QQQQQQQQQQQQQQQ.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.Q.............Q.|
|.QQQQQQQQQQQQQQQ.|
|TTTTTTTTTTTTTTTTT|
layer 6
|.................|
|SSSSSSSSSSSSSSSSS|
|.W.............W.|
|.W.............W.|
|.V.............V.|
|.Q.............Q.|
|.W.............W.|
|.V.............V.|
|.W.............W.|
|.Q.............Q.|
|.V.............V.|
|.W.............W.|
|.W.............W.|
|TTTTTTTTTTTTTTTTT|
|.................|
layer 7
|.................|
|.................|
|SSSSSSSSSSSSSSSSS|
|.W.............W.|
|.V.............V.|
|.Q.............Q.|
|.W.............W.|
|.V.............V.|
|.W.............W.|
|.Q.............Q.|
|.V.............V.|
|.W.............W.|
|TTTTTTTTTTTTTTTTT|
|.................|
|.................|
layer 8
|.................|
|.................|
|.................|
|SSSSSSSSSSSSSSSSS|
|.V.............V.|
|.Q.............Q.|
|.W.............W.|
|.V.............V.|
|.W.............W.|
|.Q.............Q.|
|.V.............V.|
|TTTTTTTTTTTTTTTTT|
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

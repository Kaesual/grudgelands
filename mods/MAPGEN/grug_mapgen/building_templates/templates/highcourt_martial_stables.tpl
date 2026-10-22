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
I role foundation
J role hearth o=facedir:1
K role hearth o=facedir:3
L role light_wall o=wallmounted:2
M role light_wall o=wallmounted:3
N role light_wall o=wallmounted:4
O role mat else=air
P role path
Q role post
R role roof_slab
S role roof_stair
T role roof_stair o=facedir:2
U role storage
V role wall_accent
W role wall_infill else=air
X role window
Y role window o=facedir:3
Z role window_frame
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
|.QZVVZVVABZVVZVQ.|
|.Z.............Z.|
|.VKO.........OJVG|
|.V.E.........E.VH|
|.ZKO.........OJZG|
|.Z.E.........E.Z.|
|.VKO.........OJV.|
|.V.E.........E.V.|
|.ZKO.........OJZ.|
|.Z.E.........E.Z.|
|.VKO.........OJVU|
|.V.E...UUU...E.V.|
|.ZZVVZZVVZZVVZVZ.|
|.................|
layer 2
|......U..........|
|.QZXXZWQCDZXXZWQ.|
|.Z.............Z.|
|.Y.............Y.|
|.Y.............Y.|
|.Z.............Z.|
|.Z.............Z.|
|.Y.............Y.|
|.Y.............Y.|
|.Z.............Z.|
|.Z.............Z.|
|.Y.............Y.|
|.Y.............Y.|
|.ZZXXZZXXZZXXZWZ.|
|.................|
layer 3
|......N...N......|
|.QZXXZWQWWZXXZWQ.|
|.Z.............Z.|
|.Y.............Y.|
|.Y.............Y.|
|.ZM...........LZ.|
|.Z.............Z.|
|.Y.............Y.|
|.Y.............Y.|
|.Z.............Z.|
|.ZM...........LZ.|
|.Y.............Y.|
|.Y.............Y.|
|.ZZXXZZXXZZXXZWZ.|
|.................|
layer 4
|.................|
|.QZWQZWQWWZWWZWQ.|
|.Z.............Z.|
|.W.............W.|
|.Q.............Q.|
|.Z.............Z.|
|.Z.............Z.|
|.Q.............Q.|
|.W.............W.|
|.Z.............Z.|
|.Z.............Z.|
|.W.............W.|
|.W.............W.|
|.ZZWQZZQWZZWWZWZ.|
|.................|
layer 5
|SSSSSSSSSSSSSSSSS|
|.QZWQZWQWWZWWZWQ.|
|.Z.............Z.|
|.W.............W.|
|.Q.............Q.|
|.Z.............Z.|
|.Z.............Z.|
|.Q.............Q.|
|.W.............W.|
|.Z.............Z.|
|.Z.............Z.|
|.W.............W.|
|.W.............W.|
|.ZZWQZZQWZZWWZWZ.|
|TTTTTTTTTTTTTTTTT|
layer 6
|.................|
|SSSSSSSSSSSSSSSSS|
|.W.............W.|
|.W.............W.|
|.Q.............Q.|
|.W.............W.|
|.W.............W.|
|.Q.............Q.|
|.W.............W.|
|.W.............W.|
|.Q.............Q.|
|.W.............W.|
|.W.............W.|
|TTTTTTTTTTTTTTTTT|
|.................|
layer 7
|.................|
|.................|
|SSSSSSSSSSSSSSSSS|
|.W.............W.|
|.Q.............Q.|
|.W.............W.|
|.W.............W.|
|.Q.............Q.|
|.W.............W.|
|.W.............W.|
|.Q.............Q.|
|.W.............W.|
|TTTTTTTTTTTTTTTTT|
|.................|
|.................|
layer 8
|.................|
|.................|
|.................|
|SSSSSSSSSSSSSSSSS|
|.Q.............Q.|
|.W.............W.|
|.W.............W.|
|.Q.............Q.|
|.W.............W.|
|.W.............W.|
|.Q.............Q.|
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

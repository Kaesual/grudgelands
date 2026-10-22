grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:martial_guard_house
name highcourt_martial_guard_house
pivot 11 7
origin -1 0 -1
size 13 10 9
cell 1
meta extent=[-1,-1,11,7] peak=7 top=9
races human

legend
A role bed variant=_bottom
B role bed variant=_top
C role chimney
D role chimney_cap
E role door variant=_a
F role door_hidden
G role floor
H role flower else=air
I role flower_alt else=air
J role foundation
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
Q role post
R role roof_slab
S role roof_stair
T role roof_stair o=facedir:1
U role roof_stair o=facedir:2
V role roof_stair o=facedir:3
W role roof_stair_outer
X role roof_stair_outer o=facedir:1
Y role roof_stair_outer o=facedir:2
Z role roof_stair_outer o=facedir:3
a role rug
b role rug_accent
c role seat
d role seat o=facedir:2
e role seat o=facedir:3
f role shelf o=facedir:1
g role shelf o=facedir:3
h role shelf_vessels o=facedir:1
i role storage
j role storage o=facedir:3
k role table_leg
l role table_top
m role wall_accent
n role wall_infill else=air
o role window
p role window o=facedir:3
q role window_frame
end

layer 0
|PPPPPPPPPPPPP|
|PJJJJJJJJJJJP|
|PJGGGGGGGbGJP|
|PJGGGaaGGbGJP|
|PJGGGaaGGGGJP|
|PJGGGGGGGGGJP|
|PJGGGGGGGGGJP|
|PJJJJJJJJJJJP|
|PPPPPPPPPPPPP|
layer 1
|..i....HI....|
|.QmmEmqmmqmQ.|
|.qA.......KC.|
|.mB...d..e.mH|
|.mj...kk...mI|
|.qg...c...fqH|
|.m........hm.|
|.QqmmqqmmqmQ.|
|.........i...|
layer 2
|..i..........|
|.QnnFnqooqQQ.|
|.q........LC.|
|.p.........p.|
|.p....ll...p.|
|.qg.......hq.|
|.n.........n.|
|.QqooqqooqQQ.|
|.............|
layer 3
|..O...O......|
|.QnnQnqooqQQ.|
|.q........CC.|
|.p.........p.|
|.p.........p.|
|.qN.......Mq.|
|.n.........n.|
|.QqooqqooqQQ.|
|.............|
layer 4
|XSSSSSSSSSSSW|
|TQnnQnqQnqQQV|
|Tq........CCV|
|Tn.........nV|
|TQ.........QV|
|Tq.........qV|
|Tn.........nV|
|TQqnQqqQnqQQV|
|YUUUUUUUUUUUZ|
layer 5
|.............|
|.XSSSSSSSSSW.|
|.T.........C.|
|.T.........V.|
|.T.........V.|
|.T.........V.|
|.T.........V.|
|.YUUUUUUUUUZ.|
|.............|
layer 6
|.............|
|.............|
|..XSSSSSSSWC.|
|..T.......V..|
|..T.......V..|
|..T.......V..|
|..YUUUUUUUZ..|
|.............|
|.............|
layer 7
|.............|
|.............|
|...........C.|
|...RRRRRRR...|
|...RRRRRRR...|
|...RRRRRRR...|
|.............|
|.............|
|.............|
layer 8
|.............|
|.............|
|...........C.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 9
|.............|
|.............|
|...........D.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|

points
doors 3 1 0 face=0
inside 2 1 4 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 9 0 5
lights 1 3 -1
lights 5 3 -1
lights 9 2 1
lights 1 3 4
lights 9 3 4
end

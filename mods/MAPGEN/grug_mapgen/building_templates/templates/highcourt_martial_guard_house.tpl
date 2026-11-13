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
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
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
k node grug_decor:xdecor_table
n role wall_infill else=air
o role window
p role window o=facedir:3
J role facade_service_roof_stair_outer o=facedir:1
Q role facade_service_roof_stair o=facedir:1
R role facade_service_roof_stair_outer o=facedir:2
S role facade_base
T role facade_frame
U role facade_infill
V role facade_service_roof_stair o=facedir:0
W role facade_service_roof_stair o=facedir:2
X role facade_service_roof_slab o=facedir:0
Y role facade_service_roof_stair_outer o=facedir:0
Z role facade_service_roof_stair o=facedir:3
l role facade_service_roof_stair_outer o=facedir:3
end

layer 0
|PPPPPPPPPPPPP|
|PSSSSSSSSSSSP|
|PSGGGGGGGbGSP|
|PSGGGaaGGbGSP|
|PSGGGaaGGGGSP|
|PSGGGGGGGGGSP|
|PSGGGGGGGGGSP|
|PSSSSSSSSSSSP|
|PPPPPPPPPPPPP|
layer 1
|..i....HI....|
|.SSSESSSSSSS.|
|.SA.......KC.|
|.SB...d..e.SH|
|.Sj...kk...SI|
|.Sg...c...fSH|
|.S........hS.|
|.SSSSSSSSSSS.|
|.........i...|
layer 2
|..i..........|
|.TnnFnTooUUT.|
|.U........LC.|
|.p.........p.|
|.p.........p.|
|.Ug.......hU.|
|.n.........n.|
|.TUooUTooUUT.|
|.............|
layer 3
|..O...O......|
|.TnnUnTooUUT.|
|.U........CC.|
|.p.........p.|
|.p.........p.|
|.UN.......MU.|
|.n.........n.|
|.TUooUTooUUT.|
|.............|
layer 4
|JVVVVVVVVVVVY|
|QTTTTTTTTTTTZ|
|QT........CCZ|
|QT.........TZ|
|QT.........TZ|
|QT.........TZ|
|QT.........TZ|
|QTTTTTTTTTTTZ|
|RWWWWWWWWWWWl|
layer 5
|.............|
|.JVVVVVVVVVY.|
|.Q.........C.|
|.Q.........Z.|
|.Q.........Z.|
|.Q.........Z.|
|.Q.........Z.|
|.RWWWWWWWWWl.|
|.............|
layer 6
|.............|
|.............|
|..JVVVVVVVYC.|
|..Q.......Z..|
|..Q.......Z..|
|..Q.......Z..|
|..RWWWWWWWl..|
|.............|
|.............|
layer 7
|.............|
|.............|
|...........C.|
|...XXXXXXX...|
|...XXXXXXX...|
|...XXXXXXX...|
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

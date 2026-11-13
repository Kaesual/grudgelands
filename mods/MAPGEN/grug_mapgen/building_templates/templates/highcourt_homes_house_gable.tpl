grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:homes_house_gable
name highcourt_homes_house_gable
pivot 9 7
origin -1 0 -1
size 11 11 9
cell 1
meta extent=[-1,-1,9,7] peak=8 top=10
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
R role roof_slab
S role roof_stair
T role roof_stair o=facedir:2
U role rug
V role rug_accent
W role seat
X role seat o=facedir:2
Y role seat o=facedir:3
Z role shelf o=facedir:1
a role shelf o=facedir:3
b role shelf_vessels o=facedir:1
c role storage o=facedir:3
d node grug_decor:xdecor_table
f role tree_log
g role wall_accent
h role wall_infill else=air
i role window
j role window o=facedir:3
J role facade_home_base
Q role facade_frame
e role facade_infill
end

layer 0
|PPPPPPPPPPP|
|PJJJJJJJJJP|
|PJGGGGGVGJP|
|PJGGUUGVGJP|
|PJGGUUGGGJP|
|PJGGGGGGGJP|
|PJGGGGGGGJP|
|PJJJJJJJJJP|
|PPPPPPPPPPP|
layer 1
|.......I...|
|.JgEggJggJ.|
|.JA.....KC.|
|.gB..X.Y.gI|
|.gc..dd..gH|
|fJa..W..ZJI|
|fg......bg.|
|.JJggJJggJ.|
|...........|
layer 2
|...........|
|.QhFeQeiiQ.|
|.e......LC.|
|.j.......j.|
|.j.......j.|
|fea.....be.|
|fh.......h.|
|.QeiiQeiiQ.|
|...........|
layer 3
|.O...O.....|
|.QhheQeiiQ.|
|.e......CC.|
|.j.......j.|
|.j.......j.|
|ReN.....Me.|
|Rh.......h.|
|.QeiiQeiiQ.|
|...........|
layer 4
|SSSSSSSSSSS|
|.QQQQQQQQQ.|
|.Q......CC.|
|.Q.......Q.|
|.Q.......Q.|
|.Q.......Q.|
|.Q.......Q.|
|.QQQQQQQQQ.|
|TTTTTTTTTTT|
layer 5
|...........|
|SSSSSSSSSSS|
|.h.......C.|
|.h.......h.|
|.e.......e.|
|.h.......h.|
|.h.......h.|
|TTTTTTTTTTT|
|...........|
layer 6
|...........|
|...........|
|SSSSSSSSSCS|
|.h.......h.|
|.e.......e.|
|.h.......h.|
|TTTTTTTTTTT|
|...........|
|...........|
layer 7
|...........|
|...........|
|.........C.|
|SSSSSSSSSSS|
|.e.......e.|
|TTTTTTTTTTT|
|...........|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........C.|
|...........|
|RRRRRRRRRRR|
|...........|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........C.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........D.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 2 1 0 face=0
inside 2 1 4 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 5
lights 0 3 -1
lights 4 3 -1
lights 7 2 1
lights 1 3 4
lights 7 3 4
end

grudgelands-building-template 1
# Frozen from the building generators (Round 56): silverleaf:glade_house_west
name silverleaf_glade_house_west
pivot 7 11
origin -1 0 -1
size 9 13 13
cell 1
meta peak=10
races elf

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
L role light_beacon else=h
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role path
S role roof_slab
T role roof_stair o=facedir:1
U role roof_stair o=facedir:3
V role rug
W role rug_accent
X role seat
Y role seat o=facedir:2
Z role seat o=facedir:3
a role shelf o=facedir:1
b role shelf o=facedir:3
c role shelf_vessels o=facedir:1
d role storage
e role storage o=facedir:3
f node grug_decor:xdecor_table
h role wall
j role window
k role window o=facedir:3
J role facade_base
R role facade_frame
g role facade_infill
i role facade_band
end

layer 0
|QQQQQQQQQ|
|QJJJJJJJQ|
|QJGGGWGJQ|
|QJGGGWGJQ|
|QJGGGGGJQ|
|QJGVVGGJQ|
|QJGVVGGJQ|
|QJGGGGGJQ|
|QJGGGGGJQ|
|QJGGGGGJQ|
|QJGGGGGJQ|
|QJJJJJJJQ|
|QQQQQQQQQ|
layer 1
|......I..|
|.JJJEJJJ.|
|.JA...KC.|
|.JB..Z.JH|
|.Je....JI|
|.Jb.Y..JH|
|.J..ff.J.|
|.J..X..J.|
|.J.....J.|
|dJ....aJ.|
|.J....cJ.|
|.JJJJJJJ.|
|...HIH...|
layer 2
|.........|
|.RhhFhhR.|
|.g....MC.|
|.k.....k.|
|.k.....k.|
|.gb....g.|
|.R.....R.|
|.k.....k.|
|.k.....k.|
|.g....cg.|
|.h.....h.|
|.RgjjghR.|
|.........|
layer 3
|..P...P..|
|.RhhhhhR.|
|.g....CC.|
|.k.....k.|
|.k.....k.|
|.g.....g.|
|.RO...NR.|
|.k.....k.|
|.k.....k.|
|.g.....g.|
|.h.....h.|
|.RgjjghR.|
|.........|
layer 4
|.........|
|.RhhhhhR.|
|.g....CC.|
|.h.....h.|
|.h.....h.|
|.g.....g.|
|.R.....R.|
|.h.....h.|
|.h.....h.|
|.g.....g.|
|.h.....h.|
|.RghhghR.|
|.........|
layer 5
|.........|
|.RhhhhhR.|
|.g....CC.|
|.h.....h.|
|.h.....h.|
|.g.....g.|
|.R.....R.|
|.h.....h.|
|.h.....h.|
|.g.....g.|
|.h.....h.|
|.RghhghR.|
|.........|
layer 6
|T.......U|
|TiiiiiiiU|
|Ti....CCU|
|Ti.....iU|
|Ti.....iU|
|Ti.....iU|
|Ti.....iU|
|Ti.....iU|
|Ti.....iU|
|Ti.....iU|
|Ti.....iU|
|TiiiiiiiU|
|T.......U|
layer 7
|.T.....U.|
|.ThhhhhU.|
|.T.....C.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.ThhhhhU.|
|.T.....U.|
layer 8
|..T...U..|
|..ThLhU..|
|..T...UC.|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..ThhhU..|
|..T...U..|
layer 9
|...T.U...|
|...ThU...|
|...T.U.C.|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...ThU...|
|...T.U...|
layer 10
|....S....|
|....S....|
|....S..C.|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
layer 11
|.........|
|.........|
|.......D.|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
layer 12
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|

points
doors 3 1 0 face=0
inside 2 1 8 id={id}
room_corner 1 0 1 closed=true id={id} top=6
room_corner 5 0 9
lights 1 3 -1
lights 5 3 -1
lights 5 2 1
lights 1 3 5
lights 5 3 5
sockets 3 1 -1 face=0 id=home_innkeeper
end

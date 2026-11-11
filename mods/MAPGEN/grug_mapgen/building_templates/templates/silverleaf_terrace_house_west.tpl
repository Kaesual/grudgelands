grudgelands-building-template 1
# Frozen from the building generators (Round 56): silverleaf:terrace_house_west
name silverleaf_terrace_house_west
pivot 7 11
origin -1 0 -1
size 9 13 13
cell 1
meta peak=10
races elf

legend
A role bed variant=_bottom
B role bed variant=_top
C role bed_fancy variant=_bottom else=A
D role bed_fancy variant=_top else=B
E role chimney
F role chimney_cap
G role door variant=_a
H role door_hidden
I role floor
K role hearth o=facedir:1
L role light_beacon else=g
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
d role storage o=facedir:3
e node grug_decor:xdecor_table
g role wall
i role window
j role window o=facedir:3
J role facade_base
R role facade_frame
f role facade_infill
h role facade_band
end

layer 0
|QQQQQQQQQ|
|QJJJJJJJQ|
|QJIIIWIJQ|
|QJIIIWIJQ|
|QJIIIIIJQ|
|QJIVVIIJQ|
|QJIVVIIJQ|
|QJIIIIIJQ|
|QJIIIIIJQ|
|QJIIIIIJQ|
|QJIIIIIJQ|
|QJJJJJJJQ|
|QQQQQQQQQ|
layer 1
|.........|
|.JJJGJJJ.|
|.JC...KE.|
|.JD..Z.J.|
|.Jd....J.|
|.Jb.Y..J.|
|.J..ee.J.|
|.J..X..J.|
|.J.....J.|
|.J....aJ.|
|.J....cJ.|
|.JJJJJJJ.|
|.........|
layer 2
|.........|
|.RggHggR.|
|.f....ME.|
|.j.....j.|
|.j.....j.|
|.fb....f.|
|.R.....R.|
|.j.....j.|
|.j.....j.|
|.f....cf.|
|.g.....g.|
|.RfiifgR.|
|.........|
layer 3
|..P...P..|
|.RgggggR.|
|.f....EE.|
|.j.....j.|
|.j.....j.|
|.f.....f.|
|.RO...NR.|
|.j.....j.|
|.j.....j.|
|.f.....f.|
|.g.....g.|
|.RfiifgR.|
|.........|
layer 4
|.........|
|.RgggggR.|
|.f....EE.|
|.g.....g.|
|.g.....g.|
|.f.....f.|
|.R.....R.|
|.g.....g.|
|.g.....g.|
|.f.....f.|
|.g.....g.|
|.RfggfgR.|
|.........|
layer 5
|.........|
|.RgggggR.|
|.f....EE.|
|.g.....g.|
|.g.....g.|
|.f.....f.|
|.R.....R.|
|.g.....g.|
|.g.....g.|
|.f.....f.|
|.g.....g.|
|.RfggfgR.|
|.........|
layer 6
|T.......U|
|ThhhhhhhU|
|Th....EEU|
|Th.....hU|
|Th.....hU|
|Th.....hU|
|Th.....hU|
|Th.....hU|
|Th.....hU|
|Th.....hU|
|Th.....hU|
|ThhhhhhhU|
|T.......U|
layer 7
|.T.....U.|
|.TgggggU.|
|.T.....E.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.TgggggU.|
|.T.....U.|
layer 8
|..T...U..|
|..TgLgU..|
|..T...UE.|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..TgggU..|
|..T...U..|
layer 9
|...T.U...|
|...TgU...|
|...T.U.E.|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...TgU...|
|...T.U...|
layer 10
|....S....|
|....S....|
|....S..E.|
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
|.......F.|
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
end

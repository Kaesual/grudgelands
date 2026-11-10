grudgelands-building-template 1
# Frozen from the building generators (Round 56): dawnmere:field_cottage
name dawnmere_field_cottage
pivot 11 9
origin -1 0 -1
size 13 12 11
cell 1
meta peak=9
races human

legend
A role bed variant=_bottom
B role bed variant=_top
C role chimney
D role chimney_cap
E role door variant=_a o=facedir:2
F role door_hidden o=facedir:2
G role floor
H role foundation
I role hearth o=facedir:1
J role light_post o=wallmounted:1
K role light_wall o=wallmounted:2
L role light_wall o=wallmounted:3
M role light_wall o=wallmounted:5
N role path
O role post
P role roof_slab
Q role roof_stair o=facedir:1
R role roof_stair o=facedir:3
S role rug
T role rug_accent
U role seat
V role seat o=facedir:2
W role seat o=facedir:3
X role shelf o=facedir:1
Y role shelf o=facedir:3
Z role shelf_vessels o=facedir:1
a role shutter else=air
b role shutter o=facedir:1 else=air
c role shutter o=facedir:2 else=air
d role shutter o=facedir:3 else=air
e role storage
f role storage o=facedir:3
g role table_leg
h role table_top
i role wall
j role wall_accent
k role window
l role window o=facedir:3
m role window_frame
end

layer 0
|NNNNNNNNNNNNN|
|NHHHHHHHHHHHN|
|NHGGGGGGGTGHN|
|NHGGGGGGGTGHN|
|NHGGGSSGGGGHN|
|NHGGGSSGGGGHN|
|NHGGGGGGGGGHN|
|NHGGGGGGGGGHN|
|NHGGGGGGGGGHN|
|NHHHHHHHHHHHN|
|NNNNNNNNNNNNN|
layer 1
|.........e...|
|.OmjjmmjjmjO.|
|.mA.......IC.|
|.jB......W.j.|
|.jf...V....j.|
|.mY...gg...m.|
|.m....U....m.|
|.j........Xj.|
|.j........Zj.|
|.mjjjjEjmjjm.|
|....e........|
layer 2
|...aa..aa....|
|.OmkkmmkkmiO.|
|.m........JC.|
|bl.........ld|
|bl.........ld|
|.mY...hh...m.|
|.m.........m.|
|bl........Zld|
|bl.........ld|
|.miiiiFimkkm.|
|.........cc..|
layer 3
|...aa..aa....|
|.OmkkmmkkmiO.|
|.m........CC.|
|bl.........ld|
|bl.........ld|
|.mL.......Km.|
|.m.........m.|
|bl.........ld|
|bl.........ld|
|.miiiiiimkkm.|
|....M...Mcc..|
layer 4
|.............|
|.OmiimmiimiO.|
|.m........CC.|
|.i.........i.|
|.i.........i.|
|.m.........m.|
|.m.........m.|
|.i.........i.|
|.i.........i.|
|.miiiiiimiim.|
|.............|
layer 5
|Q...........R|
|QOmiimmiimiOR|
|Qm........CCR|
|Qi.........iR|
|Qi.........iR|
|Qm.........mR|
|Qm.........mR|
|Qi.........iR|
|Qi.........iR|
|QmiiiiiimiimR|
|Q...........R|
layer 6
|.Q.........R.|
|.QiiiiiiiiiR.|
|.Q.........C.|
|.Q.........R.|
|.Q.........R.|
|.Q.........R.|
|.Q.........R.|
|.Q.........R.|
|.Q.........R.|
|.QiiiiiiiiiR.|
|.Q.........R.|
layer 7
|..Q.......R..|
|..QiiiiiiiR..|
|..Q.......RC.|
|..Q.......R..|
|..Q.......R..|
|..Q.......R..|
|..Q.......R..|
|..Q.......R..|
|..Q.......R..|
|..QiiiiiiiR..|
|..Q.......R..|
layer 8
|...Q.....R...|
|...QiiiiiR...|
|...Q.....R.C.|
|...Q.....R...|
|...Q.....R...|
|...Q.....R...|
|...Q.....R...|
|...Q.....R...|
|...Q.....R...|
|...QiiiiiR...|
|...Q.....R...|
layer 9
|....PPPPP....|
|....PPPPP....|
|....PPPPP..C.|
|....PPPPP....|
|....PPPPP....|
|....PPPPP....|
|....PPPPP....|
|....PPPPP....|
|....PPPPP....|
|....PPPPP....|
|....PPPPP....|
layer 10
|.............|
|.............|
|...........D.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 11
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|

points
doors 5 1 8 face=2
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 9 0 7
lights 3 3 9
lights 7 3 9
lights 9 2 1
lights 1 3 4
lights 9 3 4
end

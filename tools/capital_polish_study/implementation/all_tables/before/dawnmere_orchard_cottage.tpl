grudgelands-building-template 1
# Frozen from the building generators (Round 56): dawnmere:orchard_cottage
name dawnmere_orchard_cottage
pivot 9 9
origin -1 0 -1
size 11 12 11
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
Q role roof_stair
R role roof_stair o=facedir:2
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
i role wall_accent
j role wall_infill else=air
k role window
l role window o=facedir:3
m role window_frame
end

layer 0
|NNNNNNNNNNN|
|NHHHHHHHHHN|
|NHGGGGGTGHN|
|NHGGGGGTGHN|
|NHGGSSGGGHN|
|NHGGSSGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHHHHHHHHHN|
|NNNNNNNNNNN|
layer 1
|...........|
|.Omiimmiim.|
|.mA.....IC.|
|.iB....W.i.|
|.if..V...i.|
|.mY..gg..m.|
|.m...U...m.|
|.i......Xi.|
|.i......Zi.|
|.miiEimiim.|
|......e....|
layer 2
|...aa..aa..|
|.Omkkmmkkm.|
|.m......JC.|
|bl.......ld|
|bl.......ld|
|.mY..hh..m.|
|.m.......m.|
|bl......Zld|
|bl.......ld|
|.mjjFjmkkm.|
|.......cc..|
layer 3
|...aa..aa..|
|.Omkkmmkkm.|
|.m......CC.|
|bl.......ld|
|bl.......ld|
|.mL.....Km.|
|.m.......m.|
|bl.......ld|
|bl.......ld|
|.mjjOjmkkm.|
|..M...Mcc..|
layer 4
|...........|
|.OmjOmmOjm.|
|.m......CC.|
|.j.......j.|
|.O.......O.|
|.m.......m.|
|.m.......m.|
|.O.......O.|
|.j.......j.|
|.mjjOjmOjm.|
|...........|
layer 5
|QQQQQQQQQQQ|
|.OmjOmmOjm.|
|.m......CC.|
|.j.......j.|
|.O.......O.|
|.m.......m.|
|.m.......m.|
|.O.......O.|
|.j.......j.|
|.mjjOjmOjm.|
|RRRRRRRRRRR|
layer 6
|...........|
|QQQQQQQQQQQ|
|.j.......C.|
|.j.......j.|
|.O.......O.|
|.j.......j.|
|.j.......j.|
|.O.......O.|
|.j.......j.|
|RRRRRRRRRRR|
|...........|
layer 7
|...........|
|...........|
|QQQQQQQQQCQ|
|.j.......j.|
|.O.......O.|
|.j.......j.|
|.j.......j.|
|.O.......O.|
|RRRRRRRRRRR|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........C.|
|QQQQQQQQQQQ|
|.O.......O.|
|.j.......j.|
|.j.......j.|
|RRRRRRRRRRR|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........C.|
|...........|
|PPPPPPPPPPP|
|PPPPPPPPPPP|
|PPPPPPPPPPP|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........C.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 11
|...........|
|...........|
|.........D.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 3 1 8 face=2
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 7 0 7
lights 1 3 9
lights 5 3 9
lights 7 2 1
lights 1 3 4
lights 7 3 4
end

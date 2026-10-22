grudgelands-building-template 1
# Frozen from the building generators (Round 56): sunscar:chief_lodge
name sunscar_chief_lodge
pivot 9 9
origin -1 0 -1
size 11 9 11
cell 1
meta peak=6
races orc

legend
A node grug_decor:xdecor_potted_rose
B node grug_decor:xdecor_potted_tulip
C role bed variant=_bottom
D role bed variant=_top
E role chimney
F role chimney_cap
G role door variant=_a
H role door_hidden
I role floor
J role foundation
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
Q role post
R role roof_ridge
S role rug
T role rug_accent
U role seat
V role seat o=facedir:2
W role seat o=facedir:3
X role shelf o=facedir:1
Y role shelf o=facedir:3
Z role shelf_vessels o=facedir:1
a role storage
b role storage o=facedir:3
c role table_leg
d role table_top
e role wall_accent
f role wall_infill
g role wall_infill else=f
h role wall_infill else=air
i role window
j role window o=facedir:3
k role window_frame
end

layer 0
| PPPPPPPPP |
|PPJJJJJJJPP|
|PJJIIITIJJP|
|PJIIIITIIJP|
|PJIISSIIIJP|
|PJIISSIIIJP|
|PJIIIIIIIJP|
|PJIIIIIIIJP|
|PJJIIIIIJJP|
|PPJJJJJJJPP|
| PPPPPPPPP |
layer 1
| ......a.. |
|..QeeGeeQ..|
|.QeC...KEQ.|
|.k.D..W..k.|
|Be.b.V...eB|
|Ae.Y.cc..eA|
|Bk...U...kB|
|.e.....X.e.|
|.Qe....ZeQ.|
|..QkeekeQ..|
| ...BAB... |
layer 2
| ......a.. |
|..QhhHhhQ..|
|.Qg....LEQ.|
|.k.......k.|
|.j.......j.|
|.j.Y.dd..j.|
|.k.......k.|
|.h.....Z.h.|
|.Qg.....gQ.|
|..QkiikhQ..|
| ......... |
layer 3
| ..O...O.. |
|..QhhQhhQ..|
|.Qg....EEQ.|
|.kN......k.|
|.j.......j.|
|.j.......j.|
|.k.......k.|
|.h......Mh.|
|.QgN...MgQ.|
|..QkiikhQ..|
| ......... |
layer 4
| ......... |
|..QhhQhhQ..|
|.Qg....EEQ.|
|.k.......k.|
|.h.......h.|
|.Q.......Q.|
|.k.......k.|
|.h.......h.|
|.Qg.....gQ.|
|..QkhQkhQ..|
| ......... |
layer 5
| ......... |
|..QhhQhhQ..|
|.Qg....EEQ.|
|.k.......k.|
|.h.......h.|
|.Q.......Q.|
|.k.......k.|
|.h.......h.|
|.Qg.....gQ.|
|..QkhQkhQ..|
| ......... |
layer 6
| RRRRRRRRR |
|RRRRRRRRRRR|
|RRRRRRRRERR|
|RRRRRRRRRRR|
|RRRRRRRRRRR|
|RRRRRRRRRRR|
|RRRRRRRRRRR|
|RRRRRRRRRRR|
|RRRRRRRRRRR|
|RRRRRRRRRRR|
| RRRRRRRRR |
layer 7
| ......... |
|...........|
|........E..|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
| ......... |
layer 8
| ......... |
|...........|
|........F..|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
| ......... |

points
doors 4 1 0 face=0
inside 3 1 6 id={id}
room_corner 2 0 1 closed=true id={id} top=5
room_corner 6 0 7
room_corner 1 0 2 closed=true id={id} top=5
room_corner 7 0 6
lights 2 3 -1
lights 6 3 -1
lights 6 2 1
lights 2 3 7
lights 6 3 7
end

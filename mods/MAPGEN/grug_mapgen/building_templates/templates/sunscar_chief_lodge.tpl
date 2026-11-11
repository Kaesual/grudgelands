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
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
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
c node grug_decor:xdecor_table
e role wall_accent
f role wall_infill
g role wall_infill else=f
h role wall_infill else=air
i role window
j role window o=facedir:3
J role facade_base
Q role facade_frame
d role facade_infill
k role facade_roof_ridge
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
|..JeeGeeJ..|
|.JeC...KEJ.|
|.J.D..W..J.|
|Be.b.V...eB|
|Ae.Y.cc..eA|
|BJ...U...JB|
|.e.....X.e.|
|.Je....ZeJ.|
|..JJeeJeJ..|
| ...BAB... |
layer 2
| ......a.. |
|..QddHddQ..|
|.Qd....LEQ.|
|.d.......d.|
|.j.......j.|
|.j.Y.....j.|
|.d.......d.|
|.d.....Z.d.|
|.Qd.....dQ.|
|..QdiiddQ..|
| ......... |
layer 3
| ..O...O.. |
|..QddQddQ..|
|.Qd....EEQ.|
|.dN......d.|
|.j.......j.|
|.j.......j.|
|.d.......d.|
|.d......Md.|
|.QdN...MdQ.|
|..QdiiddQ..|
| ......... |
layer 4
| ......... |
|..QddQddQ..|
|.Qd....EEQ.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.Qd.....dQ.|
|..QdddddQ..|
| ......... |
layer 5
| ......... |
|..QhhQhhQ..|
|.Qg....EEQ.|
|.Q.......Q.|
|.h.......h.|
|.Q.......Q.|
|.Q.......Q.|
|.h.......h.|
|.Qg.....gQ.|
|..QQhQQhQ..|
| ......... |
layer 6
| RRRRRRRRR |
|RkkkkkkkRkR|
|RkkkkkkRERR|
|RkkkkkkkRkR|
|RkkkkkkkkkR|
|RkkkkkkkkkR|
|RkkkkkkkkkR|
|RkkkkkkkkkR|
|RkkkkkkkkkR|
|RkkkkkkkkkR|
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

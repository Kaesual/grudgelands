grudgelands-building-template 1
# Frozen from the building generators (Round 56): sunscar:armoury
name sunscar_armoury
pivot 16 13
origin -2 0 -1
size 19 9 15
cell 1
meta peak=6
races orc

legend
A node grug_decor:xdecor_potted_rose
B node grug_decor:xdecor_potted_tulip
C role chimney
D role chimney_cap
E role door variant=_a o=facedir:1
F role door variant=_b o=facedir:1
G role door_hidden
H role door_hidden o=facedir:1
I role floor
J role foundation
K role hearth o=facedir:1
L role hearth o=facedir:2
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role path
R role post
S role roof_ridge
T role roof_stair o=facedir:3
U role rug_accent
V role seat
W role seat o=facedir:2
X role shelf
Y role shelf o=facedir:1
Z role shelf_vessels
a role shelf_vessels o=facedir:1
b role storage
c role storage o=facedir:2
d role storage o=facedir:3
e role table_leg
f role table_top
g role wall
h role wall_accent
i role wheel o=wallmounted:2 else=air
j role window
k role window o=facedir:3
l role window_frame
m role workbench
end

layer 0
| QQQQQQQQQQQQQ     |
| QJJJJJJJJJJJQ     |
| QJIIIIIIIIIJQ     |
| QJIIIIIIIIIJQQQQQQ|
| QJIIIIIIIIIJJJJJJQ|
| QJIIIIIIIIIIIIIIJQ|
| QJIIIIIIIIIIIIIIJQ|
| QJIIIIIIIIIIIIIIJQ|
| QJIIIIIIIIIIUUUIJQ|
| QJIIIUUUIIIIIIIIJQ|
| QJIIIIIIIIIJJJJJJQ|
| QJIIIIIIIIIJQQQQQQ|
| QJIIIIIIIIIJQ     |
| QJJJJJJJJJJJQ     |
| QQQQQQQQQQQQQ     |
layer 1
| ...BAB.......     |
| .RlhhlChhlhR.     |
| .h.mL.L.Lm.h.     |
| Ah.........hBAB...|
| .h.........lhhlhR.|
| .F..........cc..C.|
| .E....W.........hB|
| .h...eee.....m.KhA|
| .l....V.........lB|
| .h..........XZ..h.|
| .hd.......YlhhlhR.|
| .ld.......ahB.b...|
| .hd.......YhA     |
| .Rlhhllhhlhl.     |
| .........b...     |
layer 2
| .............     |
| .RljjlCjjlgR.     |
| .g..M.M.M..g.     |
| .g.........g......|
| .g.........ljjlgR.|
| .G..............C.|
| .H..............k.|
| .g...fff.....D.Mk.|
| il..............l.|
| .k..............g.|
| .k.........ljjlgR.|
| .l.........k......|
| .g.........k.     |
| .Rljjlljjlgl.     |
| .............     |
layer 3
| .............     |
| .RljjlCjjlgR.     |
| .g..C.C.C..g.     |
| .gO.......Ng......|
| Ng.........ljjlgR.|
| .g.............NC.|
| .g..............k.|
| .g.............Ck.|
| Nl..............l.|
| .k............P.g.|
| .k........NljjlgR.|
| .lO........k......|
| .g.........k.     |
| .Rljjlljjlgl.     |
| .............     |
layer 4
| .............     |
| .RlgglCgglgR.     |
| .g..C.C.C..g.     |
| .g.........g......|
| .g.........lgglgR.|
| .g..............C.|
| .g..............g.|
| .g.............Cg.|
| .l..............l.|
| .g..............g.|
| .g.........lgglgR.|
| .l.........g......|
| .g.........g.     |
| .Rlggllgglgl.     |
| .............     |
layer 5
| .............     |
| .RlgglCgglgR.     |
| .g..C.C.C..g.     |
| .g.........g.TSSSS|
| .g.........ggTSSSS|
| .g...........TSSCS|
| .g...........TSSSS|
| .g...........TSSSS|
| .l...........TSSSS|
| .g...........TSSSS|
| .g.........lgTSSSS|
| .l.........g.TSSSS|
| .g.........g.     |
| .Rlggllgglgl.     |
| .............     |
layer 6
| SSSSSSSSSSSSS     |
| SSSSSSCSSSSSS     |
| SSSSSSSSSSSSS     |
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS...C.|
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS.....|
| SSSSSSSSSSSSS     |
| SSSSSSSSSSSSS     |
| SSSSSSSSSSSSS     |
layer 7
| .............     |
| ......C......     |
| .............     |
| ..................|
| ..................|
| ................C.|
| ..................|
| ..................|
| ..................|
| ..................|
| ..................|
| ..................|
| .............     |
| .............     |
| .............     |
layer 8
| .............     |
| ......D......     |
| .............     |
| ..................|
| ..................|
| ................D.|
| ..................|
| ..................|
| ..................|
| ..................|
| ..................|
| ..................|
| .............     |
| .............     |
| .............     |

points
doors 0 1 5 face=1
doors 0 1 4 face=1
inside 2 1 9 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 9 0 11
room_corner 10 0 4 closed=true id={id} top=4
room_corner 14 0 8
lights -1 3 3
lights -1 3 7
lights 3 2 1
lights 5 2 1
lights 7 2 1
lights 1 3 2
lights 9 3 2
lights 1 3 10
lights 9 3 9
lights 14 2 6
lights 14 3 4
lights 13 3 8
sockets -2 1 5 face=1 id=idle_{id}_forge
end

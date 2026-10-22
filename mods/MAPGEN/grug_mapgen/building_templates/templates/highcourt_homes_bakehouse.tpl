grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:homes_bakehouse
name highcourt_homes_bakehouse
pivot 14 11
origin -1 0 -1
size 16 11 13
cell 1
meta extent=[-1,-1,14,11] peak=8 top=10
races human

legend
A role chimney
B role chimney_cap
C role door variant=_a o=facedir:1
D role door variant=_b o=facedir:1
E role door_hidden
F role door_hidden o=facedir:1
G role floor
H role flower else=air
I role flower_alt else=air
J role foundation
K role hearth o=facedir:1
L role hearth o=facedir:2
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role path
R role post
S role roof_slab
T role roof_stair
U role roof_stair o=facedir:1
V role roof_stair o=facedir:2
W role roof_stair o=facedir:3
X role roof_stair_inner
Y role roof_stair_inner o=facedir:3
Z role rug_accent
a role seat
b role seat o=facedir:2
c role shelf
d role shelf o=facedir:1
e role shelf_vessels
f role shelf_vessels o=facedir:1
g role storage o=facedir:1
h role storage o=facedir:2
i role storage o=facedir:3
j role table_leg
k role table_top
l role wall_accent
m role wall_infill else=air
n role window
o role window o=facedir:3
p role window_frame
q role workbench
end

layer 0
|QQQQQQQQQQQQQ   |
|QJJJJJJJJJJJQ   |
|QJGGGGGGGGGJQ   |
|QJGGGGGGGGGJQQQQ|
|QJGGGGGGGGGJJJJQ|
|QJGGGGGGGGGGGGJQ|
|QJGGGGGGGGGGGGJQ|
|QJGGGGGGGGGZZZJQ|
|QJGGGZZZGGGJJJJQ|
|QJGGGGGGGGGJQQQQ|
|QJGGGGGGGGGJQ   |
|QJJJJJJJJJJJQ   |
|QQQQQQQQQQQQQ   |
layer 1
|...HIH.......   |
|.RpllpAllplR.   |
|.p.qL.L.Lq.l.   |
|.l.........lHI..|
|Il.........pllp.|
|.p....b.....hhAI|
|.D...jjj....qKlH|
|.C....a.....celI|
|.li.......dpllp.|
|.li.......flH...|
|.li.......dlI   |
|.Rpllppllplp.   |
|.........g...   |
layer 2
|.............   |
|.RpnnpAnnpRR.   |
|.p..M.M.M..m.   |
|.o.........m....|
|.o.........pnnp.|
|.p............A.|
|.E...kkk....BMo.|
|.F............o.|
|.m.........pnnp.|
|.m.........o....|
|.R.........o.   |
|.RpnnppnnpRp.   |
|.............   |
layer 3
|.............   |
|.RpnnpAnnpRR.   |
|.pO.A.A.A..m.   |
|.o........Nm....|
|.o.........pnnp.|
|Np...........NA.|
|.m...........Ao.|
|.R.........P..o.|
|.m........Npnnp.|
|NmO........o....|
|.R.........o.   |
|.RpnnppnnpRp.   |
|.............   |
layer 4
|U...........W   |
|URpmRpARmpRRW   |
|Up..A.A.A..mW   |
|Um.........mXTTT|
|UR.........pmRp.|
|Up............A.|
|Um...........Am.|
|UR............R.|
|Um.........pmRp.|
|Um.........mYVVV|
|UR.........RW   |
|URpmRppRmpRpW   |
|U...........W   |
layer 5
|.U.........W.   |
|.UmmRmARmmRW.   |
|.U.........W.   |
|.U.........W....|
|.U.........XTTTT|
|.U............A.|
|.U............m.|
|.U............R.|
|.U.........YVVVV|
|.U.........W....|
|.U.........W.   |
|.UmmRmmRmmRW.   |
|.U.........W.   |
layer 6
|..U.......W..   |
|..UmRmARmmW..   |
|..U.......W..   |
|..U.......W.....|
|..U.......W.....|
|..U.......XTTTAT|
|..U...........m.|
|..U.......YVVVVV|
|..U.......W.....|
|..U.......W.....|
|..U.......W..   |
|..UmRmmRmmW..   |
|..U.......W..   |
layer 7
|...U.....W...   |
|...URmARmW...   |
|...U.....W...   |
|...U.....W......|
|...U.....W......|
|...U.....W....A.|
|...U.....WSSSSSS|
|...U.....W......|
|...U.....W......|
|...U.....W......|
|...U.....W...   |
|...URmmRmW...   |
|...U.....W...   |
layer 8
|....SSSSS....   |
|....SSASS....   |
|....SSSSS....   |
|....SSSSS.......|
|....SSSSS.......|
|....SSSSS.....A.|
|....SSSSS.......|
|....SSSSS.......|
|....SSSSS.......|
|....SSSSS.......|
|....SSSSS....   |
|....SSSSS....   |
|....SSSSS....   |
layer 9
|.............   |
|......A......   |
|.............   |
|................|
|................|
|..............A.|
|................|
|................|
|................|
|................|
|.............   |
|.............   |
|.............   |
layer 10
|.............   |
|......B......   |
|.............   |
|................|
|................|
|..............B.|
|................|
|................|
|................|
|................|
|.............   |
|.............   |
|.............   |

points
doors 0 1 6 face=1
doors 0 1 5 face=1
inside 2 1 7 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 9 0 9
room_corner 10 0 4 closed=true id={id} top=4
room_corner 12 0 6
lights -1 3 4
lights -1 3 8
lights 3 2 1
lights 5 2 1
lights 7 2 1
lights 1 3 1
lights 9 3 2
lights 1 3 8
lights 9 3 7
lights 12 2 5
lights 12 3 4
lights 10 3 6
end

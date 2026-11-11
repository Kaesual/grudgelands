grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:garrison_watch_tower, dur_brannoc:deep_watch, dur_brannoc:terrace_watch
name dur_brannoc_garrison_watch_tower
pivot 9 9
origin -1 0 -1
size 11 13 11
cell 1
meta extent=[-1,-1,9,9] peak=12 top=12
races dwarf

legend
A node grug_decor:xdecor_potted_dandelion_white
C role bed variant=_bottom
D role bed variant=_top
E role door variant=_a o=facedir:1
F role door_hidden o=facedir:1
G role floor
H role foundation
I role light_post o=wallmounted:1
J role light_wall o=wallmounted:2
K role light_wall o=wallmounted:3
L role path
N role railing
P role roof_stair
X role seat
Y role seat o=facedir:2
Z role storage o=facedir:1
a role storage o=facedir:3
b node grug_decor:xdecor_table
f role window
g role window o=facedir:3
B role facade_roof_stair_outer o=facedir:1
M role facade_roof_stair o=facedir:1
O role facade_roof_stair_outer o=facedir:2
Q role facade_base
R role facade_infill
S role facade_roof_stair o=facedir:0
T role facade_roof_stair o=facedir:2
U role facade_roof_slab o=facedir:0
V role facade_roof_stair_outer o=facedir:0
W role facade_roof_stair o=facedir:3
c role facade_roof_stair_outer o=facedir:3
end

layer 0
|LLLLLLLLLLL|
|LHHHHHHHHHL|
|LHGGGGGGGHL|
|LHGGGGGGGHL|
|LHGGGGGGGHL|
|LHGGGGGGGHL|
|LHGGGGGGGHL|
|LHGGGGGGGHL|
|LHGGGGGGGHL|
|LHHHHHHHHHL|
|LLLLLLLLLLL|
layer 1
|...a.......|
|.QQQQQQQQQ.|
|.QC.....ZQ.|
|AQDP.....Q.|
|.Q.......Q.|
|.E.......Q.|
|.Q.....Y.Q.|
|.Q.....bbQ.|
|.Q.....X.Q.|
|.QQQQQQQQQ.|
|...........|
layer 2
|...........|
|.QRRRQRRRQ.|
|.R.......R.|
|.R.......R.|
|.Q.P.....R.|
|.F.......Q.|
|.R.......R.|
|.R.......R.|
|.R.......R.|
|.QRRRQRRRQ.|
|...........|
layer 3
|...........|
|.QRfRQRfRQ.|
|JR.......R.|
|.g.......g.|
|.Q.......R.|
|.RKP.....Q.|
|.R.......R.|
|.g.......g.|
|JR.......R.|
|.QRfRQRfRQ.|
|...........|
layer 4
|...........|
|.QQfQQQfQQ.|
|.Q.......Q.|
|.g.......g.|
|.Q.......Q.|
|.Q.......Q.|
|.Q.P.....Q.|
|.g.......g.|
|.Q.......Q.|
|.QQfQQQfQQ.|
|...........|
layer 5
|...........|
|.GGGGGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GG.GGGGGG.|
|.GGPGGGGGG.|
|.GGGGGGGGG.|
|.GGGGGGGGG.|
|...........|
layer 6
|...........|
|.QRRRRRRRQ.|
|.RI.....IR.|
|.R.......R.|
|.R.......R.|
|.R.......R.|
|.R.......R.|
|.R.......R.|
|.RI.....IR.|
|.QRRRRRRRQ.|
|...........|
layer 7
|...........|
|.Q.N.N.N.Q.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.Q.N.N.N.Q.|
|...........|
layer 8
|BSSSSSSSSSV|
|MQQQQQQQQQW|
|MQ.......QW|
|MQ.......QW|
|MQ.......QW|
|MQ.......QW|
|MQ.......QW|
|MQ.......QW|
|MQ.......QW|
|MQQQQQQQQQW|
|OTTTTTTTTTc|
layer 9
|...........|
|.BSSSSSSSV.|
|.M.......W.|
|.M.......W.|
|.M.......W.|
|.M.......W.|
|.M.......W.|
|.M.......W.|
|.M.......W.|
|.OTTTTTTTc.|
|...........|
layer 10
|...........|
|...........|
|..BSSSSSV..|
|..M.....W..|
|..M.....W..|
|..M.....W..|
|..M.....W..|
|..M.....W..|
|..OTTTTTc..|
|...........|
|...........|
layer 11
|...........|
|...........|
|...........|
|...BSSSV...|
|...M...W...|
|...M...W...|
|...M...W...|
|...OTTTc...|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|...........|
|...........|
|....UUU....|
|....UUU....|
|....UUU....|
|...........|
|...........|
|...........|
|...........|

points
doors 0 1 4 face=1
inside 5 6 4 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 7
lights -1 3 1
lights -1 3 7
lights 1 3 4
lights 1 6 1
lights 7 6 1
lights 1 6 7
lights 7 6 7
end

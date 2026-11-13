grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:martial_watch_tower
name highcourt_martial_watch_tower
pivot 9 9
origin -1 0 -1
size 11 13 11
cell 1
meta extent=[-1,-1,9,9] peak=12 top=12
races human

legend
B role bed variant=_bottom
C role bed variant=_top
D role door variant=_a o=facedir:1
E role door_hidden o=facedir:1
F role floor
G role flower_alt else=air
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
A role facade_service_roof_stair_outer o=facedir:1
H role facade_service_roof_stair o=facedir:1
M role facade_service_roof_stair_outer o=facedir:2
O role facade_base
Q role facade_frame
R role facade_infill
S role facade_service_roof_stair o=facedir:0
T role facade_service_roof_stair o=facedir:2
U role facade_service_roof_slab o=facedir:0
V role facade_service_roof_stair_outer o=facedir:0
W role facade_service_roof_stair o=facedir:3
c role facade_service_roof_stair_outer o=facedir:3
end

layer 0
|LLLLLLLLLLL|
|LOOOOOOOOOL|
|LOFFFFFFFOL|
|LOFFFFFFFOL|
|LOFFFFFFFOL|
|LOFFFFFFFOL|
|LOFFFFFFFOL|
|LOFFFFFFFOL|
|LOFFFFFFFOL|
|LOOOOOOOOOL|
|LLLLLLLLLLL|
layer 1
|...a.......|
|.OOOOOOOOO.|
|.OB.....ZO.|
|GOCP.....O.|
|.O.......O.|
|.D.......O.|
|.O.....Y.O.|
|.O.....bbO.|
|.O.....X.O.|
|.OOOOOOOOO.|
|...........|
layer 2
|...........|
|.QRRRQRRRQ.|
|.R.......R.|
|.R.......R.|
|.Q.P.....R.|
|.E.......Q.|
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
|.FFFFFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FFPFFFFFF.|
|.FFFFFFFFF.|
|.FFFFFFFFF.|
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
|ASSSSSSSSSV|
|HQQQQQQQQQW|
|HQ.......QW|
|HQ.......QW|
|HQ.......QW|
|HQ.......QW|
|HQ.......QW|
|HQ.......QW|
|HQ.......QW|
|HQQQQQQQQQW|
|MTTTTTTTTTc|
layer 9
|...........|
|.ASSSSSSSV.|
|.H.......W.|
|.H.......W.|
|.H.......W.|
|.H.......W.|
|.H.......W.|
|.H.......W.|
|.H.......W.|
|.MTTTTTTTc.|
|...........|
layer 10
|...........|
|...........|
|..ASSSSSV..|
|..H.....W..|
|..H.....W..|
|..H.....W..|
|..H.....W..|
|..H.....W..|
|..MTTTTTc..|
|...........|
|...........|
layer 11
|...........|
|...........|
|...........|
|...ASSSV...|
|...H...W...|
|...H...W...|
|...H...W...|
|...MTTTc...|
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

grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:gate_south, nhal_veyr:gate_west, nhal_veyr:gate_north, nhal_veyr:gate_east
name nhal_veyr_gate_south
pivot 13 7
origin 0 -2 0
size 13 17 7
cell 1
meta arrowslits=7 extent=[0,0,12,6] merlons=18 peak=14 top=14
races undead

legend
A role castle_paving else=F
B role castle_paving else=air
C role castle_slit o=facedir:1 else=P
D role castle_slit o=facedir:2 else=F
E role castle_slit o=facedir:3 else=P
F role castle_wall
G role castle_wall else=air
H role castle_wall_stair o=facedir:1 else=air
I role castle_wall_stair o=facedir:3 else=air
J role door variant=_a o=facedir:2
K role door_hidden o=facedir:2
L role floor
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:5
P role signature
Q role signature else=air
R role signature_slab else=air
S role window
end

layer -2
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
layer -1
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
|FFFFFFFFFFFFF|
layer 0
|FFFFAAAAAFFFF|
|FLLFAAAAAFLLF|
|FLLFAAAAAFLLF|
|FLLFAAAAAFLLF|
|FLLFAAAAAFLLF|
|FLLFAAAAAFLLF|
|FFFFAAAAAFFFF|
layer 1
|GGGG.....GGGG|
|G..G.....G..G|
|G..G.....G..G|
|G..G.....G..G|
|G..G.....G..G|
|G..G.....G..G|
|GJGG.....GGJG|
layer 2
|GGGG.....GGGG|
|G..G.....G..G|
|G..G.....G..G|
|G..G.....G..G|
|G..G.....G..G|
|G..G.....G..G|
|GKGG.....GGKG|
layer 3
|QQQQ.....QQQQ|
|QO.C.....E.OQ|
|Q..Q.....Q..Q|
|Q..Q.....Q..Q|
|Q..Q.....Q..Q|
|Q..C.....E..Q|
|QQQQ.....QQQQ|
layer 4
|GGGG.....GGGG|
|GGGGN...MGGGG|
|GGGG.....GGGG|
|GGGG.....GGGG|
|GGGG.....GGGG|
|GGGG.....GGGG|
|GGGG.....GGGG|
layer 5
|GGGGH...IGGGG|
|GGGGH...IGGGG|
|GGGGH...IGGGG|
|GGGGH...IGGGG|
|GGGGH...IGGGG|
|GGGGH...IGGGG|
|GGGGH...IGGGG|
layer 6
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
layer 7
|GGGGGGGGGGGGG|
|G...........G|
|.............|
|.............|
|.............|
|G.H.........G|
|GGGGGGGGGGGGG|
layer 8
|GGGDGGDGGDGGG|
|G...........G|
|.............|
|.............|
|.............|
|G..H........G|
|GGGSGGSGGSGGG|
layer 9
|GGGGGGGGGGGGG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G...H.......G|
|GGGSGGSGGSGGG|
layer 10
|QQQQQQQQQQQQQ|
|Q...........Q|
|Q...........Q|
|Q...........Q|
|Q...........Q|
|Q....H......Q|
|QQQQQQQQQQQQQ|
layer 11
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBB...HBBBBBB|
|BBBBBBBBBBBBB|
layer 12
|GGGGGGGGGGGGG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|GGGGGGGGGGGGG|
layer 13
|G.G.G.G.G.G.G|
|.............|
|G...........G|
|.............|
|G...........G|
|.............|
|G.G.G.G.G.G.G|
layer 14
|R.R.R.R.R.R.R|
|.............|
|R...........R|
|.............|
|R...........R|
|.............|
|R.R.R.R.R.R.R|

points
doors 1 1 6 face=2
doors 11 1 6 face=2
inside 1 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=3
room_corner 2 0 5
lights 1 3 1
lights 11 3 1
lights 4 4 1
lights 8 4 1
sockets 4 1 1 face=2 id={id}_post_west role=guard_post
sockets 8 1 1 face=2 id={id}_post_east role=guard_post
sockets 6 7 3 face=2 group=nhal_veyr_{id}_tower id={id}_rampart order=2 role=guard_patrol
sockets 6 12 3 face=2 group=nhal_veyr_{id}_tower id={id}_deck order=1 role=guard_patrol
sockets 1 1 4 face=2 id={id}_idle_west role=idle tags=[fire]
sockets 11 1 4 face=2 id={id}_idle_east role=idle tags=[fire]
end

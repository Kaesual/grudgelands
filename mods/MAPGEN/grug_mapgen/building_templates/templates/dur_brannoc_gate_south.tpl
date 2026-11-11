grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:gate_south, dur_brannoc:gate_west, dur_brannoc:gate_north, dur_brannoc:gate_east
name dur_brannoc_gate_south
pivot 13 7
origin 0 -2 0
size 13 17 7
cell 1
meta arrowslits=7 extent=[0,0,12,6] merlons=18 peak=14 top=14
races dwarf

legend
A role castle_paving else=F
B role castle_paving else=air
C role castle_slit o=facedir:1 else=P
D role castle_slit o=facedir:2 else=F
E role castle_slit o=facedir:3 else=P
F role castle_wall
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
G role facade_base
H role facade_infill
I role facade_stone_stair o=facedir:1
T role facade_stone_stair o=facedir:21
U role facade_stone_stair o=facedir:23
V role facade_stone_stair o=facedir:0
W role facade_stone_stair o=facedir:2
end

layer -2
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
layer -1
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
|GGGGGGGGGGGGG|
layer 0
|GGGGAAAAAGGGG|
|GLLGAAAAAGLLG|
|GLLGAAAAAGLLG|
|GLLGAAAAAGLLG|
|GLLGAAAAAGLLG|
|GLLGAAAAAGLLG|
|GGGGAAAAAGGGG|
layer 1
|GHHG.....GHHG|
|G..G.....GHHG|
|G..G.....G.HG|
|G..G.....G.HG|
|G..G.....G.WG|
|G..G.....G..G|
|GHJG.....GJHG|
layer 2
|GHHG.....GHHG|
|G..G.....GHHG|
|G..G.....G.HG|
|G..G.....G.WG|
|G..G.....G..G|
|G..G.....G..G|
|GHKG.....GKHG|
layer 3
|QHHQ.....QHHQ|
|QO.C.....EHHQ|
|Q..Q.....Q.WQ|
|Q..Q.....Q..Q|
|Q..Q.....Q..Q|
|Q..C.....E..Q|
|QHHQ.....QHHQ|
layer 4
|GHHG.....GHHG|
|GHHGN...MG..G|
|GHHG.....GV.G|
|GHHG.....GH.G|
|GHHG.....GH.G|
|GHHG.....GHHG|
|GHHG.....GHHG|
layer 5
|GHHGT...UGHHG|
|GHHGT...UG.OG|
|GHHGT...UG..G|
|GHHGT...UGV.G|
|GHHGT...UGHHG|
|GHHGT...UGHHG|
|GHHGT...UGHHG|
layer 6
|LLLLLLLLLLLLL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLLVLL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
layer 7
|GHHGHHHHHGHHG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G.I.........G|
|GHHGHHHHHGHHG|
layer 8
|GHHDHHDHHDHHG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G..I........G|
|GHHSHHSHHSHHG|
layer 9
|GHHGHHHHHGHHG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G...I.......G|
|GHHSHHSHHSHHG|
layer 10
|QHHQHHHHHQHHQ|
|Q...........Q|
|Q...........Q|
|Q...........Q|
|Q...........Q|
|Q....I......Q|
|QHHQHHHHHQHHQ|
layer 11
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BB....IBBBBBB|
|BBBBBBBBBBBBB|
layer 12
|GHHGHHHHHGHHG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|GHHGHHHHHGHHG|
layer 13
|G.H.H.H.H.H.G|
|.............|
|G...........G|
|.............|
|G...........G|
|.............|
|G.H.H.H.H.H.G|
layer 14
|R.R.R.R.R.R.R|
|.............|
|R...........R|
|.............|
|R...........R|
|.............|
|R.R.R.R.R.R.R|

points
doors 2 1 6 face=2
doors 10 1 6 face=2
inside 1 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=3
room_corner 2 0 5
lights 1 3 1
lights 11 5 1
lights 4 4 1
lights 8 4 1
sockets 4 1 1 face=2 id={id}_post_west role=guard_post
sockets 8 1 1 face=2 id={id}_post_east role=guard_post
sockets 6 7 3 face=2 group=dur_brannoc_{id}_tower id={id}_rampart order=2 role=guard_patrol
sockets 6 12 3 face=2 group=dur_brannoc_{id}_tower id={id}_deck order=1 role=guard_patrol
sockets 2 1 4 face=2 id={id}_idle_west role=idle tags=[fire]
sockets 10 1 4 face=2 id={id}_idle_east role=idle tags=[fire]
end

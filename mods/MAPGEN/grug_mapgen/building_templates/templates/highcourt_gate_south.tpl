grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:gate_south, highcourt:gate_west, highcourt:gate_north, highcourt:gate_east
name highcourt_gate_south
pivot 13 7
origin 0 -2 0
size 13 17 7
cell 1
meta arrowslits=7 extent=[0,0,12,6] merlons=18 peak=14 top=14
races human

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
S role window
G role facade_base
H role facade_stone_slab o=facedir:0
I role facade_masonry
Q role facade_stone_stair o=facedir:1
R role facade_stone_stair o=facedir:21
T role facade_stone_stair o=facedir:23
U role facade_stone_stair o=facedir:0
V role facade_stone_stair o=facedir:2
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
|GIIG.....GIIG|
|G..G.....GIIG|
|G..G.....G.IG|
|G..G.....G.IG|
|G..G.....G.VG|
|G..G.....G..G|
|GIJG.....GJIG|
layer 2
|GIIG.....GIIG|
|G..G.....GIIG|
|G..G.....G.IG|
|G..G.....G.VG|
|G..G.....G..G|
|G..G.....G..G|
|GIKG.....GKIG|
layer 3
|GIIG.....GIIG|
|GO.C.....EIIG|
|G..G.....G.VG|
|G..G.....G..G|
|G..G.....G..G|
|G..C.....E..G|
|GIIG.....GIIG|
layer 4
|GIIG.....GIIG|
|GIIGN...MG..G|
|GIIG.....GU.G|
|GIIG.....GI.G|
|GIIG.....GI.G|
|GIIG.....GIIG|
|GIIG.....GIIG|
layer 5
|GIIGR...TGIIG|
|GIIGR...TG.OG|
|GIIGR...TG..G|
|GIIGR...TGU.G|
|GIIGR...TGIIG|
|GIIGR...TGIIG|
|GIIGR...TGIIG|
layer 6
|LLLLLLLLLLLLL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLLULL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
layer 7
|GIIGIIIIIGIIG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G.Q.........G|
|GIIGIIIIIGIIG|
layer 8
|GIIDIIDIIDIIG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G..Q........G|
|GIISIISIISIIG|
layer 9
|GIIGIIIIIGIIG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G...Q.......G|
|GIISIISIISIIG|
layer 10
|GIIGIIIIIGIIG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G....Q......G|
|GIIGIIIIIGIIG|
layer 11
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BB....QBBBBBB|
|BBBBBBBBBBBBB|
layer 12
|GIIGIIIIIGIIG|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|G...........G|
|GIIGIIIIIGIIG|
layer 13
|G.I.I.I.I.I.G|
|.............|
|G...........G|
|.............|
|G...........G|
|.............|
|G.I.I.I.I.I.G|
layer 14
|H.H.H.H.H.H.H|
|.............|
|H...........H|
|.............|
|H...........H|
|.............|
|H.H.H.H.H.H.H|

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
sockets 6 7 3 face=2 group=highcourt_{id}_tower id={id}_rampart order=2 role=guard_patrol
sockets 6 12 3 face=2 group=highcourt_{id}_tower id={id}_deck order=1 role=guard_patrol
sockets 2 1 4 face=2 id={id}_idle_west role=idle tags=[fire]
sockets 10 1 4 face=2 id={id}_idle_east role=idle tags=[fire]
end

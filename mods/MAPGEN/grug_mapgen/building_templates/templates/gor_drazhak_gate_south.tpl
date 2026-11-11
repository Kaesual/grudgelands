grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:gate_south, gor_drazhak:gate_west, gor_drazhak:gate_north, gor_drazhak:gate_east
name gor_drazhak_gate_south
pivot 13 7
origin 0 -2 0
size 13 17 7
cell 1
meta arrowslits=7 extent=[0,0,12,6] merlons=18 peak=14 top=14
races orc

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
R role signature_slab else=air
S role window
G role facade_base
H role facade_frame
I role facade_stone_stair o=facedir:1
Q role facade_stone_stair o=facedir:21
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
|HGGH.....HGGH|
|H..H.....HGGH|
|H..H.....H.GH|
|H..H.....H.GH|
|H..H.....H.VH|
|H..H.....H..H|
|HGJH.....HJGH|
layer 2
|HGGH.....HGGH|
|H..H.....HGGH|
|H..H.....H.GH|
|H..H.....H.VH|
|H..H.....H..H|
|H..H.....H..H|
|HGKH.....HKGH|
layer 3
|HGGH.....HGGH|
|HO.C.....EGGH|
|H..H.....H.VH|
|H..H.....H..H|
|H..H.....H..H|
|H..C.....E..H|
|HGGH.....HGGH|
layer 4
|HGGH.....HGGH|
|HGGHN...MH..H|
|HGGH.....HU.H|
|HGGH.....HG.H|
|HGGH.....HG.H|
|HGGH.....HGGH|
|HGGH.....HGGH|
layer 5
|HGGHQ...THGGH|
|HGGHQ...TH.OH|
|HGGHQ...TH..H|
|HGGHQ...THU.H|
|HGGHQ...THGGH|
|HGGHQ...THGGH|
|HGGHQ...THGGH|
layer 6
|LLLLLLLLLLLLL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLLULL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
layer 7
|HGGHGGGGGHGGH|
|H...........H|
|H...........H|
|H...........H|
|H...........H|
|H.I.........H|
|HGGHGGGGGHGGH|
layer 8
|HGGDGGDGGDGGH|
|H...........H|
|H...........H|
|H...........H|
|H...........H|
|H..I........H|
|HGGSGGSGGSGGH|
layer 9
|HGGHGGGGGHGGH|
|H...........H|
|H...........H|
|H...........H|
|H...........H|
|H...I.......H|
|HGGSGGSGGSGGH|
layer 10
|HGGHGGGGGHGGH|
|H...........H|
|H...........H|
|H...........H|
|H...........H|
|H....I......H|
|HGGHGGGGGHGGH|
layer 11
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BB....IBBBBBB|
|BBBBBBBBBBBBB|
layer 12
|HGGHGGGGGHGGH|
|H...........H|
|H...........H|
|H...........H|
|H...........H|
|H...........H|
|HGGHGGGGGHGGH|
layer 13
|H.G.G.G.G.G.H|
|.............|
|H...........H|
|.............|
|H...........H|
|.............|
|H.G.G.G.G.G.H|
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
sockets 6 7 3 face=2 group=gor_drazhak_{id}_tower id={id}_rampart order=2 role=guard_patrol
sockets 6 12 3 face=2 group=gor_drazhak_{id}_tower id={id}_deck order=1 role=guard_patrol
sockets 2 1 4 face=2 id={id}_idle_west role=idle tags=[fire]
sockets 10 1 4 face=2 id={id}_idle_east role=idle tags=[fire]
end

grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:gate_south, lethariel:gate_west, lethariel:gate_east
name lethariel_gate_south
pivot 13 7
origin 0 -2 0
size 13 17 7
cell 1
meta arrowslits=7 extent=[0,0,12,6] merlons=18 peak=14 top=14
races elf

legend
A role castle_paving else=F
B role castle_paving else=air
C role castle_slit o=facedir:1 else=P
D role castle_slit o=facedir:2 else=F
E role castle_slit o=facedir:3 else=P
F role castle_wall
G role castle_wall else=air
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
H role facade_base
I role facade_frame
T role facade_masonry
U role facade_roof_stair o=facedir:1
V role facade_roof_stair o=facedir:21
W role facade_roof_stair o=facedir:23
X role facade_roof_stair o=facedir:0
Y role facade_roof_stair o=facedir:2
end

layer -2
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
layer -1
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
|HHHHHHHHHHHHH|
layer 0
|HHHHAAAAAHHHH|
|HLLHAAAAAHLLH|
|HLLHAAAAAHLLH|
|HLLHAAAAAHLLH|
|HLLHAAAAAHLLH|
|HLLHAAAAAHLLH|
|HHHHAAAAAHHHH|
layer 1
|IGGI.....IGGI|
|I..I.....IFFI|
|I..I.....I.FI|
|I..I.....I.FI|
|I..I.....I.YI|
|I..I.....I..I|
|IGJI.....IJGI|
layer 2
|IGGI.....IGGI|
|I..I.....IFFI|
|I..I.....I.FI|
|I..I.....I.YI|
|I..I.....I..I|
|I..I.....I..I|
|IGKI.....IKGI|
layer 3
|QTTQ.....QTTQ|
|QO.C.....EFFQ|
|Q..Q.....Q.YQ|
|Q..Q.....Q..Q|
|Q..Q.....Q..Q|
|Q..C.....E..Q|
|QTTQ.....QTTQ|
layer 4
|IGGI.....IGGI|
|IGGIN...MI..I|
|IGGI.....IX.I|
|IGGI.....IG.I|
|IGGI.....IG.I|
|IGGI.....IGGI|
|IGGI.....IGGI|
layer 5
|IGGIV...WIGGI|
|IGGIV...WI.OI|
|IGGIV...WI..I|
|IGGIV...WIX.I|
|IGGIV...WIGGI|
|IGGIV...WIGGI|
|IGGIV...WIGGI|
layer 6
|LLLLLLLLLLLLL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLL.LL|
|LLLLLLLLLLXLL|
|LLLLLLLLLLLLL|
|LLLLLLLLLLLLL|
layer 7
|IGGIGGGGGIGGI|
|I...........I|
|I...........I|
|I...........I|
|I...........I|
|I.U.........I|
|IGGIGGGGGIGGI|
layer 8
|IGGDGGDGGDGGI|
|I...........I|
|I...........I|
|I...........I|
|I...........I|
|I..U........I|
|IGGSGGSGGSGGI|
layer 9
|IGGIGGGGGIGGI|
|I...........I|
|I...........I|
|I...........I|
|I...........I|
|I...U.......I|
|IGGSGGSGGSGGI|
layer 10
|QTTQTTTTTQTTQ|
|Q...........Q|
|Q...........Q|
|Q...........Q|
|Q...........Q|
|Q....U......Q|
|QTTQTTTTTQTTQ|
layer 11
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BBBBBBBBBBBBB|
|BB....UBBBBBB|
|BBBBBBBBBBBBB|
layer 12
|IGGIGGGGGIGGI|
|I...........I|
|I...........I|
|I...........I|
|I...........I|
|I...........I|
|IGGIGGGGGIGGI|
layer 13
|I.G.G.G.G.G.I|
|.............|
|I...........I|
|.............|
|I...........I|
|.............|
|I.G.G.G.G.G.I|
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
sockets 6 7 3 face=2 group=lethariel_{id}_tower id={id}_rampart order=2 role=guard_patrol
sockets 6 12 3 face=2 group=lethariel_{id}_tower id={id}_deck order=1 role=guard_patrol
sockets 2 1 4 face=2 id={id}_idle_west role=idle tags=[fire]
sockets 10 1 4 face=2 id={id}_idle_east role=idle tags=[fire]
end

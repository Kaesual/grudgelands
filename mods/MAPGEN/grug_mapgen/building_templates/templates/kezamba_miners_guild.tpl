grudgelands-building-template 1
# Round 58 lane HALLS: the Miner's Guild house of Kezamba, written by
# tools/r58_halls/make_halls.py (edit the script, not this file).
name kezamba_miners_guild
pivot 11 15
origin -1 0 -1
size 13 8 17
cell 1
meta extent=[-1,-1,11,15] peak=7 top=7
races troll

legend
A node default:coalblock
B node default:stone
C node grug_decor:castle_rubble
D node grug_decor:cottages_tub
E node grug_decor:cottages_wagon_load
F node grug_decor:cottages_wagon_wheel o=wallmounted:2
G node grug_decor:cottages_wagon_wheel o=wallmounted:3
H node grug_decor:xdecor_rope
I node grug_materials:copper_block
J node grug_materials:t2_stone
K node grug_materials:t3_stone
L node grug_materials:t4_stone
M node grug_materials:t5_stone
N node grug_materials:t6_stone
O node wool:black
P node wool:red
Q role beam
R role ceiling
S role door variant=_a
T role door_hidden
U role fence
V role floor
W role foundation
X role light_wall o=wallmounted:2
Y role light_wall o=wallmounted:3
Z role light_wall o=wallmounted:4
a role path
b role rug
c role shelf o=facedir:2
d role storage o=facedir:1
e role storage o=facedir:3
f role table_leg
g role table_top
h role wall
i role wall_accent
j role window o=facedir:0
k role window o=facedir:3
end

layer 0
|aaaaaaaaaaaaa|
|aaaaaaaaaaaaa|
|aaaaaaaaaaaaa|
|aWWWWWWWWWWWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVbVVVVWa|
|aWVVVVVVVVVWa|
|aWVVVVVVVVVWa|
|aWWWWWWWWWWWa|
|aaaaaaaaaaaaa|
layer 1
|.............|
|.UDU.....FEG.|
|.C........AC.|
|.iiiiiSiiiii.|
|.i........Ai.|
|.i........ei.|
|.i.......f.i.|
|.i.f.....f.i.|
|.i.......f.i.|
|.i.........i.|
|.i.f.......i.|
|.id........i.|
|.i.........i.|
|.i...fff...i.|
|.idc.....cei.|
|.iiiiiiiiiii.|
|.............|
layer 2
|.............|
|.UHU.........|
|.............|
|.ihjPiTiPjhi.|
|.h........Ih.|
|.k.........k.|
|.k.......g.k.|
|.h.g.....g.h.|
|.h.......g.h.|
|.k.........k.|
|.k.g.......k.|
|.h.........h.|
|.h.........h.|
|.h...ggg...h.|
|.hdc.....ceh.|
|.ihBJKLMNhhi.|
|.............|
layer 3
|.............|
|.UHU.........|
|.....Z.Z.....|
|.ihjPiiiPjhi.|
|.hY.......Xh.|
|.k.........k.|
|.k.........k.|
|.h.........h.|
|.h.........h.|
|.k.........k.|
|.k.........k.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.hY.......Xh.|
|.ihiiiiiihhi.|
|.............|
layer 4
|.............|
|.QQQ.........|
|.............|
|.ihhOhIhOhhi.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.h.........h.|
|.ihhhhhhhhhi.|
|.............|
layer 5
|.............|
|.............|
|.............|
|.iiiiiiiiiii.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.iQQQQQQQQQi.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.iQQQQQQQQQi.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.iiiiiiiiiii.|
|.............|
layer 6
|.............|
|.............|
|.............|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.RRRRRRRRRRR.|
|.............|
layer 7
|.............|
|.............|
|.............|
|.iiiiiiiiiii.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.iiiiiiiiiii.|
|.............|

points
doors 5 1 2 face=0
inside 5 1 4 id={id}
room_corner 1 0 3 closed=true id={id} top=5
room_corner 9 0 13
lights 1 3 3
lights 9 3 3
lights 1 3 13
lights 9 3 13
lights 4 3 1
lights 6 3 1
sockets 5 1 13 face=2 id={id}_leader role=quest
sockets 9 1 6 face=3 id={id}_exchange role=idle tags=[work]
sockets 1 1 6 face=1 id={id}_clerk role=idle tags=[work]
sockets 1 1 9 face=1 id={id}_sorter role=idle tags=[work]
sockets 7 1 1 face=0 id={id}_porter role=idle tags=[door]
end

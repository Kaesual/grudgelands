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
b role post
c role rug
d role shelf o=facedir:2
e role storage o=facedir:1
f role storage o=facedir:3
g role table_leg
h role table_top
i role wall
j role wall_accent
k role window o=facedir:0
l role window o=facedir:3
end

layer 0
|aaaaaaaaaaaaa|
|aaaaaaaaaaaaa|
|aaaaaaaaaaaaa|
|aWWWWWWWWWWWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVcVVVVWa|
|aWVVVVVVVVVWa|
|aWVVVVVVVVVWa|
|aWWWWWWWWWWWa|
|aaaaaaaaaaaaa|
layer 1
|.............|
|.UDU.....FEG.|
|.C........AC.|
|.jjjjjSjjjjj.|
|.j........Aj.|
|.j........fj.|
|.j.......g.j.|
|.j.g.....g.j.|
|.j.......g.j.|
|.j.........j.|
|.j.g.......j.|
|.je........j.|
|.j.........j.|
|.j...ggg...j.|
|.jed.....dfj.|
|.jbjjjjjjbjj.|
|.............|
layer 2
|.............|
|.UHU.........|
|.............|
|.jikPjTjPkij.|
|.i........Ii.|
|.l.........l.|
|.l.......h.l.|
|.i.h.....h.i.|
|.i.......h.i.|
|.l.........l.|
|.l.h.......l.|
|.i.........i.|
|.i.........i.|
|.i...hhh...i.|
|.ied.....dfi.|
|.jbBJKLMNbij.|
|.............|
layer 3
|.............|
|.UHU.........|
|.....Z.Z.....|
|.jikPjjjPkij.|
|.iY.......Xi.|
|.l.........l.|
|.l.........l.|
|.i.........i.|
|.i.........i.|
|.l.........l.|
|.l.........l.|
|.i.........i.|
|.i.........i.|
|.i.........i.|
|.iY.......Xi.|
|.jbBJKLMNbij.|
|.............|
layer 4
|.............|
|.QQQ.........|
|.............|
|.jiiOiIiOiij.|
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
|.jQQQQQQQQij.|
|.............|
layer 5
|.............|
|.............|
|.............|
|.jjjjjjjjjjj.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.jQQQQQQQQQj.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.jQQQQQQQQQj.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.jjjjjjjjjjj.|
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
|.jjjjjjjjjjj.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.j.........j.|
|.jjjjjjjjjjj.|
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

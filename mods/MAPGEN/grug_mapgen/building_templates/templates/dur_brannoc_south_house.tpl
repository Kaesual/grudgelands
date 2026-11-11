grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:south_house, lethariel:south_house, nhal_veyr:south_house
name dur_brannoc_south_house
pivot 9 9
origin -1 0 -1
size 11 11 11
cell 1
meta extent=[-1,-1,9,9] peak=8 top=10
races dwarf elf undead

legend
A role bed variant=_bottom
B role bed variant=_top
C role chimney
D role chimney_cap
E role door variant=_a
F role door_hidden
G role floor
I role hearth o=facedir:1
J role light_post o=wallmounted:1
K role light_wall o=wallmounted:2
L role light_wall o=wallmounted:3
M role light_wall o=wallmounted:4
N role path
P role roof_slab
Q role roof_stair
R role roof_stair o=facedir:1
S role roof_stair o=facedir:2
T role roof_stair o=facedir:3
U role roof_stair_outer
V role roof_stair_outer o=facedir:1
W role roof_stair_outer o=facedir:2
X role roof_stair_outer o=facedir:3
Y role rug
Z role rug_accent
a role seat
b role seat o=facedir:2
c role seat o=facedir:3
d role shelf o=facedir:1
e role shelf o=facedir:3
f role shelf_vessels o=facedir:1
g role storage o=facedir:3
h node grug_decor:xdecor_table
l role window
m role window o=facedir:3
H role facade_roof_stair_outer o=facedir:1
O race *=V dwarf=H
i role facade_roof_stair o=facedir:1
j race *=R dwarf=i
k role facade_roof_stair_outer o=facedir:2
n race *=W dwarf=k
o role facade_base
p role facade_frame
q role facade_infill
r role facade_roof_stair o=facedir:0
s race *=Q dwarf=r
t role facade_band
u role facade_roof_stair o=facedir:2
v race *=S dwarf=u
w role facade_roof_slab o=facedir:0
x race *=P dwarf=w
y role facade_roof_stair_outer o=facedir:0
z race *=U dwarf=y
0 role facade_roof_stair o=facedir:3
1 race *=T dwarf=0
2 role facade_roof_stair_outer o=facedir:3
3 race *=X dwarf=2
end

layer 0
|NNNNNNNNNNN|
|NoooooooooN|
|NoGGGGGZGoN|
|NoGGGGGZGoN|
|NoGGYYGGGoN|
|NoGGYYGGGoN|
|NoGGGGGGGoN|
|NoGGGGGGGoN|
|NoGGGGGGGoN|
|NoooooooooN|
|NNNNNNNNNNN|
layer 1
|...........|
|.ooEoooooo.|
|.oA.....IC.|
|.oB....c.o.|
|.og..b...o.|
|.oe..hh..o.|
|.o...a...o.|
|.o......do.|
|.o......fo.|
|.ooooooooo.|
|...........|
layer 2
|...........|
|.pqFqpqllp.|
|.q......JC.|
|.m.......m.|
|.m.......m.|
|.pe......p.|
|.q.......q.|
|.m......fm.|
|.m.......m.|
|.pqllpqllp.|
|...........|
layer 3
|.M...M.....|
|.pqqqpqllp.|
|.q......CC.|
|.m.......m.|
|.m.......m.|
|.pL.....Kp.|
|.q.......q.|
|.m.......m.|
|.m.......m.|
|.pqllpqllp.|
|...........|
layer 4
|...........|
|.pqqqpqqqp.|
|.q......CC.|
|.q.......q.|
|.q.......q.|
|.p.......p.|
|.q.......q.|
|.q.......q.|
|.q.......q.|
|.pqqqpqqqp.|
|...........|
layer 5
|Osssssssssz|
|jttttttttt1|
|jt......CC1|
|jt.......t1|
|jt.......t1|
|jt.......t1|
|jt.......t1|
|jt.......t1|
|jt.......t1|
|jttttttttt1|
|nvvvvvvvvv3|
layer 6
|...........|
|.Osssssssz.|
|.j.......C.|
|.j.......1.|
|.j.......1.|
|.j.......1.|
|.j.......1.|
|.j.......1.|
|.j.......1.|
|.nvvvvvvv3.|
|...........|
layer 7
|...........|
|...........|
|..OssssszC.|
|..j.....1..|
|..j.....1..|
|..j.....1..|
|..j.....1..|
|..j.....1..|
|..nvvvvv3..|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........C.|
|...xxxxx...|
|...xxxxx...|
|...xxxxx...|
|...xxxxx...|
|...xxxxx...|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........C.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........D.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 2 1 0 face=0
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 7 0 7
lights 0 3 -1
lights 4 3 -1
lights 7 2 1
lights 1 3 4
lights 7 3 4
end

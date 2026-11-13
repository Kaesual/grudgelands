grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:lane_house, lethariel:plaza_house
name dur_brannoc_lane_house
pivot 9 9
origin -1 0 -1
size 11 14 11
cell 1
meta extent=[-1,-1,9,9] peak=11 top=13
races dwarf elf

legend
A role bed variant=_bottom
B role bed variant=_top
C role bed_fancy variant=_bottom else=A
D role bed_fancy variant=_top else=B
E role chimney
F role chimney_cap
G role door variant=_a
H role door_hidden
I role floor
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
R role roof_slab
S role roof_stair
T role roof_stair o=facedir:2
U role rug
V role rug_accent
W role seat
X role seat o=facedir:2
Y role seat o=facedir:3
Z role shelf o=facedir:1
a role shelf o=facedir:3
b role shelf_vessels o=facedir:1
c role storage o=facedir:3
d node grug_decor:xdecor_table
f role wall
h role window
i role window o=facedir:3
j role window_frame
J role facade_roof_stair o=facedir:2
Q race *=T dwarf=J
e role facade_roof_stair o=facedir:0
g race *=S dwarf=e
k role facade_roof_slab o=facedir:0
l race *=R dwarf=k
m role facade_base
n role facade_frame
o role facade_infill
p role facade_band
q race *=j dwarf=o elf=p
r race *=f dwarf=o elf=p
s race *=f dwarf=m
t role facade_gable
u race *=j dwarf=m elf=o
end

layer 0
|PPPPPPPPPPP|
|PmmmmmmmmmP|
|PmIIIIIVImP|
|PmIIIIIVImP|
|PmIIUUIIImP|
|PmIIUUIIImP|
|PmIIIIIIImP|
|PmIIIIIIImP|
|PmIIIIIIImP|
|PmmmmmmmmmP|
|PPPPPPPPPPP|
layer 1
|...........|
|.mmGmmmmmm.|
|.mC.....KE.|
|.mD....Y.m.|
|.mc..X...m.|
|.ma..dd..m.|
|.m...W...m.|
|.m......Zm.|
|.m......bm.|
|.mmmmmmmmm.|
|...........|
layer 2
|...........|
|.noHonohhn.|
|.o......LE.|
|.i.......i.|
|.i.......i.|
|.na......n.|
|.o.......o.|
|.i......bi.|
|.i.......i.|
|.nohhnohhn.|
|...........|
layer 3
|.O...O.....|
|.nooonohhn.|
|.o......EE.|
|.i.......i.|
|.i.......i.|
|.nN.....Mn.|
|.o.......o.|
|.i.......i.|
|.i.......i.|
|.nohhnohhn.|
|...........|
layer 4
|...........|
|.prrrpqrrp.|
|.q......EE.|
|.r.......r.|
|.r.......r.|
|.p.......p.|
|.q.......q.|
|.r.......r.|
|.r.......r.|
|.pqrrpqrrp.|
|...........|
layer 5
|...........|
|.nooonooon.|
|.o......EE.|
|.o.......o.|
|.o.......o.|
|.n.......n.|
|.o.......o.|
|.o.......o.|
|.o.......o.|
|.nussnussn.|
|QQQQQQQQQQQ|
layer 6
|...........|
|.nooonooon.|
|.o.......E.|
|.o.......o.|
|.o.......o.|
|.n.......n.|
|.o.......o.|
|.o.......o.|
|.o.......o.|
|QQQQQQQQQQQ|
|...........|
layer 7
|ggggggggggg|
|.nsssnsssn.|
|.s.......E.|
|.s.......s.|
|.s.......s.|
|.n.......n.|
|.s.......s.|
|.s.......s.|
|QQQQQQQQQQQ|
|...........|
|...........|
layer 8
|...........|
|ggggggggggg|
|.t.......E.|
|.t.......t.|
|.t.......t.|
|.n.......n.|
|.t.......t.|
|QQQQQQQQQQQ|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|gggggggggEg|
|.t.......t.|
|.t.......t.|
|.n.......n.|
|QQQQQQQQQQQ|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........E.|
|ggggggggggg|
|.t.......t.|
|QQQQQQQQQQQ|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 11
|...........|
|...........|
|.........E.|
|...........|
|lllllllllll|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|.........E.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 13
|...........|
|...........|
|.........F.|
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

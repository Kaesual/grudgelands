grudgelands-building-template 1
# Frozen from the building generators (Round 56): kezamba:west_house
name kezamba_west_house
pivot 9 9
origin -1 0 -1
size 11 14 11
cell 1
meta extent=[-1,-1,9,9] peak=11 top=13
races troll

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
J role foundation
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
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
Q role facade_roof_stair o=facedir:2
R role facade_roof_stair o=facedir:0
S role facade_roof_slab o=facedir:0
T role facade_base
e role facade_home_base
g role facade_infill
end

layer 0
|PPPPPPPPPPP|
|PJJJJJJJJJP|
|PJIIIIIVIJP|
|PJIIIIIVIJP|
|PJIIUUIIIJP|
|PJIIUUIIIJP|
|PJIIIIIIIJP|
|PJIIIIIIIJP|
|PJIIIIIIIJP|
|PJJJJJJJJJP|
|PPPPPPPPPPP|
layer 1
|...........|
|.TTGTTTTTT.|
|.TC.....KE.|
|.TD....Y.T.|
|.Tc..X...T.|
|.Ta..dd..T.|
|.T...W...T.|
|.T......ZT.|
|.T......bT.|
|.TTTTTTTTT.|
|...........|
layer 2
|...........|
|.egHgfghhe.|
|.g......LE.|
|.h.......h.|
|.h.......h.|
|.ea......e.|
|.g.......g.|
|.h......bh.|
|.h.......h.|
|.eghheghhe.|
|...........|
layer 3
|.O...O.....|
|.egggfghhe.|
|.g......EE.|
|.h.......h.|
|.h.......h.|
|.eN.....Me.|
|.g.......g.|
|.h.......h.|
|.h.......h.|
|.eghheghhe.|
|...........|
layer 4
|...........|
|.egggfggge.|
|.g......EE.|
|.g.......g.|
|.g.......g.|
|.e.......e.|
|.g.......g.|
|.g.......g.|
|.g.......g.|
|.egggeggge.|
|...........|
layer 5
|...........|
|.effffeffe.|
|.e......EE.|
|.f.......f.|
|.f.......f.|
|.e.......e.|
|.e.......e.|
|.f.......f.|
|.f.......f.|
|.eeffeeffe.|
|QQQQQQQQQQQ|
layer 6
|...........|
|.egggfggge.|
|.g.......E.|
|.g.......g.|
|.g.......g.|
|.f.......f.|
|.g.......g.|
|.g.......g.|
|.g.......g.|
|QQQQQQQQQQQ|
|...........|
layer 7
|RRRRRRRRRRR|
|.efffffffe.|
|.f.......E.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|QQQQQQQQQQQ|
|...........|
|...........|
layer 8
|...........|
|RRRRRRRRRRR|
|.g.......E.|
|.g.......g.|
|.g.......g.|
|.f.......f.|
|.g.......g.|
|QQQQQQQQQQQ|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|RRRRRRRRRER|
|.g.......g.|
|.g.......g.|
|.f.......f.|
|QQQQQQQQQQQ|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........E.|
|RRRRRRRRRRR|
|.g.......g.|
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
|SSSSSSSSSSS|
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

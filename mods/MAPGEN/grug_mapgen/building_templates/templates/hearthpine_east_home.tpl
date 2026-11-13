grudgelands-building-template 1
# Frozen from the building generators (Round 56): hearthpine:east_home
name hearthpine_east_home
pivot 11 9
origin -1 0 -1
size 13 10 11
cell 1
meta peak=7
races dwarf

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
a role rug
b role rug_accent
c role seat
d role seat o=facedir:2
e role seat o=facedir:3
f role shelf o=facedir:1
g role shelf o=facedir:3
h role shelf_vessels o=facedir:1
i role storage o=facedir:3
j node grug_decor:xdecor_table
n role window
o role window o=facedir:3
Q role facade_roof_stair_outer o=facedir:1
R role facade_roof_stair o=facedir:1
S role facade_roof_stair_outer o=facedir:2
T role facade_base
U role facade_infill
V role facade_roof_stair o=facedir:0
W role facade_roof_stair o=facedir:2
X role facade_roof_slab o=facedir:0
Y role facade_roof_stair_outer o=facedir:0
Z role facade_roof_stair o=facedir:3
k role facade_roof_stair_outer o=facedir:3
end

layer 0
|PPPPPPPPPPPPP|
|PJJJJJJJJJJJP|
|PJIIIIIIIbIJP|
|PJIIIIIIIbIJP|
|PJIIIaaIIIIJP|
|PJIIIaaIIIIJP|
|PJIIIIIIIIIJP|
|PJIIIIIIIIIJP|
|PJIIIIIIIIIJP|
|PJJJJJJJJJJJP|
|PPPPPPPPPPPPP|
layer 1
|.............|
|.TTTGTTTTTTT.|
|.TC.......KE.|
|.TD......e.T.|
|.Ti...d....T.|
|.Tg...jj...T.|
|.T....c....T.|
|.T........fT.|
|.T........hT.|
|.TTTTTTTTTTT.|
|.............|
layer 2
|.............|
|.TUUHUTnnUUT.|
|.U........LE.|
|.o.........o.|
|.o.........o.|
|.Tg........T.|
|.U.........U.|
|.o........ho.|
|.o.........o.|
|.TUnnUTnnUUT.|
|.............|
layer 3
|..O...O......|
|.TUUUUTnnUUT.|
|.U........EE.|
|.o.........o.|
|.o.........o.|
|.TN.......MT.|
|.U.........U.|
|.o.........o.|
|.o.........o.|
|.TUnnUTnnUUT.|
|.............|
layer 4
|QVVVVVVVVVVVY|
|RTTTTTTTTTTTZ|
|RT........EEZ|
|RT.........TZ|
|RT.........TZ|
|RT.........TZ|
|RT.........TZ|
|RT.........TZ|
|RT.........TZ|
|RTTTTTTTTTTTZ|
|SWWWWWWWWWWWk|
layer 5
|.............|
|.QVVVVVVVVVY.|
|.R.........E.|
|.R.........Z.|
|.R.........Z.|
|.R.........Z.|
|.R.........Z.|
|.R.........Z.|
|.R.........Z.|
|.SWWWWWWWWWk.|
|.............|
layer 6
|.............|
|.............|
|..QVVVVVVVYE.|
|..R.......Z..|
|..R.......Z..|
|..R.......Z..|
|..R.......Z..|
|..R.......Z..|
|..SWWWWWWWk..|
|.............|
|.............|
layer 7
|.............|
|.............|
|...........E.|
|...XXXXXXX...|
|...XXXXXXX...|
|...XXXXXXX...|
|...XXXXXXX...|
|...XXXXXXX...|
|.............|
|.............|
|.............|
layer 8
|.............|
|.............|
|...........E.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 9
|.............|
|.............|
|...........F.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|

points
doors 3 1 0 face=0
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 9 0 7
lights 1 3 -1
lights 5 3 -1
lights 9 2 1
lights 1 3 4
lights 9 3 4
end

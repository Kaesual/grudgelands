grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:bazaar_house, gor_drazhak:war_chief_house, gor_drazhak:bone_shaman_house
name gor_drazhak_plot_bazaar_house
pivot 11 9
origin -1 0 -1
size 13 8 11
cell 1
meta extent=[-1,-1,11,9] parapet_columns=44 peak=5 top=7
races orc

legend
A node grug_decor:xdecor_potted_rose
B node grug_decor:xdecor_potted_tulip
C role bed variant=_bottom
D role bed variant=_top
E role bed_fancy variant=_bottom else=C
F role bed_fancy variant=_top else=D
G role chimney
H role chimney_cap
I role door variant=_a
J role door_hidden
K role floor
M role hearth o=facedir:1
N role light_post o=wallmounted:1
O role light_wall o=wallmounted:2
P role light_wall o=wallmounted:3
Q role light_wall o=wallmounted:4
R role low_wall
S role path
U role roof_ridge
V role rug
W role rug_accent
X role seat
Y role seat o=facedir:2
Z role seat o=facedir:3
a role shelf o=facedir:1
b role shelf o=facedir:3
c role shelf_vessels o=facedir:1
d role signature else=air
e role storage
f role storage o=facedir:3
g node grug_decor:xdecor_table
i role wall_accent
k role window
l role window o=facedir:3
L role facade_base
T role facade_frame
h role facade_infill
j role facade_roof_ridge
end

layer 0
|SSSSSSSSSSSSS|
|SLLLLLLLLLLLS|
|SLKKKKKKKWKLS|
|SLKKKKKKKWKLS|
|SLKKKVVKKKKLS|
|SLKKKVVKKKKLS|
|SLKKKKKKKKKLS|
|SLKKKKKKKKKLS|
|SLKKKKKKKKKLS|
|SLLLLLLLLLLLS|
|SSSSSSSSSSSSS|
layer 1
|..A....BA....|
|.LiiIiLiiLiL.|
|.LE.......MG.|
|.iF......Z.iB|
|.if...Y....iA|
|.Lb...gg...LB|
|.L....X....L.|
|.i........ai.|
|.i........ci.|
|.LLiiLLiiLiL.|
|.........e...|
layer 2
|.............|
|.ThhJhTkkhhT.|
|.h........NG.|
|.l.........l.|
|.l.........l.|
|.Tb........T.|
|.h.........h.|
|.l........cl.|
|.l.........l.|
|.ThkkhTkkhhT.|
|.............|
layer 3
|..Q...Q......|
|.ThhhhTkkhhT.|
|.h........GG.|
|.l.........l.|
|.l.........l.|
|.TP.......OT.|
|.h.........h.|
|.l.........l.|
|.l.........l.|
|.ThkkhTkkhhT.|
|.............|
layer 4
|.............|
|.TLLLLTLLLLT.|
|.L........GG.|
|.L.........L.|
|.L.........L.|
|.T.........T.|
|.L.........L.|
|.L.........L.|
|.L.........L.|
|.TLLLLTLLLLT.|
|.............|
layer 5
|UUUUUUUUUUUUU|
|UjjjjjjjjjjUU|
|UjjjjjjjjjUGU|
|UjjjjjjjjjjUU|
|UjjjjjjjjjjjU|
|UjjjjjjjjjjjU|
|UjjjjjjjjjjjU|
|UjjjjjjjjjjjU|
|UjjjjjjjjjjjU|
|UjjjjjjjjjjjU|
|UUUUUUUUUUUUU|
layer 6
|RRRRRRRRRRRRR|
|R...........R|
|R..........GR|
|R...........R|
|R...........R|
|R...........R|
|R...........R|
|R...........R|
|R...........R|
|R...........R|
|RRRRRRRRRRRRR|
layer 7
|.d.d.d.d.d.d.|
|d...........d|
|...........H.|
|d...........d|
|.............|
|d...........d|
|.............|
|d...........d|
|.............|
|d...........d|
|.d.d.d.d.d.d.|

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

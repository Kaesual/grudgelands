grudgelands-building-template 1
# Frozen from the building generators (Round 56): sunscar:tusk_lodge
name sunscar_tusk_lodge
pivot 11 9
origin -1 0 -1
size 13 9 11
cell 1
meta peak=6
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
I role door variant=_a o=facedir:2
J role door_hidden o=facedir:2
K role floor
M role hearth o=facedir:1
N role light_post o=wallmounted:1
O role light_wall o=wallmounted:2
P role light_wall o=wallmounted:3
Q role light_wall o=wallmounted:5
R role path
T role roof_ridge
U role rug
V role rug_accent
W role seat
X role seat o=facedir:2
Y role seat o=facedir:3
Z role shelf o=facedir:1
a role shelf o=facedir:3
b role shelf_vessels o=facedir:1
c role storage
d role storage o=facedir:3
e node grug_decor:xdecor_table
g role wall
h role wall_accent
i role window
j role window o=facedir:3
L role facade_base
S role facade_frame
f role facade_infill
k role facade_roof_ridge
end

layer 0
|RRRRRRRRRRRRR|
|RLLLLLLLLLLLR|
|RLKKKKKKKVKLR|
|RLKKKKKKKVKLR|
|RLKKKUUKKKKLR|
|RLKKKUUKKKKLR|
|RLKKKKKKKKKLR|
|RLKKKKKKKKKLR|
|RLKKKKKKKKKLR|
|RLLLLLLLLLLLR|
|RRRRRRRRRRRRR|
layer 1
|...BAB...c...|
|.LLhhLLhhLhL.|
|.LE.......MG.|
|.hF......Y.hB|
|.hd...X....hA|
|.La...ee...LB|
|.L....W....L.|
|.h........Zh.|
|.h........bh.|
|.LhhhhIhLhhL.|
|........c....|
layer 2
|.............|
|.SfiifSiifgS.|
|.f........NG.|
|.j.........j.|
|.j.........j.|
|.Sa........S.|
|.f.........f.|
|.j........bj.|
|.j.........j.|
|.SgggSJgfiiS.|
|.............|
layer 3
|.............|
|.SfiifSiifgS.|
|.f........GG.|
|.j.........j.|
|.j.........j.|
|.SP.......OS.|
|.f.........f.|
|.j.........j.|
|.j.........j.|
|.SgggSggfiiS.|
|....Q...Q....|
layer 4
|.............|
|.SfggfSggfgS.|
|.f........GG.|
|.g.........g.|
|.g.........g.|
|.S.........S.|
|.f.........f.|
|.g.........g.|
|.g.........g.|
|.SgggSggfggS.|
|.............|
layer 5
|.............|
|.SLLLLSLLLLS.|
|.L........GG.|
|.L.........L.|
|.L.........L.|
|.S.........S.|
|.L.........L.|
|.L.........L.|
|.L.........L.|
|.SLLLSLLLLLS.|
|.............|
layer 6
|TTTTTTTTTTTTT|
|TkkkkkkkkkkTT|
|TkkkkkkkkkTGT|
|TkkkkkkkkkkTT|
|TkkkkkkkkkkkT|
|TkkkkkkkkkkkT|
|TkkkkkkkkkkkT|
|TkkkkkkkkkkkT|
|TkkkkkkkkkkkT|
|TkkkkkkkkkkkT|
|TTTTTTTTTTTTT|
layer 7
|.............|
|.............|
|...........G.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 8
|.............|
|.............|
|...........H.|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|

points
doors 5 1 8 face=2
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 9 0 7
lights 3 3 9
lights 7 3 9
lights 9 2 1
lights 1 3 4
lights 9 3 4
end

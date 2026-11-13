grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:service_yard, highcourt:martial_wain_shed, dur_brannoc:smelting_yard, dur_brannoc:garrison_wain_shed, dur_brannoc:deep_lamp_store, nhal_veyr:charnel_yard, nhal_veyr:watch_cart_shed, gor_drazhak:beast_shed, gor_drazhak:bazaar_wain_yard, gor_drazhak:war_wain_shed
name highcourt_service_yard
pivot 13 9
origin -1 0 -1
size 15 10 11
cell 1
meta extent=[-1,-1,13,9] peak=7 top=9
races dwarf human undead orc

legend
B role floor
D role light_wall o=wallmounted:3
E role path
G role roof_slab
H role roof_stair
I role roof_stair o=facedir:2
J role seat
K role seat o=facedir:2
L role storage
M node grug_decor:xdecor_table
O role tree_log
P role wall
R role window
S role window o=facedir:3
U role workbench
A role facade_roof_stair o=facedir:0
C role facade_service_roof_stair o=facedir:0
F race *=H dwarf=A human=C
N role facade_roof_stair o=facedir:2
Q role facade_service_roof_stair o=facedir:2
T race *=I dwarf=N human=Q
V role facade_roof_slab o=facedir:0
W role facade_service_roof_slab o=facedir:0
X race *=G dwarf=V human=W
Y role facade_base
Z role facade_frame
a role facade_infill
b role facade_band
c role facade_gable
d race *=P dwarf=c human=a undead=a
end

layer 0
|EEEEEEEEEEEEEEE|
|EYYYYYYYYYYYYYE|
|EYBBBBBBBBBBBYE|
|EYBBBBBBBBBBBYE|
|EYBBBBBBBBBBBYE|
|EYBBBBBBBBBBBYE|
|EYBBBBBBBBBBBYE|
|EYBBBBBBBBBBBYE|
|EYBBBBBBBBBBBYE|
|EYYYYYYYYYYYYYE|
|EEEEEEEEEEEEEEE|
layer 1
|...............|
|.Y...Z...Z...Z.|
|.YOO.......OO..|
|.Y.............|
|.Y.....K.......|
|.Y....MMM....Z.|
|.Y.....J.......|
|.Y.............|
|.YLL...U.......|
|.YYYYYYYYYYYYY.|
|...............|
layer 2
|...............|
|.Z...Z...Z...Z.|
|.aOO.......OO..|
|.S.............|
|.S.............|
|.Z...........Z.|
|.a.............|
|.S.............|
|.S.............|
|.ZaRRZaRRZaRRZ.|
|...............|
layer 3
|...............|
|.Z...Z...Z...Z.|
|.aGG.......GG..|
|.S.............|
|.S.............|
|.ZD..........Z.|
|.aD............|
|.S.............|
|.S.............|
|.ZaRRZaRRZaRRZ.|
|...............|
layer 4
|FFFFFFFFFFFFFFF|
|.ZZZZZZZZZZZZZ.|
|.b.............|
|.b.............|
|.b.............|
|.Z...........Z.|
|.b.............|
|.b.............|
|.b.............|
|.ZbbbZbbbZbbbZ.|
|TTTTTTTTTTTTTTT|
layer 5
|...............|
|FFFFFFFFFFFFFFF|
|.d...........Z.|
|.d.............|
|.d.............|
|.Z...........Z.|
|.d.............|
|.d.............|
|.d...........Z.|
|TTTTTTTTTTTTTTT|
|...............|
layer 6
|...............|
|...............|
|FFFFFFFFFFFFFFF|
|.d...........Z.|
|.d...........Z.|
|.Z...........Z.|
|.d...........Z.|
|.d...........Z.|
|TTTTTTTTTTTTTTT|
|...............|
|...............|
layer 7
|...............|
|...............|
|...............|
|XXXXXXXXXXXXXXX|
|XXXXXXXXXXXXXXX|
|XXXXXXXXXXXXXXX|
|XXXXXXXXXXXXXXX|
|XXXXXXXXXXXXXXX|
|...............|
|...............|
|...............|
layer 8
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
layer 9
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|

points
inside 2 1 4 id={id}
room_corner 1 0 1 closed=false id={id} top=4
room_corner 11 0 7
lights 1 3 4
lights 1 3 5
end

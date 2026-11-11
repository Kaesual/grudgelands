grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:plaza_house, lethariel:shore_house, nhal_veyr:plaza_house
name dur_brannoc_plaza_house
pivot 9 9
origin -1 0 -1
size 11 12 11
cell 1
meta extent=[-1,-1,9,9] peak=9 top=11
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
R role roof_stair o=facedir:2
S role rug
T role rug_accent
U role seat
V role seat o=facedir:2
W role seat o=facedir:3
X role shelf o=facedir:1
Y role shelf o=facedir:3
Z role shelf_vessels o=facedir:1
a role storage o=facedir:3
b node grug_decor:xdecor_table
f role window
g role window o=facedir:3
H role facade_roof_stair o=facedir:0
O race *=Q dwarf=H
c role facade_roof_stair o=facedir:2
d race *=R dwarf=c
e role facade_roof_slab o=facedir:0
h race *=P dwarf=e
i role facade_base
j role facade_frame
k role facade_infill
l role facade_band
m role facade_gable
end

layer 0
|NNNNNNNNNNN|
|NiiiiiiiiiN|
|NiGGGGGTGiN|
|NiGGGGGTGiN|
|NiGGSSGGGiN|
|NiGGSSGGGiN|
|NiGGGGGGGiN|
|NiGGGGGGGiN|
|NiGGGGGGGiN|
|NiiiiiiiiiN|
|NNNNNNNNNNN|
layer 1
|...........|
|.iiEiiiiii.|
|.iA.....IC.|
|.iB....W.i.|
|.ia..V...i.|
|.iY..bb..i.|
|.i...U...i.|
|.i......Xi.|
|.i......Zi.|
|.iiiiiiiii.|
|...........|
layer 2
|...........|
|.jkFkjkffj.|
|.k......JC.|
|.g.......g.|
|.g.......g.|
|.jY......j.|
|.k.......k.|
|.g......Zg.|
|.g.......g.|
|.jkffjkffj.|
|...........|
layer 3
|.M...M.....|
|.jkkkjkffj.|
|.k......CC.|
|.g.......g.|
|.g.......g.|
|.jL.....Kj.|
|.k.......k.|
|.g.......g.|
|.g.......g.|
|.jkffjkffj.|
|...........|
layer 4
|...........|
|.jkkkjkkkj.|
|.k......CC.|
|.k.......k.|
|.k.......k.|
|.j.......j.|
|.k.......k.|
|.k.......k.|
|.k.......k.|
|.jkkkjkkkj.|
|...........|
layer 5
|OOOOOOOOOOO|
|.lllllllll.|
|.l......CC.|
|.l.......l.|
|.l.......l.|
|.l.......l.|
|.l.......l.|
|.l.......l.|
|.l.......l.|
|.lllllllll.|
|ddddddddddd|
layer 6
|...........|
|OOOOOOOOOOO|
|.m.......C.|
|.m.......m.|
|.m.......m.|
|.j.......j.|
|.m.......m.|
|.m.......m.|
|.m.......m.|
|ddddddddddd|
|...........|
layer 7
|...........|
|...........|
|OOOOOOOOOCO|
|.m.......m.|
|.m.......m.|
|.j.......j.|
|.m.......m.|
|.m.......m.|
|ddddddddddd|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........C.|
|OOOOOOOOOOO|
|.m.......m.|
|.j.......j.|
|.m.......m.|
|ddddddddddd|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........C.|
|...........|
|hhhhhhhhhhh|
|hhhhhhhhhhh|
|hhhhhhhhhhh|
|...........|
|...........|
|...........|
|...........|
layer 10
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
layer 11
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

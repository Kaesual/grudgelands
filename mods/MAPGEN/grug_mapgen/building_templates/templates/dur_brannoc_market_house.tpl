grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:market_house, lethariel:quay_house, nhal_veyr:market_house
name dur_brannoc_market_house
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
Q role roof_stair o=facedir:1
R role roof_stair o=facedir:3
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
H role facade_roof_stair o=facedir:1
O race *=Q dwarf=H
c role facade_base
d role facade_frame
e role facade_infill
h role facade_band
i role facade_gable
j role facade_roof_slab o=facedir:0
k race *=P dwarf=j
l role facade_roof_stair o=facedir:3
m race *=R dwarf=l
end

layer 0
|NNNNNNNNNNN|
|NcccccccccN|
|NcGGGGGTGcN|
|NcGGGGGTGcN|
|NcGGSSGGGcN|
|NcGGSSGGGcN|
|NcGGGGGGGcN|
|NcGGGGGGGcN|
|NcGGGGGGGcN|
|NcccccccccN|
|NNNNNNNNNNN|
layer 1
|...........|
|.ccEcccccc.|
|.cA.....IC.|
|.cB....W.c.|
|.ca..V...c.|
|.cY..bb..c.|
|.c...U...c.|
|.c......Xc.|
|.c......Zc.|
|.ccccccccc.|
|...........|
layer 2
|...........|
|.deFedeffd.|
|.e......JC.|
|.g.......g.|
|.g.......g.|
|.dY......d.|
|.e.......e.|
|.g......Zg.|
|.g.......g.|
|.deffdeffd.|
|...........|
layer 3
|.M...M.....|
|.deeedeffd.|
|.e......CC.|
|.g.......g.|
|.g.......g.|
|.dL.....Kd.|
|.e.......e.|
|.g.......g.|
|.g.......g.|
|.deffdeffd.|
|...........|
layer 4
|...........|
|.deeedeeed.|
|.e......CC.|
|.e.......e.|
|.e.......e.|
|.d.......d.|
|.e.......e.|
|.e.......e.|
|.e.......e.|
|.deeedeeed.|
|...........|
layer 5
|O.........m|
|Ohhhhhhhhhm|
|Oh......CCm|
|Oh.......hm|
|Oh.......hm|
|Oh.......hm|
|Oh.......hm|
|Oh.......hm|
|Oh.......hm|
|Ohhhhhhhhhm|
|O.........m|
layer 6
|.O.......m.|
|.Oiiidiiim.|
|.O.......C.|
|.O.......m.|
|.O.......m.|
|.O.......m.|
|.O.......m.|
|.O.......m.|
|.O.......m.|
|.Oiiidiiim.|
|.O.......m.|
layer 7
|..O.....m..|
|..Oiidiim..|
|..O.....mC.|
|..O.....m..|
|..O.....m..|
|..O.....m..|
|..O.....m..|
|..O.....m..|
|..O.....m..|
|..Oiidiim..|
|..O.....m..|
layer 8
|...O...m...|
|...Oidim...|
|...O...m.C.|
|...O...m...|
|...O...m...|
|...O...m...|
|...O...m...|
|...O...m...|
|...O...m...|
|...Oidim...|
|...O...m...|
layer 9
|....kkk....|
|....kkk....|
|....kkk..C.|
|....kkk....|
|....kkk....|
|....kkk....|
|....kkk....|
|....kkk....|
|....kkk....|
|....kkk....|
|....kkk....|
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
layer 11
|...........|
|...........|
|...........|
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

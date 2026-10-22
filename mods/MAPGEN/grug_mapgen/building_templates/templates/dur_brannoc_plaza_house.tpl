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
H role foundation
I role hearth o=facedir:1
J role light_post o=wallmounted:1
K role light_wall o=wallmounted:2
L role light_wall o=wallmounted:3
M role light_wall o=wallmounted:4
N role path
O role post
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
b role table_leg
c role table_top
d role wall
e role wall_accent
f role window
g role window o=facedir:3
h role window_frame
end

layer 0
|NNNNNNNNNNN|
|NHHHHHHHHHN|
|NHGGGGGTGHN|
|NHGGGGGTGHN|
|NHGGSSGGGHN|
|NHGGSSGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHHHHHHHHHN|
|NNNNNNNNNNN|
layer 1
|...........|
|.OeEeeheeh.|
|.hA.....IC.|
|.eB....W.e.|
|.ea..V...e.|
|.hY..bb..h.|
|.h...U...h.|
|.e......Xe.|
|.e......Ze.|
|.hheehheeh.|
|...........|
layer 2
|...........|
|.OdFddhffh.|
|.h......JC.|
|.g.......g.|
|.g.......g.|
|.hY..cc..h.|
|.h.......h.|
|.g......Zg.|
|.g.......g.|
|.hhffhhffh.|
|...........|
layer 3
|.M...M.....|
|.Oddddhffh.|
|.h......CC.|
|.g.......g.|
|.g.......g.|
|.hL.....Kh.|
|.h.......h.|
|.g.......g.|
|.g.......g.|
|.hhffhhffh.|
|...........|
layer 4
|...........|
|.Oddddhddh.|
|.h......CC.|
|.d.......d.|
|.d.......d.|
|.h.......h.|
|.h.......h.|
|.d.......d.|
|.d.......d.|
|.hhddhhddh.|
|...........|
layer 5
|QQQQQQQQQQQ|
|.Oddddhddh.|
|.h......CC.|
|.d.......d.|
|.d.......d.|
|.h.......h.|
|.h.......h.|
|.d.......d.|
|.d.......d.|
|.hhddhhddh.|
|RRRRRRRRRRR|
layer 6
|...........|
|QQQQQQQQQQQ|
|.d.......C.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|RRRRRRRRRRR|
|...........|
layer 7
|...........|
|...........|
|QQQQQQQQQCQ|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|RRRRRRRRRRR|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........C.|
|QQQQQQQQQQQ|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|RRRRRRRRRRR|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........C.|
|...........|
|PPPPPPPPPPP|
|PPPPPPPPPPP|
|PPPPPPPPPPP|
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

grudgelands-building-template 1
# Frozen from the building generators (Round 56): hearthpine:west_home
name hearthpine_west_home
pivot 9 9
origin -1 0 -2
size 11 11 12
cell 1
meta peak=8
races dwarf

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
O role facade_roof_stair o=facedir:0
P role facade_roof_stair o=facedir:2
Q role facade_roof_slab o=facedir:0
R role facade_base
c role facade_infill
d role facade_gable
end

layer 0
|           |
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
|           |
|...........|
|.RRERRRRRR.|
|.RA.....IC.|
|.RB....W.R.|
|.Ra..V...R.|
|.RY..bb..R.|
|.R...U...R.|
|.R......XR.|
|.R......ZR.|
|.RRRRRRRRR.|
|...........|
layer 2
|           |
|...........|
|.RcFcccffR.|
|.c......JC.|
|.g.......g.|
|.g.......g.|
|.cY......c.|
|.c.......c.|
|.g......Zg.|
|.g.......g.|
|.RcffccffR.|
|...........|
layer 3
|           |
|.M...M.....|
|.RcccccffR.|
|.c......CC.|
|.g.......g.|
|.g.......g.|
|.cL.....Kc.|
|.c.......c.|
|.g.......g.|
|.g.......g.|
|.RcffccffR.|
|...........|
layer 4
|           |
|OOOOOOOOOOO|
|.ddddddddd.|
|.d......CC.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.ddddddddd.|
|PPPPPPPPPPP|
layer 5
|           |
|...........|
|OOOOOOOOOOO|
|.d.......C.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|PPPPPPPPPPP|
|...........|
layer 6
|           |
|...........|
|...........|
|OOOOOOOOOCO|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|PPPPPPPPPPP|
|...........|
|...........|
layer 7
|           |
|...........|
|...........|
|.........C.|
|OOOOOOOOOOO|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|PPPPPPPPPPP|
|...........|
|...........|
|...........|
layer 8
|           |
|...........|
|...........|
|.........C.|
|...........|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|...........|
|...........|
|...........|
|...........|
layer 9
|           |
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
|           |
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
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 7
lights 0 3 -1
lights 4 3 -1
lights 7 2 1
lights 1 3 4
lights 7 3 4
sockets 2 1 -2 face=0 id=idle_west_door
end

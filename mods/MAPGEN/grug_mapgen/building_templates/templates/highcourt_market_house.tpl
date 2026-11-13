grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:market_house
name highcourt_market_house
pivot 9 9
origin -1 0 -1
size 11 12 11
cell 1
meta extent=[-1,-1,9,9] peak=9 top=11
races human

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
e role storage o=facedir:3
f node grug_decor:xdecor_table
h role wall_accent
i role wall_infill else=air
j role window
k role window o=facedir:3
H role facade_home_base
O role facade_frame
a role facade_infill
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
|.HhEhhHhhH.|
|.HA.....IC.|
|.hB....W.h.|
|.he..V...h.|
|.HY..ff..H.|
|.H...U...H.|
|.h......Xh.|
|.h......Zh.|
|.HHhhHHhhH.|
|...........|
layer 2
|...........|
|.OiFaOajjO.|
|.a......JC.|
|.k.......k.|
|.k.......k.|
|.OY......O.|
|.a.......a.|
|.k......Zk.|
|.k.......k.|
|.OajjOajjO.|
|...........|
layer 3
|.M...M.....|
|.OiiaOajjO.|
|.a......CC.|
|.k.......k.|
|.k.......k.|
|.OL.....KO.|
|.a.......a.|
|.k.......k.|
|.k.......k.|
|.OajjOajjO.|
|...........|
layer 4
|...........|
|.OiiaOaaiO.|
|.a......CC.|
|.i.......i.|
|.a.......a.|
|.O.......O.|
|.a.......a.|
|.a.......a.|
|.i.......i.|
|.OaiaOaaiO.|
|...........|
layer 5
|Q.........R|
|QOOOOOOOOOR|
|QO......CCR|
|QO.......OR|
|QO.......OR|
|QO.......OR|
|QO.......OR|
|QO.......OR|
|QO.......OR|
|QOOOOOOOOOR|
|Q.........R|
layer 6
|.Q.......R.|
|.QiiaOiaiR.|
|.Q.......C.|
|.Q.......R.|
|.Q.......R.|
|.Q.......R.|
|.Q.......R.|
|.Q.......R.|
|.Q.......R.|
|.QiiaOiaiR.|
|.Q.......R.|
layer 7
|..Q.....R..|
|..QiaOiaR..|
|..Q.....RC.|
|..Q.....R..|
|..Q.....R..|
|..Q.....R..|
|..Q.....R..|
|..Q.....R..|
|..Q.....R..|
|..QiaOiaR..|
|..Q.....R..|
layer 8
|...Q...R...|
|...QaOiR...|
|...Q...R.C.|
|...Q...R...|
|...Q...R...|
|...Q...R...|
|...Q...R...|
|...Q...R...|
|...Q...R...|
|...QaOiR...|
|...Q...R...|
layer 9
|....PPP....|
|....PPP....|
|....PPP..C.|
|....PPP....|
|....PPP....|
|....PPP....|
|....PPP....|
|....PPP....|
|....PPP....|
|....PPP....|
|....PPP....|
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

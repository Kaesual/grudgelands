grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:chapel_house
name highcourt_chapel_house
pivot 9 9
origin -1 0 -1
size 11 11 11
cell 1
meta extent=[-1,-1,9,9] peak=8 top=10
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
Y role rug
Z role rug_accent
a role seat
b role seat o=facedir:2
c role seat o=facedir:3
d role shelf o=facedir:1
e role shelf o=facedir:3
f role shelf_vessels o=facedir:1
k role storage o=facedir:3
l node grug_decor:xdecor_table
o role wall_infill else=air
p role window
q role window o=facedir:3
H role facade_service_roof_stair_outer o=facedir:1
O role facade_service_roof_stair o=facedir:1
P role facade_service_roof_stair_outer o=facedir:2
Q role facade_base
R role facade_frame
S role facade_infill
T role facade_service_roof_stair o=facedir:0
U role facade_service_roof_stair o=facedir:2
V role facade_service_roof_slab o=facedir:0
W role facade_service_roof_stair_outer o=facedir:0
X role facade_service_roof_stair o=facedir:3
g role facade_service_roof_stair_outer o=facedir:3
end

layer 0
|NNNNNNNNNNN|
|NQQQQQQQQQN|
|NQGGGGGZGQN|
|NQGGGGGZGQN|
|NQGGYYGGGQN|
|NQGGYYGGGQN|
|NQGGGGGGGQN|
|NQGGGGGGGQN|
|NQGGGGGGGQN|
|NQQQQQQQQQN|
|NNNNNNNNNNN|
layer 1
|...........|
|.QQEQQQQQQ.|
|.QA.....IC.|
|.QB....c.Q.|
|.Qk..b...Q.|
|.Qe..ll..Q.|
|.Q...a...Q.|
|.Q......dQ.|
|.Q......fQ.|
|.QQQQQQQQQ.|
|...........|
layer 2
|...........|
|.RoFSRSppR.|
|.S......JC.|
|.q.......q.|
|.q.......q.|
|.Re......R.|
|.S.......S.|
|.q......fq.|
|.q.......q.|
|.RSppRSppR.|
|...........|
layer 3
|.M...M.....|
|.RooSRSppR.|
|.S......CC.|
|.q.......q.|
|.q.......q.|
|.RL.....KR.|
|.S.......S.|
|.q.......q.|
|.q.......q.|
|.RSppRSppR.|
|...........|
layer 4
|...........|
|.RooSRSSoR.|
|.S......CC.|
|.o.......o.|
|.S.......S.|
|.R.......R.|
|.S.......S.|
|.S.......S.|
|.o.......o.|
|.RSoSRSSoR.|
|...........|
layer 5
|HTTTTTTTTTW|
|ORRRRRRRRRX|
|OR......CCX|
|OR.......RX|
|OR.......RX|
|OR.......RX|
|OR.......RX|
|OR.......RX|
|OR.......RX|
|ORRRRRRRRRX|
|PUUUUUUUUUg|
layer 6
|...........|
|.HTTTTTTTW.|
|.O.......C.|
|.O.......X.|
|.O.......X.|
|.O.......X.|
|.O.......X.|
|.O.......X.|
|.O.......X.|
|.PUUUUUUUg.|
|...........|
layer 7
|...........|
|...........|
|..HTTTTTWC.|
|..O.....X..|
|..O.....X..|
|..O.....X..|
|..O.....X..|
|..O.....X..|
|..PUUUUUg..|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........C.|
|...VVVVV...|
|...VVVVV...|
|...VVVVV...|
|...VVVVV...|
|...VVVVV...|
|...........|
|...........|
|...........|
layer 9
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

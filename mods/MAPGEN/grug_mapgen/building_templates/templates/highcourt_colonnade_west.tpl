grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:colonnade_west
name highcourt_colonnade_west
pivot 15 5
origin -1 0 -1
size 17 9 7
cell 1
meta benches=6 columns=10 extent=[-1,-1,15,5] peak=7 piers=6 top=8
races human

legend
A role castle_paving
B role castle_paving else=air
D role light_wall o=wallmounted:3
I role seat
J role seat o=facedir:2
C role facade_stone_slab o=facedir:0
E role facade_base
F role facade_pillar_bottom
G role facade_pillar_middle
H role facade_pillar_top
end

layer 0
|AAAAAAAAAAAAAAAAA|
|AEEEEEEEEEEEEEEEA|
|AEAAAAAAAAAAAAAEA|
|AEAAAAAAAAAAAAAEA|
|AEAAAAAAAAAAAAAEA|
|AEEEEEEEEEEEEEEEA|
|AAAAAAAAAAAAAAAAA|
layer 1
|.................|
|.EJF.F.EJF.F.EJF.|
|.................|
|.................|
|.................|
|.EIF.F.EIF.F.EIF.|
|.................|
layer 2
|.................|
|.E.G.G.E.G.G.E.G.|
|.................|
|.................|
|.................|
|.E.G.G.E.G.G.E.G.|
|.................|
layer 3
|.................|
|.EDG.G.EDG.G.EDG.|
|.................|
|.................|
|.................|
|.EDG.G.EDG.G.EDG.|
|.................|
layer 4
|.................|
|.E.H.H.E.H.H.E.H.|
|.................|
|.................|
|.................|
|.E.H.H.E.H.H.E.H.|
|.................|
layer 5
|.................|
|.EEEEEEEEEEEEEEE.|
|.................|
|.................|
|.................|
|.EEEEEEEEEEEEEEE.|
|.................|
layer 6
|.................|
|.BBBBBBBBBBBBBBB.|
|.BBBBBBBBBBBBBBB.|
|.BBBBBBBBBBBBBBB.|
|.BBBBBBBBBBBBBBB.|
|.BBBBBBBBBBBBBBB.|
|.................|
layer 7
|CCCCCCCCCCCCCCCCC|
|C...............C|
|C...............C|
|C...............C|
|C...............C|
|C...............C|
|CCCCCCCCCCCCCCCCC|
layer 8
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|

points
lights 1 3 0
lights 1 3 4
lights 7 3 0
lights 7 3 4
lights 13 3 0
lights 13 3 4
sockets 2 1 1 face=0 id={id}_idle_a role=idle tags=[bench]
sockets 12 1 3 face=2 id={id}_idle_b role=idle tags=[bench]
sockets 7 1 2 face=1 group=highcourt_watch id={id}_walk order=9 role=guard_patrol
end

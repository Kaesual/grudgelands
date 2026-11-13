grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:colonnade_west
name gor_drazhak_colonnade_west
pivot 15 5
origin -1 0 -1
size 17 9 7
cell 1
meta benches=6 columns=10 extent=[-1,-1,15,5] peak=7 piers=6 top=8
races orc

legend
A role castle_paving
B role castle_paving else=air
D role light_wall o=wallmounted:3
I role seat
J role seat o=facedir:2
L role signature_slab else=air
C role facade_base
E role facade_frame
F role facade_pillar_bottom o=facedir:0
G role facade_pillar_middle o=facedir:0
H role facade_pillar_top o=facedir:0
end

layer 0
|AAAAAAAAAAAAAAAAA|
|ACCCCCCCCCCCCCCCA|
|ACAAAAAAAAAAAAACA|
|ACAAAAAAAAAAAAACA|
|ACAAAAAAAAAAAAACA|
|ACCCCCCCCCCCCCCCA|
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
|.CCCCCCCCCCCCCCC.|
|.................|
|.................|
|.................|
|.CCCCCCCCCCCCCCC.|
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
|LLLLLLLLLLLLLLLLL|
|L...............L|
|L...............L|
|L...............L|
|L...............L|
|L...............L|
|LLLLLLLLLLLLLLLLL|
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
sockets 7 1 2 face=1 group=gor_drazhak_watch id={id}_walk order=1 role=guard_patrol
end

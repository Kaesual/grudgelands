grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:colonnade_west
name lethariel_colonnade_west
pivot 15 5
origin -1 0 -1
size 17 9 7
cell 1
meta benches=6 columns=10 extent=[-1,-1,15,5] peak=7 piers=6 top=8
races elf

legend
A role castle_paving
B role castle_paving else=air
D role light_wall o=wallmounted:3
I role seat
J role seat o=facedir:2
L role signature_slab else=air
C role facade_base
E role facade_frame
F role facade_band
G role facade_pillar_bottom o=facedir:0
H role facade_pillar_middle o=facedir:0
K role facade_pillar_top o=facedir:0
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
|.EJG.G.EJG.G.EJG.|
|.................|
|.................|
|.................|
|.EIG.G.EIG.G.EIG.|
|.................|
layer 2
|.................|
|.E.H.H.E.H.H.E.H.|
|.................|
|.................|
|.................|
|.E.H.H.E.H.H.E.H.|
|.................|
layer 3
|.................|
|.EDH.H.EDH.H.EDH.|
|.................|
|.................|
|.................|
|.EDH.H.EDH.H.EDH.|
|.................|
layer 4
|.................|
|.E.K.K.E.K.K.E.K.|
|.................|
|.................|
|.................|
|.E.K.K.E.K.K.E.K.|
|.................|
layer 5
|.................|
|.FFFFFFFFFFFFFFF.|
|.................|
|.................|
|.................|
|.FFFFFFFFFFFFFFF.|
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
sockets 7 1 2 face=1 group=lethariel_watch id={id}_walk order=1 role=guard_patrol
end

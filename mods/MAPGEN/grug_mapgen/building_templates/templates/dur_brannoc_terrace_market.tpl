grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:terrace_market
name dur_brannoc_terrace_market
pivot 15 5
origin -1 0 -1
size 17 9 7
cell 1
meta benches=6 columns=10 extent=[-1,-1,15,5] peak=7 piers=6 top=8
races dwarf

legend
A role castle_paving
B role castle_paving else=air
C role castle_wall else=air
D role light_wall o=wallmounted:3
E role pillar variant=_bottom else=air
F role pillar variant=_middle else=air
G role pillar variant=_top else=air
H role plaza_edge
I role seat
J role seat o=facedir:2
K role signature else=air
L role signature_slab else=air
end

layer 0
|AAAAAAAAAAAAAAAAA|
|AHHHHHHHHHHHHHHHA|
|AHAAAAAAAAAAAAAHA|
|AHAAAAAAAAAAAAAHA|
|AHAAAAAAAAAAAAAHA|
|AHHHHHHHHHHHHHHHA|
|AAAAAAAAAAAAAAAAA|
layer 1
|.................|
|.CJE.E.CJE.E.CJE.|
|.................|
|.................|
|.................|
|.CIE.E.CIE.E.CIE.|
|.................|
layer 2
|.................|
|.C.F.F.C.F.F.C.F.|
|.................|
|.................|
|.................|
|.C.F.F.C.F.F.C.F.|
|.................|
layer 3
|.................|
|.CDF.F.CDF.F.CDF.|
|.................|
|.................|
|.................|
|.CDF.F.CDF.F.CDF.|
|.................|
layer 4
|.................|
|.C.G.G.C.G.G.C.G.|
|.................|
|.................|
|.................|
|.C.G.G.C.G.G.C.G.|
|.................|
layer 5
|.................|
|.KKKKKKKKKKKKKKK.|
|.................|
|.................|
|.................|
|.KKKKKKKKKKKKKKK.|
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
sockets 7 1 2 face=1 group=dur_brannoc_terrace_watch id={id}_walk order=1 role=guard_patrol
end

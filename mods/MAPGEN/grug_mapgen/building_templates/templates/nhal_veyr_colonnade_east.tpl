grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:colonnade_east
name nhal_veyr_colonnade_east
pivot 15 5
origin -1 0 -1
size 17 9 7
cell 1
meta benches=6 columns=10 extent=[-1,-1,15,5] peak=7 piers=6 top=8
races undead

legend
A role castle_paving
B role castle_paving else=air
D role light_wall o=wallmounted:3
I role seat
J role seat o=facedir:2
C role facade_stone_slab o=facedir:0
E role facade_base
F role facade_frame
G role facade_pillar_bottom o=facedir:0
H role facade_pillar_middle o=facedir:0
K role facade_pillar_top o=facedir:0
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
|.FJG.G.FJG.G.FJG.|
|.................|
|.................|
|.................|
|.FIG.G.FIG.G.FIG.|
|.................|
layer 2
|.................|
|.F.H.H.F.H.H.F.H.|
|.................|
|.................|
|.................|
|.F.H.H.F.H.H.F.H.|
|.................|
layer 3
|.................|
|.FDH.H.FDH.H.FDH.|
|.................|
|.................|
|.................|
|.FDH.H.FDH.H.FDH.|
|.................|
layer 4
|.................|
|.F.K.K.F.K.K.F.K.|
|.................|
|.................|
|.................|
|.F.K.K.F.K.K.F.K.|
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
sockets 7 1 2 face=1 group=nhal_veyr_watch id={id}_walk order=6 role=guard_patrol
end

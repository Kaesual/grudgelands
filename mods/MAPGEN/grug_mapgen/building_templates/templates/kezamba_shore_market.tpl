grudgelands-building-template 1
# Frozen from the building generators (Round 56): kezamba:shore_market
name kezamba_shore_market
pivot 15 15
origin 0 0 0
size 15 7 15
cell 1
meta cauldrons=4 extent=[0,0,14,14] peak=4 top=6
races troll

legend
A role beam
B role castle_paving
C role hearth
D role light_post o=wallmounted:1
E role plaza_edge
F role post
G role rope else=air
H role seat
I role seat o=facedir:2
J role signature else=B
K role signature else=air
end

layer 0
|EEEEEEEEEEEEEEE|
|EBJBBBBBBBBBJBE|
|EJJJJJJJJJJJJJE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EBJBBBBBBBBBJBE|
|EJJJJJJJJJJJJJE|
|EBJBBBBBBBBBJBE|
|EEEEEEEEEEEEEEE|
layer 1
|...............|
|.F...........F.|
|......III......|
|..F.........F..|
|...............|
|.....KKKKK.....|
|.....KKKKK.....|
|.....KKKKK.....|
|.....KKKKK.....|
|.....KKKKK.....|
|...............|
|..F.........F..|
|......HHH......|
|.F...........F.|
|...............|
layer 2
|...............|
|.F...........F.|
|...............|
|..F.........F..|
|..G.........G..|
|.....C...C.....|
|..G.........G..|
|.......D.......|
|..G.........G..|
|.....C...C.....|
|..G.........G..|
|..F.........F..|
|...............|
|.F...........F.|
|...............|
layer 3
|...............|
|.D...........D.|
|...............|
|..F.........F..|
|..G.........G..|
|...............|
|..G.........G..|
|...............|
|..G.........G..|
|...............|
|..G.........G..|
|..F.........F..|
|...............|
|.D...........D.|
|...............|
layer 4
|...............|
|...............|
|...............|
|..A.........A..|
|..A.........A..|
|..A.........A..|
|..A.........A..|
|..A.........A..|
|..A.........A..|
|..A.........A..|
|..A.........A..|
|..A.........A..|
|...............|
|...............|
|...............|
layer 5
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
layer 6
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|
|...............|

points
inside 7 1 1
lights 7 2 7
lights 1 3 1
lights 13 3 1
lights 1 3 13
lights 13 3 13
sockets 3 1 5 face=1 activity=brew id={id}_brew_1 role=work tags=[fire]
sockets 11 1 5 face=3 activity=brew id={id}_brew_2 role=work tags=[fire]
sockets 3 1 9 face=1 activity=brew id={id}_brew_3 role=work tags=[fire]
sockets 11 1 9 face=3 activity=brew id={id}_brew_4 role=work tags=[fire]
sockets 7 2 2 face=0 activity=sit id={id}_sit_south role=work tags=[bench]
sockets 7 2 12 face=2 activity=sit id={id}_sit_north role=work tags=[bench]
end

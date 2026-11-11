grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:market_candle_court, nhal_veyr:watch_pyre_court, nhal_veyr:vigil_high_court, nhal_veyr:homes_candle_court
name nhal_veyr_market_candle_court
pivot 11 11
origin 0 0 0
size 11 7 11
cell 1
meta benches=2 candles=4 extent=[0,0,10,10] peak=3 top=6
races undead

legend
A role castle_paving
C role light_post o=wallmounted:1
E role post
F role seat
G role seat o=facedir:2
B role facade_base
D role facade_frame
end

layer 0
|BBBBBBBBBBB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BAAAAAAAAAB|
|BBBBBBBBBBB|
layer 1
|...........|
|.E...G...E.|
|...........|
|...........|
|....DDD....|
|....DDD....|
|....DDD....|
|...........|
|...........|
|.E...F...E.|
|...........|
layer 2
|...........|
|.E.......E.|
|...........|
|...........|
|.....C.....|
|....CDC....|
|.....C.....|
|...........|
|...........|
|.E.......E.|
|...........|
layer 3
|...........|
|.C.......C.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|.C.......C.|
|...........|
layer 4
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
layer 5
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
layer 6
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
lights 6 2 5
lights 4 2 5
lights 5 2 6
lights 5 2 4
lights 1 3 1
lights 9 3 1
lights 1 3 9
lights 9 3 9
sockets 3 1 5 face=3 id={id}_idle_a role=idle tags=[bench]
sockets 7 1 5 face=1 id={id}_idle_b role=idle tags=[bench]
end

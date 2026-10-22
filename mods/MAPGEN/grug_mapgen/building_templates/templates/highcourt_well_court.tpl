grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:well_court, highcourt:market_well, highcourt:lore_herb_garden, highcourt:homes_well, dur_brannoc:cistern_court, dur_brannoc:forge_quench_court, dur_brannoc:deep_lantern_court, dur_brannoc:terrace_well_court, lethariel:fountain_court, lethariel:market_fountain, lethariel:homes_court, nhal_veyr:cistern_court, nhal_veyr:market_cistern, nhal_veyr:vigil_cloister, nhal_veyr:homes_cistern, gor_drazhak:cistern_court, gor_drazhak:bone_ash_court, kezamba:shore_well, kezamba:vine_well, kezamba:canopy_well, kezamba:totem_well
name highcourt_well_court
pivot 11 11
origin 0 0 0
size 11 7 11
cell 1
meta benches=4 extent=[0,0,10,10] peak=4 top=6
races dwarf human elf undead orc troll

legend
A role castle_paving
B role castle_paving else=D
C role light_wall o=wallmounted:5
D role low_wall
E role planter
F role plaza_edge
G role post
H role roof_slab
I role rubble
J role seat
K role seat o=facedir:1
L role seat o=facedir:2
M role seat o=facedir:3
end

layer 0
|FFFFFFFFFFF|
|FAAAAAAAAAF|
|FAAAAAAAAAF|
|FAAAAAAAAAF|
|FAAAAAAAAAF|
|FAAAAIAAAAF|
|FAAAAAAAAAF|
|FAAAAAAAAAF|
|FAAAAAAAAAF|
|FAAAAAAAAAF|
|FFFFFFFFFFF|
layer 1
|...........|
|.EE..L.....|
|.EE........|
|...........|
|....BDD....|
|.M..D.D..K.|
|....DDB....|
|...........|
|........EE.|
|.....J..EE.|
|...........|
layer 2
|...........|
|...........|
|...........|
|...........|
|....G......|
|...........|
|......G....|
|...........|
|...........|
|...........|
|...........|
layer 3
|...........|
|...........|
|...........|
|...........|
|....G......|
|....C......|
|......G....|
|...........|
|...........|
|...........|
|...........|
layer 4
|...........|
|...........|
|...........|
|...........|
|....HHH....|
|....HHH....|
|....HHH....|
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
lights 4 3 5
sockets 5 1 2 face=0 id={id}_idle_a role=idle tags=[bench]
sockets 5 1 8 face=2 id={id}_idle_b role=idle tags=[bench]
end

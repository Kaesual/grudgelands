grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:mere_shrine
name lethariel_mere_shrine
pivot 9 9
origin 0 0 0
size 9 10 9
cell 1
meta extent=[0,0,8,8] peak=7 top=9
races elf

legend
A role castle_paving
B role light_post o=wallmounted:1
J role signature_slab else=air
K role signature_stair else=air
L role signature_stair o=facedir:1 else=air
M role signature_stair o=facedir:2 else=air
N role signature_stair o=facedir:3 else=air
C role facade_base
D role facade_pillar_bottom o=facedir:0
E role facade_pillar_middle o=facedir:0
F role facade_pillar_top o=facedir:0
G role facade_band
end

layer 0
|CCCCCCCCC|
|CAAAAAAAC|
|CAAAAAAAC|
|CAAAAAAAC|
|CAAAAAAAC|
|CAAAAAAAC|
|CAAAAAAAC|
|CAAAAAAAC|
|CCCCCCCCC|
layer 1
|...KKK...|
|.CCCCCCC.|
|.CCCCCCC.|
|LCCCCCCCN|
|LCCCCCCCN|
|LCCCCCCCN|
|.CCCCCCC.|
|.CCCCCCC.|
|...MMM...|
layer 2
|.........|
|.D.....D.|
|.........|
|.........|
|...BCB...|
|.........|
|.........|
|.D.....D.|
|.........|
layer 3
|.........|
|.E.....E.|
|.........|
|.........|
|....J....|
|.........|
|.........|
|.E.....E.|
|.........|
layer 4
|.........|
|.E.....E.|
|.........|
|.........|
|.........|
|.........|
|.........|
|.E.....E.|
|.........|
layer 5
|.........|
|.F.....F.|
|.........|
|.........|
|.........|
|.........|
|.........|
|.F.....F.|
|.........|
layer 6
|.........|
|.GGGGGGG.|
|.G.....G.|
|.G.....G.|
|.G.....G.|
|.G.....G.|
|.G.....G.|
|.GGGGGGG.|
|.........|
layer 7
|.........|
|.JJJJJJJ.|
|.JJJJJJJ.|
|.JJJJJJJ.|
|.JJJJJJJ.|
|.JJJJJJJ.|
|.JJJJJJJ.|
|.JJJJJJJ.|
|.........|
layer 8
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
layer 9
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|

points
inside 4 2 3
lights 3 2 4
lights 5 2 4
sockets 2 2 4 face=1 activity=pray id={id}_keeper role=work
sockets 4 2 2 face=0 activity=pray id={id}_south role=work
sockets 4 2 6 face=2 activity=pray id={id}_north role=work
end

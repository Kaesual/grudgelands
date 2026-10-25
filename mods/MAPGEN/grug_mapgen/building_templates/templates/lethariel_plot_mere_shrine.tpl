grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:mere_shrine
name lethariel_plot_mere_shrine
pivot 9 9
origin 0 0 0
size 9 10 9
cell 1
meta extent=[0,0,8,8] peak=7 top=9
races elf

legend
A role castle_paving
B role light_post o=wallmounted:1
C role pillar variant=_bottom else=air
D role pillar variant=_middle else=air
E role pillar variant=_top else=air
F role plaza_edge
G role signature
H role signature else=G
I role signature else=air
J role signature_slab else=air
K role signature_stair else=air
L role signature_stair o=facedir:1 else=air
M role signature_stair o=facedir:2 else=air
N role signature_stair o=facedir:3 else=air
end

layer 0
|FFFFFFFFF|
|FAAAAAAAF|
|FAAAAAAAF|
|FAAAAAAAF|
|FAAAAAAAF|
|FAAAAAAAF|
|FAAAAAAAF|
|FAAAAAAAF|
|FFFFFFFFF|
layer 1
|...KKK...|
|.IIIIIII.|
|.IIIIIII.|
|LIIIIIIIN|
|LIIIIIIIN|
|LIIIIIIIN|
|.IIIIIII.|
|.IIIIIII.|
|...MMM...|
layer 2
|.........|
|.C.....C.|
|.........|
|.........|
|...BIB...|
|.........|
|.........|
|.C.....C.|
|.........|
layer 3
|.........|
|.D.....D.|
|.........|
|.........|
|....J....|
|.........|
|.........|
|.D.....D.|
|.........|
layer 4
|.........|
|.D.....D.|
|.........|
|.........|
|.........|
|.........|
|.........|
|.D.....D.|
|.........|
layer 5
|.........|
|.E.....E.|
|.........|
|.........|
|.........|
|.........|
|.........|
|.E.....E.|
|.........|
layer 6
|.........|
|.HIIIIIH.|
|.I.....I.|
|.I.....I.|
|.I.....I.|
|.I.....I.|
|.I.....I.|
|.HIIIIIH.|
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
sockets 6 1 0 face=0 id={id}_quest role=quest tags=[door]
end

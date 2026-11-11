grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:martial_drill_yard, lethariel:martial_tower
name highcourt_martial_drill_yard
pivot 9 9
origin -1 0 -1
size 11 13 11
cell 1
meta extent=[-1,-1,9,9] peak=12 top=12
races human elf

legend
B role bed variant=_bottom
C role bed variant=_top
D role door variant=_a o=facedir:1
E role door_hidden o=facedir:1
F role floor
G role flower_alt else=air
I role light_post o=wallmounted:1
J role light_wall o=wallmounted:2
K role light_wall o=wallmounted:3
L role path
N role railing
O role roof_slab
P role roof_stair
Q role roof_stair o=facedir:1
R role roof_stair o=facedir:2
S role roof_stair o=facedir:3
T role roof_stair_outer
U role roof_stair_outer o=facedir:1
V role roof_stair_outer o=facedir:2
W role roof_stair_outer o=facedir:3
X role seat
Y role seat o=facedir:2
Z role storage
a role storage o=facedir:1
b node grug_decor:xdecor_table
f role window
g role window o=facedir:3
A role facade_service_roof_stair_outer o=facedir:1
H race *=U human=A
M role facade_service_roof_stair o=facedir:1
c race *=Q human=M
d role facade_service_roof_stair_outer o=facedir:2
e race *=V human=d
h role facade_base
i role facade_frame
j role facade_infill
k role facade_band
l role facade_service_roof_stair o=facedir:0
m race *=P human=l
n role facade_service_roof_stair o=facedir:2
o race *=R human=n
p role facade_service_roof_slab o=facedir:0
q race *=O human=p
r role facade_service_roof_stair_outer o=facedir:0
s race *=T human=r
t role facade_service_roof_stair o=facedir:3
u race *=S human=t
v role facade_service_roof_stair_outer o=facedir:3
w race *=W human=v
end

layer 0
|LLLLLLLLLLL|
|LhhhhhhhhhL|
|LhFFFFFFFhL|
|LhFFFFFFFhL|
|LhFFFFFFFhL|
|LhFFFFFFFhL|
|LhFFFFFFFhL|
|LhFFFFFFFhL|
|LhFFFFFFFhL|
|LhhhhhhhhhL|
|LLLLLLLLLLL|
layer 1
|.......Z...|
|.hhhhhhhhh.|
|.hB.....ah.|
|GhCP.....h.|
|.h.......h.|
|.D.......h.|
|.h.....Y.h.|
|.h.....bbh.|
|.h.....X.h.|
|.hhhhhhhhh.|
|...........|
layer 2
|...........|
|.ijjjijjji.|
|.j.......j.|
|.j.......j.|
|.i.P.....j.|
|.E.......i.|
|.j.......j.|
|.j.......j.|
|.j.......j.|
|.ijjjijjji.|
|...........|
layer 3
|...........|
|.ijfjijfji.|
|Jj.......j.|
|.g.......g.|
|.i.......j.|
|.jKP.....i.|
|.j.......j.|
|.g.......g.|
|Jj.......j.|
|.ijfjijfji.|
|...........|
layer 4
|...........|
|.kkfkkkfkk.|
|.k.......k.|
|.g.......g.|
|.k.......k.|
|.k.......k.|
|.k.P.....k.|
|.g.......g.|
|.k.......k.|
|.kkfkkkfkk.|
|...........|
layer 5
|...........|
|.FFFFFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FFPFFFFFF.|
|.FFFFFFFFF.|
|.FFFFFFFFF.|
|...........|
layer 6
|...........|
|.ijjjjjjji.|
|.jI.....Ij.|
|.j.......j.|
|.j.......j.|
|.j.......j.|
|.j.......j.|
|.j.......j.|
|.jI.....Ij.|
|.ijjjjjjji.|
|...........|
layer 7
|...........|
|.i.N.N.N.i.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.N.......N.|
|...........|
|.i.N.N.N.i.|
|...........|
layer 8
|Hmmmmmmmmms|
|ckkkkkkkkku|
|ck.......ku|
|ck.......ku|
|ck.......ku|
|ck.......ku|
|ck.......ku|
|ck.......ku|
|ck.......ku|
|ckkkkkkkkku|
|eooooooooow|
layer 9
|...........|
|.Hmmmmmmms.|
|.c.......u.|
|.c.......u.|
|.c.......u.|
|.c.......u.|
|.c.......u.|
|.c.......u.|
|.c.......u.|
|.eooooooow.|
|...........|
layer 10
|...........|
|...........|
|..Hmmmmms..|
|..c.....u..|
|..c.....u..|
|..c.....u..|
|..c.....u..|
|..c.....u..|
|..eooooow..|
|...........|
|...........|
layer 11
|...........|
|...........|
|...........|
|...Hmmms...|
|...c...u...|
|...c...u...|
|...c...u...|
|...eooow...|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|...........|
|...........|
|....qqq....|
|....qqq....|
|....qqq....|
|...........|
|...........|
|...........|
|...........|

points
doors 0 1 4 face=1
inside 5 6 4 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 7
lights -1 3 1
lights -1 3 7
lights 1 3 4
lights 1 6 1
lights 7 6 1
lights 1 6 7
lights 7 6 7
end

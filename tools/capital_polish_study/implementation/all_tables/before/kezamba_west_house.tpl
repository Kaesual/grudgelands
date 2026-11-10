grudgelands-building-template 1
# Frozen from the building generators (Round 56): kezamba:west_house
name kezamba_west_house
pivot 9 9
origin -1 0 -1
size 11 14 11
cell 1
meta extent=[-1,-1,9,9] peak=11 top=13
races troll

legend
A role bed variant=_bottom
B role bed variant=_top
C role bed_fancy variant=_bottom else=A
D role bed_fancy variant=_top else=B
E role chimney
F role chimney_cap
G role door variant=_a
H role door_hidden
I role floor
J role foundation
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role path
Q role post
R role roof_slab
S role roof_stair
T role roof_stair o=facedir:2
U role rug
V role rug_accent
W role seat
X role seat o=facedir:2
Y role seat o=facedir:3
Z role shelf o=facedir:1
a role shelf o=facedir:3
b role shelf_vessels o=facedir:1
c role storage o=facedir:3
d role table_leg
e role table_top
f role wall
g role wall_accent
h role window
i role window_frame
end

layer 0
|PPPPPPPPPPP|
|PJJJJJJJJJP|
|PJIIIIIVIJP|
|PJIIIIIVIJP|
|PJIIUUIIIJP|
|PJIIUUIIIJP|
|PJIIIIIIIJP|
|PJIIIIIIIJP|
|PJIIIIIIIJP|
|PJJJJJJJJJP|
|PPPPPPPPPPP|
layer 1
|...........|
|.QgGggiggi.|
|.iC.....KE.|
|.gD....Y.g.|
|.gc..X...g.|
|.ia..dd..i.|
|.i...W...i.|
|.g......Zg.|
|.g......bg.|
|.iiggiiggi.|
|...........|
layer 2
|...........|
|.QfHffihhi.|
|.i......LE.|
|.h.......h.|
|.h.......h.|
|.ia..ee..i.|
|.i.......i.|
|.h......bh.|
|.h.......h.|
|.iihhiihhi.|
|...........|
layer 3
|.O...O.....|
|.Qffffihhi.|
|.i......EE.|
|.h.......h.|
|.h.......h.|
|.iN.....Mi.|
|.i.......i.|
|.h.......h.|
|.h.......h.|
|.iihhiihhi.|
|...........|
layer 4
|...........|
|.Qffffiffi.|
|.i......EE.|
|.f.......f.|
|.f.......f.|
|.i.......i.|
|.i.......i.|
|.f.......f.|
|.f.......f.|
|.iiffiiffi.|
|...........|
layer 5
|...........|
|.Qffffiffi.|
|.i......EE.|
|.f.......f.|
|.f.......f.|
|.i.......i.|
|.i.......i.|
|.f.......f.|
|.f.......f.|
|.iiffiiffi.|
|TTTTTTTTTTT|
layer 6
|...........|
|.QfffffffQ.|
|.f.......E.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|TTTTTTTTTTT|
|...........|
layer 7
|SSSSSSSSSSS|
|.QfffffffQ.|
|.f.......E.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|TTTTTTTTTTT|
|...........|
|...........|
layer 8
|...........|
|SSSSSSSSSSS|
|.f.......E.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|TTTTTTTTTTT|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|SSSSSSSSSES|
|.f.......f.|
|.f.......f.|
|.f.......f.|
|TTTTTTTTTTT|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........E.|
|SSSSSSSSSSS|
|.f.......f.|
|TTTTTTTTTTT|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 11
|...........|
|...........|
|.........E.|
|...........|
|RRRRRRRRRRR|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|.........E.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 13
|...........|
|...........|
|.........F.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 2 1 0 face=0
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 7 0 7
lights 0 3 -1
lights 4 3 -1
lights 7 2 1
lights 1 3 4
lights 7 3 4
end

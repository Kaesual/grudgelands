grudgelands-building-template 1
# Frozen from the building generators (Round 56): dur_brannoc:lane_house, lethariel:plaza_house
name dur_brannoc_lane_house
pivot 9 9
origin -1 0 -1
size 11 14 11
cell 1
meta extent=[-1,-1,9,9] peak=11 top=13
races dwarf elf

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
i role window o=facedir:3
j role window_frame
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
|.QgGggjggj.|
|.jC.....KE.|
|.gD....Y.g.|
|.gc..X...g.|
|.ja..dd..j.|
|.j...W...j.|
|.g......Zg.|
|.g......bg.|
|.jjggjjggj.|
|...........|
layer 2
|...........|
|.QfHffjhhj.|
|.j......LE.|
|.i.......i.|
|.i.......i.|
|.ja..ee..j.|
|.j.......j.|
|.i......bi.|
|.i.......i.|
|.jjhhjjhhj.|
|...........|
layer 3
|.O...O.....|
|.Qffffjhhj.|
|.j......EE.|
|.i.......i.|
|.i.......i.|
|.jN.....Mj.|
|.j.......j.|
|.i.......i.|
|.i.......i.|
|.jjhhjjhhj.|
|...........|
layer 4
|...........|
|.Qffffjffj.|
|.j......EE.|
|.f.......f.|
|.f.......f.|
|.j.......j.|
|.j.......j.|
|.f.......f.|
|.f.......f.|
|.jjffjjffj.|
|...........|
layer 5
|...........|
|.Qffffjffj.|
|.j......EE.|
|.f.......f.|
|.f.......f.|
|.j.......j.|
|.j.......j.|
|.f.......f.|
|.f.......f.|
|.jjffjjffj.|
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

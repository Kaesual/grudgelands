grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:lane_house
name gor_drazhak_lane_house
pivot 9 9
origin -1 0 -1
size 11 9 11
cell 1
meta extent=[-1,-1,9,9] parapet_columns=40 peak=6 top=8
races orc

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
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role low_wall
Q role path
S role roof_ridge
T role rug
U role rug_accent
V role seat
W role seat o=facedir:2
X role seat o=facedir:3
Y role shelf o=facedir:1
Z role shelf o=facedir:3
a role shelf_vessels o=facedir:1
b role signature else=air
c role storage o=facedir:3
d node grug_decor:xdecor_table
f role wall_accent
g role wall_infill else=air
h role window
i role window o=facedir:3
J role facade_base
R role facade_frame
e role facade_infill
j role facade_roof_ridge
end

layer 0
|QQQQQQQQQQQ|
|QJJJJJJJJJQ|
|QJIIIIIUIJQ|
|QJIIIIIUIJQ|
|QJIITTIIIJQ|
|QJIITTIIIJQ|
|QJIIIIIIIJQ|
|QJIIIIIIIJQ|
|QJIIIIIIIJQ|
|QJJJJJJJJJQ|
|QQQQQQQQQQQ|
layer 1
|...........|
|.JfGffJffJ.|
|.JC.....KE.|
|.fD....X.f.|
|.fc..W...f.|
|.JZ..dd..J.|
|.J...V...J.|
|.f......Yf.|
|.f......af.|
|.JJffJJffJ.|
|...........|
layer 2
|...........|
|.ReHegehhR.|
|.e......LE.|
|.i.......i.|
|.i.......i.|
|.RZ......R.|
|.e.......e.|
|.i......ai.|
|.i.......i.|
|.RehhRehhR.|
|...........|
layer 3
|.O...O.....|
|.ReeegehhR.|
|.e......EE.|
|.i.......i.|
|.i.......i.|
|.RN.....MR.|
|.e.......e.|
|.i.......i.|
|.i.......i.|
|.RehhRehhR.|
|...........|
layer 4
|...........|
|.ReeegeeeR.|
|.e......EE.|
|.e.......e.|
|.e.......e.|
|.R.......R.|
|.e.......e.|
|.e.......e.|
|.e.......e.|
|.ReeeReeeR.|
|...........|
layer 5
|...........|
|.RJJJgJJJR.|
|.J......EE.|
|.J.......J.|
|.J.......J.|
|.R.......R.|
|.J.......J.|
|.J.......J.|
|.J.......J.|
|.RJJJRJJJR.|
|...........|
layer 6
|SSSSSSSSSSS|
|SjjjjjjjjSS|
|SjjjjjjjSES|
|SjjjjjjjjSS|
|SjjjjjjjjjS|
|SjjjjjjjjjS|
|SjjjjjjjjjS|
|SjjjjjjjjjS|
|SjjjjjjjjjS|
|SjjjjjjjjjS|
|SSSSSSSSSSS|
layer 7
|PPPPPPPPPPP|
|P.........P|
|P........EP|
|P.........P|
|P.........P|
|P.........P|
|P.........P|
|P.........P|
|P.........P|
|P.........P|
|PPPPPPPPPPP|
layer 8
|b.b.b.b.b.b|
|...........|
|b........Fb|
|...........|
|b.........b|
|...........|
|b.........b|
|...........|
|b.........b|
|...........|
|b.b.b.b.b.b|

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

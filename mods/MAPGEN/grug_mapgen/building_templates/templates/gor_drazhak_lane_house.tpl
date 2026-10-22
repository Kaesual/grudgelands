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
J role foundation
K role hearth o=facedir:1
L role light_post o=wallmounted:1
M role light_wall o=wallmounted:2
N role light_wall o=wallmounted:3
O role light_wall o=wallmounted:4
P role low_wall
Q role path
R role post
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
d role table_leg
e role table_top
f role wall_accent
g role wall_infill else=air
h role window
i role window o=facedir:3
j role window_frame
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
|.RfGffjffj.|
|.jC.....KE.|
|.fD....X.f.|
|.fc..W...f.|
|.jZ..dd..j.|
|.j...V...j.|
|.f......Yf.|
|.f......af.|
|.jjffjjffj.|
|...........|
layer 2
|...........|
|.RgHRgjhhj.|
|.j......LE.|
|.i.......i.|
|.i.......i.|
|.jZ..ee..j.|
|.j.......j.|
|.i......ai.|
|.i.......i.|
|.jjhhjjhhj.|
|...........|
layer 3
|.O...O.....|
|.RggRgjhhj.|
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
|.RggRgjRgj.|
|.j......EE.|
|.g.......g.|
|.R.......R.|
|.j.......j.|
|.j.......j.|
|.R.......R.|
|.g.......g.|
|.jjgRjjRgj.|
|...........|
layer 5
|...........|
|.RggRgjRgj.|
|.j......EE.|
|.g.......g.|
|.R.......R.|
|.j.......j.|
|.j.......j.|
|.R.......R.|
|.g.......g.|
|.jjgRjjRgj.|
|...........|
layer 6
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSES|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
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

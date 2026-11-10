grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:warren_round_lodge
name gor_drazhak_warren_round_lodge
pivot 9 9
origin -1 0 -1
size 11 10 11
cell 1
meta extent=[-1,-1,9,9] parapet_columns=32 peak=7 top=9
races orc

legend
A node grug_decor:xdecor_potted_rose
B node grug_decor:xdecor_potted_tulip
C role bed variant=_bottom
D role bed variant=_top
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
g role wall_infill
h role wall_infill else=g
i role wall_infill else=air
j role window
k role window o=facedir:3
l role window_frame
end

layer 0
| QQQQQQQQQ |
|QQJJJJJJJQQ|
|QJJIIIUIJJQ|
|QJIIIIUIIJQ|
|QJIITTIIIJQ|
|QJIITTIIIJQ|
|QJIIIIIIIJQ|
|QJIIIIIIIJQ|
|QJJIIIIIJJQ|
|QQJJJJJJJQQ|
| QQQQQQQQQ |
layer 1
| ...A..... |
|..RfffGfR..|
|.RfC...KER.|
|.l.D..X..l.|
|Af.c.W...fA|
|Bf.Z.dd..fB|
|Al...V...lA|
|.f.....Y.f.|
|.Rf....afR.|
|..RlfflfR..|
| ...ABA... |
layer 2
| ......... |
|..RiiRHiR..|
|.Rh....LER.|
|.l.......l.|
|.k.......k.|
|.k.Z.ee..k.|
|.l.......l.|
|.i.....a.i.|
|.Rh.....hR.|
|..RljjliR..|
| ......... |
layer 3
| ...O...O. |
|..RiiRiiR..|
|.Rh....EER.|
|.l.......l.|
|.k.......k.|
|.k.......k.|
|.l.......l.|
|.i.......i.|
|.RhN...MhR.|
|..RljjliR..|
| ......... |
layer 4
| ......... |
|..RiiRiiR..|
|.Rh....EER.|
|.l.......l.|
|.i.......i.|
|.R.......R.|
|.l.......l.|
|.i.......i.|
|.Rh.....hR.|
|..RliRliR..|
| ......... |
layer 5
| ......... |
|..RiiRiiR..|
|.Rh....EER.|
|.l.......l.|
|.i.......i.|
|.R.......R.|
|.l.......l.|
|.i.......i.|
|.Rh.....hR.|
|..RliRliR..|
| ......... |
layer 6
| ......... |
|..RiiRiiR..|
|.Rh....EER.|
|.l.......l.|
|.i.......i.|
|.R.......R.|
|.l.......l.|
|.i.......i.|
|.Rh.....hR.|
|..RliRliR..|
| ......... |
layer 7
| SSSSSSSSS |
|SSSSSSSSSSS|
|SSSSSSSSESS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
|SSSSSSSSSSS|
| SSSSSSSSS |
layer 8
| ......... |
|.PPPPPPPPP.|
|.P......EP.|
|.P.......P.|
|.P.......P.|
|.P.......P.|
|.P.......P.|
|.P.......P.|
|.P.......P.|
|.PPPPPPPPP.|
| ......... |
layer 9
| ......... |
|.b.b.b.b.b.|
|........F..|
|.b.......b.|
|...........|
|.b.......b.|
|...........|
|.b.......b.|
|...........|
|.b.b.b.b.b.|
| ......... |

points
doors 5 1 0 face=0
inside 3 1 6 id={id}
room_corner 2 0 1 closed=true id={id} top=6
room_corner 6 0 7
room_corner 1 0 2 closed=true id={id} top=6
room_corner 7 0 6
lights 3 3 -1
lights 7 3 -1
lights 6 2 1
lights 2 3 7
lights 6 3 7
end

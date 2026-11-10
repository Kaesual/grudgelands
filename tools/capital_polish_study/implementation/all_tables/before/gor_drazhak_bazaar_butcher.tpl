grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:bazaar_butcher, gor_drazhak:bazaar_brewhouse, gor_drazhak:bazaar_smithy
name gor_drazhak_bazaar_butcher
pivot 16 13
origin -1 0 -1
size 18 9 15
cell 1
meta extent=[-1,-1,16,13] parapet_columns=48 peak=6 top=8
races orc

legend
A node grug_decor:xdecor_potted_rose
B node grug_decor:xdecor_potted_tulip
C role chimney
D role chimney_cap
E role door variant=_a o=facedir:1
F role door variant=_b o=facedir:1
G role door_hidden
H role door_hidden o=facedir:1
I role floor
J role foundation
K role hearth o=facedir:1
L role hearth o=facedir:2
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role low_wall
R role path
S role post
T role roof_ridge
U role rug_accent
V role seat
W role seat o=facedir:2
X role shelf
Y role shelf o=facedir:1
Z role shelf_vessels
a role shelf_vessels o=facedir:1
b role signature else=air
c role storage
d role storage o=facedir:2
e role storage o=facedir:3
f role table_leg
g role table_top
h role wall_accent
i role wall_infill else=air
j role window
k role window o=facedir:3
l role window_frame
m role workbench
end

layer 0
|RRRRRRRRRRRRR     |
|RJJJJJJJJJJJR     |
|RJIIIIIIIIIJR     |
|RJIIIIIIIIIJRRRRRR|
|RJIIIIIIIIIJJJJJJR|
|RJIIIIIIIIIIIIIIJR|
|RJIIIIIIIIIIIIIIJR|
|RJIIIIIIIIIIIIIIJR|
|RJIIIIIIIIIIUUUIJR|
|RJIIIUUUIIIIIIIIJR|
|RJIIIIIIIIIJJJJJJR|
|RJIIIIIIIIIJRRRRRR|
|RJIIIIIIIIIJR     |
|RJJJJJJJJJJJR     |
|RRRRRRRRRRRRR     |
layer 1
|...BAB...c...     |
|.SlhhlChhlhS.     |
|.l.mL.L.Lm.h.     |
|.h.........hBAB...|
|.h.........lhhlhS.|
|.l..........dd..C.|
|.F....W.........hB|
|.E...fff.....m.KhA|
|.h....V.........lB|
|ch..........XZ..h.|
|.le.......YlhhlhS.|
|.he.......ahB.c...|
|.he.......YhA     |
|.llhhllhhlhl.     |
|.............     |
layer 2
|.............     |
|.SljjlCjjlSS.     |
|.l..M.M.M..i.     |
|.k.........i......|
|.k.........ljjliS.|
|.l..............C.|
|.G..............k.|
|.H...ggg.....D.Mk.|
|.i..............l.|
|ci..............i.|
|.l.........ljjliS.|
|.k.........k......|
|.k.........k.     |
|.lljjlljjlSl.     |
|.............     |
layer 3
|.............     |
|.SljjlCjjlSS.     |
|.lO.C.C.C..i.     |
|.k........Ni......|
|.k.........ljjliS.|
|Nl.............NC.|
|.i..............k.|
|.S.............Ck.|
|.i..............l.|
|Ni............P.i.|
|.lO.......NljjliS.|
|.k.........k......|
|.k.........k.     |
|.lljjlljjlSl.     |
|.............     |
layer 4
|.............     |
|.SliSlCSilSS.     |
|.l..C.C.C..i.     |
|.i.........i......|
|.S.........liSliS.|
|.l..............C.|
|.i..............i.|
|.S.............CS.|
|.i..............l.|
|.i..............i.|
|.l.........liSliS.|
|.i.........i......|
|.i.........i.     |
|.lliSllSilSl.     |
|.............     |
layer 5
|.............     |
|.SliSlCSilSS.     |
|.l..C.C.C..i.     |
|.i.........i......|
|.S.........liSliS.|
|.l..............C.|
|.i..............i.|
|.S.............CS.|
|.i..............l.|
|.i..............i.|
|.l.........liSliS.|
|.i.........i......|
|.i.........i.     |
|.lliSllSilSl.     |
|.............     |
layer 6
|TTTTTTTTTTTTT     |
|TTTTTTCTTTTTT     |
|TTTTTTTTTTTTT     |
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTTTTTCT|
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTTTTTTT|
|TTTTTTTTTTTTT     |
|TTTTTTTTTTTTT     |
|TTTTTTTTTTTTT     |
layer 7
|QQQQQQQQQQQQQ     |
|Q.....C......     |
|Q............     |
|Q................Q|
|Q................Q|
|Q...............CQ|
|Q................Q|
|Q................Q|
|Q................Q|
|Q................Q|
|Q................Q|
|Q................Q|
|Q............     |
|Q............     |
|QQQQQQQQQQQQQ     |
layer 8
|.b.b.b.b.b.b.     |
|b.....D......     |
|.............     |
|b.................|
|.................b|
|b...............D.|
|.................b|
|b.................|
|.................b|
|b.................|
|.................b|
|b.................|
|.............     |
|b............     |
|.b.b.b.b.b.b.     |

points
doors 0 1 6 face=1
doors 0 1 5 face=1
inside 2 1 9 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 9 0 11
room_corner 10 0 4 closed=true id={id} top=5
room_corner 14 0 8
lights -1 3 4
lights -1 3 8
lights 3 2 1
lights 5 2 1
lights 7 2 1
lights 1 3 1
lights 9 3 2
lights 1 3 9
lights 9 3 9
lights 14 2 6
lights 14 3 4
lights 13 3 8
end

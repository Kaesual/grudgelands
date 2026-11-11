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
K role hearth o=facedir:1
L role hearth o=facedir:2
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role low_wall
R role path
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
f node grug_decor:xdecor_table
h role wall_accent
j role window
k role window o=facedir:3
l role window_frame
m role workbench
J role facade_base
S role facade_frame
g role facade_infill
i role facade_roof_ridge
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
|.JJhhJChhJhJ.     |
|.J.mL.L.Lm.h.     |
|.h.........hBAB...|
|.h.........lhhJhJ.|
|.J..........dd..C.|
|.F....W.........hB|
|.E...fff.....m.KhA|
|.h....V.........JB|
|ch..........XZ..h.|
|.Je.......YlhhJhJ.|
|.he.......ahB.c...|
|.he.......YhA     |
|.JJhhJJhhJhJ.     |
|.............     |
layer 2
|.............     |
|.SgjjSCjjggS.     |
|.g..M.M.M..g.     |
|.k.........S......|
|.k.........ljjggS.|
|.S..............C.|
|.G..............k.|
|.H.............Mk.|
|.g..............g.|
|cS..............g.|
|.g.........ljjggS.|
|.k.........k......|
|.k.........k.     |
|.SgjjgSjjggS.     |
|.............     |
layer 3
|.............     |
|.SgjjSCjjggS.     |
|.gO.C.C.C..g.     |
|.k........NS......|
|.k.........ljjggS.|
|NS.............NC.|
|.g..............k.|
|.g.............Ck.|
|.g..............g.|
|NS............P.g.|
|.gO.......NljjggS.|
|.k.........k......|
|.k.........k.     |
|.SgjjgSjjggS.     |
|.............     |
layer 4
|.............     |
|.SgggSCggggS.     |
|.g..C.C.C..g.     |
|.g.........S......|
|.g.........lggggS.|
|.S..............C.|
|.g..............g.|
|.g.............Cg.|
|.g..............g.|
|.S..............g.|
|.g.........lggggS.|
|.g.........g......|
|.g.........g.     |
|.SggggSggggS.     |
|.............     |
layer 5
|.............     |
|.SJJJSCJJJJS.     |
|.J..C.C.C..J.     |
|.J.........S......|
|.J.........lJJJJS.|
|.S..............C.|
|.J..............J.|
|.J.............CJ.|
|.J..............J.|
|.S..............J.|
|.J.........lJJJJS.|
|.J.........J......|
|.J.........J.     |
|.SJJJJSJJJJS.     |
|.............     |
layer 6
|TTTTTTTTTTTTT     |
|TiiiiTCTiiiiT     |
|TiiiiiTiiiiiT     |
|TiiiiiiiiiiiiTTTTT|
|TiiiiiiiiiiiiiiiTT|
|TiiiiiiiiiiiiiiTCT|
|TiiiiiiiiiiiiiiiTT|
|TiiiiiiiiiiiiiiiiT|
|TiiiiiiiiiiiiiiiiT|
|TiiiiiiiiiiiiiiiiT|
|TiiiiiiiiiiiiiiiiT|
|TiiiiiiiiiiiiTTTTT|
|TiiiiiiiiiiiT     |
|TiiiiiiiiiiiT     |
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

grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:lore_chapel_yard
name highcourt_lore_chapel_yard
pivot 11 13
origin -1 0 -1
size 13 12 15
cell 1
meta extent=[-1,-1,11,13] peak=9 top=11
races human

legend
A role bench_seat o=facedir:2 else=air
B role board_table else=air
C role door variant=_a
D role door variant=_b
E role door_hidden
F role door_hidden o=facedir:3
G role floor
H role flower else=air
I role flower_alt else=air
J role foundation
K role light_wall o=wallmounted:2
L role light_wall o=wallmounted:3
M role light_wall o=wallmounted:4
N role path
O role plaza_edge
P role post
Q role roof_slab channel=roof
R role roof_stair channel=roof
S role roof_stair channel=roof o=facedir:1
T role roof_stair channel=roof o=facedir:2
U role roof_stair channel=roof o=facedir:3
V role roof_stair_outer channel=roof
W role roof_stair_outer channel=roof o=facedir:1
X role roof_stair_outer channel=roof o=facedir:2
Y role roof_stair_outer channel=roof o=facedir:3
Z role rug_accent
a role shelf o=facedir:1
b role shelf o=facedir:3
c role shelf_vessels o=facedir:1
d role shelf_vessels o=facedir:3
e role storage
f role wall_accent
g role wall_infill else=air
h role window
i role window o=facedir:3
j role window_frame
end

layer 0
|NNNNNNNNNNNNN|
|NJJJJJJJJJJJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGGGZGGGGJN|
|NJGGOOOOOGGJN|
|NJJJJJJJJJJJN|
|NNNNNNNNNNNNN|
layer 1
|.........II..|
|.PffffCDjffj.|
|.j.........j.|
|.f.........fH|
|.f.........fI|
|.j.........jH|
|.j.AAA.AAA.j.|
|.f.........f.|
|.f.AAA.AAA.f.|
|.j.........j.|
|.j.AAA.AAA.j.|
|.fb...B...af.|
|.fd.......cf.|
|.jjffjjffjfj.|
|.........e...|
layer 2
|.............|
|.PggPgEFjhhj.|
|.j.........j.|
|.i.........i.|
|.i.........i.|
|.j.........j.|
|.j.........j.|
|.i.........i.|
|.i.........i.|
|.j.........j.|
|.j.........j.|
|.i.........i.|
|.i.........i.|
|.jjhhjjhhjPj.|
|.............|
layer 3
|....M...M....|
|.PggPggPjhhj.|
|.j.........j.|
|.i.........i.|
|.i.........i.|
|.jL.......Kj.|
|.j.........j.|
|.i.........i.|
|.i.........i.|
|.j.........j.|
|.jL.......Kj.|
|.i.........i.|
|.i...M...M.i.|
|.jjhhjjhhjPj.|
|.............|
layer 4
|.............|
|.PggPggPjgPj.|
|.j.........j.|
|.g.........g.|
|.P.........P.|
|.j.........j.|
|.j.........j.|
|.P.........P.|
|.g.........g.|
|.j.........j.|
|.j.........j.|
|.g.........g.|
|.g.........g.|
|.jjgPjjPgjPj.|
|.............|
layer 5
|WRRRRRRRRRRRV|
|SPggPggPjgPjU|
|Sj.........jU|
|Sg.........gU|
|SP.........PU|
|Sj.........jU|
|Sj.........jU|
|SP.........PU|
|Sg.........gU|
|Sj.........jU|
|Sj.........jU|
|Sg.........gU|
|Sg.........gU|
|SjjgPjjPgjPjU|
|XTTTTTTTTTTTY|
layer 6
|.............|
|.WRRRRRRRRRV.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.S.........U.|
|.XTTTTTTTTTY.|
|.............|
layer 7
|.............|
|.............|
|..WRRRRRRRV..|
|..S.......U..|
|..S.......U..|
|..S.......U..|
|..S.......U..|
|..S.......U..|
|..S.......U..|
|..S.......U..|
|..S.......U..|
|..S.......U..|
|..XTTTTTTTY..|
|.............|
|.............|
layer 8
|.............|
|.............|
|.............|
|...WRRRRRV...|
|...S.....U...|
|...S.....U...|
|...S.....U...|
|...S.....U...|
|...S.....U...|
|...S.....U...|
|...S.....U...|
|...XTTTTTY...|
|.............|
|.............|
|.............|
layer 9
|.............|
|.............|
|.............|
|.............|
|....QQQQQ....|
|....QQQQQ....|
|....QQQQQ....|
|....QQQQQ....|
|....QQQQQ....|
|....QQQQQ....|
|....QQQQQ....|
|.............|
|.............|
|.............|
|.............|
layer 10
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
layer 11
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|
|.............|

points
doors 5 1 0 face=0
doors 6 1 0 face=0
inside 2 1 10 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 9 0 11
lights 3 3 -1
lights 7 3 -1
lights 1 3 4
lights 9 3 4
lights 1 3 9
lights 9 3 9
lights 4 3 11
lights 8 3 11
end

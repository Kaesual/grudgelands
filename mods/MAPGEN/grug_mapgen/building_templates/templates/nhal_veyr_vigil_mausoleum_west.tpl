grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:vigil_mausoleum_west
name nhal_veyr_vigil_mausoleum_west
pivot 11 13
origin -1 -1 -1
size 13 11 15
cell 1
meta candles=2 extent=[-1,-1,11,13] peak=7 plinth=0 top=9
races undead

legend
A node grug_decor:xdecor_potted_tulip_black
B node grug_decor:xdecor_potted_viola
C role castle_paving else=R
D role castle_paving else=air
E role castle_wall else=air
F role chimney
G role chimney_cap
H role door variant=_a
I role door_hidden
J role floor
L role hearth o=facedir:1
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role low_wall
R role path
S role plaza
V role roof_slab
f role seat o=facedir:1
g role seat o=facedir:3
h role shelf o=facedir:1
i role shelf o=facedir:3
j role shelf_vessels o=facedir:1
k role shelf_vessels o=facedir:3
l role storage
m role wall
o role window
p role window o=facedir:3
K role facade_roof_stair_outer channel=roof o=facedir:1
T role facade_roof_stair channel=roof o=facedir:1
U role facade_roof_stair_outer channel=roof o=facedir:2
W role facade_base
X role facade_frame
Y role facade_infill
Z role facade_roof_stair channel=roof o=facedir:0
a role facade_roof_stair channel=roof o=facedir:2
b role facade_roof_slab channel=roof o=facedir:0
c role facade_roof_stair_outer channel=roof o=facedir:0
d role facade_roof_stair channel=roof o=facedir:3
e role facade_roof_stair_outer channel=roof o=facedir:3
end

layer -1
|             |
|             |
|             |
|             |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|    SSSSS    |
|             |
|             |
|             |
|             |
layer 0
|RRRRRCCCRRRRR|
|RWWWWWWWWWWWR|
|RWJJJJJJJJJWR|
|RWJWWWWWWWJWR|
|RWJWDDDDDWJWR|
|RWJWQDDDQWJWR|
|RWJWQDDDQWJWR|
|RWJWDDDDDWJWR|
|RWJWQDDDQWJWR|
|RWJWQDDDQWJWR|
|RWJWWWWWWWJWR|
|RWJWWWWWWWJWR|
|RWJJJJJJJJJWR|
|RWWWWWWWWWWWR|
|RRRRRRRRRRRRR|
layer 1
|....E...E....|
|.WWWWWHWWWWW.|
|.W........LW.|
|.W.........WA|
|.Wg.......fWB|
|.W..V...V..WA|
|.Wg.V...V.fW.|
|.W.........W.|
|.Wg.V...V.fW.|
|.W..V...V..W.|
|.W..MGGGM..W.|
|.Wi.......hW.|
|.Wk.......jW.|
|.WWWWWWWWWWW.|
|...ABA...l...|
layer 2
|....M...M....|
|.XmmmXImYooX.|
|.Y........MY.|
|.p.........p.|
|.p.........p.|
|.X.........X.|
|.Y.........Y.|
|.p.........p.|
|.p.........p.|
|.X.........X.|
|.Y.........Y.|
|.p.........p.|
|.p.........p.|
|.XYooYXooYmX.|
|.............|
layer 3
|....P...P....|
|.XmmmXmmYooX.|
|.Y........FY.|
|.p.........p.|
|.p.........p.|
|.XO.......NX.|
|.Y.........Y.|
|.p.........p.|
|.p.........p.|
|.X.........X.|
|.YO.......NY.|
|.p.........p.|
|.p.........p.|
|.XYooYXooYmX.|
|.............|
layer 4
|KZZZZZZZZZZZc|
|TXXXXXXXXXXXd|
|TX........FXd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TX.........Xd|
|TXXXXXXXXXXXd|
|Uaaaaaaaaaaae|
layer 5
|.............|
|.KZZZZZZZZZc.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.T.........d.|
|.Uaaaaaaaaae.|
|.............|
layer 6
|.............|
|.............|
|..KZZZZZZZc..|
|..T.......d..|
|..T.......d..|
|..T.......d..|
|..T.......d..|
|..T.......d..|
|..T.......d..|
|..T.......d..|
|..T.......d..|
|..T.......d..|
|..Uaaaaaaae..|
|.............|
|.............|
layer 7
|.............|
|.............|
|.............|
|...bbbbbbb...|
|...bbbbbbb...|
|...bbbbbbb...|
|...bbbbbbb...|
|...bbbbbbb...|
|...bbbbbbb...|
|...bbbbbbb...|
|...bbbbbbb...|
|...bbbbbbb...|
|.............|
|.............|
|.............|
layer 8
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
layer 9
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
inside 5 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 9 0 11
lights 3 3 -1
lights 7 3 -1
lights 3 1 9
lights 7 1 9
lights 9 2 1
lights 1 3 4
lights 9 3 4
lights 1 3 9
lights 9 3 9
lights 3 2 -1
lights 7 2 -1
sockets 5 1 -1 face=0 id={id}_mourn role=idle tags=[door]
end

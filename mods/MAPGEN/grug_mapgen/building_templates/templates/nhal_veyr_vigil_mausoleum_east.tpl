grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:vigil_mausoleum_east
name nhal_veyr_vigil_mausoleum_east
pivot 9 13
origin -1 -1 -1
size 11 11 15
cell 1
meta candles=2 extent=[-1,-1,9,13] peak=7 plinth=0 top=9
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
|           |
|           |
|           |
|           |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|    SSS    |
|           |
|           |
|           |
|           |
layer 0
|RRRRCCCRRRR|
|RWWWWWWWWWR|
|RWJJJJJJJWR|
|RWJWWWWWJWR|
|RWJWDDDWJWR|
|RWJWQDQWJWR|
|RWJWQDQWJWR|
|RWJWDDDWJWR|
|RWJWQDQWJWR|
|RWJWQDQWJWR|
|RWJWWWWWJWR|
|RWJWWWWWJWR|
|RWJJJJJJJWR|
|RWWWWWWWWWR|
|RRRRRRRRRRR|
layer 1
|...E...E...|
|.WWWWHWWWW.|
|.W......LW.|
|.W.......WA|
|.Wg.....fWB|
|.W..V.V..WA|
|.Wg.V.V.fW.|
|.W.......W.|
|.Wg.V.V.fW.|
|.W..V.V..W.|
|.W.MGGGM.W.|
|.Wi.....hW.|
|.Wk.....jW.|
|.WWWWWWWWW.|
|...ABA.l...|
layer 2
|...M...M...|
|.XmmXImmmX.|
|.Y......MY.|
|.p.......p.|
|.p.......p.|
|.X.......X.|
|.Y.......Y.|
|.p.......p.|
|.p.......p.|
|.X.......X.|
|.Y.......Y.|
|.p.......p.|
|.p.......p.|
|.XYooXYooX.|
|...........|
layer 3
|...P...P...|
|.XmmXmmmmX.|
|.Y......FY.|
|.p.......p.|
|.p.......p.|
|.XO.....NX.|
|.Y.......Y.|
|.p.......p.|
|.p.......p.|
|.X.......X.|
|.YO.....NY.|
|.p.......p.|
|.p.......p.|
|.XYooXYooX.|
|...........|
layer 4
|KZZZZZZZZZc|
|TXXXXXXXXXd|
|TX......FXd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TX.......Xd|
|TXXXXXXXXXd|
|Uaaaaaaaaae|
layer 5
|...........|
|.KZZZZZZZc.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.T.......d.|
|.Uaaaaaaae.|
|...........|
layer 6
|...........|
|...........|
|..KZZZZZc..|
|..T.....d..|
|..T.....d..|
|..T.....d..|
|..T.....d..|
|..T.....d..|
|..T.....d..|
|..T.....d..|
|..T.....d..|
|..T.....d..|
|..Uaaaaae..|
|...........|
|...........|
layer 7
|...........|
|...........|
|...........|
|...bbbbb...|
|...bbbbb...|
|...bbbbb...|
|...bbbbb...|
|...bbbbb...|
|...bbbbb...|
|...bbbbb...|
|...bbbbb...|
|...bbbbb...|
|...........|
|...........|
|...........|
layer 8
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

points
doors 4 1 0 face=0
inside 4 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 11
lights 2 3 -1
lights 6 3 -1
lights 2 1 9
lights 6 1 9
lights 7 2 1
lights 1 3 4
lights 7 3 4
lights 1 3 9
lights 7 3 9
lights 2 2 -1
lights 6 2 -1
sockets 4 1 -1 face=0 id={id}_mourn role=idle tags=[door]
end

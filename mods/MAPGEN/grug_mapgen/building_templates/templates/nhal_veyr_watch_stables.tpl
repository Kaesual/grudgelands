grudgelands-building-template 1
# Frozen from the building generators (Round 56): nhal_veyr:watch_stables
name nhal_veyr_watch_stables
pivot 15 13
origin -1 0 -1
size 17 12 15
cell 1
meta extent=[-1,-1,15,13] peak=9 top=11
races undead

legend
A node grug_decor:xdecor_potted_tulip_black
B node grug_decor:xdecor_potted_viola
C role door variant=_a
D role door variant=_b
E role door_hidden
F role door_hidden o=facedir:3
G role fence
H role floor
I role foundation
J role hearth o=facedir:1
K role hearth o=facedir:3
L role light_wall o=wallmounted:2
M role light_wall o=wallmounted:3
N role light_wall o=wallmounted:4
O role path
P role post
Q role roof_slab
R role roof_stair
S role roof_stair o=facedir:2
T role storage
U role wall
V role wall_accent
W role window
X role window o=facedir:3
Y role window_frame
end

layer 0
|OOOOOOOOOOOOOOOOO|
|OIIIIIIIIIIIIIIIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIHHHHHHHHHHHHHIO|
|OIIIIIIIIIIIIIIIO|
|OOOOOOOOOOOOOOOOO|
layer 1
|...ABAT..........|
|.PYVVYVVCDYVVYVP.|
|.Y.............Y.|
|.VK...........JVA|
|.V.G.........G.VB|
|.YK...........JYA|
|.Y.G.........G.Y.|
|.VK...........JV.|
|.V.G.........G.V.|
|.YK...........JY.|
|.Y.G.........G.Y.|
|.VK...........JVT|
|.V.G...TTT...G.V.|
|.YYVVYYVVYYVVYVY.|
|.................|
layer 2
|......T..........|
|.PYWWYUUEFYWWYUP.|
|.Y.............Y.|
|.X.............X.|
|.X.............X.|
|.Y.............Y.|
|.Y.............Y.|
|.X.............X.|
|.X.............X.|
|.Y.............Y.|
|.Y.............Y.|
|.X.............X.|
|.X.............X.|
|.YYWWYYWWYYWWYUY.|
|.................|
layer 3
|......N...N......|
|.PYWWYUUUUYWWYUP.|
|.Y.............Y.|
|.X.............X.|
|.X.............X.|
|.YM...........LY.|
|.Y.............Y.|
|.X.............X.|
|.X.............X.|
|.Y.............Y.|
|.YM...........LY.|
|.X.............X.|
|.X.............X.|
|.YYWWYYWWYYWWYUY.|
|.................|
layer 4
|.................|
|.PYUUYUUUUYUUYUP.|
|.Y.............Y.|
|.U.............U.|
|.U.............U.|
|.Y.............Y.|
|.Y.............Y.|
|.U.............U.|
|.U.............U.|
|.Y.............Y.|
|.Y.............Y.|
|.U.............U.|
|.U.............U.|
|.YYUUYYUUYYUUYUY.|
|.................|
layer 5
|RRRRRRRRRRRRRRRRR|
|.PYUUYUUUUYUUYUP.|
|.Y.............Y.|
|.U.............U.|
|.U.............U.|
|.Y.............Y.|
|.Y.............Y.|
|.U.............U.|
|.U.............U.|
|.Y.............Y.|
|.Y.............Y.|
|.U.............U.|
|.U.............U.|
|.YYUUYYUUYYUUYUY.|
|SSSSSSSSSSSSSSSSS|
layer 6
|.................|
|RRRRRRRRRRRRRRRRR|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|SSSSSSSSSSSSSSSSS|
|.................|
layer 7
|.................|
|.................|
|RRRRRRRRRRRRRRRRR|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|SSSSSSSSSSSSSSSSS|
|.................|
|.................|
layer 8
|.................|
|.................|
|.................|
|RRRRRRRRRRRRRRRRR|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|.U.............U.|
|SSSSSSSSSSSSSSSSS|
|.................|
|.................|
|.................|
layer 9
|.................|
|.................|
|.................|
|.................|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|QQQQQQQQQQQQQQQQQ|
|.................|
|.................|
|.................|
|.................|
layer 10
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
layer 11
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|
|.................|

points
doors 7 1 0 face=0
doors 8 1 0 face=0
inside 7 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 13 0 11
lights 5 3 -1
lights 9 3 -1
lights 1 3 4
lights 13 3 4
lights 1 3 9
lights 13 3 9
sockets 7 1 10 face=2 id={id}_groom role=idle tags=[work]
sockets 7 1 2 face=2 id={id}_gate role=idle tags=[door]
end

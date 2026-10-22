grudgelands-building-template 1
# Frozen from the building generators (Round 56): lethariel:martial_stable
name lethariel_martial_stable
pivot 15 11
origin -1 0 -1
size 17 12 13
cell 1
meta extent=[-1,-1,15,11] peak=9 top=11
races elf

legend
A role door variant=_a
B role door variant=_b
C role door_hidden
D role door_hidden o=facedir:3
E role fence
F role floor
G role flower else=air
H role flower_alt else=air
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
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIFFFFFFFFFFFFFIO|
|OIIIIIIIIIIIIIIIO|
|OOOOOOOOOOOOOOOOO|
layer 1
|...GHGH..........|
|.PYVVYVVABYVVYVP.|
|.Y.............Y.|
|.VK...........JVG|
|.V.E.........E.VH|
|.YK...........JYG|
|.Y.E.........E.Y.|
|.VK...........JV.|
|.V.E.........E.V.|
|.YK...........JYT|
|.V.E...TTT...E.V.|
|.PYVVYYVVYYVVYVP.|
|.................|
layer 2
|.................|
|.PYWWYUUCDYWWYUP.|
|.Y.............Y.|
|.X.............X.|
|.X.............X.|
|.Y.............Y.|
|.Y.............Y.|
|.X.............X.|
|.X.............X.|
|.Y.............Y.|
|.U.............U.|
|.PYWWYYWWYYWWYUP.|
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
|.YM...........LY.|
|.U.............U.|
|.PYWWYYWWYYWWYUP.|
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
|.U.............U.|
|.PYUUYYUUYYUUYUP.|
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
|.U.............U.|
|.PYUUYYUUYYUUYUP.|
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

points
doors 7 1 0 face=0
doors 8 1 0 face=0
inside 7 1 3 id={id}
room_corner 1 0 1 closed=true id={id} top=5
room_corner 13 0 9
lights 5 3 -1
lights 9 3 -1
lights 1 3 4
lights 13 3 4
lights 1 3 8
lights 13 3 8
sockets 7 1 8 face=2 id={id}_groom role=idle tags=[work]
sockets 7 1 2 face=2 id={id}_gate role=idle tags=[door]
end

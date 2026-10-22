grudgelands-building-template 1
# Frozen from the building generators (Round 56): highcourt:chapel_house
name highcourt_chapel_house
pivot 9 9
origin -1 0 -1
size 11 11 11
cell 1
meta extent=[-1,-1,9,9] peak=8 top=10
races human

legend
A role bed variant=_bottom
B role bed variant=_top
C role chimney
D role chimney_cap
E role door variant=_a
F role door_hidden
G role floor
H role foundation
I role hearth o=facedir:1
J role light_post o=wallmounted:1
K role light_wall o=wallmounted:2
L role light_wall o=wallmounted:3
M role light_wall o=wallmounted:4
N role path
O role post
P role roof_slab
Q role roof_stair
R role roof_stair o=facedir:1
S role roof_stair o=facedir:2
T role roof_stair o=facedir:3
U role roof_stair_outer
V role roof_stair_outer o=facedir:1
W role roof_stair_outer o=facedir:2
X role roof_stair_outer o=facedir:3
Y role rug
Z role rug_accent
a role seat
b role seat o=facedir:2
c role seat o=facedir:3
d role shelf o=facedir:1
e role shelf o=facedir:3
f role shelf_vessels o=facedir:1
g role shutter else=air
h role shutter o=facedir:1 else=air
i role shutter o=facedir:2 else=air
j role shutter o=facedir:3 else=air
k role storage o=facedir:3
l role table_leg
m role table_top
n role wall_accent
o role wall_infill else=air
p role window
q role window o=facedir:3
r role window_frame
end

layer 0
|NNNNNNNNNNN|
|NHHHHHHHHHN|
|NHGGGGGZGHN|
|NHGGGGGZGHN|
|NHGGYYGGGHN|
|NHGGYYGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHGGGGGGGHN|
|NHHHHHHHHHN|
|NNNNNNNNNNN|
layer 1
|...........|
|.OnEnnrnnr.|
|.rA.....IC.|
|.nB....c.n.|
|.nk..b...n.|
|.re..ll..r.|
|.r...a...r.|
|.n......dn.|
|.n......fn.|
|.rrnnrrnnr.|
|...........|
layer 2
|.......gg..|
|.OoFOorppr.|
|.r......JC.|
|hq.......qj|
|hq.......qj|
|.re..mm..r.|
|.r.......r.|
|hq......fqj|
|hq.......qj|
|.rrpprrppr.|
|...ii..ii..|
layer 3
|.M...M.gg..|
|.OooOorppr.|
|.r......CC.|
|hq.......qj|
|hq.......qj|
|.rL.....Kr.|
|.r.......r.|
|hq.......qj|
|hq.......qj|
|.rrpprrppr.|
|...ii..ii..|
layer 4
|...........|
|.OooOorOor.|
|.r......CC.|
|.o.......o.|
|.O.......O.|
|.r.......r.|
|.r.......r.|
|.O.......O.|
|.o.......o.|
|.rroOrrOor.|
|...........|
layer 5
|VQQQQQQQQQU|
|ROooOorOorT|
|Rr......CCT|
|Ro.......oT|
|RO.......OT|
|Rr.......rT|
|Rr.......rT|
|RO.......OT|
|Ro.......oT|
|RrroOrrOorT|
|WSSSSSSSSSX|
layer 6
|...........|
|.VQQQQQQQU.|
|.R.......C.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.R.......T.|
|.WSSSSSSSX.|
|...........|
layer 7
|...........|
|...........|
|..VQQQQQUC.|
|..R.....T..|
|..R.....T..|
|..R.....T..|
|..R.....T..|
|..R.....T..|
|..WSSSSSX..|
|...........|
|...........|
layer 8
|...........|
|...........|
|.........C.|
|...PPPPP...|
|...PPPPP...|
|...PPPPP...|
|...PPPPP...|
|...PPPPP...|
|...........|
|...........|
|...........|
layer 9
|...........|
|...........|
|.........C.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
layer 10
|...........|
|...........|
|.........D.|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|
|...........|

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

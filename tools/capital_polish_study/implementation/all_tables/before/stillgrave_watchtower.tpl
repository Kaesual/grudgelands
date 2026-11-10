grudgelands-building-template 1
# Frozen from the building generators (Round 56): stillgrave:watchtower
name stillgrave_watchtower
pivot 9 9
origin -1 0 -1
size 11 13 11
cell 1
meta peak=12
races undead

legend
A role beam
B role bed variant=_bottom
C role bed variant=_top
D role door variant=_a o=facedir:1
E role door_hidden o=facedir:1
F role floor
G role foundation
H role light_post o=wallmounted:1
I role light_wall o=wallmounted:2
J role light_wall o=wallmounted:3
K role path
L role post
M role railing
N role roof_slab
O role roof_stair
P role roof_stair o=facedir:1
Q role roof_stair o=facedir:2
R role roof_stair o=facedir:3
S role roof_stair_outer
T role roof_stair_outer o=facedir:1
U role roof_stair_outer o=facedir:2
V role roof_stair_outer o=facedir:3
W role seat
X role seat o=facedir:2
Y role storage
Z role storage o=facedir:1
a role table_leg
b role table_top
c role wall
d role wall_accent
e role window
f role window o=facedir:3
g role window_frame
end

layer 0
|KKKKKKKKKKK|
|KGGGGGGGGGK|
|KGFFFFFFFGK|
|KGFFFFFFFGK|
|KGFFFFFFFGK|
|KGFFFFFFFGK|
|KGFFFFFFFGK|
|KGFFFFFFFGK|
|KGFFFFFFFGK|
|KGGGGGGGGGK|
|KKKKKKKKKKK|
layer 1
|...........|
|.LgdgdgdgL.|
|.gB.....Zg.|
|.dCO.....d.|
|.g.......g.|
|.D.......d.|
|.g.....X.g.|
|Yd.....aadY|
|.g.....W.g.|
|.LgdgdgdgL.|
|...........|
layer 2
|...........|
|.LgdgdgdgL.|
|.g.......g.|
|.d.......d.|
|.g.O.....g.|
|.E.......d.|
|.g.......g.|
|Yd.....bbd.|
|.g.......g.|
|.LgdgdgdgL.|
|...........|
layer 3
|...........|
|.LgegcgegL.|
|Ig.......g.|
|.f.......f.|
|.g.......g.|
|.cJO.....c.|
|.g.......g.|
|.f.......f.|
|Ig.......g.|
|.LgegcgegL.|
|...........|
layer 4
|...........|
|.LgegcgegL.|
|.g.......g.|
|.f.......f.|
|.g.......g.|
|.c.......c.|
|.g.O.....g.|
|.f.......f.|
|.g.......g.|
|.LgegcgegL.|
|...........|
layer 5
|...........|
|.FFFFFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FF.FFFFFF.|
|.FFOFFFFFF.|
|.FFFFFFFFF.|
|.FFFFFFFFF.|
|...........|
layer 6
|...........|
|.ddddddddd.|
|.dH.....Hd.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.d.......d.|
|.dH.....Hd.|
|.ddddddddd.|
|...........|
layer 7
|...........|
|.L.M.M.M.L.|
|...........|
|.M.......M.|
|...........|
|.M.......M.|
|...........|
|.M.......M.|
|...........|
|.L.M.M.M.L.|
|...........|
layer 8
|TOOOOOOOOOS|
|PAAAAAAAAAR|
|PA.......AR|
|PA.......AR|
|PA.......AR|
|PA.......AR|
|PA.......AR|
|PA.......AR|
|PA.......AR|
|PAAAAAAAAAR|
|UQQQQQQQQQV|
layer 9
|...........|
|.TOOOOOOOS.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.P.......R.|
|.UQQQQQQQV.|
|...........|
layer 10
|...........|
|...........|
|..TOOOOOS..|
|..P.....R..|
|..P.....R..|
|..P.....R..|
|..P.....R..|
|..P.....R..|
|..UQQQQQV..|
|...........|
|...........|
layer 11
|...........|
|...........|
|...........|
|...TOOOS...|
|...P...R...|
|...P...R...|
|...P...R...|
|...UQQQV...|
|...........|
|...........|
|...........|
layer 12
|...........|
|...........|
|...........|
|...........|
|....NNN....|
|....NNN....|
|....NNN....|
|...........|
|...........|
|...........|
|...........|

points
doors 0 1 4 face=1
inside 5 6 4 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 7
lights -1 3 1
lights -1 3 7
lights 1 3 4
lights 1 6 1
lights 7 6 1
lights 1 6 7
lights 7 6 7
end

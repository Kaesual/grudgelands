grudgelands-building-template 1
# Frozen from the building generators (Round 56): gor_drazhak:bazaar_house, gor_drazhak:plaza_house
name gor_drazhak_bazaar_house
pivot 9 9
origin -1 0 -1
size 11 8 11
cell 1
meta extent=[-1,-1,9,9] parapet_columns=40 peak=5 top=7
races orc

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
N role low_wall
O role path
P role post
Q role roof_ridge
R role rug
S role rug_accent
T role seat
U role seat o=facedir:2
V role seat o=facedir:3
W role shelf o=facedir:1
X role shelf o=facedir:3
Y role shelf_vessels o=facedir:1
Z role signature else=air
a role storage o=facedir:3
b role table_leg
c role table_top
d role wall_accent
e role wall_infill else=air
f role window
g role window o=facedir:3
h role window_frame
end

layer 0
|OOOOOOOOOOO|
|OHHHHHHHHHO|
|OHGGGGGSGHO|
|OHGGGGGSGHO|
|OHGGRRGGGHO|
|OHGGRRGGGHO|
|OHGGGGGGGHO|
|OHGGGGGGGHO|
|OHGGGGGGGHO|
|OHHHHHHHHHO|
|OOOOOOOOOOO|
layer 1
|...........|
|.PdEddhddh.|
|.hA.....IC.|
|.dB....V.d.|
|.da..U...d.|
|.hX..bb..h.|
|.h...T...h.|
|.d......Wd.|
|.d......Yd.|
|.hhddhhddh.|
|...........|
layer 2
|...........|
|.PeFPehffh.|
|.h......JC.|
|.g.......g.|
|.g.......g.|
|.hX..cc..h.|
|.h.......h.|
|.g......Yg.|
|.g.......g.|
|.hhffhhffh.|
|...........|
layer 3
|.M...M.....|
|.PeePehffh.|
|.h......CC.|
|.g.......g.|
|.g.......g.|
|.hL.....Kh.|
|.h.......h.|
|.g.......g.|
|.g.......g.|
|.hhffhhffh.|
|...........|
layer 4
|...........|
|.PeePehPeh.|
|.h......CC.|
|.e.......e.|
|.P.......P.|
|.h.......h.|
|.h.......h.|
|.P.......P.|
|.e.......e.|
|.hhePhhPeh.|
|...........|
layer 5
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQCQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
|QQQQQQQQQQQ|
layer 6
|NNNNNNNNNNN|
|N.........N|
|N........CN|
|N.........N|
|N.........N|
|N.........N|
|N.........N|
|N.........N|
|N.........N|
|N.........N|
|NNNNNNNNNNN|
layer 7
|.Z.Z.Z.Z.Z.|
|Z.........Z|
|.........D.|
|Z.........Z|
|...........|
|Z.........Z|
|...........|
|Z.........Z|
|...........|
|Z.........Z|
|.Z.Z.Z.Z.Z.|

points
doors 2 1 0 face=0
inside 2 1 6 id={id}
room_corner 1 0 1 closed=true id={id} top=4
room_corner 7 0 7
lights 0 3 -1
lights 4 3 -1
lights 7 2 1
lights 1 3 4
lights 7 3 4
end

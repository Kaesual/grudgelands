grudgelands-building-template 1
# Frozen from the building generators (Round 56): silverleaf:terrace_house_west
name silverleaf_terrace_house_west
pivot 7 11
origin -1 0 -1
size 9 13 13
cell 1
meta peak=10
races elf

legend
A role bed variant=_bottom
B role bed variant=_top
C role bed_fancy variant=_bottom else=A
D role bed_fancy variant=_top else=B
E role chimney
F role chimney_cap
G role door variant=_a
H role door_hidden
I role floor
J role foundation
K role hearth o=facedir:1
L role light_beacon else=g
M role light_post o=wallmounted:1
N role light_wall o=wallmounted:2
O role light_wall o=wallmounted:3
P role light_wall o=wallmounted:4
Q role path
R role post
S role roof_slab
T role roof_stair o=facedir:1
U role roof_stair o=facedir:3
V role rug
W role rug_accent
X role seat
Y role seat o=facedir:2
Z role seat o=facedir:3
a role shelf o=facedir:1
b role shelf o=facedir:3
c role shelf_vessels o=facedir:1
d role storage o=facedir:3
e role table_leg
f role table_top
g role wall
h role wall_accent
i role window
j role window o=facedir:3
k role window_frame
end

layer 0
|QQQQQQQQQ|
|QJJJJJJJQ|
|QJIIIWIJQ|
|QJIIIWIJQ|
|QJIIIIIJQ|
|QJIVVIIJQ|
|QJIVVIIJQ|
|QJIIIIIJQ|
|QJIIIIIJQ|
|QJIIIIIJQ|
|QJIIIIIJQ|
|QJJJJJJJQ|
|QQQQQQQQQ|
layer 1
|.........|
|.RhhGhhR.|
|.kC...KE.|
|.hD..Z.h.|
|.hd....h.|
|.kb.Y..k.|
|.k..ee.k.|
|.h..X..h.|
|.h.....h.|
|.k....ak.|
|.h....ch.|
|.RkhhkhR.|
|.........|
layer 2
|.........|
|.RggHggR.|
|.k....ME.|
|.j.....j.|
|.j.....j.|
|.kb....k.|
|.k..ff.k.|
|.j.....j.|
|.j.....j.|
|.k....ck.|
|.g.....g.|
|.RkiikgR.|
|.........|
layer 3
|..P...P..|
|.RgggggR.|
|.k....EE.|
|.j.....j.|
|.j.....j.|
|.k.....k.|
|.kO...Nk.|
|.j.....j.|
|.j.....j.|
|.k.....k.|
|.g.....g.|
|.RkiikgR.|
|.........|
layer 4
|.........|
|.RgggggR.|
|.k....EE.|
|.g.....g.|
|.g.....g.|
|.k.....k.|
|.k.....k.|
|.g.....g.|
|.g.....g.|
|.k.....k.|
|.g.....g.|
|.RkggkgR.|
|.........|
layer 5
|.........|
|.RgggggR.|
|.k....EE.|
|.g.....g.|
|.g.....g.|
|.k.....k.|
|.k.....k.|
|.g.....g.|
|.g.....g.|
|.k.....k.|
|.g.....g.|
|.RkggkgR.|
|.........|
layer 6
|T.......U|
|TRgggggRU|
|Tk....EEU|
|Tg.....gU|
|Tg.....gU|
|Tk.....kU|
|Tk.....kU|
|Tg.....gU|
|Tg.....gU|
|Tk.....kU|
|Tg.....gU|
|TRkggkgRU|
|T.......U|
layer 7
|.T.....U.|
|.TgggggU.|
|.T.....E.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.T.....U.|
|.TgggggU.|
|.T.....U.|
layer 8
|..T...U..|
|..TgLgU..|
|..T...UE.|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..T...U..|
|..TgggU..|
|..T...U..|
layer 9
|...T.U...|
|...TgU...|
|...T.U.E.|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...T.U...|
|...TgU...|
|...T.U...|
layer 10
|....S....|
|....S....|
|....S..E.|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
|....S....|
layer 11
|.........|
|.........|
|.......F.|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
layer 12
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|
|.........|

points
doors 3 1 0 face=0
inside 2 1 8 id={id}
room_corner 1 0 1 closed=true id={id} top=6
room_corner 5 0 9
lights 1 3 -1
lights 5 3 -1
lights 5 2 1
lights 1 3 5
lights 5 3 5
end

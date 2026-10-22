grudgelands-building-template 1
# Fixture for the template gallery (lane VIEWER, Round 56): a small house
# written by hand in the format of building-template-format.md, with a door,
# a bed, pane windows, a wall torch, a role roof on the roof channel with an
# eave overhang, a race switch, an optional role with a fallback and points.
name fixture_house
pivot 7 7
origin -1 0 -1
size 9 8 9
cell 1
meta peak=7
races dwarf elf

legend
F role floor
B role foundation
P role post
W role wall
C role ceiling
d role door variant=_a o=facedir:0
h role door_hidden o=facedir:0
g role window o=facedir:3
b role bed variant=_bottom o=facedir:0
t role bed variant=_top o=facedir:0
T node default:torch_wall o=wallmounted:4
k role storage o=facedir:2
f role flower else=air
r race elf=f *=k
0 role roof_stair channel=roof o=facedir:0
1 role roof_stair channel=roof o=facedir:1
2 role roof_stair channel=roof o=facedir:2
3 role roof_stair channel=roof o=facedir:3
s role roof_slab channel=roof
end

layer 0
|         |
| BBBBBBB |
| BFFFFFB |
| BFFFFFB |
| BFFFFFB |
| BFFFFFB |
| BFFFFFB |
| BBBBBBB |
|         |
layer 1
|         |
| PWWdWWP |
| W.....W |
| W.....W |
| W.....W |
| Wb....W |
| Wt...rW |
| PWWWWWP |
|         |
layer 2
|         |
| PWWhWWP |
| W.....W |
| W.....W |
| g.....g |
| W.....W |
| W.....W |
| PWWWWWP |
|         |
layer 3
|         |
| PWWWWWP |
| W.....W |
| W.....W |
| W.....W |
| W.....W |
| W..T..W |
| PWWWWWP |
|         |
layer 4
|s0000000s|
|1CCCCCCC3|
|1CCCCCCC3|
|1CCCCCCC3|
|1CCCCCCC3|
|1CCCCCCC3|
|1CCCCCCC3|
|1CCCCCCC3|
|s2222222s|
layer 5
|         |
| s00000s |
| 1.....3 |
| 1.....3 |
| 1.....3 |
| 1.....3 |
| 1.....3 |
| s22222s |
|         |
layer 6
|         |
|         |
|  s000s  |
|  1...3  |
|  1...3  |
|  1...3  |
|  s222s  |
|         |
|         |
layer 7
|         |
|         |
|         |
|   sss   |
|   sss   |
|   sss   |
|         |
|         |
|         |

points
doors 3 1 0 face=0
inside 3 1 2 id={id}
room_corner 1 1 1 top=3 closed=true id={id}
room_corner 5 1 5
sockets 2 1 2 face=1 id={id}_keeper tags=[door,work] note="by the door"
lights 3 3 5
end

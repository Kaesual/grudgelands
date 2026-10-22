grudgelands-building-template 1
# Fixture for the template gallery (lane VIEWER, Round 56): a shed in the
# two-character cell format (`cell 2`), with a door, a role wall light, a
# glass pane of a fixed node and a slab roof on the roof channel.
name fixture_shed
pivot 3 4
origin 0 0 0
size 3 4 4
cell 2
races dwarf human

legend
Fl role floor
Ww role wall
Dr role door variant=_a o=facedir:0
Dh role door_hidden o=facedir:0
Li role light_indoor o=wallmounted:4
Gl node default:glass
Rs role roof_slab channel=roof
end

layer 0
|FlFlFl|
|FlFlFl|
|FlFlFl|
|FlFlFl|
layer 1
|WwDrWw|
|Ww..Ww|
|Ww..Ww|
|WwWwWw|
layer 2
|WwDhWw|
|Ww..Ww|
|WwLiWw|
|WwGlWw|
layer 3
|RsRsRs|
|RsRsRs|
|RsRsRs|
|RsRsRs|

points
doors 1 1 0 face=0
inside 1 1 1 id={id}
end

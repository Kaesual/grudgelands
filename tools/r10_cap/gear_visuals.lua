-- Resolve the actual inert-display item names and registered inventory artwork.
local repo=assert(arg[1]);local definitions={}
core={registered_items=definitions,register_tool=function(n,d) definitions[n]=d end,
 register_craftitem=function(n,d) definitions[n]=d end,colorize=function(_,s) return s end,
 get_modpath=function() return repo..'/mods/ITEMS/grug_gear' end,
 register_on_mods_loaded=function() end,register_on_craft=function() end,
 register_on_item_pickup=function() end,log=function() end}
dofile(repo..'/mods/ITEMS/grug_gear/init.lua')
for _,row in ipairs({{'weapon',grug_gear.weapon_item('sword',1)},
 {'armor',grug_gear.armor_item('chest','metal',1)},
 {'jewel',grug_gear.trinket_item('manawell',1)}}) do
 print(row[1],row[2],assert(definitions[row[2]]).inventory_image)
end

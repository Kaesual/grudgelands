-- Actual inert node definitions for native evidence rendering.
local repo=assert(arg[1])
core={register_node=function(name,def)
 print('node',name,table.concat(def.tiles,'|'),def.mesh or '-',def.drawtype or 'normal')
 local boxes=def.node_box and def.node_box.fixed
 if boxes then
  if type(boxes[1])=='number' then boxes={boxes} end
  for _,box in ipairs(boxes) do print('box',name,unpack(box)) end
 end
end}
dofile(repo..'/mods/ITEMS/grug_decor/capital.lua')
core.register_lbm=function() end
core.registered_nodes={}
default={set_inventory_action_loggers=function() end,node_sound_metal_defaults=function() return {} end,
 node_sound_wood_defaults=function() return {} end}
dofile(repo..'/mods/PLAYER/grug_jobs/station_nodes.lua').register_nodes()
grug_brewing={}
core.register_on_player_receive_fields=function() end
core.register_on_mods_loaded=function() end
core.register_craft=function() end
dofile(repo..'/mods/ITEMS/grug_brewing/node.lua')

-- Actual R7 resolver with real registered semantics; no MTS population.
return function(repo)
 local dir=repo.."/mods/MAPGEN/grug_mapgen/wp40"
 local common=dofile(repo.."/tools/wp40/r6/common.lua")
 local sha=common.new_sha256()
 local source=common.read_file(dir.."/r7_content.lua")
 local names,seen={},{ }
 local function add(name) if not seen[name] then names[#names+1]=name;seen[name]=true end end
 for _,name in ipairs({"air","ignore","default:water_source","default:water_flowing",
  "default:river_water_source","default:river_water_flowing","grug_farming:soil","grug_farming:soil_wet"}) do add(name) end
 for _,key in ipairs({"ACCEPTED_R6_ROWS","CULTURAL_NAMES","P9G_NAMES","ANCHOR_NAMES"}) do
  local block=assert(source:match("local "..key.." = {(.-)\n\t}"))
  for name in block:gmatch('"([^"\n]+:[^"\n]+)"') do add(name) end
 end
 table.sort(names)
 local catalog=dofile(repo.."/mods/ITEMS/grug_gathering/catalog.lua")
 local semantics=dofile(repo.."/tools/wp40/r7/node_semantics_fixture.lua")(repo,catalog,names)
 local api={registered_nodes=semantics.definitions}
 local cids={};for index,name in ipairs(names) do cids[name]=index end
 function api.get_content_id(name) return assert(cids[name],"unregistered fixture CID: "..name) end
 function api.get_name_from_content_id(cid) return names[cid] end
 local material_core={registered_nodes={}}
 function material_core.get_modpath() return nil end
 function material_core.register_on_leaveplayer() end
 function material_core.node_dig() return false end
 function material_core.handle_node_drops() end
 local env=setmetatable({core=material_core,grug_materials={}},{__index=_G})
 for _,file in ipairs({"registry.lua","mining.lua"}) do
  local chunk=assert(loadfile(repo.."/mods/ITEMS/grug_materials/"..file));setfenv(chunk,env);chunk()
 end
 local projection=dofile(repo.."/mods/MAPGEN/grug_mapgen/wp43_handoff.lua").project(env.grug_materials)
 local content=dofile(dir.."/r7_content.lua")(api,projection,sha,
  {"default:stone","grug_farming:soil","grug_farming:soil_wet"})
 return content,api,projection,sha
end

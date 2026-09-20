-- Real early definitions -> late FARM binding -> mature/wild visual comparison.
return function(repo)
 local fields={"drawtype","tiles","visual_scale","node_box","paramtype",
  "sunlight_propagates","walkable","selection_box","sounds","use_texture_alpha",
  "paramtype2","collision_box","wield_image","inventory_image"}
 local function canonical(value)
  if type(value)~="table" then return type(value)..":"..tostring(value) end
  local keys={};for k in pairs(value) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local out={"{"};for _,key in ipairs(keys) do
   out[#out+1]=canonical(key).."="..canonical(value[key])..";"
  end
  out[#out+1]="}";return table.concat(out)
 end
 local records={}
 local farm_result=dofile(repo.."/tools/r9_farm/farming_kat.lua")(repo,function(api,farming,nodes)
  local harvest=dofile(repo.."/mods/ITEMS/grug_gathering/harvest.lua")({core=api,materials={}})
  local gathering={source_can_dig=harvest.can_dig}
  dofile(repo.."/mods/MAPGEN/grug_mapgen/world_nodes.lua")(api,
   repo.."/mods/MAPGEN/grug_mapgen",nodes,gathering)
  local wild_count=0
  for _,crop in ipairs(farming.CROPS) do
   local wild=api.registered_nodes["grug_mapgen:"..crop.key.."_source"]
   if crop.key~="potato" and crop.key~="corn" then
    assert(wild and wild.drop==crop.harvest_item)
    assert(not wild.on_timer and not wild.on_construct and not wild._grug_crop)
    assert(not wild.groups.growing and not wild.groups.attached_node and not wild.groups.grug_farming_crop)
    assert(wild.buildable_to==false and wild.floodable==false)
    local mature=api.registered_nodes[crop.stages[4]]
    for _,field in ipairs(fields) do
     assert(canonical(wild[field])==canonical(mature[field]),crop.key.." wild visual differs: "..field)
    end
    wild_count=wild_count+1
   end
   for stage=1,4 do
    local def=api.registered_nodes[crop.stages[stage]]
    for _,field in ipairs(fields) do records[#records+1]=crop.key..":"..stage..":"..field.."="..canonical(def[field]) end
   end
  end
  assert(wild_count==15)
  local ember=assert(api.registered_nodes["grug_mapgen:ember_moss_source"])
  assert(ember.can_dig({},nil)==false,"missing profession authority must refuse")
  local allowed=false
  harvest.register_herb_authorizer(function(_,key,group)
   assert(key=="grug_cooking:ember_moss" and group==5)
   if allowed then return true end
   return false,"no_alchemist"
  end)
  assert(ember.can_dig({},nil)==false,"unlearned Alchemy must refuse")
  allowed=true
  assert(ember.can_dig({},nil)==true,"authorized Alchemy must allow")
  assert(api.registered_nodes["grug_mapgen:cave_cap_source"].can_dig==nil,
   "Cave Cap remains universal food")
  local first=nodes.crop_visual("salt_crust",4,{})
  local second=nodes.crop_visual("salt_crust",4,{})
  first.tiles[1].animation.length=999
  assert(second.tiles[1].animation.length==2,"visual table alias")
 end)
 table.sort(records)
 local common=dofile(repo.."/tools/wp40/r6/common.lua")
 return farm_result.."wild_visuals\t15\nshared_stage_definitions\t68\nvisual_sha256\t"..
  common.hex(common.new_sha256()(table.concat(records,"\n"))).."\n"
end

-- Eight plain hoes share one soil operation; tiers change lifetime only.
return function(callbacks)
 local uses_by_tier = {300,600,1000,1500,2000,3000}
 local hoe_tints = {
  bronze="#b97842:95", iron="#8b9298:72", steel="#c4ccd3:35",
  silversteel="#d9e0e3:70", embersteel="#a43d21:105",
  abyssal_steel="#49345f:115",
 }
 local function spend_use(stack, uses)
  local meta = stack:get_meta()
  -- Integer remainder makes every authored lifetime exact, including 192
  -- and 768 which do not divide the engine's 65535-point wear bar.
  local remainder = stack:get_wear() == 0 and 0 or meta:get_int("_grug_wear_remainder")
  local amount = 65535 + remainder
  local spent = math.floor(amount / uses)
  meta:set_int("_grug_wear_remainder", amount % uses)
  stack:set_wear(math.min(65535, stack:get_wear() + spent))
 end
 local function hoe_on_use(stack, user, pointed)
  if stack:get_wear() >= 65535 or not user or not user:is_player() or
    not pointed or pointed.type ~= "node" then return stack end
  local under, above = pointed.under, pointed.above
  if not under or not above or above.x ~= under.x or above.y ~= under.y + 1 or
    above.z ~= under.z then return stack end
  local node = core.get_node_or_nil(under)
  local def = node and core.registered_nodes[node.name]
  local groups = def and def.groups or {}
  local upper = core.get_node_or_nil(above)
  if (groups.soil or 0) < 1 or not upper or upper.name ~= "air" or
    node.name == grug_farming.SOIL_DRY or node.name == grug_farming.SOIL_WET then
   return stack
  end
  local name = user:get_player_name()
  if core.is_protected(under,name) then
   core.record_protection_violation(under,name)
   return stack
  end
  if not core.set_node(under,{name=grug_farming.SOIL_DRY}) then return stack end
  callbacks.start_soil_timer(under)
  callbacks.soil_timer(under)
  core.sound_play("default_dig_crumbly",{pos=under,gain=0.5},true)
  if not core.is_creative_enabled(name) then
   spend_use(stack,stack:get_definition()._grug_hoe_uses)
  end
  return stack
 end
 local function register(name, description, tier, uses, material, image)
  core.register_tool(name,{
   description=description.."\n"..uses.." uses",
   inventory_image=image,
   groups={hoe=1,grug_farming_hoe=1,grug_gathering_tool=1},
   _grug_tier=tier, _grug_hoe_uses=uses,
   tool_capabilities={full_punch_interval=1,damage_groups={fleshy=0},
    punch_attack_uses=0,groupcaps={}},
   on_use=hoe_on_use,
  })
  -- Both pinned VoxeLibre hoe orientations, hoes.lua:145-160.
  for side=1,2 do
   local row={"",""};row[side]="default:stick"
   core.register_craft({output=name,recipe={{material,material},row,
    {row[1],row[2]}}})
  end
 end
 register("grug_farming:hoe","Wooden Hoe",1,30,"group:wood",
  "grug_farming_woodhoe.png")
 register("grug_farming:hoe_stone","Stone Hoe",1,60,"group:stone",
  "grug_farming_steelhoe.png^[colorize:#777777:100")
 for tier=1,#grug_materials.TIERS do
  local row=grug_materials.TIERS[tier]
  register("grug_farming:hoe_"..row.key,row.name.." Hoe",tier,uses_by_tier[tier],
   row.bar_item,"grug_farming_steelhoe.png^[colorize:"..hoe_tints[row.key])
 end
end

-- Real mature crop visuals, independent wild harvest and no farming lifecycle.
return function(engine, directory, nodes, gathering)
 local catalog=dofile(directory.."/wp40/world_content_catalog.lua")
 for _,row in ipairs(catalog.plants) do
  local def=nodes.crop_visual(row.key,4,default.node_sound_leaves_defaults(),"wild")
  def.description=(row.key:gsub("_"," "):gsub("%a[%w]*",function(word)
   return word:sub(1,1):upper()..word:sub(2)
  end)).." (Wild)"
  def.drop=row.item
  def.groups={snappy=3,oddly_breakable_by_hand=3,grug_gathering_source=1}
  def.buildable_to=false
  def.floodable=false
  def.liquidtype="none"
  if row.key=="ember_moss" then
   def.groups.grug_healing_herb=5
   def.can_dig=gathering.source_can_dig({placement_class="new_p9g_source",
    harvest_kind="healing_herb",raw_item=row.item,required_group=5})
  elseif row.key=="wild_onion" or row.key=="fire_pepper" then def.groups.grug_spice=1
  elseif row.key=="sugar_cane" then def.groups.grug_sweetener=1
  elseif row.key=="salt_crust" then def.groups.grug_salt=1
  else def.groups.grug_food=1 end
 engine.register_node(row.node,def)
 end

 -- A rooted node keeps the water column intact: only the natural sand bed is
 -- replaced, while the special tile grows upward through source water.
 engine.register_node(catalog.freshwater[1], {
  description="Freshwater Waterweed",
  drawtype="plantlike_rooted",
  waving=1,
  tiles={"default_sand.png"},
  special_tiles={{name="default_kelp.png^[colorize:#4F8A52:45",tileable_vertical=true}},
  inventory_image="default_kelp.png^[colorize:#4F8A52:45",
  wield_image="default_kelp.png^[colorize:#4F8A52:45",
  paramtype="light",
  paramtype2="leveled",
  groups={crumbly=3,sand=1,not_in_creative_inventory=1},
  sounds=default.node_sound_sand_defaults(),
  selection_box={type="fixed",fixed={-0.5,-0.5,-0.5,0.5,-0.3,0.5}},
  drop="default:sand",
 })
end

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
 engine.register_node(catalog.freshwater[2], {
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

 -- The waystone (Round 29, WP17): written by the settlement writer at the
 -- centre of every waypoint pad, so it must exist before the settlement
 -- content is resolved. A standing stone one and a half nodes tall; it can
 -- never be dug or blown up. What a right-click does is grug_home's (travel).
 engine.register_node("grug_mapgen:waystone", {
  description="Waystone",
  drawtype="nodebox",
  tiles={"grug_mapgen_waystone_top.png","grug_mapgen_waystone_top.png",
   "grug_mapgen_waystone.png"},
  paramtype="light",
  light_source=4,
  node_box={type="fixed",fixed={{-0.4,-0.5,-0.4,0.4,-0.3,0.4},
   {-0.25,-0.3,-0.25,0.25,1,0.25}}},
  groups={not_in_creative_inventory=1},
  diggable=false,
  is_ground_content=false,
  drop="",
  on_blast=function() end,
  sounds=default.node_sound_stone_defaults(),
  on_rightclick=function(pos, _, clicker)
   local home=rawget(_G,"grug_home")
   if home and home.use_waystone and clicker and clicker:is_player() then
    home.use_waystone(clicker, pos)
   end
  end,
 })

 -- This occupies the air node immediately above the source-water surface;
 -- its thin box sits at the bottom of that node and never replaces water.
 engine.register_node(catalog.freshwater[1], {
  description="Freshwater Waterlily",
  drawtype="nodebox",
  paramtype="light",
  paramtype2="facedir",
  tiles={"grug_mapgen_waterlily.png","grug_mapgen_waterlily_bottom.png"},
  inventory_image="grug_mapgen_waterlily.png",
  wield_image="grug_mapgen_waterlily.png",
  use_texture_alpha="clip",
  walkable=false,
  pointable=true,
  buildable_to=true,
  floodable=true,
  groups={snappy=3,flora=1,flammable=1,not_in_creative_inventory=1},
  sounds=default.node_sound_leaves_defaults(),
  node_box={type="fixed",fixed={-0.5,-0.5,-0.5,0.5,-15/32,0.5}},
  selection_box={type="fixed",fixed={-7/16,-0.5,-7/16,7/16,-15/32,7/16}},
  drop="",
 })

 -- Dragon arena hazards (Round 31 DA2, wp40/arena_layout.lua): written by the
 -- arena writer, so they exist before the mapgen content is resolved. None
 -- can be dug or blown up (the arena is protected as well). grug_mobs deals
 -- their damage and breaks the ice (boss_dragons.lua); textures are tinted
 -- default textures.
 local layout=dofile(directory.."/wp40/arena_layout.lua")
 local arena=layout.NODES
 -- Broken ice freezes back after ICE_REFREEZE seconds (Round 36: 2 minutes);
 -- while a player still stands in it, it looks again every RECHECK seconds.
 local REFREEZE,RECHECK=layout.ICE_REFREEZE,5
 local function hazard(name, def)
  def.groups=def.groups or {}
  def.groups.not_in_creative_inventory=1
  def.groups.grug_arena_hazard=1
  def.diggable=false
  def.is_ground_content=false
  def.drop=""
  def.on_blast=function() end
  engine.register_node(name, def)
 end
 hazard(arena.thin_ice, {
  description="Thin Ice",
  drawtype="glasslike",
  tiles={"default_ice.png^[colorize:#eafcff:120^[opacity:210"},
  use_texture_alpha="blend",
  paramtype="light",
  sunlight_propagates=true,
  sounds=default.node_sound_glass_defaults(),
 })
 -- Broken ice: a node to wade in (not a liquid, so it never flows), slowed
 -- like water; it freezes back REFREEZE seconds later, once nobody stands in
 -- it.
 hazard(arena.ice_water, {
  description="Ice Water",
  drawtype="glasslike",
  tiles={"default_water.png^[colorize:#bdf2ff:110^[opacity:170"},
  use_texture_alpha="blend",
  paramtype="light",
  sunlight_propagates=true,
  walkable=false,
  pointable=false,
  buildable_to=false,
  move_resistance=3,
  liquid_move_physics=true,
  post_effect_color={a=90,r=150,g=220,b=245},
  on_construct=function(pos) engine.get_node_timer(pos):start(REFREEZE) end,
  on_timer=function(pos)
   for _,object in ipairs(engine.get_objects_inside_radius(pos,1.2)) do
    if object:is_player() then
     engine.get_node_timer(pos):start(RECHECK)
     return false
    end
   end
   engine.set_node(pos,{name=arena.thin_ice})
   return false
  end,
 })
 hazard(arena.frost_stone, {
  description="Frost Stone",
  tiles={"default_stone.png^[colorize:#a9c7e3:150"},
  sounds=default.node_sound_stone_defaults(),
 })
 -- An ember fissure: a glowing bed sunk a little below the floor that a
 -- player steps into.
 hazard(arena.ember, {
  description="Ember Fissure",
  drawtype="nodebox",
  tiles={"default_lava.png^[colorize:#ff6a10:70"},
  paramtype="light",
  light_source=9,
  walkable=false,
  pointable=false,
  node_box={type="fixed",fixed={-0.5,-0.5,-0.5,0.5,0.1,0.5}},
 })
 hazard(arena.basalt, {
  description="Basalt",
  tiles={"default_stone.png^[colorize:#2a2626:190"},
  sounds=default.node_sound_stone_defaults(),
 })
end

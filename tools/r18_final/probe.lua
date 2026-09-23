-- Isolated registration gate: no player GUI or terrain-population claim.
local meta = core.get_mod_storage()
core.register_on_mods_loaded(function()
 core.after(0,function()
 local homes = grug_home.locations()
 assert(#homes == 12, "expected exactly twelve homes")
 local seen, factions = {}, {accord=0,throng=0}
 for _,row in ipairs(homes) do
  assert(not seen[row.id] and row.pos and row.socket, "invalid home row")
  seen[row.id] = true
  factions[row.faction] = factions[row.faction] + 1
  local found = false
  for _,socket in ipairs(grug_core.settlement_sockets_at(row.id)) do
   if socket.id == row.socket then
    assert(socket.role == "innkeeper", row.id .. " missing innkeeper role")
    found = true
   end
  end
  assert(found, row.id .. " missing home socket")
 end
 assert(factions.accord == 6 and factions.throng == 6)
 local neutral, aggressive, critter = 0, 0, 0
 for name,def in pairs(core.registered_entities) do
  assert(def.initial_properties.show_on_minimap==false,
   name.." still exposes a native minimap dot")
  local kind = grug_mobs.disposition(name)
  if kind then
   assert(def._grug_disposition == kind, name .. " lost disposition prototype")
   if kind == "neutral" then
    neutral=neutral+1
    assert(def.attack_players == false and def.passive == false, name)
   elseif kind == "critter" then critter=critter+1
   else aggressive=aggressive+1 end
  end
 end
 assert(neutral >= 12 and aggressive >= 40 and critter >= 10)
 assert(math.abs(grug_mobs.scale_attack_damage(10)-15)<0.0001)
 -- Real authority + final registered species, no terrain generation required.
 -- Sample each culture toward the front across the three starting bands.
 local surfaces={}
 local catalog=dofile(core.get_modpath("grug_mapgen").."/wp40/r7_r6_manifest.lua")()
 for _,row in ipairs(catalog.surfaces) do surfaces[row.id]=row.top end
 local roles=assert(grug_mobs._r18_roles,"missing scratch registration capture")
 local spawn_rows={}
 for _,row in ipairs(core.registered_abms) do
  local name=(row.label or ""):match("^(grug_mobs:[%w_]+) spawning$")
  if name then
   spawn_rows[name]=spawn_rows[name] or {}
   spawn_rows[name][#spawn_rows[name]+1]=row
  end
 end
 local function hosted(name,host,pos)
  for _,row in ipairs(spawn_rows[name] or {}) do
   if pos.y>=(row.min_y or -31000) and pos.y<=(row.max_y or 31000) then
    for _,node in ipairs(row.nodenames) do
     if node==host or (node:sub(1,6)=="group:" and
       core.get_item_group(host,node:sub(7))>0) then return true end
    end
   end
  end
  return false
 end
 local old_time = core.get_timeofday()
 local band_limits = {{151,1,3},{300,4,6},{500,7,10}}
 local policy_samples = 0
 for _,start in ipairs(grug_core.start_identities()) do
  local direction = start.faction_id == "accord" and 1 or -1
  local race_counts={0,0}
  for _,band in ipairs(band_limits) do
   local pos = {x=start.anchor.x,y=20,z=start.anchor.z+direction*band[1]}
   local level = grug_zones.mob_level_at(pos)
   assert(level and level>=band[2] and level<=band[3],
    start.race_id.." unexpected actual starting band at "..band[1]..": "..tostring(level))
   local biome=grug_zones.biome_at(pos.x,pos.z)
   local host=assert(surfaces[biome],"missing real surface "..tostring(biome))
   pos.y=grug_zones.terrain_height_at(pos.x,pos.z)
   local counts = {}
   for clock_index,clock in ipairs({0.5,0}) do
    core.set_timeofday(clock)
    assert(math.abs(core.get_timeofday()-clock)<0.001,"native clock did not change")
    local allowed = 0
    for name,def in pairs(roles) do
     if name~="grug_mobs:kraken" and def.type~="npc" and
       def._grug_tier~="boss" and def._grug_tier~="rare" and
       def._grug_tier~="critter" and hosted(name,host,pos) and
       not mobs:spawn_abm_check(pos,{name=host},name) then
      assert((def._grug_min_level or 1)<=level,name.." exceeds actual local level")
      allowed=allowed+1
     end
    end
    counts[#counts+1]=allowed
    race_counts[clock_index]=race_counts[clock_index]+allowed
   end
   core.log("action",("[r18_population] %s distance=%d zone=%s level=%d host=%s day=%d night=%d"):
    format(start.race_id,band[1],tostring(grug_zones.id_at(pos.x,pos.z)),level,host,counts[1],counts[2]))
   policy_samples=policy_samples+1
  end
  assert(race_counts[1]>0 and race_counts[2]>0,start.race_id.." has empty sampled combat roster")
 end
 core.set_timeofday(old_time)
 assert(policy_samples==18)
 grug_quests.validate_registry()
 -- Active skill identities remain registered while their visual layer changes.
 local abilities = 0
 for id, definition in pairs(grug_abilities.registered) do
  assert(definition.id == id, "ability registry identity drift")
  assert(type(definition.name) == "string" and definition.name ~= "")
  local item=assert(core.registered_items["grug_abilities:"..id])
  assert(item.inventory_image=="grug_abilities_skill_"..id..".png",
   id.." lacks its semantic action icon")
  abilities = abilities + 1
 end
 assert(abilities >= 22, "active ability registry unexpectedly shrank")
 local p={get_player_name=function()return "r18_probe"end,
  get_meta=function()return meta end,
  get_pos=function()return {x=0,y=20,z=-2000}end,
  get_look_horizontal=function()return 0 end,is_player=function()return true end}
 local markers=grug_map.atlas.collect_markers(p)
 local count=0
 for _,row in ipairs(markers) do
  if row.kind == "home" or row.kind == "innkeeper" then count=count+1 end
 end
 assert(count==12,"expected twelve atlas innkeeper markers, got "..count)
 core.log("action",("[r18_integration] PASS homes=%d neutral=%d aggressive=%d critter=%d markers=%d"):
  format(#homes,neutral,aggressive,critter,count))
 core.after(0,function()core.request_shutdown("Round 18 registration complete",false,0)end)
 end)
end)

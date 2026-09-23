-- Isolated registration gate: no player GUI or terrain-population claim.
local meta = core.get_mod_storage()
core.register_on_mods_loaded(function()
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
 local old_time = core.get_timeofday()
 local band_limits = {{151,1,3},{300,4,6},{500,7,10}}
 local policy_samples = 0
 for _,start in ipairs(grug_core.start_identities()) do
  local direction = start.faction_id == "accord" and 1 or -1
  for _,band in ipairs(band_limits) do
   local pos = {x=start.anchor.x,y=20,z=start.anchor.z+direction*band[1]}
   local level = grug_zones.mob_level_at(pos)
   assert(level and level>=band[2] and level<=band[3],
    start.race_id.." unexpected actual starting band at "..band[1])
   local counts = {}
   for _,clock in ipairs({0.5,0}) do
    core.set_timeofday(clock)
    local allowed = 0
    for name,def in pairs(core.registered_entities) do
     if name~="grug_mobs:kraken" and def._grug_min_level and
       def.type~="npc" and def._grug_tier~="boss" and def._grug_tier~="rare" and
       grug_mobs.spawn_policy_allows(name,pos) then
      assert(def._grug_min_level<=level,name.." exceeds actual local level")
      allowed=allowed+1
     end
    end
    assert(allowed>0,start.race_id.." empty policy roster")
    counts[#counts+1]=allowed
   end
   core.log("action",("[r18_population] %s distance=%d zone=%s level=%d day=%d night=%d"):
    format(start.race_id,band[1],tostring(grug_zones.id_at(pos.x,pos.z)),level,counts[1],counts[2]))
   policy_samples=policy_samples+1
  end
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

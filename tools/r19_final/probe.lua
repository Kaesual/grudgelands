-- Registration boundary only; no terrain requests, fake PlayerRefs or GUI claim.
core.register_on_mods_loaded(function()
 core.after(0, function()
  local expected = {["grug_mobs:ice_dragon"] = 5,
   ["grug_mobs:jungle_wyvern"] = 4}
  local count = 0
  for name, anchor in pairs(expected) do
   local entity = assert(core.registered_entities[name], name)
   local profile = assert(entity._grug_hp_bar_presentation, name .. " lost profile at registration")
   assert(profile.anchor_y == anchor and profile.width == 3 and profile.height > 0.1,
    name .. " incorrect presentation")
   count = count + 1
  end
  assert(count == 2)
  assert(not core.registered_entities["grug_mobs:boar"]._grug_hp_bar_presentation)
  local a = grug_core.hud_layout.anchors.status_list
  assert(a.position.x == 0.5 and a.position.y == 0 and a.alignment.x == 0)
  assert(#grug_map.atlas.views() == 1 and grug_map.atlas.view().texture == "grug_map_atlas_world.png")
  assert(sfinv.pages["grug_map:atlas"] and sfinv.pages["grug_skills:skills"])
  core.log("action", "[r19_integration] PASS dragon_profiles=2 ordinary=unchanged status=top_center atlas=world_only")
  core.request_shutdown("Round 19 isolated registration gate passed", false, 0)
 end)
end)

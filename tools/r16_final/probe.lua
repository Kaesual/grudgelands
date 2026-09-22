-- Registration/integration smoke gate in an isolated native game snapshot.
-- No client interaction or terrain coverage is claimed by this probe.
core.register_on_mods_loaded(function()
 local armor, foods = 0, 0
 local labels = {[1] = "Cloth", [2] = "Leather", [3] = "Metal"}
 for name, def in pairs(core.registered_items) do
  local groups = def.groups or {}
  if labels[groups.grug_armor_class] then
   local label = labels[groups.grug_armor_class]
   assert(def.description:find(label, 1, true), name .. " missing armor type")
   local rebuilt = grug_gear.describe_stack_base(ItemStack(name), def._grug_ilvl)
   assert(table.concat(rebuilt, "\n"):find(label, 1, true), name .. " loses armor type")
   armor = armor + 1
  end
  if (groups.grug_food or 0) > 0 then
   assert(def.description:find("Cannot eat in combat.", 1, true), name)
   foods = foods + 1
  end
 end
 assert(armor >= 72 and foods > 20)
 grug_quests.validate_registry()
 -- Empty persistent state is sufficient for static authored service markers.
 local meta = core.get_mod_storage()
 local p = {
  get_player_name = function() return "round16_native_probe" end,
  get_meta = function() return meta end,
  get_pos = function() return {x = 0, y = 20, z = -2000} end,
  get_look_horizontal = function() return 0 end,
  is_player = function() return true end,
 }
 local markers = grug_map.atlas.collect_markers(p)
 local service, bosses, self = 0, 0, 0
 for _, row in ipairs(markers) do
  assert(row.detail == row.label, "marker tooltip must be names only")
  if row.kind == "trainer" then service = service + 1 end
  if row.kind == "boss" then bosses = bosses + 1 end
  if row.kind == "player" then self = self + 1 end
 end
 assert(service >= 54 and bosses == 8 and self == 1)
 core.log("action", ("[r16_integration] PASS armor=%d food=%d trainers=%d bosses=%d self=%d"):
  format(armor, foods, service, bosses, self))
 core.after(0, function() core.request_shutdown("Round 16 integration complete", false, 0) end)
end)

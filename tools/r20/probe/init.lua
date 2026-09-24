-- One isolated final registration smoke, not a GUI or networked-player test.
local probe_path = core.get_modpath(core.get_current_modname())
core.register_on_mods_loaded(function()
 core.after(0, function()
  assert(type(grug_abilities.input.step) == "function")
  assert(type(grug_abilities.resolve_friendly_target) == "function")
  assert(type(grug_abilities.start_bow_draw) == "function")
  assert(type(grug_abilities.cancel_bow_draw) == "function")
  assert(type(grug_food.consume_held) == "function")
  local skill_count, food_count = 0, 0
  for name, definition in pairs(core.registered_items) do
   if core.get_item_group(name, "grug_ability") > 0 then
    assert(not definition.on_use, name .. " suppresses native digging")
    assert(definition.range == 4, name .. " lost hand interaction range")
    assert(type(definition.on_place) == "function", name .. " missing node interaction")
    skill_count = skill_count + 1
   end
   if core.get_item_group(name, "grug_food") > 0 then
    assert(not definition.on_use, name .. " still consumes with LMB")
    assert(type(definition.on_place) == "function", name .. " missing food interaction")
    food_count = food_count + 1
   end
  end
  assert(skill_count >= 16 and food_count >= 12, "catalog registration incomplete")
  assert(grug_abilities.registered.loose.description:find("RMB", 1, true))
  assert(grug_abilities.registered.blink.repeat_policy == "once")
  assert(grug_abilities.registered.sprint.repeat_policy == "once")
  local hand = ItemStack(""):get_tool_capabilities()
  assert(hand.groupcaps.dig_immediate.times[2] > 0)
  for name, definition in pairs(core.registered_nodes) do
   assert((definition.groups or {}).dig_immediate ~= 3, name .. " still instant harvest")
  end
  -- The launch script stages the source-owned catalog fixture into this probe.
  local catalog = dofile(probe_path .. "/content_server.lua")
  local receipt = catalog()
  core.log("action", "[r20_integration] " .. tostring(receipt))
  core.log("action", "[r20_integration] PASS skills=" .. skill_count ..
   " food=" .. food_count .. " native-dig+RMB+catalog")
  core.request_shutdown("Round 20 isolated registration gate passed", false, 0)
 end)
end)

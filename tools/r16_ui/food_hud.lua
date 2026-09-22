-- Bounded real food/status/HUD consumers, callable by the final portable runner.
return function(root)
 local env = setmetatable({}, {__index = _G})
 local clock, notices = 0, 0
 local steps, connected, leaves, items = {}, {}, {}, {}
 local function noop() end
 for _, id in ipairs({"default:apple", "default:blueberries", "mobs:meat_raw",
  "mobs:meat", "mobs:meatblock_raw", "mobs:meatblock", "grug_mobs:raw_fish",
  "grug_fishing:silver_trout", "grug_fishing:mire_carp", "grug_fishing:frostfin",
  "grug_fishing:ember_eel", "grug_fishing:storm_tuna", "grug_fishing:cooked_fish"}) do
  items[id] = {description = id, groups = {}}
 end
 env.core = {
  registered_items = items,
  get_us_time = function() return clock * 1000000 end,
  get_connected_players = function() return connected end,
  get_player_by_name = function(name)
   for _, p in ipairs(connected) do if p.name == name then return p end end
  end,
  register_on_joinplayer = noop, register_on_dieplayer = noop,
  register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
  register_globalstep = function(fn) steps[#steps + 1] = fn end,
  chat_send_player = noop,
  override_item = function(name, fields)
   for key, value in pairs(fields) do items[name][key] = value end
  end,
 }
 env.grug_gathering = {p9g_sources = function() return {} end}
 env.grug_core = {
  in_combat = function(p) return p.combat end,
  can_use_item_level = function() return true end,
 }
 env.grug_classes = {get_max_hp = function() return 10000 end,
  get_max_mana = function() return 10000 end}
 env.grug_abilities = {
  restore_mana = function(p, n) p.mana = p.mana + n; return n end,
  notify = function() notices = notices + 1 end,
 }
 local function load(path) return setfenv(assert(loadfile(root .. "/" .. path)), env)() end
 load("mods/CORE/grug_core/status.lua")
 load("mods/ITEMS/grug_food/init.lua")
 local p = {name = "food", hp = 1, mana = 0, combat = false}
 function p:is_player() return true end
 function p:get_player_name() return self.name end
 function p:get_hp() return self.hp end
 function p:set_hp(value) self.hp = value end
 connected[1] = p
 local function advance(n)
  for _ = 1, n do
   clock = clock + 1
   for _, fn in ipairs(steps) do fn(1) end
  end
 end
 local instant, percent = {5,15,40,90,180,300}, {4,5,6,7,8,10}
 local count = 0
 for tier = 1, 6 do
  for _, role in ipairs({"hp", "hearty", "caster", "hunter"}) do
   local id = "fixture:food_" .. tier .. "_" .. role
   items[id] = {description = id, groups = {}}
   assert(env.grug_food.register_item(id, tier, role == "hp" and "raw" or "dish", role))
   assert(items[id].description:find("every 5 s for 5 min.", 1, true))
   assert(items[id].description:find("Cannot eat in combat.", 1, true))
   local stack = {count = 2, get_name = function() return id end,
    take_item = function(self, n) self.count = self.count - n end}
   p.hp, p.mana, p.combat = 1, 0, false
   local started = clock
   items[id].on_use(stack, p)
   local status = assert(env.grug_core.get_status(p, "food"))
   assert(stack.count == 1 and status.expiry_us == (started + 300) * 1000000)
   assert(p.hp == 1 + instant[tier] and p.mana == 0)
   p.combat = true
   items[id].on_use(stack, p)
   assert(stack.count == 1 and env.grug_core.get_status(p, "food") == status)
   advance(5)
   assert(p.hp == 1 + instant[tier] and p.mana == 0)
   p.combat = false
   advance(5)
   local amount = role == "hp" and 200 or percent[tier] * 100
   assert(p.hp == 1 + instant[tier] + amount)
   assert(p.mana == (role == "caster" and amount or 0))
   assert(#env.grug_core.each_status(p) == 1)
   count = count + 1
  end
 end
 assert(notices == 24)
 p.combat = true
 local before = p.hp
 advance(290)
 assert(not env.grug_core.get_status(p, "food"))
 p.combat = false
 advance(5)
 assert(p.hp == before) -- No deferred instant heal or expired food tick.
 -- Isolate HUD consumers from the status HUD, while retaining real combat state.
 steps, leaves = {}, {}
 local added, removed = 0, 0
 function p:hud_add(def)
  added = added + 1
  assert(def.text == "Combat" and def.alignment.x == 1)
  assert(def.offset.x > 90)
  return added
 end
 function p:hud_remove() removed = removed + 1 end
 load("mods/CORE/grug_core/hud_layout.lua")
 load("mods/CORE/grug_core/combat_hud.lua")
 advance(1); assert(added == 0)
 p.combat = true
 advance(1); advance(3); assert(added == 1 and removed == 0)
 p.combat = false
 advance(1); assert(removed == 1)
 p.combat = true
 advance(1); p.hp = 0; advance(1)
 assert(added == 2 and removed == 2)
 for _, fn in ipairs(leaves) do fn(p) end
 p.hp = 10
 advance(1); assert(added == 3)
 return "food-hud:24-routes:combat-refusal:double-regen:expiry:hud-lifecycle:ok"
end

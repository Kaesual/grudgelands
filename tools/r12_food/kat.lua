-- Focused current food/status integration: real status clock, all tier/role routes.
local root = arg[1] or "."
local clock = 0
local steps, connected = {}, {}
local items = {}
for _, id in ipairs({"default:apple", "default:blueberries", "mobs:meat_raw",
 "mobs:meat", "mobs:meatblock_raw", "mobs:meatblock", "grug_mobs:raw_fish",
 "grug_fishing:silver_trout", "grug_fishing:mire_carp", "grug_fishing:frostfin",
 "grug_fishing:ember_eel", "grug_fishing:storm_tuna", "grug_fishing:cooked_fish"}) do
 items[id] = {description = id, groups = {}}
end
grug_gathering = {p9g_sources = function() return {} end}
local function noop() end
core = {
 registered_items = items,
 get_us_time = function() return clock * 1000000 end,
 get_connected_players = function() return connected end,
 get_player_by_name = function(name)
  for _, p in ipairs(connected) do if p.name == name then return p end end
 end,
 register_on_joinplayer = noop, register_on_leaveplayer = noop,
 register_on_dieplayer = noop,
 register_globalstep = function(fn) steps[#steps + 1] = fn end,
 chat_send_player = noop,
 override_item = function(name, fields)
  for key, value in pairs(fields) do items[name][key] = value end
 end,
}
grug_core = {
 in_combat = function(p) return p.combat end,
 can_use_item_level = function() return true end,
}
grug_classes = {
 get_max_hp = function() return 10000 end,
 get_max_mana = function() return 10000 end,
}
grug_abilities = {restore_mana = function(p, n) p.mana = p.mana + n; return n end}
dofile(root .. "/mods/CORE/grug_core/status.lua")
dofile(root .. "/mods/ITEMS/grug_food/init.lua")
local p = {name = "food", hp = 1, mana = 0, combat = true}
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
local count = 0
for tier = 1, 6 do
 for _, role in ipairs({"hp", "hearty", "caster", "hunter"}) do
  local kind = role == "hp" and "raw" or "dish"
  local id = "fixture:food_" .. tier .. "_" .. role
  items[id] = {description = id, groups = {}}
  assert(grug_food.register_item(id, tier, kind, role))
  assert(items[id].description:find("every 5 s for 5 min.", 1, true))
  local stack = {count = 1, get_name = function() return id end,
   take_item = function(self, n) self.count = self.count - n end}
  local started = clock
  items[id].on_use(stack, p)
  local status = assert(grug_core.get_status(p, "food"))
  assert(stack.count == 0 and status.expiry_us == (started + 300) * 1000000)
  assert(status.interval == 5 and #grug_core.each_status(p) == 1)
  count = count + 1
 end
end
assert(p.hp == 1 and p.mana == 0)
advance(181)
assert(grug_core.get_status(p, "food") and p.hp == 1)
advance(118)
assert(grug_core.get_status(p, "food"))
advance(1)
assert(not grug_core.get_status(p, "food"))
-- Deferred instant survives expiry, pays once, and uses the last serving only.
p.combat = false
advance(1)
assert(p.hp == 301 and p.mana == 0)
advance(5)
assert(p.hp == 301)
io.write("R12 FOOD PASS routes=", count,
 " duration=300 tick=5 old-expiry=active final-expiry=cleared deferred=once replacement=latest tooltips=5min\n")

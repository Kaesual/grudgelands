-- Called at the end of gear_micro inside the final portable fixture environment.
return function(repo, check)
 local allow
 core.register_allow_player_inventory_action = function(fn) allow = fn end
 core.register_globalstep = function() end
 core.register_on_mods_loaded = function() end
 core.chat_send_player = function() end
 core.colorize = function(_, text) return text end
 core.is_creative_enabled = function() return false end
 core.get_mod_storage = function() return {get_string=function() return "" end,
  set_string=function() end} end
 grug_core.mono_time = function() return 0 end
 grug_inventory.BAG_COUNT = 0
 grug_classes.get_armor_rank = function() return 3 end
 grug_core.register_on_settled_outgoing_action = function() end
 grug_core.register_on_settled_incoming_hit = function() end
 local notified = 0
 grug_core.notify_equipment_change = function(player)
  notified = notified + 1
  local stack = player:get_inventory():get_stack("grug_weapon", 1)
  local combat = grug_inventory.get_equipped_weapon(player)
  check((combat == nil) == (stack:get_wear() == 65535), "cache cleared before notification")
 end
 dofile(repo .. "/mods/PLAYER/grug_inventory/equipment.lua")
 dofile(repo .. "/mods/ITEMS/grug_repair/runtime.lua")
 local lists = {}
 local inv = {}
 function inv:get_stack(list, index) return ItemStack((lists[list] or {})[index] or "") end
 function inv:set_stack(list, index, stack)
  lists[list] = lists[list] or {}; lists[list][index] = ItemStack(stack)
 end
 function inv:get_list(list)
  local out = {}; for i, stack in ipairs(lists[list] or {}) do out[i] = ItemStack(stack) end
  return out
 end
 local player = {class="warrior", level=60}
 function player:is_player() return true end
 function player:get_player_name() return "gear_boundary" end
 function player:get_hp() return 100 end
 function player:get_inventory() return inv end
 local permitted = {warrior={sword=true,dagger=true,greataxe=true},
  scout={bow=true,sword=true,dagger=true},mage={staff=true,wand=true,dagger=true},
  priest={staff=true,wand=true,dagger=true}}
 for _, class in ipairs({"warrior", "scout", "mage", "priest"}) do
  player.class = class
  for _, family in ipairs({"sword", "dagger", "greataxe", "bow", "staff", "wand"}) do
   local stack = ItemStack(grug_gear.weapon_item(family, 1))
   check(allow(player, "put", inv, {listname="grug_weapon", stack=stack}) ==
    (permitted[class][family] and 1 or 0), "real equipment allow/refusal " .. class .. family)
  end
 end
 player.class = "warrior"
 local stack = ItemStack(grug_gear.weapon_item("sword", 1))
 inv:set_stack("grug_weapon", 1, stack)
 grug_inventory.equipment_changed(player)
 check(grug_inventory.get_equipped_weapon(player), "intact combat getter")
 local max = grug_repair.maximum_durability(stack)
 grug_repair.wear_outgoing(player, "boundary:first")
 local first = inv:get_stack("grug_weapon", 1)
 check(grug_repair.durability(first) == max - 1 and notified == 2, "real first wear event")
 check(not grug_repair.wear_outgoing(player, "boundary:first") and notified == 2,
  "duplicate accepted action does not wear twice")
 local amount = (max - 1) * 65535
 first:set_wear(math.floor(amount / max))
 first:get_meta():set_int("_grug_wear_remainder", amount % max)
 inv:set_stack("grug_weapon", 1, first)
 grug_inventory.equipment_changed(player)
 grug_repair.wear_outgoing(player, "boundary:last")
 check(grug_inventory.get_equipped_weapon(player) == nil, "broken combat getter")
 local cosmetic = grug_inventory.get_cosmetic_weapon(player)
 check(cosmetic and cosmetic:get_wear() == 65535 and
  cosmetic:get_meta():get_string("inventory_image"):find("cracko", 1, true), "broken cosmetic getter")
 cosmetic:set_wear(0)
 check(grug_inventory.get_cosmetic_weapon(player):get_wear() == 65535, "cosmetic result is owned copy")
 local funds = 100000
 grug_money = {format=tostring, take_with_inventory=function(_, price, changes)
  check(price > 0 and funds >= price, "repair charge")
  for _, row in ipairs(changes) do
   local old = inv:get_stack(row.list, row.index)
   check(old:get_name() == row.expected:get_name() and old:get_wear() == row.expected:get_wear(),
    "repair transaction expected stack")
   inv:set_stack(row.list, row.index, row.replacement)
  end
  funds = funds - price
  return true
 end}
 grug_repair.register_provider("boundary", function() return true end)
 local quote = assert(grug_repair.quote(player, {kind="boundary"}, "grug_weapon", 1))
 local before = notified
 check(grug_repair.apply(player, quote) and notified == before + 1, "real repair invalidates cache")
 check(not grug_repair.apply(player, quote), "repair quote single use")
 local restored = assert(grug_inventory.get_equipped_weapon(player))
 check(restored:get_wear() == 0 and grug_repair.durability(restored) == max and
  restored:get_meta():get_int("_grug_wear_remainder") == 0, "repair restores exact durability")
 check(not grug_inventory.get_cosmetic_weapon(player):get_meta():get_string("inventory_image"):find("cracko", 1, true),
  "repair removes cosmetic crack")
end

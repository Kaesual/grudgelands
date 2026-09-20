local root = arg[1] or "."
local function stack(name) return {get_name = function() return name end} end
local store, callbacks, afters = {}, {}, {}
local lists = {main = {}, craft = {}, craftpreview = {}, grug_bag1_content = {},
	grug_quiver_content = {}, grug_weapon = {}}
local meta = {get_string = function(_, k) return store[k] or "" end,
	set_string = function(_, k, v) store[k] = v end}
local inv = {get_lists = function() return lists end}
local player = {get_player_name = function() return "recipe_tester" end,
	get_meta = function() return meta end, get_inventory = function() return inv end}
core = {
	registered_items = { ["test:oak"] = {groups = {wood = 1}},
		["test:stone"] = {groups = {stone = 1}} },
	serialize = function(t) return table.concat(t, ",") end,
	deserialize = function(v) local t = {}; for s in v:gmatch("[^,]+") do t[#t+1] = s end; return t end,
	get_item_group = function(name, group) return (core.registered_items[name].groups or {})[group] or 0 end,
	register_on_player_inventory_action = function(fn) callbacks.action = fn end,
	register_globalstep = function(fn) callbacks.step = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave = fn end,
	after = function(_, fn, name) afters[#afters+1] = {fn,name} end,
	get_player_by_name = function() return player end,
	get_connected_players = function() return {player} end,
}
grug_jobs = {_item_name = function(v) return type(v) == "string" and v or v:get_name() end}
dofile(root .. "/mods/PLAYER/grug_jobs/discovery.lua")
local starter = {profession="general", basics_presentation={starter=true}}
local exact = {profession="general", basics_presentation={main_material="test:stone"}}
local grouped = {profession="general", basics_presentation={main_material="group:wood"}}
assert(grug_jobs.recipe_discovered(player, starter))
assert(not grug_jobs.recipe_discovered(player, exact))
lists.craftpreview = {stack("test:stone")}; grug_jobs._scan_discovery(player)
assert(not grug_jobs.recipe_discovered(player, exact), "craft preview leaked discovery")
lists.grug_bag1_content = {stack("test:oak")}; grug_jobs._scan_discovery(player)
assert(grug_jobs.recipe_discovered(player, grouped), "bag/group acquisition missed")
lists.craft = {stack("test:stone")}; grug_jobs._scan_discovery(player)
assert(grug_jobs.recipe_discovered(player, exact), "craft acquisition missed")
assert(store[grug_jobs.DISCOVERY_META_KEY]:find("test:oak",1,true) and store[grug_jobs.DISCOVERY_META_KEY]:find("test:stone",1,true))
callbacks.leave(player); lists.craft = {}; lists.grug_bag1_content = {}
assert(grug_jobs.recipe_discovered(player, exact) and grug_jobs.recipe_discovered(player, grouped), "persisted discovery lost")
print("R12 RECIPES discovery PASS bag+craft+group+persistence preview-excluded")

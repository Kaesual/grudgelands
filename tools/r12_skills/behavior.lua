-- Real ability, mount-state, destination-policy and Skills-page callbacks.
local root = arg[1] or "."
arg[2] = "skills-fixture"
local fixture = dofile(root .. "/tools/wp39/combat_integration_test.lua")
arg[2] = nil
local player = fixture.new_player("skills_probe", "warrior", "accord")
local inv = player:get_inventory()
local meta_values = {}
local meta = {get_int = function(_, k) return tonumber(meta_values[k]) or 0 end,
	set_int = function(_, k, v) meta_values[k] = v end,
	get_string = function(_, k) return tostring(meta_values[k] or "") end,
	set_string = function(_, k, v) meta_values[k] = v end}
function player:get_meta() return meta end
local inventory_type = getmetatable(inv)
inv.owner_name = player:get_player_name()
function inventory_type:get_location()
	return {type = "player", name = self.owner_name}
end
function inventory_type:set_size(name, count)
	self[name] = self[name] or {}
	for i = 1, count do self[name][i] = self[name][i] or ItemStack("") end
	for i = #self[name], count + 1, -1 do self[name][i] = nil end
end
function inventory_type:room_for_item(name)
	for _, stack in ipairs(self[name] or {}) do if stack:is_empty() then return true end end
	return false
end
local stack_type = getmetatable(ItemStack(""))
function stack_type:get_count() return self:is_empty() and 0 or 1 end
for _, callback in ipairs(fixture.class_callbacks) do callback(player, "warrior") end
assert(inv:contains_item("main", "grug_abilities:strike"))
inv:set_size("grug_bag1_content", 8)
inv:set_size("grug_weapon", 1)
inv:set_size("craft", 9)
local function remove_all(name)
	for listname, list in pairs(inv:get_lists()) do
		for index, stack in ipairs(list) do
			if stack:get_name() == name then inv:set_stack(listname, index, ItemStack("")) end
		end
	end
end
remove_all("grug_abilities:strike")
grug_abilities.normalize_kit(player)
assert(not inv:contains_item("main", "grug_abilities:strike"), "normalize regranted deleted skill")
inv:set_stack("grug_bag1_content", 1, grug_abilities.stack_for(player, "strike"))
inv:set_stack("grug_weapon", 1, ItemStack("grug_abilities:strike"))
grug_abilities.normalize_kit(player)
assert(inv:get_stack("grug_weapon", 1):is_empty() and player.equipment_notices == 1)
assert(inv:contains_item("grug_bag1_content", "grug_abilities:strike"))
local charge = grug_abilities.registered.charge
grug_abilities.arm_cooldown(player, charge, 10)
fixture.set_time(2000000)
local cooldown_stack = grug_abilities.stack_for(player, "charge")
assert(cooldown_stack:get_wear() > 0 and not grug_abilities.ready(player, "charge"))
remove_all("grug_abilities:charge")
inv:set_stack("grug_bag1_content", 2, cooldown_stack)
grug_abilities.normalize_kit(player)
assert(inv:get_stack("grug_bag1_content", 2):get_wear() == cooldown_stack:get_wear())
assert(not grug_abilities.ready(player, "charge"), "recovery reset cooldown")
assert(core.registered_items["grug_abilities:strike"].on_drop(ItemStack("grug_abilities:strike"), player):is_empty())

local talent_callbacks, notices, allow_action, on_action = {}, {}, nil, nil
local destination_puts = 0
core.chat_send_player = function(_, text) notices[#notices + 1] = text end
core.register_allow_player_inventory_action = function(fn) allow_action = fn end
core.register_on_player_inventory_action = function(fn) on_action = fn end
core.register_on_player_inventory_action(function(_, action)
	if action == "put" then destination_puts = destination_puts + 1 end
end)
core.register_craftitem = function(name, def) core.registered_items[name] = def end
core.formspec_escape = function(s) return s end
core.registered_nodes = {['test:chest'] = {allow_metadata_inventory_put = function() return -1 end}}
core.override_item = function(name, fields)
	for k, v in pairs(fields) do core.registered_nodes[name][k] = v end
end
core.detached_inventories = {}
local detached = {}
core.create_detached_inventory = function(name, callbacks)
	core.detached_inventories[name] = callbacks
	detached[name] = setmetatable({writes = 0}, inventory_type)
	return detached[name]
end
core.remove_detached_inventory = function() end
core.after = function(_, fn, ...) fn(...) end
core.get_item_group = function(name, group)
	return ((core.registered_items[name] or {}).groups or {})[group] or 0
end
sfinv = {pages = {}, pages_unordered = {}, register_page = function(name, def) sfinv.pages[name] = def end,
	make_formspec = function(_, _, content) return content end}
grug_classes.register_on_talents_changed = function(fn) talent_callbacks[#talent_callbacks + 1] = fn end
grug_classes.register_on_race_chosen = function() end
grug_factions.register_on_faction_chosen = function() end
grug_classes.registered_talents = {}
grug_xp.get_level = function() return 60 end
grug_money = {take = function() return true end}
grug_mounts = {TIERS = {}, model_for = function() return {description = "Probe", icon = "probe.png"} end,
	price_for_tier = function() return 1 end}
for i, speed in ipairs({6.4, 8, 8, 12}) do
	grug_mounts.TIERS[i] = {item = "grug_mounts:t" .. i, name = "T" .. i,
		mode = i < 3 and "land" or "flight", speed = speed, level = 1}
end
dofile(root .. "/mods/PLAYER/grug_mounts/state.lua")
dofile(root .. "/mods/PLAYER/grug_mounts/items.lua")
for i = 1, 4 do assert(grug_mounts.purchase(player, i)) end
assert(#grug_mounts.owned_tier_ids(player) == 4)
for i = 1, 4 do assert(not inv:contains_item("main", "grug_mounts:t" .. i)) end
inv:set_stack("grug_weapon", 1, grug_mounts.stack_for(player, 1))
grug_mounts.reconcile_items(player)
assert(inv:get_stack("grug_weapon", 1):is_empty() and player.equipment_notices == 2)
assert(grug_mounts.stack_for(player, 1):get_meta():get_string("description"):find("6.4", 1, true))

grug_skills = {}
dofile(root .. "/mods/PLAYER/grug_skills/bound_items.lua")
dofile(root .. "/mods/PLAYER/grug_skills/page.lua")
-- Only the new page join callback creates the catalog.
fixture.callbacks.join[#fixture.callbacks.join](player)
local catalog_name = "grug_skills_" .. player:get_player_name()
local catalog = detached[catalog_name]
local callbacks = core.detached_inventories[catalog_name]
local function index_of(name)
	for i, stack in ipairs(catalog:get_list("catalog")) do
		if stack:get_name() == name then return i end
	end
	error("missing catalog " .. name)
end
local strike_index = index_of("grug_abilities:strike")
local strike = catalog:get_stack("catalog", strike_index)
assert(callbacks.allow_take(catalog, "catalog", strike_index, strike, player) == 0, "bag duplicate accepted")
remove_all(strike:get_name())
-- Luanti creates a fresh InvRef userdata for the destination-side player
-- callback. Reproduce the complete cross-inventory transaction: detached
-- infinite source allow_take, distinct destination wrapper allow_put, move,
-- then source on_take and destination on_put. The catalog source remains.
local destination_ref = setmetatable({owner_name = player:get_player_name()}, {
	__index = function(_, key) return inv[key] or inventory_type[key] end,
})
local callback_order = {}
local destination_allow = allow_action(player, "put", destination_ref,
	{listname = "main", index = 1, stack = strike})
callback_order[#callback_order + 1] = "destination_allow_put"
assert(destination_allow == nil, "player-owned destination wrapper rejected")
local source_allow = callbacks.allow_take(catalog, "catalog", strike_index, strike, player)
callback_order[#callback_order + 1] = "source_allow_take"
assert(source_allow == -1, "catalog source is not infinite")
catalog:set_stack("catalog", strike_index, ItemStack(""))
inv:set_stack("main", 1, strike)
if source_allow == -1 then
	catalog:set_stack("catalog", strike_index, strike)
end
callbacks.on_take(catalog, "catalog", strike_index, strike, player)
callback_order[#callback_order + 1] = "source_on_take"
on_action(player, "put", destination_ref,
	{listname = "main", index = 1, stack = strike})
callback_order[#callback_order + 1] = "destination_on_put"
assert(destination_puts == 1, "destination on_put notification was not delivered")
assert(table.concat(callback_order, ",") ==
	"destination_allow_put,source_allow_take,source_on_take,destination_on_put",
	"cross-inventory callback order diverged from IMoveAction")
assert(inv:get_stack("main", 1):get_name() == "grug_abilities:strike",
	"catalog recovery transaction did not reach main")
assert(catalog:get_stack("catalog", strike_index):get_name() == "grug_abilities:strike",
	"infinite catalog source was consumed")
remove_all(strike:get_name())
local foreign_ref = setmetatable({owner_name = "other"}, {
	__index = function(_, key) return inv[key] or inventory_type[key] end,
})
assert(allow_action(player, "put", foreign_ref,
	{listname = "main", index = 1, stack = strike}) == 0,
	"another player's inventory accepted a bound skill")
local mount_index = index_of("grug_mounts:t1")
local mount = catalog:get_stack("catalog", mount_index)
local forged = ItemStack(mount); forged:get_meta():set_string("grug_mounts:owner", "other")
assert(callbacks.allow_put(catalog, "catalog", mount_index, forged, player) == 0)
assert(callbacks.allow_put(catalog, "catalog", mount_index, mount, player) == -1)
assert(allow_action(player, "put", inv, {listname = "craft", stack = strike}) == 0)
assert(allow_action(player, "put", inv, {listname = "grug_bag1_content", stack = strike}) == nil)
assert(allow_action(player, "take", inv, {listname = "main", stack = strike}) == nil)
core.detached_inventories.late_chest = {allow_put = function() return -1 end}
local page_form = grug_skills.page_content(player)
assert(page_form:find(";8,1;0]", 1, true) and page_form:find(";4,1;8]", 1, true))
assert(core.detached_inventories.late_chest.allow_put(nil, nil, nil, strike, player) == 0)
assert(core.detached_inventories.late_chest.allow_put(nil, nil, nil, ItemStack("test:ordinary"), player) == -1)
assert(core.registered_nodes['test:chest'].allow_metadata_inventory_put(nil, nil, nil, strike, player) == 0)
assert(core.registered_nodes['test:chest'].allow_metadata_inventory_put(nil, nil, nil, ItemStack("test:ordinary"), player) == -1)
player.talent_ranks = {hamstring = 1}
for _, callback in ipairs(talent_callbacks) do callback(player) end
assert(#notices == 1 and notices[1]:find("Inventory > Skills", 1, true))
for _, callback in ipairs(talent_callbacks) do callback(player) end
assert(#notices == 1, "rank refresh repeated unlock notice")
print("r12 Skills real callbacks PASS: normalization, equipment notifications, retained tiers, owner/delete/recovery, bag absence, cooldown, late guards, unlock notice")

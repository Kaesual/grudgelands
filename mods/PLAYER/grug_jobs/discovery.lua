local META_SEEN = "grug_jobs:seen_items"
local SCAN_INTERVAL = 2
local cached, accumulator = {}, 0
local function player_name(player) return player and player.get_player_name and player:get_player_name() or "" end
local function load_seen(player)
	local name = player_name(player); if cached[name] then return cached[name] end
	local seen, stored = {}, player:get_meta():get_string(META_SEEN)
	if stored ~= "" then
		local values = core.deserialize(stored)
		if type(values) == "table" then for _, item in ipairs(values) do
			if type(item) == "string" and item ~= "" and not item:match("^group:") then seen[item] = true end
		end end
	end
	cached[name] = seen; return seen
end
local function save_seen(player, seen)
	local values = {}; for item in pairs(seen) do values[#values + 1] = item end
	table.sort(values); player:get_meta():set_string(META_SEEN, core.serialize(values))
end
local function add_item(seen, item)
	local name = grug_jobs._item_name(item)
	if name == "" or name:match("^group:") or seen[name] then return false end
	seen[name] = true; return true
end
local function token_matches_item(token, item)
	local groups = token:match("^group:(.+)$")
	if not groups then return token == item end
	if type(core.get_item_group) ~= "function" then return false end
	for group in groups:gmatch("[^,]+") do if core.get_item_group(item, group) <= 0 then return false end end
	return true
end
function grug_jobs.discovery_seen(player, token)
	local name = grug_jobs._item_name(token); if name == "" then return false end
	local seen = load_seen(player); if not name:match("^group:") then return seen[name] == true end
	for item in pairs(seen) do if token_matches_item(name, item) then return true end end
	return false
end
function grug_jobs.recipe_discovered(player, recipe)
	local declaration = recipe.basics_presentation
	if not declaration then return recipe.profession ~= "general" end
	return declaration.starter == true or grug_jobs.discovery_seen(player, declaration.main_material)
end
function grug_jobs.mark_seen(player, items)
	if type(items) ~= "table" then items = {items} end
	local seen, changed = load_seen(player), false
	for _, item in ipairs(items) do if add_item(seen, item) then changed = true end end
	if changed then save_seen(player, seen) end
	return changed
end
local function scan_player(player)
	if not player or not player.get_inventory then return false end
	local inventory = player:get_inventory(); if not inventory then return false end
	local all_lists = inventory.get_lists and inventory:get_lists() or {
		main = inventory:get_list("main") or {}, craft = inventory:get_list("craft") or {},
	}
	local seen, changed = load_seen(player), false
	for listname, list in pairs(all_lists) do
		if listname ~= "craftpreview" then
			for _, stack in ipairs(list) do if add_item(seen, stack) then changed = true end end
		end
	end
	if changed then
		save_seen(player, seen)
		if grug_jobs.refresh_open_book then grug_jobs.refresh_open_book(player) end
	end
	return changed
end
if core.register_on_player_inventory_action then
	core.register_on_player_inventory_action(function(player) core.after(0, function(name)
		local current = core.get_player_by_name(name); if current then scan_player(current) end
	end, player:get_player_name()) end)
end
core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime; if accumulator < SCAN_INTERVAL then return end
	accumulator = accumulator % SCAN_INTERVAL
	for _, player in ipairs(core.get_connected_players and core.get_connected_players() or {}) do scan_player(player) end
end)
core.register_on_leaveplayer(function(player) cached[player_name(player)] = nil end)
grug_jobs.DISCOVERY_META_KEY = META_SEEN
grug_jobs.DISCOVERY_SCAN_INTERVAL = SCAN_INTERVAL
grug_jobs._scan_discovery = scan_player
grug_jobs._discovery_token_matches = token_matches_item

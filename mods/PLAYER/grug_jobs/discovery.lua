local META_SEEN = "grug_jobs:seen_items"
local SCAN_INTERVAL = 2
local cached = {}
local accumulator = 0

local function player_name(player)
	return player and player.get_player_name and player:get_player_name() or ""
end

local function load_seen(player)
	local name = player_name(player)
	if cached[name] then return cached[name] end
	local seen = {}
	local stored = player:get_meta():get_string(META_SEEN)
	if stored ~= "" then
		local values = core.deserialize(stored)
		if type(values) == "table" then
			for index = 1, #values do
				local item = values[index]
				if type(item) == "string" and item ~= "" and
						not item:match("^group:") then
					seen[item] = true
				end
			end
		end
	end
	cached[name] = seen
	return seen
end

local function save_seen(player, seen)
	local values = {}
	for item in pairs(seen) do values[#values + 1] = item end
	table.sort(values)
	player:get_meta():set_string(META_SEEN, core.serialize(values))
end

local function add_item(seen, item)
	local name = grug_jobs._item_name(item)
	if name == "" or name:match("^group:") or seen[name] then return false end
	seen[name] = true
	return true
end

local function token_matches_item(token, item)
	local groups = token:match("^group:(.+)$")
	if not groups then return token == item end
	if type(core.get_item_group) ~= "function" then return false end
	for group in groups:gmatch("[^,]+") do
		if core.get_item_group(item, group) <= 0 then return false end
	end
	return true
end

local function representative(token)
	if not token:match("^group:") then return token end
	local names = {}
	for name in pairs(core.registered_items or {}) do names[#names + 1] = name end
	table.sort(names)
	for index = 1, #names do
		if token_matches_item(token, names[index]) then return names[index] end
	end
	return nil
end

function grug_jobs.discovery_seen(player, item)
	local name = grug_jobs._item_name(item)
	if name == "" then return false end
	local seen = load_seen(player)
	if not name:match("^group:") then return seen[name] == true end
	for item_name in pairs(seen) do
		if token_matches_item(name, item_name) then return true end
	end
	return false
end

function grug_jobs.recipe_discovered(player, recipe)
	for index = 1, #(recipe.flat_inputs or {}) do
		local token = recipe.flat_inputs[index]
		if token ~= "" and not grug_jobs.discovery_seen(player, token) then
			return false
		end
	end
	return true
end

function grug_jobs.mark_seen(player, items)
	if type(items) ~= "table" then items = {items} end
	local seen = load_seen(player)
	local changed = false
	for index = 1, #items do
		if add_item(seen, items[index]) then changed = true end
	end
	if changed then save_seen(player, seen) end
	return changed
end

function grug_jobs.discover_tier_one_inputs(player, profession)
	local seen = load_seen(player)
	local changed = false
	local recipes = grug_jobs.recipes_for(profession)
	for recipe_index = 1, #recipes do
		local recipe = recipes[recipe_index]
		if recipe.tier == 1 then
			for input_index = 1, #(recipe.flat_inputs or {}) do
				local item = representative(recipe.flat_inputs[input_index])
				if item and add_item(seen, item) then changed = true end
			end
		end
	end
	if changed then save_seen(player, seen) end
	return changed
end

local function scan_player(player)
	if not player or not player.get_inventory then return false end
	local inventory = player:get_inventory()
	if not inventory or not inventory.get_list then return false end
	local seen = load_seen(player)
	local changed = false
	for _, listname in ipairs({"main", "craft"}) do
		local list = inventory:get_list(listname) or {}
		for index = 1, #list do
			if add_item(seen, list[index]) then changed = true end
		end
	end
	if changed then save_seen(player, seen) end
	return changed
end

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < SCAN_INTERVAL then return end
	accumulator = 0
	local players = core.get_connected_players and core.get_connected_players() or {}
	for index = 1, #players do scan_player(players[index]) end
end)

core.register_on_leaveplayer(function(player)
	cached[player_name(player)] = nil
end)

grug_jobs.DISCOVERY_META_KEY = META_SEEN
grug_jobs.DISCOVERY_SCAN_INTERVAL = SCAN_INTERVAL
grug_jobs._scan_discovery = scan_player
grug_jobs._discovery_token_matches = token_matches_item

local META_SEEN = "grug_jobs:seen_items"
-- When the inventory is scanned (Round 37, audit PLY-05/X-13): the seen set
-- only grows and only the recipe books show it, and opening a book scans
-- first (grug_jobs.open_book), so a book always shows what the player holds.
-- Otherwise each player is scanned in its slot of SLOTS x SLOT_PERIOD =
-- 0.5 s after an inventory action, and every SWEEP seconds for items that
-- arrived without one (digging, pickups, rewards), never all players in one
-- step.
local SLOTS, SLOT_PERIOD, SWEEP = 5, 0.1, 10
local cached = {}
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
-- `quiet`: do not redraw an open book (the caller is about to draw it).
local function scan_player(player, quiet)
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
		if not quiet and grug_jobs.refresh_open_book then grug_jobs.refresh_open_book(player) end
	end
	return changed
end
-- player name -> its slot (1..SLOTS), whether an inventory action is
-- pending, and the slot visits since its last scan.
local slot_of, dirty, visits = {}, {}, {}
local joined, accumulator, current_slot = 0, 0, 0
local SWEEP_VISITS = SWEEP / (SLOTS * SLOT_PERIOD)
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	joined = joined + 1
	slot_of[name], dirty[name], visits[name] = joined % SLOTS + 1, true, 0
end)
core.register_on_player_inventory_action(function(player) dirty[player:get_player_name()] = true end)
core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < SLOT_PERIOD then return end
	-- A stall longer than one period collapses to a single slot.
	accumulator = accumulator - SLOT_PERIOD
	if accumulator > SLOT_PERIOD then accumulator = 0 end
	current_slot = current_slot % SLOTS + 1
	for name, slot in pairs(slot_of) do
		if slot == current_slot then
			visits[name] = visits[name] + 1
			if dirty[name] or visits[name] >= SWEEP_VISITS then
				local player = core.get_player_by_name(name)
				if player then scan_player(player) end
				dirty[name], visits[name] = nil, 0
			end
		end
	end
end)
core.register_on_leaveplayer(function(player)
	local name = player_name(player)
	cached[name], slot_of[name], dirty[name], visits[name] = nil, nil, nil, nil
end)
grug_jobs.DISCOVERY_META_KEY = META_SEEN
grug_jobs.DISCOVERY_SWEEP = SWEEP
-- Scans the player's lists now; `quiet` as above (open_book, probes).
grug_jobs._scan_discovery = scan_player
grug_jobs._discovery_token_matches = token_matches_item

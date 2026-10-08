-- Disposable engine probe (Round 44 lane MS: the migration step 0.44.0 end to
-- end). Never shipped: tools/r44_ms/e2e.py stages it through
-- tools/luanti_headless.sh, under the 0.43.0 game for the setup boot and
-- under this checkout's game after the tool. It asserts nothing: it writes
-- what the game saw to <world>/r43_it_obs.json (Round 43 IT's file names:
-- e2e.py boots through tools/r43_it/it.py) and e2e.py checks it.
--   at load       grug_core.world_version's decision and every registered
--                 item the step's rules concern (groups grug_bound_skill,
--                 grug_ability, grug_mount; names under grug_abilities: and
--                 grug_mounts:), so e2e.py can prove the step's frozen names
--                 against the 0.43.0 game;
--   each join     right after grug_core's migration runner (this callback is
--                 moved to the second place): the inventory as loaded; when
--                 the plan's phase starts with "setup" (0.43.0) the character
--                 is then built (see below); 2.5 s after the join the
--                 inventory as the game left it, the purchase record and the
--                 owned mounts;
--   then          once every character the plan names has left again, it
--                 writes the file and shuts the server down.
-- The plan: <world>/r43_it_plan.json {"phase": "...", "joins": [names]}.
--
-- The setup (0.43.0): "rider" becomes a warrior of the first
-- faction and its first race, owns riding tiers 1-2 and the boat (the
-- purchase record), and carries skills on the hotbar, in main[9..] and in a
-- bag, mount items on the hotbar, in main[9..], in a bag and in the craft
-- grid, and ordinary items among them. "walker" (no class) carries a skill on
-- the hotbar and an apple: nothing of it is the step's. Every placed stack is
-- listed in the observation's `layout` with the role the step must give it.

local P = "[r44_ms_probe] "
local world = core.get_worldpath()
local wv = grug_core.world_version

local function log(msg) core.log("action", P .. msg) end

local function read(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local plan = core.parse_json(read(world .. "/r43_it_plan.json") or "") or {}
local expected = plan.joins or {}
local phase = plan.phase or "?"

local obs = {
	phase = phase,
	load = {new_world = wv.new_world, from = wv.from, game = wv.game, steps = {}},
	joins = {},
	leaves = 0,
}
for i, step in ipairs(wv.steps) do
	obs.load.steps[i] = step.version
end

local function sorted(set)
	local out = {}
	for name in pairs(set) do out[#out + 1] = name end
	table.sort(out)
	return out
end

local function inventory(player)
	local out = {}
	for listname, list in pairs(player:get_inventory():get_lists()) do
		local stacks = {}
		for i, stack in ipairs(list) do stacks[i] = stack:to_string() end
		out[listname] = {size = #list, stacks = stacks}
	end
	return out
end

local MOUNT_META = {"grug_mounts:land_tier", "grug_mounts:flight_tier", "grug_mounts:water_tier"}

local function mounts(player)
	local meta = player:get_meta()
	local record = {}
	for _, key in ipairs(MOUNT_META) do record[key] = meta:get_string(key) end
	local owned = core.global_exists("grug_mounts") and grug_mounts.owned_tier_ids and
		grug_mounts.owned_tier_ids(player) or {}
	return {record = record, owned = owned}
end

-- The 0.43.0 character build (a "setup" phase).
local layouts = {}

local function place(player, entries, listname, index, stack, role)
	if stack == nil or stack:is_empty() then
		error(P .. "no stack for " .. listname .. "[" .. index .. "]")
	end
	player:get_inventory():set_stack(listname, index, stack)
	entries[#entries + 1] = {list = listname, slot = index, item = stack:get_name(), role = role}
end

local function build_rider(player)
	local factions = sorted(grug_core.factions)
	local faction = factions[1]
	local races = {}
	for id, def in pairs(grug_classes.registered_races) do
		if def.faction == faction then races[id] = true end
	end
	local race = sorted(races)[1]
	assert(grug_factions.set_faction(player, faction), "set_faction")
	assert(grug_classes.set_race(player, race), "set_race")
	assert(grug_classes.set_class(player, "warrior"), "set_class")
	local meta = player:get_meta()
	-- The purchase record as grug_mounts.purchase writes it.
	meta:set_int("grug_mounts:land_tier", 2)
	meta:set_int("grug_mounts:water_tier", 5)
	local inv = player:get_inventory()
	inv:set_list("main", {})
	inv:set_list("craft", {})
	local skill = function(id) return grug_abilities.stack_for(player, id) end
	local mount = function(tier) return grug_mounts.stack_for(player, tier) end
	local e = {}
	place(player, e, "main", 1, skill("strike"), "keep")
	place(player, e, "main", 2, skill("charge"), "keep")
	place(player, e, "main", 3, mount(1), "remove")
	place(player, e, "main", 4, ItemStack("default:apple 5"), "keep")
	place(player, e, "main", 8, skill("taunt"), "keep")
	place(player, e, "main", 9, skill("mighty_blow"), "remove")
	place(player, e, "main", 10, skill("strike"), "remove")
	place(player, e, "main", 11, mount(2), "remove")
	place(player, e, "main", 12, ItemStack("default:torch 20"), "keep")
	place(player, e, "main", 13, ItemStack("grug_materials:pick_steel 1 1234"), "keep")
	place(player, e, "main", 32, ItemStack("default:apple 2"), "keep")
	place(player, e, "craft", 1, mount(1), "remove")
	place(player, e, "craft", 5, ItemStack("default:torch 3"), "keep")
	place(player, e, grug_inventory.bag_list(1), 1, ItemStack("grug_inventory:bag_small"), "keep")
	inv:set_size(grug_inventory.content_list(1), 8)
	local bag = grug_inventory.content_list(1)
	place(player, e, bag, 1, skill("taunt"), "remove")
	place(player, e, bag, 2, mount(5), "remove")
	place(player, e, bag, 3, ItemStack("default:apple 3"), "keep")
	place(player, e, bag, 8, skill("charge"), "remove")
	return {faction = faction, race = race, class = grug_classes.get_class(player), entries = e}
end

local function build_walker(player)
	local e = {}
	local inv = player:get_inventory()
	inv:set_list("main", {})
	place(player, e, "main", 1, grug_abilities.stack_for(player, "strike"), "keep")
	place(player, e, "main", 9, ItemStack("default:apple 2"), "keep")
	return {class = grug_classes.get_class(player) or "", entries = e}
end

local BUILD = {rider = build_rider, walker = build_walker}

local function on_join(player)
	local name = player:get_player_name()
	local entry = {name = name, loaded = inventory(player)}
	obs.joins[#obs.joins + 1] = entry
	log("joined " .. name)
	if phase:match("^setup") and BUILD[name] then
		core.after(0.5, function()
			local current = core.get_player_by_name(name)
			if not current then return end
			local ok, result = pcall(BUILD[name], current)
			entry.layout = ok and result or {error = tostring(result)}
			log("built " .. name .. (ok and "" or (": " .. tostring(result))))
		end)
	end
	core.after(2.5, function()
		local current = core.get_player_by_name(name)
		if not current then return end
		entry.settled = inventory(current)
		entry.mounts = mounts(current)
		entry.hotbar_itemcount = current:hud_get_hotbar_itemcount()
	end)
end
core.register_on_joinplayer(on_join)

core.register_on_mods_loaded(function()
	local groups = {grug_bound_skill = {}, grug_ability = {}, grug_mount = {}}
	local prefixed = {["grug_abilities:"] = {}, ["grug_mounts:"] = {}}
	for name in pairs(core.registered_items) do
		for group, set in pairs(groups) do
			if core.get_item_group(name, group) > 0 then set[name] = true end
		end
		for prefix, set in pairs(prefixed) do
			if name:sub(1, #prefix) == prefix then set[name] = true end
		end
	end
	local aliases = {}
	for alias in pairs(core.registered_aliases) do
		if alias:sub(1, 15) == "grug_abilities:" or alias:sub(1, 12) == "grug_mounts:" then
			aliases[alias] = true
		end
	end
	obs.registrations = {
		groups = {}, prefixed = {}, aliases = sorted(aliases),
		hotbar_size = core.global_exists("grug_inventory") and grug_inventory.HOTBAR_SIZE or nil,
	}
	for group, set in pairs(groups) do obs.registrations.groups[group] = sorted(set) end
	for prefix, set in pairs(prefixed) do obs.registrations.prefixed[prefix] = sorted(set) end
	local joins = core.registered_on_joinplayers
	for i, fn in ipairs(joins) do
		if fn == on_join then
			table.insert(joins, 2, table.remove(joins, i))
			break
		end
	end
end)

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r44 ms probe done") end)
end

core.register_on_leaveplayer(function(player)
	obs.leaves = obs.leaves + 1
	log("left " .. player:get_player_name())
	if obs.leaves >= #expected then
		core.after(1, finish, "every planned character left")
	end
end)

core.after(0, function()
	if #expected == 0 then
		core.after(3, finish, "no joins planned")
	end
	core.after(150, finish, "timeout: not every planned character joined and left")
end)

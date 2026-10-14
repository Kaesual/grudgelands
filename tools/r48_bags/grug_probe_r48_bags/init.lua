-- Disposable engine probe (Round 48 lane BAGS: the migration step 0.48.0 end
-- to end). Never shipped: tools/r48_bags/e2e.py stages it through
-- tools/luanti_headless.sh, under the 0.47.0 game for the setup boot and
-- under this checkout's game after the tool. It asserts nothing: it writes
-- what the game saw to <world>/r43_it_obs.json (Round 43 IT's file names:
-- e2e.py boots through tools/r43_it/it.py) and e2e.py checks it.
--   each join   first of all join callbacks (before grug_core's migration
--               runner): the marker, the list sizes and every carried
--               stack as loaded; in a "setup" phase the character is then
--               built (below); 3 s after the join the same as the game
--               left them, the feed lines the step sent and the unread
--               mail count (grug_mail.unread_count, when the game has it);
--   then        once every character the plan names has left again, it
--               writes the file and shuts the server down.
-- The setup (0.47.0), every stack distinct (item meta `r48_probe` = its
-- number) so nothing merges unless the build says so:
--   hoarder  the hotbar: a torch stack and apples; main[9]: the Claim Stone
--            (soulbound); main[10..32] and four 32-slot bags (two Great
--            Cloth Bags, two Leather Rucksacks) full: 148 numbered dirt and
--            cobble stacks of varied counts, a crafted Iron Sword in bag 3
--            and two half stacks of plain apples (bag 2 and bag 4) that the
--            sort merges: 152 stacks before, 151 after the merge, 88 cells
--            after the step, so 63 stacks in 16 letters;
--   light    no bags: a few stacks in main;
--   sleeper  one full 8-slot Small Bag; joins only for the setup.

local P = "[r48_bags_probe] "
local world = core.get_worldpath()
local wv = grug_core.world_version
local MARKER = "grug_core:migrate:0.48.0"
local CONTENT = {}
for i = 1, 4 do CONTENT[i] = "grug_bag" .. i .. "_content" end

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
local setup = phase:match("^setup") ~= nil

local obs = {phase = phase, game = wv.game,
	load = {new_world = wv.new_world, from = wv.from}, joins = {}, leaves = 0}

-- The feed lines of the step (its key), per player.
local feed_lines = {}
core.register_on_mods_loaded(function()
	local feed = grug_core.feed
	grug_core.feed = function(player, kind, text, key)
		if key == "migrate_0_48_0" then
			local name = player:get_player_name()
			feed_lines[name] = feed_lines[name] or {}
			table.insert(feed_lines[name], text)
		end
		return feed(player, kind, text, key)
	end
end)

local LISTS = {"main", "grug_bag1", "grug_bag2", "grug_bag3", "grug_bag4",
	CONTENT[1], CONTENT[2], CONTENT[3], CONTENT[4]}

local function state(player)
	local inv = player:get_inventory()
	local lists, sizes = {}, {}
	for _, list in ipairs(LISTS) do
		sizes[list] = inv:get_size(list)
		local out = {}
		for index = 1, inv:get_size(list) do
			out[index] = inv:get_stack(list, index):to_string()
		end
		lists[list] = out
	end
	local name = player:get_player_name()
	return {marker = player:get_meta():get_string(MARKER), sizes = sizes, lists = lists,
		feed = feed_lines[name] or {},
		unread = rawget(_G, "grug_mail") and grug_mail.unread_count and
			grug_mail.unread_count(name) or false}
end

-- The 0.47.0 build.
local counter = 0
local function numbered(item, count)
	counter = counter + 1
	local stack = ItemStack(item .. " " .. count)
	stack:get_meta():set_string("r48_probe", tostring(counter))
	return stack
end

local function clear(player)
	local inv = player:get_inventory()
	for name in pairs(inv:get_lists()) do inv:set_list(name, {}) end
	inv:set_size("main", 32)
	for i = 1, 4 do
		inv:set_size("grug_bag" .. i, 1)
		inv:set_size(CONTENT[i], 0)
	end
	return inv
end

local function equip(inv, i, bag, size)
	inv:set_stack("grug_bag" .. i, 1, ItemStack(bag))
	inv:set_size(CONTENT[i], size)
end

local function build_hoarder(player)
	local inv = clear(player)
	inv:set_stack("main", 1, ItemStack("default:torch 20"))
	inv:set_stack("main", 2, ItemStack("default:apple 7"))
	inv:set_stack("main", 9, ItemStack(grug_housing.STONE_ITEM))
	local n = 0
	local function junk()
		n = n + 1
		return numbered(n % 2 == 0 and "default:dirt" or "default:cobble", 1 + n % 60)
	end
	for index = 10, 32 do inv:set_stack("main", index, junk()) end
	equip(inv, 1, "grug_inventory:bag_great", 32)
	equip(inv, 2, "grug_inventory:bag_leather_rucksack", 32)
	equip(inv, 3, "grug_inventory:bag_great", 32)
	equip(inv, 4, "grug_inventory:bag_leather_rucksack", 32)
	for i = 1, 4 do
		for index = 1, 32 do inv:set_stack(CONTENT[i], index, junk()) end
	end
	local sword = ItemStack("grug_gear:sword_iron")
	assert(grug_items.crafted_output(sword, player), P .. "crafted_output sword")
	inv:set_stack(CONTENT[3], 5, sword)
	inv:set_stack(CONTENT[2], 7, ItemStack("default:apple 30"))
	inv:set_stack(CONTENT[4], 9, ItemStack("default:apple 30"))
	return true
end

local function build_light(player)
	local inv = clear(player)
	inv:set_stack("main", 3, ItemStack("default:torch 5"))
	inv:set_stack("main", 12, numbered("default:dirt", 40))
	inv:set_stack("main", 20, ItemStack("default:apple 3"))
	return true
end

local function build_sleeper(player)
	local inv = clear(player)
	equip(inv, 1, "grug_inventory:bag_small", 8)
	for index = 1, 8 do inv:set_stack(CONTENT[1], index, numbered("default:cobble", index)) end
	return true
end

local BUILD = {hoarder = build_hoarder, light = build_light, sleeper = build_sleeper}

local function on_join(player)
	local name = player:get_player_name()
	local entry = {name = name, loaded = state(player)}
	obs.joins[#obs.joins + 1] = entry
	log("joined " .. name)
	if setup and BUILD[name] then
		core.after(0.5, function()
			local current = core.get_player_by_name(name)
			if not current then return end
			local ok, err = pcall(BUILD[name], current)
			entry.built_ok = ok
			entry.build_error = not ok and tostring(err) or nil
			log("built " .. name .. (ok and "" or (": " .. tostring(err))))
		end)
	end
	core.after(3, function()
		local current = core.get_player_by_name(name)
		if current then entry.settled = state(current) end
	end)
end
-- First of all join callbacks, before grug_core's migration runner.
local joins = core.registered_on_joinplayers
local count = #joins
core.register_on_joinplayer(on_join)
assert(#joins == count + 1)
core.register_on_mods_loaded(function()
	table.insert(joins, 1, table.remove(joins, count + 1))
end)

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r48 bags probe done") end)
end

core.register_on_leaveplayer(function(player)
	obs.leaves = obs.leaves + 1
	log("left " .. player:get_player_name())
	if obs.leaves >= #expected then
		core.after(1, finish, "every planned character left")
	end
end)

core.after(0, function()
	if #expected == 0 then core.after(3, finish, "no joins planned") end
	core.after(150, finish, "timeout: not every planned character joined and left")
end)

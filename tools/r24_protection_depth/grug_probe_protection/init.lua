-- Round 24 Lane G engine probe (disposable, never shipped): ruling 30 under
-- the Orc start town (Sunscar, anchor 0/2550).
--
-- 1. Emerges the ground under the town's pad (x -48..47, z 2502..2597,
--    from 96 below the floor to the anchor) and counts the P8 resource nodes above and below the
--    protected floor (the anchor's placement height - 100): none above,
--    ores below.
-- 2. A Throng probe digger (Sunscar is Throng home) with a bronze pick:
--    core.is_protected, the mining decision, the punch hint and a real
--    core.node_dig at the floor + 1, the floor and the floor - 1. An Accord
--    probe digger is refused below the floor by the ordinary home rule.
-- 3. Ruling 30 addendum: world-content cave rows (cave_cap) under the pad
--    below the floor, none above it, and a same-size reference box on
--    unprotected ground 480 nodes east for comparison.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r24_protection_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end

local DEPTH = 100
local PROBE_NAME = "r24gprobe"
local PICK = "grug_materials:pick_bronze" -- T1: every rock here is T1 (y >= -100)

local function probe_player(item)
	local stack = ItemStack(item or "")
	return {
		is_player = function() return true end,
		get_player_name = function() return PROBE_NAME end,
		get_wielded_item = function() return ItemStack(stack) end,
		set_wielded_item = function(_, new) stack = ItemStack(new) return true end,
		get_inventory = function() return nil end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
	}
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r24 protection probe done", false, 0)
end

local function orc_start()
	for _, start in ipairs(grug_core.start_identities()) do
		if start.anchor.x == 0 and start.anchor.z == 2550 then return start end
	end
end

local function ore_counts(minp, maxp)
	local names = {}
	for _, resource in ipairs(grug_materials.RESOURCES) do
		names[#names + 1] = resource.natural_node
	end
	local _, counts = core.find_nodes_in_area(minp, maxp, names)
	local total, parts = 0, {}
	for _, name in ipairs(names) do
		local count = counts[name] or 0
		total = total + count
		if count > 0 then parts[#parts + 1] = name:gsub("^.*:stone_with_", "") .. "=" .. count end
	end
	local _, stone = core.find_nodes_in_area(minp, maxp, {"default:stone"})
	return total, table.concat(parts, " "), stone["default:stone"] or 0
end

-- The world-content cave rows' nodes (cave_cap, ember_moss).
local function cave_counts(minp, maxp)
	local names = {}
	for name, def in pairs(core.registered_nodes) do
		if (name:find("cave_cap", 1, true) or name:find("ember_moss", 1, true)) and
				not name:find("seed", 1, true) then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	local _, counts = core.find_nodes_in_area(minp, maxp, names)
	local total = 0
	for _, name in ipairs(names) do total = total + (counts[name] or 0) end
	return total
end

local function digging(start, floor)
	local previous_faction = grug_core.get_player_faction
	local faction = "throng"
	grug_core.get_player_faction = function(name)
		if name == PROBE_NAME then return faction end
		return previous_faction(name)
	end
	local ok, err = pcall(function()
		local x, z = 5, 2555
		local rows = {
			{floor + 1, true}, {floor, true}, {floor - 1, false},
		}
		for _, row in ipairs(rows) do
			local pos = {x = x, y = row[1], z = z}
			faction = "throng"
			core.set_node(pos, {name = "default:stone"})
			local protected = core.is_protected(pos, PROBE_NAME)
			local player = probe_player(PICK)
			local decision = grug_materials.mining_decision(pos, core.get_node(pos), player)
			local hint = grug_materials.punch_hint(pos, core.get_node(pos), player)
			local kind = grug_zones.hard_protection_kind_at(pos)
			local rule = grug_zones.territory_rule_at(pos)
			local dug_ok, dug = pcall(core.node_dig, pos, core.get_node(pos), player)
			local after = core.get_node(pos).name
			log(("DIG throng y=%d (floor%+d): protected=%s decision=%s kind=%s rule=%s" ..
				" hint=%s node_dig=%s -> %s"):format(row[1], row[1] - floor,
				tostring(protected), tostring(decision.reason), tostring(kind),
				tostring(rule), tostring(hint), dug_ok and tostring(dug) or
				("error " .. tostring(dug)), after))
			check(protected == row[2], "throng is_protected at y=" .. row[1])
			check(decision.allowed == not row[2], "throng decision at y=" .. row[1])
			if row[2] then
				check(kind == "town" and hint == "Town – protected",
					"town hint at y=" .. row[1])
				check(after == "default:stone", "refused dig keeps the stone at y=" .. row[1])
			else
				check(kind == nil and rule == "throng_home", "home rule below the floor")
				check(hint == nil, "no hint below the floor")
				check(dug_ok and after == "air", "throng digs below the floor")
			end
			-- The other faction: the ordinary home rule below, the town above.
			faction = "accord"
			core.set_node(pos, {name = "default:stone"})
			local reason = grug_core.protection_reason(pos, PROBE_NAME)
			log(("DIG accord y=%d: protected=%s reason=%s"):format(row[1],
				tostring(core.is_protected(pos, PROBE_NAME)), tostring(reason)))
			check(core.is_protected(pos, PROBE_NAME), "accord refused at y=" .. row[1])
			check(reason == (row[2] and "town" or "throng_home"),
				"accord reason at y=" .. row[1])
		end
		-- Unbounded upward.
		faction = "throng"
		check(core.is_protected({x = x, y = 30000, z = z}, PROBE_NAME),
			"protected at y=30000")
	end)
	grug_core.get_player_faction = previous_faction
	check(ok, "digging scenario ran (" .. tostring(err) .. ")")
end

core.after(2, function()
	local start = orc_start()
	if not check(start ~= nil and start.faction_id == "throng", "Orc start identity") then
		return finish()
	end
	local floor = start.anchor.y - DEPTH
	log(("ORC start anchor %s, protected floor y=%d"):format(
		core.pos_to_string(start.anchor), floor))
	-- 240 nodes below the floor (the cave_cap rows reach -100..-500), a
	-- multiple of 16, so the 16-node layers end at the floor.
	local minp = {x = -48, y = floor - 240, z = 2502}
	local maxp = {x = 47, y = start.anchor.y - 1, z = 2597}
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("EMERGED %s..%s in %.1f s"):format(core.pos_to_string(minp),
			core.pos_to_string(maxp), (core.get_us_time() - started) / 1000000))
		local above, above_parts, above_stone = ore_counts(
			{x = minp.x, y = floor, z = minp.z}, maxp)
		local below, below_parts, below_stone = ore_counts(minp,
			{x = maxp.x, y = floor - 1, z = maxp.z})
		log(("ORES above floor (y %d..%d): %d [%s], default:stone %d"):format(
			floor, maxp.y, above, above_parts, above_stone))
		log(("ORES below floor (y %d..%d): %d [%s], default:stone %d"):format(
			minp.y, floor - 1, below, below_parts, below_stone))
		for y0 = minp.y, maxp.y, 16 do
			local y1 = math.min(maxp.y, y0 + 15)
			local count, parts, stone = ore_counts({x = minp.x, y = y0, z = minp.z},
				{x = maxp.x, y = y1, z = maxp.z})
			log(("LAYER y %4d..%4d: ores %4d stone %6d %s"):format(y0, y1, count,
				stone, parts))
		end
		check(above == 0, "no P8 ore inside the protected volume")
		check(below > 0, "ores below the protected floor")
		-- Ruling 30 addendum: cave content (world-content cave rows) under the
		-- town, against the same box 480 nodes east on unprotected ground.
		local town_below = cave_counts(minp, {x = maxp.x, y = floor - 1, z = maxp.z})
		local town_above = cave_counts({x = minp.x, y = floor, z = minp.z}, maxp)
		log(("CAVE content under the town: below floor %d, above floor %d"):format(
			town_below, town_above))
		check(town_below > 0, "cave content below the town's floor")
		check(town_above == 0, "no cave content inside the protected volume")
		local rmin = {x = minp.x + 480, y = minp.y, z = minp.z}
		local rmax = {x = maxp.x + 480, y = floor - 1, z = maxp.z}
		core.emerge_area(rmin, rmax, function(_, _, left)
			if left > 0 then return end
			log(("CAVE content in the reference box %s..%s: %d"):format(
				core.pos_to_string(rmin), core.pos_to_string(rmax),
				cave_counts(rmin, rmax)))
			digging(start, floor)
			finish()
		end)
	end)
end)

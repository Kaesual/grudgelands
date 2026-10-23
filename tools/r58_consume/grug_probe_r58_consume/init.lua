-- Disposable engine probe (Round 58 lane CONSUME): the search costs and the
-- shots of the Miner's Guild consumables. Never shipped:
-- tools/r58_consume/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client (the r49_inv driver: character creation, SHOT /
-- ack handshake).
--
-- Two lit chambers (9 x 5 x 9 of air) are cut below the spawn column: one in
-- T1 rock at y -60, one in T5 rock at y -800 (contested land: nothing there
-- is protected). Before the T1 chamber's ores are touched the probe times
-- one Ore Sense search at range 16 (the shipped grug_guild.ore_sense_find:
-- one core.find_nodes_in_area for all six T1 targets) against the spec's
-- first wording (core.find_node_near per target in priority order), and one
-- Treasure Hunt spot test (grug_guild.remains_spot_ok).
--
-- For the shots only, the running Ore Sense row is set to mark every 2 s and
-- keep its marker 60 s (a runtime table of this throwaway server), so the
-- shot does not wait 60-120 s; the T1 targets around the chamber become
-- stone and one Citrine sits two nodes inside the far wall.

local P = "[r58consume] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r58consume_settle") or "") or 3
local LIGHT = "grug_probe_r58_consume:light"
local catalog = grug_guild.catalog

local function log(msg) core.log("action", P .. msg) end

core.register_node(LIGHT, {
	drawtype = "airlike", paramtype = "light", light_source = 14,
	sunlight_propagates = true, walkable = false, pointable = false,
	diggable = false, buildable_to = true, groups = {not_in_creative_inventory = 1},
})

local state = {phase = "wait", clock = 0}
local spawn, t1, t5

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r58consume_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function chamber(center)
	for x = -4, 4 do
		for y = 0, 4 do
			for z = -4, 4 do
				core.set_node(vector.offset(center, x, y, z), {name = "air"})
			end
		end
	end
	for _, c in ipairs({{-4, -4}, {4, -4}, {-4, 4}, {4, 4}, {0, 0}}) do
		core.set_node(vector.offset(center, c[1], 4, c[2]), {name = LIGHT})
	end
end

local function look_at(player, target)
	local eye = vector.offset(player:get_pos(), 0, player:get_properties().eye_height or 1.5, 0)
	local d = vector.subtract(target, eye)
	player:set_look_horizontal(math.atan2(-d.x, d.z))
	player:set_look_vertical(-math.atan2(d.y, math.sqrt(d.x * d.x + d.z * d.z)))
end

local function stand(player, center)
	player:set_physics_override({gravity = 0, speed = 0, jump = 0})
	player:set_pos(vector.offset(center, 0, 0.5, 0))
end

local function target_nodes(tier)
	local out = {}
	for index, key in ipairs(catalog.ORE_SENSE_TARGETS[tier]) do
		out[index] = grug_materials.RESOURCE_BY_KEY[key].natural_node
	end
	return out
end

-- The costs, before anything in the T1 chamber's neighbourhood changes.
local function measure()
	local pos = vector.offset(t1, 0, 1, 0)
	local nodes = target_nodes(1)
	local runs = 40
	local start = core.get_us_time()
	local found
	for _ = 1, runs do found = grug_guild.ore_sense_find(pos, 1, 16) end
	local shipped = (core.get_us_time() - start) / runs
	start = core.get_us_time()
	local near
	for _ = 1, runs do
		near = nil
		for _, node in ipairs(nodes) do
			near = core.find_node_near(pos, 16, node)
			if near then break end
		end
	end
	local per_target = (core.get_us_time() - start) / runs
	start = core.get_us_time()
	for _ = 1, runs do
		for _, node in ipairs(nodes) do core.find_node_near(pos, 16, node) end
	end
	local all_targets_miss = (core.get_us_time() - start) / runs
	-- No target in range: a full scan either way (a node no map holds).
	local absent = {catalog.remains(6).node}
	start = core.get_us_time()
	for _ = 1, runs do
		core.find_nodes_in_area(vector.offset(pos, -16, -16, -16), vector.offset(pos, 16, 16, 16), absent, true)
	end
	local area_miss = (core.get_us_time() - start) / runs
	start = core.get_us_time()
	for _ = 1, runs do core.find_node_near(pos, 16, absent) end
	local near_miss = (core.get_us_time() - start) / runs
	-- T5 (two targets) from the T5 chamber.
	local t5_pos = vector.offset(t5, 0, 1, 0)
	start = core.get_us_time()
	for _ = 1, runs do grug_guild.ore_sense_find(t5_pos, 5, 16) end
	local t5_shipped = (core.get_us_time() - start) / runs
	log(("COST no target in range: find_nodes_in_area %.0f us, one find_node_near %.0f us; " ..
		"ore_sense_find at T5 (2 targets) %.0f us"):format(area_miss, near_miss, t5_shipped))
	local counts = {}
	local grouped = core.find_nodes_in_area(vector.offset(pos, -16, -16, -16), vector.offset(pos, 16, 16, 16),
		nodes, true)
	for _, node in ipairs(nodes) do counts[#counts + 1] = node:gsub("^.*:", "") .. "=" .. #(grouped[node] or {}) end
	log(("COST ore_sense_find range 16 (one find_nodes_in_area, 6 targets): %.0f us; " ..
		"find_node_near per target until found: %.0f us; find_node_near all 6: %.0f us; " ..
		"found %s; deposits in the box %s"):format(shipped, per_target, all_targets_miss,
		found and core.pos_to_string(found) or "none", table.concat(counts, " ")))
	-- One Treasure Hunt check is up to 16 spot tests.
	local tests, ok = 2000, 0
	start = core.get_us_time()
	for index = 1, tests do
		local at = vector.offset(t5, (index % 41) - 20, 2 + (index % 13) - 6, math.floor(index / 41) % 41 - 20)
		if grug_guild.remains_spot_ok(at, 5, NAME) then ok = ok + 1 end
	end
	log(("COST remains_spot_ok: %.1f us per spot (%d of %d spots fit around the T5 chamber)"):format(
		(core.get_us_time() - start) / tests, ok, tests))
end

local function give_items(player)
	local inv = player:get_inventory()
	for index, row in ipairs(catalog.CONSUMABLES) do
		inv:set_stack("main", 8 + index, row.item .. " " .. (row.tier + 1))
	end
end

local SHOTS = {
	{name = "C1_ore_sense_marker", run = function(player)
		stand(player, t1)
		local row = catalog.consumable("ore_sense", 1)
		row.interval_min, row.interval_max, row.marker_seconds = 2, 2, 60
		local ok, err = grug_guild.start_effect(player, "ore_sense", 1)
		log("ore sense start " .. tostring(ok) .. " " .. tostring(err))
		look_at(player, vector.offset(t1, 1, 2, 7))
	end},
	{name = "C2_remains_t1", run = function(player)
		look_at(player, vector.offset(t1, -5, 1.5, 0))
	end},
	{name = "C3_treasure_hunt_marker", run = function(player)
		grug_guild.stop_effect(player)
		stand(player, t5)
		local ok, err = grug_guild.start_effect(player, "treasure_hunt", 5)
		log("treasure hunt start " .. tostring(ok) .. " " .. tostring(err))
		local spot
		for _, at in ipairs(core.find_nodes_in_area(vector.offset(t5, -25, -25, -25),
				vector.offset(t5, 25, 25, 25), {catalog.remains(5).node})) do
			if core.get_meta(at):get_string("owner") == NAME then spot = at end
		end
		if spot then
			local solid = 0
			for dx = -1, 1 do for dy = -1, 1 do for dz = -1, 1 do
				local def = core.registered_nodes[core.get_node(vector.offset(spot, dx, dy, dz)).name]
				if (dx ~= 0 or dy ~= 0 or dz ~= 0) and def and def.walkable ~= false then solid = solid + 1 end
			end end end
			log(("treasure hunt Remains at %s, %.1f nodes away, %d of 26 neighbours solid, owner %s"):format(
				core.pos_to_string(spot), vector.distance(spot, player:get_pos()), solid,
				core.get_meta(spot):get_string("owner")))
			look_at(player, spot)
		else
			log("treasure hunt: no Remains placed")
		end
	end},
	{name = "C4_remains_t5", run = function(player)
		look_at(player, vector.offset(t5, -5, 1.5, 0))
	end},
	{name = "C5_item_icons", run = function(player)
		grug_guild.stop_effect(player)
		give_items(player)
		sfinv.set_page(player, "grug_inventory:inventory")
		core.show_formspec(NAME, "grug_probe_r58_consume:inventory",
			sfinv.get_formspec(player, sfinv.get_or_create_context(player)))
	end},
}

local function prepare(player)
	spawn = vector.round(player:get_pos())
	t1 = {x = spawn.x, y = -60, z = spawn.z}
	t5 = {x = spawn.x, y = -800, z = spawn.z}
	state.phase = "emerge"
	local pending = 2
	local function done(_, _, remaining)
		if remaining == 0 then
			pending = pending - 1
			if pending == 0 then state.phase = "build" end
		end
	end
	core.emerge_area(vector.offset(t1, -24, -24, -24), vector.offset(t1, 24, 28, 24), done)
	core.emerge_area(vector.offset(t5, -28, -28, -28), vector.offset(t5, 28, 32, 28), done)
	log("emerging " .. core.pos_to_string(t1) .. " and " .. core.pos_to_string(t5))
end

local function build(player)
	measure()
	chamber(t1)
	chamber(t5)
	-- T1: the targets around become stone; one Citrine two nodes inside the
	-- far wall, a Remains flush in the left wall beside an ore.
	local nodes = target_nodes(1)
	local around = core.find_nodes_in_area(vector.offset(t1, -17, -16, -17), vector.offset(t1, 17, 21, 17), nodes)
	for _, at in ipairs(around) do core.set_node(at, {name = "default:stone"}) end
	core.set_node(vector.offset(t1, 1, 2, 7), {name = grug_materials.RESOURCE_BY_KEY.citrine.natural_node})
	core.set_node(vector.offset(t1, -5, 1, 0), {name = catalog.remains(1).node})
	core.set_node(vector.offset(t1, -5, 1, 2), {name = "default:stone_with_coal"})
	-- T5: a Remains flush in the left wall beside an ore of its tier.
	core.set_node(vector.offset(t5, -5, 1, 0), {name = catalog.remains(5).node})
	core.set_node(vector.offset(t5, -5, 1, 2), {name = grug_materials.RESOURCE_BY_KEY.ruby.natural_node})
	grug_xp.set_xp(player, grug_xp.xp_for_level(60))
	log("level " .. grug_xp.get_level(player) .. ", spawn " .. core.pos_to_string(spawn))
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		prepare(player)
	elseif state.phase == "build" then
		build(player)
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			shot.run(player)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)

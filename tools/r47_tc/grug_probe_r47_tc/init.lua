-- Disposable engine probe (Round 47 lane TC): the generated trees in the
-- world for screenshots. Never shipped: tools/r47_tc/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, camera, SHOT / ack handshake) is lane TA's probe's
-- (tools/r47_ta/grug_probe_r47_ta), from the Round 46 TREE probe.
--
-- F  a forest per tree biome: the first column of a coarse grid in that
--    biome that is land, low (ground 3..20, under the kapok's treeless band)
--    and gentle (the ground 12 nodes away within 3 nodes); a wide view from
--    above and a close one at eye height, both looking west (-x).
-- S  two saplings on a sky platform (y 500, over the deep forest's column,
--    so the ground is wild): an apple, and a kapok whose platform ends two
--    nodes west of the sapling (no root there); grown by the real growth
--    (grug_trees.growth), every result logged.
-- T  the start town round the arrival, from above.

local P = "[r47tc] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r47tc_settle") or "") or 6
local FILTER = core.settings:get("r47tc_shots") or "F,S,T,G,W"
local TIME_OF_DAY = 0.42
-- "groves" (the groves follow-up): the capital groves and Hearthpine instead
-- of the forests and saplings.
local MODE = core.settings:get("r47tc_mode") or "forests"

local function log(msg) core.log("action", P .. msg) end

-- biome -> label (the species the shots show)
local BIOMES = {
	{"grug_deep_forest", "F1_apple_aspen"},
	{"grug_elf_forest", "F2_silverwood"},
	{"grug_jungle_edge", "F3_jungle"},
	{"grug_deep_jungle", "F4_kapok"},
	{"grug_savanna", "F5_acacia"},
	{"grug_pine_hills", "F6_pine"},
	{"grug_bone_forest", "F7_gravewood"},
}

local spots = {}   -- label -> {x, y, z}
local origin       -- the arrival
local SKY_Y = 500

local function find_spots()
	local ps = grug_mapgen.wp40.planner_source
	local want = {}
	for _, row in ipairs(BIOMES) do want[row[1]] = row[2] end
	local function ground(x, z)
		local water, _, _, biome, _, terrain_y = ps.column_values_at(x, z)
		return water, biome, terrain_y
	end
	for z = -3200, 3200, 40 do
		for x = -3600, 3600, 40 do
			local water, biome, y = ground(x, z)
			local label = want[biome]
			if label and not spots[label] and water == "land" and y >= 3 and y <= 20 then
				local gentle = true
				for _, d in ipairs({{12, 0}, {-12, 0}, {0, 12}, {0, -12}}) do
					local w2, b2, y2 = ground(x + d[1], z + d[2])
					if w2 ~= "land" or b2 ~= biome or math.abs(y2 - y) > 3 then gentle = false end
				end
				if gentle then
					spots[label] = {x = x, y = y, z = z}
					log("spot " .. label .. " " .. biome .. " at " .. core.pos_to_string(spots[label]))
				end
			end
		end
	end
end

-- Shots: camera (dx, dy, dz) from the spot's ground, yaw (90 looks -x),
-- pitch (positive looks down).
local SHOTS = {}
-- The trunk nodes a close view looks for, per scene (quarters first: a
-- thick trunk shows the octagon and, on jungle wood, the roots).
local TRUNKS = {
	F1_apple_aspen = {"grug_trees:apple_quarter", "default:tree", "default:aspen_tree"},
	F2_silverwood = {"grug_trees:silverwood_tree"},
	F3_jungle = {"grug_trees:jungle_quarter", "default:jungletree"},
	F4_kapok = {"grug_trees:jungle_quarter", "default:jungletree"},
	F5_acacia = {"default:acacia_tree"},
	F6_pine = {"default:pine_tree"},
	F7_gravewood = {"grug_trees:gravewood_tree"},
}

-- The close view's tree: the trunk foot nearest the spot (a trunk node on
-- walkable ground that is no wood), from the first name of TRUNKS that has
-- one; the camera 7 nodes east of it in free air.
local function close_target(label)
	local s = spots[label]
	for _, name in ipairs(TRUNKS[label] or {}) do
		local best, best_d
		for _, p in ipairs(core.find_nodes_in_area({x = s.x - 36, y = s.y - 4, z = s.z - 36},
				{x = s.x + 36, y = s.y + 6, z = s.z + 36}, {name})) do
			local below = core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
			local def = core.registered_nodes[below]
			if def and def.walkable and core.get_item_group(below, "tree") == 0 then
				local d = math.abs(p.x - s.x) + math.abs(p.z - s.z)
				if not best or d < best_d then best, best_d = p, d end
			end
		end
		if best then
			for _, dz in ipairs({0, 2, -2, 4, -4}) do
				local cam = {x = best.x + 7, y = best.y + 2, z = best.z + dz}
				if core.get_node(cam).name == "air" and
						core.get_node({x = cam.x, y = cam.y - 1, z = cam.z}).name == "air" then
					log("close " .. label .. ": " .. name .. " at " .. core.pos_to_string(best))
					return {x = cam.x - s.x, y = cam.y - s.y - 1, z = cam.z - s.z}
				end
			end
		end
	end
	log("close " .. label .. ": no trunk found")
	return nil
end

local function add_forest_shots()
	for _, row in ipairs(BIOMES) do
		local label = row[2]
		if spots[label] then
			SHOTS[#SHOTS + 1] = {name = label .. "_wide", spot = label, dx = 36, dy = 30,
				dz = 0, yaw = 90, pitch = 30, first = true}
			local c = close_target(label)
			if c then
				SHOTS[#SHOTS + 1] = {name = label .. "_close", spot = label, dx = c.x,
					dy = c.y, dz = c.z, yaw = 90, pitch = 10}
			end
		end
	end
end

-- The sapling platform.
local sapling_at = {}
local function build_saplings()
	local c = spots.S
	if not c then log("grow: no wild column for the platform") return end
	local p1, p2 = {x = c.x - 20, y = SKY_Y - 2, z = c.z - 30},
		{x = c.x + 20, y = SKY_Y, z = c.z + 30}
	for x = p1.x, p2.x do
		for z = p1.z, p2.z do
			-- the kapok half (z > 0) ends at x = c.x - 2: ground falls away west
			if not (z > c.z + 4 and x < c.x - 2) then
				for y = p1.y, p2.y do
					core.set_node({x = x, y = y, z = z},
						{name = y == SKY_Y and "default:dirt_with_grass" or "default:dirt"})
				end
			end
		end
	end
	sapling_at.apple = {x = c.x, y = SKY_Y + 1, z = c.z - 14}
	sapling_at.kapok = {x = c.x, y = SKY_Y + 1, z = c.z + 14}
	core.set_node(sapling_at.apple, {name = "default:sapling"})
	core.set_node(sapling_at.kapok, {name = "default:emergent_jungle_sapling"})
	core.fix_light({x = c.x - 24, y = SKY_Y - 3, z = c.z - 34},
		{x = c.x + 24, y = SKY_Y + 34, z = c.z + 34})
	for key, pos in pairs(sapling_at) do
		local name = core.get_node(pos).name
		local can = default.can_grow(pos)
		local ok = grug_trees.growth.grow(pos, name)
		local logs, apples, roots = 0, 0, 0
		for _, found in ipairs(core.find_nodes_in_area({x = pos.x - 8, y = pos.y - 1, z = pos.z - 8},
				{x = pos.x + 8, y = pos.y + 30, z = pos.z + 8}, {"group:tree"})) do
			logs = logs + 1
			if found.y == pos.y and (math.abs(found.x - pos.x) > 1 or math.abs(found.z - pos.z) > 1) then
				roots = roots + 1
			end
		end
		for _, found in ipairs(core.find_nodes_in_area({x = pos.x - 8, y = pos.y, z = pos.z - 8},
				{x = pos.x + 8, y = pos.y + 30, z = pos.z + 8}, {"default:apple"})) do
			if core.get_node(found).param2 == 0 then apples = apples + 1 end
		end
		log(("grow %s: can_grow %s, grown %s, wood %d, ground-level wood off the trunk %d, " ..
			"natural apples %d"):format(key, tostring(can), tostring(ok), logs, roots, apples))
	end
	SHOTS[#SHOTS + 1] = {name = "S1_grown_saplings", spot = "S", dx = 34, dy = 12, dz = 0,
		yaw = 90, pitch = 12, first = true}
	SHOTS[#SHOTS + 1] = {name = "S2_kapok_roots", spot = "S", dx = 9, dy = 3, dz = 14,
		yaw = 90, pitch = 14}
end

local function filter_shots()
	local kept = {}
	for _, shot in ipairs(SHOTS) do
		for prefix in FILTER:gmatch("[^,]+") do
			if shot.name:sub(1, #prefix) == prefix then
				kept[#kept + 1] = shot
				break
			end
		end
	end
	SHOTS = kept
end

local function camera_of(shot)
	local s = spots[shot.spot]
	return {x = s.x + shot.dx, y = s.y + 1 + shot.dy, z = s.z + shot.dz}, shot.yaw, shot.pitch
end

---------------------------------------------------------------------------
-- The driver (lane TA's, from the Round 46 TREE probe)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r47tc_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function hide_hud(player)
	player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false,
		wielditem = false, breathbar = false, minimap = false, minimap_radar = false,
		basic_debug = false, chat = false})
	for id in pairs(player:hud_get_all() or {}) do
		player:hud_remove(id)
	end
	player:set_clouds({density = 0})
	player:set_properties({is_visible = false, show_on_minimap = false,
		visual_size = {x = 0, y = 0, z = 0}})
end

local function clear_objects(center)
	for _, object in ipairs(core.get_objects_inside_radius(center, 80)) do
		if not object:is_player() then object:remove() end
	end
end

local function hold(player, shot)
	local pos, yaw, pitch = camera_of(shot)
	player:set_pos({x = pos.x, y = pos.y - 1.625, z = pos.z})
	player:set_look_horizontal(math.rad(yaw))
	player:set_look_vertical(math.rad(pitch))
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
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		local pos = vector.round(player:get_pos())
		origin = {x = pos.x, y = pos.y - 1, z = pos.z}
		spots.T = origin
		log("character complete at " .. core.pos_to_string(pos))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		local started = core.get_us_time()
		if MODE == "greening" then
			for _, key in ipairs({"highcourt", "lethariel", "gor_drazhak"}) do
				local a = grug_core.settlement_socket_anchor(key)
				if a then
					spots["W_" .. key] = {x = a.x, y = a.y, z = a.z}
					log("spot W_" .. key .. " at " .. core.pos_to_string(a))
				end
			end
		elseif MODE == "groves" then
			-- the first grove or copse socket of three capitals, and
			-- Hearthpine's anchor
			for _, row in ipairs({{"lethariel", "G1_lethariel_grove"},
					{"highcourt", "G2_highcourt_grove"}, {"nhal_veyr", "G3_nhal_veyr_copse"}}) do
				for _, socket in ipairs(grug_core.settlement_sockets_at(row[1]) or {}) do
					if socket.id:match("grove") or socket.id:match("copse") then
						spots[row[2]] = vector.round(socket.pos)
						spots[row[2]].y = spots[row[2]].y - 1
						log("spot " .. row[2] .. " " .. socket.id .. " at " ..
							core.pos_to_string(spots[row[2]]))
						break
					end
				end
			end
			local hp = grug_core.settlement_socket_anchor("hearthpine")
			if hp then spots.G4_hearthpine = hp end
		else
			find_spots()
			-- the sapling platform's sky over the first forest's wild column
			local base = spots.F1_apple_aspen or spots.F2_silverwood
			if base then spots.S = {x = base.x, y = SKY_Y, z = base.z} end
		end
		log(("spot search %.1f s"):format((core.get_us_time() - started) / 1e6))
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 0
		for label, s in pairs(spots) do
			state.pending = state.pending + 1
			local r = MODE == "greening" and label ~= "T" and 200 or 44
			core.emerge_area({x = s.x - r, y = s.y - 8, z = s.z - r},
				{x = s.x + r, y = s.y + 44, z = s.z + r}, function(_, _, remaining)
					if remaining == 0 then
						state.pending = state.pending - 1
						log("emerged " .. label)
					end
				end)
		end
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		if MODE == "greening" then
			for _, key in ipairs({"highcourt", "lethariel", "gor_drazhak"}) do
				if spots["W_" .. key] then
					SHOTS[#SHOTS + 1] = {name = "W_" .. key .. "_wide", spot = "W_" .. key,
						dx = 150, dy = 85, dz = 0, yaw = 90, pitch = 26, first = true}
				end
			end
		elseif MODE == "groves" then
			for _, label in ipairs({"G1_lethariel_grove", "G2_highcourt_grove",
					"G3_nhal_veyr_copse"}) do
				if spots[label] then
					SHOTS[#SHOTS + 1] = {name = label, spot = label, dx = 22, dy = 16, dz = 0,
						yaw = 90, pitch = 32, first = true}
				end
			end
			if spots.G4_hearthpine then
				SHOTS[#SHOTS + 1] = {name = "G4_hearthpine", spot = "G4_hearthpine", dx = 60,
					dy = 45, dz = 0, yaw = 90, pitch = 35, first = true}
			end
		else
			add_forest_shots()
			build_saplings()
			SHOTS[#SHOTS + 1] = {name = "T1_start_town", spot = "T", dx = 45, dy = 40, dz = 0,
				yaw = 90, pitch = 38, first = true}
		end
		filter_shots()
		hide_hud(player)
		state.phase = "shoot"
		state.shot = 1
		state.waited = 0
		state.logged = false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		core.set_timeofday(TIME_OF_DAY)
		clear_objects(camera_of(shot))
		hold(player, shot)
		hide_hud(player)
		state.waited = state.waited + step
		local wait = shot.first and SETTLE * 2 or SETTLE
		if not state.logged and state.waited >= wait then
			state.logged = true
			log("SHOT " .. shot.name .. " at " ..
				core.pos_to_string(vector.round(camera_of(shot))))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited = 0
			state.logged = false
		end
	end
end)

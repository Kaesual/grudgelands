-- Disposable engine probe (Round 47 lane SW): the swamp in the world for
-- screenshots and the in-engine pool check. Never shipped:
-- tools/r47_sw/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, camera, SHOT /
-- ack handshake) is lane TA's / TC's probe's.
--
-- W1  the swamp spot with the most pool columns round it (a coarse grid over
--     the swamp, pools counted with the world's own rule, wp40/swamp_pools.lua
--     on the main environment's planner source and full seed): a wide view
--     from above and a close one at eye height, looking west (-x);
-- W2  a second swamp spot at least 400 nodes from the first, the same two
--     views (ground mix and swamp trees away from the first pools).
-- POOLCHECK (logged after the emerge and again after the shots): in each
-- spot's 88 x 88 area, the water sources standing in kept pool columns and
-- how many of them have air or flowing water on a side or below ("open"),
-- and every flowing water node of the area ("flowing"); both must be 0.

local P = "[r47sw] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r47sw_settle") or "") or 6
local FILTER = core.settings:get("r47sw_shots") or "W"
local TIME_OF_DAY = 0.42
local REACH = 44

local function log(msg) core.log("action", P .. msg) end

local spots, origin = {}, nil
local pools

local function find_spots()
	local wp40 = grug_mapgen.wp40
	local ps = wp40.planner_source
	pools = dofile(core.get_modpath("grug_mapgen") .. "/wp40/swamp_pools.lua")(
		wp40.full_seed, ps)
	local best, best_count, candidates = nil, -1, {}
	for z = -3200, 3200, 64 do
		for x = -3600, 3600, 64 do
			local water, _, _, biome, _, y = ps.column_values_at(x, z)
			if water == "land" and biome == "grug_swamp" and y >= 2 then
				local count = 0
				for dz = -24, 24, 2 do
					for dx = -24, 24, 2 do
						if pools.at(x + dx, z + dz) then count = count + 1 end
					end
				end
				candidates[#candidates + 1] = {x = x, y = y, z = z, count = count}
				if count > best_count then best, best_count = candidates[#candidates], count end
			end
		end
	end
	if not best then log("spot: no swamp found") return end
	spots.W1 = {x = best.x, y = best.y, z = best.z}
	log(("spot W1 %s with %d pool samples"):format(core.pos_to_string(spots.W1), best_count))
	for _, c in ipairs(candidates) do
		if math.abs(c.x - best.x) + math.abs(c.z - best.z) >= 400 and c.count > 0 then
			spots.W2 = {x = c.x, y = c.y, z = c.z}
			log(("spot W2 %s with %d pool samples"):format(core.pos_to_string(spots.W2), c.count))
			break
		end
	end
	if not spots.W2 and candidates[1] then
		local c = candidates[#candidates]
		spots.W2 = {x = c.x, y = c.y, z = c.z}
		log("spot W2 " .. core.pos_to_string(spots.W2) .. " (no pools)")
	end
end

-- The pool check of one spot.
local function pool_check(label, when)
	local s = spots[label]
	if not s then return end
	local minp = {x = s.x - REACH, y = s.y - 12, z = s.z - REACH}
	local maxp = {x = s.x + REACH, y = s.y + 16, z = s.z + REACH}
	local sources, open = 0, 0
	for _, p in ipairs(core.find_nodes_in_area(minp, maxp, {"default:water_source"})) do
		local level = pools.at(p.x, p.z)
		if level then
			sources = sources + 1
			for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}, {0, -1, 0}}) do
				local name = core.get_node({x = p.x + d[1], y = p.y + d[2], z = p.z + d[3]}).name
				local def = core.registered_nodes[name]
				if name == "air" or name == "default:water_flowing" or
						(name ~= "default:water_source" and def and def.walkable == false and
							d[2] < 0) then
					open = open + 1
					log(("open side at %s: %s"):format(core.pos_to_string(p), name))
				end
			end
		end
	end
	local flowing = #core.find_nodes_in_area(minp, maxp,
		{"default:water_flowing", "default:river_water_flowing"})
	local columns, tops = 0, {}
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			if pools.at(x, z) then columns = columns + 1 end
		end
	end
	for _, name in ipairs({"grug_nodes:mud", "grug_nodes:mud_dry", "grug_nodes:mud_mottled",
			"grug_nodes:mud_with_wet_grass", "grug_nodes:swamp_moss", "grug_nodes:reeds",
			"grug_nodes:cattails", "grug_nodes:mud_with_reeds", "grug_nodes:moss_carpet",
			"grug_mapgen:freshwater_waterlily", "grug_trees:gravewood_tree",
			"grug_trees:swamp_leaves", "grug_trees:swamp_hanging_moss"}) do
		tops[#tops + 1] = name:gsub("^.*:", "") .. "=" ..
			#core.find_nodes_in_area_under_air(minp, maxp, {name})
	end
	log(("POOLCHECK %s %s: pool columns %d, pool sources %d, open %d, flowing %d; under air: %s")
		:format(label, when, columns, sources, open, flowing, table.concat(tops, " ")))
end

local SHOTS = {}
local function add_shots()
	for _, label in ipairs({"W1", "W2"}) do
		if spots[label] then
			SHOTS[#SHOTS + 1] = {name = label .. "_wide", spot = label, dx = 34, dy = 26,
				dz = 0, yaw = 90, pitch = 32, first = true}
			SHOTS[#SHOTS + 1] = {name = label .. "_close", spot = label, dx = 12, dy = 4,
				dz = 0, yaw = 90, pitch = 12}
		end
	end
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
-- The driver (lane TA's and TC's)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r47sw_ack", "r")
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
		log("character complete at " .. core.pos_to_string(pos))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		local started = core.get_us_time()
		find_spots()
		log(("spot search %.1f s"):format((core.get_us_time() - started) / 1e6))
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 0
		for label, s in pairs(spots) do
			state.pending = state.pending + 1
			core.emerge_area({x = s.x - REACH, y = s.y - 16, z = s.z - REACH},
				{x = s.x + REACH, y = s.y + 40, z = s.z + REACH}, function(_, _, remaining)
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
		pool_check("W1", "after emerge")
		pool_check("W2", "after emerge")
		add_shots()
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
			pool_check("W1", "after the shots")
			pool_check("W2", "after the shots")
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

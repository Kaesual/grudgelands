-- Disposable engine probe (Round 51 TERRAIN T4): the land surfaces in the
-- world for the closing run and its screenshots. Never shipped:
-- tools/r51_t4/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, camera, SHOT /
-- ack handshake) is lane SW's probe's (tools/r47_sw/grug_probe_r47_sw).
--
-- The spots come from the setting r51t4_spots ("label:x:z,..."; labels
-- swamp, badlands, snowy, coast). Each is emerged 40 nodes round, then
-- "CHECK <label>" logs the surface nodes under air in that area; a badlands
-- spot then moves to the band nearest to its centre (a face to look at).
-- Shots per spot: <P>_wide from above and <P>_close at eye height, looking
-- west (-x); P is S, B, I or C.

local P = "[r51t4] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51t4_settle") or "") or 6
local FILTER = core.settings:get("r51t4_shots") or "S,B,I,C"
local SPOTS = core.settings:get("r51t4_spots") or ""
local TIME_OF_DAY = 0.42
local REACH = 40
local PREFIX = {swamp = "S", badlands = "B", snowy = "I", coast = "C"}
local BANDS = {"grug_nodes:clay_band_ochre", "grug_nodes:clay_band_sienna",
	"grug_nodes:clay_band_chalk", "grug_nodes:clay_band_umber"}
local COUNT = {
	swamp = {"grug_nodes:swamp_moss", "grug_nodes:dirt_with_moss", "grug_nodes:mud",
		"grug_nodes:mud_dry", "grug_nodes:mud_mottled", "grug_nodes:mud_with_wet_grass"},
	badlands = {"grug_nodes:clay_band_ochre", "grug_nodes:clay_band_sienna",
		"grug_nodes:clay_band_chalk", "grug_nodes:clay_band_umber", "grug_nodes:mesa_clay",
		"default:dry_dirt", "default:gravel", "default:stone"},
	snowy = {"default:ice", "default:snowblock", "default:snow", "default:gravel", "default:stone"},
	coast = {"default:sand", "default:gravel", "default:stone", "default:sandstone"},
}

local function log(msg) core.log("action", P .. msg) end

local spots, order = {}, {}
local function find_spots()
	local ps = grug_mapgen.wp40.planner_source
	for label, x, z in SPOTS:gmatch("(%a+):(%-?%d+):(%-?%d+)") do
		x, z = tonumber(x), tonumber(z)
		local _, _, _, biome, _, y = ps.column_values_at(x, z)
		spots[label] = {x = x, y = y, z = z, biome = biome}
		order[#order + 1] = label
		log(("spot %s %s biome %s"):format(label, core.pos_to_string(spots[label]), tostring(biome)))
	end
end

local function area(s)
	return {x = s.x - REACH, y = s.y - 40, z = s.z - REACH},
		{x = s.x + REACH, y = s.y + 40, z = s.z + REACH}
end

local function check(label)
	local s = spots[label]
	local minp, maxp = area(s)
	local parts = {}
	for _, name in ipairs(COUNT[label] or {}) do
		parts[#parts + 1] = name:gsub("^.*:", "") .. "=" ..
			#core.find_nodes_in_area_under_air(minp, maxp, {name})
	end
	if label == "badlands" then
		-- band nodes anywhere in the area (the faces below the tops too)
		parts[#parts + 1] = "bands_all=" .. #core.find_nodes_in_area(minp, maxp, BANDS)
	end
	log(("CHECK %s under air: %s"):format(label, table.concat(parts, " ")))
end

-- A badlands spot looks at the band nearest to its centre.
local function aim_badlands()
	local s = spots.badlands
	if not s then return end
	local minp, maxp = area(s)
	local best, best_d
	for _, p in ipairs(core.find_nodes_in_area(minp, maxp, BANDS)) do
		local d = (p.x - s.x) * (p.x - s.x) + (p.z - s.z) * (p.z - s.z)
		if not best_d or d < best_d then best, best_d = p, d end
	end
	if best then
		s.x, s.y, s.z = best.x, best.y, best.z
		log("spot badlands aims at the band at " .. core.pos_to_string(best))
	end
end

local SHOTS = {}
local function add_shots()
	for _, label in ipairs(order) do
		local prefix = PREFIX[label] or label
		SHOTS[#SHOTS + 1] = {name = prefix .. "_wide", spot = label, dx = 30, dy = 22,
			dz = 0, yaw = 90, pitch = 32, first = true}
		SHOTS[#SHOTS + 1] = {name = prefix .. "_close", spot = label, dx = 10, dy = 3,
			dz = 0, yaw = 90, pitch = 12}
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
-- The driver (lane SW's)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51t4_ack", "r")
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
		log("character complete at " .. core.pos_to_string(vector.round(player:get_pos())))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		find_spots()
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 0
		for _, label in ipairs(order) do
			local minp, maxp = area(spots[label])
			state.pending = state.pending + 1
			local started = core.get_us_time()
			core.emerge_area(minp, maxp, function(_, _, remaining)
				if remaining == 0 then
					state.pending = state.pending - 1
					log(("emerged %s in %.1f s"):format(label, (core.get_us_time() - started) / 1e6))
				end
			end)
		end
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		for _, label in ipairs(order) do check(label) end
		aim_badlands()
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

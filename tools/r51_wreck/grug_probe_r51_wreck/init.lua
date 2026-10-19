-- Disposable engine probe (Round 51 lane WRECK): the first in-game test of
-- the wrecks (sea plan §5a: "a mast on a test wreck") and their screenshots.
-- Never shipped: tools/r51_wreck/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, camera, SHOT / ack handshake) is lane SW's probe's.
--
-- The wrecks come from the setting r51wreck_sites, "key:x:y:z:w:d" joined by
-- ";" (corner, lowest seabed node and footprint size, as
-- tools/r51_wreck/count.lua prints them for the same seed). For each one,
-- after the emerge, WRECKCHECK logs the wreck nodes in its box, the air
-- nodes at or below the water level in the box and round it (an air pocket:
-- must be 0), the flowing water there (must be 0) and the masts with their
-- param2. DROPS logs what digging each wreck node gives. Shots per wreck:
--   <key>_boat   from a boat's height, 10 nodes off, looking down at it;
--   <key>_swim   a swimmer's view from the side at deck height;
--   <key>_mast   (the first wreck with a mast) level with the surface, the
--                mast crossing it.

local P = "[r51wreck] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51wreck_settle") or "") or 6
local TIME_OF_DAY = 0.5
local WATER_LEVEL = 1
local WRECK_NODES = {"grug_nodes:wreck_planks", "grug_nodes:wreck_planks_algae",
	"grug_nodes:wreck_log", "grug_nodes:wreck_mast", "grug_nodes:wreck_rope",
	"grug_nodes:wreck_sail", "grug_nodes:wreck_algae", "default:mossycobble"}

local function log(msg) core.log("action", P .. msg) end

local sites = {}
for entry in (core.settings:get("r51wreck_sites") or ""):gmatch("[^;]+") do
	local key, x, y, z, w, d = entry:match("^([%w_.]+):(%-?%d+):(%-?%d+):(%-?%d+):(%d+):(%d+)$")
	if key then
		sites[#sites + 1] = {key = key, x = tonumber(x), y = tonumber(y), z = tonumber(z),
			w = tonumber(w), d = tonumber(d), label = key:gsub("^wreck%.", "") .. #sites + 1}
	end
end

local function box(s, grow)
	return {x = s.x - grow, y = s.y - 3, z = s.z - grow},
		{x = s.x + s.w - 1 + grow, y = WATER_LEVEL + 12, z = s.z + s.d - 1 + grow}
end

local function check_site(s)
	local minp, maxp = box(s, 0)
	local found = core.find_nodes_in_area(minp, maxp, WRECK_NODES)
	local counts = {}
	for _, p in ipairs(found) do
		local name = core.get_node(p).name:gsub("^.*:", "")
		counts[name] = (counts[name] or 0) + 1
	end
	local parts = {}
	for _, name in ipairs(WRECK_NODES) do
		local short = name:gsub("^.*:", "")
		parts[#parts + 1] = short .. "=" .. (counts[short] or 0)
	end
	local gmin, gmax = box(s, 3)
	local low_max = {x = gmax.x, y = WATER_LEVEL, z = gmax.z}
	local air = #core.find_nodes_in_area(gmin, low_max, {"air"})
	local flowing = #core.find_nodes_in_area(gmin, gmax, {"default:water_flowing"})
	local masts = {}
	for _, p in ipairs(core.find_nodes_in_area(minp, maxp, {"grug_nodes:wreck_mast"})) do
		local node = core.get_node(p)
		masts[#masts + 1] = ("%s param2 %d (top %.1f, surface %.1f)"):format(
			core.pos_to_string(p), node.param2, p.y + 0.5 + node.param2 / 16, WATER_LEVEL + 0.5)
		s.mast = s.mast or p
	end
	s.total = #found
	log(("WRECKCHECK %s %s at %s: %d wreck nodes (%s); air at or below the water level %d; flowing water %d; masts: %s")
		:format(s.label, s.key, core.pos_to_string({x = s.x, y = s.y, z = s.z}), #found,
			table.concat(parts, " "), air, flowing, #masts > 0 and table.concat(masts, ", ") or "none"))
end

local function drops()
	for _, name in ipairs(WRECK_NODES) do
		local got = core.get_node_drops({name = name, param2 = 96}, "")
		log(("DROPS %s -> %s"):format(name, table.concat(got, ",")))
	end
end

local SHOTS = {}
local function look(from, at)
	local dx, dy, dz = at.x - from.x, at.y - from.y, at.z - from.z
	local yaw = math.atan2(-dx, dz)
	local pitch = -math.atan2(dy, math.sqrt(dx * dx + dz * dz))
	return yaw, pitch
end
local function add_shots()
	local mast_done = false
	for _, s in ipairs(sites) do
		local centre = {x = s.x + (s.w - 1) / 2, y = s.y + 3, z = s.z + (s.d - 1) / 2}
		local off = math.max(s.w, s.d) / 2 + 10
		local boat = {x = centre.x - off * 0.7, y = WATER_LEVEL + 7, z = centre.z - off * 0.7}
		SHOTS[#SHOTS + 1] = {name = s.label .. "_boat", pos = boat, at = {x = centre.x,
			y = s.y + 1, z = centre.z}, first = #SHOTS == 0}
		local swim = {x = centre.x + off, y = s.y + 4, z = centre.z + 3}
		SHOTS[#SHOTS + 1] = {name = s.label .. "_swim", pos = swim, at = centre}
		if s.mast and not mast_done then
			mast_done = true
			local m = s.mast
			SHOTS[#SHOTS + 1] = {name = s.label .. "_mast", pos = {x = m.x - 7, y = WATER_LEVEL + 1.2,
				z = m.z - 3}, at = {x = m.x, y = WATER_LEVEL, z = m.z}}
		end
	end
end

---------------------------------------------------------------------------
-- The driver (lane SW's, TA's and TC's)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51wreck_ack", "r")
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

local function hold(player, shot)
	local yaw, pitch = look(shot.pos, shot.at)
	player:set_pos({x = shot.pos.x, y = shot.pos.y - 1.625, z = shot.pos.z})
	player:set_look_horizontal(yaw)
	player:set_look_vertical(pitch)
	player:set_breath(10)
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
		log("character complete; " .. #sites .. " wrecks to visit")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		core.set_timeofday(TIME_OF_DAY)
		drops()
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 0
		for _, s in ipairs(sites) do
			state.pending = state.pending + 1
			local minp, maxp = box(s, 24)
			core.emerge_area(minp, maxp, function(_, _, remaining)
				if remaining == 0 then
					state.pending = state.pending - 1
					log("emerged " .. s.label)
				end
			end)
		end
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		for _, s in ipairs(sites) do check_site(s) end
		add_shots()
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
		for _, object in ipairs(core.get_objects_inside_radius(shot.pos, 60)) do
			if not object:is_player() then object:remove() end
		end
		hold(player, shot)
		hide_hud(player)
		state.waited = state.waited + step
		local wait = shot.first and SETTLE * 2 or SETTLE
		if not state.logged and state.waited >= wait then
			state.logged = true
			log("SHOT " .. shot.name .. " at " .. core.pos_to_string(vector.round(shot.pos)))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited = 0
			state.logged = false
		end
	end
end)

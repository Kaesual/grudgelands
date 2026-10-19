-- Disposable engine probe (Round 51 follow-up FW): the water plants in the
-- engine. Never shipped: tools/r51_fw/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, camera, SHOT / ack handshake) is lane LG's probe's,
-- as lane LP adapted it.
--
-- Scenes on seed 12345 (found with tools/r51_fw/lake_survey.lua and the
-- seabed renders of tools/r51_terrain/seabed_render.lua):
--   M1 the edge of a seagrass meadow in the belt off the Dawnmere coast
--      (348, -2885, 4 deep) from above; M2 the same from under the surface
--   K1a, K1b the tallest kelp stalk near it, from the side under water,
--      twice (the frames move; every node of the stalk shows the same one)
--   L1 the densest waterlily cluster in the lake chunks holding the most
--      wild lake water
-- Before each scene it counts the water plants round it ("COUNT"); at the
-- start it logs the animated special tiles the server registered ("TILE").

local P = "[r51fw] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51fw_settle") or "") or 6
local FILTER = core.settings:get("r51fw_shots") or "M,K,L"
local TIME_OF_DAY = 0.5
local function log(msg) core.log("action", P .. msg) end
local function wanted(name)
	for prefix in FILTER:gmatch("[^,]+") do
		if name:sub(1, #prefix) == prefix then return true end
	end
	return false
end

local MEADOW = {x = 348, z = -2885}
local LAKES = {{x = -1752, z = -152}, {x = -1752, z = 808}, {x = -152, z = 968}}
local SEAGRASS = {"grug_mapgen:seagrass_1", "grug_mapgen:seagrass_2", "grug_mapgen:seagrass_3"}
local COUNTED = {"grug_mapgen:seagrass_1", "grug_mapgen:seagrass_2", "grug_mapgen:seagrass_3",
	"default:sand_with_kelp", "grug_mapgen:freshwater_waterlily",
	"grug_mapgen:freshwater_waterweed", "default:coral_brown", "default:coral_cyan",
	"default:coral_green", "default:coral_orange", "default:coral_pink", "default:coral_skeleton"}

local function log_tiles()
	for _, name in ipairs({"grug_mapgen:seagrass_1", "grug_mapgen:seagrass_2",
			"grug_mapgen:seagrass_3", "default:sand_with_kelp", "grug_mapgen:freshwater_waterweed"}) do
		local def = core.registered_nodes[name]
		local tile = def and def.special_tiles and def.special_tiles[1]
		local a = type(tile) == "table" and tile.animation
		log(("TILE %s waving=%s tile=%s anim=%s"):format(name, tostring(def and def.waving),
			type(tile) == "table" and tostring(tile.name) or tostring(tile),
			a and ("%s %dx%d %.1fs"):format(a.type, a.aspect_w, a.aspect_h, a.length) or "none"))
	end
end

local state = {phase = "wait", clock = 0}
local SHOTS = {}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end
local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51fw_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end
local function hide_hud(player)
	player:hud_set_flags({hotbar = false, healthbar = false, crosshair = false,
		wielditem = false, breathbar = false, minimap = false, minimap_radar = false,
		basic_debug = false, chat = false})
	for id in pairs(player:hud_get_all() or {}) do player:hud_remove(id) end
	player:set_clouds({density = 0})
	player:set_properties({is_visible = false, show_on_minimap = false,
		visual_size = {x = 0, y = 0, z = 0}})
end
local function hold(player, shot)
	player:set_armor_groups({immortal = 1})
	if player:get_hp() < 20 then player:set_hp(20) end
	player:set_breath(10)
	player:set_pos({x = shot.pos.x, y = shot.pos.y - 1.625, z = shot.pos.z})
	player:set_look_horizontal(math.rad(shot.yaw))
	player:set_look_vertical(math.rad(shot.pitch))
end

local function count(label, minp, maxp)
	local _, found = core.find_nodes_in_area(minp, maxp, COUNTED)
	local parts = {}
	for _, name in ipairs(COUNTED) do
		if (found[name] or 0) > 0 then parts[#parts + 1] = name:gsub("^.*:", "") .. "=" .. found[name] end
	end
	log(("COUNT %s %s"):format(label, table.concat(parts, " ")))
end

-- The scenes, in order: each emerges its area, then `plan` adds its shots.
local SCENES = {}
SCENES[#SCENES + 1] = {name = "meadow", prefixes = {"M", "K"}, minp = {x = MEADOW.x - 40, y = -24,
	z = MEADOW.z - 40}, maxp = {x = MEADOW.x + 40, y = 24, z = MEADOW.z + 40},
	plan = function(scene)
		count("meadow", {x = MEADOW.x - 20, y = -20, z = MEADOW.z - 20},
			{x = MEADOW.x + 20, y = 2, z = MEADOW.z + 20})
		if wanted("M1") then
			SHOTS[#SHOTS + 1] = {name = "M1_meadow_top", pos = {x = MEADOW.x, y = 12, z = MEADOW.z - 7},
				yaw = 0, pitch = 70, first = true}
		end
		if wanted("M2") then
			SHOTS[#SHOTS + 1] = {name = "M2_meadow_under", pos = {x = MEADOW.x, y = 0.3, z = MEADOW.z - 9},
				yaw = 0, pitch = 32, first = true}
		end
		if wanted("K") then
			local kelp = core.find_nodes_in_area({x = MEADOW.x - 40, y = -20, z = MEADOW.z - 40},
				{x = MEADOW.x + 40, y = 0, z = MEADOW.z + 40}, {"default:sand_with_kelp"})
			local best, height = nil, 0
			for _, p in ipairs(kelp) do
				local h = core.get_node(p).param2 / 16
				if h > height or (h == height and best and (p.x < best.x or
						(p.x == best.x and p.z < best.z))) then best, height = p, h end
			end
			if best then
				log(("scene kelp at %s, %d tall"):format(core.pos_to_string(best), height))
				local eye = {x = best.x, y = best.y + 1 + height / 2, z = best.z - 5}
				if eye.y > 0.3 then eye.y = 0.3 end
				SHOTS[#SHOTS + 1] = {name = "K1a_kelp", pos = eye, yaw = 0, pitch = 5, first = true}
				SHOTS[#SHOTS + 1] = {name = "K1b_kelp", pos = eye, yaw = 0, pitch = 5, quick = true}
			else
				log("scene kelp: none found")
			end
		end
	end}
for i, lake in ipairs(LAKES) do
	SCENES[#SCENES + 1] = {name = "lake" .. i, prefixes = {"L"},
		minp = {x = lake.x - 40, y = 40, z = lake.z - 40},
		maxp = {x = lake.x + 40, y = 200, z = lake.z + 40},
		plan = function(scene)
			count(scene.name, scene.minp, scene.maxp)
			local lilies = core.find_nodes_in_area(scene.minp, scene.maxp,
				{"grug_mapgen:freshwater_waterlily"})
			local best, around = nil, 0
			for _, p in ipairs(lilies) do
				local n = #core.find_nodes_in_area(vector.subtract(p, {x = 5, y = 0, z = 5}),
					vector.add(p, {x = 5, y = 0, z = 5}), {"grug_mapgen:freshwater_waterlily"})
				if n > around then best, around = p, n end
			end
			if best and (not state.lake or around > state.lake.around) then
				state.lake = {pos = best, around = around}
			end
			if i == #LAKES and state.lake and wanted("L1") then
				local p = state.lake.pos
				log(("scene lilies at %s, %d within 5"):format(core.pos_to_string(p), state.lake.around))
				SHOTS[#SHOTS + 1] = {name = "L1_lake_lilies", pos = {x = p.x, y = p.y + 7, z = p.z - 10},
					yaw = 0, pitch = 33, first = true}
			end
		end}
end

local function scene_wanted(scene)
	for _, prefix in ipairs(scene.prefixes) do
		if FILTER:find(prefix, 1, true) then return true end
	end
	return false
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
		hide_hud(player)
		log_tiles()
		state.phase = "next"
		state.scene = 0
		log("READY")
	elseif state.phase == "next" then
		state.scene = state.scene + 1
		local scene = SCENES[state.scene]
		if not scene then
			state.phase = "shoot"
			state.shot, state.waited, state.logged = 1, 0, false
			return
		end
		if not scene_wanted(scene) then return end
		-- stand near the scene while it emerges (the client loads it too)
		hold(player, {pos = {x = (scene.minp.x + scene.maxp.x) / 2, y = scene.maxp.y,
			z = (scene.minp.z + scene.maxp.z) / 2}, yaw = 0, pitch = 0})
		state.pending = true
		state.started = core.get_us_time()
		core.emerge_area(scene.minp, scene.maxp, function(_, _, remaining)
			if remaining == 0 then state.pending = false end
		end)
		state.phase = "emerge"
	elseif state.phase == "emerge" then
		if state.pending then return end
		local scene = SCENES[state.scene]
		log(("scene %s emerged in %.1f s"):format(scene.name, (core.get_us_time() - state.started) / 1e6))
		scene.plan(scene)
		state.phase = "next"
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		core.set_timeofday(TIME_OF_DAY)
		hold(player, shot)
		hide_hud(player)
		state.waited = state.waited + step
		local wait = shot.quick and 1.5 or (shot.first and SETTLE * 3 or SETTLE)
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

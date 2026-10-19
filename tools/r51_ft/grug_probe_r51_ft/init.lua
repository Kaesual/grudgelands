-- Disposable engine probe (Round 51 follow-up lane FT): the towns after the
-- user's GUI look, for screenshots and counts. Never shipped:
-- tools/r51_ft/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, camera,
-- SHOT / ack handshake) is lane LK's probe's (tools/r51_lk), from lane TC's.
--
-- Scenes round a settlement's anchor (grug_core.settlement_socket_anchor),
-- each an emerged box and its camera poses {dx, dy, dz, yaw, pitch} from the
-- anchor (yaw 0 looks north, +z; 90 west; 180 south; 270 east). Per scene:
--   count  the trees' logs, the ground cover (grass, ferns, shrubs, flowers),
--          the bones of the skeleton set, the lily pads and waterweeds;
--   float  a plant whose node below is air or a liquid, a lily pad not on
--          water (must be none).
-- A lake scene's camera stands over the lake's middle (`lake`, a world
-- x/z), at the water's height read once the area is emerged.

local P = "[r51ft] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51ft_settle") or "") or 6
local TIME_OF_DAY = 0.42

local function log(msg) core.log("action", P .. msg) end

local SCENES = {
	{label = "S1_hearthpine", key = "hearthpine", r = 64,
		shots = {{"wide", 50, 34, 0, 90, 32}, {"ground", 30, 4, 30, 135, 12}}},
	{label = "S2_stillgrave", key = "stillgrave", r = 64,
		shots = {{"wide", 50, 36, 0, 90, 34}, {"outside", -8, 4, 48, 160, 14},
			{"burial_ground", 38, 6, 0, 0, 20}}},
	{label = "C1_nhal_veyr_core", key = "nhal_veyr", r = 60,
		shots = {{"wide", 46, 30, 0, 90, 32}, {"ground", 30, 4, 30, 135, 12}}},
	{label = "C2_kezamba_core", key = "kezamba", r = 60,
		shots = {{"wide", -46, 30, -20, 270, 32}, {"ground", -30, 4, -30, 315, 12}}},
	{label = "O1_nhal_veyr_city", key = "nhal_veyr", r = 140, inner = 54,
		shots = {{"east", 60, 22, 0, 270, 26}, {"south", 0, 22, -60, 180, 26}}},
	{label = "O2_highcourt_city", key = "highcourt", r = 140, inner = 54,
		shots = {{"east", 60, 22, 0, 270, 26}, {"west", -60, 22, 0, 90, 26}}},
	{label = "L1_kezamba_lake", key = "kezamba", r = 120, inner = 54, lake = {x = 1890, z = 1585},
		shots = {{"lake", 0, 14, -24, 0, 34}}},
	{label = "L2_lethariel_lake", key = "lethariel", r = 120, inner = 54, lake = {x = 1880, z = -1400},
		shots = {{"lake", 0, 14, -24, 0, 34}}},
}

local COVER, BONES = {}, {}
for _, name in ipairs({"default:grass_1", "default:grass_2", "default:grass_3", "default:grass_4",
		"default:grass_5", "default:fern_1", "default:fern_2", "default:fern_3",
		"default:dry_shrub", "default:dry_grass_1", "default:dry_grass_2", "default:dry_grass_3",
		"default:dry_grass_4", "default:dry_grass_5", "default:junglegrass",
		"grug_nodes:flower_blush_star", "grug_nodes:flower_cream_cups",
		"grug_nodes:flower_lilac_bells", "grug_nodes:flower_ruby_fan",
		"grug_nodes:flower_ember_star", "grug_nodes:flower_violet_fan"}) do
	COVER[#COVER + 1] = name
end
for _, name in ipairs({"grug_nodes:bone_pile", "grug_nodes:skull_human", "grug_nodes:ribcage_human",
		"grug_nodes:skull_horned", "grug_nodes:spine_animal", "grug_nodes:bones_fragments"}) do
	BONES[#BONES + 1] = name
end
local LILY, WEED = "grug_mapgen:freshwater_waterlily", "grug_mapgen:freshwater_waterweed"
local LOGS = {"default:tree", "default:pine_tree", "default:acacia_tree", "default:jungletree",
	"default:aspen_tree", "grug_trees:silverwood_tree", "grug_trees:gravewood_tree"}

local order, centers = {}, {}

local function find_spots()
	for _, scene in ipairs(SCENES) do
		local a = grug_core.settlement_socket_anchor(scene.key)
		if a then
			local c = scene.lake and {x = scene.lake.x, y = a.y, z = scene.lake.z} or a
			centers[scene.label] = c
			order[#order + 1] = scene
			log("spot " .. scene.label .. " at " .. core.pos_to_string(c))
		else
			log("spot " .. scene.label .. " missing: no anchor for " .. scene.key)
		end
	end
end

local function liquid(name)
	local def = core.registered_nodes[name]
	return def and def.liquidtype and def.liquidtype ~= "none"
end

local SHOTS = {}
local function survey(scene)
	local c, r = centers[scene.label], scene.r
	local p1, p2 = {x = c.x - r, y = c.y - 30, z = c.z - r}, {x = c.x + r, y = c.y + 40, z = c.z + r}
	local inner = scene.inner
	local function counted(p)
		return not inner or math.abs(p.x - c.x) > inner or math.abs(p.z - c.z) > inner
	end
	-- (a lake scene's inner box is its capital's core: anchor-centred)
	if scene.lake then
		local a = grug_core.settlement_socket_anchor(scene.key)
		counted = function(p) return math.abs(p.x - a.x) > inner or math.abs(p.z - a.z) > inner end
	end
	local n = {cover = 0, bones = 0, lily = 0, weed = 0, logs = 0, floating = 0}
	for _, p in ipairs(core.find_nodes_in_area(p1, p2, COVER)) do
		if counted(p) then
			n.cover = n.cover + 1
			local below = core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
			if below == "air" or liquid(below) then
				n.floating = n.floating + 1
				log("float " .. scene.label .. " " .. core.get_node(p).name .. " at " .. core.pos_to_string(p))
			end
		end
	end
	for _, p in ipairs(core.find_nodes_in_area(p1, p2, BONES)) do
		if counted(p) then n.bones = n.bones + 1 end
	end
	local water_y
	for _, p in ipairs(core.find_nodes_in_area(p1, p2, {LILY})) do
		if counted(p) then
			n.lily = n.lily + 1
			local below = core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
			if not liquid(below) then
				n.floating = n.floating + 1
				log("float " .. scene.label .. " lily on " .. below .. " at " .. core.pos_to_string(p))
			end
			water_y = water_y or p.y - 1
		end
	end
	for _, p in ipairs(core.find_nodes_in_area(p1, p2, {WEED})) do
		if counted(p) then n.weed = n.weed + 1 end
	end
	for _, p in ipairs(core.find_nodes_in_area(p1, p2, LOGS)) do
		local below = core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
		if counted(p) and not below:find("tree", 1, true) then n.logs = n.logs + 1 end
	end
	log(("count %s: %d x %d columns%s: trees %d, cover %d, bones %d, lily pads %d, weeds %d, " ..
		"floating %d"):format(scene.label, 2 * r + 1, 2 * r + 1,
		inner and (" outside the core's +-" .. inner) or "", n.logs, n.cover, n.bones, n.lily,
		n.weed, n.floating))
	local base_y = c.y
	if scene.lake then
		-- the camera stands over the lake's surface
		local probe = {x = c.x, y = c.y + 20, z = c.z}
		for y = c.y + 20, c.y - 30, -1 do
			probe.y = y
			local name = core.get_node(probe).name
			if name ~= "air" then base_y = y break end
		end
	end
	for index, s in ipairs(scene.shots) do
		SHOTS[#SHOTS + 1] = {name = scene.label .. "_" .. s[1],
			pos = {x = c.x + s[2], y = base_y + s[3], z = c.z + s[4]},
			yaw = s[5], pitch = s[6], first = index == 1}
	end
end

---------------------------------------------------------------------------
-- The driver (lane LK's, from lane TC's)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51ft_ack", "r")
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
	player:set_pos({x = shot.pos.x, y = shot.pos.y - 1.625, z = shot.pos.z})
	player:set_look_horizontal(math.rad(shot.yaw))
	player:set_look_vertical(math.rad(shot.pitch))
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
		for _, scene in ipairs(order) do
			local c, r = centers[scene.label], scene.r
			state.pending = state.pending + 1
			local t0 = core.get_us_time()
			core.emerge_area({x = c.x - r, y = c.y - 30, z = c.z - r},
				{x = c.x + r, y = c.y + 40, z = c.z + r}, function(_, _, remaining)
					if remaining == 0 then
						state.pending = state.pending - 1
						log(("emerged %s (%.1f s after its request)"):format(scene.label,
							(core.get_us_time() - t0) / 1e6))
						-- survey at once: an emerged area unloads again when
						-- nobody is near it
						survey(scene)
					end
				end)
		end
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		hide_hud(player)
		state.phase = "shoot"
		state.shot = 1
		state.waited = 0
		state.logged = false
		log("READY " .. #SHOTS .. " shots")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		core.set_timeofday(TIME_OF_DAY)
		clear_objects(shot.pos)
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

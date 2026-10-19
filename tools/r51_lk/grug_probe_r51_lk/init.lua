-- Disposable engine probe (Round 51 lane LK): the land kit in the world for
-- screenshots and counts. Never shipped: tools/r51_lk/capture.sh stages it
-- through tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, camera, SHOT / ack handshake) is lane TC's probe's
-- (tools/r47_tc/grug_probe_r47_tc).
--
-- Per kit biome the first column of a coarse grid in that biome that is
-- land and gentle (the ground 12 nodes away within 4); Stillgrave's anchor
-- for a town graveyard. Each area (RADIUS round it) is emerged, then, as
-- soon as it is (it unloads again when nobody is near):
--   count  every kit node in it, per name;
--   float  every prop whose node below is air (must be none);
--   shots  a wide view from above and up to CLOSE close views of distinct
--          kit structures (the nearest prop or kit block of each kind).

local P = "[r51lk] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51lk_settle") or "") or 6
local RADIUS = tonumber(core.settings:get("r51lk_radius") or "") or 120
local CLOSE = tonumber(core.settings:get("r51lk_close") or "") or 3
local TIME_OF_DAY = 0.42

local function log(msg) core.log("action", P .. msg) end

local SCENES = {
	{"grug_bone_forest", "U1_bone_forest"},
	{"grug_blight", "U2_blight"},
	{"grug_crags", "D1_crags"},
	{"grug_crags_snowy", "D2_crags_snowy"},
	{"grug_pine_hills", "D3_pine_hills"},
	{"grug_badlands", "O1_badlands"},
	{"grug_elf_forest", "E1_elf_forest"},
	{"grug_deep_jungle", "J1_deep_jungle"},
}

-- The kit's node names (grug_nodes props and cairn shapes); a close view
-- looks for the first of each structure's marker names.
local KIT = {}
for name, def in pairs(core.registered_nodes) do
	if name:match("^grug_nodes:") and def.drawtype == "nodebox" and
			not name:find("camp_fire", 1, true) and not name:find("guard_banner", 1, true) and
			not name:find("carpet", 1, true) and not name:find("driftwood", 1, true) then
		KIT[#KIT + 1] = name
	end
end
table.sort(KIT)
local MARKERS = {"grug_nodes:gravestone_stele", "grug_nodes:statue_mourner_base",
	"grug_nodes:statue_mourner_upper", "grug_nodes:obelisk_broken_tip",
	"grug_nodes:statue_broken_torso", "grug_nodes:cairn_cap", "grug_nodes:cairn_branch",
	"grug_nodes:skull_human", "grug_nodes:skull_horned", "grug_nodes:ribcage_human",
	"grug_nodes:gravestone_cross", "grug_nodes:gravestone_sunken", "default:stone_block",
	"default:stonebrick", "default:silver_sandstone_brick", "default:mossycobble",
	"grug_trees:gravewood_branch", "default:jungletree", "grug_trees:silverwood_tree"}

local spots = {}
local order = {}

local function find_spots()
	local ps = grug_mapgen.wp40.planner_source
	local want = {}
	for _, row in ipairs(SCENES) do want[row[1]] = row[2] end
	local function ground(x, z)
		local water, _, _, biome, _, terrain_y = ps.column_values_at(x, z)
		return water, biome, terrain_y
	end
	for z = -3600, 3600, 48 do
		for x = -4000, 4000, 48 do
			local water, biome, y = ground(x, z)
			local label = want[biome]
			if label and not spots[label] and water == "land" and y >= 3 then
				local gentle = true
				for _, d in ipairs({{12, 0}, {-12, 0}, {0, 12}, {0, -12}}) do
					local w2, b2, y2 = ground(x + d[1], z + d[2])
					if w2 ~= "land" or b2 ~= biome or math.abs(y2 - y) > 4 then gentle = false end
				end
				if gentle then
					spots[label] = {x = x, y = y, z = z}
					log("spot " .. label .. " " .. biome .. " at " .. core.pos_to_string(spots[label]))
				end
			end
		end
	end
	for _, row in ipairs(SCENES) do
		if spots[row[2]] then order[#order + 1] = row[2] end
	end
	local town = grug_core.settlement_socket_anchor("stillgrave")
	if town then
		spots.T1_stillgrave = town
		order[#order + 1] = "T1_stillgrave"
		log("spot T1_stillgrave at " .. core.pos_to_string(town))
	end
end

local SHOTS = {}
local function camera_of(shot)
	return shot.pos, shot.yaw, shot.pitch
end

-- A camera `dist` east of p (looking west), a few heights, in free air.
local function close_camera(p, dist)
	for _, dz in ipairs({0, 2, -2, 4, -4}) do
		for _, dy in ipairs({2, 3, 5}) do
			local cam = {x = p.x + dist, y = p.y + dy, z = p.z + dz}
			if core.get_node(cam).name == "air" and
					core.get_node({x = cam.x, y = cam.y - 1, z = cam.z}).name == "air" then
				return cam
			end
		end
	end
	return nil
end

local function survey(label)
	local s = spots[label]
	local r = label == "T1_stillgrave" and 60 or RADIUS
	local p1, p2 = {x = s.x - r, y = s.y - 30, z = s.z - r}, {x = s.x + r, y = s.y + 40, z = s.z + r}
	local counts, floating, total = {}, 0, 0
	local found = core.find_nodes_in_area(p1, p2, KIT)
	for _, p in ipairs(found) do
		local name = core.get_node(p).name
		counts[name] = (counts[name] or 0) + 1
		total = total + 1
		local below = core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
		if below == "air" then
			floating = floating + 1
			log("float " .. label .. " " .. name .. " at " .. core.pos_to_string(p))
		end
	end
	local names = {}
	for name in pairs(counts) do names[#names + 1] = name end
	table.sort(names)
	local parts = {}
	for _, name in ipairs(names) do parts[#parts + 1] = name:gsub("^grug_nodes:", "") .. "=" .. counts[name] end
	log(("count %s: %d kit nodes in %d x %d columns, %d floating: %s"):format(label, total,
		2 * r + 1, 2 * r + 1, floating, table.concat(parts, " ")))
	-- shots: wide, then the nearest structure of each marker kind
	SHOTS[#SHOTS + 1] = {name = label .. "_wide", pos = {x = s.x + 40, y = s.y + 32, z = s.z},
		yaw = 90, pitch = 30, first = true}
	local closes, used = 0, {}
	for _, marker in ipairs(MARKERS) do
		if closes >= CLOSE then break end
		local near, near_d
		local list = marker:match("^grug_nodes:") and found or
			core.find_nodes_in_area(p1, p2, {marker})
		for _, p in ipairs(list) do
			if core.get_node(p).name == marker then
				local d = math.abs(p.x - s.x) + math.abs(p.z - s.z)
				local fresh = true
				for _, q in ipairs(used) do
					if math.abs(q.x - p.x) + math.abs(q.z - p.z) < 12 then fresh = false end
				end
				if fresh and (not near or d < near_d) and
						(marker:match("^grug_nodes:") or core.get_node(
							{x = p.x, y = p.y + 1, z = p.z}).name ~= "air" or
							marker:find("tree", 1, true)) then
					near, near_d = p, d
				end
			end
		end
		if near then
			local cam = close_camera(near, 6)
			if cam then
				used[#used + 1] = near
				closes = closes + 1
				log("close " .. label .. " " .. marker .. " at " .. core.pos_to_string(near))
				SHOTS[#SHOTS + 1] = {name = label .. "_close" .. closes, pos = cam, yaw = 90,
					pitch = 14}
			end
		end
	end
end

---------------------------------------------------------------------------
-- The driver (lane TC's)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51lk_ack", "r")
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
		local started = core.get_us_time()
		find_spots()
		log(("spot search %.1f s"):format((core.get_us_time() - started) / 1e6))
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 0
		for _, label in ipairs(order) do
			local s = spots[label]
			local r = label == "T1_stillgrave" and 60 or RADIUS
			state.pending = state.pending + 1
			local t0 = core.get_us_time()
			core.emerge_area({x = s.x - r, y = s.y - 30, z = s.z - r},
				{x = s.x + r, y = s.y + 40, z = s.z + r}, function(_, _, remaining)
					if remaining == 0 then
						state.pending = state.pending - 1
						log(("emerged %s (%.1f s after its request)"):format(label,
							(core.get_us_time() - t0) / 1e6))
						-- survey at once: an emerged area unloads again when
						-- nobody is near it (server_unload_unused_data_timeout)
						survey(label)
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

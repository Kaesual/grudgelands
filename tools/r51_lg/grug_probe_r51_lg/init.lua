-- Disposable engine probe (Round 51 lane LG): the engine look of the 2 x 2
-- grounds and the hanging moss dig rule, once (round plan §5). Never
-- shipped: tools/r51_lg/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, camera, SHOT / ack handshake) is lane SW's probe's.
--
-- A test patch in the sky above the spawn (full daylight, no terrain in the
-- way), every patch 8 x 8 nodes and 2 deep with a gap of 1 (the sides show):
--   row 0  wet grass, wet mud, plain mud, dry mud           (G1 wide, G1 close)
--   row 1  swamp moss, forest moss, silver litter, bone litter       (G2)
--   row 2  canopy litter, blight dirt, mesa clay, a swamp mix        (G3)
--          (every node a seeded pick of the swamp's six grounds: seams)
--   row 3  a wall of the four clay bands (2 high each) beside mesa clay (C1),
--          a sand basin, water 2 deep over one half and 1 deep over the
--          other, dry sand on its rim (S1), and a 3-node hanging moss run
--          (strand, strand, end) under a swamp leaf (M1), whose end the
--          probe digs as the player through core.node_dig (the builtin dig
--          and the node's own after_dig_node) before shooting it again (M2).
--          "DIG" logs the run before and after.

local P = "[r51lg] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51lg_settle") or "") or 6
local FILTER = core.settings:get("r51lg_shots") or "G,C,S,M"
local TIME_OF_DAY = 0.5

local function log(msg) core.log("action", P .. msg) end

local B -- the patch's origin (south-west corner of row 0, top layer)
local STRAND, TIP = "grug_trees:swamp_hanging_moss_strand", "grug_trees:swamp_hanging_moss"
local ROWS = {
	{"grug_nodes:mud_with_wet_grass", "grug_nodes:mud_mottled", "grug_nodes:mud", "grug_nodes:mud_dry"},
	{"grug_nodes:swamp_moss", "grug_nodes:dirt_with_moss", "grug_nodes:dirt_with_silver_litter",
		"grug_nodes:dirt_with_bone_litter"},
	{"grug_nodes:dirt_with_canopy_litter", "grug_nodes:blight_dirt", "grug_nodes:mesa_clay", "mix"},
}
local MIX = {"grug_nodes:mud_with_wet_grass", "grug_nodes:mud_mottled", "grug_nodes:mud",
	"grug_nodes:mud_dry", "grug_nodes:swamp_moss", "grug_nodes:dirt_with_moss"}
local ROW_Z = {0, 14, 28}
local WALL_Z = 52
local moss_at = {}

local function at(dx, dy, dz) return {x = B.x + dx, y = B.y + dy, z = B.z + dz} end

local function build()
	local put = {}
	local function set(p, name)
		put[name] = put[name] or {}
		put[name][#put[name] + 1] = p
	end
	for r, row in ipairs(ROWS) do
		for i, name in ipairs(row) do
			for x = 0, 7 do
				for z = 0, 7 do
					local n = name
					if n == "mix" then
						n = MIX[(x * 7 + z * 13 + (x * z) % 5) % #MIX + 1]
					end
					for y = -1, 0 do set(at((i - 1) * 9 + x, y, ROW_Z[r] + z), n) end
				end
			end
		end
	end
	-- the wall: four bands of two below the top, beside mesa clay; 2 thick
	local BANDS = {"umber", "chalk", "sienna", "ochre"}
	for x = 0, 15 do
		for y = -7, 0 do
			for z = 0, 1 do
				local name = "grug_nodes:mesa_clay"
				if x < 8 then name = "grug_nodes:clay_band_" .. BANDS[math.floor((y + 7) / 2) + 1] end
				set(at(x, y, WALL_Z + z), name)
			end
		end
	end
	-- the basin: 12 x 12, a sand floor at -2, a rim of 2 at -1 and 0
	for x = 20, 31 do
		for z = WALL_Z - 4, WALL_Z + 7 do
			set(at(x, -2, z), "default:sand")
			local rim = x < 22 or x > 29 or z < WALL_Z - 2 or z > WALL_Z + 5
			if rim then
				set(at(x, -1, z), "default:sand")
				set(at(x, 0, z), "default:sand")
			else
				set(at(x, -1, z), x < 26 and "default:water_source" or "default:sand")
				set(at(x, 0, z), "default:water_source")
			end
		end
	end
	-- the hanging moss run under a small leaf pad
	for dx = -1, 1 do
		for dz = -1, 1 do set(at(40 + dx, 6, WALL_Z + 2 + dz), "grug_trees:swamp_leaves") end
	end
	moss_at = {at(40, 5, WALL_Z + 2), at(40, 4, WALL_Z + 2), at(40, 3, WALL_Z + 2)}
	set(moss_at[1], STRAND)
	set(moss_at[2], STRAND)
	set(moss_at[3], TIP)
	local count = 0
	local names = {}
	for name in pairs(put) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		core.bulk_set_node(put[name], {name = name, param2 = 1})
		count = count + #put[name]
	end
	log(("patch built at %s: %d nodes"):format(core.pos_to_string(B), count))
end

local function run_names()
	local list = {}
	for i = 0, 4 do
		local p = {x = moss_at[1].x, y = moss_at[1].y + 1 - i, z = moss_at[1].z}
		list[#list + 1] = (p.y - B.y) .. "=" .. core.get_node(p).name:gsub("^.*:", "")
	end
	return table.concat(list, " ")
end

local SHOTS = {
	{name = "G1_swamp_wide", cam = {17, 13, -13}, yaw = 0, pitch = 37, first = true},
	{name = "G1_swamp_close", cam = {12, 4, -3}, yaw = 0, pitch = 32},
	{name = "G2_moss_litter", cam = {17, 13, 1}, yaw = 0, pitch = 37},
	{name = "G3_litter_clay_mix", cam = {17, 13, 15}, yaw = 0, pitch = 37},
	{name = "C1_clay_bands", cam = {8, -3, WALL_Z - 11}, yaw = 0, pitch = 8},
	{name = "S1_sand_water", cam = {26, 9, WALL_Z - 10}, yaw = 0, pitch = 40},
	{name = "M1_moss_before", cam = {40, 4, WALL_Z - 2}, yaw = 0, pitch = 5},
	{name = "M2_moss_end_dug", cam = {40, 4, WALL_Z - 2}, yaw = 0, pitch = 5, dig = true},
}

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
	return at(shot.cam[1], shot.cam[2], shot.cam[3]), shot.yaw, shot.pitch
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
	local file = io.open(core.get_worldpath() .. "/r51lg_ack", "r")
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
		log("character complete at " .. core.pos_to_string(pos))
		-- the patch lies 50 above the ground where the player may dig (away
		-- from the start's protection)
		for _, off in ipairs({{-17, 20}, {300, 0}, {0, 300}, {-300, 0}, {0, -300}, {600, 0}}) do
			B = {x = pos.x + off[1], y = pos.y + 50, z = pos.z + off[2]}
			if not core.is_protected(at(40, 3, WALL_Z + 2), NAME) then break end
		end
		log("patch origin " .. core.pos_to_string(B) .. ", protected for the player: " ..
			tostring(core.is_protected(at(40, 3, WALL_Z + 2), NAME)))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		core.set_timeofday(TIME_OF_DAY)
		state.phase = "emerge"
		state.pending = true
		state.emerge_started = core.get_us_time()
		core.emerge_area(at(-16, -24, -24), at(64, 24, 72), function(_, _, remaining)
			if remaining == 0 then state.pending = false end
		end)
	elseif state.phase == "emerge" then
		if state.pending then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		build()
		log("DIG before: " .. run_names())
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
		if shot.dig and not state.dug then
			state.dug = true
			-- the builtin dig as the player (the mining wrapper included);
			-- core.dig_node would pass the hand's hold rule (grug_abilities),
			-- which refuses a dig no button holds
			local ok = core.node_dig(moss_at[3], core.get_node(moss_at[3]), player)
			log("DIG the end (" .. tostring(ok) .. "): " .. run_names())
		end
		core.set_timeofday(TIME_OF_DAY)
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

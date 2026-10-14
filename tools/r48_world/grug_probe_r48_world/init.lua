-- Disposable engine probe (Round 48 lane WORLD): the mailbox on the twelve
-- waystone pads in a real world, for the review screenshots. Never shipped:
-- tools/r48_world/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, camera, SHOT /
-- ack handshake) is lane TC's (tools/r47_tc/grug_probe_r47_tc).
--
-- Per pad (the `travel_waypoint` socket of the six starts and six capitals,
-- from the grug_core registry): only a small area round the stone is
-- emerged; then one CHECK line (the waystone in the socket's cell, exactly one
-- mailbox within 6 nodes, at the stone + (2, 0, 1), its param2, the
-- settlement whose waypoint socket lies within three nodes of it and that
-- settlement's label) and one shot, from the pad's -x/+z side looking at the
-- mailbox's front.

local P = "[r48world] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r48world_settle") or "") or 5
local TIME_OF_DAY = 0.5
local MAILBOX = "grug_mapgen:mailbox"
local KEYS = {"hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar", "kapok",
	"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}
-- the camera from the stone's ground cell, and the point it looks at
local CAMERA = {x = -5, y = 4, z = 5}
local TARGET = {x = 1.5, y = 1.3, z = 0.6}

local function log(msg) core.log("action", P .. msg) end

local pads = {}    -- {key, label, stone}
local SHOTS = {}

local function find_pads()
	local labels = {}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		labels[row.key] = row.display_name or row.key
	end
	for index, key in ipairs(KEYS) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(key)) do
			if socket.id == "travel_waypoint" and socket.role == "waypoint" then
				pads[#pads + 1] = {key = key, label = labels[key], index = index,
					stone = vector.round(socket.pos)}
			end
		end
	end
	log("pads " .. #pads)
end

-- The settlements whose waypoint socket lies within three nodes of pos.
local function resolve(pos)
	local found = {}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		if row.slot == "start" or row.slot == "capital" then
			for _, socket in ipairs(grug_core.settlement_sockets_at(row.key)) do
				local p = socket.pos
				if socket.role == "waypoint" and math.abs(p.y - pos.y) < 0.5 and
						math.max(math.abs(p.x - pos.x), math.abs(p.z - pos.z)) <= 3 then
					found[#found + 1] = row.display_name or row.key
				end
			end
		end
	end
	return table.concat(found, "|")
end

local function check_pad(pad)
	local s = pad.stone
	local stone = core.get_node(s).name
	local found = core.find_nodes_in_area(vector.subtract(s, 6), vector.add(s, 6), {MAILBOX})
	local want = {x = s.x + 2, y = s.y, z = s.z + 1}
	local at = core.get_node(want)
	local ok = stone == "grug_mapgen:waystone" and #found == 1 and
		vector.equals(found[1], want) and at.param2 == 1
	local names = #found == 1 and resolve(found[1]) or "-"
	ok = ok and names == pad.label
	log(("CHECK %s %s: stone %s, mailboxes %d, at +2,+1 %s param2 %d, resolves to %s"):format(
		ok and "PASS" or "FAIL", pad.key, stone, #found, at.name, at.param2, names))
	return ok
end

local function camera_of(shot)
	local s = shot.pad.stone
	local eye = {x = s.x + CAMERA.x, y = s.y - 1 + 1 + CAMERA.y, z = s.z + CAMERA.z}
	local t = {x = s.x + TARGET.x, y = s.y - 1 + TARGET.y, z = s.z + TARGET.z}
	local dx, dy, dz = t.x - eye.x, t.y - eye.y, t.z - eye.z
	-- the look direction is (-sin yaw, ., cos yaw); pitch positive looks down
	local yaw = math.atan2(-dx, dz)
	local pitch = math.atan2(-dy, math.sqrt(dx * dx + dz * dz))
	return eye, yaw, pitch
end

---------------------------------------------------------------------------
-- The driver (lane TC's, from the Round 46 TREE probe)
---------------------------------------------------------------------------

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r48world_ack", "r")
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
	for _, object in ipairs(core.get_objects_inside_radius(center, 60)) do
		if not object:is_player() then object:remove() end
	end
end

local function hold(player, shot)
	local pos, yaw, pitch = camera_of(shot)
	player:set_pos({x = pos.x, y = pos.y - 1.625, z = pos.z})
	player:set_look_horizontal(yaw)
	player:set_look_vertical(pitch)
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
		player:set_armor_groups({immortal = 1})
		core.set_timeofday(TIME_OF_DAY)
		find_pads()
		state.phase = "emerge"
		state.emerge_started = core.get_us_time()
		state.pending = 0
		for _, pad in ipairs(pads) do
			state.pending = state.pending + 1
			local s = pad.stone
			core.emerge_area({x = s.x - 16, y = s.y - 8, z = s.z - 16},
				{x = s.x + 16, y = s.y + 16, z = s.z + 16}, function(_, _, remaining)
					if remaining == 0 then
						state.pending = state.pending - 1
						log("emerged " .. pad.key)
					end
				end)
		end
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		log(string.format("emerge done in %.1f s",
			(core.get_us_time() - state.emerge_started) / 1e6))
		local passed = 0
		for _, pad in ipairs(pads) do
			if check_pad(pad) then passed = passed + 1 end
			SHOTS[#SHOTS + 1] = {name = ("%02d_%s"):format(pad.index, pad.key), pad = pad}
		end
		log(("CHECK %d of %d pads pass"):format(passed, #pads))
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
		if not state.logged and state.waited >= SETTLE * 2 then
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

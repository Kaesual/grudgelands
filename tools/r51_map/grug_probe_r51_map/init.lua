-- Disposable engine probe (Round 51 lane MAP): the sea coloured by depth on
-- the map window and the minimap, for screenshots. Never shipped:
-- tools/r51_map/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) is the 0.50.2 CMAP probe's.
--
-- After the character is made (Accord, Human, Warrior) the probe finds, by
-- the water query on a 32-node grid nearest to the start first, a bay
-- middle (BAY: a bay column 150 or more nodes off the coast), a channel
-- (CHANNEL), the belt's outer edge (EDGE: a belt column 250 or more off the
-- coast next to the open sea) and a coast (COAST: a belt column 30-60 nodes
-- off the coast). It shows the map window at 1x (the whole map), then at 4x
-- centred on BAY, CHANNEL and EDGE, then closes it and shows the minimap at
-- COAST and EDGE. For each shot it waits SETTLE seconds and logs "SHOT
-- <name>" and a CHECK line (the spot's water query).
local P = "[r51map] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r51map_settle") or "") or 7
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r51map_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

-- The spots, nearest to `from` first, on a 32-node grid over the atlas.
local function find_spots(from)
	local view = grug_map.atlas.view()
	local rows = {}
	for z = view.min_z + 64, view.max_z - 64, 32 do
		for x = view.min_x + 64, view.max_x - 64, 32 do
			local dx, dz = x - from.x, z - from.z
			rows[#rows + 1] = {x = x, z = z, d = dx * dx + dz * dz}
		end
	end
	table.sort(rows, function(a, b) return a.d < b.d end)
	local Q = grug_zones.water_query_at
	local spots = {}
	for _, row in ipairs(rows) do
		if spots.bay and spots.channel and spots.edge and spots.coast then break end
		local class, _, _, distance = Q(row.x, row.z)
		if class == "bay" and distance >= 150 and not spots.bay then
			spots.bay = row
		elseif class == "channel" and not spots.channel then
			spots.channel = row
		elseif class == "belt" and distance >= 250 and not spots.edge and
				(Q(row.x + 64, row.z) == "open_sea" or Q(row.x - 64, row.z) == "open_sea" or
				Q(row.x, row.z + 64) == "open_sea" or Q(row.x, row.z - 64) == "open_sea") then
			spots.edge = row
		elseif class == "belt" and distance >= 30 and distance <= 60 and not spots.coast then
			spots.coast = row
		end
	end
	return spots
end

local SHOTS = {
	{name = "M1_map_world", window = true, zoom = 1},
	{name = "M2_map_bay", window = true, zoom = 4, spot = "bay"},
	{name = "M3_map_channel", window = true, zoom = 4, spot = "channel"},
	{name = "M4_map_belt_edge", window = true, zoom = 4, spot = "edge"},
	{name = "M5_minimap_coast", spot = "coast"},
	{name = "M6_minimap_belt_edge", spot = "edge"},
}

local function place(player, spot)
	player:set_pos({x = spot.x + 0.5, y = 12, z = spot.z + 0.5})
end

local function show(player, shot)
	local spot = shot.spot and state.spots[shot.spot]
	if spot then place(player, spot) end
	if shot.window then
		-- opened at 1x, then zoomed in step by step around the player (the
		-- soft lock centres each step on the player's position)
		grug_map.window.open(player)
		local zoom = 1
		while zoom < shot.zoom do
			grug_map.window.handle_fields(player, {grug_map_zoom_in = "+"})
			zoom = zoom * 2
		end
	else
		core.close_formspec(NAME, grug_map.window.FORMNAME)
		grug_map.minimap.set_enabled(player, true)
	end
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
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local at = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(at))
		local spots = find_spots(at)
		state.spots = {}
		for _, key in ipairs({"bay", "channel", "edge", "coast"}) do
			local spot = spots[key] or {x = at.x, z = at.z}
			state.spots[key] = spot
			log(("spot %s %s at %d,%d"):format(key, spots[key] and "found" or "MISSING",
				spot.x, spot.z))
		end
		log(("quality %s, minimap available: %s"):format(grug_map.base.quality(),
			tostring(grug_map.minimap.available())))
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			local pos = vector.round(player:get_pos())
			local class, zone, level, distance, depth, protected =
				grug_zones.water_query_at(pos.x, pos.z)
			log(("SHOT %s"):format(shot.name))
			log(("CHECK %s: at %d,%d %s zone %s level %s, %s off the coast, %s deep, protected %s"):format(
				shot.name, pos.x, pos.z, tostring(class), tostring(zone), tostring(level),
				tostring(distance and math.floor(distance)), tostring(depth and math.floor(depth)),
				tostring(protected)))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)

-- Disposable engine probe (fix 0.53.1 lane FLIGHT): the minimap's no-fly
-- overlay, for screenshots. Never shipped: tools/r531_flight/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) is the 0.50.2 CMAP
-- probe's.
--
-- After the character is made (Accord, Human, Warrior) the probe finds,
-- near the start, a column the Accord may fly over with enemy land 24 nodes
-- off in one of eight directions (BORDER) and one with ocean 24 nodes off
-- (COAST), using the flight rule itself (grug_mounts.column_flight_state).
-- For each shot it moves the player, mounts the Master flyer 20 nodes above
-- the ground, a ground mount on it or nothing, waits SETTLE seconds and logs
-- "SHOT <name>" and a CHECK line (flight mode, no-fly tiles in the cell
-- texture, the flight warning's text).
local P = "[r531flight] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r531flight_settle") or "") or 7
local FACTION = "accord"
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r531flight_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function rule(x, z)
	return grug_mounts.column_flight_state(FACTION, x, z)
end

-- Flyable land columns on a 16-node grid, nearest to `from` first, with a
-- refused column of the wanted kind 24 nodes off in one of eight directions.
local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {0.7, 0.7}, {0.7, -0.7}, {-0.7, 0.7},
	{-0.7, -0.7}}
local function find_spots(from)
	local rows = {}
	for z = -3500, 3500, 16 do
		for x = -4000, 4000, 16 do
			local dx, dz = x - from.x, z - from.z
			rows[#rows + 1] = {x = x, z = z, d = dx * dx + dz * dz}
		end
	end
	table.sort(rows, function(a, b) return a.d < b.d end)
	local found = {}
	for _, row in ipairs(rows) do
		if found.enemy and found.ocean then break end
		local x, z = row.x, row.z
		if rule(x, z) and grug_zones.water_class_at(x, z) == "land" then
			for _, dir in ipairs(DIRS) do
				local legal, kind = rule(x + dir[1] * 24, z + dir[2] * 24)
				if not legal and not found[kind] and (kind == "enemy" or kind == "ocean") then
					found[kind] = {x = x, z = z}
				end
			end
		end
	end
	return found.enemy, found.ocean
end

local SHOTS = {
	{name = "F1_flyer_border", spot = "border", mount = 4},
	{name = "F2_flyer_coast", spot = "coast", mount = 4},
	{name = "F3_ground_mount_border", spot = "border", mount = 2},
	{name = "F4_on_foot_border", spot = "border"},
}

local function show(player, shot)
	grug_mounts.dismount(player, nil, true)
	local spot = state.spots[shot.spot]
	local ground = math.max(grug_zones.terrain_height_at(spot.x, spot.z), 1)
	local pos = {x = spot.x + 0.5, y = ground + (shot.mount == 4 and 20 or 1.5), z = spot.z + 0.5}
	player:set_pos(pos)
	if shot.mount then
		local ok, err = grug_mounts.spawn_entity(player, shot.mount, pos)
		log(("%s: mount %d %s"):format(shot.name, shot.mount, ok and "ok" or tostring(err)))
	end
end

local function warning_text(player)
	for _, def in pairs(player:hud_get_all()) do
		if type(def.text) == "string" and def.text:find("^Flight boundary") then return def.text end
	end
	return "none"
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
		local at = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(at))
		local border, coast = find_spots(at)
		log(("spots: border %s, coast %s"):format(border and (border.x .. "," .. border.z) or "none",
			coast and (coast.x .. "," .. coast.z) or "none"))
		state.spots = {border = border or {x = at.x, z = at.z}, coast = coast or border or
			{x = at.x, z = at.z}}
		log(("minimap available: %s"):format(tostring(grug_map.minimap.available())))
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			grug_mounts.dismount(player, nil, true)
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			local texture = grug_map.minimap.texture_of(player) or ""
			local tiles = 0
			for _ in texture:gmatch("grug_map_flight_") do tiles = tiles + 1 end
			log(("SHOT %s"):format(shot.name))
			log(("CHECK %s: flying %s, flight mode %s, %d no-fly tiles in the cell texture, " ..
				"warning %q, at %s"):format(shot.name, tostring(grug_mounts.is_flying(player)),
				tostring(grug_map.minimap.flight_of(player)), tiles, warning_text(player),
				core.pos_to_string(vector.round(player:get_pos()))))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)

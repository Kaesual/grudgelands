-- Disposable engine probe (Round 70 capitals): a capital's castle in the real
-- engine. Never shipped: tools/r70_cap/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver follows
-- tools/r70_towns's probe.
--
-- Checks, logged as "check ...": the patrol legs through the route cache
-- (grug_mobs.route_walk on a real guard, one leg after the other, each until
-- the cache has decided it), the engine's path from the seat to the great door,
-- the king and the guards' sockets, the core's nodes at the throne.

local P = "[r70cap] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r70cap_settle") or "") or 3
local CAPITAL = core.settings:get("r70cap_capital") or "dur_brannoc"
local APPROACH = tonumber(core.settings:get("r70cap_approach") or "") or 62

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r70cap_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function sockets(key)
	local by_id, anchor = {}, nil
	for _, socket in ipairs(grug_core.settlement_sockets_at(key)) do
		by_id[socket.id] = socket
		anchor = anchor or vector.subtract(socket.pos, vector.new(socket.x, socket.y, socket.z))
	end
	return by_id, anchor
end

local function view(player, from, to)
	player:set_pos(from)
	local eye = vector.offset(from, 0, 1.5, 0)
	local dx, dy, dz = to.x - eye.x, to.y - eye.y, to.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end

local function castle_shots(by_id)
	local king = by_id.king
	local dir = king.dir or {x = 0, z = -1}
	local function along(n, y)
		return vector.offset(king.pos, dir.x * n, y, dir.z * n)
	end
	local throne = along(-2, 3)
	local function time(value) return function() core.set_timeofday(value) end end
	local function shots(tag, value)
		return {
			{name = CAPITAL .. "_approach_" .. tag, setup = time(value), run = function(p)
				view(p, along(APPROACH, 1), along(0, 12))
			end},
			{name = CAPITAL .. "_hall_" .. tag, run = function(p)
				view(p, along(23, 0), throne)
			end},
			{name = CAPITAL .. "_throne_" .. tag, run = function(p)
				view(p, along(9, 0), throne)
			end},
		}
	end
	local list = shots("day", 0.5)
	for _, shot in ipairs(shots("night", 0.0)) do list[#list + 1] = shot end
	return list
end

-- Every leg of every patrol group of the core, in order. The district plots'
-- watch stays out: its legs lie beyond the emerged area.
local function patrol_legs(by_id)
	local groups, names = {}, {}
	for _, socket in pairs(by_id) do
		if socket.role == "guard_patrol" and socket.group and
				math.max(math.abs(socket.x), math.abs(socket.z)) <= 57 then
			if not groups[socket.group] then
				groups[socket.group] = {}
				names[#names + 1] = socket.group
			end
			table.insert(groups[socket.group], socket)
		end
	end
	table.sort(names)
	local legs = {}
	for _, name in ipairs(names) do
		local list = groups[name]
		table.sort(list, function(a, b) return a.order < b.order end)
		for index, socket in ipairs(list) do
			local nxt = list[index % #list + 1]
			legs[#legs + 1] = {group = name, a = socket, b = nxt}
		end
	end
	return legs
end

-- The patrolling guard nearest the anchor: the shots may have unloaded one.
local function find_guard(anchor)
	local best, near
	for _, object in ipairs(core.get_objects_inside_radius(anchor, 70)) do
		local entity = object:get_luaentity()
		if entity and entity.name and entity.name:find("guard", 1, true) and
				entity._grug_patrol_route then
			local distance = vector.distance(object:get_pos(), anchor)
			if not near or distance < near then best, near = entity, distance end
		end
	end
	return best
end

local function census(anchor, by_id)
	local names = {}
	for _, object in ipairs(core.get_objects_inside_radius(anchor, 90)) do
		local entity = object:get_luaentity()
		if entity and entity.name then
			names[entity.name] = (names[entity.name] or 0) + 1
			if entity.name:find("king", 1, true) or entity.name:find("royal", 1, true) then
				local pos = object:get_pos()
				log(("check entity %s at %s, hp %s"):format(entity.name,
					core.pos_to_string(vector.round(pos)), tostring(entity.health)))
			end
		end
	end
	local list = {}
	for name, count in pairs(names) do list[#list + 1] = name .. "=" .. count end
	table.sort(list)
	log("check census " .. table.concat(list, " "))
	local king = by_id.king.pos
	local door_guard = by_id.door_guard_west.pos
	local dir = by_id.king.dir or {x = 0, z = -1}
	-- Six nodes past the door guards along the hall's axis, on the ground.
	local along = (door_guard.x - king.x) * dir.x + (door_guard.z - king.z) * dir.z + 6
	local front = vector.offset(king, dir.x * along, door_guard.y - 2 - king.y, dir.z * along)
	local path = core.find_path(king, front, 64, 1, 4, "A*_noprefetch")
	log(("check engine path seat %s to the door's front %s: %s"):format(
		core.pos_to_string(king), core.pos_to_string(front),
		path and (#path .. " points") or "NONE"))
	for _, id in ipairs({"king", "throne_guard_west", "throne_guard_east", "door_guard_west",
			"door_guard_east"}) do
		local pos = by_id[id].pos
		log(("check socket %s %s feet %s head %s under %s"):format(id, core.pos_to_string(pos),
			core.get_node(pos).name, core.get_node(vector.offset(pos, 0, 1, 0)).name,
			core.get_node(vector.offset(pos, 0, -1, 0)).name))
	end
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.phase == "legs" and state.guard then
		-- The leg through the real cache, on the real guard's body: each step
		-- until its cache entry has decided (the guard's own patrol shares
		-- the slot, so the entry is read right after the call).
		local leg, guard = state.legs[state.leg], state.guard
		local pos = guard.object and guard.object:get_pos()
		if not pos then
			guard = find_guard(state.anchor) or guard
			state.guard = guard
			pos = guard.object and guard.object:get_pos()
		end
		if leg and pos then
			local ok, err = pcall(grug_mobs.route_walk, guard, dtime, pos, CAPITAL, leg.a.pos,
				leg.b.pos, "r70cap", true)
			if not ok and not state.complained then
				state.complained = true
				log("route_walk: " .. tostring(err))
			end
			local held = guard.temp and guard.temp.grug_leg
			if held and held.owner == "r70cap" then state.entry = held.entry end
		end
	end
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local by_id, anchor = sockets(CAPITAL)
		state.by_id, state.anchor = by_id, anchor
		log("capital " .. CAPITAL .. " anchor " .. core.pos_to_string(anchor))
		player:set_pos(vector.offset(anchor, 0, 12, 0))
		local t0 = core.get_us_time()
		state.phase = "emerging"
		core.emerge_area(vector.offset(anchor, -72, -8, -72), vector.offset(anchor, 72, 44, 72),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				log(("emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
				state.phase = "settle"
				state.waited = 0
			end)
	elseif state.phase == "settle" then
		-- The settlement's NPCs are placed as the blocks go active.
		state.waited = state.waited + step
		if state.waited >= 25 then
			census(state.anchor, state.by_id)
			state.phase = "shots"
		end
	elseif state.phase == "legs" then
		state.waited = state.waited + step
		local leg = state.legs[state.leg]
		if not leg then
			log("check route cache " .. core.write_json(grug_mobs.route_cache_stats(CAPITAL) or {}))
			log("shutdown")
			state.phase = "done"
			core.request_shutdown("probe done", false, 0)
			return
		end
		local entry = state.entry
		if entry and not (entry.a.x == leg.a.pos.x and entry.a.z == leg.a.pos.z and
				entry.b.x == leg.b.pos.x and entry.b.z == leg.b.pos.z) then
			entry = nil
		end
		if entry and entry.state ~= "pending" or state.waited >= 15 then
			log(("check leg %s %s -> %s %.0f nodes: %s, %d corners"):format(leg.group, leg.a.id,
				leg.b.id, vector.distance(leg.a.pos, leg.b.pos),
				entry and entry.state or "UNDECIDED",
				entry and #entry.points or 0))
			state.leg, state.waited, state.entry = state.leg + 1, 0, nil
		end
	elseif state.phase == "shots" then
		state.shots = castle_shots(state.by_id)
		state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
		state.phase = "shoot"
	elseif state.phase == "shoot" then
		local shot = state.shots[state.shot]
		if not shot then
			core.set_timeofday(0.5)
			player:set_pos(vector.offset(state.anchor, 0, 12, 0))
			state.guard = find_guard(state.anchor)
			log("check patrol guard " .. tostring(state.guard and state.guard.name))
			state.legs = state.guard and patrol_legs(state.by_id) or {}
			state.leg, state.waited = 1, 0
			log("check legs " .. #state.legs)
			state.phase = "legs"
			return
		end
		if not state.ran then
			state.ran = true
			if shot.setup then shot.setup() end
			local ok, err = pcall(shot.run, player)
			log("run " .. shot.name .. ": " .. (ok and "ok" or tostring(err)))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)

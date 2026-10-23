-- Disposable engine probe (Round 58 lane TOWNFIX): views of the town fixes for
-- screenshots. Never shipped: tools/r58_townfix/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r57_qsys's probe.
--
-- An elf of The Accord starts at Silverleaf: its centre with the waystone,
-- the mailbox and the Quartermaster, and a terrace house's stair. Then
-- Lethariel's core is emerged: the south gatehouse's inner stair from its
-- door and from the first floor, the deck with its opening and the city side
-- with the two watch guards below, the east bough platform, and the king
-- with his throne guards. Each shot logs where the NPCs it shows stand.

local P = "[r58townfix] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r58townfix_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r58townfix_ack", "r")
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

local function holder(key, id, pos)
	for _, object in ipairs(core.get_objects_inside_radius(pos, 24)) do
		local entity = object:get_luaentity()
		if entity and entity._grug_start == key and entity._grug_socket == id then return entity end
	end
end

-- Stand (feet) at `from` and look at `to`.
local function view(player, from, to)
	player:set_pos(from)
	local eye = vector.offset(from, 0, 1.5, 0)
	local dx, dy, dz = to.x - eye.x, to.y - eye.y, to.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end

local function where(key, id, socket)
	local entity = socket and holder(key, id, socket.pos)
	if not entity then return id .. " absent" end
	local p = entity.object:get_pos()
	local dx, dz = p.x - socket.pos.x, p.z - socket.pos.z
	return ("%s at %s, %.1f m from its socket"):format(id, core.pos_to_string(vector.round(p)),
		math.sqrt(dx * dx + dz * dz))
end

local SIL, LET = {}, {}
local function at(anchor, x, y, z) return vector.add(anchor, vector.new(x, y, z)) end

local function watch_log()
	local ids = {"gate_south_watch_west_1", "gate_south_watch_east_1", "gate_south_deck"}
	local out = {}
	for _, id in ipairs(ids) do
		local entity = holder("lethariel", id, LET.s[id].pos)
		local p = entity and entity.object:get_pos()
		out[#out + 1] = id .. "=" .. (p and core.pos_to_string(vector.subtract(vector.round(p),
			LET.a)) or "absent")
	end
	log("watch (local) " .. table.concat(out, " "))
end

local SHOTS = {
	{name = "S1_silverleaf_waystone", run = function(player)
		local stone, vendor = SIL.s.travel_waypoint, SIL.s.court_vendor
		view(player, at(SIL.a, 15, 4, -10), vector.offset(vector.multiply(
			vector.add(stone.pos, vendor.pos), 0.5), 0, 0.5, 0))
	end, after = function()
		local stone, vendor = SIL.s.travel_waypoint, SIL.s.court_vendor
		log(("waystone %s (local %d,%d), mailbox %s, %s"):format(core.pos_to_string(stone.pos),
			stone.x, stone.z, core.get_node(vector.offset(stone.pos, 2, 0, 1)).name,
			where("silverleaf", "court_vendor", vendor)))
	end},
	{name = "S2_silverleaf_terrace_stair", run = function(player)
		view(player, at(SIL.a, -24, 2, -28), at(SIL.a, -19, 2.5, -20))
		local treads = {}
		for z = -23, -19 do
			treads[#treads + 1] = z .. ":" .. core.get_node(at(SIL.a, -19, 0, z)).name:gsub("^.*:", "") ..
				"/" .. core.get_node(at(SIL.a, -19, 1, z)).name:gsub("^.*:", "") ..
				"/" .. core.get_node(at(SIL.a, -19, 2, z)).name:gsub("^.*:", "") ..
				"/" .. core.get_node(at(SIL.a, -19, 3, z)).name:gsub("^.*:", "")
		end
		log("terrace west column x -19, y 0..3: " .. table.concat(treads, " "))
	end},
	-- The south gatehouse stands at (-6, -49) unturned: its frame is the
	-- capital's, shifted.
	{name = "G1_gate_stair_from_landing", run = function(player)
		view(player, at(LET.a, 4.4, 3.5, -47.7), at(LET.a, 4.6, 2.2, -44))
	end},
	{name = "G2_gate_stairwell_first_floor", run = function(player)
		view(player, at(LET.a, 1, 8.5, -47.5), at(LET.a, 4, 5, -46))
	end},
	{name = "G3_gate_deck_opening", run = function(player)
		view(player, at(LET.a, -2, 16, -48.5), at(LET.a, -2.5, 11, -44))
	end, after = watch_log},
	{name = "G4_gate_watch", run = function(player)
		view(player, at(LET.a, 0, 13, -29), at(LET.a, 0, 1, -40))
	end, after = function()
		watch_log()
		log(where("lethariel", "gate_south_deck", LET.s.gate_south_deck))
	end},
	{name = "L1_bough_east_platform", run = function(player)
		view(player, at(LET.a, 54, 9, -12), at(LET.a, 42, 6, -17))
	end},
	{name = "L2_royal_guards", run = function(player)
		local king = LET.s.king
		local from = vector.add(king.pos, vector.new(king.dir.x * 9, 1, king.dir.z * 9))
		view(player, from, vector.offset(king.pos, 0, 0.6, 0))
	end, after = function()
		local king = LET.s.king
		for _, id in ipairs({"king", "throne_guard_west", "throne_guard_east"}) do
			log(where("lethariel", id, LET.s[id]))
		end
		local k = holder("lethariel", "king", king.pos)
		local kp = k and k.object:get_pos()
		for _, id in ipairs({"throne_guard_west", "throne_guard_east"}) do
			local g = holder("lethariel", id, LET.s[id].pos)
			local gp = g and g.object:get_pos()
			if kp and gp then
				log(("%s %.1f m from the king, follow %s, no_wander %s"):format(id,
					vector.distance({x = gp.x, y = 0, z = gp.z}, {x = kp.x, y = 0, z = kp.z}),
					tostring(g.temp and g.temp.grug_royal_follow_active), tostring(g._grug_no_wander)))
			end
		end
	end},
}

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
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		SIL.s, SIL.a = sockets("silverleaf")
		LET.s, LET.a = sockets("lethariel")
		log("anchors silverleaf " .. core.pos_to_string(SIL.a) .. " lethariel " ..
			core.pos_to_string(LET.a))
		state.phase = "emerge"
		core.emerge_area(vector.offset(SIL.a, -40, -6, -40), vector.offset(SIL.a, 40, 16, 40),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				log("READY silverleaf")
			end)
	elseif state.phase == "lethariel" then
		state.phase = "emerging"
		local t0 = core.get_us_time()
		player:set_pos(at(LET.a, 0, 14, -30))
		core.emerge_area(vector.offset(LET.a, -56, -6, -56), vector.offset(LET.a, 56, 36, 56),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				log(("lethariel emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
				state.phase = "npcs"
				state.waited = 0
			end)
	elseif state.phase == "npcs" then
		-- The capital's NPCs appear once their blocks are active and the
		-- heartbeat has served them; the royal guards walk to their posts.
		state.waited = state.waited + step
		player:set_pos(at(LET.a, 0, 14, -30))
		local need = {"king", "throne_guard_west", "throne_guard_east", "gate_south_watch_west_1",
			"gate_south_watch_east_1", "gate_south_deck"}
		local missing = {}
		for _, id in ipairs(need) do
			if not holder("lethariel", id, LET.s[id].pos) then missing[#missing + 1] = id end
		end
		if (#missing == 0 and state.waited > 12) or state.waited > 60 then
			log(("NPCs after %.1f s, missing: %s"):format(state.waited, table.concat(missing, ",")))
			state.phase = "shoot"
			state.waited, state.logged, state.ran = 0, false, false
			log("READY lethariel")
		end
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if shot.name:sub(1, 1) ~= "S" and state.where ~= "lethariel" then
			state.where = "lethariel"
			state.phase = "lethariel"
			return
		end
		if not state.ran then
			state.ran = true
			local ok, err = pcall(shot.run, player)
			log("run " .. shot.name .. ": " .. (ok and "ok" or tostring(err)))
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			if shot.after then
				local ok, err = pcall(shot.after)
				if not ok then log("after " .. shot.name .. ": " .. tostring(err)) end
			end
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)

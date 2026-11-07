-- Disposable engine probe (Round 70 lane TOWNS): two views of each start town
-- from its arrival, and one generated waypost with its text. Never shipped:
-- tools/r70_towns/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver follows tools/r58_townfix's probe.

local P = "[r70towns] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r70towns_settle") or "") or 3
local TOWNS = {"hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar", "kapok"}
-- The road side of each town, the way a walker comes in.
local GATE = {hearthpine = 1, dawnmere = 1, silverleaf = 1, stillgrave = -1, sunscar = -1, kapok = -1}

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0, town = 1}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r70towns_ack", "r")
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

-- Stand (feet) at `from` and look at `to`.
local function view(player, from, to)
	player:set_pos(from)
	local eye = vector.offset(from, 0, 1.5, 0)
	local dx, dy, dz = to.x - eye.x, to.y - eye.y, to.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end

local function town_shots(key)
	local by_id, anchor = sockets(key)
	local stone = by_id.travel_waypoint.pos
	local sign = GATE[key]
	return {
		-- Over the spawn, from the gate side: the square, the pocket beside it.
		{name = key .. "_1_arrival", run = function(player)
			view(player, vector.offset(anchor, 0, 7, sign * 26), vector.offset(stone, 0, 0, 0))
		end},
		-- From the arrival beside the stone, across the centre.
		{name = key .. "_2_waystone", run = function(player)
			view(player, vector.offset(stone, 1, 1.5, 0), vector.offset(anchor, 0, 3, 0))
		end},
	}
end

local function waypost_site()
	local keys = {}
	for key in pairs(grug_mapgen.wp40.waypost_texts) do keys[#keys + 1] = key end
	table.sort(keys)
	local x, y, z = keys[1]:match("^(-?%d+):(-?%d+):(-?%d+)$")
	local base = vector.new(tonumber(x), tonumber(y), tonumber(z))
	while grug_mapgen.wp40.waypost_texts[base.x .. ":" .. (base.y - 1) .. ":" .. base.z] do
		base.y = base.y - 1
	end
	return base, #keys
end

local function waypost_log(base)
	for y = -1, 3 do
		local pos = vector.offset(base, 0, y, 0)
		local node = core.get_node(pos)
		log(("waypost %s %s param2 %d text '%s'"):format(core.pos_to_string(pos), node.name,
			node.param2, core.get_meta(pos):get_string("text")))
	end
	local texts = 0
	for _, object in ipairs(core.get_objects_inside_radius(vector.offset(base, 0, 1, 0), 4)) do
		local entity = object:get_luaentity()
		if entity and entity.name == "grug_text:text" then texts = texts + 1 end
	end
	log("waypost text entities " .. texts)
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
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		state.phase = "emerge"
	elseif state.phase == "emerge" then
		local key = TOWNS[state.town]
		if not key then
			local base, count = waypost_site()
			log("waypost nodes in this world " .. count .. ", first stack " .. core.pos_to_string(base))
			state.phase = "emerging"
			state.base = base
			player:set_pos(vector.offset(base, 0, 12, 0))
			local t0 = core.get_us_time()
			core.emerge_area(vector.offset(base, -20, -12, -20), vector.offset(base, 20, 12, 20),
				function(_, _, remaining)
					if remaining ~= 0 then return end
					log(("waypost emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
					state.shots = {{name = "waypost", run = function(p)
						view(p, vector.offset(base, 5, 1, 4), vector.offset(base, 0, 1, 0))
					end, after = function() waypost_log(base) end}}
					state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
					state.phase = "shoot"
					state.last = true
				end)
			return
		end
		local _, anchor = sockets(key)
		log("town " .. key .. " anchor " .. core.pos_to_string(anchor))
		state.phase = "emerging"
		player:set_pos(vector.offset(anchor, 0, 20, 0))
		local t0 = core.get_us_time()
		core.emerge_area(vector.offset(anchor, -44, -6, -44), vector.offset(anchor, 44, 24, 44),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				log(("town %s emerged in %.1f s"):format(key, (core.get_us_time() - t0) / 1e6))
				state.shots = town_shots(key)
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
				state.phase = "shoot"
			end)
	elseif state.phase == "shoot" then
		local shot = state.shots[state.shot]
		if not shot then
			if state.last then
				state.phase = "done"
				log("shutdown")
				core.request_shutdown("probe done", false, 0)
				return
			end
			state.town = state.town + 1
			state.phase = "emerge"
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

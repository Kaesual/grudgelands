-- Disposable engine probe (Round 62 lane TEMPLATEFIX): views of the fixed
-- building templates for screenshots. Never shipped:
-- tools/r62_templatefix/capture.sh stages it through tools/luanti_headless.sh
-- and connects one real client. The driver (character creation, SHOT / ack
-- handshake) follows tools/r58_townfix's probe.
--
-- Kezamba's moot house: its double door from the porch and from inside, with
-- the four door cells logged (the right-hinged leaf's upper cell was a
-- window). Lethariel's two mere shrines, the core's and the district plot's:
-- the shrine with the cells at its inside point logged (it was the floor
-- block; it is one step north of the south socket, a quarter of the way to
-- the north one, in both frames). The player is immortal and floats.

local P = "[r62templatefix] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r62templatefix_settle") or "") or 3

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r62templatefix_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function by_id(key)
	local out = {}
	for _, socket in ipairs(grug_core.settlement_sockets_at(key)) do out[socket.id] = socket end
	return out
end

-- Stand (feet) at `from` and look at `to`.
local function view(player, from, to)
	player:set_pos(from)
	local eye = vector.offset(from, 0, 1.5, 0)
	local dx, dy, dz = to.x - eye.x, to.y - eye.y, to.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end

local function cell(pos)
	local node = core.get_node(pos)
	return ("%s %s/%d"):format(core.pos_to_string(pos), node.name, node.param2)
end

local KEZ, SHRINES = {}, {}

-- Kezamba's core frame: the moot house at x -24, z 30, turns 1, so the
-- template's (x, y, z) is the core's (-24 + z, y, 40 - x); the double door's
-- leaves at template (5,5,6) and (4,5,6) are the core's (-18,5,35) and
-- (-18,5,36).
local function kez(x, y, z) return vector.add(KEZ.anchor, vector.new(x, y, z)) end

local function shrine_log(s)
	local spot = s.inside
	log(("shrine %s inside %s: below %s | at %s | above %s"):format(s.label,
		core.pos_to_string(spot), cell(vector.offset(spot, 0, -1, 0)), cell(spot),
		cell(vector.offset(spot, 0, 1, 0))))
end

local function shrine_view(player, s)
	-- from beyond the south socket, a little raised, looking at the inside point
	local away = vector.direction(s.north, s.south)
	view(player, vector.add(s.south, vector.new(away.x * 6, 2, away.z * 6)), s.inside)
end

local SHOTS = {
	{name = "K1_moot_house_door_outside", area = function()
		return kez(-34, -4, 22), kez(-6, 20, 48)
	end, run = function(player)
		view(player, kez(-23, 5, 35.5), kez(-18, 5.8, 35.5))
	end, after = function()
		for _, p in ipairs({{-18, 5, 35}, {-18, 6, 35}, {-18, 5, 36}, {-18, 6, 36}}) do
			log("moot door cell " .. cell(kez(p[1], p[2], p[3])))
		end
	end},
	{name = "K2_moot_house_door_inside", run = function(player)
		view(player, kez(-15, 5, 36), kez(-18, 5.8, 36))
	end},
	{name = "L1_mere_shrine_core", area = function()
		local s = SHRINES.core
		return vector.offset(s.inside, -14, -4, -14), vector.offset(s.inside, 14, 12, 14)
	end, run = function(player) shrine_view(player, SHRINES.core) end,
		after = function() shrine_log(SHRINES.core) end},
	{name = "L2_mere_shrine_plot", area = function()
		local s = SHRINES.plot
		return vector.offset(s.inside, -14, -4, -14), vector.offset(s.inside, 14, 12, 14)
	end, run = function(player) shrine_view(player, SHRINES.plot) end,
		after = function() shrine_log(SHRINES.plot) end},
}

-- The two shrines from their south and north sockets: the core's carry the
-- core frame's coordinates (x 20), the plot's its own (x 0).
local function find_shrines()
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		local s = by_id(settlement.key)
		for _, socket in pairs(s) do
			local prefix = socket.id:match("^(.*mere_shrine)_south$")
			local north = prefix and s[prefix .. "_north"]
			if north then
				local which = socket.x == 20 and "core" or "plot"
				local step = vector.divide(vector.subtract(north.pos, socket.pos), 4)
				SHRINES[which] = {label = settlement.key .. ":" .. socket.id .. " (" .. which .. ")",
					south = socket.pos, north = north.pos, inside = vector.add(socket.pos, step)}
				log(("shrine %s south %s north %s"):format(SHRINES[which].label,
					core.pos_to_string(socket.pos), core.pos_to_string(north.pos)))
			end
		end
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
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_elf = "Elf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		core.set_timeofday(0.5)
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		player:set_armor_groups({immortal = 1})
		local porch = by_id("kezamba").moot_house_porch
		KEZ.anchor = vector.subtract(porch.pos, vector.new(porch.x, porch.y, porch.z))
		log("anchors kezamba " .. core.pos_to_string(KEZ.anchor) .. " (porch " ..
			core.pos_to_string(porch.pos) .. ")")
		find_shrines()
		state.phase = "next"
		state.shot = 1
	elseif state.phase == "next" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		state.waited, state.logged, state.ran = 0, false, false
		if not shot.area then
			state.phase = "shoot"
			return
		end
		local ok, minp, maxp = pcall(shot.area)
		if not ok then
			log("skip " .. shot.name .. ": " .. tostring(minp))
			state.shot = state.shot + 1
			return
		end
		state.phase = "emerging"
		player:set_pos(vector.divide(vector.add(minp, maxp), 2))
		local t0 = core.get_us_time()
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining ~= 0 then return end
			log(("emerged %s in %.1f s"):format(shot.name, (core.get_us_time() - t0) / 1e6))
			state.phase = "shoot"
		end)
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
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
			state.phase = "next"
		end
	end
end)

-- Round 71 lane UI, the proof on an older world (tools/r71_ui/old_world.sh):
-- brings the clerk's socket of all six capitals into the active area without a
-- player and reports what stands booked on it, the marker included. The first
-- boot (the code before the registrar) stops when every clerk stands; the
-- second (the same world, the new code) stops when every clerk's socket holds
-- the registrar and nothing else. Never shipped.
local SOCKET = "miners_guild/miners_guild_clerk"
local KEYS = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}
local LIMIT, PERIOD = 240, 5
local function log(text) core.log("action", "[r71ui] " .. text) end

local function clerk_pos(key)
	for _, socket in ipairs(grug_core.settlement_sockets_at(key)) do
		if socket.id == SOCKET then return socket.pos end
	end
end

local function report()
	local done, lines = 0, {}
	for _, key in ipairs(KEYS) do
		local holders = {}
		for _, object in ipairs(core.get_objects_inside_radius(clerk_pos(key), 96)) do
			local entity = object:get_luaentity()
			if entity and entity._grug_start == key and entity._grug_socket == SOCKET then
				holders[#holders + 1] = entity
			end
		end
		local marker = grug_mobs.storage:get_string("startnpc:" .. key .. ":" .. SOCKET)
		local first = holders[1]
		lines[#lines + 1] = ("%s holders=%d marker=%q role=%s name=%s walker=%s"):format(key,
			#holders, marker, tostring(first and first._grug_socket_role),
			tostring(first and first._grug_npc_name), tostring(first and first._grug_walker))
		if #holders == 1 and marker == "1" then done = done + 1 end
	end
	return done, lines
end

local started, wanted
local function tick()
	local done, lines = report()
	local elapsed = core.get_gametime() - started
	for _, line in ipairs(lines) do log(("t=%d %s"):format(elapsed, line)) end
	local all = done == #KEYS
	if all and wanted then
		for _, line in ipairs(lines) do
			if not line:find(wanted, 1, true) then all = false end
		end
	end
	if all or elapsed >= LIMIT then
		log(all and "CHECK all six as expected" or "CHECK timed out")
		log("shutdown")
		core.request_shutdown()
		return
	end
	core.after(PERIOD, tick)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		started = core.get_gametime()
		-- The boot after the registrar exists waits for it on every socket.
		for _, socket in ipairs(grug_core.settlement_sockets_at("highcourt")) do
			if socket.id == SOCKET then
				wanted = socket.role ~= "idle" and ("role=" .. socket.role) or nil
			end
		end
		log("boot, the socket's role " .. (wanted or "idle"))
		for _, key in ipairs(KEYS) do
			local pos = clerk_pos(key)
			core.emerge_area(vector.offset(pos, -32, -16, -32), vector.offset(pos, 32, 16, 32),
				function(_, _, remaining)
					if remaining == 0 then
						log("emerged " .. key .. " " .. core.pos_to_string(pos))
						core.forceload_block(pos, true)
					end
				end)
		end
		core.after(PERIOD, tick)
	end)
end)

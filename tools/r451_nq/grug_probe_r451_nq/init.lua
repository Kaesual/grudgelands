-- Disposable release 0.45.1 lane NQ probe (never shipped; staged into a
-- throwaway game copy by tools/luanti_headless.sh through
-- tools/r451_nq/engine.sh).
--
-- The capital NPC socket audit: the user saw NPCs in front of Nhal Veyr's
-- houses sunk about half their height into the ground (production, 0.45.0).
-- Per target capital (targets.lua, staged by engine.sh; default Nhal Veyr):
--   1. every chunk holding one of its sockets is emerged, one at a time;
--      right after a chunk lands its sockets are read (EMERGE: a neighbour
--      chunk may still be the engine's unfinished shell), and again once every
--      chunk is written (FINAL): the feet cell (the socket node), the head
--      cell (one above) and the floor (one below). A socket whose feet or head
--      cell is walkable is BAD (logged with the first free two-cell gap above
--      it); one whose floor is not walkable is FLOATING;
--   2. every NPC the settlement engine places is recorded (a wrap of
--      core.add_entity on the `_grug_unplaced` staticdata `place` hands it),
--      so the summary says how many FINAL-BAD sockets got an NPC;
--   3. the blocks of every socket are force-loaded, which activates the NPCs,
--      and after `settle` seconds every NPC booked on a socket is read: one
--      whose feet cell is a solid full node is logged as SUNK, with the
--      column around its feet (capital displays, positioned by their own
--      code and not physical, are left out).
-- Every line carries "[r451nq]"; "RESULT" is the last one.

local P = "[r451nq] "
local function log(s) core.log("action", P .. s) end
local cfg_path = core.get_modpath(core.get_current_modname()) .. "/targets.lua"
local cfg = {capitals = {"nhal_veyr"}, settle = 45}
local f = io.open(cfg_path, "rb")
if f then
	f:close()
	cfg = dofile(cfg_path)
end
local SKIP = {waypoint = true, public_station = true}
local floor = math.floor

local function walkable(name)
	local def = core.registered_nodes[name]
	return def == nil or def.walkable ~= false
end
local function key3(p) return p.x .. "," .. p.y .. "," .. p.z end

-- What the settlement engine places, with where.
local placed = {}
local add_entity = core.add_entity
core.add_entity = function(pos, name, staticdata, ...)
	local object = add_entity(pos, name, staticdata, ...)
	if object and type(staticdata) == "string" and staticdata:find("_grug_unplaced", 1, true) then
		placed[key3(vector.round(pos))] = name
	end
	return object
end

local bad, totals = {}, {}
local function chunk_min(v) return floor((v + 32) / 80) * 80 - 32 end

-- `stage` is "EMERGE" right after the socket's chunk landed (a neighbour
-- chunk may still be a shell then) or "FINAL" once every chunk is written.
local function audit(entry, stage)
	local pos = entry.socket.pos
	local feet = core.get_node(pos).name
	local head = core.get_node({x = pos.x, y = pos.y + 1, z = pos.z}).name
	local below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
	local t = totals[entry.key][stage]
	t.audited = t.audited + 1
	if feet == "ignore" or head == "ignore" or below == "ignore" then
		t.unloaded = t.unloaded + 1
		log(("%s-UNLOADED %s %s %s"):format(stage, entry.key, entry.socket.id, core.pos_to_string(pos)))
		return
	end
	local spawn = entry.socket.spawn and "spawn" or "spare"
	if walkable(feet) or walkable(head) then
		local lift
		for dy = 1, 4 do
			if not walkable(core.get_node({x = pos.x, y = pos.y + dy, z = pos.z}).name) and
					not walkable(core.get_node({x = pos.x, y = pos.y + dy + 1, z = pos.z}).name) then
				lift = dy
				break
			end
		end
		t.bad = t.bad + 1
		if entry.socket.spawn then t.bad_spawn = t.bad_spawn + 1 end
		if stage == "FINAL" then bad[#bad + 1] = entry end
		log(("%s-BAD %s %s role=%s %s %s feet=%s head=%s floor=%s free_above=%s"):format(stage,
			entry.key, entry.socket.id, entry.socket.role, spawn, core.pos_to_string(pos), feet, head,
			below, tostring(lift)))
	elseif not walkable(below) then
		t.floating = t.floating + 1
		log(("%s-FLOATING %s %s role=%s %s %s floor=%s"):format(stage, entry.key, entry.socket.id,
			entry.socket.role, spawn, core.pos_to_string(pos), below))
	end
end
local function stage_totals()
	return {audited = 0, bad = 0, bad_spawn = 0, floating = 0, unloaded = 0}
end

local function finish()
	local n_bad = 0
	for _, key in ipairs(cfg.capitals) do
		local t = totals[key]
		if t then
			local got = 0
			for _, entry in ipairs(bad) do
				if entry.key == key and placed[key3(entry.socket.pos)] then got = got + 1 end
			end
			for _, stage in ipairs({"EMERGE", "FINAL"}) do
				local s = t[stage]
				log(("SUMMARY %s %s sockets=%d audited=%d bad=%d (spawn %d) floating=%d unloaded=%d"):format(
					key, stage, t.sockets, s.audited, s.bad, s.bad_spawn, s.floating, s.unloaded))
			end
			log(("SUMMARY %s chunks=%d, final bad sockets with an NPC placed %d; active NPCs %d, " ..
				"feet inside a solid node %d"):format(key, t.chunks, got, t.npcs or 0, t.sunk or 0))
			n_bad = n_bad + t.FINAL.bad
		end
	end
	log(("RESULT done bad=%d"):format(n_bad))
	core.request_shutdown("r451 nq probe done", false, 0)
end

-- Phase 3: activate the capital (every socket's block and the one under it,
-- transient force-loads), let its NPCs live for `settle` seconds, then read
-- the feet of every NPC booked on one of its sockets.
local SOLID = {normal = true, allfaces = true, allfaces_optional = true, glasslike = true,
	glasslike_framed = true, glasslike_framed_optional = true}
local function solid(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable ~= false and SOLID[def.drawtype or "normal"] == true
end
local function feet_cell(p)
	return core.get_node({x = p.x, y = floor(p.y + 0.5), z = p.z}).name
end
local function column(p)
	local names = {}
	for dy = -2, 2 do
		names[#names + 1] = core.get_node({x = p.x, y = floor(p.y + 0.5) + dy, z = p.z}).name
			:gsub("^.-:", "")
	end
	return table.concat(names, "|")
end
local function seated()
	local loaded = 0
	for _, key in ipairs(cfg.capitals) do
		for _, socket in ipairs(totals[key] and grug_core.settlement_sockets_at(key) or {}) do
			if not SKIP[socket.role] then
				core.forceload_block(socket.pos, true, -1)
				core.forceload_block({x = socket.pos.x, y = socket.pos.y - 2, z = socket.pos.z}, true, -1)
				loaded = loaded + 1
			end
		end
	end
	log(("force-loaded the blocks of %d sockets; settling %d s"):format(loaded, cfg.settle or 45))
	core.after(cfg.settle or 45, function()
		local bad_at = {}
		for _, entry in ipairs(bad) do bad_at[entry.key .. "/" .. entry.socket.id] = entry end
		for _, key in ipairs(cfg.capitals) do
			local t = totals[key]
			local socket_pos = {}
			for _, socket in ipairs(t and grug_core.settlement_sockets_at(key) or {}) do
				socket_pos[socket.id] = socket.pos
			end
			local npcs, sunk = 0, 0
			local seen = {}
			for _, socket in ipairs(t and grug_core.settlement_sockets_at(key) or {}) do
				for _, object in ipairs(core.get_objects_inside_radius(socket.pos, 24)) do
					local entity = object:get_luaentity()
					if entity and entity._grug_start == key and not seen[entity] and
							not entity._grug_capital_display then
						seen[entity] = true
						npcs = npcs + 1
						local p = object:get_pos()
						local cell = feet_cell(p)
						local home = socket_pos[entity._grug_socket or ""]
						if solid(cell) then
							sunk = sunk + 1
							log(("SUNK %s %s %s at %s column(-2..+2)=%s socket=%s%s"):format(key,
								tostring(entity._grug_socket), entity.name, core.pos_to_string(p, 2), column(p),
								home and core.pos_to_string(home) or "?",
								bad_at[key .. "/" .. tostring(entity._grug_socket)] and " (a BAD socket)" or ""))
						end
					end
				end
			end
			if t then t.npcs, t.sunk = npcs, sunk end
		end
		finish()
	end)
end

core.after(2, function()
	local wanted = {}
	for _, key in ipairs(cfg.capitals) do wanted[key] = true end
	local chunks, order = {}, {}
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		if wanted[record.key] then
			log(("SETTLEMENT %s slot=%s anchor=%s"):format(record.key, tostring(record.slot),
				core.pos_to_string(record.anchor)))
			local t = {sockets = 0, chunks = 0, EMERGE = stage_totals(), FINAL = stage_totals()}
			totals[record.key] = t
			for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
				if not SKIP[socket.role] then
					t.sockets = t.sockets + 1
					local c = {x = chunk_min(socket.pos.x), y = chunk_min(socket.pos.y),
						z = chunk_min(socket.pos.z)}
					local ck = key3(c)
					if not chunks[ck] then
						chunks[ck] = {minp = c, entries = {}, key = record.key}
						order[#order + 1] = ck
						t.chunks = t.chunks + 1
					end
					local list = chunks[ck].entries
					-- (a head cell in the chunk above reads "ignore" and is
					-- logged as UNLOADED, not guessed)
					list[#list + 1] = {key = record.key, socket = socket}
				end
			end
		end
	end
	log(("%d chunks to emerge"):format(#order))
	local started = core.get_us_time()
	local i = 0
	local function next_chunk()
		i = i + 1
		local ck = order[i]
		if not ck then
			log(("EMERGED all in %.1f s"):format((core.get_us_time() - started) / 1e6))
			-- Every chunk is written now: the final audit (load_area brings
			-- back what the unload timer has dropped since).
			for _, ck in ipairs(order) do
				local chunk = chunks[ck]
				core.load_area(vector.subtract(chunk.minp, 1), vector.add(chunk.minp, 80))
				for _, entry in ipairs(chunk.entries) do audit(entry, "FINAL") end
			end
			-- one more heartbeat or two of placement before the seat check
			core.after(6, seated)
			return
		end
		local chunk = chunks[ck]
		local maxp = vector.add(chunk.minp, 79)
		core.emerge_area(chunk.minp, maxp, function(_, _, remaining)
			if remaining > 0 then return end
			for _, entry in ipairs(chunk.entries) do audit(entry, "EMERGE") end
			log(("CHUNK %d/%d %s %s %d sockets at %.1f s"):format(i, #order, chunk.key,
				core.pos_to_string(chunk.minp), #chunk.entries, (core.get_us_time() - started) / 1e6))
			next_chunk()
		end)
	end
	next_chunk()
end)

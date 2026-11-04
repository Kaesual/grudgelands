-- Round 69 lane CAMP: the camp site templates through the real blueprint
-- (every race, every turn) and the box rewrite's job with a recording engine.
--   luajit tools/r69_camp/portable_test.lua <repo>
local repo = assert(arg[1])
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local build = dofile(dir .. "/r58_camp_blueprint.lua")
local rot = dofile(dir .. "/../wp13/plot_approach.lua").rot
local R, HEIGHT = 11, 9
local function key(x, y, z) return x .. ":" .. y .. ":" .. z end

local SOCKETS = {gate_west = {-2, -9, 1, 0, "guard_post", "gate"}, gate_east = {2, -9, -1, 0, "guard_post", "gate"},
	yard_west = {-4, 1, 0, -1, "guard_post", "camp"}, yard_east = {4, 1, 0, -1, "guard_post", "camp"},
	captain = {0, 3, 0, -1, "captain"}}
local FACTION = {human = "accord", dwarf = "accord", elf = "accord", orc = "throng", undead = "throng", troll = "throng"}

local builds = 0
for race, faction in pairs(FACTION) do
	for turns = 0, 3 do
		local bp = build({}, {blueprint_schema = "test", art = {kind = "camp_construction",
			faction = faction, race = race, turns = turns}})
		builds = builds + 1
		local label = race .. " turn " .. turns .. ": "
		assert(bp.clear_to == HEIGHT and bp.bounds.max.y == HEIGHT and bp.bounds.max.x == R,
			label .. "the box differs")
		local cells = {}
		for _, c in ipairs(bp.cells) do
			assert(math.abs(c.x) <= R and math.abs(c.z) <= R and c.y >= 0 and c.y <= HEIGHT,
				label .. "a cell outside the box")
			assert(not cells[key(c.x, c.y, c.z)], label .. "a cell twice")
			assert(c.name ~= "ignore" and not c.name:match("^wool:"), label .. "wool or ignore: " .. c.name)
			cells[key(c.x, c.y, c.z)] = c.name
		end
		assert(#bp.cells == (2 * R + 1) * (2 * R + 1) * (HEIGHT + 1), label .. "the box is not whole")
		local function clear(x, y, z) return cells[key(x, y, z)] == "air" end
		local function stand(x, z)
			return clear(x, 1, z) and clear(x, 2, z) and not clear(x, 0, z)
		end
		-- Yard and anchor support (the local frame's centre does not turn).
		for z = -2, 2 do for x = -2, 2 do for y = 1, 3 do
			assert(clear(x, y, z), label .. "the yard is blocked")
		end end end
		assert(not clear(0, 0, 0), label .. "no anchor support")
		-- The gate: every cell of the opening, and a walk from it.
		local gx, gz = rot(0, -R, turns)
		assert(stand(gx, gz), label .. "the gate is blocked")
		local queue, seen, at = {{gx, gz}}, {[key(gx, 1, gz)] = true}, 1
		while queue[at] do
			local p = queue[at]
			at = at + 1
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local x, z = p[1] + d[1], p[2] + d[2]
				local k = key(x, 1, z)
				if math.abs(x) <= R and math.abs(z) <= R and not seen[k] and stand(x, z) then
					seen[k] = true
					queue[#queue + 1] = {x, z}
				end
			end
		end
		-- The sockets: ids, cells, facings and tags as every world's garrison
		-- has them, clear and reachable from the gate.
		local found = 0
		for _, s in ipairs(bp.landmarks.sockets) do
			local row = assert(SOCKETS[s.id], label .. "an unknown socket " .. tostring(s.id))
			local x, z = rot(row[1], row[2], turns)
			local dx, dz = rot(row[3], row[4], turns)
			assert(s.x == x and s.z == z and s.y == 1 and s.dir.x == dx and s.dir.z == dz and
				s.role == row[5], label .. "socket " .. s.id .. " moved")
			assert((s.tags and s.tags[1]) == row[6], label .. "socket " .. s.id .. " tags")
			assert(stand(x, z), label .. "socket " .. s.id .. " blocked")
			assert(seen[key(x, 1, z)], label .. "socket " .. s.id .. " unreachable")
			found = found + 1
		end
		assert(found == 5, label .. "a socket is missing")
	end
end
print(("templates: %d builds, gate, yard, support, sockets, whole box"):format(builds))

-- The job, with a recording engine.
local factory = dofile(repo .. "/mods/MAPGEN/grug_mapgen/camp_rewrite.lua")
local IGNORE = 127

local function new_storage(values)
	local s = {values = values or {}}
	function s:get_string(k) return self.values[k] or "" end
	function s:set_string(k, v) self.values[k] = v ~= "" and v or nil end
	return s
end

-- A one-box map: nodes by "x:y:z", with metadata and timers by the same key.
local function new_world(opts)
	opts = opts or {}
	local w = {queue = {}, writes = 0, meta = {}, timers = {}, severe = {}, logs = {},
		emerges = 0, nodes = {}, param2s = {}}
	local ids, names = {air = 1}, {"air"}
	local function id_of(name)
		if not ids[name] then
			names[#names + 1] = name
			ids[name] = #names
		end
		return ids[name]
	end
	local engine = {CONTENT_IGNORE = IGNORE, EMERGE_ERRORED = 1, EMERGE_CANCELLED = 2,
		settings = {get = function() return "5" end}}
	function engine.after(delay, fn, ...)
		local args = {...}
		w.queue[#w.queue + 1] = {delay = delay, run = function() fn(unpack(args)) end}
	end
	function engine.emerge_area(min, max, callback)
		w.emerges = w.emerges + 1
		callback({x = 0, y = 0, z = 0}, opts.emerge_action or 3, 1)
		assert(w.writes == 0 or w.in_emerge == nil, "no write inside the emerge callback")
		w.in_emerge = true
		callback({x = 0, y = 0, z = 0}, 3, 0)
		w.in_emerge = nil
		w.box = {min = min, max = max}
	end
	function engine.get_voxel_manip()
		local vm = {}
		function vm:read_from_map(min, max) return min, max end
		function vm:get_data()
			local data = {}
			for z = w.box.min.z, w.box.max.z do for y = w.box.min.y, w.box.max.y do
				for x = w.box.min.x, w.box.max.x do
					local name = w.nodes[key(x, y, z)]
					data[#data + 1] = opts.hole == key(x, y, z) and IGNORE or
						(name and ids[name] or id_of("old"))
				end
			end end
			return data
		end
		function vm:get_param2_data()
			local data = {}
			for i = 1, (w.box.max.z - w.box.min.z + 1) * (w.box.max.y - w.box.min.y + 1) *
					(w.box.max.x - w.box.min.x + 1) do data[i] = 0 end
			return data
		end
		function vm:set_data(data) self.data = data end
		function vm:set_param2_data(data) self.param2 = data end
		function vm:write_to_map(light)
			assert(light == true, "the write takes the engine's light update")
			assert(not w.in_emerge, "no write inside the emerge callback")
			local i = 0
			for z = w.box.min.z, w.box.max.z do for y = w.box.min.y, w.box.max.y do
				for x = w.box.min.x, w.box.max.x do
					i = i + 1
					w.nodes[key(x, y, z)] = names[self.data[i]] or "ignore"
					w.param2s[key(x, y, z)] = self.param2[i]
				end
			end end
			w.writes = w.writes + 1
		end
		return vm
	end
	function engine.find_nodes_with_meta(min, max)
		local out = {}
		for k in pairs(w.meta) do
			local x, y, z = k:match("^(-?%d+):(-?%d+):(-?%d+)$")
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if x >= min.x and x <= max.x and y >= min.y and y <= max.y and
					z >= min.z and z <= max.z then
				out[#out + 1] = {x = x, y = y, z = z}
			end
		end
		return out
	end
	function engine.get_meta(pos)
		return {from_table = function(_, t)
			assert(t == nil, "metadata is cleared")
			w.meta[key(pos.x, pos.y, pos.z)] = nil
		end}
	end
	function engine.get_node_timer(pos)
		local k = key(pos.x, pos.y, pos.z)
		return {stop = function() w.timers[k] = nil end}
	end
	engine.get_content_id = id_of
	function engine.get_us_time() return 0 end
	function engine.log(_, text) w.logs[#w.logs + 1] = text end
	w.engine = engine
	w.severe_api = {report = function(_, summary) w.severe[#w.severe + 1] = summary end}
	return w
end

_G.VoxelArea = function(emin, emax)
	local sx, sy = emax.x - emin.x + 1, emax.y - emin.y + 1
	return {index = function(_, x, y, z)
		return (z - emin.z) * sy * sx + (y - emin.y) * sx + (x - emin.x) + 1
	end}
end

local function site(name, ox, opts)
	opts = opts or {}
	return {key = name, place = opts.place or function()
		local cells = {}
		for z = 0, 1 do for y = 0, 1 do for x = 0, 1 do
			cells[#cells + 1] = {x = x, y = y, z = z, name = "new_" .. x, param2 = z}
		end end end
		return {cells = cells, base = {x = ox, y = 10, z = 0},
			min = {x = ox, y = 10, z = 0}, max = {x = ox + 1, y = 11, z = 1},
			reserved = {x = ox, y = 11, z = 0}}
	end}
end

local function drain(w, limit)
	local spent = 0
	while #w.queue > 0 do
		local item = table.remove(w.queue, 1)
		if limit and spent + item.delay > limit then
			table.insert(w.queue, 1, item)
			return
		end
		spent = spent + item.delay
		item.run()
	end
end

local function reset_stub(pending)
	return {pending = function() return pending end,
		clear = function(_, fn) if pending then fn() end end}
end

local function job(w, storage, reset, sites)
	return factory(w.engine, storage, sites or {site("a", 0), site("b", 100)}, reset or reset_stub(false),
		w.severe_api)
end

do -- a request: both camps written, the root kept, metadata and timers gone
	local w, storage = new_world(), new_storage()
	w.meta[key(1, 11, 1)], w.timers[key(1, 11, 1)] = true, true
	w.meta[key(0, 11, 0)], w.timers[key(0, 11, 0)] = true, true
	local rewrite = job(w, storage)
	assert(not storage.values.camp_rewrite, "nothing at load without a key")
	assert(#w.queue == 0, "a new world schedules nothing")
	rewrite.request()
	assert(storage.values.camp_rewrite and rewrite.pending(), "the request is durable at once")
	drain(w, 1)
	assert(w.writes == 2 and w.emerges == 2, "both camps written, one at a time")
	assert(rewrite.pending(), "the key stays until two map saves have passed")
	assert(w.nodes[key(1, 10, 1)] == "new_1" and w.param2s[key(1, 10, 1)] == 1, "cells and param2")
	assert(not w.meta[key(1, 11, 1)] and not w.timers[key(1, 11, 1)], "old metadata and timer gone")
	assert(w.meta[key(0, 11, 0)] and w.timers[key(0, 11, 0)], "the anchor root's stay")
	assert(w.nodes[key(0, 11, 0)] == "old", "the anchor root is not written")
	drain(w)
	assert(not rewrite.pending(), "done after the settle")
end
do -- a restart picks the key up; a repeat writes the same
	local w, storage = new_world(), new_storage({camp_rewrite = "1"})
	local rewrite = job(w, storage)
	drain(w)
	assert(w.writes == 2 and not rewrite.pending(), "the next start finishes")
	local first = {}
	for k, v in pairs(w.nodes) do first[k] = v end
	storage.values.camp_rewrite, w.writes = "1", 0
	rewrite = job(w, storage)
	drain(w)
	assert(w.writes == 2, "the repeat ran")
	for k, v in pairs(first) do assert(w.nodes[k] == v, "the repeat changed " .. k) end
end
do -- a crash before the settle: the key stays for the next start
	local w, storage = new_world(), new_storage()
	job(w, storage).request()
	drain(w, 1)
	assert(w.writes == 2 and storage.values.camp_rewrite, "written and still pending")
end
do -- a map reset: nothing recorded, an older key cleared
	local w, storage = new_world(), new_storage({camp_rewrite = "1"})
	local rewrite = job(w, storage, reset_stub(true))
	assert(not storage.values.camp_rewrite, "the map reset clears the key")
	rewrite.request()
	assert(not storage.values.camp_rewrite and #w.queue == 0, "no job at a reset's start")
end
do -- a failed emerge and an unloaded cell: severe, the key stays, no write
	local w, storage = new_world({emerge_action = 1}), new_storage()
	job(w, storage).request()
	drain(w)
	assert(w.writes == 0 and storage.values.camp_rewrite and #w.severe == 1, "a failed emerge")
	w, storage = new_world({hole = key(1, 11, 1)}), new_storage()
	job(w, storage).request()
	drain(w)
	assert(w.writes == 0 and storage.values.camp_rewrite and #w.severe == 1, "an unloaded cell")
	w, storage = new_world(), new_storage()
	job(w, storage, nil, {site("a", 0, {place = function() error("no cells") end})}).request()
	drain(w)
	assert(w.writes == 0 and storage.values.camp_rewrite and #w.severe == 1, "a failed rebuild")
end
print("job: request, resume, repeat, crash, map reset, failures")

-- The world handler records the job, and only that.
do
	_G.grug_core = {}
	local requests = 0
	_G.grug_mapgen = {camp_rewrite = {request = function() requests = requests + 1 end}}
	dofile(repo .. "/mods/CORE/grug_core/migrations.lua")
	local versions = grug_core.migrations.versions
	assert(versions[#versions] == "0.69.0", "the step is registered")
	local handlers = grug_core.migrations.handlers["0.69.0"]
	assert(handlers.world and not handlers.character, "a world part only")
	handlers.world("1")
	handlers.world("1")
	assert(requests == 2, "safe to run again")
end
print("portable_test: PASS")

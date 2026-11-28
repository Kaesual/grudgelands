-- Round 89 lane REWRITE: the box rewrite of the arena Breach Road's two halls
-- (the migration 0.89.0, upgrade contract §5.9).
--   S  the hall sites (`wp40/r89_hall_sites.lua`) on the real model and
--      writer: each box is 0.88.0's, whole, and every cell is what generation
--      leaves there, chunk by chunk over a natural ground (a leaf in a hall
--      included), the waystone on its cell;
--   J  the job (`hall_rewrite.lua`) with a recording engine: request, resume,
--      repeat, crash, map reset, failures, the read-back;
--   R  the sites' refusals with one input changed as it is read: a hall box that
--      grew (not 0.88.0's) and a kept natural cell in a box column; each
--      refuses with its message, and the job writes nothing;
--   H  the world handler 0.89.0 records the job, and only that.
--   luajit tools/r89_rewrite/portable_test.lua <repo>
local repo = assert(arg[1], "usage: portable_test.lua <repo>")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function key(x, y, z) return x .. ":" .. y .. ":" .. z end

-- S -------------------------------------------------------------------------
local L = dofile(wp40 .. "/breach_layout.lua")
local B = dofile(wp40 .. "/breach_model.lua")
local cids, names = {air = 0}, {[0] = "air"}
local core_api = {registered_nodes = setmetatable({}, {__index = function(_, name)
	if type(name) == "string" and name:find(":", 1, true) then return {} end
end}), CONTENT_AIR = 0}
function core_api.get_content_id(name)
	if not cids[name] then
		names[#names + 1] = name
		cids[name] = #names
	end
	return cids[name]
end
function core_api.get_name_from_content_id(cid) return names[cid] end
local STONE, GRASS, LEAF = core_api.get_content_id("default:stone"),
	core_api.get_content_id("default:dirt_with_grass"), core_api.get_content_id("default:leaves")
local site = {x = -72, z = 8, y = 30, reach = 29}
local placement = "P2 0\n" .. L.format(site) .. "\n"
-- Two biomes per hall (the roles follow the column), a leaf in each box.
local function column_values_at(x, z)
	return "land", nil, nil, (x + z) % 2 == 0 and "grug_deep_forest" or "grug_badlands",
		nil, site.y, nil
end
local leaves = {[key(site.x + 30, site.y + 20, site.z)] = true,
	[key(site.x - 30, site.y + 20, site.z + 3)] = true}
local function natural(x, y, z)
	if y < site.y then return STONE elseif y == site.y then return GRASS end
	return leaves[key(x, y, z)] and LEAF or 0
end

local sites = dofile(wp40 .. "/r89_hall_sites.lua")(wp40, core_api, placement, column_values_at)
check(#sites == 2 and sites[1].key == "accord" and sites[2].key == "throng", "S two halls, Accord first")

-- Generation: the writer chunk by chunk over the natural ground.
local model = B.new(wp40)
local writer = dofile(wp40 .. "/breach_writer.lua")(core_api, {breach = site}, B, model)
local world = {}
local function origin(v) return (math.floor((math.floor(v / 16) + 2) / 5) * 5 - 2) * 16 end
for oz = origin(site.z - 50), origin(site.z + 50), 80 do
	for oy = origin(site.y - 2), origin(site.y + 40), 80 do
		for ox = origin(site.x - 50), origin(site.x + 50), 80 do
			local context = {min_x = ox, min_y = oy, min_z = oz, max_x = ox + 79, max_y = oy + 79,
				max_z = oz + 79, column_values_at = column_values_at}
			function context.settled_at(x, y, z)
				local v = world[key(x, y, z)]
				if v then return v[1], v[2] end
				return natural(x, y, z), 0
			end
			function context.write_road(x, y, z, cid, param2) world[key(x, y, z)] = {cid, param2} end
			writer.dress(context)
		end
	end
end
local function generated(x, y, z)
	local v = world[key(x, y, z)]
	if v then return names[v[1]], v[2] end
	return names[natural(x, y, z)], 0
end

local BOXES = {accord = {22, 42}, throng = {-42, -22}}
for _, s in ipairs(sites) do
	local place = s.place()
	local label = "S " .. s.key .. ": "
	local xs = BOXES[s.key]
	check(place.min.x == site.x + xs[1] and place.max.x == site.x + xs[2] and
		place.min.y == site.y + 6 and place.max.y == site.y + 24 and
		place.min.z == site.z - 15 and place.max.z == site.z + 15, label .. "0.88.0's box")
	check(place.base.x == place.min.x and place.base.y == place.min.y and
		place.base.z == place.min.z, label .. "cells from the box's corner")
	check(#place.cells == 21 * 19 * 31, label .. "every cell of the box (" .. #place.cells .. ")")
	local seen, differ, solids, kinds = {}, 0, 0, {}
	for _, cell in ipairs(place.cells) do
		local x, y, z = place.base.x + cell.x, place.base.y + cell.y, place.base.z + cell.z
		check(x >= place.min.x and x <= place.max.x and y >= place.min.y and y <= place.max.y and
			z >= place.min.z and z <= place.max.z, label .. "a cell outside the box")
		check(not seen[key(x, y, z)], label .. "a cell twice")
		seen[key(x, y, z)] = true
		local name, param2 = generated(x, y, z)
		if name ~= cell.name or param2 ~= cell.param2 then differ = differ + 1 end
		if cell.name ~= "air" then solids = solids + 1 end
		kinds[cell.name] = true
	end
	check(differ == 0, label .. differ .. " cells differ from generation")
	check(solids > 1000 and not kinds["default:leaves"], label .. "the hall stands, the leaf is cleared")
	local w = L.world(site).halls[s.key].waystone
	local function at(dy)
		for _, cell in ipairs(place.cells) do
			if place.base.x + cell.x == w.x and place.base.y + cell.y == w.y + dy and
					place.base.z + cell.z == w.z then
				return cell.name
			end
		end
	end
	check(at(0) == B.WAYSTONE and at(1) == "air" and at(2) == "air",
		label .. "the waystone on the layout's cell, air above it")
end
-- The model and the writer are built once per job and shared by both halls.
do
	local loads, real = 0, dofile
	_G.dofile = function(path)
		if path:find("breach_model.lua", 1, true) then loads = loads + 1 end
		return real(path)
	end
	local fresh = dofile(wp40 .. "/r89_hall_sites.lua")(wp40, core_api, placement, column_values_at)
	fresh[1].place()
	fresh[2].place()
	_G.dofile = real
	check(loads == 1, "S one model per job (" .. loads .. ")")
end
print(("sites: both boxes 21 x 19 x 31 as generation leaves them, %d checks"):format(checks))

-- J -------------------------------------------------------------------------
local factory = dofile(repo .. "/mods/MAPGEN/grug_mapgen/hall_rewrite.lua")
local IGNORE = 127

local function new_storage(values)
	local s = {values = values or {}}
	function s:get_string(k) return self.values[k] or "" end
	function s:set_string(k, v) self.values[k] = v ~= "" and v or nil end
	return s
end

-- A map: nodes by "x:y:z", with metadata and timers by the same key.
local function new_world(opts)
	opts = opts or {}
	local w = {queue = {}, writes = 0, meta = {}, timers = {}, severe = {}, logs = {},
		emerges = 0, nodes = {}, param2s = {}}
	local ids, list = {air = 1}, {"air"}
	local function id_of(name)
		if not ids[name] then
			list[#list + 1] = name
			ids[name] = #list
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
		w.in_emerge = true
		callback({x = 0, y = 0, z = 0}, 3, 0)
		w.in_emerge = nil
	end
	function engine.get_voxel_manip()
		local vm = {}
		function vm:read_from_map(min, max)
			self.box = {min = min, max = max}
			return min, max
		end
		local function each(box, fn)
			local i = 0
			for z = box.min.z, box.max.z do for y = box.min.y, box.max.y do
				for x = box.min.x, box.max.x do
					i = i + 1
					fn(i, x, y, z)
				end
			end end
		end
		function vm:get_data()
			local data = {}
			each(self.box, function(i, x, y, z)
				local hole = opts.hole == key(x, y, z) or
					(opts.hole_after_write == key(x, y, z) and w.writes > 0)
				local name = w.nodes[key(x, y, z)]
				data[i] = hole and IGNORE or (name and id_of(name) or id_of("old"))
			end)
			return data
		end
		function vm:get_param2_data()
			local data = {}
			each(self.box, function(i, x, y, z) data[i] = w.param2s[key(x, y, z)] or 0 end)
			return data
		end
		function vm:set_data(data) self.data = data end
		function vm:set_param2_data(data) self.param2 = data end
		function vm:write_to_map(light)
			assert(light == true, "the write takes the engine's light update")
			assert(not w.in_emerge, "no write inside the emerge callback")
			each(self.box, function(i, x, y, z)
				w.nodes[key(x, y, z)] = list[self.data[i]] or "ignore"
				w.param2s[key(x, y, z)] = self.param2[i]
			end)
			w.writes = w.writes + 1
			if opts.after_write then opts.after_write(w) end
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

-- A 2 x 2 x 2 hall at (ox, 10, 0).
local function hall(name, ox, opts)
	opts = opts or {}
	return {key = name, place = opts.place or function()
		local cells = {}
		for z = 0, 1 do for y = 0, 1 do for x = 0, 1 do
			cells[#cells + 1] = {x = x, y = y, z = z, name = "new_" .. x, param2 = z}
		end end end
		return {cells = cells, base = {x = ox, y = 10, z = 0},
			min = {x = ox, y = 10, z = 0}, max = {x = ox + 1, y = 11, z = 1}}
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

local function job(w, storage, reset, halls)
	return factory(w.engine, storage, halls or {hall("accord", 0), hall("throng", 100)},
		reset or reset_stub(false), w.severe_api)
end

do -- a request: both halls written, metadata and timers gone, the key waits
	local w, storage = new_world(), new_storage()
	w.meta[key(1, 11, 1)], w.timers[key(1, 11, 1)] = true, true
	w.meta[key(0, 10, 0)], w.timers[key(0, 10, 0)] = true, true
	w.meta[key(2, 10, 0)], w.timers[key(2, 10, 0)] = true, true
	local rewrite = job(w, storage)
	check(not storage.values.hall_rewrite, "J nothing at load without a key")
	rewrite.request()
	check(storage.values.hall_rewrite and rewrite.pending(), "J the request is durable at once")
	check(not storage.values.camp_rewrite, "J the camp job's key is not touched")
	drain(w, 1)
	check(w.writes == 2 and w.emerges == 2, "J both halls written, one at a time")
	check(rewrite.pending(), "J the key stays until two map saves have passed")
	check(w.nodes[key(1, 10, 1)] == "new_1" and w.param2s[key(1, 10, 1)] == 1, "J cells and param2")
	check(w.nodes[key(0, 10, 0)] == "new_0", "J every cell of the box, its corner too")
	check(not w.meta[key(1, 11, 1)] and not w.timers[key(1, 11, 1)] and
		not w.meta[key(0, 10, 0)] and not w.timers[key(0, 10, 0)], "J old metadata and timers gone")
	check(w.meta[key(2, 10, 0)] and w.timers[key(2, 10, 0)], "J outside the box they stay")
	check(w.logs[1]:find("arena hall accord rewritten: 8 cells", 1, true), "J the log line")
	drain(w)
	check(not rewrite.pending(), "J done after the settle")
end
do -- a new world: nothing runs
	local w, storage = new_world(), new_storage()
	local rewrite = job(w, storage)
	check(#w.queue == 0, "J a new world schedules nothing")
	drain(w)
	check(w.emerges == 0 and w.writes == 0 and not rewrite.pending(), "J a new world does nothing")
	check(next(storage.values) == nil, "J a new world writes no key")
end
do -- a restart picks the key up; a repeat writes the same
	local w, storage = new_world(), new_storage({hall_rewrite = "1"})
	local rewrite = job(w, storage)
	drain(w)
	check(w.writes == 2 and not rewrite.pending(), "J the next start finishes")
	local first = {}
	for k, v in pairs(w.nodes) do first[k] = v end
	storage.values.hall_rewrite, w.writes = "1", 0
	job(w, storage)
	drain(w)
	check(w.writes == 2, "J the repeat ran")
	for k, v in pairs(first) do check(w.nodes[k] == v, "J the repeat changed " .. k) end
end
do -- a crash before the settle: the key stays for the next start
	local w, storage = new_world(), new_storage()
	job(w, storage).request()
	drain(w, 1)
	check(w.writes == 2 and storage.values.hall_rewrite, "J written and still pending")
end
do -- a map reset: nothing recorded, an older key cleared
	local w, storage = new_world(), new_storage({hall_rewrite = "1", camp_rewrite = "1"})
	local rewrite = job(w, storage, reset_stub(true))
	check(not storage.values.hall_rewrite, "J the map reset clears the key")
	rewrite.request()
	check(not storage.values.hall_rewrite, "J no key at a reset's start")
	drain(w)
	check(w.emerges == 0 and w.writes == 0, "J no job at a reset's start")
end
do -- a failed emerge, an unloaded cell, a failed place: severe, the key stays
	local w, storage = new_world({emerge_action = 1}), new_storage()
	job(w, storage).request()
	drain(w)
	check(w.writes == 0 and storage.values.hall_rewrite and #w.severe == 1, "J a failed emerge")
	w, storage = new_world({hole = key(1, 11, 1)}), new_storage()
	job(w, storage).request()
	drain(w)
	check(w.writes == 0 and storage.values.hall_rewrite and #w.severe == 1, "J an unloaded cell")
	w, storage = new_world(), new_storage()
	job(w, storage, nil, {hall("accord", 0, {place = function() error("box moved") end})}).request()
	drain(w)
	check(w.writes == 0 and storage.values.hall_rewrite and #w.severe == 1, "J a failed place")
end
do -- the read-back: a generating neighbour reverts a written cell
	local reverted = false
	local w, storage = new_world({after_write = function(w)
		if w.writes == 2 and not reverted then
			reverted = true
			w.nodes[key(101, 10, 1)] = "old"
		end
	end}), new_storage()
	local rewrite = job(w, storage)
	rewrite.request()
	drain(w, 1)
	check(w.writes == 2 and rewrite.pending(), "J the key waits for the read-back")
	drain(w)
	check(w.writes == 4, "J a reverted cell writes the job again")
	check(w.nodes[key(101, 10, 1)] == "new_1", "J the cell is back")
	check(not rewrite.pending() and #w.severe == 0, "J then the key goes, no severe")
	-- param2 alone counts.
	reverted = false
	w, storage = new_world({after_write = function(w)
		if w.writes == 1 and not reverted then
			reverted = true
			w.param2s[key(1, 10, 1)] = 3
		end
	end}), new_storage()
	rewrite = job(w, storage, nil, {hall("accord", 0)})
	rewrite.request()
	drain(w)
	check(w.writes == 2 and not rewrite.pending(), "J a reverted param2 writes again")
	-- Three passes, no more.
	w, storage = new_world({after_write = function(w)
		w.nodes[key(1, 10, 1)] = "something"
	end}), new_storage()
	rewrite = job(w, storage, nil, {hall("accord", 0)})
	rewrite.request()
	drain(w)
	check(w.writes == 3, "J the job writes three passes, no more")
	check(rewrite.pending() and storage.values.hall_rewrite, "J then the key stays")
	check(#w.severe == 1 and #w.queue == 0, "J severe once, and nothing left running")
	-- A box that cannot be read is no mismatch, and no loop either.
	w, storage = new_world({hole_after_write = key(1, 11, 1)}), new_storage()
	rewrite = job(w, storage, nil, {hall("accord", 0)})
	rewrite.request()
	drain(w)
	check(rewrite.pending() and #w.severe == 1, "J an unreadable box keeps the key, severe once")
	check(w.writes <= 3 and #w.queue == 0, "J and nothing loops")
end
print("job: request, resume, repeat, crash, map reset, failures, read-back")

-- R -------------------------------------------------------------------------
-- The real sites file, model and writer, with one input changed as it is
-- read: `dofile` hands the model and the sites a template reader (wp13's
-- templates.lua) or field data (breach_field.lua) with `change` applied.
local function with_change(file, change, fn)
	local real = dofile
	local seen = false
	_G.dofile = function(path)
		local loaded = real(path)
		if file == "breach_field.lua" and path:sub(-#file) == file then
			local columns = change(loaded.columns)
			seen = seen or columns ~= loaded.columns
			loaded.columns = columns
		elseif file ~= "breach_field.lua" and path:sub(-#"templates.lua") == "templates.lua" then
			local factory = loaded
			loaded = function(...)
				local templates = factory(...)
				local read = templates.read
				templates.read = function(at)
					local text = read(at)
					if at:sub(-#file) == file then
						local changed = change(text)
						seen = seen or changed ~= text
						return changed
					end
					return text
				end
				return templates
			end
		end
		return loaded
	end
	local ok, err = pcall(fn)
	_G.dofile = real
	if not ok then error(err, 0) end
	check(seen, "R the input " .. file .. " was changed")
end
-- Refused with `message` by place() and by the job: severe once, no emerge,
-- no write, the key kept.
local function refuses(message)
	local s = dofile(wp40 .. "/r89_hall_sites.lua")(wp40, core_api, placement, column_values_at)
	local ok, err = pcall(s[1].place)
	check(not ok and tostring(err) == message, "R place() refuses: " .. tostring(err))
	local w, storage = new_world(), new_storage()
	local details = {}
	w.severe_api = {report = function(_, summary, detail)
		w.severe[#w.severe + 1] = summary
		details[#details + 1] = detail
	end}
	job(w, storage, nil, s).request()
	drain(w)
	check(#w.severe == 1 and details[1] == message, "R the job reports it: " .. tostring(details[1]))
	check(w.emerges == 0 and w.writes == 0 and next(w.nodes) == nil, "R and writes nothing")
	check(storage.values.hall_rewrite == "1", "R the key stays for the next start")
end
-- The Accord's template one layer taller (size 21 x 20 x 31, an air layer on
-- top): its box is no longer 0.88.0's.
with_change("breach_accord.tpl", function(text)
	local rows = {}
	for _ = 1, 31 do rows[#rows + 1] = "|" .. string.rep(".", 21) .. "|" end
	text = text:gsub("\nsize 21 19 31\n", "\nsize 21 20 31\n", 1)
	return (text:gsub("\n\npoints\n", "\n\nlayer 19\n" .. table.concat(rows, "\n") ..
		"\n\npoints\n", 1))
end, function()
	refuses("the breach_accord box moved: the rewrite needs 0.88.0's box")
end)
-- A field column inside the Accord's box keeps the natural surface from y 7
-- up ("="), under the hall's air: a cell the writer would leave unwritten.
with_change("breach_field.lua", function(text)
	return (text:gsub("\n35 0 AAFAAFA\n", "\n35 0 AAFAAFA" .. string.rep("=", 18) .. "\n", 1))
end, function()
	refuses("a kept natural cell in the breach_accord box")
end)
print("refusals: a grown box and a kept cell, each refused, nothing written")

-- H -------------------------------------------------------------------------
do
	_G.grug_core = {}
	local requests = 0
	_G.grug_mapgen = {camp_rewrite = {request = function() end},
		hall_rewrite = {request = function() requests = requests + 1 end}}
	dofile(repo .. "/mods/CORE/grug_core/migrations.lua")
	local listed = false
	for _, version in ipairs(grug_core.migrations.versions) do
		listed = listed or version == "0.89.0"
	end
	check(listed, "H the step is registered")
	local handlers = grug_core.migrations.handlers["0.89.0"]
	check(handlers.world and not handlers.character, "H a world part only")
	handlers.world("1")
	handlers.world("1")
	check(requests == 2, "H it records the job, safe to run again")
end
print(("portable_test: PASS (%d checks)"):format(checks))

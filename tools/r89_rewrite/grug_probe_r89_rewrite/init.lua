-- Disposable engine probe (Round 89 lane REWRITE: the two-boot proof of the
-- arena halls' box rewrite). Never shipped: tools/r89_rewrite/e2e.py stages it
-- through tools/luanti_headless.sh, under the old game for the setup and under
-- the new one afterwards. It asserts nothing: it writes the cells to
-- <world>/r89_dump_<phase>.txt and what the game saw to <world>/r43_it_obs.json
-- (Round 43 IT's file names: e2e.py boots through tools/r43_it/it.py), and
-- e2e.py compares them. It emerges only the halls.
--   setup_*   one hall whole with its ring; one that straddles a mapchunk
--             border only on one side of it, else none; old metadata and a
--             node timer inside the whole box and metadata in its ring; the
--             old design's cells of both boxes (this game's model and writer);
--             a stand-in's discovery of each hall stone; dump
--   crash     nothing: e2e.py kills the server during the job
--   resume, repeat   once the job is done, emerges both halls with their ring,
--             the waystone checks, dump
--   fresh     the same on a new world, with the new design's model cells
--   reset     only the observations
local P = "[r89_rewrite_probe] "
local world = core.get_worldpath()
local RING = 8
-- The hall template's box around its waystone (template u, y, v of the
-- marker; 21 x 19 x 31 cells): 0.88.0's boxes, written down here on their own.
local MARKER = {accord = {x = 16, y = 1, z = 15}, throng = {x = 4, y = 1, z = 15}}
local SIZE = {x = 21, y = 19, z = 31}
local FACTIONS = {"accord", "throng"}

local function log(msg) core.log("action", P .. msg) end
local function read(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end
local plan = core.parse_json(read(world .. "/r43_it_plan.json") or "") or {}
local phase = plan.phase or "?"
local kind = phase:match("^(%a+)")
local expected = #(plan.joins or {})
local rewrite = rawget(grug_mapgen, "hall_rewrite")
local obs = {phase = phase, game = grug_core.world_version.game, leaves = 0, halls = {},
	load = {new_world = grug_core.world_version.new_world, from = grug_core.world_version.from},
	job = rewrite ~= nil}

local function halls()
	local out = {}
	for _, faction in ipairs(FACTIONS) do
		local w, m = grug_mapgen.breach.halls[faction].waystone, MARKER[faction]
		local min = {x = w.x - m.x, y = w.y - m.y, z = w.z - m.z}
		out[#out + 1] = {id = faction, waystone = w, arrival = grug_mapgen.breach.halls[faction].arrival,
			min = min, max = {x = min.x + SIZE.x - 1, y = min.y + SIZE.y - 1, z = min.z + SIZE.z - 1}}
	end
	return out
end
local function grown(p, by) return {x = p.x + by, y = p.y + by, z = p.z + by} end
local function chunk(v) return math.floor((v + 32) / 80) end
local function with_ring(hall) return {grown(hall.min, -RING), grown(hall.max, RING)} end

-- This game's design of a box: its model and writer, every air cell written,
-- a cell the writer leaves is air (r89_hall_sites.lua's rule, written again).
local function design(hall)
	local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
	local L = dofile(wp40 .. "/breach_layout.lua")
	local B = dofile(wp40 .. "/breach_model.lua")
	local model = B.new(wp40)
	local site = L.from_placement(grug_mapgen.wp40.placement_layout_text)
	local writer = dofile(wp40 .. "/breach_writer.lua")(core, {breach = site}, B, model)
	local got = {}
	writer.dress({min_x = hall.min.x, max_x = hall.max.x, min_y = hall.min.y, max_y = hall.max.y,
		min_z = hall.min.z, max_z = hall.max.z,
		column_values_at = grug_mapgen.wp40.planner_source.column_values_at,
		settled_at = function() return -1 end,
		write_road = function(x, y, z, cid, param2)
			got[x .. "," .. y .. "," .. z] = core.get_name_from_content_id(cid) .. ":" .. param2
		end})
	local tokens = {}
	for z = hall.min.z, hall.max.z do for y = hall.min.y, hall.max.y do for x = hall.min.x, hall.max.x do
		tokens[#tokens + 1] = got[x .. "," .. y .. "," .. z] or "air:0"
	end end end
	return tokens
end

-- What each node of the boxes does at runtime, from the live registrations:
-- the design needs nothing initialised (upgrade contract §5.9).
local function node_facts(names)
	local rows = {}
	for name in pairs(names) do
		local def = core.registered_nodes[name]
		local row = {on_construct = def.on_construct ~= nil, on_timer = def.on_timer ~= nil,
			after_place = def.after_place_node ~= nil, walkable = def.walkable ~= false, lbm = {}}
		for _, lbm in ipairs(core.registered_lbms) do
			for _, wanted in ipairs(type(lbm.nodenames) == "table" and lbm.nodenames or
					{lbm.nodenames}) do
				local group = wanted:match("^group:(.+)$")
				if wanted == name or (group and core.get_item_group(name, group) > 0) then
					row.lbm[#row.lbm + 1] = lbm.name
				end
			end
		end
		rows[name] = row
	end
	return rows
end

-- A stand-in player of a faction at a stone: name, faction, position, meta.
local function stand_in(name, faction, pos)
	local data = {["grug_factions:faction"] = faction}
	local meta = {
		get_string = function(_, k) return data[k] or "" end,
		set_string = function(_, k, v) data[k] = v end,
		get_int = function(_, k) return tonumber(data[k]) or 0 end,
		set_int = function(_, k, v) data[k] = tostring(v) end,
	}
	return {get_player_name = function() return name end, is_player = function() return true end,
		get_meta = function() return meta end, get_hp = function() return 20 end,
		get_pos = function() return vector.new(pos) end}, data
end

-- The stones after the job: the node on its cell, the registry's cell, the
-- validated arrival a trip lands on, a right-click by the stone's faction
-- (the origin found by its cell) and the objects in the box.
local function stones()
	local out = {}
	for _, hall in ipairs(halls()) do
		local id = "breach_road_" .. hall.id
		local w = hall.waystone
		local pos = grug_home.waystone_pos(id)
		local arrival = grug_home.waystone_arrival(id)
		local who, data = stand_in("r89probe_" .. hall.id, hall.id, {x = w.x + 1, y = w.y, z = w.z})
		local ok, err = pcall(grug_home.use_waystone, who, w)
		local objects = {}
		for _, object in ipairs(core.get_objects_in_area(grown(hall.min, -1), grown(hall.max, 1))) do
			if not object:is_player() then
				local entity = object:get_luaentity()
				objects[#objects + 1] = entity and entity.name or "?"
			end
		end
		table.sort(objects)
		out[hall.id] = {node = core.get_node(w).name, cell = pos and vector.equals(pos, w) or false,
			arrival = arrival and {x = arrival.x, y = arrival.y, z = arrival.z} or false,
			layout_arrival = hall.arrival, use = ok and "ok" or tostring(err),
			discovered = data["grug_home:waypoints"] or "", objects = objects}
	end
	return out
end

local function dump(with_design)
	local out = {}
	local box_names = {}
	for _, hall in ipairs(halls()) do
		local low, high = grown(hall.min, -RING), grown(hall.max, RING)
		local vm = core.get_voxel_manip()
		local emin, emax = vm:read_from_map(low, high)
		local area = VoxelArea(emin, emax)
		local data, param2, light = vm:get_data(), vm:get_param2_data(), vm:get_light_data()
		local names, index_of, tokens = {}, {}, {}
		for z = low.z, high.z do for y = low.y, high.y do for x = low.x, high.x do
			local i = area:index(x, y, z)
			local cid = data[i]
			if not index_of[cid] then
				names[#names + 1] = core.get_name_from_content_id(cid)
				index_of[cid] = #names
			end
			tokens[#tokens + 1] = index_of[cid] .. ":" .. param2[i] .. ":" .. light[i]
			if cid ~= core.CONTENT_AIR and cid ~= core.CONTENT_IGNORE and
					x >= hall.min.x and x <= hall.max.x and y >= hall.min.y and y <= hall.max.y and
					z >= hall.min.z and z <= hall.max.z then
				box_names[core.get_name_from_content_id(cid)] = true
			end
		end end end
		out[#out + 1] = ("hall %s %d %d %d %d %d %d %d %d %d %d %d %d"):format(hall.id,
			low.x, low.y, low.z, high.x, high.y, high.z,
			hall.min.x, hall.min.y, hall.min.z, hall.max.x, hall.max.y, hall.max.z)
		out[#out + 1] = "palette " .. table.concat(names, " ")
		out[#out + 1] = "cells " .. table.concat(tokens, " ")
		local meta, timers = {}, {}
		for _, pos in ipairs(core.find_nodes_with_meta(low, high)) do
			meta[#meta + 1] = pos.x .. "," .. pos.y .. "," .. pos.z
		end
		for z = low.z, high.z do for y = low.y, high.y do for x = low.x, high.x do
			if core.get_node_or_nil({x = x, y = y, z = z}) and
					core.get_node_timer({x = x, y = y, z = z}):is_started() then
				timers[#timers + 1] = x .. "," .. y .. "," .. z
			end
		end end end
		out[#out + 1] = "meta " .. table.concat(meta, " ")
		out[#out + 1] = "timers " .. table.concat(timers, " ")
		if with_design then out[#out + 1] = "design " .. table.concat(design(hall), " ") end
	end
	obs.box_nodes = node_facts(box_names)
	assert(core.safe_file_write(world .. "/r89_dump_" .. phase .. ".txt",
		table.concat(out, "\n") .. "\n"))
	log("dumped " .. phase)
end

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	obs.pending = rewrite ~= nil and rewrite.pending()
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r89 rewrite probe done") end)
end

local function emerge_all(list, done)
	local index = 0
	local function next_one()
		index = index + 1
		local item = list[index]
		if not item then return done() end
		core.emerge_area(item[1], item[2], function(_, _, remaining)
			if remaining == 0 then core.after(0, next_one) end
		end)
	end
	next_one()
end

local function wait_joins(fn)
	if expected > 0 and obs.leaves < expected then
		core.after(0.5, wait_joins, fn)
		return
	end
	fn()
end

local function setup()
	local list = halls()
	local partial, full
	for _, hall in ipairs(list) do
		local sx = chunk(hall.min.x) ~= chunk(hall.max.x)
		local sy = chunk(hall.min.y) ~= chunk(hall.max.y)
		local sz = chunk(hall.min.z) ~= chunk(hall.max.z)
		obs.halls[hall.id] = {straddles = {x = sx, y = sy, z = sz}, min = hall.min, max = hall.max}
		if (sx or sy or sz) and not partial then
			partial = hall
			partial.far = {x = sx and -32 + 80 * chunk(hall.min.x) + 79 or hall.max.x,
				y = sy and -32 + 80 * chunk(hall.min.y) + 79 or hall.max.y,
				z = sz and -32 + 80 * chunk(hall.min.z) + 79 or hall.max.z}
		elseif not full then
			full = hall
		end
	end
	assert(full, "no hall to emerge whole")
	obs.full, obs.partial = full.id, partial and partial.id or nil
	local todo = {with_ring(full)}
	if partial then todo[#todo + 1] = {partial.min, partial.far} end
	-- The exact discovered set a character of each faction stores (e2e.py
	-- seeds it into the visitor's row: a character who found the stone).
	obs.discovered = {}
	for _, hall in ipairs(list) do
		local who, data = stand_in("r89probe_" .. hall.id, hall.id, hall.waystone)
		pcall(grug_home.use_waystone, who, hall.waystone)
		obs.discovered[hall.id] = data["grug_home:waypoints"] or ""
	end
	emerge_all(todo, function()
		-- What a running 0.88.0 world may have left on replaced cells, and a
		-- marker outside the box that must stay.
		local inside = {x = full.min.x + 5, y = full.min.y + 8, z = full.min.z + 5}
		core.get_meta(inside):set_string("r89_old", "1")
		core.get_node_timer(inside):start(86400)
		local ring = {x = full.max.x + 3, y = full.min.y + 2, z = full.min.z + 10}
		core.get_meta(ring):set_string("r89_ring", "1")
		obs.old_meta, obs.ring_meta = inside, ring
		dump(true)
		wait_joins(function() finish("setup") end)
	end)
end

local function after_job()
	if (rewrite and rewrite.pending()) or (expected > 0 and obs.leaves < expected) then
		core.after(0.5, after_job)
		return
	end
	local list = {}
	for _, hall in ipairs(halls()) do list[#list + 1] = with_ring(hall) end
	emerge_all(list, function()
		obs.stones = stones()
		dump(kind == "fresh")
		finish(phase)
	end)
end

-- The crash between the halls (Round 89 HALLS' rerun): in the `crash` boot
-- every emerge asked for after the first hall's write line never calls
-- back, so the job waits before the second hall until e2e.py kills the
-- server (hall_rewrite.lua writes the line and asks for the next emerge in
-- the same step, and looks core.emerge_area up at each call).
if kind == "crash" then
	local log_line, emerge, written = core.log, core.emerge_area, false
	core.log = function(level, text)
		log_line(level, text)
		if text and tostring(text):find("[grug_mapgen] arena hall ", 1, true) then written = true end
	end
	core.emerge_area = function(...)
		if written then
			log("holding an emerge after the first hall's write")
			return
		end
		return emerge(...)
	end
end

-- The read-back on a real map: in a `repeat` boot one written cell goes back
-- after the job's last write, as a chunk generating beside the box would do.
if kind == "repeat" then
	local log_line, writes = core.log, 0
	core.log = function(level, text)
		log_line(level, text)
		if text and tostring(text):find("[grug_mapgen] arena hall ", 1, true) then
			writes = writes + 1
			if writes == #FACTIONS then
				core.after(1, function()
					local hall = halls()[1]
					local pos = {x = hall.min.x + 10, y = hall.min.y + 12, z = hall.min.z + 15}
					local was = core.get_node(pos).name
					obs.reverted = {pos = pos, was = was}
					core.swap_node(pos, {name = was == "default:stone" and "default:dirt" or "default:stone"})
					log("reverted one written cell")
				end)
			end
		end
	end
end

core.register_on_joinplayer(function(player)
	-- The character's own discovered stones, as the waystone list reads them.
	core.after(0.5, function()
		if not player:is_player() then return end
		local ids = {}
		for _, row in ipairs(grug_home.known_waypoints(player)) do ids[#ids + 1] = row.id end
		obs.visitor_known = obs.visitor_known or {}
		obs.visitor_known[#obs.visitor_known + 1] = table.concat(ids, " ")
	end)
end)
core.register_on_leaveplayer(function()
	obs.leaves = obs.leaves + 1
end)
core.register_on_mods_loaded(function()
	core.after(1, function()
		log("phase " .. phase .. ", job pending: " .. tostring(rewrite and rewrite.pending()))
		if kind == "setup" then
			setup()
		elseif kind == "resume" or kind == "repeat" or kind == "fresh" then
			after_job()
		elseif kind == "reset" then
			finish("reset")
		end
	end)
end)

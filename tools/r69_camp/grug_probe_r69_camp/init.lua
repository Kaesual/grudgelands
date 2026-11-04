-- Disposable engine probe (Round 69 lane CAMP: the two-boot proof of the camp
-- box rewrite). Never shipped: tools/r69_camp/e2e.py stages it through
-- tools/luanti_headless.sh, under the 0.68.0 game for the setup and under this
-- checkout's game afterwards. It asserts nothing: it writes the cells to
-- <world>/r69_dump_<phase>.txt and what the game saw to
-- <world>/r43_it_obs.json (Round 43 IT's file names: e2e.py boots through
-- tools/r43_it/it.py), and e2e.py compares them. It emerges only the camps.
--   setup_*   one camp fully with its ring, one that straddles a mapchunk
--             border only on one side of it, four untouched; old metadata and
--             a node timer inside the full box and metadata in its ring; dump
--   crash     nothing: e2e.py kills the server during the job
--   resume, repeat   once the job is done, emerges every camp with its ring
--             and dumps
--   fresh     the same on a new world
--   reset     only the observations
local P = "[r69_camp_probe] "
local world = core.get_worldpath()
local RING = 8
local R, HEIGHT = 11, 9

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
local obs = {phase = phase, game = grug_core.world_version.game, leaves = 0, camps = {},
	load = {new_world = grug_core.world_version.new_world, from = grug_core.world_version.from}}

local function camps()
	local out = {}
	for _, camp in ipairs(grug_mapgen.mining_camps.under_construction) do
		local a = grug_core.settlement_socket_anchor(camp.id)
		out[#out + 1] = {id = camp.id, anchor = a,
			min = {x = a.x - R, y = a.y, z = a.z - R},
			max = {x = a.x + R, y = a.y + HEIGHT, z = a.z + R}}
	end
	return out
end
local function grown(p, by, dy)
	return {x = p.x + by, y = p.y + dy, z = p.z + by}
end
local function chunk(v) return math.floor((v + 32) / 80) end

local function record(camp)
	local a, row = camp.anchor, {id = camp.id, anchor = a}
	row.sockets = {}
	for _, s in ipairs(grug_core.settlement_sockets_at(camp.id)) do
		row.sockets[#row.sockets + 1] = {id = s.id, role = s.role, x = s.x, y = s.y, z = s.z,
			face = s.face, dir = s.dir, tags = s.tags}
	end
	local function protected(dx, dy, dz)
		local pos = {x = a.x + dx, y = a.y + dy, z = a.z + dz}
		return {feature = grug_core.world_feature_at(pos),
			protected = core.is_protected(pos, "r69_probe_player")}
	end
	row.protection = {inside = protected(R + 10, 0, 0), beyond = protected(R + 11, 0, 0),
		corner = protected(R + 10, 0, -(R + 10)), low = protected(0, -10, 0),
		below = protected(0, -11, 0), high = protected(0, HEIGHT + 10, 0),
		above = protected(0, HEIGHT + 11, 0)}
	obs.camps[camp.id] = row
end

-- What each node of the box does at runtime, from the live registrations:
-- the picked design needs nothing initialised, and what a player inside it
-- meets (grug_core.should_suffocate is the game's own tick rule).
local function node_facts(names)
	local rows = {}
	for name in pairs(names) do
		local def = core.registered_nodes[name]
		local row = {on_construct = def.on_construct ~= nil, on_timer = def.on_timer ~= nil,
			after_place = def.after_place_node ~= nil, suffocates =
				grug_core.should_suffocate(def, false, false), walkable = def.walkable ~= false,
			lbm = {}}
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

local function dump()
	local out = {}
	local box_names = {}
	for _, camp in ipairs(camps()) do
		local low, high = grown(camp.min, -RING, -RING), grown(camp.max, RING, RING)
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
			if cid ~= core.CONTENT_AIR and x >= camp.min.x and x <= camp.max.x and
					y >= camp.min.y and y <= camp.max.y and z >= camp.min.z and z <= camp.max.z then
				box_names[core.get_name_from_content_id(cid)] = true
			end
		end end end
		out[#out + 1] = ("camp %s %d %d %d %d %d %d %d %d %d"):format(camp.id,
			low.x, low.y, low.z, high.x, high.y, high.z,
			camp.anchor.x, camp.anchor.y, camp.anchor.z)
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
	end
	obs.box_nodes = node_facts(box_names)
	assert(core.safe_file_write(world .. "/r69_dump_" .. phase .. ".txt",
		table.concat(out, "\n") .. "\n"))
	log("dumped " .. phase)
end

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	obs.pending = grug_mapgen.camp_rewrite ~= nil and grug_mapgen.camp_rewrite.pending()
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r69 camp probe done") end)
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

local function with_ring(camp)
	return {grown(camp.min, -RING, -RING), grown(camp.max, RING, RING)}
end

local function setup()
	local list = camps()
	local partial, full
	for _, camp in ipairs(list) do
		local x, z = chunk(camp.min.x) ~= chunk(camp.max.x), chunk(camp.min.z) ~= chunk(camp.max.z)
		if (x or z) and not partial then
			partial = camp
			partial.far = {x = x and -32 + 80 * chunk(camp.min.x) + 79 or camp.max.x,
				y = camp.max.y, z = z and -32 + 80 * chunk(camp.min.z) + 79 or camp.max.z}
		elseif not full then
			full = camp
		end
	end
	assert(partial and full, "seed gives no straddling camp")
	obs.full, obs.partial = full.id, partial.id
	emerge_all({with_ring(full), {partial.min, partial.far}}, function()
		-- What a running 0.68.0 world may have left on replaced cells, and a
		-- marker outside the box that must stay.
		local inside = {x = full.anchor.x + 5, y = full.anchor.y + 2, z = full.anchor.z + 5}
		core.get_meta(inside):set_string("r69_old", "1")
		core.get_node_timer(inside):start(86400)
		local ring = {x = full.max.x + 3, y = full.anchor.y + 2, z = full.anchor.z}
		core.get_meta(ring):set_string("r69_ring", "1")
		obs.old_meta, obs.ring_meta = inside, ring
		dump()
		finish("setup")
	end)
end

local function after_job()
	if grug_mapgen.camp_rewrite.pending() or (expected > 0 and obs.leaves < expected) then
		core.after(0.5, after_job)
		return
	end
	local list = {}
	for _, camp in ipairs(camps()) do list[#list + 1] = with_ring(camp) end
	emerge_all(list, function()
		dump()
		finish(phase)
	end)
end

-- The read-back on a real map: in a `repeat` boot one written cell goes back
-- after the job's last write, as a chunk generating beside the box would do.
if kind == "repeat" then
	local log_line, writes = core.log, 0
	core.log = function(level, text)
		log_line(level, text)
		if text and tostring(text):find("[grug_mapgen] camp site ", 1, true) then
			writes = writes + 1
			if writes == 6 then
				core.after(1, function()
					local camp = camps()[1]
					local pos = {x = camp.anchor.x + 10, y = camp.anchor.y + 2, z = camp.anchor.z}
					obs.reverted = {pos = pos, was = core.get_node(pos).name}
					core.swap_node(pos, {name = "default:stone"})
					log("reverted one written cell")
				end)
			end
		end
	end
end

core.register_on_leaveplayer(function()
	obs.leaves = obs.leaves + 1
end)
core.register_on_mods_loaded(function()
	for _, camp in ipairs(camps()) do record(camp) end
	core.after(1, function()
		log("phase " .. phase .. ", job pending: " .. tostring(grug_mapgen.camp_rewrite and
			grug_mapgen.camp_rewrite.pending()))
		if kind == "setup" then
			setup()
		elseif kind == "resume" or kind == "repeat" or kind == "fresh" then
			after_job()
		elseif kind == "reset" then
			finish("reset")
		end
	end)
end)

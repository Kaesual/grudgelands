-- 0.49.1 study HKEEP engine probe (disposable, never shipped): does a mapchunk
-- column that a map reset keeps survive the regeneration of its neighbours?
--
-- tools/r491_hkeep/run.sh stages it with a config.lua ({mode = "build"} or
-- {mode = "check", tag = "..."}). Region: the 3 x 3 chunk columns around the
-- kept column K (minp x 368, z -2352: ordinary meadow land on seed 12345,
-- pinned by tools/mgprof), three chunk layers (minp y -112, -32, 48).
--
--   build  (boot 1, fresh world) waits for the world preparation, emerges the
--          region, places markers in K (a cobble pillar, a trench and a chest
--          on K's west edge, an air pocket at y -100 on that edge, an item
--          entity in K's middle), snapshots every chunk (node names and
--          param2) into <world>/hkeep/ and shuts down.
--   check  (after run.sh deleted every map block outside K's column) waits for
--          the preparation, emerges the region again, logs per chunk how its
--          blocks came back (from disk or generated) and every node that
--          differs from the boot-1 snapshot (in K by distance to K's sides),
--          checks the markers, and measures the seam on K's four sides:
--          ground height inside K's edge column against the column just
--          outside, and the new layout's predicted terrain height outside
--          (planner_source.column_values_at) against the ground found there.

local PREFIX = "[hkeep_probe] "
local modpath = core.get_modpath(core.get_current_modname())
local config = dofile(modpath .. "/config.lua")
local KX, KZ = 368, -2352
local LAYERS = {-112, -32, 48}
local dir = core.get_worldpath() .. "/hkeep"
core.mkdir(dir)
local function log(message) core.log("action", PREFIX .. message) end
local floor = math.floor

local chunks, by_key = {}, {}
for dz = -1, 1 do
	for dx = -1, 1 do
		for _, y in ipairs(LAYERS) do
			local minp = {x = KX + 80 * dx, y = y, z = KZ + 80 * dz}
			local c = {id = ("c%d_%d_y%d"):format(dx, dz, y), minp = minp,
				maxp = vector.offset(minp, 79, 79, 79), kept = dx == 0 and dz == 0,
				actions = {}}
			chunks[#chunks + 1] = c
			by_key[minp.x .. "," .. minp.y .. "," .. minp.z] = c
		end
	end
end

local ACTION = {}
for _, name in ipairs({"EMERGE_CANCELLED", "EMERGE_ERRORED", "EMERGE_FROM_MEMORY",
		"EMERGE_FROM_DISK", "EMERGE_GENERATED"}) do
	if core[name] then ACTION[core[name]] = name:sub(8):lower() end
end

local function chunk_of_block(b)
	local function axis(v) return (floor((v + 2) / 5) * 5 - 2) * 16 end
	return by_key[axis(b.x) .. "," .. axis(b.y) .. "," .. axis(b.z)]
end

local function ground_y(x, z)
	for y = 127, -112, -1 do
		local name = core.get_node({x = x, y = y, z = z}).name
		local def = core.registered_nodes[name]
		if name ~= "air" and name ~= "ignore" and def and def.walkable and
				not (def.groups and (def.groups.tree or def.groups.leaves)) then
			return y, name
		end
	end
	return nil, "none"
end

-- Node names and param2 of one chunk, as a names line and 3 bytes per node.
local function read_chunk(c)
	local vm = VoxelManip()
	local emin, emax = vm:read_from_map(c.minp, c.maxp)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	return vm:get_data(), vm:get_param2_data(), area
end

local function snapshot(c)
	local data, p2, area = read_chunk(c)
	local names, ids, parts, buf, n = {}, {}, {}, {}, 0
	local minp, maxp = c.minp, c.maxp
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local vi = area:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				local cid = data[vi]
				local lid = ids[cid]
				if not lid then
					names[#names + 1] = core.get_name_from_content_id(cid)
					lid = #names
					ids[cid] = lid
				end
				n = n + 1
				buf[n] = string.char(lid % 256, floor(lid / 256), p2[vi])
				if n == 4096 then parts[#parts + 1] = table.concat(buf); buf, n = {}, 0 end
				vi = vi + 1
			end
		end
	end
	parts[#parts + 1] = table.concat(buf, "", 1, n)
	local file = assert(io.open(dir .. "/" .. c.id .. ".bin", "wb"))
	file:write(table.concat(names, "\t"), "\n", table.concat(parts))
	file:close()
end

local function band_kept(x, z)
	local d = math.min(x - KX, KX + 79 - x, z - KZ, KZ + 79 - z)
	if d == 0 then return "edge" elseif d < 16 then return "block1" end
	return "inner"
end

local function band_neighbour(x, z)
	local near_k = math.max(KX - x, x - (KX + 79), KZ - z, z - (KZ + 79)) <= 16
	local outer = math.min(x - (KX - 80), KX + 159 - x, z - (KZ - 80), KZ + 159 - z) < 16
	if near_k then return "nearK" elseif outer then return "outer" end
	return "inner"
end

local function compare(c)
	local file = io.open(dir .. "/" .. c.id .. ".bin", "rb")
	if not file then return log(c.id .. " no snapshot") end
	local all = file:read("*a")
	file:close()
	local nl = all:find("\n", 1, true)
	local old_names = {}
	for name in all:sub(1, nl - 1):gmatch("[^\t]+") do old_names[#old_names + 1] = name end
	local data, p2, area = read_chunk(c)
	local byte, minp, maxp = string.byte, c.minp, c.maxp
	local o, total, bands, trans, sample = nl + 1, 0, {}, {}, {}
	local cache = {}
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local vi = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				local a, b, q = byte(all, o, o + 2)
				o = o + 3
				local old = old_names[a + 256 * b]
				local cid = data[vi]
				local new = cache[cid]
				if not new then new = core.get_name_from_content_id(cid); cache[cid] = new end
				local key
				if old ~= new then key = old .. ">" .. new
				elseif q ~= p2[vi] then key = "p2:" .. new end
				if key then
					total = total + 1
					local band = c.kept and band_kept(x, z) or band_neighbour(x, z)
					bands[band] = (bands[band] or 0) + 1
					trans[key] = (trans[key] or 0) + 1
					if not sample[key] then sample[key] = ("%d,%d,%d"):format(x, y, z) end
				end
				vi = vi + 1
			end
		end
	end
	local keys = {}
	for key in pairs(trans) do keys[#keys + 1] = key end
	table.sort(keys, function(l, r) return trans[l] > trans[r] or (trans[l] == trans[r] and l < r) end)
	local top = {}
	for i = 1, math.min(8, #keys) do
		top[#top + 1] = ("%s x%d @%s"):format(keys[i], trans[keys[i]], sample[keys[i]])
	end
	local band_list = {}
	for _, band in ipairs({"edge", "block1", "inner", "nearK", "outer"}) do
		if bands[band] then band_list[#band_list + 1] = band .. "=" .. bands[band] end
	end
	local acts = {}
	for name, count in pairs(c.actions) do acts[#acts + 1] = name .. "=" .. count end
	table.sort(acts)
	log(("diff %s %s blocks[%s] changed=%d (%s) %s"):format(c.id, c.kept and "KEPT" or "regen",
		table.concat(acts, ","), total, table.concat(band_list, ","), table.concat(top, "; ")))
end

-- The seam on K's four sides: ground inside K's edge column vs just outside.
local function seam(label)
	local source = grug_mapgen.wp40.planner_source
	local hist, max_dy, pred_err, n = {}, 0, {}, 0
	local function bucket(v)
		v = math.abs(v)
		if v == 0 then return "0" elseif v == 1 then return "1" elseif v <= 3 then return "2-3"
		elseif v <= 7 then return "4-7" elseif v <= 15 then return "8-15" end
		return "16+"
	end
	local sides = {}
	for i = 0, 79 do
		sides[#sides + 1] = {KX, KZ + i, KX - 1, KZ + i}
		sides[#sides + 1] = {KX + 79, KZ + i, KX + 80, KZ + i}
		sides[#sides + 1] = {KX + i, KZ, KX + i, KZ - 1}
		sides[#sides + 1] = {KX + i, KZ + 79, KX + i, KZ + 80}
	end
	local worst
	for _, s in ipairs(sides) do
		local gin = ground_y(s[1], s[2])
		local gout, nout = ground_y(s[3], s[4])
		if gin and gout then
			n = n + 1
			local dy = gout - gin
			local bk = bucket(dy)
			hist[bk] = (hist[bk] or 0) + 1
			if math.abs(dy) > math.abs(max_dy) then
				max_dy = dy
				worst = ("%d,%d in %d out %d (%s)"):format(s[3], s[4], gin, gout, nout)
			end
			local terrain_y = select(6, source.column_values_at(s[3], s[4]))
			if terrain_y then
				local eb = bucket(terrain_y - gout)
				pred_err[eb] = (pred_err[eb] or 0) + 1
			end
		end
	end
	local function fmt(t)
		local out = {}
		for _, k in ipairs({"0", "1", "2-3", "4-7", "8-15", "16+"}) do
			if t[k] then out[#out + 1] = k .. ":" .. t[k] end
		end
		return table.concat(out, " ")
	end
	log(("seam %s columns=%d |dy| %s; max dy %d at %s; |predicted-found outside| %s"):format(
		label, n, fmt(hist), max_dy, tostring(worst), fmt(pred_err)))
end

local MARK = {}
local function marker_positions()
	local g = {}
	local function gy(x, z)
		local key = x .. "," .. z
		if not g[key] then g[key] = ground_y(x, z) or 0 end
		return g[key]
	end
	MARK.pillar = {}
	for dz = 5, 7 do
		local y = gy(KX, KZ + dz)
		for dy = 1, 3 do MARK.pillar[#MARK.pillar + 1] = {x = KX, y = y + dy, z = KZ + dz} end
	end
	MARK.trench = {}
	for x = KX, KX + 2 do
		for z = KZ + 20, KZ + 30 do
			local y = gy(x, z)
			for yy = y - 3, y do MARK.trench[#MARK.trench + 1] = {x = x, y = yy, z = z} end
		end
	end
	MARK.chest = {x = KX, y = gy(KX, KZ + 40) + 1, z = KZ + 40}
	MARK.pocket = {}
	for x = KX, KX + 2 do
		for z = KZ + 50, KZ + 52 do
			for y = -100, -98 do MARK.pocket[#MARK.pocket + 1] = {x = x, y = y, z = z} end
		end
	end
	MARK.item = {x = KX + 40, y = gy(KX + 40, KZ + 40) + 1, z = KZ + 40}
end

local function place_markers()
	for _, p in ipairs(MARK.pillar) do core.set_node(p, {name = "default:cobble"}) end
	for _, p in ipairs(MARK.trench) do core.set_node(p, {name = "air"}) end
	for _, p in ipairs(MARK.pocket) do core.set_node(p, {name = "air"}) end
	core.set_node(MARK.chest, {name = "default:chest"})
	local meta = core.get_meta(MARK.chest)
	meta:set_string("hkeep", "marker")
	meta:get_inventory():add_item("main", "default:apple 5")
	core.add_item(MARK.item, "default:apple 3")
	local file = assert(io.open(dir .. "/markers.lua", "w"))
	file:write("return " .. core.serialize(MARK):gsub("^return ", ""))
	file:close()
	log(("markers placed: chest %s item %s"):format(core.pos_to_string(MARK.chest),
		core.pos_to_string(MARK.item)))
end

local function check_markers(done)
	local m = dofile(dir .. "/markers.lua")
	local bad = 0
	for _, p in ipairs(m.pillar) do if core.get_node(p).name ~= "default:cobble" then bad = bad + 1 end end
	local trench_bad, pocket_bad = 0, 0
	for _, p in ipairs(m.trench) do if core.get_node(p).name ~= "air" then trench_bad = trench_bad + 1 end end
	for _, p in ipairs(m.pocket) do if core.get_node(p).name ~= "air" then pocket_bad = pocket_bad + 1 end end
	local chest = core.get_node(m.chest).name
	local meta = core.get_meta(m.chest)
	local apples = meta:get_inventory():contains_item("main", "default:apple 5")
	log(("markers: pillar missing %d of %d, trench not air %d of %d, pocket not air %d of %d, " ..
		"chest %s meta=%s apples=%s"):format(bad, #m.pillar, trench_bad, #m.trench, pocket_bad,
		#m.pocket, chest, meta:get_string("hkeep"), tostring(apples)))
	-- The item entity is static data in its block: activate the block, then look.
	core.forceload_block(m.item, true)
	core.after(4, function()
		local found = 0
		for _, obj in ipairs(core.get_objects_inside_radius(m.item, 4)) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "__builtin:item" and ent.itemstring == "default:apple 3" then
				found = found + 1
			end
		end
		log(("item entity in K: found %d"):format(found))
		core.forceload_free_block(m.item, true)
		done()
	end)
end

local function finish()
	log("RESULT DONE " .. config.mode)
	core.after(1, function() core.request_shutdown("hkeep probe done") end)
end

local function after_emerge()
	if config.mode == "build" then
		marker_positions()
		place_markers()
		seam("original")
		core.after(2, function()
			local t0 = core.get_us_time()
			for _, c in ipairs(chunks) do snapshot(c) end
			log(("snapshots written: %d chunks in %.1f s"):format(#chunks,
				(core.get_us_time() - t0) / 1e6))
			finish()
		end)
	else
		check_markers(function()
			for _, c in ipairs(chunks) do compare(c) end
			seam(config.tag or "check")
			finish()
		end)
	end
end

local function emerge()
	local t0 = core.get_us_time()
	log("emerge start")
	core.emerge_area({x = KX - 80, y = -112, z = KZ - 80}, {x = KX + 159, y = 127, z = KZ + 159},
		function(blockpos, action, remaining)
			local c = chunk_of_block(blockpos)
			local name = ACTION[action] or tostring(action)
			if c then c.actions[name] = (c.actions[name] or 0) + 1 end
			if remaining == 0 then
				log(("emerge done in %.1f s"):format((core.get_us_time() - t0) / 1e6))
				core.after(0, after_emerge)
			end
		end)
end

local function wait_ready()
	local status = grug_core.world_preparation_status()
	if status.ready then
		log(("preparation ready (%d chunks)"):format(status.total))
		return emerge()
	end
	if status.failed then log("preparation FAILED"); return finish() end
	core.after(1, wait_ready)
end
core.after(1, wait_ready)
log("loaded mode " .. config.mode)

-- The seed fleet's world (Round 37, audit MGT-01/MGS-02/MGT-07): the real R7
-- mapgen runtime of one seed without the engine (LuaJIT), as main and emerge
-- build it, plus a fake VoxelManip, so the real per-chunk path
-- (`session.plan_slice` and `writer.apply`) runs on any seed.
--
--   local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed[, mode])
--   R.main             main's runtime (r7_runtime.lua, no layout texts: a
--                      world's first start)
--   R.built            the session and writer: main's own `build` (default),
--                      or with mode "emerge" emerge's runtime and build from
--                      main's layout texts and prepared handover, checked
--                      against main's build_authority (R.authority), as the
--                      engine builds it
--   R.chunk(minp[, hooks]) plans and writes the 80^3 chunk at minp (hooks:
--                      optional before_plan / after_plan functions); returns
--                      {result, plan, data_hash, candidates (the owner-root
--                      decoration rows, a string), plan_seconds,
--                      write_seconds}
--   R.new_vm(minp)     the fake VoxelManip of a chunk (sets the heightmap
--                      the next write reads); R.written_hash(vm) the hash of
--                      what it holds after a write
--   R.seconds          {main, build}: CPU seconds of the two constructions
--
-- The engine seams are stand-ins, so a chunk's bytes are this harness's and
-- not the engine's (compare runs of the harness with each other, never with
-- a world):
--   * nodes: the real registrations of default, grug_trees, grug_materials,
--     grug_nodes, doors and grug_decor (the Round 24 mining harness,
--     tools/r24_mining/fixture.lua), grug_gathering's sources and
--     grug_mapgen's world nodes, so the frozen content semantics hold; any
--     other name the mapgen asks for (the settlement palette's furniture) is
--     registered on demand as a plain solid node. Content ids are this
--     harness's own;
--   * schematics: the MTS files read as the engine's read_schematic returns
--     them (tools/wp40/r6/common.lua read_mts);
--   * the VoxelManip: v7's chunk stood in by stone up to the planned ground
--     with smooth cave pockets, water up to y 1 and air above, the 16-node
--     shell filled the same way (a generated neighbour), lighting calls
--     accepted and ignored; the heightmap is that ground.
return function(repo, seed, mode)
	seed = tostring(seed)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()

	-- The real node registrations (they also set the global grug_materials).
	_G.R24_MINING_HARNESS = true
	local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
	_G.R24_MINING_HARNESS = nil
	local gathering_path = repo .. "/mods/ITEMS/grug_gathering"
	local catalog = dofile(gathering_path .. "/catalog.lua")
	dofile(gathering_path .. "/nodes.lua")(H.core, catalog,
		dofile(gathering_path .. "/harvest.lua")({core = H.core}))
	dofile(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua")(H.core,
		repo .. "/mods/MAPGEN/grug_mapgen", rawget(_G, "grug_nodes"),
		{source_can_dig = function() return function() return true end end})

	-- Node registry and content ids.
	local CONTENT_UNKNOWN, CONTENT_AIR, CONTENT_IGNORE = 125, 126, 127
	local nodes = setmetatable({}, {__index = function(t, name)
		if type(name) ~= "string" or not name:match("^[%w_]+:[%w_]+$") then return nil end
		local def = {name = name, groups = {}, walkable = true}
		rawset(t, name, def)
		return def
	end})
	for name, def in pairs(H.nodes) do rawset(nodes, name, def) end
	-- A content id is a function of the name alone (the mapgen asks for ids
	-- in `pairs` order, which varies between runs), well below 2^31.
	local cid_of, name_of = {air = CONTENT_AIR, ignore = CONTENT_IGNORE},
		{[CONTENT_AIR] = "air", [CONTENT_IGNORE] = "ignore"}
	local function get_content_id(name)
		local cid = cid_of[name]
		if cid then return cid end
		if not nodes[name] then error("unknown node " .. tostring(name)) end
		local a, b, c, d = raw_sha256(name):byte(1, 4)
		cid = 1000 + ((a % 64) * 16777216 + b * 65536 + c * 256 + d)
		if name_of[cid] then error("harness: content id collision " .. name) end
		cid_of[name], name_of[cid] = cid, name
		return cid
	end

	local settings = {num_emerge_threads = "1"}
	local mapgen_settings = {mg_name = "v7", water_level = "1", mapgen_limit = "31007",
		chunksize = "5", mgv7_dungeon_ymin = "-31000", mgv7_dungeon_ymax = "-193",
		mg_flags = "caves, dungeons, light, decorations, biomes, ores",
		mgv7_spflags = "mountains, ridges, nofloatlands, caverns", seed = seed}
	local heightmap = {}
	local fake = {
		registered_nodes = nodes, CONTENT_AIR = CONTENT_AIR, CONTENT_IGNORE = CONTENT_IGNORE,
		CONTENT_UNKNOWN = CONTENT_UNKNOWN,
		get_content_id = get_content_id,
		get_name_from_content_id = function(cid) return name_of[cid] or "unknown" end,
		get_mapgen_setting = function(name) return mapgen_settings[name] end,
		settings = {get = function(_, name) return settings[name] end,
			get_bool = function(_, _, default) return default end},
		sha256 = function(bytes, raw)
			local digest = raw_sha256(bytes)
			return raw and digest or common.hex(digest)
		end,
		read_schematic = function(path)
			local mts = common.read_mts(path)
			return {size = mts.size, yslice_prob = mts.yslice_prob, data = mts.data}
		end,
		get_mapgen_object = function(kind)
			if kind ~= "heightmap" then error("mapgen object " .. tostring(kind)) end
			return heightmap
		end,
	}

	local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
	local projection = handoff.project(rawget(_G, "grug_materials"))
	local native = dofile(wp40 .. "/r7_native.lua")
	local schematics = repo .. "/mods/BASE/default/schematics"

	-- The settlement palette the content contract checks (rawget): the sorted
	-- union r7_runtime.lua builds, read off its build closure.
	local function upvalue(fn, wanted)
		for index = 1, 255 do
			local name, value = debug.getupvalue(fn, index)
			if name == nil then break end
			if name == wanted then return value end
		end
		error("harness: upvalue " .. wanted .. " not found")
	end
	local function register_palette(runtime)
		for _, name in ipairs(upvalue(upvalue(runtime.build, "build"), "settlement_palette")) do
			local _ = nodes[name]
		end
	end

	local runtime_factory = dofile(wp40 .. "/r7_runtime.lua")
	local R = {fake = fake, seed = seed, sha = raw_sha256, seconds = {}}
	local t0 = os.clock()
	R.main = runtime_factory(fake, wp40, schematics, projection, catalog)
	register_palette(R.main)
	local t1 = os.clock()
	R.seconds.main = t1 - t0
	if mode == "emerge" then
		R.authority = R.main.build_authority(native.identities())
		local runtime = runtime_factory(fake, wp40, schematics, projection, catalog,
			R.main.water_layout_text(), R.main.road_layout_text(),
			R.main.capital_layout_text(), R.main.prepared_handover())
		register_palette(runtime)
		R.built = runtime.build(native.identities(), R.authority.manifest.sha256)
		if R.built.full_seed ~= R.authority.full_seed then error("main/emerge seed differs") end
	else
		R.built = R.main.build(native.identities())
	end
	R.seconds.build = os.clock() - t1

	-- The planned ground of a column (the stand-in for v7's surface).
	local function ground_at(x, z)
		return R.built.zones_session.terrain_height_at(x, z)
	end

	local stone, water = get_content_id("default:stone"), get_content_id("default:water_source")
	local function cave(x, y, z)
		return math.sin(x * 0.11) + math.sin(z * 0.13) + math.sin(y * 0.17 + x * 0.05) > 2.2
	end

	-- The fake VoxelManip of one chunk: native data, the writer's results kept.
	local function new_vm(minp, maxp)
		local eminx, eminy, eminz = minp.x - 16, minp.y - 16, minp.z - 16
		local emaxx, emaxy, emaxz = maxp.x + 16, maxp.y + 16, maxp.z + 16
		local ground = {}
		for z = eminz, emaxz do
			for x = eminx, emaxx do ground[(z - eminz) * 112 + (x - eminx) + 1] = ground_at(x, z) end
		end
		local data, param2, light = {}, {}, {}
		local i = 0
		for z = eminz, emaxz do
			for y = eminy, emaxy do
				for x = eminx, emaxx do
					i = i + 1
					local h = ground[(z - eminz) * 112 + (x - eminx) + 1]
					if y <= h then
						data[i], light[i] = (y < h - 4 and cave(x, y, z)) and CONTENT_AIR or stone, 0
					elseif y <= 1 then
						data[i], light[i] = water, 0
					else
						data[i], light[i] = CONTENT_AIR, 15
					end
					param2[i] = 0
				end
			end
		end
		-- v7's heightmap: the highest walkable node of the chunk's column, or
		-- -31007 (Mapgen::findGroundLevel).
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				local found = -31007
				for y = maxp.y, minp.y, -1 do
					if data[(z - eminz) * 12544 + (y - eminy) * 112 + (x - eminx) + 1] == stone then
						found = y
						break
					end
				end
				heightmap[(z - minp.z) * 80 + (x - minp.x) + 1] = found
			end
		end
		local vm = {written = {}}
		local emin, emax = {x = eminx, y = eminy, z = eminz}, {x = emaxx, y = emaxy, z = emaxz}
		local function fill(source)
			return function(_, buffer)
				buffer = buffer or {}
				for index = 1, #source do buffer[index] = source[index] end
				return buffer
			end
		end
		vm.get_emerged_area = function() return emin, emax end
		vm.get_data, vm.get_param2_data, vm.get_light_data = fill(data), fill(param2), fill(light)
		local function keep(key)
			return function(_, buffer)
				local copy = {}
				for index = 1, #buffer do copy[index] = buffer[index] end
				vm.written[key] = copy
			end
		end
		vm.set_data, vm.set_param2_data, vm.set_light_data = keep("data"), keep("param2"),
			keep("light")
		vm.set_lighting = function() end
		vm.calc_lighting = function() end
		vm.update_liquids = function() end
		vm.native = {data = data, param2 = param2}
		return vm
	end

	-- Two 31-bit polynomial hashes over content and param2 (what the chunk
	-- would hold after the transaction).
	local function hash_volume(data, param2)
		local a, b = 7, 11
		for index = 1, #data do
			local v = data[index] * 256 + param2[index]
			a = (a * 31 + v) % 2147483647
			b = (b * 37 + v) % 2147483629
		end
		return ("%08x%08x"):format(a, b)
	end

	-- The plan's decoration candidates rooted inside the owner, in plan order.
	local function owner_candidates(plan)
		local parts = {}
		for cell = 1, plan.candidate_cell_count do
			local base = (cell - 1) * 4
			for candidate = plan.candidate_cell_values[base + 3],
					plan.candidate_cell_values[base + 4] - 1 do
				local cb = (candidate - 1) * 14
				local v = plan.candidate_values
				local x, y, z = v[cb + 4], v[cb + 5], v[cb + 6]
				if x >= plan.min_x and x <= plan.max_x and y >= plan.min_y and y <= plan.max_y and
						z >= plan.min_z and z <= plan.max_z then
					for k = 1, 14 do parts[#parts + 1] = ("%.0f"):format(v[cb + k]) end
				end
			end
		end
		return table.concat(parts, ",")
	end

	function R.new_vm(minp)
		return new_vm(minp, {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79})
	end
	function R.written_hash(vm)
		return hash_volume(vm.written.data or vm.native.data,
			vm.written.param2 or vm.native.param2)
	end

	function R.chunk(minp, hooks)
		minp = {x = minp.x, y = minp.y, z = minp.z}
		local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
		local vm = new_vm(minp, maxp)
		if hooks and hooks.before_plan then hooks.before_plan() end
		local t1 = os.clock()
		local plan, generation = R.built.session.plan_slice(minp, maxp)
		local t2 = os.clock()
		if hooks and hooks.after_plan then hooks.after_plan() end
		local candidates = owner_candidates(plan)
		local result = R.built.writer.apply(vm, minp, maxp, plan, generation)
		local t3 = os.clock()
		return {result = result, plan = plan, candidates = candidates,
			data_hash = R.written_hash(vm),
			plan_seconds = t2 - t1, write_seconds = t3 - t2}
	end

	-- The chunk origin holding a world coordinate.
	function R.origin(value)
		local block = math.floor(value / 16)
		return (math.floor((block + 2) / 5) * 5 - 2) * 16
	end
	R.ground_at = ground_at
	return R
end

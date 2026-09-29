-- Round 24 Lane I portable fixture (LuaJIT): housing areas are ordinary
-- terrain (ruling 33).
--
--   luajit tools/r24_housing_terrain/fixture.lua "$PWD" [seed ...]
--   R24_I_ELIGIBILITY_ONLY=1 ... prints only the claim-eligibility digest
--   (run it on a main checkout too: the digest must not change).
--
-- Builds the real zones.lua / simple_map.lua / height.lua world of each seed
-- twice: as shipped, and with the horizontal session's housing mask stubbed
-- out (housing_mask_id_at always nil). On a sample of housing-mask columns of
-- all ten masks the two worlds must decide alike:
--   1. the planner column tuple, the surface-cave run and the claim
--      exclusions of every purpose;
--   2. the surface-cave candidates of every cave cell over a housing mask
--      (mouths and tunnels may now open in housing areas);
--   3. the shallow bands, cliff layers and rock nests: the production strata
--      and layer passes (r6_settlement.lua) on a real 16 x 16 patch of every
--      mask, each world handing the writer its own mask;
--   4. runtime renewal: the vegetation authority (surface and cave sites,
--      with the runtime's ruling-30 cave deps) and grug_farming/renewal.lua's
--      evaluate() on a flat synthetic ground at the planned height -- its
--      planner raises if the housing mask is consulted and its api has no
--      claim-aware permission at all;
--   5. no mapgen writer and no renewal file names the housing mask or the
--      claim guards (source scan); the mask stays for claim eligibility;
--   6. claim eligibility: a digest of housing_mask_id_at and
--      housing_eligible_at over the masks, unchanged against main.
-- Prints the counts and "R24 HOUSING TERRAIN FIXTURE PASS checks=<n>", or the
-- failures and an error. evidence/: this run, the same run against main
-- (fails: the checks have teeth) and the engine before/after comparison of a
-- housing and a non-housing box (engine/run.sh, engine/analyze.py).
local repo = assert(arg[1], "usage: fixture.lua <repo> [seed ...]")
local seeds = {}
for index = 2, #arg do seeds[#seeds + 1] = arg[index] end
if #seeds == 0 then seeds = {"4242424242", "10536739806879207652"} end
local ELIGIBILITY_ONLY = os.getenv("R24_I_ELIGIBILITY_ONLY") == "1"

local checks, failures, first_failures = 0, 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if #first_failures < 80 then first_failures[#first_failures + 1] = label end
	end
end
local lines = {}
local function out(text) lines[#lines + 1] = text; print(text) end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local function digest(text) return common.hex(sha(text)):sub(1, 16) end

-- ---------------------------------------------------------------------------
-- World (as tools/r24_protection_depth/fixture.lua)
-- ---------------------------------------------------------------------------
local CITY_HALF = 120
local function build_world(seed, stub_mask)
	local tdata = dofile(dir .. "/terrain_data.lua")
	local source = dofile(dir .. "/source/simple_map.lua")
	local simple_map_factory = dofile(dir .. "/simple_map.lua")(dofile(dir .. "/zone_field.lua"))
	local shapes = {}
	for index = 1, #source.anchors do
		local anchor = source.anchors[index]
		if anchor.slot_id == "capital" then
			local ax, az = anchor.position.x, anchor.position.z
			shapes[anchor.id] = {member = function(x, z)
				return math.abs(x - ax) <= CITY_HALF and math.abs(z - az) <= CITY_HALF
			end}
		end
	end
	local protection_holder = {shapes = shapes}
	local captured = {}
	local function horizontal_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.capital_protection = protection_holder
		local module = simple_map_factory(bound)
		local new = module.new
		module.new = function(...)
			local session = new(...)
			captured.mask = session.housing_mask_id_at
			if stub_mask then
				function session.housing_mask_id_at() return nil end
			end
			return session
		end
		return module
	end
	local water = {module = dofile(dir .. "/water_layout.lua")(tdata.water),
		authored = dofile(dir .. "/water_authored.lua")(tdata.water), plot_rects = {}}
	local hf = dofile(dir .. "/height.lua")
	_G.core = _G.core or {}
	local settlement = dofile(dir .. "/r7_settlement.lua")
	local palette = dofile(dir .. "/../wp13/palette.lua")
	local TWIN = {["default:dirt_with_dry_grass"] = "default:dry_dirt_with_dry_grass"}
	local start_grounds = {}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "start" then
			local ground = palette.races[profile.race].ground
			start_grounds[profile.anchor_id] = {ground = TWIN[ground] or ground}
		end
	end
	local function height_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.water = water
		bound.start_grounds = start_grounds
		return hf(bound)
	end
	local zones = dofile(dir .. "/zones.lua")({source = source,
		schemas = dofile(dir .. "/schemas.lua"), canonical = dofile(dir .. "/canonical.lua"),
		deterministic = dofile(dir .. "/deterministic.lua"),
		index128 = dofile(dir .. "/index128.lua"), horizontal_factory = horizontal_factory,
		height_factory = height_factory,
		terrain_field = dofile(dir .. "/terrain_field.lua")(tdata), raw_sha256 = sha})
	local session, planner_source = zones.new_with_planner_source_runtime(seed, 1)
	-- `mask` is the real mask in both worlds (sampling only).
	return {session = session, planner_source = planner_source, source = source,
		mask = captured.mask}
end

local function mask_bounds(row)
	if row.coastal_window then return row.coastal_window end
	local b = {min_x = math.huge, max_x = -math.huge, min_z = math.huge, max_z = -math.huge}
	for _, p in ipairs(row.polygon) do
		b.min_x, b.max_x = math.min(b.min_x, p.x), math.max(b.max_x, p.x)
		b.min_z, b.max_z = math.min(b.min_z, p.z), math.max(b.max_z, p.z)
	end
	return b
end

-- ---------------------------------------------------------------------------
-- 6. Claim eligibility digest
-- ---------------------------------------------------------------------------
local function eligibility_digest(W)
	local parts, eligible, masked = {}, 0, 0
	for _, row in ipairs(W.source.housing_masks) do
		local b = mask_bounds(row)
		for x = b.min_x, b.max_x, 16 do
			for z = b.min_z, b.max_z, 16 do
				local id = W.planner_source.housing_mask_id_at(x, z)
				if id then masked = masked + 1 end
				parts[#parts + 1] = tostring(id)
			end
		end
		for x = b.min_x + 7, b.max_x, 97 do
			for z = b.min_z + 7, b.max_z, 97 do
				local ok = W.session.housing_eligible_at(x, z)
				if ok then eligible = eligible + 1 end
				parts[#parts + 1] = ok and "E" or "-"
			end
		end
	end
	return digest(table.concat(parts, ",")), masked, eligible
end

if ELIGIBILITY_ONLY then
	for _, seed in ipairs(seeds) do
		local d, masked, eligible = eligibility_digest(build_world(seed, false))
		print(("seed %s: claim eligibility digest %s (%d mask samples, %d eligible" ..
			" centres)"):format(seed, d, masked, eligible))
	end
	return
end

-- ---------------------------------------------------------------------------
-- 5. Source scan
-- ---------------------------------------------------------------------------
do
	-- Where the housing identifiers may appear: the mask's owner, the
	-- eligibility query, the planner bridge that carries it read-only and the
	-- runtime authority's public claim query.
	local allowed = {
		housing_mask_id_at = {["wp40/simple_map.lua"] = true, ["wp40/zones.lua"] = true,
			["wp40/planner.lua"] = true},
		housing_eligible_at = {["wp40/simple_map.lua"] = true, ["wp40/zones.lua"] = true,
			["grug_core/zone_authority.lua"] = true},
		housing_excluded_at = {},
		housing_exclusion = {},
		world_alterable = {["grug_core/protection.lua"] = true,
			["grug_core/water_guard.lua"] = true, ["grug_farming/bucket.lua"] = true},
		register_world_alteration_guard = {["grug_core/protection.lua"] = true},
	}
	-- No directory listing in plain Lua: every mod's files are found by
	-- following the ".lua" names its init.lua and the files it loads mention,
	-- resolved against the mod's own directories.
	local roots = {
		{"mods/MAPGEN/grug_mapgen", {"", "wp40/", "wp40/source/", "wp13/"}},
		{"mods/ITEMS/grug_farming", {""}}, {"mods/ITEMS/grug_gathering", {""}},
		{"mods/CORE/grug_core", {""}}, {"mods/ENTITIES/grug_mobs", {""}},
	}
	local function read(path)
		local handle = io.open(repo .. "/" .. path, "rb")
		if not handle then return nil end
		local text = handle:read("*a")
		handle:close()
		return text
	end
	local found, files, paths = {}, 0, {}
	for _, root in ipairs(roots) do
		local seen, queue = {}, {root[1] .. "/init.lua"}
		while #queue > 0 do
			local path = table.remove(queue, 1)
			local text = not seen[path] and read(path)
			seen[path] = true
			if text then
				paths[#paths + 1] = {path = path, text = text}
				for name in text:gmatch("([%w_]+%.lua)[\"']") do
					for _, sub in ipairs(root[2]) do
						local candidate = root[1] .. "/" .. sub .. name
						if not seen[candidate] then queue[#queue + 1] = candidate end
					end
				end
			end
		end
	end
	table.sort(paths, function(a, b) return a.path < b.path end)
	for _, entry in ipairs(paths) do
		local path, text = entry.path, entry.text
		files = files + 1
		local short = path:match("([^/]+/[^/]+)$")
		do
			for word, where in pairs(allowed) do
				-- whole identifiers only
				local position = 1
				while true do
					local s, e = text:find(word, position, true)
					if not s then break end
					local before = s > 1 and text:sub(s - 1, s - 1) or ""
					local after = text:sub(e + 1, e + 1)
					if not before:match("[%w_]") and not after:match("[%w_]") then
						if not where[short] then
							found[#found + 1] = word .. " in " .. path
						end
					end
					position = e + 1
				end
			end
		end
	end
	check(files > 50, "source scan found the mod files")
	for _, hit in ipairs(found) do check(false, "source scan: " .. hit) end
	out(("source scan: %d files, %d housing/claim references outside the claim" ..
		" code"):format(files, #found))
end

-- ---------------------------------------------------------------------------
-- Shared pieces
-- ---------------------------------------------------------------------------
local r6 = dofile(dir .. "/r6_settlement.lua")
local habitat = dofile(dir .. "/habitat_registry.lua")
local world_catalog = dofile(dir .. "/world_content_catalog.lua")
local gathering = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")

local function tuple_text(...)
	local n = select("#", ...)
	local parts = {}
	for index = 1, n do parts[index] = tostring((select(index, ...))) end
	return table.concat(parts, "|")
end

local function serial(value)
	if type(value) ~= "table" then return tostring(value) end
	local keys = {}
	for k in pairs(value) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. serial(value[k]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function new_density(W, seed)
	local P = W.planner_source
	return dofile(dir .. "/vegetation_density.lua")({
		habitat = habitat, world_plants = world_catalog.plants,
		p9g_rows = gathering.p9g_sources(),
		decorations = {}, template_records = {}, support_names = {},
		vegetation_rule = habitat.vegetation_rule(seed, P.land_zone_at),
		decoration_cover = function() return 1 end,
		column_values_at = P.column_values_at,
		overlay_exclusion_at = P.overlay_exclusion_at,
		surface_mob_level_at = W.session.surface_mob_level_at,
		primary_relief_at = P.primary_relief_at,
		static_exclusion_values_at = P.static_exclusion_values_at,
		surface_cave_run_at = P.surface_cave_run_at,
		-- the runtime's ruling-30 deps (r7_runtime.lua); the housing mask is
		-- handed in too, for a checkout that still reads it
		cave_limit = r6.r30_cave_limit, housing_mask_id_at = P.housing_mask_id_at,
		protected_floor_at = P.protected_floor_at,
		protected_only_floor_at = P.protected_only_floor_at,
	})
end

-- grug_farming/renewal.lua on a flat synthetic ground: the support node at
-- `ground` over every column, air above, no plants present.
local function new_renewal(W, density, state)
	local P = W.planner_source
	local planner = setmetatable({}, {__index = function(_, key)
		if key == "housing_mask_id_at" then
			error("renewal consulted the housing mask", 2)
		end
		return P[key]
	end})
	local api = {
		get_node_or_nil = function(pos)
			if pos.y == state.ground then return {name = state.support} end
			if pos.y > state.ground then return {name = "air"} end
			return {name = "default:stone"}
		end,
		set_node = function(pos, node) state.placed = node.name end,
		get_natural_light = function() return state.light end,
		find_nodes_in_area = function(_, _, _, grouped)
			return {}
		end,
		find_nodes_in_area_under_air = function(minp, maxp, names)
			local wanted = false
			for _, name in ipairs(names) do
				if name == state.support then wanted = true end
			end
			local list = {}
			if wanted and minp.y <= state.ground and maxp.y >= state.ground then
				for x = minp.x, maxp.x do
					for z = minp.z, maxp.z do
						list[#list + 1] = {x = x, y = state.ground, z = z}
					end
				end
			end
			return list
		end,
		get_item_group = function(name, group)
			return group == "soil" and name:find("dirt", 1, true) and 1 or 0
		end,
		density = density, planner = planner,
		natural_ground_alterable = function() return true end,
		random = function()
			state.seed = (state.seed * 16807) % 2147483647
			return state.seed / 2147483647
		end,
		trees = true, non_natural = {"default:cobble"},
	}
	return dofile(repo .. "/mods/ITEMS/grug_farming/renewal.lua")(api)
end

local SUPPORTS = {"default:dirt_with_grass", "default:dry_dirt_with_dry_grass",
	"default:dirt_with_dry_grass", "default:dirt_with_rainforest_litter",
	"default:dirt_with_coniferous_litter", "grug_nodes:dirt_with_forest_litter",
	"default:sand", "default:desert_sand", "default:dirt", "grug_nodes:mud",
	"default:gravel", "default:stone", "default:dirt_with_snow"}

-- The strata and layer passes on a real patch, as the writer calls them
-- (r6_settlement.lua): original native stone below the planned surface, the
-- world's own column tuple, claim exclusions and protected-only floors, and
-- -- for a checkout that still reads it -- the world's own housing mask.
local STONE = 1
local function run_bands(W, seed, x0, z0)
	local P = W.planner_source
	local names, cid_by_name = {[0] = "air", [STONE] = "default:stone"}, {}
	local function cid_of(name)
		local cid = cid_by_name[name]
		if not cid then
			cid = 10
			while names[cid] do cid = cid + 1 end
			names[cid], cid_by_name[name] = name, cid
		end
		return cid
	end
	local low, high = math.huge, -math.huge
	for x = x0, x0 + 15 do
		for z = z0, z0 + 15 do
			local terrain_y = select(6, P.column_values_at(x, z))
			low, high = math.min(low, terrain_y), math.max(high, terrain_y)
		end
	end
	local box = {min_x = x0, max_x = x0 + 15, min_z = z0, max_z = z0 + 15,
		min_y = math.max(-37, low - 90), max_y = high + 2}
	local ex, ey = 16, box.max_y - box.min_y + 1
	local function index_at(x, y, z)
		return (z - box.min_z) * ex * ey + (y - box.min_y) * ex + (x - box.min_x) + 1
	end
	local original, final, intent, writes = {}, {}, {}, {}
	for z = box.min_z, box.max_z do
		for x = box.min_x, box.max_x do
			local terrain_y = select(6, P.column_values_at(x, z))
			for y = box.min_y, box.max_y do
				local i = index_at(x, y, z)
				original[i] = y <= terrain_y and STONE or 0
				final[i], intent[i] = original[i], 0
			end
		end
	end
	local function write(x, y, z, ref)
		local i = index_at(x, y, z)
		final[i], intent[i] = ref, 2
		writes[#writes + 1] = x .. "/" .. y .. "/" .. z .. "=" .. names[ref]
	end
	local info, cap = {}, {}
	local strata = r6.r8_strata_new(seed, W.source)
	r6.r8_apply_strata({min_x = box.min_x, min_y = box.min_y, min_z = box.min_z,
		max_x = box.max_x, max_y = box.max_y, max_z = box.max_z, floor_y = -37,
		original_data = original, column_info = info, stone_cid = STONE,
		index_at = index_at, column_values_at = P.column_values_at,
		static_exclusion_values_at = P.static_exclusion_values_at,
		protected_only_floor_at = function(x, z)
			return P.protected_only_floor_at(x, z) or -math.huge
		end, column_cap = cap,
		housing_excluded_at = function(x, z) return P.housing_mask_id_at(x, z) ~= nil end,
		select_surface = function(_, x, z)
			-- a steep column (cliff face) where a neighbour lies 3+ lower
			local terrain_y = select(6, P.column_values_at(x, z))
			local steep = false
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				if terrain_y - select(6, P.column_values_at(x + d[1], z + d[2])) >= 3 then
					steep = true
				end
			end
			return {filler_depth = 4, steep = steep}
		end,
		strata = strata, content_ref = cid_of,
		fill_stone_at = function() return false end, write = write})
	r6.r24_apply_fill_layers({min_x = box.min_x, min_y = box.min_y,
		min_z = box.min_z, max_x = box.max_x, max_y = box.max_y,
		max_z = box.max_z, floor_y = -37, index_at = index_at, column_info = info,
		column_cap = cap, column_values_at = P.column_values_at,
		original_data = original, final_data = final, intent_opcode = intent,
		stone_cid = STONE, layers = r6.r24_fill_layers_new(seed),
		fill_stone_at = function() return false end, content_ref = cid_of,
		write = write})
	return writes
end

-- ---------------------------------------------------------------------------
-- Per seed
-- ---------------------------------------------------------------------------
for _, seed in ipairs(seeds) do
	local started = os.clock()
	local A = build_world(seed, false)
	local B = build_world(seed, true)
	out(("seed %s (two worlds built in %.1f s)"):format(seed, os.clock() - started))
	check(B.planner_source.housing_mask_id_at(0, 2100) == nil, "stubbed world has no mask")
	local PA, PB = A.planner_source, B.planner_source

	-- 6. Eligibility (the shipped world)
	local elig, masked, eligible = eligibility_digest(A)
	out(("seed %s: claim eligibility digest %s (%d mask samples, %d eligible" ..
		" centres)"):format(seed, elig, masked, eligible))
	check(masked > 0 and eligible > 0, "housing masks and eligible centres exist")

	-- Sample housing columns (step 24) of every mask.
	local samples, per_mask = {}, {}
	for _, row in ipairs(A.source.housing_masks) do
		local b = mask_bounds(row)
		per_mask[row.id] = 0
		for x = b.min_x, b.max_x, 24 do
			for z = b.min_z, b.max_z, 24 do
				if A.mask(x, z) == row.id then
					samples[#samples + 1] = {x = x, z = z, mask = row.id}
					per_mask[row.id] = per_mask[row.id] + 1
				end
			end
		end
	end
	for id, count in pairs(per_mask) do check(count > 0, id .. " sampled") end
	check(#samples > 1000, "enough housing samples")

	-- 1. Planner tuple, surface caves, claim exclusions
	local tuple_diff, land = 0, 0
	for _, s in ipairs(samples) do
		local x, z = s.x, s.z
		local a = tuple_text(PA.column_values_at(x, z))
		local b = tuple_text(PB.column_values_at(x, z))
		if a ~= b then tuple_diff = tuple_diff + 1 end
		if PA.column_values_at(x, z) == "land" then land = land + 1 end
		for _, purpose in ipairs({false, "vegetation", "cave"}) do
			local p = purpose or nil
			check(tuple_text(PA.static_exclusion_values_at(x, z, p)) ==
				tuple_text(PB.static_exclusion_values_at(x, z, p)),
				"claim exclusion " .. tostring(purpose) .. " at " .. x .. "," .. z)
		end
		check(tuple_text(PA.surface_cave_run_at(x, z)) ==
			tuple_text(PB.surface_cave_run_at(x, z)), "surface cave run at " .. x .. "," .. z)
		check(PA.housing_mask_id_at(x, z) == s.mask, "shipped mask kept at " .. x .. "," .. z)
	end
	check(tuple_diff == 0, "planner tuple differs on " .. tuple_diff .. " housing columns")
	out(("seed %s: %d housing samples (%d land) over %d masks; planner tuple," ..
		" surface-cave run and claim exclusions equal: %d tuple differences"):format(
		seed, #samples, land, #A.source.housing_masks, tuple_diff))

	-- 2. Surface-cave candidates of every cell over a mask
	local cells, cell_list = {}, {}
	for _, s in ipairs(samples) do
		local cx, cz = PA.surface_cave_cell_at(s.x, s.z)
		local key = cx .. "," .. cz
		if not cells[key] then
			cells[key] = true
			cell_list[#cell_list + 1] = {cx, cz}
		end
	end
	local candidates, cave_diff, in_housing = 0, 0, 0
	for _, cell in ipairs(cell_list) do
		local a = PA.surface_cave_candidate_at_cell(cell[1], cell[2])
		local b = PB.surface_cave_candidate_at_cell(cell[1], cell[2])
		if serial(a) ~= serial(b) then cave_diff = cave_diff + 1 end
		if a then
			candidates = candidates + 1
			if a.mouth_x and A.mask(a.mouth_x, a.mouth_z) then in_housing = in_housing + 1 end
		end
	end
	check(cave_diff == 0, "surface-cave candidates differ in " .. cave_diff .. " cells")
	check(in_housing > 0, "some cave mouths lie in housing areas")
	out(("seed %s: %d cave cells over housing masks, %d candidates (%d mouths in a" ..
		" housing area), %d differ"):format(seed, #cell_list, candidates, in_housing,
		cave_diff))

	-- 3. Bands, cliff layers and nests on a patch of every mask
	local band_writes, band_diff, patches = 0, 0, 0
	for _, row in ipairs(A.source.housing_masks) do
		-- the first land sample of the mask whose 16 x 16 patch is all housing land
		for _, s in ipairs(samples) do
			if s.mask == row.id then
				local all = true
				for x = s.x, s.x + 15, 5 do
					for z = s.z, s.z + 15, 5 do
						if A.mask(x, z) ~= row.id or PA.column_values_at(x, z) ~= "land" or
								PA.static_exclusion_values_at(x, z) ~= nil then
							all = false
						end
					end
				end
				if all then
					local a = run_bands(A, seed, s.x, s.z)
					local b = run_bands(B, seed, s.x, s.z)
					patches = patches + 1
					band_writes = band_writes + #a
					if table.concat(a, ",") ~= table.concat(b, ",") then
						band_diff = band_diff + 1
					end
					check(#a > 0, row.id .. " patch has bands")
					break
				end
			end
		end
	end
	check(patches >= 8, "band patches in most masks")
	check(band_diff == 0, "bands/layers differ in " .. band_diff .. " patches")
	out(("seed %s: bands, cliff layers and nests on %d housing patches: %d writes," ..
		" %d patches differ"):format(seed, patches, band_writes, band_diff))

	-- 4. Renewal
	local DA, DB = new_density(A, seed), new_density(B, seed)
	local surface_open, cave_open, category_diff = 0, 0, 0
	local placed, evaluated, reasons_a = 0, 0, {}
	local state_a, state_b = {}, {}
	local RA = new_renewal(A, DA, state_a)
	local RB = new_renewal(B, DB, state_b)
	local far = {{x = 1e6, y = 0, z = 1e6}}
	for index, s in ipairs(samples) do
		local x, z = s.x, s.z
		local water, _, _, _, _, terrain_y = PA.column_values_at(x, z)
		if water == "land" then
			local chosen
			for _, support in ipairs(SUPPORTS) do
				local ca, ra = DA.categories(x, terrain_y + 1, z, support, 15)
				local cb, rb = DB.categories(x, terrain_y + 1, z, support, 15)
				if serial(ca) ~= serial(cb) or serial(ra) ~= serial(rb) then category_diff = category_diff + 1 end
				if ca and #ca > 0 then
					surface_open = surface_open + 1
					chosen = chosen or support
				end
			end
			for _, y in ipairs({-60, -150, terrain_y - 6}) do
				if y <= terrain_y - 2 then
					local ca, ra = DA.categories(x, y, z, "default:stone", 0)
					local cb, rb = DB.categories(x, y, z, "default:stone", 0)
					if serial(ca) ~= serial(cb) or serial(ra) ~= serial(rb) then category_diff = category_diff + 1 end
					if ca and #ca > 0 then cave_open = cave_open + 1 end
				end
			end
			if chosen and index % 3 == 0 then
				for _, st in ipairs({state_a, state_b}) do
					st.ground, st.support, st.light, st.seed = terrain_y, chosen, 15, 4242 + index
					st.placed = nil
				end
				local ok_a, a, a_node = pcall(RA.evaluate, {x = x, y = terrain_y, z = z},
					far, {left = 1e9}, 0)
				local ok_b, b, b_node = pcall(RB.evaluate, {x = x, y = terrain_y, z = z},
					far, {left = 1e9}, 0)
				check(ok_a, "renewal evaluate at " .. x .. "," .. z .. ": " .. tostring(a))
				check(ok_b and a == b and a_node == b_node,
					"renewal equal at " .. x .. "," .. z .. ": " .. tostring(a) .. " / " .. tostring(b))
				evaluated = evaluated + 1
				reasons_a[tostring(a)] = (reasons_a[tostring(a)] or 0) + 1
				if a == "placed" then placed = placed + 1 end
			end
		end
	end
	check(category_diff == 0, "renewal categories differ at " .. category_diff .. " sites")
	check(surface_open > 0 and cave_open > 0, "renewal hosts surface and cave plants in housing")
	check(placed > 0, "renewal places plants in housing areas")
	local reason_list = {}
	for reason, count in pairs(reasons_a) do reason_list[#reason_list + 1] = reason .. " " .. count end
	table.sort(reason_list)
	out(("seed %s: renewal on housing columns: %d open surface support rows, %d open" ..
		" cave sites, %d category differences; evaluate() %d sites: %s"):format(seed,
		surface_open, cave_open, category_diff, evaluated, table.concat(reason_list, ", ")))
end

if failures > 0 then
	for _, label in ipairs(first_failures) do print("FAIL " .. label) end
	error(("R24 HOUSING TERRAIN FIXTURE FAIL %d/%d"):format(failures, checks), 0)
end
print(("R24 HOUSING TERRAIN FIXTURE PASS checks=%d"):format(checks))

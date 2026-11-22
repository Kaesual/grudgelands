-- One seed of the seed fleet (tools/run.sh): the real mapgen runtime as main
-- builds it on a world's first start (tools/seed_fleet/runtime.lua:
-- r7_runtime.lua over the shared world assembly -- inland water, roads,
-- capitals, every settlement prepared -- and its `build`: the zones session,
-- the R7 anchor roster and every settlement's configuration), every
-- tributary's junction stretch at most JOIN_MAX nodes, no open sea at the rim
-- of a bay (Round 51 T2), every camp of the Miner's Guild placed and
-- registered (Round 58: 36 with lifts, 6 under construction) with their
-- 148 rooms, and the
-- per-chunk path
-- (Round 37, audit MGT-01/MGS-02): a sample of chunks planned and written
-- through the real `plan_slice` and writer against a fake VoxelManip.
--
--   luajit tools/seed_fleet/seed.lua REPO SEED
--
-- The sample is a function of the seed: one map corner, the first coast on
-- the way from it to the centre, one sea mouth of a river, the edge of one
-- capital's protected city and the collar of one other settlement (a start,
-- village, outpost, camp or POI), each the chunk holding the column's ground
-- or water surface.
--
-- A seed may also name chunks of its own in tools/seed_fleet/chunks.txt (a
-- chunk that once failed in a real world, Round 41); they are planned and
-- written after the sample.
--
-- Every recipe quest place is placed on the seed (Round 60, quest_places
-- below).
--
-- The arena "Breach Road" (Round 85, arena below): its levelled hull is dry
-- land at the datum (no swamp pool either), no lake or river lies where its
-- blend grades, the middle road runs straight through both mouths at
-- the datum and on from each mouth to its capital, and the levelling adds
-- at most LIMIT (`breach_site.lua`) to the natural grade (4-node baseline,
-- both axes, across the zone border too, on the columns it reaches; road
-- columns follow their own profile); no camp, leader, quest place or rare
-- patrol point stands on its footprint and fringe (Round 85 lane TERRITORY,
-- ruling 13); the chunk columns of its footprint join the sample at the
-- datum, and at every chunk layer up to the arena's reach. In those chunks
-- the arena's blocks (Round 85 lane BUILD, `breach_model.lua`) are checked:
-- every cell of the model holds its node (the ground's roles and the
-- dressing their column's biome family, the rim its natural surface), solid
-- ground under every footprint column, only air above each column's highest
-- cell up to the reach (arena_blocks below).
--
-- Road cut walls (Round 86 lane ROADS, road_cuts below): at every road's
-- side zone edge the cut adds at most ROAD_CUT_LIMIT to the step between a
-- cut column and its neighbour off the roads (`tools/r86_roads/walls.lua`:
-- the cut meets the ground there, `road_layout.lua` CUT_FADE); columns in a
-- capital's protected city are exempt (the capital core keeps its ground,
-- a step at the core's edge is the town guard's; the exemption reaches the
-- whole protected city, its wall line + 21, wider than the civic cores where
-- such steps stand). Report only: road_face, the largest step a cut adds
-- over nature between neighbouring columns from a road's last column to 6
-- nodes beyond its edge (the slope's foot, its low wall included; sampled
-- every sixth node; the lift bound, CUT_FADE_LIFT, keeps it low, guarded by
-- tools/r86_roads/portable_test.lua).
--
-- Digest mode (Round 82, tools/r82_gen; opt-in, the printed line stays the
-- same): with a third argument the seed also writes a digest file there, one
-- line per item in a fixed order -- the roster, the tree roll-up, the world
-- layouts (water, roads, capitals, placement), every settlement's prepared
-- handover, its sockets and its blueprint identities (the manifest's
-- `*_blueprint_sha256`), the manifest digest (marked "info": an identity of
-- the contracts, not world output), then per chunk of the sample its written
-- nodes and param2, its light (runtime.lua `record_light`) and the waypost
-- texts main writes into it (the only metadata the generation writes,
-- init.lua). A fourth argument "dense" adds the digest chunks (a road, a
-- river's middle, a forest, the highest mountain and the chunk under it, a
-- village, a capital core and the fill floor y -112..-33 under the road or
-- the river), chosen by the seed like the sample.
--
--   luajit tools/seed_fleet/seed.lua REPO SEED [DIGEST_FILE [dense]]
--
-- Prints one line, "OK <seed> <seconds> <roster sha256> chunks=<n>
-- chunk_seconds=<s> trees=<the generated tree templates' roll-up, 16 hex>
-- places=<recipe quest places checked> place_seconds=<s> wayposts=<stacks>
-- arena_cells=<the arena's cells checked> arena_added=<the largest rise
-- the levelling adds over 4 nodes>/4[,fallback] road_cut=<the largest step a
-- road cut adds at its side zone's edge> road_cut_seconds=<s> road_face=<the
-- largest step a cut adds within 6 nodes of a road's edge>@<x>,<z>" or
-- "FAIL <seed> <seconds> <error>" and then raises (a non-zero exit). A failure
-- in the per-chunk path names the chunk.
local repo, seed, digest_file = arg[1], arg[2], arg[3]
local dense = arg[4] == "dense"
assert(repo and seed and seed:match("^%d+$") and (arg[4] == nil or (digest_file and dense)),
	"usage: seed.lua REPO SEED [DIGEST_FILE [dense]]")
local t0 = os.clock()
-- A tributary's last stretch (its snap onto the parent) stays short: on main
-- before Round 34 F3 the longest over 150 seeds was about 110 nodes; moving
-- the junction past a core adds at most 2 * (core radius + reach + pad) +
-- one step, under 200 for every core but a dragon arena (on the islands), so
-- 320 means the snap went astray (a long straight canyon).
local JOIN_MAX = 320
-- The sample's map corner: the corner of the world's query bounds.
local SOURCE = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local WORLD = SOURCE.world_bounds
local X_LIMIT, Z_LIMIT = WORLD.max_x, WORLD.max_z

local R, rivers
local function build()
	R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local module = dofile(dir .. "/water_layout.lua")(dofile(dir .. "/terrain_data.lua").water)
	rivers = module.deserialize(R.main.water_layout_text()).rivers
	for _, r in ipairs(rivers) do
		local n = #r.x
		if r.parent and n > 1 then
			local dx, dz = r.x[n] - r.x[n - 1], r.z[n] - r.z[n - 1]
			local d = math.sqrt(dx * dx + dz * dz)
			if d > JOIN_MAX then
				error(("river %d joins its parent across %.0f nodes (bound %d)")
					:format(r.id, d, JOIN_MAX), 0)
			end
		end
	end
	-- No open sea at the rim of a bay (Round 51 T2, sea plan ruling 4): no
	-- open-sea column within 32 nodes of planned water and 128 of land around
	-- each bay, every 16 nodes (the open sea begins 250-350 off the coast).
	local zones = R.built.zones_session
	local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, 1}, {1, -1}, {-1, -1}}
	local function near(x, z, wanted, reach, step)
		for d = step, reach, step do
			for _, o in ipairs(DIRS) do
				if zones.water_class_at(x + o[1] * d, z + o[2] * d) == wanted then return true end
			end
		end
		return false
	end
	-- Every camp is placed and registered (Round 58): the 20 mining camps and
	-- the 16 war camps with their lift columns, the 6 camps under
	-- construction, each in its own zone on a dry core (no wet resort), its
	-- settlement registered at the anchor the camp module names.
	do
		local C = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r58_camps.lua")
		local text = R.main.placement_layout_text()
		local camps, under = C.camps(text), C.under_construction(text)
		if #camps ~= 36 or #under ~= 6 then
			error(("camps: %d with lifts and %d under construction, not 36 and 6"):format(#camps,
				#under), 0)
		end
		local registered = {}
		for _, row in ipairs(R.main.settlement_sockets(R.built)) do registered[row.key] = row end
		local step_of = {}
		for line in text:gmatch("[^\n]+") do
			local id, step = line:match("^(anchor_%d+) %-?%d+ %-?%d+ (%d+)$")
			if id then step_of[id] = tonumber(step) end
		end
		local wet = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/placement_rules.lua").WET_RESORT
		for _, list in ipairs({camps, under}) do
			for _, camp in ipairs(list) do
				local row = registered[camp.id]
				if not row or row.anchor.x ~= camp.anchor.x or row.anchor.z ~= camp.anchor.z then
					error("camp " .. camp.id .. " is not registered at its anchor", 0)
				end
				if R.built.zones_session.id_at(camp.anchor.x, camp.anchor.z) ~= camp.zone_id then
					error("camp " .. camp.id .. " is not in its zone", 0)
				end
				if step_of[camp.anchor_id] == wet then
					error("camp " .. camp.id .. " found no dry core", 0)
				end
			end
		end
		-- Their rooms (Round 58 lane ROOMS, `guild_rooms.lua` through the game's
		-- seam): 148, no two boxes meeting (the index refuses that), each box
		-- in one y chunk of the grid -32 + 80k.
		local G = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/guild_rooms.lua")
		local rooms = G.index(G.lift_camps(repo .. "/mods/MAPGEN/grug_mapgen/wp40", text))
		if #rooms.list ~= 148 then
			error(("guild rooms: %d, not 148"):format(#rooms.list), 0)
		end
		for _, room in ipairs(rooms.list) do
			if math.floor((room.minp.y + 32) / 80) ~= math.floor((room.maxp.y + 32) / 80) then
				error("guild room of " .. room.camp_id .. " T" .. room.tier ..
					" crosses a chunk edge in y", 0)
			end
		end
	end
	for _, bay in ipairs(SOURCE.bays) do
		local cx = bay.centreline[1].x
		local sign = bay.deep_ocean_side == "min_z" and -1 or 1
		for zz = 1800, 3300, 16 do
			for x = cx - 1100, cx + 1100, 16 do
				local z = sign * zz
				if zones.water_class_at(x, z) == "deep_ocean" and
						near(x, z, "planned_water", 32, 16) and near(x, z, "land", 128, 32) then
					error(("open sea at the rim of %s (%d, %d)"):format(bay.id, x, z), 0)
				end
			end
		end
	end
end

-- Every recipe quest place stands on this seed (Round 60, the user's
-- ruling: round60-plan.md §2a point 7): the spawn regions of each zone whose
-- recipe has `places`, built offline as the game builds them
-- (spawn_regions_core.lua through its own query adapter on this runtime's
-- zones, planner and roads, as tools/r28_regions/regions.lua does), each
-- place placed (spawn_regions.md step 8). quest_targets.py checks the same
-- on the six rendered seeds; this covers every fleet seed. Returns the
-- count of places checked. The maps are built with the arena's fringe
-- reserved, as the game builds them (Round 85, `reserved_of`), and kept for
-- the arena's check below (region_map).
local region_maps = {}
local region_map
local function quest_places()
	local core = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local function read(path)
		local f = assert(io.open(path, "rb"))
		local text = f:read("*a")
		f:close()
		return text
	end
	local catalogue = {}
	do
		local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
		for _, row in ipairs(data[1] and data or data.subtypes) do catalogue[row.role] = row end
	end
	local labels = {}
	for _, row in ipairs(dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua").roster) do
		if row.anchor_id then labels[row.anchor_id] = row.label end
	end
	local zones = R.built.zones_session
	assert(R.planner_source and R.planner_source.column_values_at, "the runtime published no planner source")
	local L = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/breach_layout.lua")
	local q = core.queries({zones = zones, column_values_at = R.planner_source.column_values_at,
		road_polylines = R.main.road_polylines(), source = SOURCE,
		reserved = core.reserved_of(L.world(L.from_placement(R.main.placement_layout_text())))})
	local checked = 0
	local dir = repo .. "/mods/ENTITIES/grug_mobs/data/zones"
	local function recipe_data(zone)
		local f = io.open(dir .. "/" .. zone .. ".spawns.json", "rb")
		local data = f and json.parse(f:read("*a"))
		if f then f:close() end
		return data and data.recipe and data
	end
	-- the zone's region map (nil without a recipe), built once
	function region_map(zone)
		if region_maps[zone] == nil then
			local data = recipe_data(zone)
			region_maps[zone] = false
			if data then
				local record = zones.get(zone)
				local recipe = core.parse_recipe(zone, data.recipe, {
					band = {record.level_min, record.level_max},
					role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
					leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
					pois = function(id) return core.zone_pois(SOURCE, id, labels) end,
				})
				region_maps[zone] = {map = core.build(zone, q, recipe), recipe = recipe}
			end
		end
		return region_maps[zone] or nil
	end
	for _, row in ipairs(SOURCE.zones) do
		local zone = row.id
		local data = recipe_data(zone)
		if data and type(data.recipe.places) == "table" and #data.recipe.places > 0 then
			local built = region_map(zone)
			local map, recipe = built.map, built.recipe
			local placed = {}
			for _, place in ipairs(map.places or {}) do placed[place.id] = true end
			for _, place in ipairs(recipe.places) do
				if not placed[place.id] then
					error(("quest place %s/%s is not placed"):format(zone, place.id), 0)
				end
				checked = checked + 1
			end
		end
	end
	return checked
end

-- the largest rise the levelling adds over 4 nodes (printed: how near the
-- limit a seed comes) and whether the site is the search's fallback
local arena_added, arena_fallback = 0, false

-- The arena (Round 85): the checks above the sample's header names. The
-- natural ground comes from a roadless world built from main's placement
-- and water texts (emerge's way, `world_assembly.lua`). Returns its site.
local function arena()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local L = dofile(wp40 .. "/breach_layout.lua")
	local site = L.from_placement(R.main.placement_layout_text())
	local zones, q = R.built.zones_session, R.planner_source
	local where = ("arena %d,%d: "):format(site.x, site.z)
	for lz = -L.HALF_Z, L.HALF_Z do
		for lx = -L.HALF_X, L.HALF_X do
			if L.in_hull(lx, lz) then
				local x, z = site.x + lx, site.z + lz
				if zones.water_query_at(x, z) ~= nil then
					error(where .. ("water at %d,%d"):format(x, z), 0)
				end
				if zones.terrain_height_at(x, z) ~= site.y and q.road_column_at(x, z) ~= "surface" then
					error(where .. ("ground off the datum at %d,%d"):format(x, z), 0)
				end
			end
		end
	end
	local roads = dofile(wp40 .. "/road_layout.lua").deserialize(R.main.road_layout_text())
	local inner, legs = nil, {}
	for _, r in pairs(roads.roads) do
		if r.a == "breach_south" and r.b == "breach_north" then inner = r
		elseif r.a == "breach_south" or r.a == "breach_north" then legs[r.a] = r end
	end
	if not inner or #inner.X ~= 2 * L.HALF_Z + 1 then error(where .. "no inner road", 0) end
	for i = 1, #inner.X do
		if inner.X[i] ~= site.x or inner.R[i] ~= site.y then
			error(where .. "the inner road leaves the axis or the datum", 0)
		end
	end
	for _, m in ipairs(L.world(site).mouths) do
		local leg = legs["breach_" .. m.id]
		if not leg or math.abs(leg.X[1] - m.x) > 0.25 or leg.Z[1] ~= m.z or leg.R[1] ~= site.y or
				not leg.b:match("^anchor_") then
			error(where .. "no road from the " .. m.id .. " mouth to its capital", 0)
		end
		if q.road_column_at(m.x, m.z) ~= "surface" or zones.terrain_height_at(m.x, m.z) ~= site.y then
			error(where .. "the " .. m.id .. " mouth is no road at the datum", 0)
		end
	end
	local A = dofile(wp40 .. "/world_assembly.lua")(wp40, R.sha)
	local W = A.world(seed, {placement = R.main.placement_layout_text(),
		water = R.main.water_layout_text()}, {roads = false, protection = A.square_cities(120)})
	local source = W.place()
	local height = W.height_factory({source = source, canonical = A.canonical,
		deterministic = A.deterministic, raw_sha256 = R.sha,
		horizontal_session = W.horizontal_factory({source = source, schemas = A.schemas,
			canonical = A.canonical, deterministic = A.deterministic,
			raw_sha256 = R.sha}).new(seed),
		terrain_field = A.terrain_field}).new_runtime(seed)
	local natural = height.natural_height_at
	-- the columns the arena reaches (another fitting's may lie near)
	local profile = A.breach.profile(site, natural)
	local function reached(x, z)
		return A.breach.ground(profile, x, z, natural(x, z), natural) ~= nil
	end
	local limit = 4 * A.breach.P.LIMIT
	local stats = R.main.placement_stats()
	arena_fallback = stats and stats.breach and stats.breach.fallback or false
	local r = site.reach + 4
	-- (every pair 4 apart in x and z with a column the arena reaches, so the
	-- step across the hull's edge counts on all four sides)
	for lz = -L.HALF_Z - r - 4, L.HALF_Z + r do
		for lx = -L.HALF_X - r - 4, L.HALF_X + r do
			do
				local x, z = site.x + lx, site.z + lz
				local n0, f0 = natural(x, z), zones.terrain_height_at(x, z)
				local a0 = reached(x, z)
				-- (a swamp pool may lie in the blend, as on any gentle swamp
				-- ground: it never flows; lakes and rivers may not)
				if a0 and n0 ~= f0 and L.hull_project(lx, lz) > 0 and
						q.road_column_at(x, z) == nil and height.inland_water_at(x, z) ~= nil then
					error(where .. ("a lake or river in the blend at %d,%d"):format(x, z), 0)
				end
				for _, o in ipairs({{4, 0}, {0, 4}}) do
					local x2, z2 = x + o[1], z + o[2]
					local n1, f1 = natural(x2, z2), zones.terrain_height_at(x2, z2)
					if (a0 or reached(x2, z2)) and q.road_column_at(x, z) == nil and
							q.road_column_at(x2, z2) == nil then
						local added = math.abs(f1 - f0) - math.abs(n1 - n0)
						if added > arena_added then arena_added = added end
						if added > limit then
							error(where .. ("the levelling steepens %d,%d by %d over 4"):format(x,
								z, added), 0)
						end
					end
				end
			end
		end
	end
	-- no spawn-region content on the footprint and its fringe (ruling 13):
	-- no camp, leader or quest place of the region maps of the zones the
	-- fringe touches (built as the game builds them, quest_places above) and
	-- no rare's patrol point (the consumer payload, as grug_core.rare_route
	-- serves them)
	local f = L.world(site).fringe
	local function on_fringe(x, z)
		return x >= f.min.x and x <= f.max.x and z >= f.min.z and z <= f.max.z
	end
	local seen = {}
	for x = f.min.x, f.max.x, 8 do
		for z = f.min.z, f.max.z, 8 do
			local id = zones.id_at(x, z)
			if id and not seen[id] then
				seen[id] = true
				local built = region_map(id)
				for _, list in ipairs(built and {built.map.camps, built.map.leaders, built.map.places} or {}) do
					for _, s in ipairs(list) do
						if on_fringe(s.x, s.z) then
							error(where .. ("%s %s at %d,%d on the fringe"):format(id,
								tostring(s.id or s.role), s.x, s.z), 0)
						end
					end
				end
			end
		end
	end
	for _, row in ipairs(R.built.consumer_payload.rare_routes) do
		local a = zones.anchor(row.anchor.zone_id, row.anchor.slot_id)
		for _, o in ipairs(row.patrol_offsets) do
			if on_fringe(a.x + o.x, a.z + o.z) then
				error(where .. ("rare %s's patrol point %d,%d on the fringe"):format(row.id,
					a.x + o.x, a.z + o.z), 0)
			end
		end
	end
	return site
end

-- The sample: {label, x, z} columns, chosen by bytes of a digest of the seed.
local function sample()
	local bytes = {R.sha("seed_fleet_chunks:" .. seed):byte(1, 8)}
	local function pick(index, count) return bytes[index] % count + 1 end
	local zones = R.built.zones_session
	local columns = {}
	local sx = pick(1, 2) == 1 and -1 or 1
	local sz = pick(2, 2) == 1 and -1 or 1
	columns[#columns + 1] = {"corner", sx * X_LIMIT, sz * Z_LIMIT}
	-- the first land on the diagonal from that corner to the centre
	for step = 8, X_LIMIT, 8 do
		local x, z = sx * (X_LIMIT - step), sz * math.floor(Z_LIMIT - step * Z_LIMIT / X_LIMIT)
		if zones.water_class_at(x, z) == "land" then
			columns[#columns + 1] = {"coast", x, z}
			break
		end
	end
	local mouths = {}
	for _, r in ipairs(rivers) do
		if not r.parent and r.end_kind == "sea" then mouths[#mouths + 1] = r end
	end
	if #mouths > 0 then
		local r = mouths[pick(3, #mouths)]
		columns[#columns + 1] = {"river mouth " .. r.id, r.x[#r.x], r.z[#r.z]}
	end
	local rows, capitals, others = R.main.settlement_sockets(R.built), {}, {}
	for _, row in ipairs(rows) do
		if row.slot == "capital" then capitals[#capitals + 1] = row
		else others[#others + 1] = row end
	end
	local DIRECTIONS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	local direction = DIRECTIONS[pick(4, 4)]
	local capital = capitals[pick(5, #capitals)]
	local shape = R.main.capital_protection()[capital.anchor.id]
	for d = 0, 800, 4 do
		local x, z = capital.anchor.x + direction[1] * d, capital.anchor.z + direction[2] * d
		if not shape.member(x, z) then
			columns[#columns + 1] = {"capital edge " .. capital.key, x, z}
			break
		end
	end
	-- just outside the settlement's own cells (its prepared bounds; a start's
	-- pad is 128 nodes wide)
	local other = others[pick(6, #others)]
	local prepared = R.main.prepared_handover()[other.key]
	local reach = 72
	if prepared then
		local b = prepared.bounds
		reach = math.max(direction[1] > 0 and b.max.x or 0, direction[1] < 0 and -b.min.x or 0,
			direction[2] > 0 and b.max.z or 0, direction[2] < 0 and -b.min.z or 0) + 8
	end
	columns[#columns + 1] = {"collar " .. other.key, other.anchor.x + direction[1] * reach,
		other.anchor.z + direction[2] * reach}
	return columns
end

-- The arena's blocks (Round 85 lane BUILD): the model its writer stamps.
local arena_B, arena_model
local function arena_model_of()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	arena_B = arena_B or dofile(wp40 .. "/breach_model.lua")
	arena_model = arena_model or arena_B.new(wp40)
	return arena_B, arena_model
end

-- The arena's footprint (Round 85): every chunk column its bounds touch, at
-- the datum and every chunk layer up to its blocks' reach ({label, x, z, nil,
-- chunk origin y, arena = true}; 4 to 18 chunks).
local function arena_columns(site)
	local L = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/breach_layout.lua")
	local _, model = arena_model_of()
	local columns = {}
	for oy = R.origin(site.y), R.origin(site.y + model.REACH), 80 do
		for oz = R.origin(site.z - L.HALF_Z), R.origin(site.z + L.HALF_Z), 80 do
			for ox = R.origin(site.x - L.HALF_X), R.origin(site.x + L.HALF_X), 80 do
				columns[#columns + 1] = {"arena " .. ox .. "," .. oy .. "," .. oz, ox, oz, nil, oy,
					arena = true}
			end
		end
	end
	return columns
end

-- The arena's blocks in one written chunk (header): raises on the first
-- cell that is missing, floats or lies buried.
local function arena_blocks(site, minp, vm)
	local B, model = arena_model_of()
	local fake = R.fake
	local air = fake.CONTENT_AIR
	local data = vm.written.data or vm.native.data
	local param2 = vm.written.param2 or vm.native.param2
	local ex, ey, ez = minp.x - 16, minp.y - 16, minp.z - 16
	local function at(x, y, z)
		local i = (z - ez) * 12544 + (y - ey) * 112 + (x - ex) + 1
		return data[i], param2[i]
	end
	local q = R.planner_source
	local function family(x, z) return B.FAMILIES[B.family((select(4, q.column_values_at(x, z))))] end
	local function inside(x, y, z)
		return x >= minp.x and x <= minp.x + 79 and y >= minp.y and y <= minp.y + 79 and
			z >= minp.z and z <= minp.z + 79
	end
	local where = ("arena blocks %d,%d (chunk %d,%d,%d): "):format(site.x, site.z, minp.x, minp.y,
		minp.z)
	local dressed = {}
	for _, g in ipairs(model.dressing) do
		for _, cell in ipairs(g.cells[family(site.x + g.x, site.z + g.z).dress]) do
			dressed[(site.x + cell.x) .. "," .. (site.y + cell.y) .. "," .. (site.z + cell.z)] =
				cell.entry
		end
	end
	local checked = 0
	for _, c in ipairs(model.columns) do
		local x, z = site.x + c.lx, site.z + c.lz
		if inside(x, minp.y, z) then
			local f
			if inside(x, site.y - 1, z) then
				local name = fake.get_name_from_content_id((at(x, site.y - 1, z)))
				if name == "air" or name:find("water", 1, true) or name:find("lava", 1, true) then
					error(where .. ("%s under the arena at %d,%d,%d"):format(name, x, site.y - 1, z), 0)
				end
			end
			for ly = 0, model.REACH do
				local y = site.y + ly
				if inside(x, y, z) then
					local want = dressed[x .. "," .. y .. "," .. z] or c.cells[ly + 1]
					local got, p2 = at(x, y, z)
					local label = ("%d,%d,%d"):format(x, y, z)
					if want == nil or want == B.AIR then
						if got ~= air then
							error(where .. fake.get_name_from_content_id(got) .. " buries the arena at " ..
								label, 0)
						end
					elseif want == B.KEEP then
						if got == air then error(where .. "no ground at the rim at " .. label, 0) end
					else
						local e = model.entries[want]
						local name = e.name
						if e.role then
							f = f or family(x, z)
							name = f[e.role]
						end
						if got ~= fake.get_content_id(name) or p2 ~= e.param2 then
							error(where .. ("%s %d missing at %s (holds %s %d)"):format(name, e.param2,
								label, fake.get_name_from_content_id(got), p2), 0)
						end
					end
					checked = checked + 1
				end
			end
		end
	end
	return checked
end

-- The named chunks of this seed: {label, minp}.
local function named_chunks()
	local result = {}
	local file = io.open(repo .. "/tools/seed_fleet/chunks.txt", "r")
	if not file then return result end
	for line in file:lines() do
		local s, x, y, z, label = line:match("^(%d+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s*(.*)$")
		if s == seed then
			result[#result + 1] = {label ~= "" and label or "named",
				{x = tonumber(x), y = tonumber(y), z = tonumber(z)}}
		end
	end
	file:close()
	return result
end

-- Digest mode's extra chunks: {label, x, z, dy, y} columns (dy: chunks
-- below the ground chunk; y: a fixed chunk origin instead), chosen by later
-- bytes of the same seed digest. A kind the seed lacks is left out.
local function dense_columns()
	local bytes = {R.sha("seed_fleet_chunks:" .. seed):byte(9, 16)}
	local function pick(index, count) return bytes[index] % count + 1 end
	local columns = {}
	local roads = {}
	for _, line in ipairs(R.main.road_polylines()) do
		if line.kind == "road" and #line.points > 2 then roads[#roads + 1] = line end
	end
	if #roads > 0 then
		local line = roads[pick(1, #roads)]
		local point = line.points[math.floor((#line.points + 1) / 2)]
		columns[#columns + 1] = {"road", point.x, point.z, 0}
	end
	if #rivers > 0 then
		local r = rivers[pick(2, #rivers)]
		local middle = math.floor((#r.x + 1) / 2)
		columns[#columns + 1] = {"river middle " .. r.id, r.x[middle], r.z[middle], 0}
	end
	-- a forest column and the highest ground, on a 128-node grid
	local source = R.planner_source
	local forests, top_x, top_z, top_y = {}, nil, nil, -math.huge
	for x = WORLD.min_x, X_LIMIT, 128 do
		for z = WORLD.min_z, Z_LIMIT, 128 do
			local water_class, _, _, biome, _, terrain_y = source.column_values_at(x, z)
			if water_class == "land" then
				if type(biome) == "string" and (biome:find("forest", 1, true) or
						biome:find("jungle", 1, true)) then
					forests[#forests + 1] = {x, z, biome}
				end
				if terrain_y > top_y then top_x, top_z, top_y = x, z, terrain_y end
			end
		end
	end
	if #forests > 0 then
		local f = forests[pick(3, #forests)]
		columns[#columns + 1] = {"forest " .. f[3], f[1], f[2], 0}
	end
	if top_x then
		columns[#columns + 1] = {"mountain", top_x, top_z, 0}
		columns[#columns + 1] = {"under the mountain", top_x, top_z, 1}
	end
	local villages, capitals = {}, {}
	for _, row in ipairs(R.main.settlement_sockets(R.built)) do
		if row.slot:find("^village") then villages[#villages + 1] = row end
		if row.slot == "capital" then capitals[#capitals + 1] = row end
	end
	if #villages > 0 then
		local v = villages[pick(4, #villages)]
		columns[#columns + 1] = {"village " .. v.key, v.anchor.x, v.anchor.z, 0}
	end
	local c = capitals[pick(5, #capitals)]
	columns[#columns + 1] = {"capital core " .. c.key, c.anchor.x, c.anchor.z, 0}
	-- the fill floor (the chunk at y -112: R5's fill runs, the strata and
	-- the fill ores of rows -37..-33) under the road or the river middle
	local under = columns[pick(6, 2)]
	if under and (under[1] == "road" or under[1]:find("^river middle")) then
		columns[#columns + 1] = {"under the ground at the " .. under[1], under[2], under[3], 0, -112}
	end
	return columns
end

-- A canonical text of plain data (sorted keys, numbers exact), for hashing.
local function canonical(value, out)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			canonical(key, out)
			out[#out + 1] = "="
			canonical(value[key], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	elseif kind == "number" then
		out[#out + 1] = ("%.17g"):format(value)
	elseif kind == "string" then
		out[#out + 1] = ("%q"):format(value)
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	else
		error("digest: cannot hash a " .. kind, 0)
	end
	return out
end
local function hex_sha(bytes)
	return (R.sha(bytes):gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
local digest_lines = {}
local function layout_digests()
	local main = R.main
	local function add(kind, text) digest_lines[#digest_lines + 1] = kind .. " " .. hex_sha(text) end
	add("layout water", main.water_layout_text())
	add("layout roads", main.road_layout_text())
	add("layout capitals", main.capital_layout_text())
	add("layout placement", main.placement_layout_text())
	add("layout handover", table.concat(canonical(main.prepared_handover(), {})))
	add("layout sockets", table.concat(canonical(main.settlement_sockets(R.built), {})))
	local values, keys = R.built.manifest.values, {}
	for key in pairs(values) do
		if key:find("_blueprint_sha256$") then keys[#keys + 1] = key end
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. values[key] end
	add("layout blueprints", table.concat(parts, "\n"))
	digest_lines[#digest_lines + 1] = "info manifest " .. R.built.manifest.sha256
end
-- The texts main writes into a finished chunk (init.lua): the wayposts.
local WAYPOSTS = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/wayposts.lua")
local waypost_rows
local function chunk_meta(minp, vm)
	local data = vm.written.data or vm.native.data
	local node = R.fake.get_content_id(WAYPOSTS.NODE)
	local texts = {}
	WAYPOSTS.write_texts(waypost_rows or {}, minp,
		{x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}, function(pos)
			return data[(pos.z - minp.z + 16) * 12544 + (pos.y - minp.y + 16) * 112 +
				(pos.x - minp.x + 16) + 1] == node
		end, function(pos, text)
			texts[#texts + 1] = ("%d,%d,%d %s"):format(pos.x, pos.y, pos.z, text)
		end)
	if #texts == 0 then return "0" end
	return #texts .. ":" .. hex_sha(table.concat(texts, "\n")):sub(1, 16)
end

-- What a chunk reaches (an "info" line, not compared: the counters are the
-- writer's own and may change with it): its columns that are land, river,
-- road, settlement ground (functional), forest, and whose ground lies in the
-- chunk; the owner's decoration candidates; what the settlements and the
-- P9G pass wrote or accepted, and the voxels the writer changed.
local function counters()
	local m = R.built.session.metrics()
	local written = 0
	for _, row in pairs(m.settlements or {}) do written = written + (row.written or 0) end
	return {written = written, p9g = m.p9g and m.p9g.accepted or 0,
		voxels = m.settlement and m.settlement.modified_voxels or 0}
end
local function coverage(minp, before, result)
	local source = R.planner_source
	local n = {land = 0, river = 0, road = 0, settlement = 0, forest = 0, ground = 0}
	for z = minp.z, minp.z + 79 do
		for x = minp.x, minp.x + 79 do
			local water_class, _, _, biome, _, terrain_y, _, river_id, _, functional =
				source.column_values_at(x, z)
			if water_class == "land" then n.land = n.land + 1 end
			if river_id ~= nil then n.river = n.river + 1 end
			if source.road_column_at(x, z) ~= nil then n.road = n.road + 1 end
			if functional ~= nil then n.settlement = n.settlement + 1 end
			if type(biome) == "string" and (biome:find("forest", 1, true) or
					biome:find("jungle", 1, true)) then
				n.forest = n.forest + 1
			end
			if terrain_y >= minp.y and terrain_y <= minp.y + 79 then n.ground = n.ground + 1 end
		end
	end
	local after = counters()
	local _, decorations = result.candidates:gsub(",", ",")
	return ("info cover %d,%d,%d seconds=%.2f land=%d river=%d road=%d settlement=%d " ..
		"forest=%d ground=%d decorations=%d settlement_written=%d p9g_accepted=%d " ..
		"modified_voxels=%d"):format(minp.x, minp.y, minp.z,
		result.plan_seconds + result.write_seconds, n.land, n.river, n.road, n.settlement,
		n.forest, n.ground,
		result.candidates == "" and 0 or (decorations + 1) / 7, after.written - before.written,
		after.p9g - before.p9g, after.voxels - before.voxels)
end

local ok, err = pcall(build)
if ok and digest_file then
	R.record_light = true
	ok, err = pcall(layout_digests)
end
local roster = ok and R.built.anchor_roster.sha256
local places, place_seconds = 0, 0
if ok then
	local started = os.clock()
	ok, err = pcall(quest_places)
	if ok then places = err end
	place_seconds = os.clock() - started
end
-- The seed's generated tree templates (Round 47): the expander checked every
-- variant while the runtime was built (bounds, vocabulary, decoration role);
-- the manifest publishes their roll-up, printed so two runs can be compared.
local trees
if ok then
	trees = R.built.manifest.values.r6_generated_templates_sha256
	if type(trees) ~= "string" or not trees:match("^%x+$") or #trees ~= 64 then
		ok, err = false, "generated tree templates missing from the manifest"
	end
end
-- The wayposts at the road junctions (Round 70, wp40/wayposts.lua): on every
-- seed some stand, each off the road surface on dry land inside the road's
-- vegetation exclusion, outside every settlement's reservation, its names fit
-- the board. The first one's chunk joins the sample.
local function wayposts()
	local rows = R.main.waypost_rows(R.planner_source)
	if #rows < 4 then error("only " .. #rows .. " wayposts stand", 0) end
	local q = R.planner_source
	local reserved = {}
	local profile = {}
	for _, p in ipairs(SOURCE.anchor_profiles) do profile[p.id] = p end
	local by_id = {}
	for _, a in ipairs(SOURCE.anchors) do by_id[a.id] = a end
	for id, x, z in R.main.placement_layout_text():gmatch("(anchor_%d+) (%-?%d+) (%-?%d+)") do
		local a = by_id[id]
		local half = a.slot_id == "capital" and 256 or a.slot_id == "start" and 80 or
			(profile[a.template_id].building_core_width or 16) / 2 + 10
		reserved[#reserved + 1] = {id = id, x = tonumber(x), z = tonumber(z), half = half}
	end
	for _, row in ipairs(rows) do
		local where = ("waypost %d,%d,%d: "):format(row.x, row.y, row.z)
		if q.road_column_at(row.x, row.z) == "surface" then error(where .. "on the road", 0) end
		local class = q.column_values_at(row.x, row.z)
		if class ~= "land" then error(where .. "on " .. tostring(class), 0) end
		if q.overlay_exclusion_at(row.x, row.z) ~= "road_corridor" then
			error(where .. "outside the road's exclusion", 0)
		end
		if #row.arms ~= 3 then error(where .. #row.arms .. " arrows", 0) end
		for _, arm in ipairs(row.arms) do
			if #arm.text > 14 or #arm.text < 1 then error(where .. arm.text, 0) end
		end
		for _, r in ipairs(reserved) do
			if math.max(math.abs(row.x - r.x), math.abs(row.z - r.z)) <= r.half then
				error(where .. "inside the reservation of " .. r.id, 0)
			end
		end
	end
	return rows
end
-- Road cut walls (header): the largest step a cut adds at a side zone's
-- edge, raising above ROAD_CUT_LIMIT (2: the cut's own rock face per node;
-- a cut that meets the ground adds 1 or 2 where its face is floored).
local ROAD_CUT_LIMIT = 2
local function road_cuts()
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local W = dofile(repo .. "/tools/r86_roads/walls.lua")
	local RL = dofile(wp40 .. "/road_layout.lua")
	local q, zones = R.planner_source, R.built.zones_session
	local height
	for index = 1, 255 do
		local name, value = debug.getupvalue(q.road_column_at, index)
		if name == nil then break end
		if name == "height" then height = value end
	end
	assert(height and height.fitted_values_at, "the planner source's height session is not reachable")
	local capitals = R.main.capital_protection()
	local function exempt(x, z)
		for _, shape in pairs(capitals) do
			if shape.member(x, z) then return true end
		end
		return false
	end
	local function query(x, z)
		return zones.terrain_height_at(x, z), (height.fitted_values_at(x, z)), (q.road_column_at(x, z))
	end
	local step, at = W.largest(RL.deserialize(R.main.road_layout_text()), RL.P.SIDE_MAX, query,
		exempt)
	if step > ROAD_CUT_LIMIT then
		error(("a road cut ends in a wall of %d at %d,%d (the step it adds over the ground " ..
			"beside it; bound %d)"):format(step, at[2], at[3], ROAD_CUT_LIMIT), 0)
	end
	local face, fx, fz = W.face(RL.deserialize(R.main.road_layout_text()), -1, 6, query, exempt)
	return step, ("%d@%s,%s"):format(face, tostring(fx), tostring(fz))
end
local posts = 0
local road_cut, road_cut_seconds, road_face = 0, 0, "-"
local chunks, chunk_seconds = 0, 0
local arena_site, arena_cells = nil, 0
if ok then
	local started = os.clock()
	local columns, rows
	ok, err = pcall(sample)
	if ok then columns = err end
	if ok then
		local site
		ok, site = pcall(arena)
		if ok then
			arena_site = site
			for _, column in ipairs(arena_columns(site)) do columns[#columns + 1] = column end
		else
			err = site
		end
	end
	if ok then
		ok, rows = pcall(wayposts)
		if ok then
			posts = #rows
			waypost_rows = rows
			columns[#columns + 1] = {"a waypost", rows[1].x, rows[1].z}
		else
			err = rows
		end
	end
	if ok then
		local c0 = os.clock()
		ok, road_cut, road_face = pcall(road_cuts)
		if not ok then err = road_cut end
		road_cut_seconds = os.clock() - c0
	end
	if ok and dense then
		local extra
		ok, extra = pcall(dense_columns)
		if ok then
			for _, column in ipairs(extra) do columns[#columns + 1] = column end
		else
			err = extra
		end
	end
	local function run_chunk(minp, label, site)
		local result
		local before = digest_file and counters()
		ok, result = pcall(R.chunk, minp)
		if not ok then
			err = ("chunk %d,%d,%d (%s): %s"):format(minp.x, minp.y, minp.z, label,
				tostring(result))
			return
		end
		chunks = chunks + 1
		if site then
			local checked
			ok, checked = pcall(arena_blocks, site, minp, result.vm)
			if not ok then
				err = checked
				return
			end
			arena_cells = arena_cells + checked
		end
		if digest_file then
			digest_lines[#digest_lines + 1] = ("chunk %d,%d,%d nodes=%s light=%s meta=%s %s")
				:format(minp.x, minp.y, minp.z, result.data_hash, result.light_hash:sub(1, 16),
				chunk_meta(minp, result.vm), label)
			digest_lines[#digest_lines + 1] = coverage(minp, before, result)
		end
	end
	for _, column in ipairs(ok and columns or {}) do
		local label, x, z = column[1], column[2], column[3]
		local minp = {x = R.origin(x),
			y = column[5] or R.origin(math.max(R.ground_at(x, z), 1)) - 80 * (column[4] or 0),
			z = R.origin(z)}
		run_chunk(minp, label, column.arena and arena_site)
		if not ok then break end
	end
	for _, named in ipairs(ok and named_chunks() or {}) do
		run_chunk(named[2], named[1])
		if not ok then break end
	end
	chunk_seconds = os.clock() - started
end
local seconds = ("%.1f"):format(os.clock() - t0)
if digest_file then
	local file = assert(io.open(digest_file, "w"))
	file:write("# tools/r82_gen digest v1 (tools/seed_fleet/seed.lua)\n", "seed " .. seed .. "\n")
	if ok then
		file:write("roster " .. roster .. "\n", "trees " .. trees .. "\n",
			table.concat(digest_lines, "\n"), "\n")
	else
		file:write("FAIL " .. (tostring(err):gsub("[\t\n]", " ")) .. "\n")
	end
	file:close()
end
if ok then
	print("OK", seed, seconds, roster, "chunks=" .. chunks,
		("chunk_seconds=%.1f"):format(chunk_seconds), "trees=" .. trees:sub(1, 16),
		"places=" .. places, ("place_seconds=%.1f"):format(place_seconds),
		"wayposts=" .. posts, "arena_cells=" .. arena_cells,
		("arena_added=%d/4%s"):format(arena_added, arena_fallback and ",fallback" or ""),
		"road_cut=" .. road_cut, ("road_cut_seconds=%.1f"):format(road_cut_seconds),
		"road_face=" .. road_face)
else
	print("FAIL", seed, seconds, (tostring(err):gsub("[\t\n]", " ")))
	error("seed " .. seed .. " failed", 0)
end

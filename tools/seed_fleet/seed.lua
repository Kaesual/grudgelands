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
-- Prints one line, "OK <seed> <seconds> <roster sha256> chunks=<n>
-- chunk_seconds=<s> trees=<the generated tree templates' roll-up, 16 hex>
-- places=<recipe quest places checked> place_seconds=<s>" or
-- "FAIL <seed> <seconds> <error>" and then raises (a non-zero exit). A failure
-- in the per-chunk path names the chunk.
local repo, seed = arg[1], arg[2]
assert(repo and seed and seed:match("^%d+$"), "usage: seed.lua REPO SEED")
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
-- count of places checked.
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
	local q = core.queries({zones = zones, column_values_at = R.planner_source.column_values_at,
		road_polylines = R.main.road_polylines(), source = SOURCE})
	local checked = 0
	local dir = repo .. "/mods/ENTITIES/grug_mobs/data/zones"
	for _, row in ipairs(SOURCE.zones) do
		local zone = row.id
		local f = io.open(dir .. "/" .. zone .. ".spawns.json", "rb")
		local data = f and json.parse(f:read("*a"))
		if f then f:close() end
		if data and data.recipe and type(data.recipe.places) == "table" and #data.recipe.places > 0 then
			local record = zones.get(zone)
			local recipe = core.parse_recipe(zone, data.recipe, {
				band = {record.level_min, record.level_max},
				role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
				leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
				pois = function(id) return core.zone_pois(SOURCE, id, labels) end,
			})
			local map = core.build(zone, q, recipe)
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

local ok, err = pcall(build)
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
local chunks, chunk_seconds = 0, 0
if ok then
	local started = os.clock()
	local columns
	ok, err = pcall(sample)
	if ok then columns = err end
	for _, column in ipairs(ok and columns or {}) do
		local label, x, z = column[1], column[2], column[3]
		local minp = {x = R.origin(x), y = R.origin(math.max(R.ground_at(x, z), 1)),
			z = R.origin(z)}
		ok, err = pcall(R.chunk, minp)
		if not ok then
			err = ("chunk %d,%d,%d (%s): %s"):format(minp.x, minp.y, minp.z, label, tostring(err))
			break
		end
		chunks = chunks + 1
	end
	for _, named in ipairs(ok and named_chunks() or {}) do
		local minp = named[2]
		ok, err = pcall(R.chunk, minp)
		if not ok then
			err = ("chunk %d,%d,%d (%s): %s"):format(minp.x, minp.y, minp.z, named[1],
				tostring(err))
			break
		end
		chunks = chunks + 1
	end
	chunk_seconds = os.clock() - started
end
local seconds = ("%.1f"):format(os.clock() - t0)
if ok then
	print("OK", seed, seconds, roster, "chunks=" .. chunks,
		("chunk_seconds=%.1f"):format(chunk_seconds), "trees=" .. trees:sub(1, 16),
		"places=" .. places, ("place_seconds=%.1f"):format(place_seconds))
else
	print("FAIL", seed, seconds, (tostring(err):gsub("[\t\n]", " ")))
	error("seed " .. seed .. " failed", 0)
end

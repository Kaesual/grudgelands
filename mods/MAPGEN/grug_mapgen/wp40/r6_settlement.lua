-- WP40 R6 P7-P9 refinement settlement and single VM transaction.

local function settlement_factory()
	local MAX_SAFE = 9007199254740991
	local MAX_VOLUME = 112 * 112 * 112
	local RUN_STRIDE = 9
	local COLUMN_STRIDE = 12
	local CELL_STRIDE = 4
	local CANDIDATE_STRIDE = 7
	local CLASS_AIR, CLASS_FOREIGN, CLASS_IGNORE, CLASS_LIQUID = 1, 2, 3, 4
	local CLASS_NATIVE_ORE, CLASS_NATURAL_HOST, CLASS_NATURAL_SURFACE = 5, 6, 7
	local CLASS_NATURAL_VEGETATION, CLASS_UNKNOWN = 8, 9
	local CLASS_WP43_RESOURCE, CLASS_WP43_STRATUM = 10, 11
	local FACE_X = {1, -1, 0, 0, 0, 0}
	local FACE_Y = {0, 0, 1, -1, 0, 0}
	local FACE_Z = {0, 0, 0, 0, 1, -1}
	-- THE FOREST DENSITY PARAMETER (Round 47 groves follow-up): generated trees
	-- interleave their crowns (each reserves only its own cells), and two
	-- accepted generated trees of one owner keep their roots this many nodes
	-- apart (Chebyshev, strictly less refuses). Lane TD measures density
	-- against it; 1 would be wood-against-wood only.
	local TREE_SPACING = 4
	-- The P9G suffix of the content namespace (r7_content.lua P9G_NAMES; 36
	-- before Round 51 T3's seagrass): its writes and the anchor and settlement
	-- windows after it.
	local P9G_COUNT = 39

	local function fail(code, message)
		error(code .. ": " .. message, 0)
	end

	-- The error handler of the transaction wrapper below: a failure keeps its
	-- stack (once, however deeply the wrappers nest), so a seed-fleet run and
	-- a server log both show where it failed.
	local function with_traceback(message)
		if type(message) ~= "string" or message:find("\nstack traceback:", 1, true) or
				type(debug) ~= "table" or type(debug.traceback) ~= "function" then
			return message
		end
		return debug.traceback(message, 2)
	end

	local function integer(value, label, minimum, maximum, code)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail(code or "fail_bound", label .. " is not an exact bounded integer")
		end
		return value
	end

	local function r9_native_air_run(context, x, z)
		local _, terrain_y = context.column_at(x, z)
		local run = 0
		for depth = 1, 4 do
			if context.native_class_at(x, terrain_y - depth, z) ~= CLASS_AIR then break end
			run = run + 1
		end
		return run, terrain_y
	end

	-- The opening decision of one column. Exclusions are supplied by the
	-- existing claim/fitting authorities.
	local function r9_surface_skin_open(context, x, z)
		local water_class = context.column_at(x, z)
		local run, terrain_y = r9_native_air_run(context, x, z)
		if water_class ~= "land" or run < 4 or context.excluded_at(x, z) then
			return false, run, terrain_y
		end
		-- Native sky is also air.  Authorize an opening only when R5 retained
		-- every central cell as cave air instead of filling it to authored land.
		for depth = 1, 4 do
			if not context.preserved_native_air_at(x, terrain_y - depth, z) then
				return false, run, terrain_y
			end
		end
		for direction = 1, 4 do
			local dx = direction == 1 and 1 or direction == 2 and -1 or 0
			local dz = direction == 3 and 1 or direction == 4 and -1 or 0
			local _, neighbor_y = context.column_at(x + dx, z + dz)
			if neighbor_y <= terrain_y - 2 then return true, run, terrain_y end
		end
		for dz = -1, 1 do
			for dx = -1, 1 do
				if r9_native_air_run(context, x + dx, z + dz) < 4 then
					return false, run, terrain_y
				end
			end
		end
		return true, run, terrain_y
	end

	local function r9_surface_skin_owned_range(terrain_y, min_y, max_y)
		local band_min = math.max(-37, terrain_y - 3)
		local band_max = terrain_y - 1
		local owned_min = math.max(band_min, min_y)
		local owned_max = math.min(band_max, max_y)
		return owned_min <= owned_max and owned_min or nil,
			owned_min <= owned_max and owned_max or nil,
			terrain_y >= min_y and terrain_y <= max_y,
			terrain_y + 1 >= min_y and terrain_y + 1 <= max_y
	end

	local function new_r8_strata(full_seed, source)
		local secondary_by_biome = {
			grug_savanna = "default:sandstone",
			grug_badlands = "grug_materials:basalt",
			grug_badlands_east = "grug_materials:basalt",
			grug_meadows = "default:desert_stone",
			grug_pine_hills = "grug_materials:slate",
			grug_jungle_edge = "default:mossycobble",
			grug_deep_jungle = "default:mossycobble",
			grug_jungle_fringe = "default:mossycobble",
			grug_swamp = "default:mossycobble",
			grug_beach = "default:sandstone",
			grug_crags = "grug_materials:slate",
			grug_crags_snowy = "grug_materials:slate",
			grug_elf_forest = "default:desert_stone",
			grug_deep_forest = "default:desert_stone",
			grug_blight = "grug_materials:basalt",
			grug_bone_forest = "grug_materials:basalt",
		}
		local zone_relief = {}
		for zone_index = 1, #(source.zones or {}) do
			zone_relief[source.zones[zone_index].id] =
				source.zones[zone_index].primary_relief_id
		end
		local phase = 0
		for index = 1, #full_seed do
			phase = (phase * 131 + string.byte(full_seed, index)) % 65521
		end
		local function draw(x, z, salt)
			local value = (x * 374761 + z * 668265 + phase * 69069 + salt) % 16777213
			value = (value * value) % 16777213
			return (value * 48271) % 16777213
		end
		local result = {}
		-- The depths where a column's secondary band, gravel band and pocket
		-- start (column hashes only).
		function result.column_starts(filler_depth, x, z)
			local first_depth = filler_depth + 1
			return math.max(first_depth, 8 + draw(x, z, 19349663) % 4),
				math.max(first_depth, 18 + draw(x, z, 83492791) % 4),
				math.max(first_depth, 29 + draw(x, z, 297121507) % 5)
		end
		-- The stratum at `depth` of a column with those starts, or nil.
		function result.material_from(zone_id, biome, filler_depth, secondary_start,
				gravel_start, pocket_start, depth)
			if depth < filler_depth + 1 or depth > 40 then return nil end
			if depth >= secondary_start and depth <= secondary_start + 2 then
				return secondary_by_biome[biome] or "default:desert_stone"
			end
			if depth >= gravel_start and depth <= gravel_start + 2 then
				return "default:gravel"
			end
			if depth >= pocket_start and depth <= pocket_start + 1 then
				return (biome == "grug_swamp" or zone_relief[zone_id] == "wetland_delta") and
					"default:clay" or "default:dirt"
			end
			return nil
		end
		function result.material_at(zone_id, biome, filler_depth, x, z, depth)
			local secondary_start, gravel_start, pocket_start =
				result.column_starts(filler_depth, x, z)
			return result.material_from(zone_id, biome, filler_depth, secondary_start,
				gravel_start, pocket_start, depth)
		end
		function result.secondary_for(biome)
			return secondary_by_biome[biome] or "default:desert_stone"
		end
		return result
	end

	-- Shared by the production VM writer and the portable immutable-CID fixture.
	-- The immutable native input, rather than the already settled terrain, is the
	-- only provenance accepted here.  In particular, gravel is never inferred to
	-- be filler from its CID because native gravel ore has the identical CID.
	local function r8_apply_strata(context)
		local written = 0
		-- Optional output for the layer pass: per owner column -1 when the
		-- bands' column exclusions reject it, else filler_depth * 2 + steep.
		local info = context.column_info
		local x_count = context.max_x - context.min_x + 1
		-- Bands and strata lie in a column's top 40 nodes below its terrain;
		-- a column whose top 40 miss the owner's rows (above the floor) is
		-- skipped before any query (the layer pass reads its column info for
		-- those rows only).
		local low_y = math.max(context.min_y, context.floor_y)
		for z = context.min_z, context.max_z do
			for x = context.min_x, context.max_x do
				if info then info[(z - context.min_z) * x_count + (x - context.min_x) + 1] = -1 end
				local water_class, _, zone_id, biome, _, terrain_y, water_y, _, _,
					functional_kind, _, _, _, transition_kind, _, _, _, _, _, hard =
						context.column_values_at(x, z)
				if terrain_y - 1 >= low_y and terrain_y - 40 <= context.max_y then
					-- Ruling 30 addendum (optional `protected_only_floor_at`): a
					-- column whose claim exclusion is protection only takes its
					-- bands (and the layer pass its nests) below that floor.
					local cap
					local admitted = context.static_exclusion_values_at(x, z) == nil
					if not admitted and context.protected_only_floor_at then
						cap = context.protected_only_floor_at(x, z)
						admitted = cap > -math.huge
					end
					if context.column_cap then
						context.column_cap[(z - context.min_z) * x_count +
							(x - context.min_x) + 1] = cap or false
					end
					if water_class == "land" and zone_id and biome and water_y == nil and
							functional_kind == nil and transition_kind == nil and not hard and
							admitted then
						local surface = context.select_surface(biome, x, z, water_y, terrain_y,
							zone_id)
						local filler_depth = surface and surface.filler_depth or 4
						if info then
							info[(z - context.min_z) * x_count + (x - context.min_x) + 1] =
								filler_depth * 2 + (surface and surface.steep and 1 or 0)
						end
						-- Round 51 T4: a banded badlands row (r6_content.lua
						-- `bands`) lays its clay bands by height down the face below
						-- its top, over the column's stone and its own filler (never
						-- a resource ore, a cave or water; a native gravel blob under
						-- a gravel filler matches the filler and may take a band),
						-- and takes the strata below.
						local bands, band_last = surface and surface.bands, 0
						if bands then
							band_last = surface.band_depth - 1
							local filler_cid = context.content_cids[surface.filler_ref]
							for depth = 1, band_last do
								local y = terrain_y - depth
								if y >= context.floor_y and y >= context.min_y and
										y <= context.max_y and (cap == nil or y < cap) then
									local index = context.index_at(x, y, z)
									if context.final_data[index] == filler_cid or
											context.original_data[index] == context.stone_cid or
											context.fill_stone_at(index, x, y, z) then
										context.write(x, y, z, bands[y % 7 + 1])
										written = written + 1
									end
								end
							end
						end
						-- Steep columns (rock faces and lips) show their side: no
						-- bands along a cliff face (Round 22 Phase 6).
						local first = surface and surface.steep and 41 or
							math.max(filler_depth, band_last) + 1
						local secondary_start, gravel_start, pocket_start
						if first <= 40 then
							secondary_start, gravel_start, pocket_start =
								context.strata.column_starts(filler_depth, x, z)
						end
						for depth = first, 40 do
							local y = terrain_y - depth
							if y >= context.floor_y and y >= context.min_y and y <= context.max_y and
									(cap == nil or y < cap) then
								local target = context.strata.material_from(zone_id, biome,
									filler_depth, secondary_start, gravel_start, pocket_start, depth)
								if target then
									local index = context.index_at(x, y, z)
									-- Round 24 ruling 11: the terrain fill takes the same
									-- bands as native stone.
									if context.original_data[index] == context.stone_cid or
											context.fill_stone_at(index, x, y, z) then
										local ref = context.content_ref(target)
										if not ref then
											fail("fail_content_manifest", "R8 stratum target is absent")
										end
										context.write(x, y, z, ref)
										written = written + 1
									end
								end
							end
						end
					end
				end
			end
		end
		return written
	end

	-- Round 24 (rulings 9-13): the terrain fill.  R5 closes the gap between
	-- native v7 and the authored surface with plain default:stone (opcode 27,
	-- policy fill-void).  A fill voxel is such stone that R5 wrote into native
	-- void (air, water or plants) and that no later stage has touched.  It
	-- hosts the P8 fill ores (Round 49; native rock keeps its native ores)
	-- and takes the shallow bands like native stone; below the band depth it
	-- takes sparse horizontal layers.  Nothing carves caves into it
	-- (fill-void keeps native cave air only below the native heightmap), and
	-- the seam to native v7 may cut through clusters, bands and caves.
	local R24_FILL_OPCODE = 27
	local R24_LAYER_FIRST_DEPTH = 41
	local R24_LAYER_PERIOD = 13
	local R24_OFFSET_GRID, R24_OFFSET_AMPLITUDE = 48, 5
	local R24_POCKET_CELL = 16

	local function r24_fill_stone(original_cid, final_cid, intent_opcode,
			r5_opcode, stone_cid)
		return final_cid == stone_cid and original_cid ~= stone_cid and
			intent_opcode == 0 and r5_opcode == R24_FILL_OPCODE
	end

	-- Round 49: whether one voxel is a P8 fill-ore host. Native rock carries
	-- the native scatter ores (r7_native.lua) and is never one. A host is the
	-- `default:stone` R5 wrote into native void (air, water or plants) that no
	-- later stage changed: the terrain fill (opcode 27), an anchor's grading
	-- fill (21) or a foundation fill (15; user ruling 2026-10-07: ground
	-- anyone may dig carries the ordinary distribution).
	local function r49_fill_ore_host(original_cid, final_cid, intent_opcode,
			r5_opcode, stone_cid)
		return final_cid == stone_cid and original_cid ~= stone_cid and
			intent_opcode == 0 and (r5_opcode == R24_FILL_OPCODE or
				r5_opcode == 21 or r5_opcode == 15)
	end

	-- Round 49: the P8 fill-ore choice, a function (x, y, z) -> the index of
	-- the resource whose ore a fill host at (x, y, z) takes, or nil. The fill
	-- is `default:stone`, the T1 host, and lies at y >= -37, so only the T1
	-- column of the resource table applies (`tier`: WP43 tier 1); a
	-- `lower_half_of` T1 row (Round 47 ruling 6) only at or below T1's
	-- `lower_half_y_max`. The cluster shapes are the native rows'
	-- (r7_native.lua, mapgen plan ruling 3) by vein cap: a lattice cube of
	-- the row's size is a cluster with probability volume / (denominator *
	-- ores per cluster), and in a cluster each voxel is an ore with
	-- probability ores per cluster / volume, so the rate per host is
	-- 1 / denominator. The first resource in table order takes a voxel two
	-- would claim. `mix` is the world's placement hash (r6_hash.lua
	-- `placement`: exact double arithmetic, LuaJIT and plain Lua 5.1 agree);
	-- a row salts it by its resource index.
	-- Returns the choice and `chunk(min_x, min_y, min_z)`: from that call on,
	-- each row keeps its cube decisions for the 80^3 chunk at that corner in
	-- a dense array (allocated at the row's first cube, at most 41^3
	-- entries), so the voxels of one cube draw its hash once in any order;
	-- `chunk(nil)` drops the arrays. Every voxel the choice is asked for
	-- then lies inside that chunk. The result is the same with or without.
	local R49_CLUSTER_BY_CAP = {[8] = {3, 8}, [4] = {2, 4}, [2] = {2, 1}}
	local function r49_fill_ores_new(resources, tier, mix)
		local floor = math.floor
		local y_min, lower_max = tier.y_min, tier.lower_half_y_max
		-- A row: {resource index, cube size, cube volume, ores per cluster,
		-- cluster modulus = denominator * ores per cluster, hash salt}.
		local upper, lower = {}, {}
		for index = 1, #resources do
			local resource = resources[index]
			local denominator = resource.denominators[1]
			if denominator then
				local shape = R49_CLUSTER_BY_CAP[resource.max_nodes_per_vein]
				if not shape then
					error("fail_resource_manifest: resource vein cap differs", 0)
				end
				-- (fields 7-10: the last cube this row tested and whether it is a
				-- cluster; 11: the chunk's decisions, 0 unknown, 1 none, 2 a
				-- cluster; 12: their edge in cubes; 13-15: the chunk's first cube)
				local edge = floor(79 / shape[1]) + 2
				local row = {index, shape[1], shape[1] * shape[1] * shape[1], shape[2],
					denominator * shape[2], index * 7919, false, false, false, false,
					false, edge, 0, 0, 0}
				if resource.lower_half_of ~= 1 then upper[#upper + 1] = row end
				lower[#lower + 1] = row
			end
		end
		local chunk_x, chunk_y, chunk_z = false, false, false
		local function choice(x, y, z)
			if y < y_min then return nil end
			local rows = y > lower_max and upper or lower
			for index = 1, #rows do
				local row = rows[index]
				local size = row[2]
				local cx, cy, cz = floor(x / size), floor(y / size), floor(z / size)
				local cluster = row[10]
				if cx ~= row[7] or cy ~= row[8] or cz ~= row[9] then
					local decisions = row[11]
					if chunk_x and not decisions then
						decisions = {}
						for cell = 1, row[12] * row[12] * row[12] do decisions[cell] = 0 end
						row[11] = decisions
						row[13], row[14], row[15] = floor(chunk_x / size),
							floor(chunk_y / size), floor(chunk_z / size)
					end
					if decisions then
						local edge = row[12]
						local cell = ((cz - row[15]) * edge + (cx - row[13])) * edge +
							(cy - row[14]) + 1
						local known = decisions[cell]
						if known == 0 then
							cluster = mix(cx, cy, cz, row[6]) % row[5] < row[3]
							decisions[cell] = cluster and 2 or 1
						else
							cluster = known == 2
						end
					else
						cluster = mix(cx, cy, cz, row[6]) % row[5] < row[3]
					end
					row[7], row[8], row[9], row[10] = cx, cy, cz, cluster
				end
				if cluster and mix(x, y, z, row[6] + 1) % row[3] < row[4] then
					return row[1]
				end
			end
			return nil
		end
		local function chunk(min_x, min_y, min_z)
			chunk_x, chunk_y, chunk_z = min_x or false, min_y or false, min_z or false
			for index = 1, #lower do lower[index][11] = false end
		end
		return choice, chunk
	end

	-- Ruling 30 addendum: the cave-content rule of one column, read by runtime
	-- renewal (vegetation_density.lua). Since Round 49 the generator places
	-- the cave plants natively (r7_native.lua) without this rule (mapgen plan
	-- answer 3: also under towns and planned water). A column is
	-- excluded by a "cave" claim shape on land, a functional kind other than
	-- a land grade, or a hard foundation. Planned-water/coast shapes are no
	-- protection: excluded at every depth. Every other exclusion (anchor
	-- envelopes, hard cores, anchor grades, hard foundations) ends at the
	-- column's protected floor
	-- (`floor_at(x, z)`, nil where no protected shape holds it).
	-- Returns the y below which cave content may place: math.huge when the
	-- column is not excluded, -math.huge when it is excluded at every depth.
	local function r30_protected_claim_id(id)
		local prefix = id:sub(1, 15)
		return prefix == "exclude:anchor:" or prefix == "exclude:active:"
	end
	local function r30_cave_limit(water_class, cave_id, functional_kind,
			hard_foundation, floor_at, x, z)
		if not ((water_class == "land" and cave_id ~= nil) or
				(functional_kind ~= nil and functional_kind ~= "land_grade") or
				hard_foundation) then
			return math.huge
		end
		if cave_id ~= nil and not hard_foundation and
				not r30_protected_claim_id(cave_id) then
			return -math.huge
		end
		return floor_at(x, z) or -math.huge
	end

	-- Ruling 12: mountain interiors.  Below the band depth the fill carries
	-- sparse horizontal layers: absolute y plus a smooth per-column offset
	-- picks a slab of R24_LAYER_PERIOD nodes; a slab holds at most one layer
	-- of 2-4 nodes, its rock drawn from a small biome palette.  Slabs are
	-- keyed by zone, so a zone's layers line up across its mountains.  A
	-- coarse 3D lattice adds an occasional gravel or dirt pocket or, rarer, a
	-- nest of a decorative rock of the palette.  Stone stays clearly dominant
	-- (measured 81-89 % stone, plus ores, in interiors).
	-- Round 24 B2 (cliffs): steep columns carry the same layers from below the
	-- filler down, in native stone as well as fill, so strata break through
	-- rock faces; only rock nests, never loose pockets, sit in the top 40
	-- nodes; ordinary columns get the rock nests in their top 40 nodes too.
	local R24_DEFAULT_PALETTE = {"grug_materials:slate", "grug_materials:granite",
		"grug_materials:basalt"}
	local function new_r24_fill_layers(full_seed)
		local sand_palette = {"default:sandstone", "default:desert_stone",
			"grug_materials:granite"}
		local badland_palette = {"default:desert_stone", "default:sandstone",
			"grug_materials:basalt"}
		local ash_palette = {"grug_materials:basalt", "grug_materials:slate",
			"grug_materials:granite"}
		local forest_palette = {"grug_materials:granite", "grug_materials:slate",
			"default:desert_stone"}
		local palettes = {
			grug_savanna = sand_palette, grug_beach = sand_palette,
			grug_badlands = badland_palette, grug_badlands_east = badland_palette,
			grug_blight = ash_palette, grug_bone_forest = ash_palette,
			grug_meadows = forest_palette, grug_elf_forest = forest_palette,
			grug_deep_forest = forest_palette,
		}
		-- The decorative rocks of each palette, for the rock nests.
		local function decorative(palette)
			local rocks = {}
			for index = 1, #palette do
				if palette[index]:sub(1, 15) == "grug_materials:" then
					rocks[#rocks + 1] = palette[index]
				end
			end
			return rocks
		end
		local nest_rocks = {}
		for biome, palette in pairs(palettes) do nest_rocks[biome] = decorative(palette) end
		local default_nest_rocks = decorative(R24_DEFAULT_PALETTE)
		local phase = 0
		for index = 1, #full_seed do
			phase = (phase * 131 + string.byte(full_seed, index)) % 65521
		end
		local function mix(a, b, c, salt)
			local value = (a * 374761 + b * 668265 + c * 972663 + phase * 69069 +
				salt) % 16777213
			value = (value * value) % 16777213
			return (value * 48271) % 16777213
		end
		-- Both memos are bounded: zones are a closed set, and a slab key is a
		-- zone and one of the few thousand slabs of the world's height range.
		local zone_keys, slabs = {}, {}
		local function zone_key(zone_id)
			local key = zone_keys[zone_id]
			if key == nil then
				key = 0
				for index = 1, #zone_id do
					key = (key * 131 + string.byte(zone_id, index)) % 65521
				end
				zone_keys[zone_id] = key
			end
			return key
		end
		-- start * 64 + thickness * 4 + palette index, or -1 for no layer
		local function slab(zone, k)
			local memo_key = zone * 16384 + k + 8192
			local value = slabs[memo_key]
			if value == nil then
				local h = mix(zone, k, 0, 40503)
				if h % 20 < 9 then
					local thickness = 2 + math.floor(h / 20) % 3
					local start = math.floor(h / 60) % (R24_LAYER_PERIOD - thickness + 1)
					value = start * 64 + thickness * 4 + math.floor(h / 780) % 3
				else
					value = -1
				end
				slabs[memo_key] = value
			end
			return value
		end
		local function corner(cx, cz)
			return mix(cx, cz, 0, 5813) % (2 * R24_OFFSET_AMPLITUDE + 1)
		end
		local layers = {}
		-- Bilinear between lattice corners, exact in integers.
		function layers.column_offset(x, z)
			local grid = R24_OFFSET_GRID
			local cx, cz = math.floor(x / grid), math.floor(z / grid)
			local fx, fz = x - cx * grid, z - cz * grid
			local sum = (corner(cx, cz) * (grid - fx) + corner(cx + 1, cz) * fx) *
				(grid - fz) +
				(corner(cx, cz + 1) * (grid - fx) + corner(cx + 1, cz + 1) * fx) * fz
			return math.floor(sum / (grid * grid)) - R24_OFFSET_AMPLITUDE
		end
		-- One pocket per lattice cell at most: a gravel or dirt pocket with
		-- probability 3/10, a rock nest with probability 1/10.  Returns the
		-- material and whether it is loose ground.
		function layers.pocket_at(x, y, z, biome)
			local cell = R24_POCKET_CELL
			local cx, cy, cz = math.floor(x / cell), math.floor(y / cell),
				math.floor(z / cell)
			local h = mix(cx, cz, cy, 70001)
			local kind = h % 10
			if kind >= 4 then return nil end
			local shape = mix(cz, cy, cx, 91019)
			local rx = 2 + math.floor(shape / 1000) % 2
			local rz = 2 + math.floor(shape / 2000) % 2
			local ry = 2
			local dx = x - (cx * cell + 3 + shape % 10)
			local dy = y - (cy * cell + 3 + math.floor(shape / 10) % 10)
			local dz = z - (cz * cell + 3 + math.floor(shape / 100) % 10)
			local rx2, ry2, rz2 = rx * rx, ry * ry, rz * rz
			if dx * dx * ry2 * rz2 + dy * dy * rx2 * rz2 + dz * dz * rx2 * ry2 >
					rx2 * ry2 * rz2 then
				return nil
			end
			if kind == 3 then
				local rocks = nest_rocks[biome] or default_nest_rocks
				return rocks[math.floor(h / 10) % #rocks + 1], false
			end
			return math.floor(h / 10) % 5 < 3 and "default:gravel" or "default:dirt", true
		end
		function layers.layer_at(zone_id, biome, y, offset)
			local shifted = y + offset
			local k = math.floor(shifted / R24_LAYER_PERIOD)
			local value = slab(zone_key(zone_id), k)
			if value < 0 then return nil end
			local within = shifted - k * R24_LAYER_PERIOD
			local start = math.floor(value / 64)
			if within < start or within >= start + math.floor(value / 4) % 16 then
				return nil
			end
			return (palettes[biome] or R24_DEFAULT_PALETTE)[value % 4 + 1]
		end
		-- mode "deep": pockets of both kinds, then the layer (fill 41+ deep);
		-- "face": rock nests, then the layer (top 40 of a steep column);
		-- "nest": rock nests only (top 40 of an ordinary column).
		function layers.material_at(zone_id, biome, x, y, z, offset, mode)
			local pocket, loose = layers.pocket_at(x, y, z, biome)
			if pocket and (not loose or mode == "deep") then return pocket end
			if mode == "nest" then return nil end
			return layers.layer_at(zone_id, biome, y, offset)
		end
		return layers
	end

	-- Shared by the production VM writer and the portable fixture.  Below the
	-- band depth only fill stone changes (deep mode).  In the top 40 nodes
	-- of a column the strata pass accepted (`column_info`, same exclusions as
	-- the bands), untouched native or fill stone below the filler takes rock
	-- nests, and on steep columns also the layers.  Ores and bands are never
	-- replaced: both are no longer untouched stone.
	local function r24_apply_fill_layers(context)
		local written = 0
		local layers, refs = context.layers, {}
		local original, final, intent = context.original_data, context.final_data,
			context.intent_opcode
		local stone = context.stone_cid
		local info_by_column = context.column_info
		local x_count = context.max_x - context.min_x + 1
		local bottom = math.max(context.min_y, context.floor_y)
		-- Owners wholly below the authored floor hold no fill and no bands.
		if bottom > context.max_y then return 0 end
		local function place(x, y, z, target)
			local ref = refs[target]
			if ref == nil then
				ref = context.content_ref(target)
				if not ref then
					fail("fail_content_manifest", "fill layer target is absent")
				end
				refs[target] = ref
			end
			context.write(x, y, z, ref)
			written = written + 1
		end
		for z = context.min_z, context.max_z do
			for x = context.min_x, context.max_x do
				local _, _, zone_id, biome, _, terrain_y = context.column_values_at(x, z)
				if zone_id and biome then
					local offset = layers.column_offset(x, z)
					local top = math.min(context.max_y, terrain_y - R24_LAYER_FIRST_DEPTH)
					for y = bottom, top do
						local index = context.index_at(x, y, z)
						-- The cheap half of the fill test first (B2 speedup): only
						-- untouched stone over native void can be fill.
						local target = final[index] == stone and intent[index] == 0 and
							original[index] ~= stone and
							layers.material_at(zone_id, biome, x, y, z, offset, "deep")
						if target and context.fill_stone_at(index, x, y, z) then
							place(x, y, z, target)
						end
					end
					local info = info_by_column and
						info_by_column[(z - context.min_z) * x_count + (x - context.min_x) + 1]
					if info and info >= 0 then
						local mode = info % 2 == 1 and "face" or "nest"
						local shallow_top = math.min(context.max_y,
							terrain_y - (math.floor(info / 2) + 1))
						local cap = context.column_cap and context.column_cap[
							(z - context.min_z) * x_count + (x - context.min_x) + 1]
						if cap then shallow_top = math.min(shallow_top, cap - 1) end
						for y = math.max(bottom, terrain_y - 40), shallow_top do
							local index = context.index_at(x, y, z)
							local target = final[index] == stone and intent[index] == 0 and
								layers.material_at(zone_id, biome, x, y, z, offset, mode)
							if target and (original[index] == stone or
									context.fill_stone_at(index, x, y, z)) then
								place(x, y, z, target)
							end
						end
					end
				end
			end
		end
		return written
	end

	local function exact_fields(value, allowed, label, code)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(code or "fail_settlement", label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not allowed[key] then
				fail(code or "fail_settlement",
					label .. " has unexpected field " .. tostring(key))
			end
		end
		for key, requirement in pairs(allowed) do
			if requirement == true and value[key] == nil then
				fail(code or "fail_settlement", label .. " is missing " .. key)
			end
		end
		return value
	end

	local function position(value, label)
		if type(value) ~= "table" then
			fail("fail_bounds", label .. " is not a table")
		end
		local metatable = getmetatable(value)
		if metatable ~= nil and (type(vector) ~= "table" or
				metatable ~= vector.metatable) then
			fail("fail_bounds", label .. " has an unexpected metatable")
		end
		local count = 0
		for key in pairs(value) do
			if key ~= "x" and key ~= "y" and key ~= "z" then
				fail("fail_bounds", label .. " has an unexpected field")
			end
			count = count + 1
		end
		if count ~= 3 or rawget(value, "x") == nil or
				rawget(value, "y") == nil or rawget(value, "z") == nil then
			fail("fail_bounds", label .. " fields differ")
		end
		return integer(rawget(value, "x"), label .. " x", -30912, 30927),
			integer(rawget(value, "y"), label .. " y", -30912, 30927),
			integer(rawget(value, "z"), label .. " z", -30912, 30927)
	end

	local function copy_map(value, active)
		if type(value) ~= "table" then return value end
		active = active or {}
		if active[value] then fail("fail_settlement", "metrics graph contains a cycle") end
		active[value] = true
		local result = {}
		for key, child in pairs(value) do result[copy_map(key, active)] = copy_map(child, active) end
		active[value] = nil
		return result
	end

	local function new(dependencies)
		exact_fields(dependencies, {
			full_seed_string = true, r5_adapter = true, content = true,
			templates = true, hash = true, horizontal = true, planner_source = true,
			construction_identity = true, source = true,
			counting_allocator = true, successor_tail = "optional",
		}, "settlement dependencies", "fail_settlement")
		local full_seed = dependencies.full_seed_string
		local r5_adapter = dependencies.r5_adapter
		local content = dependencies.content
		local templates = dependencies.templates
		local hash = dependencies.hash
		local horizontal = dependencies.horizontal
		local planner_source = dependencies.planner_source
		local source = dependencies.source
		-- The world's query bounds (`source/simple_map.lua` world_bounds).
		local world_bounds = source.world_bounds
		if type(world_bounds) ~= "table" then
			fail("fail_settlement", "settlement world bounds missing")
		end
		local WORLD_MIN_X, WORLD_MAX_X = world_bounds.min_x, world_bounds.max_x
		local WORLD_MIN_Z, WORLD_MAX_Z = world_bounds.min_z, world_bounds.max_z
		local r8_strata = new_r8_strata(full_seed, source)
		local r24_layers = new_r24_fill_layers(full_seed)
		local allocator = dependencies.counting_allocator
		local successor_tail = dependencies.successor_tail
		if type(full_seed) ~= "string" or full_seed == "" or
				type(r5_adapter) ~= "table" or type(r5_adapter.apply) ~= "function" or
				type(content) ~= "table" or type(templates) ~= "table" or
				type(hash) ~= "table" or type(hash.placement) ~= "function" or
				type(horizontal) ~= "table" or
				type(planner_source) ~= "table" or
				type(planner_source.column_values_at) ~= "function" or
				type(planner_source.coast_material_at) ~= "function" or
				type(planner_source.river_water_in) ~= "function" or
				type(planner_source.overlay_exclusion_at) ~= "function" or
				type(planner_source.protected_floor_at) ~= "function" or
				type(planner_source.protected_only_floor_at) ~= "function" or
				type(source) ~= "table" or
				(successor_tail ~= nil and (type(successor_tail) ~= "table" or
					type(successor_tail.settle) ~= "function")) then
			fail("fail_settlement", "construction seams differ")
		end
		exact_fields(allocator, {new_array = true, new_map = true, grow = true,
			map_put = true, seal_construction = true, enter_hotpath = true,
			leave_hotpath = true, metrics = true}, "settlement counting allocator",
			"fail_settlement")
		for name, method in pairs(allocator) do
			if type(method) ~= "function" then
				fail("fail_settlement", "settlement allocator method differs: " .. name)
			end
		end
		local function retained_array(label, size, value)
			local result = allocator:new_array(label, size)
			allocator:grow(result, label, 0, size)
			if value ~= 0 then
				for index = 1, size do result[index] = value end
			end
			return result
		end
		local contract = content.content_contract()
		local ordinary_water_cid, ordinary_water_kind, ordinary_water_param2 =
			contract.r5.resolve(10, 0, 0)
		local river_water_cid, river_water_kind, river_water_param2 =
			contract.r5.resolve(13, 0, 0)
		local native_air_cid, native_air_kind, native_air_param2 =
			contract.r5.resolve(1, 0, 0)
		if ordinary_water_kind ~= 2 or river_water_kind ~= 2 or
				ordinary_water_param2 ~= 0 or river_water_param2 ~= 0 or
				native_air_kind ~= 0 or native_air_param2 ~= 0 then
			fail("fail_content_manifest", "prospective water targets differ")
		end
		local surfaces = content.surfaces()
		local select_surface = content.surface_selector(full_seed, planner_source)
		local resources = content.resources()
		local decorations = content.decorations()
		-- Shrub templates (Round 23 Phase 2, world_zones.md §7.6) place like the
		-- engine's own schematics (mg_schematic.cpp blitToVManip): a non-force
		-- cell (a leaf) that would hit ground is skipped instead of rejecting
		-- the whole bush, so the shrub band survives on slopes. Force-placed
		-- cells (the stem) keep the full rule. The one-node ground cover is
		-- checked against the "cover" exclusion purpose, which opens a share of
		-- a start's or capital's bare band (Round 36 W3, habitat_registry.lua
		-- band_cover); every other row against "vegetation".
		do
			local rule = content.vegetation_rule(full_seed, planner_source)
			for index = 1, #decorations do
				local row = decorations[index]
				local class = rule.decoration_class(row)
				row.partial_leaves = row.kind == "template" and
					(class == "shrub" or class == "shrub_band") or nil
				row.plant_purpose = rule.band_cover(row) and "cover" or "vegetation"
				-- A generated tree (Round 47 lane TC, tree_templates.lua), or a
				-- land kit structure (Round 51 lane LK, kit_templates.lua):
				-- placed as a generated tree, its runs by the kit's rule (P9).
				row.generated_kit = row.kind == "template" and
					row.asset_or_node:match("^kitgen:") ~= nil or nil
				row.generated_tree = row.kind == "template" and
					(row.asset_or_node:match("^treegen:") ~= nil or row.generated_kit) or nil
			end
		end
		-- The ground a generated tree's root stands in (the root runs below):
		-- the content ids of the production surfaces that are ground.
		local root_ground_cids = {}
		if type(templates.root_ground_names) == "function" then
			local names = templates.root_ground_names()
			for index = 1, #names do
				local ref = content.content_ref(names[index])
				if ref then root_ground_cids[contract.content_cids[ref]] = true end
			end
		end
		-- The ground a land kit run's column stands on (Round 51 lane LK).
		local kit_ground_cids = {}
		if type(templates.kit_ground_names) == "function" then
			local names = templates.kit_ground_names()
			for index = 1, #names do
				local ref = content.content_ref(names[index])
				if ref then kit_ground_cids[contract.content_cids[ref]] = true end
			end
		end
		local projection = content.wp43_projection()
		local surface_by_id = {}
		for index = 1, #surfaces do surface_by_id[surfaces[index].id] = surfaces[index] end
		local tier_by_y = projection.tiers
		-- Exclusion reasons by kind: routes, water and coast are
		-- `route_or_water`, every other kind (anchor envelopes, active cores)
		-- `fixed_or_protected`. The static rows take their kind from their
		-- recipe; the overlay kinds come from the planner source (inland water
		-- and its banks, stale-rule R5; the road corridor, Round 22 Phase 4).
		local ROUTE_OR_WATER_KIND = {road_corridor = true, planned_water = true,
			coast = true, inland_water = true, water_bank = true}
		local recipe_kind = {}
		for index = 1, #(source.claim_exclusion_recipes or {}) do
			local recipe = source.claim_exclusion_recipes[index]
			recipe_kind[recipe.id] = recipe.kind
		end
		local exclusion_reason_by_id = {}
		for index = 1, #(source.claim_exclusions or {}) do
			local row = source.claim_exclusions[index]
			local kind = recipe_kind[row.recipe_id]
			if not kind then fail("fail_settlement", "exclusion recipe differs") end
			exclusion_reason_by_id[row.id] = ROUTE_OR_WATER_KIND[kind] and
				"route_or_water" or "fixed_or_protected"
		end
		local overlay_exclusion_id = {}
		for kind in pairs(ROUTE_OR_WATER_KIND) do
			overlay_exclusion_id[kind] = "exclude:" .. kind
		end
		-- `purpose` is the exclusion-set selector of
		-- `simple_map.lua`'s `static_exclusion_values_at`. Everything that claims,
		-- reserves or censuses ground passes nil and gets the full territory rule.
		-- Biome DECORATIONS pass "vegetation", which skips the start and capital
		-- claim envelopes; their hard cores still refuse (a start town since plan
		-- D78: the 128-node pad and a bare 12-node band, the same shape as its
		-- envelope), as do the road corridors, planned water and the coast
		-- projection, so the pad, the band, the blueprint volume and the road
		-- surfaces stay clear. Ground cover passes "cover", which also opens a
		-- hashed share of the start's or capital's band (Round 36 W3).
		local function static_exclusion_reason(x, z, purpose)
			local _, id = horizontal.static_exclusion_values_at(x, z, purpose)
			if not id then return nil end
			local reason = exclusion_reason_by_id[id]
			if not reason then fail("fail_settlement", "exclusion identity differs") end
			if reason == "route_or_water" and
					select(20, planner_source.column_values_at(x, z)) then
				return "fixed_or_protected", id
			end
			return reason, id
		end
		-- The territory rule (purpose nil) adds the overlay kinds after the
		-- static shapes: a wet river or lake column is "exclude:inland_water",
		-- dry land within two nodes of one "exclude:water_bank" (stale-rule
		-- R5). Content that seeks a shore (P9G and world-content shore rows)
		-- ignores the bank id. Vegetation sees only the road corridor (nothing
		-- grows on a road or its side slopes); cave skins see none of them.
		-- "gathering" (user ruling 2026-10-07) is the natural content's rule
		-- (P9G sources, world-content plants and their renewal): the static
		-- shapes as trees see them -- no anchor blend envelope, a POI only
		-- with its core and margin -- and every overlay kind as the territory
		-- rule adds them.
		local function exclusion_reason(x, z, purpose)
			local reason, id = static_exclusion_reason(x, z,
				purpose == "gathering" and "vegetation" or purpose)
			if reason then return reason, id end
			if purpose == "vegetation" or purpose == "cover" then
				if planner_source.overlay_exclusion_at(x, z) == "road_corridor" then
					return "route_or_water", overlay_exclusion_id.road_corridor
				end
				return nil
			end
			if purpose ~= nil and purpose ~= "gathering" then return nil end
			local kind = planner_source.overlay_exclusion_at(x, z)
			if kind == nil then return nil end
			id = overlay_exclusion_id[kind]
			if not id then fail("fail_settlement", "overlay exclusion kind differs") end
			return "route_or_water", id
		end
		local original_data = retained_array("r6_settlement_original_data",
			MAX_VOLUME, 0)
		local original_param2 = retained_array("r6_settlement_original_param2",
			MAX_VOLUME, 0)
		local final_data = retained_array("r6_settlement_final_data", MAX_VOLUME, 0)
		local final_param2 = retained_array("r6_settlement_final_param2",
			MAX_VOLUME, 0)
		local original_light = retained_array("r6_settlement_original_light",
			MAX_VOLUME, 0)
		local occupancy = retained_array("r6_settlement_occupancy", MAX_VOLUME, 0)
		local intent_opcode = retained_array("r6_settlement_intent_opcode",
			MAX_VOLUME, 0)
		local intent_feature = retained_array("r6_settlement_intent_feature",
			MAX_VOLUME, 0)
		local intent_interface = retained_array("r6_settlement_intent_interface",
			MAX_VOLUME, 0)
		local intent_aux = retained_array("r6_settlement_intent_aux", MAX_VOLUME, 0)
		local light_zero, light_full = {day = 0, night = 0}, {day = 15, night = 0}
		local call_min, call_max = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}
		local transaction_state = {
			light_zero = light_zero, light_full = light_full,
			-- The VoxelManip the transaction has written to (false before the
			-- first setter) and whether it relit it: a later failure puts the
			-- engine's bytes back (settlement.apply, Round 41 lane CR).
			written_vm = false, written_light = false,
			call_min = call_min, call_max = call_max,
			successor_tail = successor_tail,
			-- Per owner column (ruling 30 addendum, memoised per call; false
			-- until asked): the protected-only floor of the territory rule.
			protected_only_floor_column = retained_array(
				"r6_settlement_protected_only_floor_column", 6400, false),
			surface_skin_column = retained_array(
				"r6_settlement_surface_skin_column", 6400, 0),
			-- The commit scan's answers per content id pair and per content
			-- id (below); content ids are fixed for the server's lifetime.
			scan_pairs = {}, scan_liquid = {},
		}
		local stable_state = {
			resource = retained_array("r6_settlement_stable_resource", #resources, 0),
			decoration = retained_array("r6_settlement_stable_decoration", #decorations, 0),
			bound = false,
		}
		local metrics_state = {
			apply_calls = 0, modified_voxels = 0, content_dirty_columns = 0,
			param2_dirty_columns = 0,
			-- Per template row: owner-rooted candidates, those clipped by the
			-- owner (mapchunk border), those accepted, and the generated trees'
			-- root runs tried and written (Round 47 lane TC, measured by
			-- tools/r47_tc/forest.lua).
			templates = {},
		}

		-- The engine-trusted classification (r7_content.lua): every content
		-- id the writer meets comes from the VoxelManip or its own resolvers.
		local classify = contract.classify_runtime
		if type(classify) ~= "function" then
			fail("fail_settlement", "runtime classification is absent")
		end

		-- Chunk-edge light (Round 22 D64/D65): the transaction relights, from
		-- scratch, everything the VoxelManip can decide.
		--
		-- Both banks of every node inside the VM's outer one-node shell are
		-- zeroed, the sun goes down each interior column (below), and
		-- calc_lighting spreads over the whole VM from the sun runs, the light
		-- sources and the untouched shell. Light reaches at most 14 nodes, and
		-- v7's light from its temporary geometry (sun over the owner and its
		-- +-1 rows, spread from there) ends 15 nodes into the 16-node halo, so
		-- the shell still holds its own chunk's light. Every generated node
		-- inside the shell is then a from-scratch solve over the final
		-- content: a neighbour's halo gets brighter (a lamp beside it) or
		-- darker (v7's stale light) as the content says, whatever the
		-- generation order.
		--
		-- The sun, per interior column, top down through three vertical
		-- groups: the block above the owner, the owner's rows, the block
		-- below. Each group belongs to one chunk, and a chunk is generated
		-- whole or not at all (one emerge thread, num_emerge_threads = 1), so
		-- one probe node per group tells whether its chunk is still fresh: the
		-- top shell row, the owner's min_y + 40 and the bottom shell row hold
		-- ignore then. v7 writes provisional rows into a fresh block only next
		-- to a generated chunk, i.e. at a chunk's first or last row, never at a
		-- probe. The exception is v7's random-walk caves (only in chunks with
		-- maxp.y <= -33), which can carve into a fresh block and hit a probe;
		-- harmless, as no sun reaches that depth, so every group there reads
		-- "no sun" either way.
		--   generated group: the final content decides. The sun enters with
		--     the top shell's stored day light and runs down while nodes pass
		--     sunlight. Stored day 15 is sun (spread decays, and no light
		--     source exceeds 14); a sun-passing light source reads 14 even
		--     under the sun, so it defers to the node below (entry_sun);
		--   fresh group: unknown. Its real nodes are v7's provisional rows;
		--     they neither block nor carry the sun (their chunk rewrites
		--     them);
		--   first generated group below a fresh one: an owner column takes the
		--     sky the plan predicts for the chunk above (sky_open), a halo
		--     column the stored day light of that group's top node (entry_sun),
		--     i.e. the decision its own chunk made.
		-- Sun runs go to set_lighting batched along x. Left open: a sun change
		-- deeper than the bottom shell (D65 B2), structures the plan cannot
		-- predict above a fresh chunk top (sky_open).
		-- (one table: the transaction closure is at Lua 5.1's upvalue limit)
		local halo = {sun_cache = {}, args = {}, vm = false,
			shell_light = {day = 15, night = 0}}
		-- per (content, param2): 0 blocks the sun, 1 passes it, 2 passes it and
		-- emits light
		function halo.sun_class(cid, param2)
			local key = cid * 256 + param2
			local value = halo.sun_cache[key]
			if value == nil then
				local _, _, _, _, _, _, _, sunlight, source = classify(cid, param2)
				value = not sunlight and 0 or source > 0 and 2 or 1
				halo.sun_cache[key] = value
			end
			return value
		end
		function halo.passes_sun(cid, param2)
			return (halo.sun_cache[cid * 256 + param2] or
				halo.sun_class(cid, param2)) > 0
		end
		function halo.set_sun(x0, y0, z, x1, y1)
			local low, high = transaction_state.call_min, transaction_state.call_max
			low.x, low.y, low.z = x0, y0, z
			high.x, high.y, high.z = x1, y1, z
			local vm = halo.vm
			local ok = pcall(vm.set_lighting, vm, transaction_state.light_full, low, high)
			if not ok then fail("fail_vm_contract", "sun run setter failed") end
		end
		-- The sky over an owner column while the chunk above is still fresh
		-- (D65 B1), from the planned column tuple: open unless the planned
		-- terrain or water lies above the owner's top row. Trees, buildings,
		-- road decks and other structures of the chunk above are not in the
		-- tuple; that chunk corrects the 16 rows below it when it is
		-- generated.
		function halo.sky_open(x, z, max_y)
			local _, _, _, _, _, terrain_y, water_y =
				planner_source.column_values_at(x, z)
			return terrain_y <= max_y and (water_y == nil or water_y <= max_y)
		end
		-- The stored (pre-transaction) day light at index i is sunlight. The
		-- one light read of the transaction is checked where it is used.
		function halo.stored_sun(light, i)
			local value = light[i]
			if type(value) ~= "number" or value < 0 or value > 255 or
					value % 1 ~= 0 then
				fail("fail_vm_contract", "VM light differs")
			end
			return value % 16 == 15
		end
		-- The sun its own chunk recorded at node i, the top of a generated group
		-- or the top shell: stored day 15 on a sun-passing node. A sun-passing
		-- light source is the exception: spreadLight stores its own level in
		-- both banks and its sunlit neighbours raise the day bank to 14 only,
		-- so it defers to the node below, at most `rows` nodes down (never as
		-- far as the rows v7's temporary sun reaches).
		function halo.entry_sun(data, param2, light, i, ex, rows)
			for _ = 1, rows do
				local class = halo.sun_class(data[i], param2[i])
				if class == 0 then return false end
				if halo.stored_sun(light, i) then return true end
				if class == 1 then return false end
				i = i - ex
			end
			return false
		end

		-- a: data, param2 (final content), light (the ORIGINAL light),
		--   ignore_cid, emerged bounds eminx .. emaxz, owner bounds min_x ..
		--   max_z. Returns the number of sun runs.
		function halo.relight(a)
			local data, param2, light, ignore_cid = a.data, a.param2, a.light,
				a.ignore_cid
			local eminx, eminy, eminz, emaxx, emaxy, emaxz =
				a.eminx, a.eminy, a.eminz, a.emaxx, a.emaxy, a.emaxz
			local min_x, min_y, min_z, max_x, max_y, max_z =
				a.min_x, a.min_y, a.min_z, a.max_x, a.max_y, a.max_z
			local passes_sun, set_sun, stored_sun = halo.passes_sun, halo.set_sun,
				halo.stored_sun
			local entry_sun = halo.entry_sun
			local shell_light = halo.shell_light
			local vm = halo.vm
			local ex = emaxx - eminx + 1
			local zs = ex * (emaxy - eminy + 1)
			local low, high = transaction_state.call_min, transaction_state.call_max
			low.x, low.y, low.z = eminx + 1, eminy + 1, eminz + 1
			high.x, high.y, high.z = emaxx - 1, emaxy - 1, emaxz - 1
			local ok = pcall(vm.set_lighting, vm, transaction_state.light_zero, low, high)
			if not ok then fail("fail_vm_contract", "light reset failed") end
			-- index offsets from a column's bottom shell node
			local top_offset = (emaxy - eminy) * ex
			local probe_offset = (min_y + 40 - eminy) * ex
			local owner_top_offset = (max_y - eminy) * ex
			-- entry_sun's reach: from the top shell down to max_y + 2 (v7's sun
			-- ends at max_y + 1 over the owner)
			local entry_rows = emaxy - max_y - 1
			local calls = 0
			-- one pending sun run along x, extended while columns share a segment
			local run_x0, run_x1, run_top, run_bottom, run_z
			local function flush()
				if run_x0 ~= nil then
					set_sun(run_x0, run_bottom, run_z, run_x1, run_top)
					calls = calls + 1
					run_x0 = nil
				end
			end
			local function emit(x, z, top, bottom)
				if run_x0 ~= nil and run_z == z and run_x1 == x - 1 and
						run_top == top and run_bottom == bottom then
					run_x1 = x
				else
					flush()
					run_x0, run_x1, run_top, run_bottom, run_z = x, x, top, bottom, z
				end
			end
			for z = eminz + 1, emaxz - 1 do
				local owner_row = z >= min_z and z <= max_z
				local col = (z - eminz) * zs + 2
				for x = eminx + 1, emaxx - 1 do
					local owner_col = owner_row and x >= min_x and x <= max_x
					local top_i = col + top_offset
					local fresh_above = data[top_i] == ignore_cid
					local fresh_side = not owner_col and
						data[col + probe_offset] == ignore_cid
					local fresh_below = data[col] == ignore_cid
					-- true / false, nil = unknown (below a fresh group)
					local sun
					if not fresh_above then
						sun = entry_sun(data, param2, light, top_i, ex, entry_rows)
					end
					local seg_top, seg_bottom
					for group = 1, 3 do
						local y_hi, y_lo, fresh
						if group == 1 then y_hi, y_lo, fresh = emaxy - 1, max_y + 1, fresh_above
						elseif group == 2 then y_hi, y_lo, fresh = max_y, min_y, fresh_side
						else y_hi, y_lo, fresh = min_y - 1, eminy + 1, fresh_below end
						if fresh then
							sun = nil
						else
							local i = col + (y_hi - eminy) * ex
							if sun == nil then
								if owner_col then
									-- group 2 under a fresh chunk above
									local top = col + owner_top_offset
									sun = passes_sun(data[top], param2[top]) and
										halo.sky_open(x, z, max_y)
								else
									sun = entry_sun(data, param2, light, i, ex, entry_rows)
								end
							end
							if sun then
								for y = y_hi, y_lo, -1 do
									if passes_sun(data[i], param2[i]) then
										if seg_top == nil then seg_top = y end
										seg_bottom = y
									else
										sun = false
										break
									end
									i = i - ex
								end
							end
						end
						if seg_top ~= nil and not sun then
							emit(x, z, seg_top, seg_bottom)
							seg_top = nil
						end
					end
					if seg_top ~= nil then emit(x, z, seg_top, seg_bottom) end
					-- A run down to the bottom shell's top neighbour continues
					-- into the shell node, keeping its night bank (the node's
					-- night light may come from below the VM).
					if sun and not fresh_below and passes_sun(data[col], param2[col]) and
							not stored_sun(light, col) then
						shell_light.night = (light[col] - light[col] % 16) / 16
						low.x, low.y, low.z = x, eminy, z
						high.x, high.y, high.z = x, eminy, z
						ok = pcall(vm.set_lighting, vm, shell_light, low, high)
						if not ok then fail("fail_vm_contract", "shell sun setter failed") end
					end
					col = col + 1
				end
			end
			flush()
			-- Spread only: calc_lighting spreads over the whole VM. Its own sun
			-- scan (param1 = 15, clearing the night bank) is confined to the
			-- interior's bottom row, where it repeats what the sun runs did.
			low.x, low.y, low.z = eminx + 1, eminy + 1, eminz + 1
			high.x, high.y, high.z = emaxx - 1, eminy + 1, emaxz - 1
			ok = pcall(vm.calc_lighting, vm, low, high, true)
			if not ok then fail("fail_vm_contract", "light spread failed") end
			return calls
		end

		local function resolve(content_ref, param2, role_bit)
			integer(content_ref, "content ref", 1, #contract.content_names,
				"fail_content_manifest")
			integer(param2, "content param2", 0, 255, "fail_content_manifest")
			local ok, cid, kind, mode, value, mask = pcall(contract.resolve_r6,
				content_ref, param2)
			if not ok or type(cid) ~= "number" or kind ~= 1 or mode ~= 1 or
					value ~= param2 or mask ~= contract.content_kind_masks[content_ref] or
					math.floor(mask / role_bit) % 2 ~= 1 or cid == contract.ignore_cid then
				fail("fail_content_manifest", "content target differs")
			end
			return cid, value
		end

		-- The world's placement hash (r6_hash.lua, Round 49): P8's fill ores
		-- and the P9 draws below.
		local placement_mix, placement_salt = hash.placement(full_seed)
		-- P8 (Round 49): the fill-ore choice of this world.
		local fill_ore_at, fill_ore_chunk = r49_fill_ores_new(resources, tier_by_y[1],
			placement_mix)

		-- The planner's river/lake bed and bank seal (planner.lua) as a y range,
		-- or nil. A wet sealed column seals its bed; a column beside such water
		-- gets the bank seal. Neighbours are only read near sealed water. The
		-- sealed id "lake:<n>" holds ordinary water, every other id ("river:",
		-- a lake's step face "outlet:") river water.
		local function river_liquid(river_id)
			return river_id ~= nil and river_id:sub(1, 5) ~= "lake:"
		end
		local function wet_river_at(x, z)
			local _, _, _, _, _, terrain_y, water_y, river_id =
				planner_source.column_values_at(x, z)
			if river_id ~= nil and terrain_y < water_y then
				return terrain_y, water_y
			end
			return nil, nil
		end
		local function analytic_hydrology_seal(x, z)
			local bed_y = wet_river_at(x, z)
			local near = planner_source.river_water_in(x - 2, z - 2, x + 2, z + 2)
			if bed_y then
				-- tripwire, as in the planner: a sealed column the bucket
				-- lookup misses would lose the bank seals around it
				if not near then
					fail("fail_source", "sealed water column outside river_water_in")
				end
				return bed_y - 2, bed_y
			end
			if not near then return nil, nil end
			local terrain_y = select(6, planner_source.column_values_at(x, z))
			local minimum_seal_y, maximum_water_y
			for dx = -2, 2 do
				for dz = -2, 2 do
					local distance = math.abs(dx) + math.abs(dz)
					if distance >= 1 and distance <= 2 then
						local neighbor_bed, neighbor_surface = wet_river_at(x + dx, z + dz)
						if neighbor_bed then
							minimum_seal_y = minimum_seal_y and
								math.min(minimum_seal_y, neighbor_bed - 2) or neighbor_bed - 2
							maximum_water_y = maximum_water_y and
								math.max(maximum_water_y, neighbor_surface) or neighbor_surface
						end
					end
				end
			end
			if minimum_seal_y then
				return minimum_seal_y, math.min(terrain_y, maximum_water_y)
			end
			return nil, nil
		end

		local function analytic_p7_material_ref(x, y, z)
			local _, _, zone_id, biome, _, terrain_y, water_y, _, _,
				functional_kind, _, functional_feature_id =
					planner_source.column_values_at(x, z)
			local surface = select_surface(biome, x, z, water_y, terrain_y, zone_id)
			if not zone_id or not surface or y < terrain_y - surface.filler_depth or
					y > terrain_y or y < -37 then return nil end
			-- Anchors 1..12: the six starts and, since WP13 round 3, the six
			-- CAPITALS. A capital fitting grades its whole 704-node blend square
			-- and everything inside it was `default:stone` before, which is why
			-- all six looked like the same slab. They keep the surface of their
			-- own zone's biomes. Ordinary POI collars use this same natural
			-- skin; their authored buildings and short paving overwrite it later.
			local dry_anchor_grade = functional_kind == "land_grade" and
				type(functional_feature_id) == "string" and
				functional_feature_id:match("^anchor_%d%d%d$") ~= nil and
				(water_y == nil or water_y <= terrain_y)
			if functional_kind == "anchor_platform" or
					(functional_kind == "land_grade" and not dry_anchor_grade) then
				return nil
			end
			local wet = water_y ~= nil and water_y > terrain_y
			-- The seal keeps the ground solid; only the top of a sealed bed or
			-- bank takes its surface material over it (below).
			local seal_min, seal_max = analytic_hydrology_seal(x, z)
			if seal_min and seal_min <= y and y <= seal_max and y ~= terrain_y then
				return nil
			end
			if y < terrain_y then return surface.filler_ref end
			local name = wet and surface.bed or
				(biome == "grug_beach" and surface.shore or surface.top)
			return content.content_ref(name)
		end

		local function analytic_p7_support_ref(x, y, z)
			local _, _, _, _, _, terrain_y = planner_source.column_values_at(x, z)
			if y ~= terrain_y then return nil end
			return analytic_p7_material_ref(x, y, z)
		end

		local function decoration_support_ref(row, x, y, z)
			local ref = analytic_p7_support_ref(x, y, z)
			local _, _, _, biome = planner_source.column_values_at(x, z)
			if content.decoration_cover(row.id, biome, ref) > 0 then return ref end
			return nil
		end

		local function run_at(plan, column, y)
			local r5 = plan.r5_plan
			for run = r5.column_start[column], r5.column_start[column + 1] - 1 do
				local base = (run - 1) * RUN_STRIDE
				if y < r5.run_values[base + 1] then return nil end
				if y <= r5.run_values[base + 2] then return base end
			end
			return nil
		end
		-- (one table: the transaction closure is at Lua 5.1's upvalue limit)
		local helpers = {
			-- natural rock classes a force-placed decoration root may take
			ground_body_class = function(class_id)
				return class_id == CLASS_NATURAL_HOST or class_id == CLASS_NATURAL_SURFACE or
					class_id == CLASS_NATIVE_ORE or class_id == CLASS_WP43_STRATUM
			end,
			-- the planned R5 opcode of a voxel (27: natural terrain fill)
			r5_opcode_at = function(plan, column, y)
				local rbase = run_at(plan, column, y)
				return rbase and plan.r5_plan.run_values[rbase + 4]
			end,
			exclusion_reason = exclusion_reason,
			analytic_p7_material_ref = analytic_p7_material_ref,
			analytic_p7_support_ref = analytic_p7_support_ref,
			decoration_support_ref = decoration_support_ref,
			r8_strata = r8_strata,
			r8_select_surface = select_surface, r8_horizontal = horizontal,
			-- the swamp's pools (Round 47 lane SW, swamp_pools.lua), or nil
			swamp_pools = content.swamp_pools(full_seed, planner_source),
			r8_apply_strata = r8_apply_strata,
			r24_layers = r24_layers, r24_apply_fill_layers = r24_apply_fill_layers,
			r24_fill_stone = r24_fill_stone,
			r5_adapter = r5_adapter,
			r8_templates = templates, r8_full_seed = full_seed,
			root_ground_cids = root_ground_cids, kit_ground_cids = kit_ground_cids,
			template_metrics = metrics_state.templates,
			tree_spacing = TREE_SPACING,
			template_rotation = templates.rotation_runtime or templates.rotation}
		-- The P9 draws of a decoration root, each its row's stream of the
		-- placement hash (r6_hash.lua): a template's quarter turn (0..3) and a
		-- simple class-3 decoration's height (2..4).
		local rotation_salt, height_salt = {}, {}
		for index = 1, #decorations do
			local id = decorations[index].id
			rotation_salt[id] = placement_salt("decoration_rotation", id)
			height_salt[id] = placement_salt("decoration_simple_height", id)
		end
		function helpers.rotation_at(id, x, y, z)
			return placement_mix(x, y, z, rotation_salt[id]) % 4
		end
		function helpers.simple_height_at(id, x, y, z)
			return 2 + placement_mix(x, y, z, height_salt[id]) % 3
		end

		local function apply_impl(vm, minp, maxp, plan, plan_generation, call_mode)
			if call_mode ~= "production" then
				fail("fail_status", "settlement call mode differs")
			end
			if type(plan) ~= "table" or
					plan.schema ~= "grug_wp40_r6_refinement_plan_v1" or
					not plan.valid or plan.generation ~= plan_generation or
					type(dependencies.construction_identity) ~= "table" or
					dependencies.construction_identity.value == false or
					not rawequal(plan.construction_identity,
						dependencies.construction_identity.value) then
				fail("fail_settlement", "plan identity or generation differs")
			end
			local min_x, min_y, min_z = position(minp, "minp")
			local max_x, max_y, max_z = position(maxp, "maxp")
			if min_x ~= plan.min_x or min_y ~= plan.min_y or min_z ~= plan.min_z or
					max_x ~= plan.max_x or max_y ~= plan.max_y or max_z ~= plan.max_z then
				fail("fail_settlement", "plan bounds differ")
			end
			if type(vm) ~= "table" and type(vm) ~= "userdata" then
				fail("fail_vm_contract", "VoxelManip object differs")
			end
			if not stable_state.bound then
				local function bind(values, field, output)
					for value_index = 1, #values do
						local wanted, found = values[value_index][field], 0
						for stable_index = 1, #plan.stable_refs do
							if plan.stable_refs[stable_index] == wanted then
								found = stable_index break
							end
						end
						if found == 0 then
							fail("fail_settlement", "successor stable ref is absent")
						end
						output[value_index] = found
					end
				end
				bind(resources, "key", stable_state.resource)
				bind(decorations, "id", stable_state.decoration)
				stable_state.bound = true
			end
			local required_methods = {"get_emerged_area", "get_data", "get_param2_data",
				"get_light_data", "set_data", "set_param2_data", "set_lighting",
				"calc_lighting", "set_light_data", "update_liquids"}
			for index = 1, #required_methods do
				if type(vm[required_methods[index]]) ~= "function" then
					fail("fail_vm_contract", "required VoxelManip method is absent")
				end
			end
			local ok_area, emerged_min, emerged_max = pcall(vm.get_emerged_area, vm)
			if not ok_area then fail("fail_vm_contract", "get_emerged_area failed") end
			-- Luanti pushes get_emerged_area results as builtin vectors. Normalize
			-- that exact engine representation before the plain R6 boundary.
			local eminx, eminy, eminz = position(emerged_min, "emerged min")
			local emaxx, emaxy, emaxz = position(emerged_max, "emerged max")
			if eminx ~= min_x - 16 or eminy ~= min_y - 16 or eminz ~= min_z - 16 or
					emaxx ~= max_x + 16 or emaxy ~= max_y + 16 or emaxz ~= max_z + 16 then
				fail("fail_halo", "emerged halo differs")
			end
			local ex, ey, ez = emaxx - eminx + 1, emaxy - eminy + 1,
				emaxz - eminz + 1
			local volume = ex * ey * ez
			if volume < 1 or volume > MAX_VOLUME then
				fail("fail_vm_contract", "emerged volume differs")
			end
			local y_stride, z_stride = ex, ex * ey
			local function index_at(x, y, z)
				return (z - eminz) * z_stride + (y - eminy) * y_stride +
					(x - eminx) + 1
			end
			local ok_data, returned_data = pcall(vm.get_data, vm, original_data)
			if not ok_data or not rawequal(returned_data, original_data) then
				fail("fail_vm_contract", "get_data did not reuse the retained buffer")
			end
			local ok_p2, returned_p2 = pcall(vm.get_param2_data, vm, original_param2)
			if not ok_p2 or not rawequal(returned_p2, original_param2) then
				fail("fail_vm_contract", "get_param2_data did not reuse the retained buffer")
			end
			-- No per-voxel scalar check: the engine fills every index of the
			-- emerged volume with an integer content ID (u16) and param2 (u8)
			-- (`l_vmanip.cpp` get_data / get_param2_data), and the halo check
			-- above fixes the volume.
			-- The five side arrays are written inside the owner only
			-- (`write_intent` refuses anything else; the decoration box and the
			-- successor writers test the owner), so their shell stays 0 and the
			-- owner box alone is reset; the whole volume again when the emerged
			-- box changes its shape (a smaller slice moves the owner's indices).
			local shape = (ex * 256 + ey) * 256 + ez
			if transaction_state.reset_shape ~= shape then
				for index = 1, volume do
					occupancy[index], intent_opcode[index], intent_feature[index],
						intent_interface[index], intent_aux[index] = 0, 0, 0, 0, 0
				end
				transaction_state.reset_shape = shape
			else
				for z = min_z, max_z do
					for y = min_y, max_y do
						local first = index_at(min_x, y, z)
						for index = first, first + max_x - min_x do
							occupancy[index], intent_opcode[index], intent_feature[index],
								intent_interface[index], intent_aux[index] = 0, 0, 0, 0, 0
						end
					end
				end
			end

			-- The nested R5 transaction works on its own buffers and hands its
			-- whole result back through the shadow's setters; content it did not
			-- change is copied over from the engine's below.
			local data_set, param2_set = false, false
			local shadow = {}
			function shadow.get_emerged_area() return emerged_min, emerged_max end
			function shadow.get_data(_, buffer)
				for index = 1, volume do buffer[index] = original_data[index] end
				return buffer
			end
			function shadow.get_param2_data(_, buffer)
				for index = 1, volume do buffer[index] = original_param2[index] end
				return buffer
			end
			function shadow.set_data(_, buffer)
				for index = 1, volume do final_data[index] = buffer[index] end
				data_set = true
			end
			function shadow.set_param2_data(_, buffer)
				for index = 1, volume do final_param2[index] = buffer[index] end
				param2_set = true
			end
			local function discarded_light_call()
				fail("fail_vm_contract", "composed R5 attempted an inner light transaction")
			end
			shadow.get_light_data = discarded_light_call
			shadow.set_lighting = discarded_light_call
			shadow.calc_lighting = discarded_light_call
			shadow.set_light_data = discarded_light_call
			function shadow.update_liquids() end
			local r5_result = helpers.r5_adapter:apply(shadow, minp, maxp, plan.r5_plan,
				plan.r5_generation, "engine_fixture", "outer_transaction")
			if type(r5_result) ~= "string" then
				fail("fail_settlement", "nested R5 result differs")
			end
			if not data_set then
				for index = 1, volume do final_data[index] = original_data[index] end
			end
			if not param2_set then
				for index = 1, volume do final_param2[index] = original_param2[index] end
			end

			local x_count = max_x - min_x + 1
			local function column_index(x, z)
				return (z - min_z) * x_count + (x - min_x) + 1
			end
			-- Round 24 ruling 30 addendum: below a protected-only floor the
			-- territory rule's claim exclusion no longer applies (an anchor
			-- envelope on a slope reaches ground far below its anchor).
			-- -math.huge where the column has no such floor.
			local protected_only_floor_column =
				transaction_state.protected_only_floor_column
			for index = 1, x_count * (max_z - min_z + 1) do
				protected_only_floor_column[index] = false
			end
			local function protected_only_floor(x, z)
				local owned = x >= min_x and x <= max_x and z >= min_z and z <= max_z
				local column = owned and column_index(x, z)
				local value = owned and protected_only_floor_column[column]
				if not value then
					value = planner_source.protected_only_floor_at(x, z) or -math.huge
					if owned then protected_only_floor_column[column] = value end
				end
				return value
			end
			local function write_intent(x, y, z, content_ref, param2, opcode,
					feature_ref, interface_ref, role_bit, occupant)
				if x < min_x or x > max_x or y < min_y or y > max_y or
						z < min_z or z > max_z then
					fail("fail_settlement", ("successor write escaped central owner " ..
						"at (%s,%s,%s) opcode=%s"):format(tostring(x), tostring(y),
						tostring(z), tostring(opcode)))
				end
				local index = index_at(x, y, z)
				local cid, exact_param2 = resolve(content_ref, param2, role_bit)
				final_data[index], final_param2[index] = cid, exact_param2
				intent_opcode[index], intent_feature[index], intent_interface[index] =
					opcode, feature_ref or 0, interface_ref or 0
				intent_aux[index] = (content_ref - 1) * 256 + exact_param2
				if occupant then occupancy[index] = occupant end
			end

			local surface_skin_column = transaction_state.surface_skin_column
			local function surface_skin_excluded(x, z, water_class, functional_kind,
					hard_foundation)
				local _, static_id = helpers.r8_horizontal.static_exclusion_values_at(
					x, z, "cave")
				-- Natural landmark relief envelopes are terrain, not occupied cells.
				-- Their real water/route/build footprints remain independently guarded.
				return (water_class == "land" and static_id ~= nil) or
					(functional_kind ~= nil and functional_kind ~= "land_grade") or
					hard_foundation
			end
			local skin_context = {}
			function skin_context.column_at(x, z)
				local water_class, _, _, _, _, terrain_y =
					planner_source.column_values_at(x, z)
				return water_class, terrain_y
			end
			function skin_context.native_class_at(x, y, z)
				if x < eminx or x > emaxx or y < eminy or y > emaxy or
						z < eminz or z > emaxz then return CLASS_UNKNOWN end
				local index = index_at(x, y, z)
				return original_data[index] == native_air_cid and
					CLASS_AIR or CLASS_UNKNOWN
			end
			function skin_context.preserved_native_air_at(x, y, z)
				if x < eminx or x > emaxx or y < eminy or y > emaxy or
						z < eminz or z > emaxz then return false end
				local index = index_at(x, y, z)
				if original_data[index] ~= native_air_cid or
						final_data[index] ~= native_air_cid then return false end
				local column = column_index(x, z)
				local rbase = y >= min_y and y <= max_y and
					run_at(plan, column, y) or nil
				-- Owned cells must have traversed the cave-preserving terrain-fill
				-- policy.  Below-owner halo cells are already the committed result
				-- of the preceding slice, which is the dust-only boundary case.
				-- R5 can also preserve native cave air under a start/capital
				-- anchor grade (opcode 21). The immutable-air and final-air checks
				-- above prove preservation; functional footprint guards still apply.
				local opcode = rbase ~= nil and plan.r5_plan.run_values[rbase + 4]
				return y < min_y or opcode == 27 or opcode == 21
			end
			function skin_context.excluded_at(x, z)
				local water_class, _, _, _, _, _, _, _, _, functional_kind, _, _, _,
					_, _, _, _, _, _, hard_foundation =
						planner_source.column_values_at(x, z)
				return surface_skin_excluded(x, z, water_class, functional_kind,
					hard_foundation)
			end
			for z = min_z, max_z do
				for x = min_x, max_x do
					local column = column_index(x, z)
					local water_class, _, _, _, _, terrain_y, _, _, _, functional_kind,
						_, _, _, _, _, _, _, _, _, hard_foundation =
							planner_source.column_values_at(x, z)
					local excluded, opened = false, false
					local skin_min, _, surface_owned, dust_owned =
						r9_surface_skin_owned_range(terrain_y, min_y, max_y)
					if skin_min ~= nil or surface_owned or dust_owned then
						local has_native_air = false
						for depth = 1, 3 do
							local y = terrain_y - depth
							if y >= eminy and original_data[index_at(x, y, z)] ==
									native_air_cid then
								has_native_air = true
								break
							end
						end
						if has_native_air then
							excluded = surface_skin_excluded(x, z, water_class,
								functional_kind, hard_foundation)
							-- A swamp pool and its banks keep their skin (Round 47
							-- lane SW): an opening there would drain the pool.
							if not excluded and water_class == "land" and
									not (helpers.swamp_pools and
										helpers.swamp_pools.guard(x, z)) then
								opened = r9_surface_skin_open(skin_context, x, z)
							end
						end
					end
					surface_skin_column[column] = excluded and 0 or (opened and 2 or 1)
				end
			end

			-- P7: exact R5 P5 predecessor refinement.
			-- These horizontal decisions are invariant for the complete column and
			-- the planner has already frozen water/race values in its retained plan.
			-- Resolve the remaining exclusion once rather than once per resource node.
			for z = min_z, max_z do
				for x = min_x, max_x do
					local column = column_index(x, z)
					local base = (column - 1) * COLUMN_STRIDE
					local terrain_y = plan.column_values[base + 5]
					local surface_kind = plan.column_values[base + 7]
					local top_ref = plan.column_values[base + 8]
					local filler_ref = plan.column_values[base + 9]
					local alternate_ref = plan.column_values[base + 10]
					local filler_depth = plan.column_values[base + 11]
					local dust_ref = plan.column_values[base + 12]
					local dry_anchor_grade
					if top_ref ~= 0 and terrain_y >= min_y and terrain_y <= max_y and
							surface_skin_column[column] == 2 then
						local index = index_at(x, terrain_y, z)
						final_data[index], final_param2[index] = native_air_cid, 0
						intent_opcode[index], intent_feature[index],
							intent_interface[index], intent_aux[index] = 26, 0, 0, 0
						occupancy[index] = 1
					elseif top_ref ~= 0 and terrain_y >= min_y and terrain_y <= max_y then
						local rbase = run_at(plan, column, terrain_y)
						local predecessor = rbase and plan.r5_plan.run_values[rbase + 4]
						if predecessor == 22 then
							local _, _, _, _, _, _, water_y, _, _, functional_kind, _,
								functional_feature_id = planner_source.column_values_at(x, z)
							dry_anchor_grade = functional_kind == "land_grade" and
								type(functional_feature_id) == "string" and
								functional_feature_id:match("^anchor_%d%d%d$") ~= nil and
								(water_y == nil or water_y <= terrain_y)
						end
						-- A sealed river or lake bed (R5 opcode 18) and a sealed
						-- bank (17) get their surface on top like any natural
						-- column: bed patches of sand, gravel, stone and swamp mud,
						-- the near-water shore material or the biome top
						-- (world_zones.md §7.4; Round 22 Phase 5) -- where the
						-- analytic mirror answers that top too, so the decoration
						-- planning agrees with the writer (a bay platform or a wet
						-- anchor grade keeps its seal).
						if predecessor == 28 or dry_anchor_grade and predecessor == 22 or
								((predecessor == 17 or predecessor == 18) and
									helpers.analytic_p7_support_ref(x, terrain_y, z) ~= nil) then
							local opcode = surface_kind == 1 and 4 or
								(surface_kind == 2 and 3 or 1)
							write_intent(x, terrain_y, z,
								surface_kind == 1 and top_ref or alternate_ref, 0,
								opcode, 0, 0, 1, false)
						end
					end
					for y = terrain_y - filler_depth, terrain_y - 1 do
						if y >= min_y and y <= max_y then
							local rbase = run_at(plan, column, y)
							local predecessor = rbase and plan.r5_plan.run_values[rbase + 4]
							if predecessor == 21 and dry_anchor_grade == nil then
								local _, _, _, _, _, _, water_y, _, _, functional_kind, _,
									functional_feature_id = planner_source.column_values_at(x, z)
								dry_anchor_grade = functional_kind == "land_grade" and
									type(functional_feature_id) == "string" and
									functional_feature_id:match("^anchor_%d%d%d$") ~= nil and
									(water_y == nil or water_y <= terrain_y)
							end
							if predecessor == 27 or dry_anchor_grade == true and predecessor == 21 then
								local index = index_at(x, y, z)
								local class_id = classify(final_data[index], final_param2[index])
								if filler_ref ~= 0 and class_id ~= CLASS_AIR and
										class_id ~= CLASS_LIQUID then
									if class_id == CLASS_FOREIGN or class_id == CLASS_UNKNOWN or
											class_id == CLASS_IGNORE then
										fail("fail_settlement", ("P7 filler predecessor differs " ..
											"at (%d,%d,%d) cid=%d param2=%d class=%d opcode=%d"):format(
											x, y, z, final_data[index], final_param2[index], class_id,
											predecessor))
									end
									write_intent(x, y, z, filler_ref, 0, 2, 0, 0, 1, false)
								end
							end
						end
					end
					local dust_y = terrain_y + 1
					if dust_ref ~= 0 and surface_kind == 1 and
							surface_skin_column[column] ~= 2 and dust_y >= min_y and
							dust_y <= max_y then
						local rbase = run_at(plan, column, dust_y)
						local index = index_at(x, dust_y, z)
						if helpers.analytic_p7_support_ref(x, terrain_y, z) ~= nil and rbase and
								plan.r5_plan.run_values[rbase + 4] == 26 and
								classify(final_data[index], final_param2[index]) == CLASS_AIR then
							write_intent(x, dust_y, z, dust_ref, 0, 33, 0, 0, 2, false)
						end
					end
				end
			end

			-- R9 surface skin. The opening decision above used immutable native data
			-- before P7. Fill only native air that the R5 resolver actually preserved;
			-- exact foundations, water, paths and clears therefore remain untouched.
			local skin_host_ref = content.content_ref("default:stone")
			if not skin_host_ref then
				fail("fail_content_manifest", "surface skin host rock is absent")
			end
			-- Round 24: the terrain-fill stone predicate (bands and layers).
			local fill_stone_cid = contract.content_cids[skin_host_ref]
			local function fill_stone_at(index, x, y, z)
				if final_data[index] ~= fill_stone_cid or intent_opcode[index] ~= 0 or
						original_data[index] == fill_stone_cid then
					return false
				end
				local rbase = run_at(plan, column_index(x, z), y)
				return helpers.r24_fill_stone(original_data[index], final_data[index],
					intent_opcode[index], rbase and plan.r5_plan.run_values[rbase + 4],
					fill_stone_cid)
			end
			for z = min_z, max_z do
				for x = min_x, max_x do
					local column = column_index(x, z)
					if surface_skin_column[column] == 1 then
						local terrain_y = select(6, planner_source.column_values_at(x, z))
						for y = math.max(-37, terrain_y - 3), terrain_y - 1 do
							if y >= min_y and y <= max_y then
								local index = index_at(x, y, z)
								local rbase = run_at(plan, column, y)
								local opcode = rbase and plan.r5_plan.run_values[rbase + 4]
								local feature_ref = rbase and plan.r5_plan.run_values[rbase + 7] or 0
								local feature_id = feature_ref ~= 0 and
									plan.r5_plan.stable_refs[feature_ref] or nil
								local anchor_grade = type(feature_id) == "string" and
									feature_id:match("^anchor_%d%d%d$") ~= nil
							if original_data[index] == native_air_cid and
										final_data[index] == original_data[index] and
										(opcode == 27 or opcode == 21 and anchor_grade) then
									write_intent(x, y, z, skin_host_ref, 0, 2, 0, 0, 1, false)
								end
							end
						end
					end
				end
			end

			if contract.schema == "grug_wp40_r7_production_r6_content_v1" then
			-- R8 shallow strata.  The shared writer seam accepts only immutable
			-- native stone; native gravel ore is therefore never CID-ambiguous.
			local stone_ref = content.content_ref("default:stone")
			if not stone_ref then
				fail("fail_content_manifest", "native stone is absent")
			end
			-- Round 24 B2: the strata pass hands each column's band eligibility,
			-- filler depth and steepness to the layer pass.
			local column_info, column_cap = {}, {}
			helpers.r8_apply_strata({min_x = min_x, min_y = min_y, min_z = min_z,
				max_x = max_x, max_y = max_y, max_z = max_z, floor_y = -37,
				original_data = original_data, column_info = column_info,
				final_data = final_data, content_cids = contract.content_cids,
				stone_cid = contract.content_cids[stone_ref], index_at = index_at,
				column_values_at = planner_source.column_values_at,
				static_exclusion_values_at = helpers.r8_horizontal.static_exclusion_values_at,
				protected_only_floor_at = protected_only_floor, column_cap = column_cap,
				select_surface = helpers.r8_select_surface, strata = helpers.r8_strata,
				content_ref = content.content_ref, fill_stone_at = fill_stone_at,
				write = function(x, y, z, ref)
					write_intent(x, y, z, ref, 0, 2, 0, 0, 1, false)
				end})

			-- Round 24 ruling 12 and B2: layers in the fill below the band depth,
			-- layers through steep faces, rock nests near the surface.
			helpers.r24_apply_fill_layers({min_x = min_x, min_y = min_y,
				min_z = min_z, max_x = max_x, max_y = max_y, max_z = max_z,
				floor_y = -37, index_at = index_at, column_info = column_info,
				column_cap = column_cap,
				column_values_at = planner_source.column_values_at,
				original_data = original_data, final_data = final_data,
				intent_opcode = intent_opcode, stone_cid = fill_stone_cid,
				layers = helpers.r24_layers, fill_stone_at = fill_stone_at,
				content_ref = content.content_ref,
				write = function(x, y, z, ref)
					write_intent(x, y, z, ref, 0, 2, 0, 0, 1, false)
				end})
			end
			local function inside_owner(x, y, z)
				return x >= min_x and x <= max_x and y >= min_y and y <= max_y and
					z >= min_z and z <= max_z and x >= WORLD_MIN_X and x <= WORLD_MAX_X and
					z >= WORLD_MIN_Z and z <= WORLD_MAX_Z and y >= -31000 and y <= 31000
			end
			local function candidate_fields(candidate)
				local base = (candidate - 1) * CANDIDATE_STRIDE
				return plan.candidate_values[base + 1], plan.candidate_values[base + 2],
					plan.candidate_values[base + 3], plan.candidate_values[base + 4],
					plan.candidate_values[base + 5], plan.candidate_values[base + 6]
			end

			-- P8 (Round 49): the fill ores, one flat pass over the voxels the
			-- writer itself filled with stone (r49_fill_ore_host). The native
			-- rock they meet carries the native scatter rows (r7_native.lua), so
			-- every stone voxel takes its ores from exactly one source; an
			-- integer hash per voxel decides (r49_fill_ores_new). No exclusion
			-- under towns or deep water (mapgen plan ruling 5 and §4.1); no
			-- whole-chunk scan, no per-cell budget, no SHA.
			local r5_plan = plan.r5_plan
			fill_ore_chunk(min_x, min_y, min_z)
			for z = min_z, max_z do
				for x = min_x, max_x do
					local column = column_index(x, z)
					for run = r5_plan.column_start[column],
							r5_plan.column_start[column + 1] - 1 do
						local base = (run - 1) * RUN_STRIDE
						local opcode = r5_plan.run_values[base + 4]
						if opcode == 27 or opcode == 21 or opcode == 15 then
							for y = r5_plan.run_values[base + 1], r5_plan.run_values[base + 2] do
								local index = index_at(x, y, z)
								local resource_index = r49_fill_ore_host(original_data[index],
									final_data[index], intent_opcode[index], opcode, fill_stone_cid) and
									fill_ore_at(x, y, z)
								if resource_index then
									local resource = resources[resource_index]
									write_intent(x, y, z, resource.content_ref, 0, 24,
										stable_state.resource[resource_index], 0, 4, resource_index + 1)
								end
							end
						end
					end
				end
			end
			fill_ore_chunk(nil)

			-- P9 decorations, globally ordered by class, cell z/x and planned rank.
			-- `tree_roots`: the roots of the generated trees accepted in this owner
			-- (Round 47), kept TREE_SPACING apart.
			local tree_roots = {}
			for class = 1, 4 do
				for cell = 1, plan.candidate_cell_count do
					local cell_base = (cell - 1) * CELL_STRIDE
					for candidate = plan.candidate_cell_values[cell_base + 3],
							plan.candidate_cell_values[cell_base + 4] - 1 do
						local kind, catalog, parameter, root_x, root_y, root_z =
							candidate_fields(candidate)
						if kind == 2 and parameter == class and root_x >= min_x and
								root_x <= max_x and root_y >= min_y and root_y <= max_y and
								root_z >= min_z and root_z <= max_z then
							local row = decorations[catalog]
							local min_fx, max_fx, min_fy, max_fy, min_fz, max_fz = 0, 0, 0, 0, 0, 0
							local template_ref = 0
							local rotation, variant, template, height
							if row.generated_tree then
								-- A generated tree (Round 47): this world's variant by a
								-- hash of the root, turned like every template; its
								-- roots are optional runs (below, after acceptance).
								rotation = helpers.rotation_at(row.id, root_x, root_y, root_z)
								variant = helpers.r8_templates.variant_index(
									helpers.r8_full_seed, row.id, root_x, root_y, root_z)
								local bounds = helpers.r8_templates.generated_bounds(row.id,
									variant, rotation)
								template_ref = stable_state.decoration[catalog]
								min_fx, max_fx, min_fy, max_fy, min_fz, max_fz = bounds.min_x,
									bounds.max_x, bounds.min_y, bounds.max_y,
									bounds.min_z, bounds.max_z
							elseif row.kind == "template" then
								rotation = helpers.rotation_at(row.id, root_x, root_y, root_z)
								template = helpers.template_rotation(row.id, rotation)
								template_ref = stable_state.decoration[catalog]
								min_fx, max_fx, min_fy, max_fy, min_fz, max_fz = template.min_x,
									template.max_x, template.min_y, template.max_y,
									template.min_z, template.max_z
							else
								height = 1
								if row.settlement_class == 3 then
									height = helpers.simple_height_at(row.id, root_x, root_y,
										root_z)
								end
								max_fy = height - 1
							end
							-- The cheap rejections come first, from the bounds alone: a
							-- box the owner clips, a missing host, then an excluded,
							-- unloaded or (but for a generated tree, which claims only
							-- its own cells, below) occupied cell of the box. Every
							-- rejection is final and nothing is kept of a rejected
							-- candidate, so its cells are built only after these.
							local clipped = not inside_owner(root_x + min_fx, root_y + min_fy,
								root_z + min_fz) or not inside_owner(root_x + max_fx,
								root_y + max_fy, root_z + max_fz)
							local rejected = clipped
							if not rejected then
								local support = inside_owner(root_x, root_y - 1, root_z) and
									index_at(root_x, root_y - 1, root_z) or nil
								local support_ref = helpers.decoration_support_ref(row, root_x,
									root_y - 1, root_z)
								rejected = not support_ref or (support and
									(intent_opcode[support] < 1 or intent_opcode[support] > 4 or
										final_data[support] ~= contract.content_cids[support_ref])) or
									false
							end
							if not rejected then
								-- A generated tree's leaf (-4) counts against the box of
								-- every other decoration.
								local box_claims = not row.generated_tree
								local resource_last = #resources + 1
								for z = root_z + min_fz, root_z + max_fz do
									for x = root_x + min_fx, root_x + max_fx do
										if helpers.exclusion_reason(x, z, row.plant_purpose) then
											rejected = true
											break
										end
										for y = root_y + min_fy, root_y + max_fy do
											local index = index_at(x, y, z)
											local occupant = occupancy[index]
											if original_data[index] == contract.ignore_cid or
													(box_claims and (occupant == 1 or occupant == -1 or
														occupant == -4 or
														(occupant >= 2 and occupant <= resource_last))) then
												rejected = true
												break
											end
										end
										if rejected then break end
									end
									if rejected then break end
								end
							end
							local cells, root_runs
							if not rejected then
								if row.generated_tree then
									cells, root_runs = helpers.r8_templates.generated_cells(
										row.id, variant, rotation)
								elseif template then
									-- The probability trials of this root (r6_templates.lua).
									local trial = helpers.r8_templates.probability_trials(
										helpers.r8_full_seed, row.id, root_x, root_y, root_z)
									cells = {}
									local slice_destination_y = {}
									local destination_y = template.min_y
									for y = 1, template.size_y do
										if trial("slice", 0, y - 1, 0,
												template.y_slice_probabilities[y]) then
											slice_destination_y[y] = destination_y
											destination_y = destination_y + 1
										end
									end
									for z = 1, template.size_z do
										for y = 1, template.size_y do
											local placed_y = slice_destination_y[y]
											for x = 1, template.size_x do
												local source_index = (z - 1) * template.size_x *
													template.size_y + (y - 1) * template.size_x + x
												local node = template.cells[source_index]
												local included = placed_y ~= nil and node.name ~= "air" and
													trial("node", x - 1, y - 1, z - 1, node.probability)
												cells[#cells + 1] = {x = template.min_x + x - 1,
													y = placed_y or template.min_y,
													z = template.min_z + z - 1, include = included,
													content_ref = node.content_ref, param2 = node.param2,
													force_place = node.force_place}
											end
										end
									end
								else
									cells = {}
									for y = 0, height - 1 do
										cells[#cells + 1] = {x = 0, y = y, z = 0, include = true,
											content_ref = row.content_ref,
											param2 = row.rule == "param2_4" and 4 or 0,
											force_place = false}
									end
								end
							end
							-- GENERATED TREES INTERLEAVE (Round 47 groves follow-up): a
							-- tree reserves its wood cells (-1) and its leaf cells
							-- (-4), not its box. Wood never lands on wood, a reserved
							-- box, a settlement cell or an ore claim; a leaf there or
							-- on another tree's leaf is left out (the first leaf
							-- stays); wood may take another tree's leaf. Its root
							-- keeps TREE_SPACING (Chebyshev) from every generated tree
							-- this owner accepted, the one density parameter of the
							-- interleaved forest. The whole tree still lies inside the
							-- owner (not clipped, above), so a crown never meets one
							-- of another mapchunk and none is cut at a border.
							if row.generated_tree and not rejected then
								local spacing = row.generated_kit and 0 or helpers.tree_spacing
								for index = 1, #tree_roots do
									local other = tree_roots[index]
									if math.abs(other[1] - root_x) < spacing and
											math.abs(other[2] - root_z) < spacing then
										rejected = true
										break
									end
								end
								for part = 1, rejected and 0 or #cells do
									local cell_record = cells[part]
									local occupant = occupancy[index_at(root_x + cell_record.x,
										root_y + cell_record.y, root_z + cell_record.z)]
									if occupant ~= 0 and not (occupant == -4 and
											not cell_record.optional) then
										if not cell_record.optional then
											rejected = true
											break
										end
										cell_record.include = false
									end
								end
							end
							if not rejected then
								for part = 1, #cells do
									local cell_record = cells[part]
									if cell_record.include then
										local index = index_at(root_x + cell_record.x,
											root_y + cell_record.y, root_z + cell_record.z)
										local target_cid = contract.content_cids[cell_record.content_ref]
										local class_id = classify(final_data[index], final_param2[index])
										-- Every force-placed decoration cell (tree trunks and
										-- roots, bush stems, the papyrus dirt, the sunk roots of
										-- the emergent jungle tree) may replace the surface skin
										-- (opcodes 1-4) and, since Round 22 Phase 6, also the
										-- natural ground body below it: untouched native rock,
										-- ore or stratum, or the planned terrain fill (R5 27).
										-- That is Luanti's own force_place meaning.
										local opcode = intent_opcode[index]
										local ground_body = cell_record.force_place and
											opcode == 0 and helpers.ground_body_class(class_id) and
											(final_data[index] == original_data[index] or
												helpers.r5_opcode_at(plan, column_index(
													root_x + cell_record.x, root_z + cell_record.z),
													root_y + cell_record.y) == 27)
										if final_data[index] ~= target_cid and class_id ~= CLASS_AIR and
												class_id ~= CLASS_NATURAL_VEGETATION and not ground_body and
												not (cell_record.force_place and opcode >= 1 and
													opcode <= 4) then
											if cell_record.force_place or not (row.partial_leaves or
													cell_record.optional) then
												rejected = true
												break
											end
											-- a shrub's leaf, or a generated tree's leaf,
											-- against ground: skip the cell
											cell_record.include = false
										end
									end
								end
							end
							-- THE KIT'S RUNS (Round 51 lane LK, kit_templates.lua). A
							-- cell's column stands on kit ground right under the root's
							-- level (offset 0), one node higher (+1) or one lower (-1),
							-- with no ground at the level above that; a run takes the
							-- offset of its columns, which must agree, so a structure
							-- follows gentle ground column by column like the viewer's
							-- and a multi-column piece (a log, a doorway) lies level.
							-- Each cell, so moved, must be free (air or natural
							-- vegetation, no claim but a tree's leaf); a cell below the
							-- level (a sunken course, a crypt step) takes its column's
							-- own dry surface top (never a bed under water). A run with a parent only with its
							-- parent; a required run that cannot stand rejects the
							-- whole structure. Kept runs are written moved (below).
							local kit_kept
							if row.generated_kit and root_runs and not rejected then
								local kit_ground = helpers.kit_ground_cids
								local function offset(x, z)
									if not (inside_owner(x, root_y - 2, z) and inside_owner(x, root_y + 1, z)) then
										return nil
									end
									local ground = kit_ground[final_data[index_at(x, root_y - 1, z)]]
									local higher = kit_ground[final_data[index_at(x, root_y, z)]]
									if higher then
										if kit_ground[final_data[index_at(x, root_y + 1, z)]] then return nil end
										return 1
									elseif ground then
										return 0
									elseif kit_ground[final_data[index_at(x, root_y - 2, z)]] then
										return -1
									end
									return nil
								end
								kit_kept = {}
								for run_index = 1, #root_runs do
									local run = root_runs[run_index]
									local ok = run.parent == 0 or kit_kept[run.parent] == true
									local shift
									for part = 1, ok and #run or 0 do
										local cell_record = run[part]
										local x, z = root_x + cell_record.x, root_z + cell_record.z
										local o = offset(x, z)
										if o == nil or (shift ~= nil and o ~= shift) then ok = false break end
										shift = o
										local y = root_y + cell_record.y + o
										if not inside_owner(x, y, z) then ok = false break end
										local index = index_at(x, y, z)
										if cell_record.y < 0 then
											-- a dry surface top only (opcode 1 is the wet bed
											-- under water)
											if occupancy[index] ~= 0 or intent_opcode[index] < 2 or
													intent_opcode[index] > 4 then ok = false break end
										else
											local class_id = classify(final_data[index], final_param2[index])
											if not ((occupancy[index] == 0 or occupancy[index] == -4) and
													(class_id == CLASS_AIR or class_id == CLASS_NATURAL_VEGETATION)) then
												ok = false break
											end
										end
									end
									kit_kept[run_index] = ok
									if ok then
										for part = 1, #run do run[part].y = run[part].y + shift end
									elseif run.required then
										rejected = true
										break
									end
								end
							end
							local template_metrics
							if row.kind == "template" then
								template_metrics = helpers.template_metrics[row.id]
								if not template_metrics then
									template_metrics = {candidates = 0, clipped = 0, accepted = 0,
										root_runs = 0, root_runs_written = 0}
									helpers.template_metrics[row.id] = template_metrics
								end
								template_metrics.candidates = template_metrics.candidates + 1
								if clipped then
									template_metrics.clipped = template_metrics.clipped + 1
								end
								if not rejected then
									template_metrics.accepted = template_metrics.accepted + 1
								end
							end
							if not rejected then
								if row.generated_kit then
									-- a kit structure claims only its cells (written below)
								elseif row.generated_tree then
									tree_roots[#tree_roots + 1] = {root_x, root_z}
								else
									for z = root_z + min_fz, root_z + max_fz do
										for y = root_y + min_fy, root_y + max_fy do
											for x = root_x + min_fx, root_x + max_fx do
												occupancy[index_at(x, y, z)] = -1
											end
										end
									end
								end
								for part = 1, #cells do
									local cell_record = cells[part]
									if cell_record.include then
										-- a generated tree reserves its wood (-1) and its
										-- leaves (-4); every other template its box (above)
										write_intent(root_x + cell_record.x,
											root_y + cell_record.y, root_z + cell_record.z,
											cell_record.content_ref, cell_record.param2, 12,
											stable_state.decoration[catalog], template_ref, 8,
											cell_record.optional and -4 or -1)
									end
								end
								-- THE ROOTS (Round 47 lane TC, handoff §5): a run is
								-- written only if every cell of it has ground right
								-- under its column at the foot (y - 1) and none at the
								-- foot's level (the terrain neither falls away nor
								-- rises there), and the cell itself is free; a fork's
								-- toe only with its parent run. Every root cell lies
								-- inside the tree's bounds, so a run at a mapchunk
								-- border is complete or absent with its tree.
								if root_runs then
									local root_ground_cids = helpers.root_ground_cids
									local kept = kit_kept or helpers.r8_templates.kept_root_runs(root_runs,
										function(cell_record)
											local x, z = root_x + cell_record.x, root_z + cell_record.z
											local y = root_y + cell_record.y
											if not (inside_owner(x, root_y - 1, z) and
													inside_owner(x, root_y, z) and inside_owner(x, y, z)) or
													not root_ground_cids[final_data[index_at(x, root_y - 1, z)]] or
													root_ground_cids[final_data[index_at(x, root_y, z)]] then
												return false
											end
											local index = index_at(x, y, z)
											local class_id = classify(final_data[index], final_param2[index])
											return (occupancy[index] == 0 or occupancy[index] == -4) and
												(class_id == CLASS_AIR or class_id == CLASS_NATURAL_VEGETATION)
										end)
									for run_index = 1, #root_runs do
										local run = root_runs[run_index]
										template_metrics.root_runs = template_metrics.root_runs + 1
										if kept[run_index] then
											template_metrics.root_runs_written =
												template_metrics.root_runs_written + 1
											for part = 1, #run do
												local cell_record = run[part]
												write_intent(root_x + cell_record.x,
													root_y + cell_record.y, root_z + cell_record.z,
													cell_record.content_ref, cell_record.param2, 12,
													stable_state.decoration[catalog], template_ref, 8, -1)
											end
										end
									end
								end
							end
						end
					end
				end
			end

			-- R7's only legal successor hook. It receives a deliberately narrow
			-- closure surface over these private buffers, runs after the complete R6
			-- P9 loop and before the commit, and cannot call a VoxelManip setter.
			-- A missing tail preserves the accepted R6 path.
			if transaction_state.successor_tail then
				local successor_context = {
					schema = "grug_wp40_r7_successor_context_v1",
					plan = plan, generation = plan_generation, call_mode = call_mode,
					min_x = min_x, min_y = min_y, min_z = min_z,
					max_x = max_x, max_y = max_y, max_z = max_z,
				}
				function successor_context.inside_owner(x, y, z)
					return inside_owner(x, y, z)
				end
				function successor_context.original_at(x, y, z)
					local index = index_at(x, y, z)
					return original_data[index], original_param2[index]
				end
				function successor_context.settled_at(x, y, z)
					local index = index_at(x, y, z)
					return final_data[index], final_param2[index], occupancy[index],
						intent_opcode[index], intent_feature[index], intent_interface[index],
						intent_aux[index]
				end
				function successor_context.production_content(name)
					local ref = content.content_ref(name)
					return ref, ref and contract.content_cids[ref] or nil
				end
				function successor_context.analytic_p7_ref(x, y, z)
					return helpers.analytic_p7_material_ref(x, y, z)
				end
				function successor_context.analytic_p7_tuple(x, y, z)
					local ref = helpers.analytic_p7_material_ref(x, y, z)
					if not ref then return -1, -1, -3, -1, -1, -1, -1 end
					local _, _, _, biome, _, terrain_y, water_y =
						planner_source.column_values_at(x, z)
					local opcode
					if y < terrain_y then opcode = 2
					elseif water_y ~= nil and water_y > terrain_y then opcode = 1
					elseif biome == "grug_beach" then opcode = 3
					else opcode = 4 end
					return contract.content_cids[ref], 0, 0, opcode, 0, 0,
						(ref - 1) * 256
				end
				-- `y` (optional, ruling 30 addendum): the height a surface writer
				-- places at; below the column's protected-only floor the claim
				-- exclusion does not apply. `dry_island_open`: P9G's view of the
				-- dragon islands' coast envelopes (nonblocking on dry land).
				-- `purpose`: nil (the territory rule) or "gathering" (see
				-- `exclusion_reason`).
				function successor_context.exclusion_at(x, z, y, dry_island_open,
						purpose)
					local reason, id = helpers.exclusion_reason(x, z, purpose)
					if y ~= nil and reason == "fixed_or_protected" and
							y < (dry_island_open and
								(planner_source.protected_only_floor_at(x, z, true) or
									-math.huge) or protected_only_floor(x, z)) then
						return nil
					end
					return reason, id
				end
				function successor_context.column_values_at(x, z)
					return planner_source.column_values_at(x, z)
				end
				-- 39: P9G_COUNT (a literal here: this function is at Lua's limit of
				-- 60 upvalues)
				function successor_context.write_p9g(x, y, z, cid, param2,
						local_ref, feature_ref)
					if not inside_owner(x, y, z) then
						fail("fail_settlement", ("P9G write escaped central owner " ..
							"at (%s,%s,%s)"):format(tostring(x), tostring(y), tostring(z)))
					end
					integer(cid, "P9G CID", 0, MAX_SAFE, "fail_content_manifest")
					integer(param2, "P9G param2", 0, 255, "fail_content_manifest")
					integer(local_ref, "P9G local ref", 1, 39, "fail_content_manifest")
					integer(feature_ref, "P9G feature ref", 1, 39, "fail_content_manifest")
					if cid == contract.ignore_cid then
						fail("fail_content_manifest", ("P9G target is ignore " ..
							"at (%d,%d,%d)"):format(x, y, z))
					end
					local index = index_at(x, y, z)
					final_data[index], final_param2[index] = cid, param2
					intent_opcode[index], intent_feature[index], intent_interface[index] =
						35, feature_ref, 0
					local successor_ref = #contract.content_names + local_ref
					intent_aux[index] = (successor_ref - 1) * 256 + param2
					occupancy[index] = -2
				end
				function successor_context.write_anchor(x, y, z, cid, param2,
						local_ref, feature_ref)
					if not inside_owner(x, y, z) then
						fail("fail_settlement", ("anchor write escaped central owner " ..
							"at (%s,%s,%s)"):format(tostring(x), tostring(y), tostring(z)))
					end
					integer(cid, "anchor CID", 0, MAX_SAFE, "fail_content_manifest")
					integer(param2, "anchor param2", 0, 255, "fail_content_manifest")
					integer(local_ref, "anchor local ref", 1, 2, "fail_content_manifest")
					integer(feature_ref, "anchor feature ref", 7, 60, "fail_content_manifest")
					if cid == contract.ignore_cid then
						fail("fail_content_manifest", ("anchor target is ignore " ..
							"at (%d,%d,%d)"):format(x, y, z))
					end
					local index = index_at(x, y, z)
					final_data[index], final_param2[index] = cid, param2
					intent_opcode[index], intent_feature[index], intent_interface[index] =
						36, feature_ref, 0
					local successor_ref = #contract.content_names + 39 + local_ref
					intent_aux[index] = (successor_ref - 1) * 256 + param2
					occupancy[index] = -2
				end
				-- Round 22 Phase 4: the road dressing (`road_writer.lua`) reads a
				-- column's road record and writes plain nodes; everything
				-- settled later (P9G, anchors, settlements) may overwrite them.
				function successor_context.road_column_at(x, z)
					return planner_source.road_column_at(x, z)
				end
				function successor_context.write_road(x, y, z, cid, param2)
					if not inside_owner(x, y, z) then
						fail("fail_settlement", ("road write escaped central owner " ..
							"at (%s,%s,%s)"):format(tostring(x), tostring(y), tostring(z)))
					end
					integer(cid, "road CID", 0, MAX_SAFE, "fail_content_manifest")
					integer(param2, "road param2", 0, 255, "fail_content_manifest")
					if cid == contract.ignore_cid then
						fail("fail_content_manifest", ("road target is ignore " ..
							"at (%d,%d,%d)"):format(x, y, z))
					end
					local index = index_at(x, y, z)
					final_data[index], final_param2[index] = cid, param2
					intent_opcode[index], intent_feature[index], intent_interface[index] =
						38, 0, 0
					intent_aux[index] = 0
					occupancy[index] = 0
				end
				function successor_context.write_hearthpine(x, y, z, cid, param2,
						local_ref, feature_ref)
					if not inside_owner(x, y, z) then
						fail("fail_settlement", ("Hearthpine write escaped central owner " ..
							"at (%s,%s,%s)"):format(tostring(x), tostring(y), tostring(z)))
					end
					integer(cid, "Hearthpine CID", 0, MAX_SAFE, "fail_content_manifest")
					integer(param2, "Hearthpine param2", 0, 255,
						"fail_content_manifest")
					integer(local_ref, "Hearthpine local ref", 1, MAX_SAFE,
						"fail_content_manifest")
					if feature_ref ~= 1 or cid == contract.ignore_cid then
						fail("fail_content_manifest", "Hearthpine identity differs")
					end
					local index = index_at(x, y, z)
					if original_data[index] == contract.ignore_cid then
						fail("fail_content_ignore", ("Hearthpine owner is ignore " ..
							"at (%d,%d,%d) cid=%d"):format(x, y, z, original_data[index]))
					end
					final_data[index], final_param2[index] = cid, param2
					intent_opcode[index], intent_feature[index], intent_interface[index] =
						37, feature_ref, 0
					local successor_ref = #contract.content_names + 39 + 2 + local_ref
					intent_aux[index] = (successor_ref - 1) * 256 + param2
					occupancy[index] = -2
				end
				local successor_ledger = transaction_state.successor_tail:settle(successor_context)
				if type(successor_ledger) ~= "table" or
						successor_ledger.schema ~= "grug_wp40_r7_successor_ledger_v1" then
					fail("fail_ledger", "R7 successor ledger differs")
				end
			end

			-- What the VM needs after the writes: per changed owner voxel, whether
			-- its light properties or its liquid state changed (or, for a node
			-- that turned floodable or no longer is, whether it borders liquid or
			-- the owner's edge). Both answers are functions of the old and the
			-- new content id alone (the class row of r7_content.lua; a liquid's
			-- level matters only for a liquid, whose family is never 0), so they
			-- are kept per id pair, and the scan stops asking once both hold.
			local content_changed, param2_changed, light_changed, liquid_changed =
				false, false, false, false
			local modified, content_columns, param2_columns = 0, 0, 0
			local scan_pairs, scan_liquid = transaction_state.scan_pairs,
				transaction_state.scan_liquid
			for z = min_z, max_z do
				for x = min_x, max_x do
					local column_content, column_param2 = false, false
					for y = min_y, max_y do
						local index = index_at(x, y, z)
						local old_cid, new_cid = original_data[index], final_data[index]
						local changed_content = new_cid ~= old_cid
						local changed_param2 = final_param2[index] ~= original_param2[index]
						if changed_content or changed_param2 then
							modified = modified + 1
							content_changed = content_changed or changed_content
							param2_changed = param2_changed or changed_param2
							column_content = column_content or changed_content
							column_param2 = column_param2 or changed_param2
							if not (light_changed and liquid_changed) then
								local by_new = scan_pairs[old_cid]
								if not by_new then
									by_new = {}
									scan_pairs[old_cid] = by_new
								end
								-- 1: the light changes, 2: the liquid changes, 4: the
								-- floodability changes
								local code = by_new[new_cid]
								if code == nil then
									local _, old_family, old_liquid, old_level, old_flood,
										old_light, old_propagates, old_sun, old_source =
										classify(old_cid, original_param2[index])
									local _, new_family, new_liquid, new_level, new_flood,
										new_light, new_propagates, new_sun, new_source =
										classify(new_cid, final_param2[index])
									code = ((changed_content and
										(old_light ~= new_light or old_propagates ~= new_propagates or
											old_sun ~= new_sun or old_source ~= new_source)) and 1 or 0) +
										((old_family > 0 or new_family > 0 or
											old_liquid ~= new_liquid or old_family ~= new_family or
											old_level ~= new_level) and 2 or 0) +
										(old_flood ~= new_flood and 4 or 0)
									by_new[new_cid] = code
								end
								if code % 2 == 1 then light_changed = true end
								if not liquid_changed then
									local voxel_liquid = code % 4 >= 2
									if not voxel_liquid and code >= 4 then
										for face = 1, 6 do
											local nx, ny, nz = x + FACE_X[face], y + FACE_Y[face],
												z + FACE_Z[face]
											if nx < min_x or nx > max_x or ny < min_y or ny > max_y or
													nz < min_z or nz > max_z then
												voxel_liquid = true
											else
												local neighbor = index_at(nx, ny, nz)
												local cid = final_data[neighbor]
												if cid == original_data[neighbor] and
														final_param2[neighbor] == original_param2[neighbor] then
													local liquid = scan_liquid[cid]
													if liquid == nil then
														local _, family, kind = classify(cid, final_param2[neighbor])
														liquid = (family == contract.ordinary_water_family_id or
															family == contract.river_water_family_id) and
															(kind == 1 or kind == 2)
														scan_liquid[cid] = liquid
													end
													if liquid then voxel_liquid = true end
												end
											end
											if voxel_liquid then break end
										end
									end
									if voxel_liquid then liquid_changed = true end
								end
							end
						end
					end
					if column_content then content_columns = content_columns + 1 end
					if column_param2 then param2_columns = param2_columns + 1 end
				end
			end
			metrics_state.modified_voxels = metrics_state.modified_voxels + modified
			metrics_state.content_dirty_columns = metrics_state.content_dirty_columns +
				content_columns
			metrics_state.param2_dirty_columns = metrics_state.param2_dirty_columns +
				param2_columns
			if not content_changed and not param2_changed then return "noop_equal_content" end

			-- One light read for the relight (halo.relight) before any setter.
			if light_changed then
				local ok, returned = pcall(vm.get_light_data, vm, original_light)
				if not ok or not rawequal(returned, original_light) then
					fail("fail_vm_contract", "get_light_data did not reuse buffer")
				end
			end

			transaction_state.written_vm = vm
			if content_changed then
				local ok = pcall(vm.set_data, vm, final_data)
				if not ok then fail("fail_vm_contract", "set_data failed") end
			end
			if param2_changed then
				local ok = pcall(vm.set_param2_data, vm, final_param2)
				if not ok then fail("fail_vm_contract", "set_param2_data failed") end
			end
			if light_changed then
				local a = halo.args
				a.data, a.param2, a.light, a.ignore_cid = final_data, final_param2,
					original_light, contract.ignore_cid
				a.eminx, a.eminy, a.eminz, a.emaxx, a.emaxy, a.emaxz =
					eminx, eminy, eminz, emaxx, emaxy, emaxz
				a.min_x, a.min_y, a.min_z, a.max_x, a.max_y, a.max_z =
					min_x, min_y, min_z, max_x, max_y, max_z
				halo.vm = vm
				transaction_state.written_light = true
				halo.relight(a)
			end
			if liquid_changed then
				local ok = pcall(vm.update_liquids, vm)
				if not ok then fail("fail_vm_contract", "update_liquids failed") end
			end
			metrics_state.apply_calls = metrics_state.apply_calls + 1
			local c, p, l, q = content_changed, param2_changed, light_changed,
				liquid_changed
			if not c then return q and "applied_pq" or "applied_p" end
			if p then
				if l then return q and "applied_cplq" or "applied_cpl" end
				return q and "applied_cpq" or "applied_cp"
			end
			if l then return q and "applied_clq" or "applied_cl" end
			return q and "applied_cq" or "applied_c"
		end

		local settlement = {}
		function settlement.apply(self, vm, minp, maxp, plan, generation, call_mode)
			if not rawequal(self, settlement) then
				fail("fail_status", "settlement receiver differs")
			end
			allocator:enter_hotpath("r6_settlement_apply")
			local ok, result = xpcall(function()
				return apply_impl(vm, minp, maxp, plan, generation, call_mode)
			end, with_traceback)
			allocator:leave_hotpath("r6_settlement_apply")
			local written = transaction_state.written_vm
			if not ok and written then
				-- A failure after the first VoxelManip setter (an engine call that
				-- failed) restores the engine's own content, param2 and light, so
				-- the chunk keeps engine terrain (Round 41 ruling 8; the emerge
				-- wrapper in r7_mapgen.lua reports it and goes on).
				pcall(written.set_data, written, original_data)
				pcall(written.set_param2_data, written, original_param2)
				if transaction_state.written_light then
					pcall(written.set_light_data, written, original_light)
				end
			end
			transaction_state.written_vm, transaction_state.written_light = false, false
			if not ok then error(result, 0) end
			return result
		end
		function settlement.metrics(self)
			if not rawequal(self, settlement) then
				fail("fail_status", "settlement receiver differs")
			end
			local result = copy_map(metrics_state)
			local allocation = allocator:metrics()
			result.retained_buffer_growth_events = allocation.hotpath_table_allocations
			result.allocator_sealed = allocation.construction_sealed
			return result
		end
		allocator:seal_construction()
		return settlement
	end

	return {new_runtime = new,
		r8_strata_new = new_r8_strata, r8_apply_strata = r8_apply_strata,
		r24_fill_stone = r24_fill_stone,
		r49_fill_ore_host = r49_fill_ore_host, r49_fill_ores_new = r49_fill_ores_new,
		r30_cave_limit = r30_cave_limit,
		r24_fill_layers_new = new_r24_fill_layers,
		r24_apply_fill_layers = r24_apply_fill_layers,
		r24_layer_first_depth = R24_LAYER_FIRST_DEPTH}
end

return settlement_factory()

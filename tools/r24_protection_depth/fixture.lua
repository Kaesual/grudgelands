-- Round 24 Lane G portable fixture (LuaJIT): protection depth (ruling 30).
--
--   luajit tools/r24_protection_depth/fixture.lua "$PWD" [seed ...]
--
-- Builds the real zones.lua / simple_map.lua / height.lua world of each seed
-- (no roads; the capitals' protected cities are stood in by a 241-node square
-- round each capital anchor, since only the vertical rule is under test here)
-- plus the R7 anchor roster and functional-anchor overlay, then checks:
--   1. every hard footprint type -- start town (centre and band), capital,
--      apex socket column, outpost column, bandit column -- is protected at
--      its bound (placement height - 100) and at bound + 1, and not at
--      bound - 1, through territory_rule_at, hard_protection_kind_at and
--      world_protected_for_faction for both factions; protection stays
--      unbounded upward; below the bound the zone's own territory rule
--      answers, and the contested deep still starts at y = -701;
--   2. the capital guard level is 60 inside the capital's volume only;
--   3. mapgen: the protected floor planner_source.protection_floor_y hands
--      the P8 resource pass for every anchor envelope and apex socket core,
--      and the P8 column predicate r30_resource_column_open (production
--      code of r6_settlement.lua) above, at and below that floor.
-- Prints the bound table and "R24 PROTECTION DEPTH FIXTURE PASS checks=<n>",
-- or raises on the first failure. The engine counterpart (ores and digging
-- at the floor under the Orc start) is `run.sh OUT_DIR [TIMEOUT]`; its
-- output and this fixture's are kept in `evidence/`.
local repo = assert(arg[1], "usage: fixture.lua <repo> [seed ...]")
local seeds = {}
for index = 2, #arg do seeds[#seeds + 1] = arg[index] end
if #seeds == 0 then seeds = {"4242424242", "10536739806879207652"} end

local DEPTH = 100
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local settlement = dofile(dir .. "/r6_settlement.lua")

-- ---------------------------------------------------------------------------
-- World (as tools/r23_tree_line/world_source.lua, with stand-in capital cities)
-- ---------------------------------------------------------------------------
local CITY_HALF = 120
local function build_world(seed)
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
	local function horizontal_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.capital_protection = protection_holder
		return simple_map_factory(bound)
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
	local roster = dofile(dir .. "/r7_anchor_roster.lua")(source, session,
		planner_source, sha)
	local overlay = dofile(dir .. "/r7_zone_overlay.lua")(session, roster)
	return {session = session, overlay = overlay, planner_source = planner_source,
		source = source, roster = roster}
end

-- ---------------------------------------------------------------------------
-- 1. Runtime authority at bound - 1, bound, bound + 1
-- ---------------------------------------------------------------------------
local function placement_y(planner_source, x, z)
	-- height.lua's placement height: the final functional surface of the
	-- centre column, else its terrain.
	local _, _, _, _, _, terrain_y, _, _, _, _, functional_y =
		planner_source.column_values_at(x, z)
	return functional_y or terrain_y
end

local function zone_rule(Z, x, z)
	local zone = Z.get(Z.id_at(x, z))
	return zone and zone.territory_rule
end

local function check_volume(W, label, x, z, bound, kind)
	local Z = W.overlay
	local compat = Z.compatibility
	for _, y in ipairs({bound, bound + 1, bound + DEPTH, 30000}) do
		local pos = {x = x, y = y, z = z}
		check(Z.territory_rule_at(pos) == "hard_protected",
			label .. " protected at y=" .. y)
		check(Z.hard_protection_kind_at(pos) == kind,
			label .. " kind " .. kind .. " at y=" .. y)
		check(compat.world_protected_for_faction(pos, "accord") and
			compat.world_protected_for_faction(pos, "throng"),
			label .. " closed to both factions at y=" .. y)
	end
	local below = {x = x, y = bound - 1, z = z}
	local rule = Z.territory_rule_at(below)
	check(rule ~= "hard_protected", label .. " not protected at bound-1 (" ..
		tostring(rule) .. ")")
	check(Z.hard_protection_kind_at(below) == nil, label .. " no kind at bound-1")
	-- Below the bound the ordinary rules answer: the zone's own territory rule
	-- down to -700, the contested deep from -701.
	if bound - 1 >= -700 then
		local expected = zone_rule(Z, x, z)
		if Z.water_class_at(x, z) == "deep_ocean" then expected = "immutable" end
		check(rule == expected, label .. " zone rule below the bound: " ..
			tostring(rule) .. " vs " .. tostring(expected))
		if rule == "contested_land" then
			check(not compat.world_protected_for_faction(below, "accord") and
				not compat.world_protected_for_faction(below, "throng"),
				label .. " contested ground below the bound is open")
		elseif rule == "accord_home" or rule == "throng_home" then
			local home = rule == "accord_home" and "accord" or "throng"
			local other = home == "accord" and "throng" or "accord"
			check(not compat.world_protected_for_faction(below, home),
				label .. " open to the home faction below the bound")
			check(compat.world_protected_for_faction(below, other),
				label .. " closed to the other faction below the bound")
		end
	end
	local deep = {x = x, y = -701, z = z}
	check(Z.territory_rule_at(deep) == "contested_land",
		label .. " contested deep at -701")
end

local lines = {}
local function row(kind, id, x, z, placement, bound)
	lines[#lines + 1] = ("%-8s %-22s x=%6d z=%6d placement=%4d bound=%4d"):format(
		kind, id, x, z, placement, bound)
end

local function runtime_checks(W)
	local S, P, source = W.session, W.planner_source, W.source
	local Zs = {}
	for index = 1, #source.zones do Zs[index] = source.zones[index] end
	-- Start towns and capitals (anchors 1-12).
	for index = 1, 12 do
		local a = source.anchors[index]
		local zone = Zs[a.zone_numeric_id]
		local record = S.anchor(zone.id, a.slot_id)
		local placement = placement_y(P, a.position.x, a.position.z)
		check(placement == record.y, a.id .. " placement is the anchor surface")
		local bound = placement - DEPTH
		check(S.protection_floor_y(placement) == bound, a.id .. " session floor")
		local kind = "town"
		check_volume(W, a.id .. " " .. a.slot_id, a.position.x, a.position.z, bound, kind)
		row(a.slot_id, a.id, a.position.x, a.position.z, placement, bound)
		-- The whole footprint's ground lies inside the volume: the lowest
		-- terrain of the reserved square (532 capital, 152 start; every 4th
		-- column) stays above the bound.
		local half = a.slot_id == "capital" and 266 or 76
		local lowest = math.huge
		for dx = -half, half, 4 do
			for dz = -half, half, 4 do
				local h = S.terrain_height_at(a.position.x + dx, a.position.z + dz)
				if h < lowest then lowest = h end
			end
		end
		check(lowest > bound, a.id .. " ground above the bound")
		lines[#lines] = lines[#lines] .. (" lowest ground %d (margin %d)"):format(
			lowest, lowest - bound)
		if a.slot_id == "start" then
			-- a band column (pad -64..+63, band 12): the town's own bound
			check_volume(W, a.id .. " band", a.position.x + 70, a.position.z, bound, kind)
			check(S.territory_rule_at({x = a.position.x + 80, y = placement,
				z = a.position.z}) ~= "hard_protected", a.id .. " outside the band")
		else
			-- 2. guard level: 60 inside the capital's volume only
			local at = {x = a.position.x, y = bound, z = a.position.z}
			local under = {x = a.position.x, y = bound - 1, z = a.position.z}
			check(S.guard_level_at(at) == 60, a.id .. " guard level 60 at the bound")
			local surface = S.surface_mob_level_at(a.position.x, a.position.z)
			local generic = math.min(70, math.max(20, surface))
			check(S.guard_level_at(under) == generic, a.id ..
				" generic guard level below the bound")
		end
	end
	-- Apex socket columns: the socket column's own surface.
	local anchor_by_id = {}
	for _, a in ipairs(source.anchors) do anchor_by_id[a.id] = a end
	for _, socket in ipairs(source.apex_sockets) do
		local a = anchor_by_id[socket.anchor_id]
		local x, z = a.position.x + socket.offset.x, a.position.z + socket.offset.z
		local placement = placement_y(P, x, z)
		local bound = placement - DEPTH
		check_volume(W, socket.id, x, z, bound, "landmark")
		row("socket", socket.id, x, z, placement, bound)
		-- 3. its P8 floor: its own bound, or lower where its apex mine's
		-- envelope holds the column with a lower floor (lowest floor wins;
		-- exact values in the overlap check below)
		check(P.protection_floor_y("exclude:active:hard:" .. socket.id, x, z) <= bound,
			socket.id .. " P8 floor")
	end
	-- Outpost and bandit functional columns: the roster's anchor y.
	for _, r in ipairs(W.roster.rows) do
		if r.family == "outpost" or r.family == "bandit" then
			check(r.y == placement_y(P, r.x, r.z), r.id .. " roster y is the surface")
			local bound = r.y - DEPTH
			check_volume(W, r.id .. " " .. r.family, r.x, r.z, bound, "landmark")
			row(r.family, r.id, r.x, r.z, r.y, bound)
		end
	end
end

-- ---------------------------------------------------------------------------
-- 3. Mapgen: the P8 floor of every anchor envelope, and the column predicate
-- ---------------------------------------------------------------------------
local function mapgen_checks(W)
	local S, P, source = W.session, W.planner_source, W.source
	local anchor_by_id = {}
	for _, a in ipairs(source.anchors) do anchor_by_id[a.id] = a end
	local envelopes = 0
	for _, exclusion in ipairs(source.claim_exclusions) do
		if exclusion.recipe_id == "exclude_anchor_blend_v1" then
			local a = anchor_by_id[exclusion.source_id]
			local record = S.anchor(source.zones[a.zone_numeric_id].id, a.slot_id)
			local floor = P.protection_floor_y(exclusion.id, a.position.x, a.position.z)
			-- at most the anchor's own floor: an overlapping envelope may hold
			-- the centre with a lower one (exact values below)
			check(floor <= record.y - DEPTH, exclusion.id .. " P8 floor " .. floor ..
				" vs anchor y " .. record.y)
			envelopes = envelopes + 1
		end
	end
	check(envelopes == #source.anchors, "every anchor has an envelope floor")
	-- Overlapping square envelopes (POIs, villages, camps, outposts, apex
	-- mines) and apex socket cores: every column of every overlap takes the
	-- LOWEST floor of all shapes holding it, not the floor of the one shape
	-- static_exclusion_values_at answers first.
	local squares = {}
	local hard_by_id = {}
	for _, hard in ipairs(source.hard_protection) do hard_by_id[hard.id] = hard end
	for _, exclusion in ipairs(source.claim_exclusions) do
		if exclusion.recipe_id == "exclude_anchor_blend_v1" then
			local a = anchor_by_id[exclusion.source_id]
			if a.slot_id ~= "capital" and a.slot_id ~= "start" then
				local record = S.anchor(source.zones[a.zone_numeric_id].id, a.slot_id)
				squares[#squares + 1] = {id = exclusion.id, center = exclusion.center,
					width = exclusion.total_width, floor = record.y - DEPTH}
			end
		elseif exclusion.recipe_id == "exclude_active_core_v1" then
			local hard = hard_by_id[exclusion.source_id]
			if hard.recipe_id == "hard_apex_socket_column_v1" then
				squares[#squares + 1] = {id = exclusion.id, center = hard.center,
					width = 1, floor = placement_y(P, hard.center.x, hard.center.z) - DEPTH}
			end
		end
	end
	local function holds(sq, x, z)
		local x2, z2 = 2 * x, 2 * z
		return x2 >= 2 * sq.center.x - sq.width and x2 < 2 * sq.center.x + sq.width and
			z2 >= 2 * sq.center.z - sq.width and z2 < 2 * sq.center.z + sq.width
	end
	local floor_by_id = {}
	for _, sq in ipairs(squares) do floor_by_id[sq.id] = sq.floor end
	-- exact at every square's centre
	for _, sq in ipairs(squares) do
		local x, z = sq.center.x, sq.center.z
		local expected
		for _, other in ipairs(squares) do
			if holds(other, x, z) and (expected == nil or other.floor < expected) then
				expected = other.floor
			end
		end
		check(P.protection_floor_y(sq.id, x, z) == expected, sq.id .. " centre floor")
	end
	local pairs_found, overlap_columns, first_would_differ = {}, 0, 0
	for i = 1, #squares do
		for j = i + 1, #squares do
			local a, b = squares[i], squares[j]
			local min_x = math.max(a.center.x - a.width, b.center.x - b.width)
			local max_x = math.min(a.center.x + a.width, b.center.x + b.width)
			local min_z = math.max(a.center.z - a.width, b.center.z - b.width)
			local max_z = math.min(a.center.z + a.width, b.center.z + b.width)
			local columns = 0
			for x = min_x, max_x do
				for z = min_z, max_z do
					if holds(a, x, z) and holds(b, x, z) then
						local expected
						for _, sq in ipairs(squares) do
							if holds(sq, x, z) and (expected == nil or sq.floor < expected) then
								expected = sq.floor
							end
						end
						local _, first = P.static_exclusion_values_at(x, z)
						local floor = P.protection_floor_y(first, x, z)
						check(floor == expected, ("overlap %s/%s at %d,%d: floor %d vs %d"):format(
							a.id, b.id, x, z, floor, expected))
						if floor_by_id[first] and floor_by_id[first] ~= expected then
							first_would_differ = first_would_differ + 1
						end
						columns = columns + 1
					end
				end
			end
			if columns > 0 and a.width > 1 and b.width > 1 then
				pairs_found[#pairs_found + 1] = ("%s/%s %d"):format(
					a.id:match("anchor_%d+"), b.id:match("anchor_%d+"), columns)
			end
			overlap_columns = overlap_columns + columns
		end
	end
	check(#pairs_found > 0, "overlapping envelope pairs exist")
	lines[#lines + 1] = ("envelope overlaps: %s; %d columns, %d where the first" ..
		" shape's floor is not the lowest"):format(table.concat(pairs_found, ", "),
		overlap_columns, first_would_differ)
	-- The Orc start (Sunscar): the column's own static exclusion id.
	local orc = source.anchors[5]
	check(orc.position.x == 0 and orc.position.z == 2550, "anchor_005 is the Orc start")
	local _, id = P.static_exclusion_values_at(0, 2550)
	local orc_y = placement_y(P, 0, 2550)
	local orc_floor = P.protection_floor_y(id, 0, 2550)
	check(orc_floor == orc_y - DEPTH, "Orc start P8 floor")
	-- Ruling 30 addendum: the cave-content rule's view of the same column.
	-- Its "cave" shape is a protected one (not route/water), and its floor is
	-- the town's, so cave content places at y < floor and not above.
	local _, cave_id = P.static_exclusion_values_at(0, 2550, "cave")
	check(type(cave_id) == "string" and (cave_id:sub(1, 15) == "exclude:anchor:" or
		cave_id:sub(1, 15) == "exclude:active:"), "Orc start cave shape is protected")
	check(P.protected_floor_at(0, 2550) == orc_floor, "Orc start cave floor")
	check(settlement.r30_cave_below_protection(false,
		P.protected_floor_at(0, 2550), orc_floor - 1), "Orc start cave content below")
	check(not settlement.r30_cave_below_protection(false,
		P.protected_floor_at(0, 2550), orc_floor), "Orc start no cave content at floor")
	-- every anchor centre: the non-failing floor equals the P8 floor
	for _, a in ipairs(source.anchors) do
		local _, id_at = P.static_exclusion_values_at(a.position.x, a.position.z)
		check(P.protected_floor_at(a.position.x, a.position.z) ==
			P.protection_floor_y(id_at, a.position.x, a.position.z),
			a.id .. " protected_floor_at")
	end
	lines[#lines + 1] = ("Orc start (0,%d,2550): exclusion %s, P8 floor %d"):format(
		orc_y, id, orc_floor)
end

local open = settlement.r30_resource_column_open
check(type(open) == "function", "r6_settlement exports r30_resource_column_open")
do
	local floor = -63
	-- bit 1: resource allowed on the column; bit 2: protected column
	for _, y in ipairs({-700, -64, -63, -62, 37, 500}) do
		check(open(1, 0, y) == true, "allowed ordinary column open at y=" .. y)
		check(open(0, 0, y) == false, "disallowed column closed at y=" .. y)
		check(open(2, floor, y) == false, "disallowed protected column closed at y=" .. y)
	end
	check(open(3, floor, floor - 1) == true, "protected column open at bound-1")
	check(open(3, floor, floor) == false, "protected column closed at the bound")
	check(open(3, floor, floor + 1) == false, "protected column closed at bound+1")
	check(open(3, floor, -700) == true, "protected column open at -700")
	check(open(3, floor, -701) == true, "protected column open at -701")
end

-- ---------------------------------------------------------------------------
-- 4. Ruling 30 addendum: cave content below the protected floor
-- ---------------------------------------------------------------------------
local cave_open = settlement.r30_cave_below_protection
check(type(cave_open) == "function", "r6_settlement exports r30_cave_below_protection")
do
	local floor = -63
	check(cave_open(false, floor, floor - 1) == true, "cave content at bound-1")
	check(cave_open(false, floor, floor) == false, "no cave content at the bound")
	check(cave_open(false, floor, floor + 1) == false, "no cave content at bound+1")
	check(cave_open(false, floor, -600) == true, "cave content deep under a town")
	check(cave_open(true, floor, floor - 1) == false,
		"route/water/housing keep the exclusion below the floor")
	check(cave_open(false, nil, -600) == false,
		"no protected shape: the exclusion stays (no floor)")
end

-- The runtime renewal mirror (vegetation_density.lua) on one synthetic
-- column: a town's cave-excluded column, floor -200, a cave_cap host.
do
	local habitat = dofile(dir .. "/habitat_registry.lua")
	local world_catalog = dofile(dir .. "/world_content_catalog.lua")
	local function density_for(cave_id, floor_fn)
		return dofile(dir .. "/vegetation_density.lua")({
			habitat = habitat, world_plants = world_catalog.plants, p9g_rows = {},
			decorations = {}, template_records = {}, support_names = {},
			vegetation_rule = habitat.vegetation_rule("1041",
				function() return "elandor_dawnmere_fields" end),
			decoration_cover = function() return 1 end,
			column_values_at = function()
				return "land", 2, "elandor_dawnmere_fields", "grug_meadows", "human", 40
			end,
			overlay_exclusion_at = function() return nil end,
			surface_mob_level_at = function() return 5 end,
			primary_relief_at = function() return "rolling_hills" end,
			static_exclusion_values_at = function(_, _, purpose)
				if purpose == "cave" then return 1, cave_id end
				return 1, cave_id
			end,
			surface_cave_run_at = function() return nil end,
			protected_floor_at = floor_fn,
		})
	end
	local function has_cave_cap(density, y, support)
		local categories = density.categories(0, y, 0, support, 0)
		if not categories then return false end
		for _, category in ipairs(categories) do
			if category.key == "cave_cap" then return true end
		end
		return false
	end
	local floor = function() return -200 end
	local town = density_for("exclude:anchor:anchor_005:01", floor)
	check(has_cave_cap(town, -250, "grug_materials:t3_stone"),
		"renewal: cave_cap below a town's floor")
	check(not has_cave_cap(town, -200, "grug_materials:t2_stone"),
		"renewal: no cave_cap at the floor")
	check(not has_cave_cap(town, -150, "grug_materials:t2_stone"),
		"renewal: no cave_cap above the floor")
	check(not has_cave_cap(density_for("exclude:coast:island_stormscale", floor),
		-250, "grug_materials:t3_stone"), "renewal: coast keeps its exclusion")
	check(not has_cave_cap(density_for("exclude:anchor:anchor_005:01", nil),
		-250, "grug_materials:t3_stone"), "renewal: no floor source, excluded")
end

for _, seed in ipairs(seeds) do
	local started = os.clock()
	local W = build_world(seed)
	lines[#lines + 1] = ("seed %s (built in %.1f s)"):format(seed, os.clock() - started)
	check(W.overlay.r7_functional_anchor_overlay.schema ==
		"grug_wp40_r7_functional_anchor_protection_v2", "overlay schema v2")
	runtime_checks(W)
	mapgen_checks(W)
end
print(table.concat(lines, "\n"))
print(("R24 PROTECTION DEPTH FIXTURE PASS checks=%d"):format(checks))

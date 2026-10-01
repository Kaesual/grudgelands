-- Round 24 Lane F portable fixture (LuaJIT): ruling 27 (per-zone density
-- budget) and ruling 28 (gathering XP) without an engine.
--
--   luajit tools/r24_density_xp/fixture.lua "$PWD"
--
-- 1. Loads the real spawn roster (roster.lua: spawn_policy.lua, density.lua
--    and every mob file init.lua loads) and checks the row preparation:
--    budgeted surface rows get 1.5x attempt frequency and the lifted cap,
--    every other row keeps the Round 16 rule.
-- 2. Prints, per named zone and clock, the budgeted cast, the pre-Round-24
--    per-area sum of caps (the old density) and the new budget, and checks
--    the reference medians, the shares and the single-species case.
-- 3. Drives grug_mobs.density_allows against a stub object list: total
--    budget, per-point shares with level-gated species, excluded rares/camps.
-- 4. Gathering XP (grug_xp.gather_xp, Round 28 ruling 32 ratios): the table
--    at several player levels, ore/gem tiers and fishing bands, and its
--    rounding.
-- The tool-level gate matrix (ruling 29) is tool_gate_fixture.lua.
-- Prints "R24 DENSITY/XP FIXTURE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit fixture.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function round(value) return math.floor(value + 0.5) end

-- ---------------------------------------------------------------------------
-- 1. Roster and row preparation
-- ---------------------------------------------------------------------------
local roster = dofile(repo .. "/tools/r24_density_xp/roster.lua")(repo)
check(#roster.failed == 0, "every mob file loads: " .. table.concat(roster.failed, "; "))
check(#roster.rows == #roster.raw_rows and #roster.rows > 60, "rows captured")
local gm = roster.grug_mobs
local row_cap = gm.density_row_cap()
-- Checked against every zone's largest possible point budget below, once
-- the zone entries exist.
check(row_cap == gm.DENSITY_ROW_CAP, "row cap is DENSITY_ROW_CAP")

-- Old (Round 16) cap of one raw surface row.
local function old_cap(aoc, night)
	local cap = math.max(1, round(aoc * 1.3))
	if night then cap = math.ceil(cap * 5 / 4) end
	return cap
end

local budgeted_names = {}
for i, raw in ipairs(roster.raw_rows) do
	local row = roster.rows[i]
	local surface = not (raw.max_height and raw.max_height <= -40)
	if surface and gm.density_budgeted(raw.name) then
		budgeted_names[raw.name] = true
		check(row.active_object_count == row_cap, raw.name .. " row cap lifted")
		check(row.chance == math.max(1, round(raw.chance / 1.5)),
			raw.name .. " attempt frequency 1.5x")
		check(gm.density_weight(raw.name) >= raw.active_object_count,
			raw.name .. " weight is its largest row cap")
	elseif surface and raw.name ~= "grug_mobs:kraken" and
			raw.name ~= "grug_mobs:reed_angelfish" then
		check(row.active_object_count == raw.active_object_count or
			row.active_object_count == old_cap(raw.active_object_count, false) or
			row.active_object_count == old_cap(raw.active_object_count, true) or
			row.active_object_count == math.ceil(raw.active_object_count * 5 / 4),
			raw.name .. " keeps the Round 16 rule")
	else
		check(row.chance == raw.chance or row.chance == round(raw.chance / 1.3),
			raw.name .. " unbudgeted row")
	end
end
-- Excluded tiers and families never enter the budget.
for _, name in ipairs({"grug_mobs:rabbit", "grug_mobs:hare", "grug_mobs:parrot",
		"grug_mobs:wild_turkey", "grug_mobs:song_bird",
		"grug_mobs:kraken", "grug_mobs:reed_angelfish", "grug_mobs:gull",
		"grug_mobs:shore_crab", "grug_mobs:reef_lurker", "grug_mobs:bandit",
		"grug_mobs:mirefolk", "grug_mobs:cave_bat", "grug_mobs:goblin_miner"}) do
	check(not gm.density_budgeted(name), name .. " is outside the budget")
end
for name, def in pairs(roster.defs) do
	if def.type == "npc" or def._grug_tier == "rare" or def._grug_tier == "boss" or
			def._grug_tier == "critter" or def._grug_fixed_level then
		check(not budgeted_names[name], name .. " (npc/rare/boss/critter/fixed) unbudgeted")
	end
end

-- ---------------------------------------------------------------------------
-- 2. Per-zone table
-- ---------------------------------------------------------------------------
local function median(values)
	table.sort(values)
	local n = #values
	if n % 2 == 1 then return values[(n + 1) / 2] end
	return (values[n / 2] + values[n / 2 + 1]) / 2
end

local old_sums = {day = {}, night = {}}
local lines = {}
for _, zone in ipairs(gm.density_zone_ids()) do
	local day = gm.zone_density_cast(zone, "day")
	local night = gm.zone_density_cast(zone, "night")
	if #day + #night > 0 then
		local in_day, in_night = {}, {}
		for _, name in ipairs(day) do in_day[name] = true end
		for _, name in ipairs(night) do in_night[name] = true end
		local cells = {}
		for _, clock in ipairs({"day", "night"}) do
			local cast = clock == "day" and day or night
			local old = 0
			for _, name in ipairs(cast) do
				-- Night-only in this zone: the Round 16 night 5/4 applied.
				local night_row = in_night[name] and not in_day[name]
				old = old + old_cap(gm.density_weight(name), night_row)
			end
			local entry = gm.density_entry(zone, clock)
			local budget = gm.density_budget(zone, clock)
			if #cast > 0 then
				old_sums[clock][#old_sums[clock] + 1] = old
				check(entry and entry.budget == budget and #entry.names == #cast,
					zone .. " " .. clock .. " entry")
				-- The shares with the whole cast eligible sum to the budget
				-- within rounding, and each species alone may fill it.
				local shares = 0
				for _, name in ipairs(cast) do
					shares = shares + gm.density_share(budget, entry.weight[name], entry.total)
					check(gm.density_share(budget, entry.weight[name],
						entry.weight[name]) == budget, zone .. " " .. name .. " alone fills")
				end
				check(math.abs(shares - budget) <= (#cast + 1) / 2,
					zone .. " " .. clock .. " shares sum to the budget")
			end
			cells[#cells + 1] = ("%s n=%d old=%d new=%d"):format(clock, #cast, old,
				#cast > 0 and budget or 0)
		end
		lines[#lines + 1] = ("%-30s %-24s %-24s  day: %s | night: %s"):format(zone,
			cells[1], cells[2], table.concat(day, " "):gsub("grug_mobs:", ""),
			(table.concat(night, " "):gsub("grug_mobs:", "")))
	end
end
print("zone                           palette cast: day (species, cap sum, budget)  night")
for _, line in ipairs(lines) do print(line) end
check(#old_sums.day > 25 and #old_sums.night > 25, "named zones with a budgeted cast")

-- ---------------------------------------------------------------------------
-- 2b. Per-point density on a real world (seed 4242424242). At every sampled
--     land column (step 32, y 10) the budgeted species that may spawn there
--     now (their hosts include the column's biome top node, and the full
--     per-point decision: policy, level gate, row check, clock) give the old
--     area population (sum of their Round 16 caps) and the new one (the zone
--     budget when any is eligible): both are the cap-bound equilibrium of a
--     uniform patch of that biome.
-- ---------------------------------------------------------------------------
local world = dofile(repo .. "/tools/r23_tree_line/world_source.lua")(repo, "4242424242")
local S = world.session
local STARTS = {
	{race = "dwarf", x = -1800, z = -2550}, {race = "human", x = 0, z = -2550},
	{race = "elf", x = 1800, z = -2550}, {race = "undead", x = -1800, z = 2550},
	{race = "orc", x = 0, z = 2550}, {race = "troll", x = 1800, z = 2550},
}
-- Biome top nodes, from the R7 surface manifest (biome|top|filler|...).
local BIOME_TOP = {}
do
	local text = assert(io.open(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua")):read("*a")
	local rows = assert(text:match("local SURFACE_ROWS = %[%[\n(.-)%]%]"))
	for biome, top in rows:gmatch("(grug_[%w_]+)|([^|]+)|") do BIOME_TOP[biome] = top end
	check(BIOME_TOP.grug_meadows == "default:dirt_with_grass", "biome top table")
end
local timeofday, top_node = 0.5, "ignore"
_G.grug_zones = S
_G.core = {get_timeofday = function() return timeofday end,
	get_node = function() return {name = top_node} end,
	get_item_group = function() return 0 end,
	settings = {get = function() return nil end}}
_G.grug_core = {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	start_identities = function()
		local out = {}
		for i, start in ipairs(STARTS) do
			out[i] = {race_id = start.race, anchor = {x = start.x, y = 10, z = start.z}}
		end
		return out
	end}

local START_ZONES = {
	elandor_hearthpine_vale = "dwarf", elandor_dawnmere_fields = "human",
	elandor_silverleaf_glades = "elf", kragmar_stillgrave_hollow = "undead",
	kragmar_sunscar_flats = "orc", kragmar_kapok_cradle = "troll",
}
local per_zone = {}
local no_sparser = true
local function stat(zone)
	local s = per_zone[zone]
	if not s then
		s = {}
		for _, clock in ipairs({"day", "night"}) do
			s[clock] = {points = 0, old = 0, new = 0, empty = 0,
				band1 = {points = 0, old = 0, new = 0, empty = 0}}
		end
		per_zone[zone] = s
	end
	return s
end
for x = -3584, 3584, 32 do
	for z = -3584, 3584, 32 do
		local zone = S.id_at(x, z)
		local pos = {x = x, y = 10, z = z}
		local level = zone and S.mob_level_at(pos)
		top_node = BIOME_TOP[S.biome_at(x, z)] or "ignore"
		if zone and level and S.water_class_at(x, z) == "land" then
			for _, clock in ipairs({"day", "night"}) do
				timeofday = clock == "day" and 0.5 or 0.0
				local cast = gm.zone_density_cast(zone, clock)
				if #cast > 0 then
					local old, floor, eligible = 0, 0, 0
					local in_other = {}
					for _, name in ipairs(gm.zone_density_cast(zone,
							clock == "day" and "night" or "day")) do
						in_other[name] = true
					end
					for _, name in ipairs(cast) do
						if gm.density_hosts(name, top_node) and
								roster.spawn_allowed(name, pos) then
							eligible = eligible + 1
							-- The exact Round 16 rule (5/4 only for night rows)
							-- and the budget's own old term (5/4 for all at night).
							old = old + old_cap(gm.density_weight(name),
								clock == "night" and not in_other[name])
							floor = floor + gm.density_old_cap(gm.density_weight(name), clock)
						end
					end
					-- Area population reachable now: the point budget, but no
					-- species past its species cap (ceil(1.5 x old cap)).
					local caps = 0
					for _, name in ipairs(cast) do
						if gm.density_hosts(name, top_node) and
								roster.spawn_allowed(name, pos) then
							caps = caps + gm.density_species_cap(gm.density_weight(name), clock)
						end
					end
					local new = eligible > 0 and math.min(caps,
						gm.density_point_budget(gm.density_budget(zone, clock), floor)) or 0
					if new < old then no_sparser = false end
					local cells = {stat(zone)[clock]}
					if level <= 3 then cells[2] = cells[1].band1 end
					for _, cell in ipairs(cells) do
						cell.points = cell.points + 1
						cell.old = cell.old + old
						cell.new = cell.new + new
						if eligible == 0 then cell.empty = cell.empty + 1 end
					end
				end
			end
		end
	end
end
local zone_ids = {}
for zone in pairs(per_zone) do zone_ids[#zone_ids + 1] = zone end
table.sort(zone_ids)
local means = {day = {}, night = {}}
print("\nper-point mean area population (old -> new), share of columns with no budgeted species")
for _, zone in ipairs(zone_ids) do
	local cells = {}
	for _, clock in ipairs({"day", "night"}) do
		local c = per_zone[zone][clock]
		if c.points > 0 then
			means[clock][#means[clock] + 1] = c.old / c.points
			cells[#cells + 1] = ("%s %5.1f -> %5.1f (empty %3d%%)"):format(clock,
				c.old / c.points, c.new / c.points, round(100 * c.empty / c.points))
			if START_ZONES[zone] and c.band1.points > 0 then
				local b = c.band1
				cells[#cells + 1] = ("[band 1 %4.1f -> %4.1f]"):format(b.old / b.points,
					b.new / b.points)
			end
		end
	end
	print(("%-30s %s%s"):format(zone, START_ZONES[zone] and "* " or "  ",
		table.concat(cells, "  ")))
end
local day_median, night_median = median(means.day), median(means.night)
print(("per-point old population: day median %.2f over %d zones, night median %.2f over %d")
	:format(day_median, #means.day, night_median, #means.night))
-- A tolerance, not identity: the reference is a recorded first value, and
-- later roster or terrain changes may move the median a little.
check(math.abs(gm.DENSITY_REFERENCE.day - day_median) <= 1 and
	math.abs(gm.DENSITY_REFERENCE.night - night_median) <= 1,
	"DENSITY_REFERENCE is the pre-Round-24 per-point median (within 1)")
check(gm.density_budget("kragmar_sunscar_flats", "day") == 15 and
	gm.density_budget("kragmar_sunscar_flats", "night") == 23, "budgets 15 / 23")

-- No point sparser than before (coordinator correction to ruling 27): at
-- every sampled column the point budget is at least the exact old
-- population, and no point budget can exceed the lifted row cap.
check(no_sparser, "no sampled column's budget is below its old population")
do
	print("\nper-zone budgets: zone budget, mean old -> mean new area population")
	print(("%-30s %-24s %-24s"):format("zone", "day", "night"))
	for _, zone in ipairs(zone_ids) do
		local cells = {}
		for _, clock in ipairs({"day", "night"}) do
			local c = per_zone[zone][clock]
			local entry = gm.density_entry(zone, clock)
			if entry then
				check(math.max(entry.budget, entry.old_total) <= gm.DENSITY_ROW_CAP,
					zone .. " " .. clock .. " point budgets stay below the row cap")
			end
			if c.points > 0 then
				cells[#cells + 1] = ("%2d: %5.1f -> %5.1f"):format(
					gm.density_budget(zone, clock), c.old / c.points, c.new / c.points)
			else
				cells[#cells + 1] = "-"
			end
		end
		print(("%-30s %-24s %-24s"):format(zone, cells[1], cells[2]))
	end
end

-- Start-town hostile refusal ends at the town's protected floor (ruling 30),
-- read from the zone authority: in the anchor column it agrees with the
-- authority's own "town" answer at every height, and the floor lies below
-- the surface.
do
	local agree, floor = true, nil
	for y = -300, 60 do
		local refused = gm.in_start_footprint(0, -2550, y)
		local town = S.hard_protection_kind_at({x = 0, y = y, z = -2550}) == "town"
		if refused ~= town then agree = false end
		if refused and not floor then floor = y end
	end
	print(("human start town: hostile refusal from y %s (surface %s)"):format(
		tostring(floor), tostring(S.terrain_height_at(0, -2550))))
	check(agree and floor and floor < S.terrain_height_at(0, -2550) - 50 and
		gm.in_start_footprint(0, -2550),
		"start footprint: the authority's protected volume, not unlimited depth")
end
-- Ruling 31 (Lane D3): Scorpion and Viper carry a night row and a zone day
-- row with the same cap; the weight is that one cap, and the zone key puts
-- them into their start zone's day cast only.
check(gm.density_weight("grug_mobs:scorpion") == 4 and
	gm.density_weight("grug_mobs:viper") == 4, "two rows, one weight")
do
	local function has(zone, clock, name)
		for _, other in ipairs(gm.zone_density_cast(zone, clock)) do
			if other == name then return true end
		end
		return false
	end
	check(has("kragmar_sunscar_flats", "day", "grug_mobs:scorpion") and
		has("kragmar_sunscar_flats", "night", "grug_mobs:scorpion") and
		not has("kragmar_redtusk_savanna", "day", "grug_mobs:scorpion") and
		has("kragmar_kapok_cradle", "day", "grug_mobs:viper") and
		not has("kragmar_raincall_basin", "day", "grug_mobs:viper"),
		"zone clock keys: day cast only in the start zone")
	check(has("kragmar_sunscar_flats", "day", "grug_mobs:plains_runner"),
		"plains runner (fighting prey since D3) is budgeted")
end

-- ---------------------------------------------------------------------------
-- 2c. Lone species (review finding): with no other mob in range, every
--     budgeted species of every zone cast stops at exactly its species cap
--     ceil(1.5 x old cap), whatever the budget. Then the named worst cases on
--     the real world: Stone Golem on bare stone in Frostbarrow/Stormvault,
--     War Construct in Broken Causeway/Shattered Line, Carrion Crow.
-- ---------------------------------------------------------------------------
do
	local lone_objects = {}
	local real_objects = _G.core.get_objects_inside_radius
	_G.core.get_objects_inside_radius = function() return lone_objects end
	local function fill_same(name, n)
		lone_objects = {}
		for _ = 1, n do
			local ent = {name = name}
			lone_objects[#lone_objects + 1] = {get_luaentity = function() return ent end}
		end
	end
	local function max_count(name, pos, node_name, eligible)
		local n = 0
		while n < 80 do
			fill_same(name, n)
			if not gm.density_allows(name, pos, node_name, eligible) then break end
			n = n + 1
		end
		return n
	end
	-- Property over the whole roster: a stub point in each zone where only
	-- the tested species is eligible.
	local saved_zones = _G.grug_zones
	local stub_zone
	_G.grug_zones = {id_at = function() return stub_zone end}
	local lone_ok, cases = true, 0
	for _, zone in ipairs(gm.density_zone_ids()) do
		for _, clock in ipairs({"day", "night"}) do
			timeofday = clock == "day" and 0.5 or 0.0
			local entry = gm.density_entry(zone, clock)
			for _, name in ipairs(entry and entry.names or {}) do
				stub_zone = zone
				local cap = gm.density_species_cap(entry.weight[name], clock)
				local got = max_count(name, {x = 0, y = 10, z = 0}, "ignore",
					function() return false end)
				cases = cases + 1
				if got ~= cap then
					lone_ok = false
					print(("lone %s %s %s: %d, cap %d"):format(zone, clock, name, got, cap))
				end
			end
		end
	end
	_G.grug_zones = saved_zones
	check(lone_ok and cases > 300, "every lone budgeted species stops at its species cap")
	-- The review's cases on the real world (full per-point eligibility).
	local named = {
		{"elandor_frostbarrow_shelf", "grug_mobs:stone_golem", "default:stone"},
		{"elandor_stormvault_heights", "grug_mobs:stone_golem", "default:stone"},
		{"front_broken_causeway", "grug_mobs:war_construct", "default:stone"},
		{"front_shattered_line", "grug_mobs:war_construct", "default:stone"},
		{"front_broken_causeway", "grug_mobs:carrion_crow", "grug_nodes:mud"},
		{"kragmar_bannerbreak_mesa", "grug_mobs:carrion_crow", "grug_nodes:mesa_clay"},
	}
	print("\nlone worst cases on seed 4242424242 (no other mob in range)")
	for _, row in ipairs(named) do
		local zone, name, node_name = row[1], row[2], row[3]
		for _, clock in ipairs({"day", "night"}) do
			timeofday = clock == "day" and 0.5 or 0.0
			local pos
			for x = -3584, 3584, 16 do
				for z = -3584, 3584, 16 do
					if not pos and S.id_at(x, z) == zone and
							S.water_class_at(x, z) == "land" then
						local candidate = {x = x, y = math.max(1, S.terrain_height_at(x, z)), z = z}
						top_node = node_name
						if roster.spawn_allowed(name, candidate) then pos = candidate end
					end
				end
			end
			if pos then
				local old = gm.density_old_cap(gm.density_weight(name), clock)
				local cap = gm.density_species_cap(gm.density_weight(name), clock)
				local got = max_count(name, pos, node_name, roster.spawn_allowed)
				print(("%-28s %-5s %-22s old cap %d -> at most %d (species cap %d, budget %d)")
					:format(zone, clock, name, old, got, cap, gm.density_budget(zone, clock)))
				check(got <= cap and got >= old, zone .. " " .. clock .. " " .. name ..
					" lone count within [old cap, ceil(1.5 x old cap)]")
			else
				print(("%-28s %-5s %-22s never eligible by policy"):format(zone, clock, name))
			end
		end
	end
	_G.core.get_objects_inside_radius = real_objects
end

-- Worst-case area totals: for each zone and clock, over every subset E of
-- the cast that could share a point, the largest total the rules allow is
-- min(max(zone budget, old(E)), sum of E's species caps); never below old(E).
do
	print("\nworst-case area totals (zone budget, whole-cast old population, worst total, largest single species)")
	local worst_ok = true
	for _, zone in ipairs(gm.density_zone_ids()) do
		local cells = {}
		for _, clock in ipairs({"day", "night"}) do
			local entry = gm.density_entry(zone, clock)
			if entry then
				local n = #entry.names
				local worst, single = 0, 0
				for mask = 1, 2 ^ n - 1 do
					local old, caps, bit_value = 0, 0, mask
					for i = 1, n do
						if bit_value % 2 == 1 then
							local w = entry.weight[entry.names[i]]
							old = old + gm.density_old_cap(w, clock)
							caps = caps + gm.density_species_cap(w, clock)
						end
						bit_value = math.floor(bit_value / 2)
					end
					local total = math.min(math.max(entry.budget, old), caps)
					if total < old then worst_ok = false end
					if total > worst then worst = total end
				end
				for i = 1, n do
					single = math.max(single,
						gm.density_species_cap(entry.weight[entry.names[i]], clock))
				end
				cells[#cells + 1] = ("%2d / %2d / %2d / %2d"):format(entry.budget,
					entry.old_total, worst, single)
			else
				cells[#cells + 1] = "-"
			end
		end
		print(("%-30s day %-19s night %s"):format(zone, cells[1], cells[2]))
	end
	check(worst_ok, "worst-case totals never below the old population")
end

-- ---------------------------------------------------------------------------
-- 3. density_allows against a stub area (Sunscar Flats, dry-grass node)
-- ---------------------------------------------------------------------------
do
	local area = {zone = "kragmar_sunscar_flats", level = 2, objects = {}}
	_G.grug_zones = {
		id_at = function() return area.zone end,
		mob_level_at = function() return area.level end,
		biome_at = function() return "grug_savanna" end,
		race_region_at = function() return "orc" end,
		pvp_rule_at = function() return "faction" end,
	}
	_G.core.get_objects_inside_radius = function(_, radius)
		check(radius == 128, "count radius is mobs_redo's 2 x active_block_range x 16")
		return area.objects
	end
	local function fill(list)
		area.objects = {}
		for _, row in ipairs(list) do
			for _ = 1, row[2] do
				local ent = {name = "grug_mobs:" .. row[1]}
				for key, value in pairs(row[3] or {}) do ent[key] = value end
				area.objects[#area.objects + 1] = {get_luaentity = function() return ent end}
			end
		end
	end
	local pos = {x = 0, y = 10, z = 2900}
	local node = "default:dry_dirt_with_dry_grass"
	local function allows(name)
		return gm.density_allows("grug_mobs:" .. name, pos, node, roster.spawn_allowed)
	end
	-- Day on grass, band 1: only the Boar can spawn there (the Plains Runner
	-- needs dry grass, the Scorpion band 2); alone it stops at its species cap
	-- ceil(1.5 x old cap 7) = 11, below the budget 15.
	timeofday = 0.5
	local day_budget = gm.density_budget("kragmar_sunscar_flats", "day")
	local boar_cap = gm.density_species_cap(gm.density_weight("grug_mobs:boar"), "day")
	check(boar_cap == 11 and boar_cap < day_budget, "boar species cap 11")
	node = "default:dirt_with_grass"
	fill({{"boar", boar_cap - 1}, {"rabbit", 9}})
	check(allows("boar"), "day on grass: cap-1 boars (+9 critters) -> one more")
	fill({{"boar", boar_cap}})
	check(not allows("boar"), "day on grass: boar species cap reached")
	-- Day on dry grass, band 1: Boar and Plains Runner share by row cap.
	node = "default:dry_dirt_with_dry_grass"
	local share = gm.density_share(day_budget, gm.density_weight("grug_mobs:boar"),
		gm.density_weight("grug_mobs:boar") + gm.density_weight("grug_mobs:plains_runner"))
	fill({{"boar", share - 1}})
	check(allows("boar"), "day on dry grass: below the boar share")
	fill({{"boar", share}})
	check(not allows("boar") and allows("plains_runner"),
		"day on dry grass: boar share reached, the runner still has room")
	-- Night, band 1: only the Giant Rat is eligible (Scorpion start band 4,
	-- Husk level-gated): it stops at its species cap ceil(1.5 x 7) = 11.
	timeofday = 0.0
	area.level = 2
	local rat_cap = gm.density_species_cap(gm.density_weight("grug_mobs:giant_rat"), "night")
	check(rat_cap == 11, "rat night species cap 11")
	fill({{"giant_rat", rat_cap - 1}, {"boar", 14}})
	check(allows("giant_rat"), "night band 1: cap-1 rats -> one more (day boars not counted)")
	fill({{"giant_rat", rat_cap}})
	check(not allows("giant_rat"), "night band 1: rat species cap reached")
	-- Night, level 10: Rat, Scorpion and Husk eligible, weight 4 each -> share 8.
	area.level = 10
	fill({{"giant_rat", 7}})
	check(allows("giant_rat"), "night level 10: 7 rats -> below share 8")
	fill({{"giant_rat", 8}})
	check(not allows("giant_rat"), "night level 10: 8 rats -> share reached")
	check(allows("scorpion"), "night level 10: scorpion still has its share")
	fill({{"scorpion", 10}, {"sun_dried_husk", 13}})
	check(allows("giant_rat"),
		"night level 10: total full, but the rat is below its old cap 7 -> spawns as before")
	fill({{"giant_rat", 7}, {"scorpion", 8}, {"sun_dried_husk", 8}})
	check(not allows("giant_rat") and not allows("scorpion"),
		"night level 10: total 23 full and everyone at or above the old cap")
	-- The engine case: a band-1 column (only the Jungle Boar may spawn there)
	-- next to a band-2 edge whose Lynx, Tapir and Viper fill the budget; the
	-- boar still reaches its old cap 7.
	do
		local saved_zone, saved_node, saved_level, saved_time =
			area.zone, node, area.level, timeofday
		area.zone, area.level, timeofday = "kragmar_kapok_cradle", 3, 0.5
		node = "default:dirt_with_rainforest_litter"
		fill({{"jungle_boar", 6}, {"jungle_lynx", 7}, {"tapir", 4}, {"viper", 5}})
		check(allows("jungle_boar"), "mixed area: boar below its old cap despite a full budget")
		fill({{"jungle_boar", 7}, {"jungle_lynx", 7}, {"tapir", 4}, {"viper", 5}})
		check(not allows("jungle_boar"), "mixed area: boar at its old cap, total full")
		area.zone, node, area.level, timeofday =
			saved_zone, saved_node, saved_level, saved_time
	end
	-- A species-rich point keeps its old population as its budget: Kapok by
	-- day at level 10 on rainforest litter, Jungle Boar, Jungle Lynx, Tapir and
	-- Viper (old caps 7 + 7 + 4 + 5 = 23 > zone budget 15).
	do
		local saved_zone, saved_node, saved_level, saved_time =
			area.zone, node, area.level, timeofday
		area.zone, area.level, timeofday = "kragmar_kapok_cradle", 10, 0.5
		node = "default:dirt_with_rainforest_litter"
		fill({{"jungle_boar", 5}, {"jungle_lynx", 7}, {"tapir", 4}, {"viper", 5}})
		check(allows("jungle_boar"), "rich point: 21 of 23, boar below its share 7")
		fill({{"jungle_boar", 7}, {"jungle_lynx", 7}, {"tapir", 4}, {"viper", 5}})
		check(not allows("tapir"), "rich point: old population 23 reached")
		area.zone, node, area.level, timeofday =
			saved_zone, saved_node, saved_level, saved_time
	end
	-- Named rares, camp members and rare/boss tiers never count.
	fill({{"giant_rat", 30, {_grug_camp_pos = {x = 0, y = 0, z = 0}}},
		{"scorpion", 5, {_grug_rare_id = "r"}}, {"sun_dried_husk", 5, {_grug_tier = "boss"}}})
	check(allows("giant_rat"), "camp/rare/boss entities are outside the budget")
	-- A host the other species cannot use: on grass only the Rat of the three
	-- could spawn at level 10, so it may go past its share 8 up to its cap.
	node = "default:dirt_with_grass"
	fill({{"giant_rat", rat_cap - 1}})
	check(allows("giant_rat"), "rat alone on its host node: up to its species cap")
	fill({{"giant_rat", rat_cap}})
	check(not allows("giant_rat"), "rat alone on its host node: never past its species cap")
	node = "default:dry_dirt_with_dry_grass"
	-- Unbudgeted species are never limited here; underground rows neither.
	fill({{"rabbit", 50}})
	check(allows("rabbit"), "critter row untouched")
	check(gm.density_allows("grug_mobs:giant_rat", {x = 0, y = -60, z = 0}, "default:stone",
		roster.spawn_allowed), "underground row untouched")
end

-- ---------------------------------------------------------------------------
-- 4. Gathering XP (ruling 28; kill-equivalent ratios since Round 28 ruling 32)
-- ---------------------------------------------------------------------------
do
	_G.grug_core = {}
	_G.core = {log = function() end, register_on_joinplayer = function() end,
		register_on_leaveplayer = function() end, register_globalstep = function() end,
		register_chatcommand = function() end, register_on_dieplayer = function() end,
		register_on_respawnplayer = function() end}
	setmetatable(_G.core, {__index = function() return function() end end})
	dofile(repo .. "/mods/PLAYER/grug_xp/init.lua")
	local X = _G.grug_xp
	check(X.GATHER_XP_RATIO.ore == 0.10 and X.GATHER_XP_RATIO.gem == 0.20 and
		X.GATHER_XP_RATIO.fish == 0.33, "ratios 0.10 / 0.20 / 0.33")
	local levels = {1, 3, 5, 10, 15, 20, 30, 45, 60}
	local rows = {
		{"ore T1 (coal..quartz)", "ore", 1}, {"ore T2 (gold)", "ore", 2},
		{"ore T3 (silver)", "ore", 3}, {"ore T4 (emberglass)", "ore", 4},
		{"ore T5 (abyssal crystal)", "ore", 5}, {"gem T2 (G1)", "gem", 2},
		{"gem T4 (G2)", "gem", 4},
	}
	for band = 1, 6 do rows[#rows + 1] = {"fish band " .. band, "fish", band} end
	local header = {"player level"}
	for _, level in ipairs(levels) do header[#header + 1] = ("%4d"):format(level) end
	print("\ngathering XP per node / fish")
	print(("%-26s %s"):format(header[1], table.concat(header, " ", 2)))
	for _, row in ipairs(rows) do
		local reference = X.gathering_reference_level(row[3])
		local cells = {}
		for _, level in ipairs(levels) do
			local xp = X.gather_xp(row[2], reference, level)
			local expected = math.floor(X.GATHER_XP_RATIO[row[2]] *
				(25 + 5 * math.min(10 * row[3], level + 5)) + 0.5)
			check(xp == expected, row[1] .. " at level " .. level)
			check(xp > 0, row[1] .. " at level " .. level .. " pays (no gray rule)")
			cells[#cells + 1] = ("%4d"):format(xp)
		end
		print(("%-26s %s"):format(row[1], table.concat(cells, " ")))
	end
	-- Worked values: rounding half up, cap at player level + 5, no gray rule.
	check(X.gather_xp("ore", 10, 1) == 6, "coal at level 1: 0.1 x M(6) = 5.5 -> 6")
	check(X.gather_xp("ore", 10, 3) == 7, "coal at level 3: 0.1 x M(8) = 6.5 -> 7")
	check(X.gather_xp("ore", 10, 60) == 8, "coal at level 60 still pays 0.1 x M(10) = 7.5 -> 8")
	check(X.gather_xp("gem", 40, 30) == 40, "G2 gem at level 30: 0.2 x M(35)")
	check(X.gather_xp("fish", 60, 60) == 107, "band 6 fish at level 60: 0.33 x M(60) = 107.25")
	check(X.gather_xp("fish", 10, 1) == 18, "band 1 fish at level 1: 0.33 x M(6) = 18.15")
	-- Award goes through add_xp with source "gathering" (no quest bonus).
	local seen
	local real_add = X.add_xp
	X.add_xp = function(player, amount, source) seen = {amount, source} end
	X.get_level = function() return 12 end
	check(X.award_gathering({}, "gem", 20) == 22 and seen[1] == 22 and
		seen[2] == "gathering", "award_gathering at level 12: 0.2 x M(min(20, 17)) = 22")
	X.add_xp = real_add
end

print("R24 DENSITY/XP FIXTURE PASS checks=" .. checks)

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
-- 4. Gathering XP (grug_xp.gathering_xp): the table at several player
--    levels, ore/gem tiers and fishing bands, and its rounding.
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
check(row_cap == math.ceil(math.max(gm.DENSITY_REFERENCE.day,
	gm.DENSITY_REFERENCE.night) * gm.DENSITY_SCALE), "row cap is the largest budget")

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
					local old, eligible = 0, 0
					local in_other = {}
					for _, name in ipairs(gm.zone_density_cast(zone,
							clock == "day" and "night" or "day")) do
						in_other[name] = true
					end
					for _, name in ipairs(cast) do
						if gm.density_hosts(name, top_node) and
								roster.spawn_allowed(name, pos) then
							eligible = eligible + 1
							old = old + old_cap(gm.density_weight(name),
								clock == "night" and not in_other[name])
						end
					end
					local new = eligible > 0 and gm.density_budget(zone, clock) or 0
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
check(gm.density_budget("kragmar_sunscar_flats", "day") == 14 and
	gm.density_budget("kragmar_sunscar_flats", "night") == 23, "budgets 14 / 23")

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
	-- Day, one budgeted species (Boar): it alone may fill the whole budget 14.
	timeofday = 0.5
	fill({{"boar", 13}, {"rabbit", 9}})
	check(allows("boar"), "day: 13 boars (+9 critters) -> a 14th may spawn")
	fill({{"boar", 14}})
	check(not allows("boar"), "day: 14 boars -> budget full")
	-- Night, band 1: only the Giant Rat is eligible (Scorpion start band 4,
	-- Husk level-gated), so it may fill the night budget 23.
	timeofday = 0.0
	area.level = 2
	fill({{"giant_rat", 22}, {"boar", 14}})
	check(allows("giant_rat"), "night band 1: 22 rats -> 23rd may spawn (day boars not counted)")
	fill({{"giant_rat", 23}})
	check(not allows("giant_rat"), "night band 1: 23 rats -> budget full")
	-- Night, level 10: Rat, Scorpion and Husk eligible, weight 4 each -> share 8.
	area.level = 10
	fill({{"giant_rat", 7}})
	check(allows("giant_rat"), "night level 10: 7 rats -> below share 8")
	fill({{"giant_rat", 8}})
	check(not allows("giant_rat"), "night level 10: 8 rats -> share reached")
	check(allows("scorpion"), "night level 10: scorpion still has its share")
	fill({{"scorpion", 10}, {"sun_dried_husk", 13}})
	check(not allows("giant_rat"), "night level 10: 23 others -> total budget full")
	-- Named rares, camp members and rare/boss tiers never count.
	fill({{"giant_rat", 23, {_grug_camp_pos = {x = 0, y = 0, z = 0}}},
		{"scorpion", 5, {_grug_rare_id = "r"}}, {"sun_dried_husk", 5, {_grug_tier = "boss"}}})
	check(allows("giant_rat"), "camp/rare/boss entities are outside the budget")
	-- A host the other species cannot use: on grass only the Rat of the three
	-- could spawn, so its share is the whole budget again.
	node = "default:dirt_with_grass"
	fill({{"giant_rat", 20}})
	check(allows("giant_rat"), "rat alone on its host node: share is the budget")
	node = "default:dry_dirt_with_dry_grass"
	-- Unbudgeted species are never limited here; underground rows neither.
	fill({{"rabbit", 50}})
	check(allows("rabbit"), "critter row untouched")
	check(gm.density_allows("grug_mobs:giant_rat", {x = 0, y = -60, z = 0}, "default:stone",
		roster.spawn_allowed), "underground row untouched")
end

-- ---------------------------------------------------------------------------
-- 4. Gathering XP (ruling 28)
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
	check(X.GATHERING_XP_FACTOR.ore == 1.5 and X.GATHERING_XP_FACTOR.gem == 3 and
		X.GATHERING_XP_FACTOR.fish == 5, "factors 1.5 / 3 / 5")
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
			local xp = X.gathering_xp(row[2], reference, level)
			local expected = math.floor(X.GATHERING_XP_FACTOR[row[2]] *
				math.min(10 * row[3], level + 5) + 0.5)
			check(xp == expected, row[1] .. " at level " .. level)
			check(xp > 0, row[1] .. " at level " .. level .. " pays (no gray rule)")
			cells[#cells + 1] = ("%4d"):format(xp)
		end
		print(("%-26s %s"):format(row[1], table.concat(cells, " ")))
	end
	-- Worked values: rounding half up, cap at player level + 5, no gray rule.
	check(X.gathering_xp("ore", 10, 1) == 9, "coal at level 1: 1.5 x 6 = 9")
	check(X.gathering_xp("ore", 10, 2) == 11, "coal at level 2: 1.5 x 7 = 10.5 -> 11")
	check(X.gathering_xp("ore", 10, 60) == 15, "coal at level 60 still pays 15")
	check(X.gathering_xp("gem", 40, 30) == 105, "G2 gem at level 30: 3 x 35")
	check(X.gathering_xp("fish", 60, 60) == 300, "band 6 fish at level 60: 300")
	check(X.gathering_xp("fish", 10, 1) == 30, "band 1 fish at level 1: 5 x 6")
	-- Award goes through add_xp with source "gathering" (no quest bonus).
	local seen
	local real_add = X.add_xp
	X.add_xp = function(player, amount, source) seen = {amount, source} end
	X.get_level = function() return 12 end
	check(X.award_gathering({}, "gem", 20) == 51 and seen[1] == 51 and
		seen[2] == "gathering", "award_gathering at level 12: 3 x min(20, 17) = 51")
	X.add_xp = real_add
end

print("R24 DENSITY/XP FIXTURE PASS checks=" .. checks)

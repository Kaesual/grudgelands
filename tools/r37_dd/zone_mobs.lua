-- Round 37 lane DD: the generated placement table docs/design/zone_mobs.md.
--
-- The spawn recipes (mods/ENTITIES/grug_mobs/data/zones/<zone>.spawns.json)
-- are the placement authority for surface mobs; this script prints a view of
-- them per zone and per family, with each zone's level band from its mapgen
-- zone record (grug_mapgen/wp40/source/simple_map.lua) and each role's base
-- mob from the catalogue (data/subtypes.json), a leader by its slot name in
-- data/names.json (Round 38). The Rift Spawn's surface row
-- zones come from spawn_policy.lua's RECIPE_ZONE_ROWS.
--
--   luajit tools/r37_dd/zone_mobs.lua [REPO]           rewrite the file
--   luajit tools/r37_dd/zone_mobs.lua [REPO] --check   fails (status 1) when stale
--
-- As a module (dofile, no arguments seen as a script): returns
-- {build = function(repo) -> text, zones}, used by portable_test.lua.

local DOC = "docs/design/zone_mobs.md"
local MOB_PREFIX = "grug_mobs:"

-- Base display names that the plain title case of the id gets wrong.
local NAME_OVERRIDES = {sun_dried_husk = "Sun-Dried Husk"}

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function title(id)
	if NAME_OVERRIDES[id] then return NAME_OVERRIDES[id] end
	return (id:gsub("_", " "):gsub("(%a)(%w*)", function(first, rest)
		return first:upper() .. rest
	end))
end

local function sorted_keys(set)
	local list = {}
	for key in pairs(set) do list[#list + 1] = key end
	table.sort(list)
	return list
end

-- The zone ids RECIPE_ZONE_ROWS keeps the Rift Spawn's surface row in.
local function rift_row_zones(policy_text)
	local block = policy_text:match("local RECIPE_ZONE_ROWS = (%b{})")
	assert(block, "RECIPE_ZONE_ROWS not found in spawn_policy.lua")
	local row = block:match('%["grug_mobs:rift_spawn"%]%s*=%s*(%b{})')
	assert(row, "RECIPE_ZONE_ROWS has no rift_spawn row")
	local zones = {}
	for zone in row:gmatch("([%w_]+)%s*=%s*true") do zones[zone] = true end
	return zones
end

local function build(repo)
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	local mobs_dir = repo .. "/mods/ENTITIES/grug_mobs"
	local roles = {}
	for _, record in ipairs(json.parse(read(mobs_dir .. "/data/subtypes.json"))) do
		roles[record.role] = record
	end
	local function family_of(role)
		local record = assert(roles[role], "role not in the catalogue: " .. role)
		local base = record.base
		assert(base:sub(1, #MOB_PREFIX) == MOB_PREFIX, "foreign base " .. base)
		return title(base:sub(#MOB_PREFIX + 1))
	end
	local rift = rift_row_zones(read(mobs_dir .. "/spawn_policy.lua"))
	-- Round 38: a leader's name is its slot's in data/names.json.
	local names_core = dofile(mobs_dir .. "/names_core.lua")
	local names = names_core.api((names_core.build(json.parse(read(mobs_dir .. "/data/names.json")).names)))

	local zones, by_family = {}, {}
	local function note(family, column, zone_name)
		local row = by_family[family] or {day = {}, night = {}, camp = {}, leader = {}}
		by_family[family] = row
		row[column][zone_name] = true
	end
	for index, zone in ipairs(source.zones) do
		local data = json.parse(read(mobs_dir .. "/data/zones/" .. zone.id .. ".spawns.json"))
		assert(data.zone == zone.id, "zone id differs in " .. zone.id)
		local recipe = assert(data.recipe, "no recipe for " .. zone.id)
		local row = {index = index, zone = zone, day = {}, night = {}, camp = {},
			leaders = {}, critters = {},
			capital = type(recipe.from) == "table" and recipe.from.anchor == "capital"}
		for _, belt in ipairs(recipe.belts) do
			for _, kind in pairs(belt.kinds) do
				for _, clock in ipairs({"day", "night"}) do
					-- A roster written as "open" is the belt's open roster,
					-- which this loop reads on its own anyway.
					if type(kind[clock]) == "table" then
						for _, entry in ipairs(kind[clock]) do
							row[clock][family_of(entry.role)] = true
						end
					end
				end
			end
		end
		for _, camp in ipairs(recipe.camps or {}) do
			for _, entry in ipairs(camp.roster) do
				row.camp[family_of(entry.role)] = true
			end
		end
		for _, leader in ipairs(recipe.leaders or {}) do
			row.leaders[#row.leaders + 1] = names.lookup(leader.role, zone.id, nil) or roles[leader.role].display
			note(family_of(leader.role), "leader", zone.display_name)
		end
		for _, critter in ipairs(recipe.critters or {}) do
			row.critters[title(critter)] = true
		end
		for _, column in ipairs({"day", "night", "camp"}) do
			for family in pairs(row[column]) do note(family, column, zone.display_name) end
		end
		zones[#zones + 1] = row
	end

	local function list(set)
		local names = sorted_keys(set)
		return #names > 0 and table.concat(names, ", ") or "–"
	end
	local function zone_list(set)
		local names = {}
		for _, row in ipairs(zones) do
			if set[row.zone.display_name] then names[#names + 1] = row.zone.display_name end
		end
		return #names > 0 and table.concat(names, ", ") or "–"
	end
	local function band(zone)
		if zone.level_min == zone.level_max then return tostring(zone.level_min) end
		return ("%d–%d"):format(zone.level_min, zone.level_max)
	end

	local out = {}
	local function line(text) out[#out + 1] = text or "" end
	line("# Zone mobs")
	line()
	line("<!-- Generated by tools/r37_dd/zone_mobs.lua from the spawn recipes; do not edit by hand. -->")
	line()
	line("Which mobs spawn on the surface of each zone. The spawn recipes")
	line("(`mods/ENTITIES/grug_mobs/data/zones/<zone>.spawns.json`) are the placement")
	line("authority; this file is a view of them, with each zone's level band from its")
	line("mapgen zone record (`grug_mapgen/wp40/source/simple_map.lua`). What each")
	line("family is and does: [biomes_mobs.md](biomes_mobs.md) §3; how a recipe becomes")
	line("regions on a seed's terrain: [spawn_regions.md](spawn_regions.md).")
	line()
	line("- A family is the base mob of a role (`data/subtypes.json` `base`); each")
	line("  role's own name, levels and drops are in the catalogue.")
	line("- **Day** and **Night**: the families of every kind's roster at that clock,")
	line("  over all belts. **Camps**: the families of the camp rosters. **Leaders**:")
	line("  the zone's named leaders. **Critters**: the critter ABM rows the recipe")
	line("  keeps in the zone.")
	line("- A capital zone's recipe populates the land outside its city. The city")
	line("  (inside the wall line, the wall and its band) is protected spawn surface")
	line("  and gets no ambient non-critter spawn")
	line("  ([biomes_mobs.md §4.2](biomes_mobs.md#42-spawn-regions-round-28-rulings-3-34-37-38-lane-s1)).")
	line()
	line("After a recipe or catalogue change run `luajit tools/r37_dd/zone_mobs.lua`")
	line("(rewrites this file); `--check`, and with it `tools/run_fixtures.sh r37_dd`,")
	line("fails while the file is stale.")
	line()
	line("## By zone")
	line()
	line("| # | Zone | Band | Day | Night | Camps | Leaders | Critters |")
	line("|---|---|---|---|---|---|---|---|")
	for _, row in ipairs(zones) do
		local name = row.zone.display_name .. (row.capital and " (capital)" or "")
		line(("| %d | %s | %s | %s | %s | %s | %s | %s |"):format(row.index, name,
			band(row.zone), list(row.day), list(row.night), list(row.camp),
			#row.leaders > 0 and table.concat(row.leaders, ", ") or "–", list(row.critters)))
	end
	line()
	line("## By family")
	line()
	line("| Family | Day | Night | Camps | Leaders |")
	line("|---|---|---|---|---|")
	for _, family in ipairs(sorted_keys(by_family)) do
		local row = by_family[family]
		line(("| %s | %s | %s | %s | %s |"):format(family, zone_list(row.day),
			zone_list(row.night), zone_list(row.camp), zone_list(row.leader)))
	end
	line()
	line("## Surface rows outside the recipes")
	line()
	local rift_names = {}
	for _, row in ipairs(zones) do
		if rift[row.zone.id] then rift_names[#rift_names + 1] = row.zone.display_name end
	end
	line("- **Rift Spawn**, its own night ABM row on its host ground (`spawn_policy.lua`")
	line("  `RECIPE_ZONE_ROWS`): " .. table.concat(rift_names, ", ") .. ".")
	line("- Not placed by recipes: the underground rows, the water rows (Kraken Guard,")
	line("  Reed Angelfish), named rares, bosses and kings, guards and the PvP")
	line("  garrisons ([biomes_mobs.md](biomes_mobs.md) §3, §4).")
	return table.concat(out, "\n") .. "\n", zones
end

local M = {build = build, DOC = DOC}

-- Run as a script only when called with arguments from the command line
-- (`luajit zone_mobs.lua [REPO] [--check]`); dofile from a fixture passes none.
local script = arg and arg[0] and arg[0]:match("zone_mobs%.lua$")
if not script then
	return M
end

local repo, check = ".", false
for _, value in ipairs(arg) do
	if value == "--check" then check = true else repo = value end
end
local text = build(repo)
local path = repo .. "/" .. DOC
if check then
	local handle = io.open(path, "rb")
	local current = handle and handle:read("*a")
	if handle then handle:close() end
	if current ~= text then
		-- error() ends luajit with status 1 (os.exit is not used in this repo's Lua).
		error(DOC .. " is stale: run luajit tools/r37_dd/zone_mobs.lua", 0)
	end
	print(DOC .. " is current")
	return
end
local handle = assert(io.open(path, "wb"))
handle:write(text)
handle:close()
print("wrote " .. DOC)

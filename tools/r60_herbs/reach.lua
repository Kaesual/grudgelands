-- Round 60 lane HERBS: where every Alchemy ingredient comes from, per zone,
-- read from the shipped data (portable LuaJIT, never shipped).
--
--   local reach = dofile(ROOT .. "/tools/r60_herbs/reach.lua")
--   local world = reach.load(ROOT)
--
-- The plants, gathering sources, fish and caves come from the Round 46
-- locality index (tools/r46_ck/locality.lua: a source counts in a zone when
-- the zone is listed and one of its biomes hosts it); the mob loot is added
-- here: a zone has an item when a mob role of its spawn file drops it in the
-- drop band of a level the role spawns at there (drops.json bands,
-- grug_mobs.level_band; a leader also drops its family's leader bonus). The
-- Alchemy recipes are the real grug_alchemy/recipes.lua under small stubs.
--
-- The zones a tier is checked against (`M.tier_zones`): T1 the race's start
-- zone (1-10), T2 its 11-20 zone, T3 its 21-30 zones, T4 its contested
-- 31-40 zone (capitals are not counted); T5 and T6 the fronts of the band
-- (41-50, 51-60), which both factions share, for every race alike.

local M = {}

local VIAL = "vessels:glass_bottle"
M.RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}
M.FACTION = {dwarf = "accord", human = "accord", elf = "accord",
	undead = "throng", orc = "throng", troll = "throng"}

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function band_of(level)
	return math.max(1, math.min(6, math.floor((level - 1) / 10) + 1))
end

-- The Alchemy catalogue (every potion and elixir with its tier and inputs)
-- from the real recipes.lua; the stubs only record.
local function load_alchemy(root, json)
	local names = {"core", "grug_alchemy", "grug_jobs", "grug_traders",
		"grug_mobs", "grug_brewing", "grug_gathering", "grug_core"}
	local saved = {}
	for _, name in ipairs(names) do saved[name] = rawget(_G, name) end
	local registered = {}
	_G.core = {
		registered_items = registered,
		register_craftitem = function(name, def) registered[name] = def end,
		register_on_mods_loaded = function() end,
	}
	_G.grug_alchemy = {TIER_LEVELS = {1, 11, 21, 31, 41, 51},
		register_consumable = function(id, def)
			registered["grug_alchemy:" .. id] = {inventory_image = "x.png", tier = def.tier}
		end,
		potion_use = function() end, elixir_use = function() end,
		utility_use = function() end}
	_G.grug_jobs = {DURATIONS = {potion = 2, station = 1},
		register_recipe = function() end, register_ingredient_tier = function() end,
		ingredient_list = function(tokens) return tokens end}
	_G.grug_traders = {POTION_COOLDOWN = 30, register_all_vendor_stock = function() end}
	_G.grug_mobs = {read_data_json = function(file)
		return json.decode(read(root .. "/mods/ENTITIES/grug_mobs/data/" .. file))
	end}
	_G.grug_brewing = {NODE = "grug_brewing:brewing_stand"}
	_G.grug_gathering = {register_herb_authorizer = function() end}
	_G.grug_core = {}
	dofile(root .. "/mods/ITEMS/grug_alchemy/recipes.lua")
	local alchemy = _G.grug_alchemy
	for _, name in ipairs(names) do _G[name] = saved[name] end
	local rows = {}
	for _, row in ipairs(alchemy.CATALOG) do
		local inputs = {}
		for _, item in ipairs(row.inputs) do
			if item ~= VIAL then inputs[#inputs + 1] = item end
		end
		rows[#rows + 1] = {id = row.id, name = row.name, tier = row.tier, inputs = inputs}
	end
	return rows, alchemy.INGREDIENT_TIERS
end

-- Every (role, level span) a spawn file names; a role inherits the nearest
-- enclosing `levels`, else its sub-type's.
local function collect_roles(value, levels, out, leader)
	if type(value) ~= "table" then return end
	if type(value.levels) == "table" and #value.levels >= 1 then levels = value.levels end
	if type(value.role) == "string" then
		out[#out + 1] = {role = value.role, levels = levels, leader = leader}
	end
	for key, child in pairs(value) do
		collect_roles(child, levels, out, leader or key == "leaders")
	end
end

-- zone id -> {item -> true} of the mob loot that drops there.
local function load_drops(root, json, zones)
	local data = root .. "/mods/ENTITIES/grug_mobs/data/"
	local drops = {}
	for _, row in ipairs(json.decode(read(data .. "drops.json"))) do
		drops[row.family] = row
	end
	local subtypes = {}
	for _, row in ipairs(json.decode(read(data .. "subtypes.json"))) do
		subtypes[row.role] = row
	end
	local out = {}
	for _, zone in ipairs(zones) do
		local have = {}
		local handle = io.open(data .. "zones/" .. zone.id .. ".spawns.json", "rb")
		if handle then
			local spawns = json.decode(handle:read("*a"))
			handle:close()
			local roles = {}
			collect_roles(spawns, nil, roles, false)
			for _, entry in ipairs(roles) do
				local sub = subtypes[entry.role]
				local levels = entry.levels or (sub and sub.levels) or
					{zone.level_min, zone.level_max}
				local family = drops[sub and (sub.drops or sub.family) or entry.role]
				local leader = entry.leader or (sub and sub.tier == "leader")
				if family then
					for band = band_of(levels[1]), band_of(levels[#levels]) do
						for _, drop in ipairs(family.bands[tostring(band)] or {}) do
							have[drop.item] = true
						end
					end
					if leader then
						for _, drop in ipairs(family.leader_bonus or {}) do
							have[drop.item] = true
						end
					end
				end
			end
		end
		out[zone.id] = have
	end
	return out
end

function M.load(root)
	local json = dofile(root .. "/tools/r28_b4_quests/json.lua")
	local locality = dofile(root .. "/tools/r46_ck/locality.lua")
	local world = locality.load(root)
	world.locality = locality
	world.alchemy, world.ingredient_tiers = load_alchemy(root, json)
	world.gathering = dofile(root .. "/mods/ITEMS/grug_gathering/catalog.lua")
	world.zone_by_id = {}
	for _, zone in ipairs(world.zones) do world.zone_by_id[zone.id] = zone end
	local drops = load_drops(root, json, world.zones)
	for zone_id, items in pairs(drops) do
		local have = world.have[zone_id]
		for item in pairs(items) do
			if not have[item] then have[item] = {share = 100, how = "drop"} end
		end
	end
	return world
end

-- The zones a race checks a tier against (see the header), sorted by id.
function M.tier_zones(world, race, tier)
	local low = (tier - 1) * 10 + 1
	local high = low + 9
	local out = {}
	for _, zone in ipairs(world.zones) do
		local overlaps = zone.level_min <= high and zone.level_max >= low
		if overlaps and not zone.civic_no_hostiles then
			if tier >= 5 then
				if zone.id:match("^front_") then out[#out + 1] = zone.id end
			elseif zone.race_region == race and not zone.id:match("^front_") then
				out[#out + 1] = zone.id
			end
		end
	end
	table.sort(out)
	return out
end

-- The source of `token` in any of `zone_ids`: {zone, share, how, item} of
-- the zone with the largest host share, or nil.
function M.source_in(world, zone_ids, token)
	local best
	for _, zone_id in ipairs(zone_ids) do
		local found = world.locality.source(world, zone_id, token)
		if found and (not best or found.share > best.share) then
			best = {zone = zone_id, share = found.share, how = found.how, item = found.item}
		end
	end
	return best
end

-- Per recipe of `tier`: the inputs `race`'s tier zones lack (empty when the
-- recipe is brewable there).
function M.missing(world, race, tier)
	local zones = M.tier_zones(world, race, tier)
	local out = {}
	for _, row in ipairs(world.alchemy) do
		if row.tier == tier then
			local lacking = {}
			for _, token in ipairs(row.inputs) do
				if not M.source_in(world, zones, token) then lacking[#lacking + 1] = token end
			end
			out[#out + 1] = {row = row, missing = lacking}
		end
	end
	return out, zones
end

-- The herb rows of the gathering catalogue Alchemy uses: key -> row.
function M.herb_rows(world)
	local used = {}
	for _, row in ipairs(world.alchemy) do
		for _, token in ipairs(row.inputs) do used[token] = true end
	end
	local out = {}
	for _, row in ipairs(world.gathering.p9g_sources()) do
		if used[row.raw_item] then out[#out + 1] = row end
	end
	return out
end

-- The tiers whose recipes name `item`, ascending.
function M.tiers_using(world, item)
	local seen, out = {}, {}
	for _, row in ipairs(world.alchemy) do
		for _, token in ipairs(row.inputs) do
			if token == item and not seen[row.tier] then
				seen[row.tier] = true
				out[#out + 1] = row.tier
			end
		end
	end
	table.sort(out)
	return out
end

-- The biome ids one row's hosts name in `zone_id` that the zone really has,
-- with their summed share (percent of the zone's biome targets).
function M.host_biomes(world, row, zone_id)
	local zone = world.zone_by_id[zone_id]
	local has = {}
	for _, biome in ipairs(zone.biomes) do has[biome.id] = biome.share end
	local seen, out, share = {}, {}, 0
	for _, host in ipairs(row.hosts) do
		if (host.zone == nil or host.zone == zone_id) and has[host.biome] and
				not seen[host.biome] then
			seen[host.biome] = true
			out[#out + 1] = host.biome
			share = share + has[host.biome]
		end
	end
	table.sort(out)
	return out, share
end

M.band_of = band_of
return M

-- Round 46 lane CK: which Cooking recipes each zone can make from its own
-- ingredients, read from the shipped data (portable LuaJIT, never shipped).
--
--   local locality = dofile(ROOT .. "/tools/r46_ck/locality.lua")
--   local world = locality.load(ROOT)
--
-- "Local" means the ingredient's source exists in the zone:
--   * a wild plant (grug_mapgen world content): the zone is in its zone list
--     (or the list is empty), one of the zone's biomes hosts it and its
--     surface-level window overlaps the zone's level band; shore rows count
--     where their host biome exists (every zone has water margins); cave rows
--     (Cave Cap, Ember Moss) are under every zone;
--   * a gathering source (grug_gathering catalog): the zone is listed and one
--     of its biomes is a host for that zone; apples and blueberries grow on
--     their biomes' trees and bushes;
--   * a fish: the catch table of every ten-level band the zone's level band
--     touches (grug_fishing/catch.lua; every zone has water);
--   * raw meat: a mob of the zone's spawn file drops it (drops.json).
-- Each ingredient carries the zone's share of its host biomes (100 for
-- caves, fish and meat), so thin sources can be reported.

local M = {}

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function band_of(level)
	return math.floor((level - 1) / 10) + 1
end
M.band_of = band_of

-- The cooking catalog under a stub engine: dishes, raw assemblies and the
-- ingredient groups (captured from the group overrides it makes).
local function load_cooking(root)
	local groups = {}
	local saved = {core = rawget(_G, "core"), grug_classes = rawget(_G, "grug_classes"),
		grug_food = rawget(_G, "grug_food"), grug_jobs = rawget(_G, "grug_jobs"),
		grug_cooking = rawget(_G, "grug_cooking")}
	_G.core = {
		registered_items = setmetatable({}, {__index = function(_, name)
			return {description = name, groups = {}}
		end}),
		register_craftitem = function() end,
		override_item = function(name, def)
			for group in pairs(def.groups or {}) do
				if group:match("^grug_cooking_") then
					groups[group] = groups[group] or {}
					groups[group][#groups[group] + 1] = name
				end
			end
		end,
		register_craft = function() end,
		register_on_joinplayer = function() end,
	}
	_G.grug_classes = {register_on_arrival = function() end}
	_G.grug_food = {register_item = function() return true end}
	_G.grug_jobs = {register_ingredient_tier = function() end, DURATIONS = {food = 1},
		register_recipe = function() end,
		ingredient_list = function(tokens) return tokens end}
	dofile(root .. "/mods/ITEMS/grug_cooking/init.lua")
	local cooking = _G.grug_cooking
	for name, value in pairs(saved) do _G[name] = value end
	for _, members in pairs(groups) do table.sort(members) end
	local recipes = {}
	local raw = {}
	for _, row in ipairs(cooking.RAW_ASSEMBLIES) do raw[row.output] = row end
	for _, dish in ipairs(cooking.DISHES) do
		local assembly = raw[dish.item]
		recipes[#recipes + 1] = {id = assembly and assembly.id or dish.id,
			name = assembly and ("Raw " .. dish.description) or dish.description,
			dish = dish.description, tier = dish.tier, role = dish.role,
			inputs = dish.inputs or assembly.inputs}
	end
	table.sort(recipes, function(a, b)
		if a.tier ~= b.tier then return a.tier < b.tier end
		return a.name < b.name
	end)
	return recipes, groups, cooking.INGREDIENT_TIERS
end

local function load_catch(root)
	local saved = rawget(_G, "grug_fishing")
	_G.grug_fishing = {}
	dofile(root .. "/mods/ITEMS/grug_fishing/catch.lua")
	local tables = _G.grug_fishing.CATCH_TABLES
	_G.grug_fishing = saved
	local by_band = {}
	for band = 1, 6 do
		by_band[band] = {}
		for _, entry in ipairs(tables[band]) do
			if entry.fish then by_band[band][#by_band[band] + 1] = entry.name end
		end
	end
	return by_band
end

-- Every mob role a zone's spawn file names (belts, camps, leaders, critters).
local function collect_roles(value, out)
	if type(value) ~= "table" then return out end
	if type(value.role) == "string" then out[value.role] = true end
	for _, child in pairs(value) do collect_roles(child, out) end
	return out
end

local function load_meat_zones(root)
	local json = dofile(root .. "/tools/r28_b4_quests/json.lua")
	local data = root .. "/mods/ENTITIES/grug_mobs/data/"
	local family_meat = {}
	for _, row in ipairs(json.decode(read(data .. "drops.json"))) do
		for _, list in pairs(row.bands or {}) do
			for _, drop in ipairs(list) do
				if drop.item == "mobs:meat_raw" then family_meat[row.family] = true end
			end
		end
	end
	local role_meat = {}
	for _, row in ipairs(json.decode(read(data .. "subtypes.json"))) do
		role_meat[row.role] = family_meat[row.drops or row.family] or false
	end
	return function(zone_id)
		local handle = io.open(data .. "zones/" .. zone_id .. ".spawns.json", "rb")
		if not handle then return false end
		local text = handle:read("*a")
		handle:close()
		for role in pairs(collect_roles(json.decode(text), {})) do
			if role_meat[role] then return true end
		end
		return false
	end
end

-- The share (percent) of the zone's biomes among `hosts` (a set of biome
-- ids, or true for any biome).
local function host_share(zone, hosts)
	if hosts == true then return 100 end
	local share = 0
	for _, biome in ipairs(zone.biomes) do
		if hosts[biome.id] then share = share + biome.share end
	end
	return share
end

local function add(have, item, share, how)
	local old = have[item]
	if not old or old.share < share then have[item] = {share = share, how = how} end
end

function M.load(root)
	local world = {}
	world.zones = dofile(root .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").zones
	local plants = dofile(root .. "/mods/MAPGEN/grug_mapgen/wp40/world_content_catalog.lua").plants
	local gathering = dofile(root .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local fish = load_catch(root)
	local meat_in = load_meat_zones(root)
	world.recipes, world.groups, world.tiers = load_cooking(root)
	-- The fish group every caught fish carries (grug_mobs items.lua,
	-- grug_fishing init.lua).
	local all_fish = {}
	for band = 1, 6 do
		for _, name in ipairs(fish[band]) do all_fish[#all_fish + 1] = name end
	end
	world.groups.food_fish_raw = all_fish

	world.have = {}
	for _, zone in ipairs(world.zones) do
		local have = {}
		local zone_biomes = {}
		for _, biome in ipairs(zone.biomes) do zone_biomes[biome.id] = true end
		for _, row in ipairs(plants) do
			local listed = #row.zones == 0
			for _, id in ipairs(row.zones) do listed = listed or id == zone.id end
			if listed then
				if row.mode == "cave" then
					add(have, row.item, 100, "cave")
				elseif row.min <= zone.level_max and row.max >= zone.level_min then
					local hosts = {}
					for key in pairs(row.hosts) do
						if key == "any" then hosts = true break end
						hosts[key] = true
					end
					local share = host_share(zone, hosts)
					if share > 0 then
						add(have, row.item, share, row.shore ~= "none" and "shore" or "wild")
					end
				end
			end
		end
		for _, row in ipairs(gathering.p9g_sources()) do
			local listed = false
			for _, id in ipairs(row.zones) do listed = listed or id == zone.id end
			if listed then
				local hosts = {}
				for _, host in ipairs(row.hosts) do
					if host.zone == nil or host.zone == zone.id then hosts[host.biome] = true end
				end
				local share = host_share(zone, hosts)
				if share > 0 then add(have, row.raw_item, share, "gathering") end
			end
		end
		for _, row in ipairs(gathering.reuse_sources()) do
			if row.harvest_kind == "existing_food" then
				local hosts = {}
				for _, feature in ipairs(row.feature_ids) do
					for biome in pairs(zone_biomes) do
						if feature:sub(1, #biome - 5) == biome:sub(6) then hosts[biome] = true end
					end
				end
				local share = host_share(zone, hosts)
				if share > 0 then
					for _, item in ipairs(row.outputs) do add(have, item, share, "tree") end
				end
			end
		end
		for band = band_of(zone.level_min), band_of(zone.level_max) do
			for _, name in ipairs(fish[band]) do add(have, name, 100, "fishing") end
		end
		if meat_in(zone.id) then add(have, "mobs:meat_raw", 100, "mobs") end
		world.have[zone.id] = have
	end
	return world
end

-- The source of `token` a zone has: {share, how, item}, or nil. A group
-- counts its best-placed member.
function M.source(world, zone_id, token)
	local have = world.have[zone_id]
	local group = token:match("^group:(.+)$")
	if not group then
		local found = have[token]
		return found and {share = found.share, how = found.how, item = token} or nil
	end
	local best
	for _, member in ipairs(world.groups[group] or {}) do
		local found = have[member]
		if found and (not best or found.share > best.share) then
			best = {share = found.share, how = found.how, item = member}
		end
	end
	return best
end

-- The recipes `zone_id` can cook locally; each with its thinnest input share.
function M.cookable(world, zone_id)
	local out = {}
	for _, recipe in ipairs(world.recipes) do
		local thinnest, ok = 100, true
		for _, token in ipairs(recipe.inputs) do
			local found = M.source(world, zone_id, token)
			if not found then ok = false break end
			thinnest = math.min(thinnest, found.share)
		end
		if ok then out[#out + 1] = {recipe = recipe, share = thinnest} end
	end
	return out
end

return M

-- The ingredient source index (Round 57 lane DETAILS, round57-plan.md ruling
-- 5): where an item comes from, generated from the registered data, for the
-- recipe details pages. A pure module: `build(data)` takes plain tables and
-- answers queries; `game_data()` collects those tables from the loaded mods,
-- and `grug_jobs.item_sources` builds the index once, at its first use
-- (every mod has loaded by then: grug_jobs loads before grug_traders).
--
-- A source is a table with `kind` and the fields a player needs:
--   recipe   id, area, profession (nil in Basic), tier, station, count
--   furnace  input (an item or "group:<name>"), count
--   alloy    inputs {a, b}, count, time (the dual furnace)
--   vendor   vendor (a shelf kind: "quartermaster" for the core stock), label,
--            where ("every town and capital", "capitals"), price (copper)
--   drop     key (the drop table: a family or a sub-type's `drops`), band,
--            levels {lo, hi}, chance (1 in n), min, max, leader (only the
--            family's leaders), mobs (sub-type names in the band); a static
--            drop has mob (the entity) and label instead of key and band
--   gather   node, zones (ids, empty for "wherever its ground is"), levels
--            or depth {y_min, y_max}, alchemy_tier (a healing herb)
--   mining   resource, label, harvest_tier, pick_level, tiers (the rock
--            tiers it lies in), lower_half (a tier where it lies only in
--            the band's lower half)
--   tree     node, label (a log, or a sapling from leaves)
--   fishing  band, levels, weight (percent)
--   farming  crop, seed
--   dig      node, label (natural ground and plants)
--   use      text (a fixed line where an action makes the item: FIXED)
-- Each item's list is sorted by kind (KIND_ORDER), then by a stable key.
-- Group ingredients resolve to their members (`members`); a member hidden
-- from the creative inventory (a tree's shape node) is no kind of its own.

local M = {}

M.KIND_ORDER = {"recipe", "furnace", "alloy", "vendor", "drop", "gather",
	"mining", "tree", "fishing", "farming", "dig", "use"}
local KIND_RANK = {}
for index, kind in ipairs(M.KIND_ORDER) do KIND_RANK[kind] = index end

-- Where a shelf's vendor stands (settlements.md "Profession vendors"): a
-- race Quartermaster in every start town and capital, the faction
-- Quartermasters and the profession shops in the capitals.
M.WHERE_CORE = "every town and capital"
M.WHERE_SHOP = "capitals"

-- Items an action makes, which no data names (the coordinator's ruling,
-- Round 57): item -> the line the details page shows.
M.FIXED = {
	["grug_farming:water_bucket"] = "Fill an Empty Iron Bucket at water",
}

local function band_levels(band)
	return {(band - 1) * 10 + 1, band * 10}
end

local function first_line(def, name)
	local text = def and def.description or ""
	text = text:match("^[^\n]*") or ""
	return text ~= "" and text or name
end

-- The item names a node's drop yields: its own name without a drop, the
-- name of a drop string, every item of a drop table's entries.
local function drop_names(name, def)
	local drop = def.drop
	if drop == nil then return {name} end
	if type(drop) == "string" then
		local item = drop:match("^%s*(%S+)")
		return item and {item} or {}
	end
	local out, seen = {}, {}
	for _, entry in ipairs(type(drop) == "table" and drop.items or {}) do
		for _, item in ipairs(entry.items or {}) do
			item = item:match("^%s*(%S+)")
			if item and not seen[item] then
				seen[item] = true
				out[#out + 1] = item
			end
		end
	end
	return out
end

-- A mob's name: its definition's description without escapes.
local function entity_label(def, name)
	local text = (def.description or ""):gsub("\27%([^)]*%)", ""):gsub("\27[EF]", "")
	text = text:match("^[^\n]*") or ""
	return text ~= "" and text or name
end

local function sorted_keys(map)
	local keys = {}
	for key in pairs(map) do keys[#keys + 1] = key end
	table.sort(keys)
	return keys
end

-- `data` (every field optional; game_data below fills them):
--   items        name -> definition (registered_items, nodes included)
--   recipes      the registry's records
--   cooking      {output, count, input} (the engine's cooking recipes)
--   alloys       {output, inputs, time} (grug_smelting.RECIPES)
--   shelves      {vendor, label, where, item, price}
--   drop_tables  key -> {bands = {[b] = rows}, leader_bonus = rows}
--   subtypes     role -> {drops, display, levels, leader}
--   entities     name -> definition (the mobs' static drops)
--   herbs        grug_gathering.p9g_sources(); reuse its reuse_sources()
--   plants       the world content catalog's wild plants
--   resources    grug_materials.RESOURCES; ore_rows key -> {denominators,
--                lower_half_of} (the mapgen's resource rows)
--   catch        grug_fishing.CATCH_TABLES; catch_total
--   crops        grug_farming.CROPS (a list of {key, harvest_item, seed, stages})
--   zone         function(zone id) -> {display_name, level_min, level_max}
--   name_of      function(item name) -> its name (default: the description's
--                first line; the game passes grug_core.item_name)
--   world_nodes  extra natural node names (the mapgen's plants and reef)
--   fixed        item -> a fixed line (M.FIXED)
function M.build(data)
	local items = data.items or {}
	local first_line = data.name_of and function(_, name) return data.name_of(name) end or
		first_line
	local by_item = {}
	local placed = {} -- item, kind and node: a node yields an item once
	local function add(item, source)
		if type(item) ~= "string" or item == "" then return end
		if source.node then
			local key = item .. "\0" .. source.kind .. "\0" .. source.node
			if placed[key] then return end
			placed[key] = true
		end
		local list = by_item[item]
		if not list then
			list = {}
			by_item[item] = list
		end
		list[#list + 1] = source
	end
	local function groups_of(name)
		local def = items[name]
		return def and def.groups or {}
	end

	-- Recipes, furnaces, alloys.
	for _, recipe in ipairs(data.recipes or {}) do
		add(recipe.output, {kind = "recipe", id = recipe.id, area = recipe.area,
			profession = recipe.profession, tier = recipe.tier,
			station = recipe.station, count = recipe.count, sort = recipe.id})
	end
	for _, row in ipairs(data.cooking or {}) do
		add(row.output, {kind = "furnace", input = row.input, count = row.count or 1,
			sort = row.input})
	end
	for _, row in ipairs(data.alloys or {}) do
		local output, count = row.output:match("^(%S+)%s*(%d*)$")
		add(output, {kind = "alloy", inputs = {row.inputs[1], row.inputs[2]},
			count = tonumber(count) or 1, time = row.time,
			sort = row.inputs[1] .. "+" .. row.inputs[2]})
	end

	-- Vendors: one source per shelf that offers the item (its lowest price
	-- when a shelf lists it twice).
	local offered = {}
	for _, row in ipairs(data.shelves or {}) do
		local key = row.item .. "\0" .. row.vendor
		local seen = offered[key]
		if seen then
			if row.price < seen.price then seen.price = row.price end
		else
			seen = {kind = "vendor", vendor = row.vendor, label = row.label,
				where = row.where, price = row.price,
				sort = (row.vendor == "quartermaster" and "0" or "1") .. row.vendor}
			offered[key] = seen
			add(row.item, seen)
		end
	end

	-- Drops. A sub-type takes its drop table's rows in the bands the table
	-- covers and its definition's static drops elsewhere (grug_mobs
	-- band_drop_rows); a leader adds the table's leader rows.
	local tables = data.drop_tables or {}
	local subtypes = data.subtypes or {}
	local entities = data.entities or {}
	local members = {} -- drop key -> sub-types
	for _, role in ipairs(sorted_keys(subtypes)) do
		local sub = subtypes[role]
		members[sub.drops] = members[sub.drops] or {}
		table.insert(members[sub.drops], sub)
	end
	local function mob_names(key, lo, hi, leaders_only)
		local names, seen = {}, {}
		local list = {}
		for _, sub in ipairs(members[key] or {}) do
			if sub.levels[1] <= hi and lo <= sub.levels[2] and
					(not leaders_only or sub.leader) and not seen[sub.display] then
				seen[sub.display] = true
				list[#list + 1] = sub
			end
		end
		table.sort(list, function(a, b)
			if a.levels[1] ~= b.levels[1] then return a.levels[1] < b.levels[1] end
			return a.display < b.display
		end)
		for index, sub in ipairs(list) do names[index] = sub.display end
		return names
	end
	for _, key in ipairs(sorted_keys(tables)) do
		local entry = tables[key]
		for band = 1, 6 do
			local levels = band_levels(band)
			for _, row in ipairs(entry.bands[band] or {}) do
				add(row.name, {kind = "drop", key = key, band = band, levels = levels,
					chance = row.chance, min = row.min, max = row.max,
					mobs = mob_names(key, levels[1], levels[2]),
					sort = key .. "/" .. band})
			end
		end
		for _, row in ipairs(entry.leader_bonus or {}) do
			local names = mob_names(key, 1, 60, true)
			add(row.name, {kind = "drop", key = key, leader = true,
				chance = row.chance, min = row.min, max = row.max, mobs = names,
				sort = key .. "/leader"})
		end
	end
	local function static_drops(name, def, label, lo, hi)
		for _, row in ipairs(def.drops or {}) do
			if type(row) == "table" and type(row.name) == "string" then
				add(row.name, {kind = "drop", mob = name, label = label,
					levels = lo and {lo, hi} or nil, chance = row.chance or 1,
					min = row.min or 1, max = row.max or 1, sort = "~" .. name})
			end
		end
	end
	for _, name in ipairs(sorted_keys(entities)) do
		local def = entities[name]
		local role = name:match("^grug_mobs:(.+)$")
		local sub = role and subtypes[role]
		if type(def.drops) == "table" and #def.drops > 0 then
			if sub then
				-- The bands of its levels that its table leaves uncovered.
				local entry = tables[sub.drops]
				local lo, hi
				for band = 1, 6 do
					local levels = band_levels(band)
					if levels[1] <= sub.levels[2] and sub.levels[1] <= levels[2] and
							not (entry and entry.bands[band]) then
						lo = lo or math.max(levels[1], sub.levels[1])
						hi = math.min(levels[2], sub.levels[2])
					end
				end
				if lo then static_drops(name, def, sub.display, lo, hi) end
			elseif not (role and tables[role]) then
				static_drops(name, def, entity_label(def, name),
					def._grug_min_level, def._grug_max_level or def._grug_min_level)
			end
		end
	end

	-- Gathering: the herb and food sources (zones by id) and the wild plants
	-- of the world content catalog (zones, levels or a cave depth).
	local covered = {} -- nodes a category below already explains
	for _, row in ipairs(data.herbs or {}) do
		covered[row.source_node] = true
		local zones = {}
		for index, zone in ipairs(row.zones or {}) do zones[index] = zone end
		table.sort(zones)
		add(row.raw_item, {kind = "gather", node = row.source_node, zones = zones,
			alchemy_tier = row.harvest_kind == "healing_herb" and row.required_group or nil,
			sort = row.source_node})
	end
	-- Fruit the gathering catalog reuses from trees and bushes (apples,
	-- blueberries); its signature woods are logs, which the trees below give.
	for _, row in ipairs(data.reuse or {}) do
		if row.harvest_kind == "existing_food" then
			for _, item in ipairs(row.outputs or {}) do
				local node = row.source_items[1]
				add(item, {kind = "tree", node = node, label = first_line(items[node], node),
					sort = node})
			end
		end
	end
	for _, row in ipairs(data.plants or {}) do
		covered[row.node] = true
		local zones = {}
		for index, zone in ipairs(row.zones or {}) do zones[index] = zone end
		table.sort(zones)
		local source = {kind = "gather", node = row.node, zones = zones, sort = row.node}
		if row.mode == "cave" then
			source.depth = {row.min, row.max}
		else
			source.levels = {row.min, row.max}
		end
		local herb = (groups_of(row.node).grug_healing_herb or 0)
		if herb > 0 then source.alchemy_tier = herb end
		add(row.item, source)
	end

	-- Mining: every resource, in the rock tiers its row places it.
	for _, resource in ipairs(data.resources or {}) do
		covered[resource.natural_node] = true
		local row = (data.ore_rows or {})[resource.key]
		local tiers = {}
		if row then
			for tier = 1, 6 do
				if row.denominators[tier] then tiers[#tiers + 1] = tier end
			end
		else
			tiers[1] = resource.harvest_tier
		end
		local def = items[resource.natural_node] or {}
		add(resource.raw_item, {kind = "mining", resource = resource.key,
			label = resource.name, node = resource.natural_node,
			harvest_tier = resource.harvest_tier,
			pick_level = resource.pick_level or ((def.groups or {}).level or 0),
			tiers = tiers, lower_half = row and row.lower_half_of or nil,
			sort = resource.key})
	end

	-- Fishing and farming.
	local catch_total = data.catch_total or 100
	for band = 1, 6 do
		for _, row in ipairs((data.catch or {})[band] or {}) do
			add(row.name, {kind = "fishing", band = band, levels = band_levels(band),
				weight = math.floor(row.weight * 100 / catch_total + 0.5),
				sort = tostring(band)})
		end
	end
	for _, row in ipairs(data.crops or {}) do
		for _, stage in ipairs(row.stages or {}) do covered[stage] = true end
		add(row.harvest_item, {kind = "farming", crop = row.key, seed = row.seed,
			sort = row.key})
	end

	-- Trees and natural nodes: what digging yields. A log comes from its
	-- tree (shape nodes yield the same log and add nothing); leaves give
	-- saplings and fruit; the natural ground, plants and the mapgen's other
	-- world nodes give what they drop.
	local extra = {}
	for _, name in ipairs(data.world_nodes or {}) do extra[name] = true end
	for _, name in ipairs(sorted_keys(items)) do
		local def = items[name]
		local groups = def.groups or {}
		local tree = (groups.tree or 0) > 0 or (groups.leaves or 0) > 0
		local natural = (groups.grug_natural or 0) > 0 or (groups.flora or 0) > 0 or
			extra[name]
		if def.type == "node" and not covered[name] and (tree or natural) and
				(groups.grug_resource or 0) == 0 and (groups.grug_gathering_source or 0) == 0 then
			for _, item in ipairs(drop_names(name, def)) do
				local shape = tree and item ~= name and (groups.not_in_creative_inventory or 0) > 0
				if not shape and items[item] then
					add(item, {kind = tree and "tree" or "dig", node = name,
						label = first_line(def, name), sort = name})
				end
			end
		end
	end

	for _, item in ipairs(sorted_keys(data.fixed or {})) do
		if items[item] then add(item, {kind = "use", text = data.fixed[item], sort = item}) end
	end

	for _, list in pairs(by_item) do
		table.sort(list, function(a, b)
			local ra, rb = KIND_RANK[a.kind], KIND_RANK[b.kind]
			if ra ~= rb then return ra < rb end
			return a.sort < b.sort
		end)
	end

	local index = {by_item = by_item}
	local empty = {}
	-- The sources of one item (never write into the list).
	function index.sources(item)
		return by_item[item] or empty
	end
	-- The registered members of a group, sorted, without hidden members.
	local member_cache = {}
	function index.members(group)
		local cached = member_cache[group]
		if cached then return cached end
		cached = {}
		for _, name in ipairs(sorted_keys(items)) do
			local groups = items[name].groups or {}
			if (groups[group] or 0) > 0 and (groups.not_in_creative_inventory or 0) == 0 then
				cached[#cached + 1] = name
			end
		end
		member_cache[group] = cached
		return cached
	end
	-- Whether an ingredient token (an item or "group:<name>") has a source:
	-- a group when any member has one.
	function index.has_source(token)
		local group = token:match("^group:(.+)$")
		if not group then return by_item[token] ~= nil end
		for _, name in ipairs(index.members(group)) do
			if by_item[name] then return true end
		end
		return false
	end
	-- An item's name: the first line of its description.
	function index.label(item)
		return first_line(items[item], item)
	end
	-- A zone's record by id, or nil.
	function index.zone(id)
		return data.zone and data.zone(id) or nil
	end
	return index
end

-- The node names of a schematic file (.mts, version 4): the header's name
-- list, which comes before the compressed node data.
local function mts_names(path)
	local handle = io.open(path, "rb")
	if not handle then return {} end
	local bytes = handle:read("*a")
	handle:close()
	local function u16(offset)
		local high, low = bytes:byte(offset, offset + 1)
		return high and low and high * 256 + low or 0
	end
	if bytes:sub(1, 4) ~= "MTSM" or u16(5) ~= 4 then return {} end
	local offset = 13 + u16(9) -- signature, version, size; one byte per y slice
	local names = {}
	for index = 1, u16(offset) do
		offset = offset + 2
		local length = u16(offset)
		names[index] = bytes:sub(offset + 2, offset + 1 + length)
		offset = offset + length
	end
	return names
end

-- The tables `build` takes, from the loaded mods (after load). The pure
-- mapgen data files are read from grug_mapgen's folder: the wild plants
-- (wp40/world_content_catalog.lua), and the ore rows and the decorations
-- (wp40/r7_r6_manifest.lua; a decoration's schematic names its nodes).
function M.game_data()
	local data = {items = core.registered_items, recipes = grug_jobs.recipes,
		entities = core.registered_entities, name_of = grug_core.item_name, fixed = M.FIXED}
	data.cooking = {}
	for _, name in ipairs(sorted_keys(core.registered_items)) do
		for _, recipe in ipairs(core.get_all_craft_recipes(name) or {}) do
			local output, count = (recipe.output or ""):match("^(%S+)%s*(%d*)$")
			local input = recipe.items and recipe.items[1]
			if recipe.method == "cooking" and output == name and type(input) == "string" then
				data.cooking[#data.cooking + 1] = {output = name,
					count = tonumber(count) or 1, input = input:match("^(%S+)")}
			end
		end
	end
	local smelting = rawget(_G, "grug_smelting")
	data.alloys = smelting and smelting.RECIPES or {}
	local traders = rawget(_G, "grug_traders")
	data.shelves = {}
	if traders then
		for _, entry in ipairs(traders.stock or {}) do
			data.shelves[#data.shelves + 1] = {vendor = "quartermaster",
				label = "Quartermaster", where = M.WHERE_CORE, item = entry.item,
				price = entry.price}
		end
		for _, kind in ipairs(sorted_keys(traders.profession_stock or {})) do
			local vendor = (traders.vendors or {})["grug_traders:vendor_" .. kind]
			local label = vendor and vendor.nametag or kind
			local shelf = {}
			for _, entry in ipairs(traders.profession_stock[kind]) do shelf[#shelf + 1] = entry end
			if vendor and vendor.brackets and traders.vendor_bracket_stock then
				for _, entry in ipairs(traders.vendor_bracket_stock(vendor, 1)) do
					shelf[#shelf + 1] = entry
				end
			end
			for _, entry in ipairs(shelf) do
				data.shelves[#data.shelves + 1] = {vendor = kind, label = label,
					where = M.WHERE_SHOP, item = entry.item, price = entry.price}
			end
		end
	end
	local mobs = rawget(_G, "grug_mobs")
	data.drop_tables = mobs and mobs.drop_tables and mobs.drop_tables() or {}
	data.subtypes = mobs and mobs.subtypes or {}
	local gathering = rawget(_G, "grug_gathering")
	data.herbs = gathering and gathering.p9g_sources() or {}
	data.reuse = gathering and gathering.reuse_sources() or {}
	local materials = rawget(_G, "grug_materials")
	data.resources = materials and materials.RESOURCES or {}
	local mapgen = core.get_modpath("grug_mapgen")
	if mapgen then
		local catalog = dofile(mapgen .. "/wp40/world_content_catalog.lua")
		data.plants = catalog.plants
		data.world_nodes = {}
		for _, list in ipairs({catalog.reef, catalog.freshwater, catalog.seagrass}) do
			for _, name in ipairs(list or {}) do data.world_nodes[#data.world_nodes + 1] = name end
		end
		local manifest = dofile(mapgen .. "/wp40/r7_r6_manifest.lua")()
		data.ore_rows = {}
		for _, row in ipairs(manifest.resources) do data.ore_rows[row.key] = row end
		local schematics = (core.get_modpath("default") or "") .. "/schematics/"
		for _, row in ipairs(manifest.decorations) do
			if row.kind == "simple" then
				data.world_nodes[#data.world_nodes + 1] = row.asset_or_node
			elseif row.kind == "template" and row.asset_or_node:match("^[%w_]+%.mts$") then
				for _, name in ipairs(mts_names(schematics .. row.asset_or_node)) do
					data.world_nodes[#data.world_nodes + 1] = name
				end
			end
		end
	end
	local fishing = rawget(_G, "grug_fishing")
	data.catch = fishing and fishing.CATCH_TABLES or {}
	data.catch_total = fishing and fishing.CATCH_TOTAL or 100
	local farming = rawget(_G, "grug_farming")
	data.crops = farming and farming.CROPS or {}
	local zones = rawget(_G, "grug_zones")
	data.zone = zones and function(id) return zones.get(id) end or nil
	return data
end

grug_jobs.sources = M

-- The index of the loaded game, built at its first use.
local game_index
function grug_jobs.item_sources()
	if not game_index then game_index = M.build(M.game_data()) end
	return game_index
end

return M

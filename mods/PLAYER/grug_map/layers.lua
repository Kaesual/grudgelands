-- The map window's marker layers (Round 47 lane ML, the work package
-- docs/planning/round47-map-layers.md; docs/design/world_map.md "Map
-- window"). The player picks one layer at a time with the buttons under the
-- map (window.lua); the player's and the party's arrows show in every one.
--
--   Quests    the own faction's quest givers by their state (the "quest"
--             provider, the minimap's precedence: ready, available, active,
--             locked)
--   Bosses    the six kings, the two dragons (a dragon arena and its dragon
--             are one icon, bake.lua SAME_PLACE), the rift boss at his
--             clash site and the rare dens, both factions
--   Trainers  the own faction's trainers, the Riding trainer, the mender,
--             the Crownbinder, the Decor Merchant and the Housing Steward
--             (the "service" provider)
--   Towns     every start, capital, village and outpost of both factions,
--             plus the own innkeepers, the home, the Claim Stone and the
--             discovered waystones (the "home" and "waypoint" providers)
--   POIs      bandit and Mirefolk camps, mines and gem camps, clash sites,
--             both factions
--   PvP       the two fortresses and the war camps
--   Zones     every zone's name and level band as text (zone_labels.lua)
--   None      only the arrows
--
-- Settlements, camps, kings, dragons, the rift boss and the zone labels are
-- the same for every player: built once at start from the settlement
-- registry, the boss registries and the world authority, never from live
-- entities or loaded terrain. Each marker carries its tooltip text in
-- `detail`. The icons are the former baked art (art/baked_<kind>.png,
-- shipped as textures/grug_map_<kind>.png).
local modpath = core.get_modpath(core.get_current_modname())
local atlas = grug_map.atlas
local icons = dofile(modpath .. "/settlement_icons.lua")
local bake = dofile(modpath .. "/bake.lua")
local zone_labels = dofile(modpath .. "/zone_labels.lua")

local L = {}
grug_map.layers = L
L.zone_labels = zone_labels

-- Button order (the work package's §8 default: as in its table); the label
-- is the button's text, the title its tooltip.
L.LIST = {
	{id = "quests", label = "Quests", title = "Quest givers", providers = {quest = true}},
	{id = "bosses", label = "Bosses", title = "Kings & bosses", providers = {boss = true}},
	{id = "trainers", label = "Trainers", title = "Trainers & traders",
		providers = {service = true}},
	{id = "towns", label = "Towns", title = "Settlements & travel",
		providers = {settlement = true, home = true, waypoint = true}},
	{id = "pois", label = "POIs", title = "Points of interest", providers = {poi = true}},
	{id = "pvp", label = "PvP", title = "PvP", providers = {pvp = true}},
	{id = "zones", label = "Zones", title = "Zones", zones = true},
	{id = "none", label = "None", title = "No markers"},
}
L.BY_ID = {}
for _, layer in ipairs(L.LIST) do L.BY_ID[layer.id] = layer end
-- The layer of a window's first opening; kept until the player leaves.
L.DEFAULT = "quests"
-- The arrows' providers, asked in every mode.
L.ARROWS = {player = true, party = true}

-- Draw order inside a layer, bottom to top: the baked layer's (bake.KINDS,
-- the bosses last), the rift boss with the kings, then the other kinds by
-- atlas.collect_markers' own order.
L.ORDER = {}
for index, kind in ipairs(bake.KINDS) do L.ORDER[kind] = index end
L.ORDER.rift_boss = L.ORDER.king

-- provider name -> the static rows of its layer
local rows = {settlement = {}, boss = {}, poi = {}, pvp = {}}
L.rows = rows
-- The zone labels {id, name, band, x, z} in zone order, and the placement
-- figures for the log and the report.
L.zones, L.zone_stats = {}, nil

local function texture(kind)
	return "grug_map_" .. kind .. ".png"
end

-- A boss's name with its level where the registry has a fixed one:
-- "King of Highcourt (level 65)".
local function with_level(name, entity)
	local level = entity and grug_mobs.fixed_level(entity)
	return level and ("%s (level %d)"):format(name, level) or name
end

local function entity_name(entity, fallback)
	local def = core.registered_entities[entity]
	return def and def.description or fallback
end

-- Settlements by layer, kings at their sockets, the dragons, the rift boss.
local function build_rows()
	local faction_of_race = {}
	for _, identity in ipairs(grug_core.start_identities()) do
		faction_of_race[identity.race_id] = identity.faction_id
	end
	local dragons = grug_mobs.dragon_map_markers()
	local function near_dragon(anchor)
		for _, dragon in ipairs(dragons) do
			local dx, dz = anchor.x - dragon.pos.x, anchor.z - dragon.pos.z
			if dx * dx + dz * dz <= bake.SAME_PLACE * bake.SAME_PLACE then return true end
		end
		return false
	end
	local providers = {towns = "settlement", pois = "poi", pvp = "pvp", bosses = "boss"}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local kind, layer = icons.kind(row.slot), icons.layer(row.slot)
		local name = row.display_name or row.key
		local provider = layer and providers[layer]
		if provider and not (kind == "dragon" and near_dragon(row.anchor)) then
			local detail = name
			local word = icons.poi_word(row.slot)
			if word then detail = word .. ": " .. name end
			if kind == "rare_den" then
				-- The rare's level comes from the field at its spawn place
				-- (grug_mobs rares.lua), the den on its route.
				local ok, level = pcall(grug_core.mob_level_at, row.anchor)
				detail = name .. "\nRare den" ..
					((ok and type(level) == "number") and (", level " .. level) or "")
			end
			local list = rows[provider]
			list[#list + 1] = {id = row.key, label = name, detail = detail, kind = kind,
				texture = texture(kind), position = row.anchor,
				faction = faction_of_race[row.race_id]}
		end
		for _, socket in ipairs(grug_core.settlement_sockets_at(row.key)) do
			if socket.role == "king" and socket.spawn ~= false then
				local entity = "grug_mobs:king_" .. row.race_id
				local king = entity_name(entity, "King")
				rows.boss[#rows.boss + 1] = {id = "king:" .. row.key .. "/" .. socket.id,
					label = king, detail = with_level(king, entity), kind = "king",
					texture = texture("king"), position = socket.pos,
					faction = faction_of_race[row.race_id]}
			end
		end
	end
	for _, dragon in ipairs(dragons) do
		rows.boss[#rows.boss + 1] = {id = dragon.id, label = dragon.name,
			detail = with_level(dragon.name, dragon.entity), kind = "dragon",
			texture = texture("dragon"), position = dragon.pos}
	end
	-- The rift boss at his clash site (grug_mobs rift.lua), with the clash
	-- site's crossed swords.
	local rules = grug_mobs.rift_rules
	local site = rules and grug_mobs.spawn_regions.place(rules.SITE)
	if site then
		local name = entity_name("grug_mobs:rift_boss", "Rift boss")
		rows.boss[#rows.boss + 1] = {id = "rift_boss", label = name,
			detail = with_level(name, "grug_mobs:rift_boss"), kind = "rift_boss",
			texture = texture("clash"), position = {x = site.x, y = site.y, z = site.z}}
	end
end

-- The zone labels: the grid, the reference size (a 1920x1080 window at GUI
-- scale 1 at zoom 1, the map's units to nodes) and the region names' baked
-- boxes as obstacles, then the placement.
L.REFERENCE = {size = {x = 1920, y = 1080}, max_formspec_size = {x = 1920 / 72, y = 1080 / 72},
	real_gui_scaling = 1}
-- The collision count is also logged for the user's small window (1035x696,
-- 53.3 px per unit like 720p).
L.SMALL = {size = {x = 1035, y = 696},
	max_formspec_size = {x = 1035 / (0.5555 * 96), y = 696 / (0.5555 * 96)}, real_gui_scaling = 1}
local function place_zones()
	if not grug_core.zone_authority_installed() then return end
	local started = core.get_us_time()
	local view = atlas.view()
	local W = grug_map.window
	local layout = W.layout(W.window_size(L.REFERENCE))
	local nodes = (view.max_x - view.min_x) / layout.map_w
	local metrics = zone_labels.metrics(L.REFERENCE)
	-- The baked region names, drawn at normal (bake.SCALE) over the 1080 px
	-- wide image: their glyph box in nodes.
	local art = dofile(modpath .. "/baked_art.lua")
	local per_px = (view.max_x - view.min_x) / 1080 * bake.SCALE.normal
	local names = {}
	for _, label in ipairs(bake.REGION_LABELS) do
		local box = bake.layout(art.font, label[1], label.wrap)
		names[#names + 1] = {x = label[2], z = label[3], soft = true,
			rx = box.width * per_px / 2, rz = box.height * per_px / 2}
	end
	local grid, seen = zone_labels.sample(view, grug_zones.water_class_at, grug_zones.id_at)
	local sampled = core.get_us_time()
	local records, order = {}, {}
	for id in pairs(seen) do
		records[id] = grug_zones.get(id)
		order[#order + 1] = id
	end
	table.sort(order, function(a, b) return records[a].numeric_id < records[b].numeric_id end)
	local wanted, by_id = {}, {}
	for _, id in ipairs(order) do
		local record = records[id]
		local name, band = record.display_name or id, zone_labels.band(record)
		local box = zone_labels.box(name, band, metrics)
		local row = {id = id, name = name, band = band, rx = box.w / 2 * nodes,
			rz = box.h / 2 * nodes}
		wanted[#wanted + 1] = row
		by_id[id] = row
	end
	local points = zone_labels.place(grid, wanted, names)
	local placed = {}
	L.zones = {}
	for _, row in ipairs(wanted) do
		local point = points[row.id]
		if point then
			L.zones[#L.zones + 1] = {id = row.id, name = row.name, band = row.band,
				x = point.x, z = point.z}
			placed[#placed + 1] = {x = point.x, z = point.z, rx = row.rx, rz = row.rz}
		end
	end
	local overlapping, on_names = zone_labels.overlaps(placed, names)
	-- The same labels' boxes at 1x on the small window.
	local small_layout = W.layout(W.window_size(L.SMALL))
	local small_nodes = (view.max_x - view.min_x) / small_layout.map_w
	local small_metrics = zone_labels.metrics(L.SMALL)
	local small = {}
	for _, zone in ipairs(L.zones) do
		local box = zone_labels.box(zone.name, zone.band, small_metrics)
		small[#small + 1] = {x = zone.x, z = zone.z, rx = box.w / 2 * small_nodes,
			rz = box.h / 2 * small_nodes}
	end
	local small_overlapping, small_on_names = zone_labels.overlaps(small, names)
	L.zone_stats = {zones = #L.zones, overlapping = overlapping, on_names = on_names,
		small_overlapping = small_overlapping, small_on_names = small_on_names,
		grid_s = (sampled - started) / 1e6, total_s = (core.get_us_time() - started) / 1e6}
	core.log("action", ("[grug_map] placed %d zone labels in %.3f s (grid %dx%d sampled " ..
		"in %.3f s); at 1x on 1920x1080 %d overlapping pairs, %d over a region name; " ..
		"on 1035x696 %d and %d"):format(#L.zones, L.zone_stats.total_s, grid.nx, grid.nz,
		L.zone_stats.grid_s, overlapping, on_names, small_overlapping, small_on_names))
end

-- After providers.lua's hook (registered earlier, so it runs first) and the
-- region maps of grug_mobs (a dependency, its hooks run before ours).
core.register_on_mods_loaded(function()
	build_rows()
	place_zones()
end)

for name, list in pairs(rows) do
	atlas.register_marker_provider(name, function() return list end)
end

return L

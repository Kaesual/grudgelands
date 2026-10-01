-- Disposable engine probe (Round 28 Lane C0 tools). Never shipped:
-- tools/r28_design/dump_items.sh stages it through tools/luanti_headless.sh.
--
-- After every mod has loaded it writes the REAL registry as JSON into the
-- world directory: every item (craftitem, tool, node) with its groups, tier
-- hints and known sources, every alias, every mobs_redo entity with its drops,
-- and the content-curation lists. tools/r28_design/items_catalog.py turns the
-- dump into docs/planning/round28/items/existing.{json,md}.
--
-- "Existing" means without the design catalogue's own registrations: the
-- sub-types (grug_mobs.subtype) and the loot items grug_mobs registered from
-- data/items.json (they carry _grug_icon_brief). The design tools read those
-- from the catalogue itself, so a role or item there never "collides" with
-- its own shipped registration.

local P = "[r28_items_probe] "
local function log(msg) core.log("action", P .. msg) end

local function plain(text)
	if type(text) ~= "string" then return nil end
	if core.get_translated_string then text = core.get_translated_string("en", text) end
	text = core.strip_colors(text)
	-- Leftover translation markers (unknown domain) and escape bytes.
	text = text:gsub("\27%([^)]*%)", ""):gsub("\27.", "")
	return text
end

local function first_line(text)
	text = plain(text)
	if not text then return nil end
	return (text:match("^([^\n]*)"))
end

local function scalar_fields(def)
	local out
	for key, value in pairs(def) do
		local kind = type(value)
		if type(key) == "string" and key:sub(1, 6) == "_grug_" and
				(kind == "string" or kind == "number" or kind == "boolean") then
			out = out or {}
			out[key] = value
		end
	end
	return out
end

local function push(map, key, value)
	local list = map[key]
	if not list then list = {}; map[key] = list end
	list[#list + 1] = value
end

local function drop_names(drop, out)
	if type(drop) == "string" then
		local name = drop:match("^(%S+)")
		if name and name ~= "" then out[name] = true end
	elseif type(drop) == "table" then
		for _, row in ipairs(drop.items or {}) do
			for _, stack in ipairs(row.items or {}) do drop_names(stack, out) end
		end
	end
end

local function run()
	-- Sources, indexed by item name.
	local profession_routes, mob_drops, node_drops, fishing = {}, {}, {}, {}
	for _, recipe in ipairs(grug_jobs.recipes or {}) do
		local output = type(recipe.output) == "string" and recipe.output:match("^(%S+)")
		if output then
			push(profession_routes, output, {profession = recipe.profession,
				tier = recipe.tier, station = recipe.station})
		end
	end
	local entities = {}
	for name, def in pairs(core.registered_entities) do
		if (def._cmi_is_mob or def.type == "monster" or def.type == "animal" or def.type == "npc")
				and not grug_mobs.subtype(name) then
			local drops = {}
			for _, row in ipairs(type(def.drops) == "table" and def.drops or {}) do
				if type(row) == "table" and type(row.name) == "string" then
					drops[#drops + 1] = {item = row.name, chance = row.chance or 1,
						min = row.min or 1, max = row.max or 1}
					push(mob_drops, row.name, {mob = name, chance = row.chance or 1,
						min = row.min or 1, max = row.max or 1})
				end
			end
			entities[name] = {
				type = def.type,
				description = first_line(def.description or def._grug_display_name),
				tier = def._grug_tier,
				disposition = grug_mobs.disposition and grug_mobs.disposition(name) or nil,
				domains = def._grug_spawn_domains,
				fields = scalar_fields(def),
				drops = drops,
			}
		end
	end
	for name, def in pairs(core.registered_nodes) do
		if def.drop ~= nil and def.drop ~= "" then
			local found = {}
			drop_names(def.drop, found)
			for item in pairs(found) do
				if item ~= name then push(node_drops, item, name) end
			end
		end
	end
	for band, rows in pairs(grug_fishing.CATCH_TABLES or {}) do
		for _, row in ipairs(rows) do
			push(fishing, row.name, {band = band, weight = row.weight, fish = row.fish == true})
		end
	end
	local resources = {}
	for _, resource in ipairs(grug_materials.RESOURCES or {}) do
		resources[resource.raw_item] = {key = resource.key, tier = resource.harvest_tier,
			kind = resource.grade and "gem" or "ore", grade = resource.grade,
			scope = resource.scope, node = resource.natural_node}
	end
	local alloys = {}
	for _, recipe in ipairs(grug_smelting.RECIPES or {}) do
		alloys[recipe.output] = recipe.inputs
	end
	local processed = {}
	for _, material in ipairs(grug_materials.PROCESSED_MATERIALS or {}) do
		processed[material.item] = {key = material.key, kind = material.kind, tier = material.tier}
	end

	local items, count = {}, 0
	for name, def in pairs(core.registered_items) do
		if name ~= "" and name ~= "air" and name ~= "ignore" and name ~= "unknown"
				and def._grug_icon_brief == nil then
			count = count + 1
			local engine = {}
			for _, recipe in ipairs(core.get_all_craft_recipes(name) or {}) do
				local method = recipe.method or "normal"
				local inputs = {}
				for _, input in pairs(recipe.items or {}) do
					if type(input) == "string" and input ~= "" then inputs[#inputs + 1] = input end
				end
				table.sort(inputs)
				local output = ItemStack(recipe.output or "")
				engine[#engine + 1] = {method = method, inputs = inputs,
					count = output:get_count()}
			end
			items[name] = {
				type = def.type,
				mod_origin = def.mod_origin,
				description = first_line(def.description),
				full_description = plain(def.description),
				short_description = first_line(def.short_description),
				groups = def.groups or {},
				stack_max = def.stack_max,
				fields = scalar_fields(def),
				ingredient_tier = grug_jobs.ingredient_tier and grug_jobs.ingredient_tier(name) or nil,
				food = grug_food.is_food and grug_food.is_food(name) or false,
				engine_recipes = engine,
				profession_recipes = profession_routes[name],
				mob_drops = mob_drops[name],
				node_drops = node_drops[name],
				fishing = fishing[name],
				resource = resources[name],
				alloy_inputs = alloys[name],
				processed = processed[name],
			}
		end
	end
	local aliases = {}
	for from, to in pairs(core.registered_aliases) do aliases[from] = to end
	local function registered(list)
		local out = {}
		for _, name in ipairs(list or {}) do
			out[#out + 1] = {name = name, registered = rawget(core.registered_items, name) ~= nil}
		end
		return out
	end
	-- Quest NPCs and today's quests: the designers' NPC ids and the legacy
	-- quest ids a new design replaces.
	local function scalars(def)
		local out = {}
		for key, value in pairs(def) do
			local kind = type(value)
			if type(key) == "string" and (kind == "string" or kind == "number" or kind == "boolean") then
				out[key] = value
			end
		end
		return out
	end
	local quest_npcs, quests = {}, {}
	for id, def in pairs(grug_quests.registered_npcs or {}) do quest_npcs[id] = scalars(def) end
	for id, def in pairs(grug_quests.registered_quests or {}) do
		local row = scalars(def)
		row.description = nil
		row.xp = def.rewards and def.rewards.xp
		row.prerequisites = def.prerequisites
		quests[id] = row
	end
	local dump = {
		quest_npcs = quest_npcs,
		quests = quests,
		items = items,
		aliases = aliases,
		entities = entities,
		curation = {
			removed = registered(grug_materials.CURATED_VENDOR_REMOVALS),
			no_recipe = registered(grug_materials.REMOVED_SILVER_SANDSTONE_OUTPUTS),
			removed_mobs_utilities = registered(grug_materials.REMOVED_MOBS_UTILITIES),
		},
		tiers = grug_materials.TIERS,
	}
	local path = core.get_worldpath() .. "/r28_items_probe.json"
	local json, err = core.write_json(dump)
	if not json then
		core.log("error", P .. "write_json failed: " .. tostring(err))
	else
		core.safe_file_write(path, json)
		local entity_count = 0
		for _ in pairs(entities) do entity_count = entity_count + 1 end
		log("items " .. count .. " entities " .. entity_count .. " written " .. path)
		log("RESULT PASS")
	end
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)

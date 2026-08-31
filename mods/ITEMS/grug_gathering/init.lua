-- WP33 gathering registrations and runtime harvest behavior. Placement is
-- owned by WP40 R7's single mapgen transaction and is deliberately absent.

grug_gathering = {}

local modpath = core.get_modpath(core.get_current_modname())
local catalog = dofile(modpath .. "/catalog.lua")
local harvest = dofile(modpath .. "/harvest.lua")({
	core = core,
	materials = grug_materials,
})
local registered_nodes = dofile(modpath .. "/nodes.lua")(core, catalog, harvest)

function grug_gathering.manifest()
	return catalog.manifest()
end

function grug_gathering.p9g_sources()
	return catalog.p9g_sources()
end

function grug_gathering.reuse_sources()
	return catalog.reuse_sources()
end

function grug_gathering.cultural_sources()
	return catalog.cultural_sources()
end

function grug_gathering.cultural_registrations()
	return catalog.cultural_registrations()
end

function grug_gathering.register_herb_authorizer(callback)
	return harvest.register_herb_authorizer(callback)
end

local manifest = catalog.manifest()
if core.sha256(manifest.canonical_bytes) ~= manifest.sha256 then
	error("grug_gathering: catalog manifest digest differs", 0)
end
if #registered_nodes ~= 18 then
	error("grug_gathering: source node population differs", 0)
end

core.register_on_leaveplayer(function(player)
	harvest.clear_player(player)
end)

core.register_on_mods_loaded(function()
	for index = 1, #registered_nodes do
		local name = registered_nodes[index]
		local definition = core.registered_nodes[name]
		local groups = definition and definition.groups or {}
		if not definition or groups.grug_gathering_source ~= 1 or
				definition.walkable ~= false or definition.buildable_to ~= false or
				definition.liquidtype ~= "none" or definition.drop == name then
			error("grug_gathering: invalid source registration " .. name, 0)
		end
	end
	local p9g = catalog.p9g_sources()
	for index = 1, #p9g do
		local row = p9g[index]
		local definition = core.registered_nodes[row.source_node]
		local groups = definition and definition.groups or {}
		local family_ok = (row.harvest_kind == "healing_herb" and
			groups.grug_healing_herb == row.required_group) or
			(row.harvest_kind == "spice" and
				groups.grug_spice == row.required_group) or
			(row.harvest_kind == "food" and groups.grug_food == 1 and
				groups.grug_found_only_food == nil) or
			(row.harvest_kind == "found_only_food" and groups.grug_food == 1 and
				groups.grug_found_only_food == 1)
		if not core.registered_items[row.raw_item] or not definition or
				definition.drop ~= row.raw_item or not family_ok then
			error("grug_gathering: P9G target differs " .. row.key, 0)
		end
	end
	local cultural = catalog.cultural_sources()
	for index = 1, #cultural do
		local row = cultural[index]
		local definition = core.registered_nodes[row.source_node]
		local groups = definition and definition.groups or {}
		if not core.registered_items[row.raw_item] or
				not definition or definition.drop ~= row.raw_item or
				groups.grug_cultural_source ~= 1 or
				groups[row.ordinary_group] ~= 3 then
			error("grug_gathering: cultural target differs " .. row.key, 0)
		end
	end
	local reuse = catalog.reuse_sources()
	for index = 1, #reuse do
		local row = reuse[index]
		for _, item_name in ipairs(row.source_items) do
			if not core.registered_items[item_name] then
				error("grug_gathering: missing reused source " .. item_name, 0)
			end
		end
		for _, item_name in ipairs(row.outputs) do
			if not core.registered_items[item_name] then
				error("grug_gathering: missing reused output " .. item_name, 0)
			end
		end
	end
end)

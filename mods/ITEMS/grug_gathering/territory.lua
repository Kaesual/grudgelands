-- Gathering in enemy home territory (Round 88 ruling 6). The world rule keeps
-- the other faction's home territory unchanged for a visitor; this exception
-- lets the visitor dig a gathering source there all the same: the herbs,
-- spices and found food of this catalogue, the wild cooking and alchemy
-- sources (grug_mapgen/world_nodes.lua), the apple and the blueberry bush
-- with berries; and, for consistency (the user, 2026-11-27), the small ground
-- plants: grass, ferns, flowers and their kin (`ground_plant` below). Trees,
-- leaves, logs, ores, stone, soil and every placement stay refused.
--
-- A source joins by carrying the group grug_gathering_source (every source
-- registration does) or, for a reused default node, by an "existing_food"
-- row of catalog.lua's reuse sources. A ground plant joins by being attached
-- to the ground with the group flora or grug_decor_plant (not a sapling, not
-- leaves), by dropping such a plant (a variant), or through GROUND_PLANTS.
-- The group grug_decor_plant alone is no rule: it also marks leaves, corals,
-- water plants and hanging moss, and default's grass carries flora only.
-- Right-click picking (pick.lua) is a dig, so it meets the same answer.
--
-- Placing: a source is no placement target (none is buildable_to), but grass,
-- flowers and most ground plants are, and the engine asks the same
-- is_protected for placing into one as for digging it. So a buildable_to
-- plant is allowed only while its own dig or punch runs at that position
-- (`digging`, the pattern grug_housing/protection.lua uses for its arrival
-- cube); a placement never runs inside one, so it stays refused.
--
-- The exception answers only where the home's own faction may change the
-- place: a town, landmark, road, bridge, settlement or POI core, guild room
-- or the sea inside that territory refuses its owners as well, so its own
-- refusal and hint stand. Claims are grug_housing's (its wrapper asks after
-- this one and still refuses).
local OTHER = {accord = "throng", throng = "accord"}

-- Ground plants with neither group (moss, cattails, land reeds, the dry shrub).
local GROUND_PLANTS = {
	["grug_nodes:moss_carpet"] = true,
	["grug_nodes:cattails"] = true,
	["grug_nodes:reeds"] = true,
	["default:dry_shrub"] = true,
}

local function ground_plant(def)
	local groups = def and def.groups or {}
	if (groups.attached_node or 0) == 0 or (groups.sapling or 0) > 0 or
			(groups.leaves or 0) > 0 then
		return false
	end
	return (groups.flora or 0) > 0 or (groups.grug_decor_plant or 0) > 0
end

local function pos_key(pos)
	return math.floor(pos.x + 0.5) .. "," .. math.floor(pos.y + 0.5) .. "," ..
		math.floor(pos.z + 0.5)
end

return function(catalog)
	local found_food = {}
	for _, row in ipairs(catalog.reuse_sources()) do
		if row.harvest_kind == "existing_food" then
			for _, name in ipairs(row.source_items) do found_food[name] = true end
		end
	end
	-- name -> true for every ground plant, filled once all mods have loaded.
	local plants = {}
	-- player name -> the position key of the buildable_to plant being dug
	local digging = {}

	local function gatherable(name)
		return found_food[name] == true or plants[name] == true or
			core.get_item_group(name, "grug_gathering_source") > 0
	end

	local function with_digging(original)
		return function(pos, node, actor, ...)
			local name = actor and actor.is_player and actor:is_player() and
				actor:get_player_name()
			if type(name) ~= "string" or name == "" or not pos then
				return original(pos, node, actor, ...)
			end
			local previous = digging[name]
			digging[name] = pos_key(pos)
			local result = original(pos, node, actor, ...)
			digging[name] = previous
			return result
		end
	end

	-- Outermost on the buildable_to plants' on_dig and on_punch (the punch's
	-- protection hint): on the first server step, after the mods-loaded
	-- overrides of grug_abilities and grug_materials, in place and raw as
	-- grug_housing does.
	local function install_digging()
		for name in pairs(plants) do
			local def = core.registered_nodes[name]
			if def.buildable_to == true then
				for _, field in ipairs({"on_punch", "on_dig"}) do
					if type(def[field]) == "function" then
						rawset(def, field, with_digging(def[field]))
					end
				end
			end
		end
	end

	core.register_on_mods_loaded(function()
		for name, def in pairs(core.registered_nodes) do
			if GROUND_PLANTS[name] or ground_plant(def) then plants[name] = true end
		end
		for name, def in pairs(core.registered_nodes) do
			if type(def.drop) == "string" and plants[def.drop] and
					((def.groups or {}).leaves or 0) == 0 then
				plants[name] = true
			end
		end
		core.after(0, install_digging)
	end)

	core.register_on_leaveplayer(function(player)
		digging[player:get_player_name()] = nil
	end)

	grug_core.register_world_exception(function(pos, name)
		local node = core.get_node_or_nil(pos)
		if not node or not gatherable(node.name) then return nil end
		if plants[node.name] and core.registered_nodes[node.name].buildable_to == true and
				digging[name] ~= pos_key(pos) then
			return nil
		end
		if not grug_core.zone_authority_installed() then return nil end
		local owner = OTHER[grug_core.get_player_faction(name)]
		if not owner or grug_zones.territory_rule_at(pos) ~= owner .. "_home" or
				grug_core.world_protected_for_faction(pos, owner) then
			return nil
		end
		return true
	end)

	return gatherable
end

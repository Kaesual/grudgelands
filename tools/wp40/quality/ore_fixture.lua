-- Isolated compact fixture for the retired depleted-vein compatibility node.

return function(repo)
	local function check(condition, message)
		if not condition then error("quality ore fixture: " .. message, 0) end
	end
	local depleted = "grug_nodes:depleted_vein"
	local world, metadata, timers = {}, {}, {}
	local registered_node, registered_lbm
	local dignode_callbacks, removals = 0, 0
	local function key(pos) return pos.x .. "/" .. pos.y .. "/" .. pos.z end
	local core = {}
	function core.register_node(name, definition)
		check(name == depleted and registered_node == nil, "node registration differs")
		registered_node = definition
	end
	function core.register_lbm(definition)
		check(registered_lbm == nil, "LBM population differs")
		registered_lbm = definition
	end
	function core.register_on_dignode()
		dignode_callbacks = dignode_callbacks + 1
	end
	function core.get_node(pos)
		return world[key(pos)] or {name = "air"}
	end
	function core.remove_node(pos)
		local pos_key = key(pos)
		world[pos_key], metadata[pos_key], timers[pos_key] = {name = "air"}, nil, nil
		removals = removals + 1
		return true
	end
	local default = {}
	function default.node_sound_stone_defaults() return {} end
	local environment = setmetatable({core = core, default = default}, {__index = _G})
	local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_nodes/ore_respawn.lua"))
	setfenv(chunk, environment)
	chunk()
	check(dignode_callbacks == 0, "natural-ore dig hook remains")
	check(registered_node and registered_node.drop == "" and
		registered_node.groups.not_in_creative_inventory == 1,
		"legacy node visibility or drop differs")
	check(registered_lbm and
		registered_lbm.name == "grug_nodes:remove_legacy_depleted_vein" and
		registered_lbm.nodenames[1] == depleted and
		registered_lbm.run_at_every_load == false,
		"one-time LBM contract differs")
	for index, old_meta in ipairs({"default:stone_with_gold", "unknown:ore", ""}) do
		local pos = {x = index, y = -50, z = 0}
		local pos_key = key(pos)
		world[pos_key] = {name = depleted}
		metadata[pos_key], timers[pos_key] = {grug_ore = old_meta}, 1
		local before = removals
		check(registered_node.on_timer(pos) == false, "timer return differs")
		check(core.get_node(pos).name == "air" and metadata[pos_key] == nil and
			timers[pos_key] == nil and removals == before + 1,
			"timer migration differs")
		check(registered_node.on_timer(pos) == false and removals == before + 1,
			"repeated timer is not harmless")
	end
	local pos = {x = 10, y = -50, z = 0}
	world[key(pos)] = {name = depleted}
	local before = removals
	registered_lbm.action(pos, {name = depleted})
	check(core.get_node(pos).name == "air" and removals == before + 1,
		"LBM migration differs")
	registered_lbm.action(pos, {name = depleted})
	check(removals == before + 1, "repeated LBM is not harmless")
	world[key(pos)] = {name = "default:stone"}
	registered_node.on_timer(pos)
	registered_lbm.action(pos, {name = depleted})
	check(core.get_node(pos).name == "default:stone" and removals == before + 1,
		"stale callbacks removed replacement node")
	return table.concat({
		"schema\tgrug_wp40_quality_ore_fixture_v1",
		"dig_hooks\t" .. dignode_callbacks,
		"migration_meta_cases\t3",
		"removals\t" .. removals,
		"replacement_preserved\ttrue",
	}, "\n") .. "\n"
end

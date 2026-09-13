-- Compact source fixture for the fresh-world natural-ore persistence rule.

return function(repo)
	local function check(condition, message)
		if not condition then error("quality ore fixture: " .. message, 0) end
	end
	local function read(path)
		local file = assert(io.open(repo .. "/" .. path, "rb"))
		local source = file:read("*a")
		file:close()
		return source
	end
	local removed = io.open(repo .. "/mods/ITEMS/grug_nodes/ore_respawn.lua", "rb")
	if removed then removed:close() end
	check(removed == nil, "retired respawn file exists")
	local source = read("mods/ITEMS/grug_nodes/init.lua")
	for _, needle in ipairs({"ore_respawn", "depleted_vein", "register_on_dignode"}) do
		check(source:find(needle, 1, true) == nil, "retired path remains: " .. needle)
	end
	return table.concat({
		"schema\tgrug_wp40_quality_ore_fixture_v2",
		"respawn_file_absent\ttrue",
		"respawn_loader_absent\ttrue",
		"depleted_node_absent\ttrue",
	}, "\n") .. "\n"
end

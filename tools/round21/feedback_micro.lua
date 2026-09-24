-- Portable Round 21 feedback micro-suite. It deliberately composes only the
-- small focused fixtures touched by the round; mapgen integration belongs to
-- the separate real-manifest gate owned by the coordinator.
return function(repo)
	local fixtures = {
		{"food_input", "tools/r20_input/controls_micro.lua"},
		{"socket_labels", "tools/wp13/settlement_sockets_kat.lua"},
		{"furnaces", "tools/r21_furnace/automatic_kat.lua"},
		{"furnace_light", "tools/r21_furnace/workspaces_light_kat.lua"},
		{"aquatic_content", "tools/r21_aquatic/world_content_kat.lua"},
		{"fish_spawn", "tools/r21_aquatic/fish_spawn_kat.lua"},
	}
	local report = {}
	for _, fixture in ipairs(fixtures) do
		local output = {}
		local env = setmetatable({_G = false, arg = {repo}}, {__index = _G})
		env._G = env
		env.print = function(...)
			local fields = {}
			for index = 1, select("#", ...) do
				fields[index] = tostring(select(index, ...))
			end
			output[#output + 1] = table.concat(fields, "\t")
		end
		env.dofile = function(path)
			local child = assert(loadfile(path))
			setfenv(child, env)
			return child()
		end
		local chunk = assert(loadfile(repo .. "/" .. fixture[2]))
		setfenv(chunk, env)
		local result = chunk()
		if type(result) == "function" then result = result(repo) end
		if result ~= nil then output[#output + 1] = tostring(result) end
		report[#report + 1] = fixture[1] .. "\t" .. table.concat(output, " | ")
	end
	return table.concat(report, "\n") .. "\n"
end

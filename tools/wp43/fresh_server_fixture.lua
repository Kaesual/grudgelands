-- Callable final-pair fixture for the fresh-server material boundary.
-- Usage: local bytes = dofile(path)(absolute_repository_root)

return function(repo)
	assert(type(repo) == "string" and repo:match("^/[A-Za-z0-9._/-]+$") and
			not repo:find("/../", 1, true) and not repo:find("/./", 1, true),
		"absolute repository root is required")

	local output = {}
	local fixture_env = {
		arg = {
			[0] = repo .. "/tools/wp43/materials_test.lua",
			[1] = repo,
		},
		print = function(...)
			local fields = {}
			for index = 1, select("#", ...) do
				fields[index] = tostring(select(index, ...))
			end
			output[#output + 1] = table.concat(fields, "\t")
		end,
		table = {},
	}
	for key, value in pairs(table) do
		fixture_env.table[key] = value
	end
	fixture_env._G = fixture_env
	setmetatable(fixture_env, {__index = _G})

	fixture_env.dofile = function(path)
		local chunk, message = loadfile(path)
		assert(chunk, message)
		setfenv(chunk, fixture_env)
		return chunk()
	end

	fixture_env.dofile(repo .. "/tools/wp43/materials_test.lua")
	assert(#output == 1 and
		output[1] == "WP43 material progression integration tests passed",
		"fresh-server material fixture did not reach its receipt")

	return table.concat({
		"schema\tgrug_fresh_server_materials_fixture_v1",
		"vendor_registrations\t53_removed",
		"storage_derivatives\t22_canonical",
		"material_aliases\t0",
		"recipe_inputs\tcanonical",
		"handoff\tvalidated",
		"result\tpass",
	}, "\n") .. "\n"
end

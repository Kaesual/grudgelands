-- One compact final-byte fixture for R8-TAGS and every touched compatibility
-- pin. The caller passes an absolute repository root and writes the returned
-- canonical output verbatim.

local function run(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")
	local output = {}
	local function add(value)
		if value and value ~= "" then output[#output + 1] = value end
	end
	local function function_kat(path)
		local value, failure = dofile(repo .. path)(repo)
		if value == false then error(failure, 0) end
		add(value)
	end
	local function capture_script(path)
		local saved_write, saved_print = io.write, print
		local saved_arg = arg
		local chunks = {}
		io.write = function(...)
			local values = {...}
			for index = 1, #values do chunks[#chunks + 1] = tostring(values[index]) end
		end
		print = function(...)
			local values = {...}
			for index = 1, #values do
				if index > 1 then chunks[#chunks + 1] = "\t" end
				chunks[#chunks + 1] = tostring(values[index])
			end
			chunks[#chunks + 1] = "\n"
		end
		arg = {[0] = path, repo}
		local ok, value = pcall(dofile, repo .. path)
		arg, io.write, print = saved_arg, saved_write, saved_print
		if not ok then error(value, 0) end
		add(table.concat(chunks))
		return value
	end

	function_kat("/tools/r8_tags/kat.lua")
	for _, file in ipairs({
		"combat_obstacle_kat.lua",
		"mob_cadence_kat.lua",
		"move_aggregator_kat.lua",
		"talent_tree_kat.lua",
		"talent_ui_kat.lua",
	}) do
		function_kat("/tools/wp11/" .. file)
	end
	capture_script("/tools/r5_multiplayer_feel/kat.lua")
	add(capture_script("/tools/r5_progression/progression_kat.lua"))
	function_kat("/tools/wp13/start_npcs_kat.lua")
	capture_script("/tools/wp45/character_creation_test.lua")
	function_kat("/tools/wp40/quality/vendor_fixture.lua")
	return table.concat(output)
end

return run

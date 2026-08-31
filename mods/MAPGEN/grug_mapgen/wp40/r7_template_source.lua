-- Engine-backed, read-only schematic source for the production R6 template
-- expander. Luanti owns MTS decoding in both main and mapgen environments.

return function(core_api, schematic_directory)
	if type(core_api) ~= "table" or type(core_api.read_schematic) ~= "function" or
			type(schematic_directory) ~= "string" or schematic_directory == "" then
		error("WP40 R7 template source: construction seam differs", 0)
	end
	local source = {}
	function source.read(filename)
		if type(filename) ~= "string" or filename == "" or
				filename:find("/", 1, true) or filename:find("\\", 1, true) or
				not filename:match("^[a-z0-9_]+%.mts$") then
			error("WP40 R7 template source: schematic name differs", 0)
		end
		local value = core_api.read_schematic(schematic_directory .. "/" .. filename,
			{write_yslice_prob = "all"})
		if type(value) ~= "table" or type(value.data) ~= "table" then
			error("WP40 R7 template source: engine read failed", 0)
		end
		for index = 1, #value.data do
			local cell = value.data[index]
			if type(cell) ~= "table" then
				error("WP40 R7 template source: engine cell differs", 0)
			end
			-- The accepted MTS parser normalizes CONTENT_IGNORE placeholders to
			-- air. Keep that exact input vocabulary before R6 hashes templates.
			if cell.name == "ignore" then cell.name = "air" end
			if cell.force_place == nil then cell.force_place = false end
		end
		return value
	end
	return source
end

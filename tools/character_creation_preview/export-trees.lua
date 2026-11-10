-- Offline adapter for the exact shipped tree generator and node mapping.
-- Arguments after the repository root are species:seed pairs. TSV keeps this
-- adapter independent of an engine JSON implementation or external Lua modules.
local root = assert(arg[1], "repository root required")
local generator = dofile(root .. "/mods/MAPGEN/grug_mapgen/wp40/treegen.lua")
local templates = dofile(root .. "/mods/MAPGEN/grug_mapgen/wp40/tree_templates.lua")(generator)
for i = 2, #arg do
	local species, seed = arg[i]:match("^(%a+):(%d+)$")
	assert(species and seed, "expected species:seed")
	local cells = templates.tree(species, tonumber(seed))
	for _, cell in ipairs(cells) do
		io.write(table.concat({arg[i], cell.x, cell.y, cell.z, cell.name,
			cell.param2, cell.root and 1 or 0}, "\t"), "\n")
	end
end

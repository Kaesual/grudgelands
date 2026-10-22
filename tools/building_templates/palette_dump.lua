-- The palette and param2 facts the template validator reads (Round 56,
-- building-template-format.md §6), straight from the game's own
-- `wp13/palette.lua` and `wp13/parts.lua`:
--   required <role> / optional <role>   the declared roles, in file order
--   family <role> <suffix> ...          the family roles and their suffixes
--   bind <race> <role> <node>           every race's binding
--   kind <node> <param2 kind> <place_param2> <shaped 0|1> <tree piece 0|1>
--        <wild soil 0|1>                for every node name read from stdin
-- Usage: luajit tools/building_templates/palette_dump.lua <repo> < names
-- Plain Lua 5.1 (no engine).

local repo = arg[1] or "."
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local parts = dofile(wp13 .. "/parts.lua")
local out = {}
for _, role in ipairs(palettes.required) do out[#out + 1] = "required " .. role end
for _, role in ipairs(palettes.optional) do out[#out + 1] = "optional " .. role end
local families = {}
for role in pairs(palettes.prefix_roles) do families[#families + 1] = role end
table.sort(families)
for _, role in ipairs(families) do
	out[#out + 1] = "family " .. role .. " " .. table.concat(palettes.prefix_roles[role], " ")
end
local races = {}
for race in pairs(palettes.races) do races[#races + 1] = race end
table.sort(races)
for _, race in ipairs(races) do
	local roles = {}
	for role in pairs(palettes.races[race]) do roles[#roles + 1] = role end
	table.sort(roles)
	for _, role in ipairs(roles) do
		out[#out + 1] = "bind " .. race .. " " .. role .. " " .. palettes.races[race][role]
	end
end
for name in io.read("*a"):gmatch("%S+") do
	out[#out + 1] = table.concat({"kind", name, parts.param2_kind(name),
		parts.place_param2(name), parts.shaped(name) and 1 or 0,
		parts.tree_piece(name) and 1 or 0, parts.wild_soil(name) and 1 or 0}, " ")
end
print(table.concat(out, "\n"))

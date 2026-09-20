-- Exact presentation and ownership policy for the current engine recipe
-- catalog. Craft registration remains in each content mod; this table only
-- decides which book presents an already registered route.
local M = {declarations = {}}

function M.route_key(recipe)
	local signature = table.concat(recipe.display_items or recipe.inputs or {}, "\1")
	return table.concat({recipe.station, recipe.output_name or recipe.output,
		recipe.method, tostring(recipe.width), tostring(recipe.shapeless == true),
		signature}, "\0")
end

local source = dofile(core.get_modpath(core.get_current_modname()) ..
	"/basics_routes.lua")
for index = 1, #source do
	local declaration = source[index]
	local key = M.route_key({station = declaration.station,
		output_name = declaration.output, method = declaration.method,
		width = declaration.width, shapeless = declaration.shapeless,
		display_items = declaration.inputs})
	assert(not M.declarations[key], "duplicate Basics catalog declaration: " .. key)
	assert(declaration.owner == "profession" or declaration.owner == "general",
		"invalid Basics catalog owner: " .. key)
	if declaration.owner == "general" then
		assert(declaration.starter == true or
			type(declaration.main_material) == "string",
			"general route lacks visibility declaration: " .. key)
	end
	M.declarations[key] = declaration
end

function M.bind(records)
	local used, general = {}, {}
	for index = 1, #records do
		local recipe = records[index]
		local key = M.route_key(recipe)
		local declaration = M.declarations[key]
		assert(declaration, "missing Basics catalog declaration: " .. key)
		assert(not used[key], "duplicate runtime Basics route: " .. key)
		used[key] = true
		if declaration.owner == "general" then
			recipe.basics_route_key = key
			recipe.basics_presentation = declaration
			general[#general + 1] = recipe
		end
	end
	for key in pairs(M.declarations) do
		assert(used[key], "stale Basics catalog declaration: " .. key)
	end
	return general
end

function M.counts()
	local result = {general = 0, profession = 0}
	for _, declaration in pairs(M.declarations) do
		result[declaration.owner] = result[declaration.owner] + 1
	end
	return result
end

return M

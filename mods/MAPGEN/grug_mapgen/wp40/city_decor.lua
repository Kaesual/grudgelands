-- Round 75 authored city dressing. Placement choice is frozen in the catalog;
-- this module only verifies expected cells and applies exact node substitutions.
return function(directory)
	local catalog = dofile(directory .. "/city_decor_catalog.lua")
	local M = {}

	local function less_bytes(a, b)
		local count = math.min(#a, #b)
		for index = 1, count do
			local left, right = string.byte(a, index), string.byte(b, index)
			if left ~= right then return left < right end
		end
		return #a < #b
	end

	local function key(x, y, z)
		return x .. ":" .. y .. ":" .. z
	end

	-- `strict` belongs to the offline authoring audit. Game construction uses
	-- the safe form: if sources drift, retain the undressed blueprint whole.
	function M.apply(city, scope, blueprint, strict)
		local city_rows = catalog[city]
		local rows = city_rows and city_rows[scope]
		if not rows then return blueprint end
		local by_pos = {}
		for index = 1, #blueprint.cells do
			local cell = blueprint.cells[index]
			by_pos[key(cell.x, cell.y, cell.z)] = cell
		end
		local placements, target = {}, {}
		local function differ(message)
			if strict then error("city decor: " .. city .. "/" .. scope .. ": " .. message, 0) end
			return blueprint
		end
		for row_index = 1, #rows do
			local row = rows[row_index]
			for placement_index = 1, #row.placements do
				local p = row.placements[placement_index]
				local where = key(p.x, p.y, p.z)
				if target[where] then return differ("duplicate target " .. where) end
				local old = by_pos[where]
				if not old or old.name ~= p.expect then
					return differ(row.id .. " target differs at " .. where)
				end
				local support = by_pos[key(p.x + p.support_dx, p.y + p.support_dy,
					p.z + p.support_dz)]
				if not support or support.name ~= p.support then
					return differ(row.id .. " support differs at " .. where)
				end
				target[where] = p
				placements[#placements + 1] = p
			end
		end
		if #placements == 0 then return blueprint end
		local names = {}
		for index = 1, #blueprint.palette do names[blueprint.palette[index]] = true end
		for index = 1, #placements do names[placements[index].node] = true end
		local cells = {}
		for index = 1, #blueprint.cells do
			local old = blueprint.cells[index]
			local p = target[key(old.x, old.y, old.z)]
			if p then
				cells[index] = {x = old.x, y = old.y, z = old.z, name = p.node,
					param2 = p.param2}
			else
				cells[index] = old
			end
		end
		local palette = {}
		for name in pairs(names) do palette[#palette + 1] = name end
		table.sort(palette, less_bytes)
		local out = {}
		for field, value in pairs(blueprint) do out[field] = value end
		out.cells, out.palette = cells, palette
		return out
	end

	function M.catalog() return catalog end
	return M
end

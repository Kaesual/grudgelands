-- The arena "Breach Road"'s blocks (Round 85 lane BUILD, round85-plan.md §4
-- BUILD). The ground is already there: world generation levels the hull to
-- the datum, grows nothing on it and writes the inner road (lane WORLD,
-- `breach_site.lua`, `road_writer.lua`). This pass writes the model of
-- `breach_model.lua` onto it, in the R7 successor settle after the dragon
-- arenas (last, after every settlement, POI and the roads, so nothing later
-- overwrites it; the pattern of `arena_writer.lua`):
--   * every column's cells from the datum up (terraces, stairs, the road's
--     wear, breastworks, piers, the hearths, both halls); a KEEP cell leaves
--     the natural surface the planner wrote (the rim), an AIR cell clears;
--   * CLEAR_ABOVE nodes of air above each column's highest cell;
--   * the dressing groups.
-- The ground's three roles and each dressing group take the family of the
-- biome the zone field puts at their own column (`breach_model.lua`
-- FAMILIES), so the palette follows the zones and biome patches the site
-- stands in.
--
-- Each chunk writes exactly the model's cells inside its own owner, and a
-- cell's node is a function of its position and the seed's site alone (the
-- biome is the planner's pure column answer), so the arena comes out the
-- same in any emerge order, a hall over a chunk border included.
--
--   local write = dofile(wp40 .. "/breach_writer.lua")(core_api, source, B, model)
--   write.dress(context) -> the number of cells written or cleared
-- (`B` is `breach_model.lua`, `model` its `B.new(wp40)`; `source.breach` the
-- world's site, none: nothing is written.)
return function(core_api, source, B, model)
	local function fail(message) error("WP40 breach writer: " .. message, 0) end
	if type(core_api) ~= "table" or type(core_api.get_content_id) ~= "function" or
			type(core_api.registered_nodes) ~= "table" or type(source) ~= "table" or
			type(B) ~= "table" or type(B.FAMILIES) ~= "table" or
			type(model) ~= "table" or type(model.columns) ~= "table" then
		fail("construction seam differs")
	end
	local writer = {}
	local site = source.breach
	if site == nil then
		function writer.dress() return 0 end
		return writer
	end
	local function cid(name)
		if not core_api.registered_nodes[name] then fail("arena node missing: " .. name) end
		return core_api.get_content_id(name)
	end
	local air = core_api.CONTENT_AIR or cid("air")
	-- entry index -> content id and param2; a role's per family
	local fixed_cid, fixed_param2, role_of = {}, {}, {}
	for index, e in ipairs(model.entries) do
		if e.role then role_of[index] = e.role
		else fixed_cid[index], fixed_param2[index] = cid(e.name), e.param2 end
	end
	local family_cid = {}
	for _, family in ipairs(B.FAMILY_ORDER) do
		local f, row = B.FAMILIES[family], {}
		for _, role in ipairs(B.ROLES) do row[role] = cid(f[role]) end
		family_cid[family] = row
	end
	local KEEP, AIR, CLEAR = B.KEEP, B.AIR, B.CLEAR_ABOVE
	local sx, sz, datum = site.x, site.z, site.y
	local L = model.layout
	local columns, dressing = model.columns, model.dressing
	local x_lo, x_hi = sx - L.HALF_X, sx + L.HALF_X
	local z_lo, z_hi = sz - L.HALF_Z, sz + L.HALF_Z
	local y_lo, y_hi = datum, datum + model.REACH

	-- `context`: the R7 successor context (owner bounds, settled_at,
	-- column_values_at, write_road).
	function writer.dress(context)
		local min_x, max_x, min_z, max_z = context.min_x, context.max_x, context.min_z, context.max_z
		local min_y, max_y = context.min_y, context.max_y
		if max_x < x_lo or min_x > x_hi or max_z < z_lo or min_z > z_hi or
				max_y < y_lo or min_y > y_hi then
			return 0
		end
		local write, settled_at = context.write_road, context.settled_at
		local function family_at(x, z)
			return B.family((select(4, context.column_values_at(x, z))))
		end
		local count = 0
		for index = 1, #columns do
			local c = columns[index]
			local x, z = sx + c.lx, sz + c.lz
			if x >= min_x and x <= max_x and z >= min_z and z <= max_z then
				local cells, roles = c.cells, nil
				local top = math.min(max_y, datum + c.top + CLEAR)
				for y = math.max(min_y, datum), top do
					local value = cells[y - datum + 1]
					if value == nil or value == AIR then
						if settled_at(x, y, z) ~= air then
							write(x, y, z, air, 0)
							count = count + 1
						end
					elseif value ~= KEEP then
						local role = role_of[value]
						if role then
							roles = roles or family_cid[family_at(x, z)]
							write(x, y, z, roles[role], 0)
						else
							write(x, y, z, fixed_cid[value], fixed_param2[value])
						end
						count = count + 1
					end
				end
			end
		end
		for index = 1, #dressing do
			local g = dressing[index]
			local gx, gz = sx + g.x, sz + g.z
			-- (every cell lies within one node of its centre column)
			if gx + 1 >= min_x and gx - 1 <= max_x and gz + 1 >= min_z and gz - 1 <= max_z then
				local cells = g.cells[B.FAMILIES[family_at(gx, gz)].dress]
				for k = 1, #cells do
					local cell = cells[k]
					local x, y, z = sx + cell.x, datum + cell.y, sz + cell.z
					if x >= min_x and x <= max_x and z >= min_z and z <= max_z and
							y >= min_y and y <= max_y then
						write(x, y, z, fixed_cid[cell.entry], fixed_param2[cell.entry])
						count = count + 1
					end
				end
			end
		end
		return count
	end
	return writer
end

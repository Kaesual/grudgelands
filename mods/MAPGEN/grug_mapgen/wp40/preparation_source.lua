-- Readonly surface envelopes derived from the same decoded content and fitted
-- column authority as the writer. This does not plan or write mapgen content.
local path = assert(debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]"))
local plot_approach = dofile(path .. "/../wp13/plot_approach.lua")
local settlement_module = dofile(path .. "/r7_settlement.lua")
return function(columns, templates, cultural, settlements, zones, anchors, identity, sha256)
	assert(type(columns.column_values_at) == "function" and #templates > 0)
	local reach, below, above = 1, -1, 1
	local function include(x, y, z)
		reach = math.max(reach, math.abs(x), math.abs(z))
		below, above = math.min(below,y), math.max(above,y)
	end
	for _, record in ipairs(templates) do
		for _, rotation in ipairs(record.rotations) do
			include(rotation.min_x, rotation.min_y+1, rotation.min_z)
			include(rotation.max_x, rotation.max_y+1, rotation.max_z)
		end
	end
	for _, row in ipairs(cultural) do
		for _, cell in ipairs(row.cells) do include(cell.x,cell.y+1,cell.z) end
	end
	-- Settlement boxes: a start or a civic core at its fitted anchor, a
	-- capital's placed plots and its city edge from this world's capital
	-- layout (Round 22 capital planner). The streets, connectors, squares and
	-- the canal are roads and water: `column_bounds` reads them per column.
	local boxes = {}
	for _, row in ipairs(settlements) do
		local profile = row.profile
		local anchor = assert(zones.anchor(profile.zone_id, profile.slot))
		assert(anchor.id == profile.anchor_id, "Preparation settlement identity differs")
		for _, blueprint in ipairs(row.prepared.blueprints) do
			local d, b = blueprint.descriptor, blueprint.bounds
			local x_min, x_max = anchor.x + b.min.x, anchor.x + b.max.x
			local z_min, z_max = anchor.z + b.min.z, anchor.z + b.max.z
			local y_min, y_max = anchor.y + b.min.y, anchor.y + b.max.y
			if d.kind == "reference" then
				-- A placed capital plot: its bounds turned with the plot at the
				-- layout's offset and base height, plus the collar the successor
				-- shapes round it and the approach along its turned front.
				local rect = settlement_module.plot_rect(blueprint, anchor.x, anchor.z)
				local y = d.base_y
				local collar, approach = plot_approach.COLLAR, plot_approach.MAX_APPROACH
				local fx, fz = plot_approach.rot(0, -1, d.turns or 0)
				x_min = rect.min_x - collar - (fx < 0 and approach or 0)
				x_max = rect.max_x + collar + (fx > 0 and approach or 0)
				z_min = rect.min_z - collar - (fz < 0 and approach or 0)
				z_max = rect.max_z + collar + (fz > 0 and approach or 0)
				y_min = math.min(y + b.min.y, y - approach)
				y_max = math.max(y + b.max.y, y + approach + 3)
			elseif d.kind == "overlay" then
				-- The city edge on the capital outline: its reach, and the
				-- heights its walls, gatehouses and turrets stand between.
				local city = blueprint.city
				y_min, y_max = city.y_min, city.y_max
			else
				assert(d.kind == "anchor", "Unsupported preparation blueprint kind")
			end
			boxes[#boxes+1] = {x_min=x_min,x_max=x_max,
				z_min=z_min,z_max=z_max,y_min=y_min,y_max=y_max,radius=0}
		end
	end
	for _, row in ipairs(anchors.copy_rows()) do
		boxes[#boxes+1] = {x_min=row.x,x_max=row.x,z_min=row.z,z_max=row.z,
			y_min=row.y,y_max=row.y+1,radius=0}
	end
	-- Runtime CIDs enter the complete R7 manifest SHA and may be assigned
	-- differently on a normal restart. Bind stable semantic source identity,
	-- decoded reach and the actual fitted boxes instead of those runtime IDs.
	local bytes = {identity, tostring(reach), tostring(below), tostring(above)}
	for _, b in ipairs(boxes) do
		bytes[#bytes+1] = table.concat({b.x_min,b.x_max,b.y_min,b.y_max,
			b.z_min,b.z_max,b.radius}, ",")
	end
	local source = {identity="grug_surface_v1:" .. sha256(table.concat(bytes,"\n"))}
	function source.tile_bounds(lo,hi)
		local radius, bottom, top = reach, math.huge, -math.huge
		for _, b in ipairs(boxes) do
			if lo.x <= b.x_max and hi.x >= b.x_min and lo.z <= b.z_max and hi.z >= b.z_min then
				radius = math.max(radius,b.radius)
				bottom,top = math.min(bottom,b.y_min),math.max(top,b.y_max)
			end
		end
		return radius,bottom,top
	end
	function source.column_bounds(x,z)
		local _,_,_,_,_,ground,water,_,_,_,functional,_,_,_,_,upper,lower =
			columns.column_values_at(x,z)
		assert(type(ground) == "number", "Preparation column authority missing")
		-- Eight visible water nodes plus one support node; deep seabeds are not
		-- a surface-travel requirement. Shallow beds retain their actual height.
		local surface_low = water and math.max(ground,water-8) or ground
		local surface_high = water and math.max(ground,water) or ground
		if functional then
			surface_low = math.min(surface_low,functional)
			surface_high = math.max(surface_high,functional)
		end
		if upper then surface_high = math.max(surface_high,upper) end
		if lower then surface_low = math.min(surface_low,lower) end
		-- Roads (Round 22 Phase 4): a deck or bridge stands above its ground,
		-- with a slab on a half step and, on a straight capital street, a
		-- railing on top (D74, D75); cuts already lower `ground`.
		if columns.road_column_at then
			local _, road_y, _, _, _, _, _, _, rail = columns.road_column_at(x,z)
			if road_y then
				surface_high = math.max(surface_high,math.floor(road_y)+(rail and 2 or 1))
			end
		end
		return surface_low+below,surface_high+above
	end
	return source
end

-- Readonly surface envelopes derived from the same decoded content and fitted
-- column authority as the writer. This does not plan or write mapgen content.
local path = assert(debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]"))
local plot_approach = dofile(path .. "/../wp13/plot_approach.lua")
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
	local boxes = {}
	local function terrain(x,z)
		local _,_,_,_,_,y = columns.column_values_at(x,z)
		assert(type(y) == "number", "Preparation terrain authority missing")
		return y
	end
	for _, row in ipairs(settlements) do
		local profile = row.profile
		local anchor = assert(zones.anchor(profile.zone_id, profile.slot))
		assert(anchor.id == profile.anchor_id, "Preparation settlement identity differs")
		for _, blueprint in ipairs(row.prepared.blueprints) do
			local d, b = blueprint.descriptor, blueprint.bounds
			local x,y,z = anchor.x,anchor.y,anchor.z
			if d.kind == "reference" then
				x,z = x+d.offset.x,z+d.offset.z
				y = terrain(x+blueprint.reference.x,z+blueprint.reference.z)
			else
				assert(d.kind == "anchor" or d.kind == "overlay",
					"Unsupported preparation blueprint kind")
			end
			local x_min, x_max, z_min, z_max = x+b.min.x, x+b.max.x, z+b.min.z, z+b.max.z
			local y_min, y_max = y+b.min.y, y+b.max.y
			if d.kind == "reference" then
				local plot = blueprint.landmarks and blueprint.landmarks.plot
				if plot then
					-- The successor may cut/fill outside the authored cell box.
					-- Cover the bounded approach and its headroom explicitly;
					-- an incidental avenue envelope is not its authority.
					x_min = math.min(x_min, math.max(anchor.x-265, x+plot.min.x-plot_approach.COLLAR))
					x_max = math.max(x_max, math.min(anchor.x+265, x+plot.max.x+plot_approach.COLLAR))
					z_min = math.min(z_min, math.max(anchor.z-265, z+plot.min.z-plot_approach.MAX_APPROACH))
					z_max = math.max(z_max, math.min(anchor.z+265, z+plot.max.z+plot_approach.COLLAR))
					y_min = math.min(y_min, y-plot_approach.MAX_APPROACH)
					y_max = math.max(y_max, y+plot_approach.MAX_APPROACH+3)
				end
			end
			boxes[#boxes+1] = {x_min=x_min,x_max=x_max,
				z_min=z_min,z_max=z_max,y_min=y_min,y_max=y_max,
				-- Avenue envelopes read every lane within their authored reach;
				-- use that neighborhood as well as their authorized volume.
				radius=d.kind == "overlay" and blueprint.reach+blueprint.half+1 or 0}
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
		return surface_low+below,surface_high+above
	end
	return source
end

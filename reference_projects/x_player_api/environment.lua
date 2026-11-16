-- x_player_api environment detection module
-- Handles zero-allocation spatial probing for ground, liquids, ladders, and air.

x_player_api = rawget(_G, "x_player_api") or rawget(_G, "player_api") or {}

-- Static collision probe offsets for corner checks (zero-allocation)
---@type {x: number, z: number}[]
local CHECK_OFFSETS = {
	{x = 0, z = 0},
	{x = 0.25, z = 0.25},
	{x = -0.25, z = 0.25},
	{x = 0.25, z = -0.25},
	{x = -0.25, z = -0.25},
}

---@type Vector3 Pre-allocated scratch vector for ground probing
local scratch_probe_pos = {x = 0, y = 0, z = 0}
---@type Vector3 Pre-allocated scratch vector for liquid and ladder checks
local scratch_check_pos = {x = 0, y = 0, z = 0}

---Check if player is in liquid (head or waist) with vertical probe short-circuiting
---@nodiscard
---@param pos Vector3|nil Player world position
---@return boolean in_liquid True if player intersects a liquid node
function x_player_api.is_player_in_liquid(pos)
	if not pos then return false end
	scratch_check_pos.x = pos.x
	scratch_check_pos.z = pos.z
	scratch_check_pos.y = pos.y + 0.8
	local node = core.get_node_or_nil(scratch_check_pos)
	if node then
		local def = core.registered_nodes[node.name]
		if def and ((def.liquidtype and def.liquidtype ~= "none")
			or def.drawtype == "liquid" or def.drawtype == "flowingliquid") then
			return true
		end
	end

	-- Skip second probe if both probes resolve to the same integer node coordinate
	local y1 = math.floor(pos.y + 0.8 + 0.5)
	local y2 = math.floor(pos.y + 0.2 + 0.5)
	if y1 ~= y2 then
		scratch_check_pos.y = pos.y + 0.2
		node = core.get_node_or_nil(scratch_check_pos)
		if node then
			local def = core.registered_nodes[node.name]
			if def and ((def.liquidtype and def.liquidtype ~= "none")
				or def.drawtype == "liquid" or def.drawtype == "flowingliquid") then
				return true
			end
		end
	end
	return false
end

---Check if player is on ladder or climbable node with vertical probe short-circuiting
---@nodiscard
---@param pos Vector3|nil Player world position
---@return boolean on_ladder True if player intersects a climbable node
function x_player_api.is_player_on_ladder(pos)
	if not pos then return false end
	scratch_check_pos.x = pos.x
	scratch_check_pos.z = pos.z

	-- Probe waist/torso height first (most common contact point)
	scratch_check_pos.y = pos.y + 0.5
	local node = core.get_node_or_nil(scratch_check_pos)
	if node then
		local def = core.registered_nodes[node.name]
		if def and def.climbable == true then
			return true
		end
	end

	local y_mid = math.floor(pos.y + 0.5 + 0.5)

	-- Probe upper torso/head height (pos.y + 1.2) if in a different node (jumping or mounting ladder)
	local y_top = math.floor(pos.y + 1.2 + 0.5)
	if y_top ~= y_mid then
		scratch_check_pos.y = pos.y + 1.2
		node = core.get_node_or_nil(scratch_check_pos)
		if node then
			local def = core.registered_nodes[node.name]
			if def and def.climbable == true then
				return true
			end
		end
	end

	-- Probe feet (pos.y) if in a different node
	local y_bot = math.floor(pos.y + 0.5)
	if y_bot ~= y_mid and y_bot ~= y_top then
		scratch_check_pos.y = pos.y
		node = core.get_node_or_nil(scratch_check_pos)
		if node then
			local def = core.registered_nodes[node.name]
			if def and def.climbable == true then
				return true
			end
		end
	end
	return false
end

---Check if a node definition supports the player from below at foot level
---@nodiscard
---@param node_name string Node item name
---@param node_y number Integer node Y coordinate
---@param player_y number Player world Y coordinate
---@param dist? number Maximum probe distance
---@return boolean is_supporting True if node is walkable and provides upward support surface
local function is_node_supporting(node_name, node_y, player_y, dist)
	local def = core.registered_nodes[node_name]
	if not def or not def.walkable then
		return false
	end

	local local_y = player_y - node_y
	-- If local_y is outside node vertical span [-0.5, 0.5], it cannot be inside this node
	if local_y < -0.5 or local_y > 0.5 then
		return true
	end

	-- Node is at foot level: check collision/node box to ensure player is not beneath an inverted/ceiling box
	local cbox = def.collision_box or def.node_box
	if not cbox or cbox.type ~= "fixed" or not cbox.fixed then
		-- Standard full cube (or unspecified box): top face is at local_y = 0.5
		return true
	end

	local max_dist = dist or 0.8
	local fixed = cbox.fixed
	if type(fixed[1]) == "number" then
		-- Single box: {minx, miny, minz, maxx, maxy, maxz}
		local miny = fixed[2]
		local maxy = fixed[5]
		return local_y >= (miny - 0.05) and local_y >= (maxy - 0.1) and local_y <= (maxy + max_dist)
	elseif type(fixed[1]) == "table" then
		-- Multiple boxes: check if any sub-box supports player
		for i = 1, #fixed do
			local box = fixed[i]
			local miny = box[2]
			local maxy = box[5]
			if local_y >= (miny - 0.05) and local_y >= (maxy - 0.1) and local_y <= (maxy + max_dist) then
				return true
			end
		end
		return false
	end

	return true
end

---Check if solid ground is within a vertical distance below player with center-first short-circuiting
---@nodiscard
---@param pos Vector3|nil Player world position
---@param dist number Probe distance downward in nodes
---@param pstate? PlayerControlState Per-player control state for maintaining ground continuity in unloaded chunks
---@return boolean ground_near True if solid walkable node is found within distance
function x_player_api.is_ground_near(pos, dist, pstate)
	if not pos then return false end

	-- Check center column at key probe depths
	scratch_probe_pos.x = pos.x
	scratch_probe_pos.z = pos.z

	-- Depth 1: Immediately below feet (0.25 nodes) to detect direct contact with full blocks, slabs, stairs, snow
	scratch_probe_pos.y = pos.y - 0.25
	local node = core.get_node_or_nil(scratch_probe_pos)
	if node then
		if node.name == "ignore" then
			return pstate == nil or pstate.was_on_ground ~= false
		end
		local def = core.registered_nodes[node.name]
		if def and def.walkable then
			return true
		end
	elseif pstate and pstate.was_on_ground ~= false then
		-- Unloaded chunk: retain grounded state to avoid false airborne hover on join
		return true
	end

	-- Depth 2: Foot level (pos.y) for thin walkable nodeboxes (e.g. lotus leaves, waterlilies, carpets)
	-- whose top collision surface resides in the lower portion of the node (nodebox max_y < -0.25).
	scratch_probe_pos.y = pos.y
	node = core.get_node_or_nil(scratch_probe_pos)
	if node then
		if node.name == "ignore" then
			return pstate == nil or pstate.was_on_ground ~= false
		end
		local node_y = math.floor(pos.y + 0.5)
		if is_node_supporting(node.name, node_y, pos.y, dist) then
			return true
		end
	elseif pstate and pstate.was_on_ground ~= false then
		return true
	end

	-- Depth 2: Target distance downward (e.g. 0.8 nodes for slope/stair steps)
	if dist > 0.25 then
		scratch_probe_pos.y = pos.y - dist
		node = core.get_node_or_nil(scratch_probe_pos)
		if node then
			if node.name == "ignore" then
				return pstate == nil or pstate.was_on_ground ~= false
			end
			local def = core.registered_nodes[node.name]
			if def and def.walkable then
				return true
			end
		elseif pstate and pstate.was_on_ground ~= false then
			return true
		end
	end

	if dist > 1.2 then
		scratch_probe_pos.y = pos.y - 0.8
		node = core.get_node_or_nil(scratch_probe_pos)
		if node then
			if node.name == "ignore" then
				return pstate == nil or pstate.was_on_ground ~= false
			end
			local def = core.registered_nodes[node.name]
			if def and def.walkable then
				return true
			end
		end
	end

	local center_nx = math.floor(pos.x + 0.5)
	local center_nz = math.floor(pos.z + 0.5)
	local dx = math.abs(pos.x - center_nx)
	local dz = math.abs(pos.z - center_nz)
	if dx < 0.25 and dz < 0.25 then
		return false
	end

	-- Check outer corners only if they cross into different node columns
	local prev_nx, prev_nz = center_nx, center_nz
	for index = 2, 5 do
		local off = CHECK_OFFSETS[index]
		local probe_x = pos.x + off.x
		local probe_z = pos.z + off.z
		local c_nx = math.floor(probe_x + 0.5)
		local c_nz = math.floor(probe_z + 0.5)

		if (c_nx ~= center_nx or c_nz ~= center_nz) and (c_nx ~= prev_nx or c_nz ~= prev_nz) then
			prev_nx, prev_nz = c_nx, c_nz
			scratch_probe_pos.x = probe_x
			scratch_probe_pos.z = probe_z

			scratch_probe_pos.y = pos.y - 0.25
			node = core.get_node_or_nil(scratch_probe_pos)
			if node then
				local def = core.registered_nodes[node.name]
				if def and def.walkable then
					return true
				end
			end

			scratch_probe_pos.y = pos.y
			node = core.get_node_or_nil(scratch_probe_pos)
			if node then
				if node.name == "ignore" then
					return pstate == nil or pstate.was_on_ground ~= false
				end
				local node_y = math.floor(pos.y + 0.5)
				if is_node_supporting(node.name, node_y, pos.y, dist) then
					return true
				end
			elseif pstate and pstate.was_on_ground ~= false then
				return true
			end

			if dist > 0.25 then
				scratch_probe_pos.y = pos.y - dist
				node = core.get_node_or_nil(scratch_probe_pos)
				if node then
					local def = core.registered_nodes[node.name]
					if def and def.walkable then
						return true
					end
				end
			end

			if dist > 1.2 then
				scratch_probe_pos.y = pos.y - 0.8
				node = core.get_node_or_nil(scratch_probe_pos)
				if node then
					local def = core.registered_nodes[node.name]
					if def and def.walkable then
						return true
					end
				end
			end
		end
	end
	return false
end

---Perform unified environmental spatial probing for water, ladder, ground, and air
---@nodiscard
---@param pos Vector3 Player world position
---@param vel Vector3 Player velocity vector
---@param pstate PlayerControlState? Player internal control state
---@return boolean in_water Whether player is in water
---@return boolean on_ladder Whether player is on ladder or vine
---@return boolean is_on_ground Whether player is supported by ground
---@return boolean in_air Whether player is airborne
function x_player_api.detect_environment(pos, vel, pstate)
	local in_water = x_player_api.is_player_in_liquid(pos)
	local on_ladder = x_player_api.is_player_on_ladder(pos)
	local ground_probe_dist = (vel.y < -0.5) and 0.35 or 0.8
	local is_on_ground = x_player_api.is_ground_near(pos, ground_probe_dist, pstate)
	local in_air = not is_on_ground
	if pstate then
		pstate.was_on_ground = is_on_ground
		if is_on_ground then
			pstate.was_jumping = false
		end
	end
	return in_water, on_ladder, is_on_ground, in_air
end

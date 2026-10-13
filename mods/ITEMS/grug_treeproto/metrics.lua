-- Tree prototype (Round 46 lane TREE): node and face counts of one tree, by
-- the client's own culling rules, so the render cost of today's trees and
-- the drafts can be compared.
--
-- The rules (reference_projects/luanti, 5.17.0-dev):
--   * a full cube ("normal") skips a face only towards the same node or a
--     neighbour of solidness 2, i.e. another full cube
--     (src/client/content_mapblock.cpp drawSolidNode);
--   * fancy leaves are drawn as allfaces: all six faces of every leaf node,
--     always (node_visuals.cpp: allfaces_optional -> NDT_ALLFACES under
--     leaves_style = fancy; content_mapblock.cpp drawAllfacesNode);
--   * a node box draws six faces per box, except a face lying on the node
--     boundary towards a full-cube neighbour, and a pair of opposite faces of
--     a box spanning the node towards the same node with the same rotation
--     (content_mapblock.cpp getNodeBoxMask and drawNodeboxNode; node boxes
--     default to opaque, lua_api.md use_texture_alpha); faces inside
--     the node (between its own boxes) are drawn too;
--   * a connected node box gets its arms from its six face neighbours
--     (nodedef.cpp nodeboxConnects);
--   * a plantlike node (the apple) is counted as two quads.
-- The ground (y <= 0) counts as full cubes.
--
-- count(cells, describe) takes a list of {x, y, z, name, param2} and a
-- function name -> {draw = "normal" | "allfaces" | "plantlike" | "nodebox",
-- shape = shapes.lua key, connects = set of names, wood = true}.
--
-- Plain Lua 5.1, pure.

return function(shapes)
	local M = {}

	local function key(x, y, z)
		return ((y + 64) * 256 + (z + 128)) * 256 + (x + 128)
	end

	-- face direction bits as the engine's masks use them: 1 +y, 2 -y, 4 +x,
	-- 8 -x, 16 +z, 32 -z
	local FLAGS = {1, 2, 4, 8, 16, 32}
	local DIRS = {{0, 1, 0, 1}, {0, -1, 0, 2}, {1, 0, 0, 4}, {-1, 0, 0, 8},
		{0, 0, 1, 16}, {0, 0, -1, 32}}

	function M.count(cells, describe)
		local at = {}
		for _, cell in ipairs(cells) do at[key(cell.x, cell.y, cell.z)] = cell end
		local function neighbour(cell, d)
			local y = cell.y + d[2]
			local other = at[key(cell.x + d[1], y, cell.z + d[3])]
			if other then return other, describe(other.name) end
			if y <= 0 then return "ground", {draw = "normal"} end
			return nil, nil
		end
		local result = {nodes = 0, wood = 0, faces = 0, wood_faces = 0,
			leaf_faces = 0, by_name = {}}
		for _, cell in ipairs(cells) do
			local info = describe(cell.name)
			local faces = 0
			if info.draw == "allfaces" then
				faces = 6
			elseif info.draw == "plantlike" then
				faces = 2
			elseif info.draw == "normal" then
				for _, d in ipairs(DIRS) do
					local other, other_info = neighbour(cell, d)
					local culled = other ~= nil and (other == "ground" or
						other.name == cell.name or other_info.draw == "normal")
					if not culled then faces = faces + 1 end
				end
			elseif info.draw == "nodebox" then
				local solid, same, connected = 0, 0, {}
				for _, d in ipairs(DIRS) do
					local other, other_info = neighbour(cell, d)
					if other ~= nil then
						if other == "ground" or other_info.draw == "normal" then
							solid = solid + d[4]
						end
						if other ~= "ground" and other.name == cell.name and
								(other.param2 or 0) == (cell.param2 or 0) then
							same = same + d[4]
						end
					end
				end
				if info.connects then
					for _, side in ipairs(shapes.SIDES) do
						local o = shapes.SIDE_OFFSET[side]
						local other = at[key(cell.x + o[1], cell.y + o[2], cell.z + o[3])]
						if other and info.connects[other.name] then
							connected[side] = true
						end
					end
				end
				for _, box in ipairs(shapes.boxes(info.shape, cell.param2, connected)) do
					local mask = 0
					if box[5] == 8 then mask = mask + 1 end
					if box[2] == -8 then mask = mask + 2 end
					if box[4] == 8 then mask = mask + 4 end
					if box[1] == -8 then mask = mask + 8 end
					if box[6] == 8 then mask = mask + 16 end
					if box[3] == -8 then mask = mask + 32 end
					local pairs_mask = 0
					if mask % 4 == 3 then pairs_mask = pairs_mask + 3 end
					if math.floor(mask / 4) % 4 == 3 then pairs_mask = pairs_mask + 12 end
					if math.floor(mask / 16) % 4 == 3 then pairs_mask = pairs_mask + 48 end
					for _, flag in ipairs(FLAGS) do
						local skip = (math.floor(mask / flag) % 2 == 1 and
							math.floor(solid / flag) % 2 == 1) or
							(math.floor(pairs_mask / flag) % 2 == 1 and
							math.floor(same / flag) % 2 == 1)
						if not skip then faces = faces + 1 end
					end
				end
			end
			result.nodes = result.nodes + 1
			result.faces = result.faces + faces
			local entry = result.by_name[cell.name] or {nodes = 0, faces = 0}
			entry.nodes = entry.nodes + 1
			entry.faces = entry.faces + faces
			result.by_name[cell.name] = entry
			if info.wood then
				result.wood = result.wood + 1
				result.wood_faces = result.wood_faces + faces
			elseif info.draw == "allfaces" then
				result.leaf_faces = result.leaf_faces + faces
			end
		end
		return result
	end

	return M
end

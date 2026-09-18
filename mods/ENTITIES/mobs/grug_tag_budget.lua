-- GRUG PATCH: observer-managed nametag children are presentation objects, not
-- spawn pressure. Remove only those children from the engine's wider AOC count
-- when that raw count would otherwise reject a spawn.

local M = {}

function M.effective_count(core_api, pos, raw_count, limit)
	if not raw_count or raw_count < limit then return raw_count end
	local base_x = math.floor(pos.x / 16) * 16
	local base_y = math.floor(pos.y / 16) * 16
	local base_z = math.floor(pos.z / 16) * 16
	local objects = core_api.get_objects_in_area(
		{x = base_x - 16, y = base_y - 16, z = base_z - 16},
		{x = base_x + 31, y = base_y + 31, z = base_z + 31})
	local carriers = 0
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		if entity and entity.name == "grug_core:tag_carrier" then
			carriers = carriers + 1
		end
	end
	return math.max(0, raw_count - carriers)
end

return M

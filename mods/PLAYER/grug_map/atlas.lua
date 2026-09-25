-- Pure atlas geometry and marker collection. The per-world base image
-- (base.lua) is rendered over these exact bounds; runtime markers and labels
-- never become pixels in it.

local M = {}

local WORLD = {label = "World", texture = "",
	min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200}
local providers = {}

-- Set once at load time to the rendered base's media name (or a fallback).
function M.set_base_texture(texture)
	assert(type(texture) == "string" and texture ~= "",
		"[grug_map] invalid base texture")
	WORLD.texture = texture
end

function M.views()
	return {{id = "world", view = M.view()}}
end

function M.view()
	return {label = WORLD.label, texture = WORLD.texture, min_x = WORLD.min_x,
		max_x = WORLD.max_x, min_z = WORLD.min_z, max_z = WORLD.max_z}
end

-- Scroll units represent one thousandth of the unzoomed viewport on each axis.
-- Thus both axes use the same integer range despite the 9:8 viewport aspect.
function M.scroll_limit(zoom)
	return (zoom - 1) * 1000
end

function M.clamp_scroll(value, zoom)
	if type(value) ~= "number" or value ~= value then return 0 end
	return math.floor(math.max(0, math.min(M.scroll_limit(zoom), value)) + 0.5)
end

function M.zoom_scroll(value, old_zoom, new_zoom)
	return M.clamp_scroll((value + 500) * new_zoom / old_zoom - 500, new_zoom)
end

function M.contains(view, position)
	return type(position) == "table" and type(position.x) == "number" and
		type(position.z) == "number" and position.x >= view.min_x and
		position.x <= view.max_x and position.z >= view.min_z and
		position.z <= view.max_z
end

function M.world_to_screen(view, position, x, y, width, height)
	if not M.contains(view, position) then return nil end
	local sx = x + (position.x - view.min_x) /
		(view.max_x - view.min_x) * width
	local sy = y + (view.max_z - position.z) /
		(view.max_z - view.min_z) * height
	return sx, sy
end

function M.register_marker_provider(name, callback)
	assert(type(name) == "string" and name ~= "" and
		type(callback) == "function", "[grug_map] invalid marker provider")
	assert(not providers[name], "[grug_map] duplicate marker provider " .. name)
	providers[name] = callback
end

function M.collect_markers(player)
	local result, ids = {}, {}
	for name, callback in pairs(providers) do
		local rows = callback(player) or {}
		assert(type(rows) == "table", "[grug_map] marker provider returned non-table")
		for index = 1, #rows do
			local row = rows[index]
			assert(type(row) == "table" and type(row.id) == "string" and
				row.id ~= "" and type(row.label) == "string" and
				type(row.position) == "table" and
				type(row.position.x) == "number" and
				type(row.position.z) == "number",
				"[grug_map] invalid marker from " .. name)
			local id = name .. ":" .. row.id
			assert(not ids[id], "[grug_map] duplicate marker " .. id)
			ids[id] = true
			result[#result + 1] = {id = id, label = row.label,
				detail = row.detail or row.label, kind = row.kind or "poi",
				heading = row.heading, status = row.status, texture = row.texture,
				position = {x = row.position.x, y = row.position.y,
					z = row.position.z}}
		end
	end
	local layers = {settlement = 1, hostile = 1, trainer = 2, boss = 2,
		innkeeper = 2, home = 2, quest = 3, party = 4, player = 5}
	table.sort(result, function(a, b)
		local al, bl = layers[a.kind] or 1, layers[b.kind] or 1
		if al ~= bl then return al < bl end
		return a.id < b.id
	end)
	return result
end

-- Injective field identity survives marker insertion/removal and list reordering.
function M.field_id(id)
	return "grug_map_marker_" .. id:gsub(".", function(c)
		return ("%02x"):format(string.byte(c))
	end)
end

function M.heading_frame(yaw)
	return math.floor((yaw or 0) / (2 * math.pi) * 16 + 0.5) % 16
end

return M

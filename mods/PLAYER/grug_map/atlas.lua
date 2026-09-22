-- Pure atlas geometry and marker collection. The background images use these
-- exact authored bounds; runtime markers never become pixels in those images.

local M = {}

local VIEWS = {
	world = {label = "World", texture = "grug_map_atlas_world.png",
		min_x = -3600, max_x = 3600, min_z = -3200, max_z = 3200},
	dwarf = {label = "Dwarf lands", texture = "grug_map_atlas_dwarf.png",
		min_x = -2700, max_x = -900, min_z = -3000, max_z = -1400},
	human = {label = "Human lands", texture = "grug_map_atlas_human.png",
		min_x = -900, max_x = 900, min_z = -3000, max_z = -1400},
	elf = {label = "Elf lands", texture = "grug_map_atlas_elf.png",
		min_x = 900, max_x = 2700, min_z = -3000, max_z = -1400},
	undead = {label = "Undead lands", texture = "grug_map_atlas_undead.png",
		min_x = -2700, max_x = -900, min_z = 1400, max_z = 3000},
	orc = {label = "Orc lands", texture = "grug_map_atlas_orc.png",
		min_x = -900, max_x = 900, min_z = 1400, max_z = 3000},
	troll = {label = "Troll lands", texture = "grug_map_atlas_troll.png",
		min_x = 900, max_x = 2700, min_z = 1400, max_z = 3000},
}
local VIEW_ORDER = {"world", "dwarf", "human", "elf", "undead", "orc", "troll"}
local providers = {}

local function copy_view(view)
	return {label = view.label, texture = view.texture, min_x = view.min_x,
		max_x = view.max_x, min_z = view.min_z, max_z = view.max_z}
end

function M.views()
	local result = {}
	for index = 1, #VIEW_ORDER do
		local id = VIEW_ORDER[index]
		result[index] = {id = id, view = copy_view(VIEWS[id])}
	end
	return result
end

function M.view(id)
	return copy_view(VIEWS[id] or VIEWS.world)
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


-- Dragon arena layout (Round 31 DA2, round31-plan.md §6 item 11): which
-- hazard every column of a dragon arena carries, relative to the arena's
-- anchor. Pure data and arithmetic, no engine calls: the mapgen writer
-- (`arena_writer.lua`), grug_mobs (the dragon's arena and the hazard ticks)
-- and the fixtures read the same answers. Every shape is a union of circles
-- or a jagged line from integer offsets (no trigonometry), so the answer is
-- the same on every interpreter.
local M = {}

-- Node names the writer places and grug_mobs reacts to.
M.NODES = {
	thin_ice = "grug_mapgen:arena_thin_ice",
	ice_water = "grug_mapgen:arena_ice_water",
	frost_stone = "grug_mapgen:arena_frost_stone",
	ember = "grug_mapgen:arena_ember",
	basalt = "grug_mapgen:arena_basalt",
}

-- The theme of a dragon arena by its zone; the rim stone material.
M.THEMES = {
	front_wyrmglass_crown = {id = "wyrmglass", rim = "default:stone"},
	front_stormscale_summit = {id = "stormscale", rim = "default:mossycobble"},
}

-- The dragon's rest positions (bosses.lua), kept clear of every hazard.
M.PERCHES = {{0, 0}, {18, 8}, {-15, 12}}
-- No hazard nearer the spawn than this; none beyond radius - EDGE_MARGIN.
M.SPAWN_CLEAR, M.EDGE_MARGIN = 9, 4

-- Breaking ice: blobs of a main circle and a smaller offset one {x, z, r}.
local ICE = {
	{-12, -12, 4.5}, {13, -20, 4.5}, {26, -4, 4.5}, {-28, 6, 4},
	{8, 26, 4}, {-6, -31, 4}, {-30, -6, 4},
}
-- Frost terraces: level-1 circles and the level-2 circles inside them.
local TERRACES = {
	{outer = {{-22, -18, 6}, {-17, -24, 4}}, inner = {{-21, -20, 3}}},
	{outer = {{26, 16, 5}, {21, 23, 4}}, inner = {{25, 18, 3}}},
	{outer = {{-12, 26, 5}, {-5, 30, 4}}, inner = {{-10, 27, 3}}},
}
-- Ember fissures {x1, z1, x2, z2, width}; the zigzag offsets across them.
local FISSURES = {
	{-30, -10, -16, -4, 2}, {4, -32, 9, -17, 2}, {30, -6, 18, -1, 1},
	{-10, 30, -6, 18, 1}, {20, 26, 28, 16, 2}, {-22, -24, -12, -29, 1},
}
local ZIGZAG = {0, 1, 1, 0, -1, -1, 0, 1, 0, -1}
-- Fallen trunks, one node high {x, z, length, axis}.
local TRUNKS = {
	{-20, 4, 8, "x"}, {-4, -20, 7, "x"}, {10, 18, 8, "z"},
	{24, -18, 8, "z"}, {-30, 12, 7, "z"},
}

local function in_circles(circles, dx, dz)
	for index = 1, #circles do
		local c = circles[index]
		local ex, ez = dx - c[1], dz - c[2]
		if ex * ex + ez * ez <= c[3] * c[3] then return index end
	end
	return nil
end

local ice_circles = {}
for _, b in ipairs(ICE) do
	ice_circles[#ice_circles + 1] = b
	ice_circles[#ice_circles + 1] = {b[1] + b[3] * 0.6, b[2] - b[3] * 0.4, b[3] * 0.6}
end

-- The cells of every fissure (a set keyed "dx,dz") and of its basalt rim.
local fissure_cells, rim_cells = {}, {}
local function key(dx, dz) return dx .. "," .. dz end
for _, f in ipairs(FISSURES) do
	local x1, z1, x2, z2, width = f[1], f[2], f[3], f[4], f[5]
	local steps = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	local along_x = math.abs(x2 - x1) >= math.abs(z2 - z1)
	for i = 0, steps do
		local x = x1 + math.floor((x2 - x1) * i / steps + 0.5)
		local z = z1 + math.floor((z2 - z1) * i / steps + 0.5)
		local off = ZIGZAG[(i % #ZIGZAG) + 1]
		for w = 0, width - 1 do
			if along_x then fissure_cells[key(x, z + off + w)] = true
			else fissure_cells[key(x + off + w, z)] = true end
		end
	end
end
for cell in pairs(fissure_cells) do
	local x, z = cell:match("^(-?%d+),(-?%d+)$")
	x, z = tonumber(x), tonumber(z)
	for ez = -1, 1 do
		for ex = -1, 1 do
			local k = key(x + ex, z + ez)
			if not fissure_cells[k] then rim_cells[k] = true end
		end
	end
end
local trunk_cells = {}
for _, t in ipairs(TRUNKS) do
	for i = 0, t[3] - 1 do
		if t[4] == "x" then trunk_cells[key(t[1] + i, t[2])] = 12
		else trunk_cells[key(t[1], t[2] + i)] = 4 end
	end
end

-- A small integer hash of a world column, for the sparse rim stones.
local function hash(x, z)
	local h = (x * 73856093 + z * 19349663) % 1048573
	return (h * h + 40503) % 1048573
end

-- The hazard of the column (dx, dz) of an arena of `radius` whose theme is
-- `theme`, at world column (x, z): nil, or kind and detail:
--   "thin_ice"; "frost", level (1 or 2) and the terrace's centre {dx, dz};
--   "ember"; "basalt"; "trunk", param2 (12 along x, 4 along z);
--   "rim", the stone's height (1 or 2) and the rim node name.
function M.hazard_at(theme, radius, dx, dz, x, z)
	local d2 = dx * dx + dz * dz
	local r = math.floor(math.sqrt(d2) + 0.5)
	if r == radius then
		local h = hash(x, z)
		if h % 5 == 0 then return "rim", h % 15 == 0 and 2 or 1, theme.rim end
		return nil
	end
	if r > radius - M.EDGE_MARGIN then return nil end
	if theme.id == "wyrmglass" then
		for index = 1, #TERRACES do
			local t = TERRACES[index]
			if in_circles(t.outer, dx, dz) then
				local c = t.outer[1]
				return "frost", in_circles(t.inner, dx, dz) and 2 or 1, {c[1], c[2]}
			end
		end
		if in_circles(ice_circles, dx, dz) then return "thin_ice" end
	elseif theme.id == "stormscale" then
		local k = key(dx, dz)
		if fissure_cells[k] then return "ember" end
		if rim_cells[k] then return "basalt" end
		if trunk_cells[k] then return "trunk", trunk_cells[k] end
	end
	return nil
end

-- Every dragon arena of the source map: {id, zone, x, z, radius, theme}.
function M.arenas(source)
	local profile_by_id = {}
	for _, p in ipairs(source.anchor_profiles) do profile_by_id[p.id] = p end
	local out = {}
	for _, a in ipairs(source.anchors) do
		local p = profile_by_id[a.template_id]
		if p and p.arena_radius then
			local zone = source.zones[a.zone_numeric_id]
			local theme = M.THEMES[zone.id]
			assert(theme, "dragon arena without a theme: " .. tostring(zone.id))
			out[#out + 1] = {id = theme.id, zone = zone.id, x = a.position.x,
				z = a.position.z, radius = p.arena_radius, theme = theme}
		end
	end
	return out
end

return M

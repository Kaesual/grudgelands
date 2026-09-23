-- Lightweight atlas renderer. It reads authored control geometry only: no
-- mapgen session, terrain sampling, chunk generation or world access.

local repo = assert(arg[1], "repository root required")
local output = assert(arg[2], "SVG output required")
local view_id = arg[3] or "world"
local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local known_view = false
for _, row in ipairs(atlas.views()) do
	if row.id == view_id then known_view = true end
end
assert(known_view, "unknown atlas view")
local bounds = atlas.view(view_id)
local min_x, max_x = bounds.min_x, bounds.max_x
local min_z, max_z = bounds.min_z, bounds.max_z
local height = 800
local width = math.floor(height * (max_x - min_x) / (max_z - min_z) + 0.5)
local function sx(x) return (x - min_x) / (max_x - min_x) * width end
local function sy(z) return (max_z - z) / (max_z - min_z) * height end
local function n(value) return ("%.2f"):format(value) end
local function escape(value)
	local amp = string.char(38)
	return tostring(value):gsub(amp, amp .. "amp;"):gsub("<", amp .. "lt;"):
		gsub(">", amp .. "gt;"):gsub('"', amp .. "quot;")
end
local function points(values)
	local result = {}
	for index = 1, #values do
		result[index] = n(sx(values[index].x)) .. "," .. n(sy(values[index].z))
	end
	return table.concat(result, " ")
end

local file = assert(io.open(output, "wb"))
local function write(...) assert(file:write(...)) end
write('<?xml version="1.0" encoding="UTF-8"?>\n')
write(('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'):
	format(width, height, width, height))
write(('<rect width="%d" height="%d" fill="#16384a"/>\n'):format(width, height))
write('<g fill="#bba875" stroke="#eadca8" stroke-width="3">\n')
for index = 1, #source.land_primitives do
	local row = source.land_primitives[index]
	if row.kind == "rounded_rect" then
		write('<rect x="', n(sx(row.min_x)), '" y="', n(sy(row.max_z)),
			'" width="', n((row.max_x - row.min_x) / (max_x - min_x) * width),
			'" height="', n((row.max_z - row.min_z) / (max_z - min_z) * height),
			'" rx="18"/>\n')
	elseif (row.primitive or row.kind) == "ellipse" then
		write('<ellipse cx="', n(sx(row.center.x)), '" cy="', n(sy(row.center.z)),
			'" rx="', n(row.radius_x / (max_x - min_x) * width), '" ry="',
			n(row.radius_z / (max_z - min_z) * height), '"/>\n')
	elseif row.kind == "capsule" then
		write('<line x1="', n(sx(row.a.x)), '" y1="', n(sy(row.a.z)),
			'" x2="', n(sx(row.b.x)), '" y2="', n(sy(row.b.z)),
			'" stroke="#bba875" stroke-width="',
			n(2 * row.radius / (max_x - min_x) * width),
			'" stroke-linecap="round"/>\n')
	end
end
for index = 1, #source.islands do
	write('<polygon points="', points(source.islands[index].polygon), '"/>\n')
end
write('</g>\n')
-- Bays are authored subtractive water corridors. Painting them after the
-- positive macro land preserves the readable coastline without evaluating a
-- production map session.
write('<g fill="none" stroke="#16384a" stroke-linecap="round">\n')
for index = 1, #source.bays do
	local bay = source.bays[index]
	for point_index = 1, #bay.centreline - 1 do
		local a, b = bay.centreline[point_index], bay.centreline[point_index + 1]
		local half_width = (a.half_width + b.half_width) / 2
		write('<line x1="', n(sx(a.x)), '" y1="', n(sy(a.z)),
			'" x2="', n(sx(b.x)), '" y2="', n(sy(b.z)),
			'" stroke-width="', n(2 * half_width / (max_x - min_x) * width),
			'"/>\n')
	end
end
write('</g>\n')
write('<g fill="none" stroke="#6e5534" stroke-linecap="round" stroke-linejoin="round">\n')
local route_width = {primary = 5, secondary = 3.5, trail = 2}
for index = 1, #source.routes do
	local route = source.routes[index]
	write('<polyline points="', points(route.centreline), '" stroke-width="',
		tostring(route_width[route.class] or 2), '"/>\n')
end
for index = 1, #source.island_routes do
	write('<polyline points="', points(source.island_routes[index].centreline),
		'" stroke-width="3"/>\n')
end
write('</g>\n')
write('<g font-family="sans-serif" text-anchor="middle" paint-order="stroke" stroke="#efe3bb" stroke-width="4" fill="#33271b">\n')
if view_id == "world" then
	-- At whole-world scale, 38 zone labels become unreadable. Region views
	-- retain every zone name; this overview names only the six culture lands,
	-- the central front and the two edge islands. Clamp the island label anchors
	-- because their zone hubs intentionally sit close to the authored extent.
	local labels = {
		{"Dwarven Lands", -1800, -2350}, {"Human Lands", 0, -2350},
		{"Elven Lands", 1800, -2350}, {"Undead Lands", -1800, 2350},
		{"Orc Lands", 0, 2350}, {"Troll Lands", 1800, 2350},
		{"The Contested Front", 0, 0},
		{"Wyrmglass Crown", -3150, 0}, {"Stormscale Summit", 3150, 0},
	}
	for index = 1, #labels do
		local row = labels[index]
		local x = math.max(92, math.min(width - 92, sx(row[2])))
		write('<text x="', n(x), '" y="', n(sy(row[3]) - 8),
			'" font-size="16" font-weight="bold">', escape(row[1]), '</text>\n')
	end
else
	for index = 1, #source.zones do
		local zone = source.zones[index]
		if zone.hub.x >= min_x and zone.hub.x <= max_x and
				zone.hub.z >= min_z and zone.hub.z <= max_z then
			write('<text x="', n(sx(zone.hub.x)), '" y="',
				n(sy(zone.hub.z) - 8), '" font-size="18">',
				escape(zone.display_name), '</text>\n')
		end
	end
end
write(('</g>\n<rect x="2" y="2" width="%d" height="%d" fill="none" stroke="#e8d49a" stroke-width="4"/>\n</svg>\n'):
	format(width - 4, height - 4))
assert(file:close())

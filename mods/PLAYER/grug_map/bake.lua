-- The baked map layer (Round 44, world_map.md "Baked layer"): settlement,
-- point-of-interest and boss icons and the region names in a pixel font,
-- drawn by the base renderer (base.lua) into the map images themselves.
-- The world-map image gets the icons and the names, the minimap's image the
-- small icons only. PURE Lua: no engine calls, so the portable fixture
-- (tools/r44_mb/portable_test.lua) runs it as it ships. The art and the font
-- come as data from baked_art.lua (tools/r44_mb/gen_baked_art.py), since
-- the engine decodes no PNG for Lua.
--
-- Images are the renderer's packed RGB arrays (r * 65536 + g * 256 + b, row
-- by row from the top-left, 1-based). This file's own source is the layout
-- version in the base's cache key: changing a scale, a colour, a name or
-- its place re-renders every world's map at its next start.

local B = {}

-- Draw scale per image, nearest-neighbour. A 16 px icon is 32 px in the
-- normal image (about 0.37 formspec units on the Map tab at zoom 1, where
-- the overlay icons are 0.34) and 96 px in the high one (0.33); the 6 px
-- minimap icons stay as they are (about 18 screen pixels at 1080p, beside
-- the minimap's 16 px markers). Names use the same scale as the icons:
-- a cap height of 14 px at normal, 42 at high.
B.SCALE = {normal = 2, high = 6, mini = 1}
-- Light names on a dark halo of one glyph pixel read on land and sea.
B.TEXT = {243, 232, 200}
B.HALO = {42, 28, 16}
-- Glyph pixels between two glyphs and between two lines of a name.
B.LETTER_GAP, B.LINE_GAP = 1, 1

-- Every kind of the art, in draw order (later on top): the bosses last.
B.KINDS = {"war_camp", "outpost", "village", "mine", "clash", "rare_den", "bandit",
	"mirefolk", "fortress", "start", "capital", "king", "dragon"}
local ORDER = {}
for index, kind in ipairs(B.KINDS) do ORDER[kind] = index end

-- A dragon arena is a settlement (slot "dragon") and the dragon's own
-- marker at the same place: a dragon settlement within this many nodes of
-- a dragon is not drawn again.
B.SAME_PLACE = 64

-- The region names (Round 22 macro layout, world_zones.md §7.1): text,
-- world x and z, and the clearance box in formspec units that the Map tab's
-- zone markers keep from the name (location.lua, an estimate of the drawn
-- text). `wrap` puts one word on each line. The island names stand over the
-- sea just north of their islands, clear of the dragon arenas.
B.REGION_LABELS = {
	{"Dwarven Lands", -1800, -2350, 4.6, 1.3}, {"Human Lands", 0, -2350, 4.6, 1.3},
	{"Elven Lands", 1800, -2350, 4.6, 1.3}, {"Undead Lands", -1800, 2350, 4.6, 1.3},
	{"Orc Lands", 0, 2350, 4.6, 1.3}, {"Troll Lands", 1800, 2350, 4.6, 1.3},
	{"The Contested Front", 0, 0, 4.6, 1.3},
	{"Wyrmglass Crown", -3150, 440, 2.4, 2.0, wrap = true},
	{"Stormscale Summit", 3150, 440, 2.4, 2.0, wrap = true},
}

-- The icons to bake from plain rows {kind, x, z}: `settlements` (kind nil:
-- a slot of no known kind, not drawn but counted), `kings` and `dragons`
-- ({x, z} each). Returns the items {kind, x, z} in draw order (by kind,
-- then x, then z) and the count of settlements without a kind.
function B.items(settlements, kings, dragons)
	local items, unknown = {}, 0
	local function near_dragon(row)
		for _, dragon in ipairs(dragons) do
			local dx, dz = row.x - dragon.x, row.z - dragon.z
			if dx * dx + dz * dz <= B.SAME_PLACE * B.SAME_PLACE then return true end
		end
		return false
	end
	for _, row in ipairs(settlements) do
		if not row.kind then
			unknown = unknown + 1
		elseif not (row.kind == "dragon" and near_dragon(row)) then
			items[#items + 1] = {kind = row.kind, x = row.x, z = row.z}
		end
	end
	for _, row in ipairs(kings) do items[#items + 1] = {kind = "king", x = row.x, z = row.z} end
	for _, row in ipairs(dragons) do items[#items + 1] = {kind = "dragon", x = row.x, z = row.z} end
	table.sort(items, function(a, b)
		local oa, ob = ORDER[a.kind] or 0, ORDER[b.kind] or 0
		if oa ~= ob then return oa < ob end
		if a.x ~= b.x then return a.x < b.x end
		return a.z < b.z
	end)
	return items, unknown
end

-- What the cache key must cover besides the terrain: the layout (this
-- file), the art and the font versions and every icon's kind and place.
function B.key_text(versions, items)
	local parts = {"bake", tostring(versions.layout), tostring(versions.art),
		tostring(versions.font)}
	for _, item in ipairs(items) do
		parts[#parts + 1] = item.kind .. ":" .. item.x .. "," .. item.z
	end
	return table.concat(parts, "\n")
end

-- A name's glyphs in glyph pixels: the text upper-cased, one word per line
-- when `wrap`, each line centred. Returns {width, height, glyphs = {{char,
-- x, y}}, missing} with a one-pixel halo border included in the size;
-- a character the font lacks takes a space's width and counts as missing.
function B.layout(font, text, wrap)
	local lines = {}
	text = text:upper()
	if wrap then
		for word in text:gmatch("%S+") do lines[#lines + 1] = word end
	else
		lines[1] = text
	end
	local space = font.glyphs[" "]
	local blank = space and #space[1] or 3
	local widths, widest, missing = {}, 0, 0
	for index, line in ipairs(lines) do
		local width = 0
		for i = 1, #line do
			local glyph = font.glyphs[line:sub(i, i)]
			if not glyph then missing = missing + 1 end
			width = width + (glyph and #glyph[1] or blank) + (i > 1 and B.LETTER_GAP or 0)
		end
		widths[index] = width
		if width > widest then widest = width end
	end
	local result = {width = widest + 2,
		height = #lines * font.height + (#lines - 1) * B.LINE_GAP + 2, glyphs = {},
		missing = missing}
	for index, line in ipairs(lines) do
		local x = 1 + math.floor((widest - widths[index]) / 2)
		local y = 1 + (index - 1) * (font.height + B.LINE_GAP)
		for i = 1, #line do
			local char = line:sub(i, i)
			local glyph = font.glyphs[char]
			if glyph then result.glyphs[#result.glyphs + 1] = {char = char, x = x, y = y} end
			x = x + (glyph and #glyph[1] or blank) + B.LETTER_GAP
		end
	end
	return result
end

-- The layout's cells, row by row from 0: 2 a glyph pixel, 1 its halo (the
-- eight neighbours of a glyph pixel), nil empty.
function B.mask(font, layout)
	local w, cells = layout.width, {}
	for _, placed in ipairs(layout.glyphs) do
		for gy, row in ipairs(font.glyphs[placed.char]) do
			for gx = 1, #row do
				if row:sub(gx, gx) == "#" then
					local x, y = placed.x + gx - 1, placed.y + gy - 1
					for dy = -1, 1 do
						for dx = -1, 1 do
							local index = (y + dy) * w + x + dx
							cells[index] = cells[index] or 1
						end
					end
				end
			end
		end
	end
	for _, placed in ipairs(layout.glyphs) do
		for gy, row in ipairs(font.glyphs[placed.char]) do
			for gx = 1, #row do
				if row:sub(gx, gx) == "#" then
					cells[(placed.y + gy - 1) * w + placed.x + gx - 1] = 2
				end
			end
		end
	end
	return cells
end

-- An icon of the art as rows of {r, g, b, a} (nil: transparent), decoded
-- once.
local decoded = setmetatable({}, {__mode = "k"})
function B.decode(icon)
	local known = decoded[icon]
	if known then return known end
	-- palette: symbol -> "rrggbbaa"; every symbol has the same length
	local symbols, code = {}, 1
	for symbol, hex in pairs(icon.palette) do
		local a = tonumber(hex:sub(7, 8), 16)
		symbols[symbol] = a > 0 and {tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16),
			tonumber(hex:sub(5, 6), 16), a} or false
		code = #symbol
	end
	local cells = {}
	for y, row in ipairs(icon.rows) do
		for x = 1, icon.w do
			cells[(y - 1) * icon.w + x] = symbols[row:sub((x - 1) * code + 1, x * code)] or nil
		end
	end
	known = {w = icon.w, h = icon.h, cells = cells}
	decoded[icon] = known
	return known
end

local floor = math.floor
local function blend(dst, r, g, b, a)
	if a >= 255 then return (r * 256 + g) * 256 + b end
	local t = a / 255
	local dr, dg, db = floor(dst / 65536), floor(dst / 256) % 256, dst % 256
	return (floor(dr + (r - dr) * t + 0.5) * 256 + floor(dg + (g - dg) * t + 0.5)) * 256 +
		floor(db + (b - db) * t + 0.5)
end

-- Draws `icon` (an art entry) centred on pixel cx/cy at `scale`; returns its
-- box {x0, y0, x1, y1} (exclusive ends, unclipped).
function B.draw_icon(pixels, width, height, icon, cx, cy, scale)
	local image = B.decode(icon)
	local x0 = cx - floor(image.w * scale / 2)
	local y0 = cy - floor(image.h * scale / 2)
	for y = 0, image.h - 1 do
		for x = 0, image.w - 1 do
			local cell = image.cells[y * image.w + x + 1]
			if cell then
				for j = y0 + y * scale, y0 + y * scale + scale - 1 do
					if j >= 0 and j < height then
						local row = j * width + 1
						for i = x0 + x * scale, x0 + x * scale + scale - 1 do
							if i >= 0 and i < width then
								pixels[row + i] = blend(pixels[row + i], cell[1], cell[2], cell[3], cell[4])
							end
						end
					end
				end
			end
		end
	end
	return {x0, y0, x0 + image.w * scale, y0 + image.h * scale}
end

-- Draws a region label row centred on pixel cx/cy at `scale`, its box
-- clamped into the image (a name wider than the image is cut); returns the
-- box.
function B.draw_label(pixels, width, height, font, row, cx, cy, scale)
	local layout = B.layout(font, row[1], row.wrap)
	local cells = B.mask(font, layout)
	local w, h = layout.width * scale, layout.height * scale
	local x0 = math.max(0, math.min(width - w, cx - floor(w / 2)))
	local y0 = math.max(0, math.min(height - h, cy - floor(h / 2)))
	local text = (B.TEXT[1] * 256 + B.TEXT[2]) * 256 + B.TEXT[3]
	local halo = (B.HALO[1] * 256 + B.HALO[2]) * 256 + B.HALO[3]
	for y = 0, layout.height - 1 do
		for x = 0, layout.width - 1 do
			local cell = cells[y * layout.width + x]
			if cell then
				local colour = cell == 2 and text or halo
				for j = math.max(0, y0 + y * scale), math.min(height, y0 + y * scale + scale) - 1 do
					local first = j * width + 1
					for i = math.max(0, x0 + x * scale), math.min(width, x0 + x * scale + scale) - 1 do
						pixels[first + i] = colour
					end
				end
			end
		end
	end
	return {x0, y0, x0 + w, y0 + h}
end

local function overlap(a, b)
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

-- Draws `layer` ({items, labels}) into a `width` x `height` image of the
-- world rectangle `view` with `art` (baked_art.lua): every item's icon of
-- kind .. `suffix` at `scale`, then the names when `names`. A world point
-- lands on the pixel the base's roads use (base.lua's canvas). Returns
-- {icons, names, icon_overlaps, name_overlaps}: the drawn counts and the
-- pairs of icons that overlap each other or a name, for the log.
function B.draw(pixels, width, height, view, layer, art, scale, names, suffix)
	local sx = width / (view.max_x - view.min_x)
	local sz = height / (view.max_z - view.min_z)
	local boxes, stats = {}, {icons = 0, names = 0, icon_overlaps = 0, name_overlaps = 0}
	for _, item in ipairs(layer.items) do
		local icon = art.icons[item.kind .. suffix]
		if icon then
			local box = B.draw_icon(pixels, width, height, icon,
				floor((item.x - view.min_x) * sx), floor((view.max_z - item.z) * sz), scale)
			for _, other in ipairs(boxes) do
				if overlap(box, other) then stats.icon_overlaps = stats.icon_overlaps + 1 end
			end
			boxes[#boxes + 1] = box
			stats.icons = stats.icons + 1
		end
	end
	if names then
		for _, row in ipairs(layer.labels) do
			local box = B.draw_label(pixels, width, height, art.font, row,
				floor((row[2] - view.min_x) * sx), floor((view.max_z - row[3]) * sz), scale)
			for _, other in ipairs(boxes) do
				if overlap(box, other) then stats.name_overlaps = stats.name_overlaps + 1 end
			end
			stats.names = stats.names + 1
		end
	end
	return stats
end

return B

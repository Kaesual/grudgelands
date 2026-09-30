-- The minimap's geometry (Round 27, WP50; glide variant): which part of the
-- base image a player's client holds, where it is drawn so the map glides
-- under a fixed centred arrow, and where markers go. PURE Lua: it calls
-- nothing from `core`, so the portable fixture loads the real file.
--
-- Rulings: north up (6), a window of about 900 nodes (7), markers are
-- separate HUD elements, party members outside the window become rim
-- arrows (8), and the client builds a new map texture only when the player
-- enters a new grid cell (9).
--
-- Glide: the texture of a cell is a disc of T base pixels, larger than the
-- visible hole of C (the 900-node window) by the most the player can be off
-- the cell centre (half a cell diagonally, d). Moving it so the player's
-- own pixel lies at the centre keeps the hole covered; an opaque bezel of
-- outer radius R (base pixels) covers the overhang, since HUD images are
-- never clipped. The scale f (screen pixels per base pixel) is a whole
-- multiple of 1/grid, so neighbouring cells' textures sit a whole number of
-- screen pixels apart: swapping the texture on a cell change moves no pixel.

local V = {}

V.WINDOW_NODES = 900
-- The bezel art (textures/grug_map_minimap_bezel.png): hole radius over
-- outer radius. The hole shows the C-pixel window, so R = C / 2 / BEZEL_HOLE.
V.BEZEL_HOLE = 0.77
V.RIM_FRAMES = 16
-- The snap grid in base pixels per map quality (ruling 9): 12 px (80
-- nodes) at normal, 32 px (64 nodes) at high. A new texture is built every
-- cell; the bezel is as wide as the texture's overhang, about 1.4 cells.
V.GRID = {normal = 12, high = 32}

-- `base` is what base.lua's install returned (quality, width, height,
-- tiles); `bounds` the atlas world bounds.
function V.new(base, bounds)
	local npp = (bounds.max_x - bounds.min_x) / base.width
	local crop = math.floor(V.WINDOW_NODES / npp + 0.5)
	local grid = V.GRID[base.quality] or V.GRID.normal
	-- The disc must cover the hole with the player half a cell off-centre
	-- diagonally: T >= C + 2 d; T is a whole number of cells.
	local d = math.sqrt(2) * grid / 2
	local texture = math.ceil((crop + 2 * d) / grid) * grid
	return {npp = npp, crop = crop, grid = grid, tiles = base.tiles,
		texture = texture, d = d, outer = crop / 2 / V.BEZEL_HOLE,
		min_x = bounds.min_x, max_z = bounds.max_z,
		width = base.width, height = base.height}
end

-- Base pixel coordinates (fractional) of world x/z.
function V.base_pixel(v, x, z)
	return (x - v.min_x) / v.npp, (v.max_z - z) / v.npp
end

-- The grid cell holding world x/z.
function V.cell(v, x, z)
	local px, py = V.base_pixel(v, x, z)
	return math.floor(px / v.grid), math.floor(py / v.grid)
end

-- The texture's top-left base pixel for a cell: centred on the cell centre.
function V.origin(v, cx, cy)
	local shift = (v.grid - v.texture) / 2
	return cx * v.grid + shift, cy * v.grid + shift
end

-- The cell's texture: the tiles it overlaps (at most four, a tile is at
-- least as large as the texture) combined, cut to a disc by `mask`. Parts
-- outside the base stay transparent.
function V.texture(v, ox, oy, mask)
	local parts = {("[combine:%dx%d"):format(v.texture, v.texture)}
	for _, tile in ipairs(v.tiles) do
		if tile.x < ox + v.texture and tile.x + tile.w > ox and
				tile.y < oy + v.texture and tile.y + tile.h > oy then
			parts[#parts + 1] = ("%d,%d=%s"):format(tile.x - ox, tile.y - oy, tile.name)
		end
	end
	return table.concat(parts, ":") .. "^[mask:" .. mask
end

-- The drawing frame for a minimap `box` (grug_core.hud_layout.minimap_box):
-- the largest scale f = k / grid (k whole) whose bezel fits the box, the
-- bezel's diameter and centre (its top-right corner at the box's), the
-- texture's drawn size and the hole radius, all in real screen pixels.
function V.frame(v, box)
	local k = math.max(1, math.floor(box.size / (2 * v.outer) * v.grid))
	local f = k / v.grid
	local diameter = math.floor(2 * v.outer * f + 0.5)
	local right, top = box.center_x + box.size / 2, box.center_y - box.size / 2
	return {f = f, k = k, diameter = diameter, drawn = v.texture * k / v.grid,
		center_x = right - diameter / 2, center_y = top + diameter / 2,
		hole = v.crop / 2 * f, hud = box.hud, width = box.width, height = box.height}
end

-- The texture's top-left screen pixel with the player at base pixel px/py:
-- the player's pixel lands on the centre. Rounded once, so the cell term
-- (a whole number of pixels) never changes the rounding.
function V.map_corner(v, frame, ox, oy, px, py)
	return math.floor(frame.center_x - (px - ox) * frame.f + 0.5),
		math.floor(frame.center_y - (py - oy) * frame.f + 0.5)
end

-- Screen position (real pixels, fractional) of world x/z with the texture
-- at mx/my, and its distance from the centre.
function V.place(v, frame, ox, oy, mx, my, x, z)
	local px, py = V.base_pixel(v, x, z)
	local sx, sy = mx + (px - ox) * frame.f, my + (py - oy) * frame.f
	local dx, dy = sx - frame.center_x, sy - frame.center_y
	return sx, sy, math.sqrt(dx * dx + dy * dy)
end

-- A rim arrow for a point at dx/dy (screen, y down) from the centre: on the
-- middle of the bezel, with the frame of its 16 directions (frame 0 points
-- up, frames turn clockwise).
function V.rim(frame, dx, dy)
	local angle = math.atan2(dx, -dy)
	local r = (frame.hole + frame.diameter / 2) / 2
	local index = math.floor(angle / (2 * math.pi) * V.RIM_FRAMES + 0.5) % V.RIM_FRAMES
	return frame.center_x + r * math.sin(angle), frame.center_y - r * math.cos(angle), index
end

return V

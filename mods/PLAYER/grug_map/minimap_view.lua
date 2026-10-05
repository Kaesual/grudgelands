-- The minimap's geometry (Round 27, WP50; glide variant): which part of the
-- base image a player's client holds, where it is drawn so the map glides
-- under a fixed centred arrow, and where markers go. PURE Lua: it calls
-- nothing from `core`, so the portable fixture loads the real file.
--
-- Rulings: north up (6), a window of about 440 nodes (7, zoomed in twice
-- since Round 32), markers are
-- separate HUD elements, party members outside the window become rim
-- arrows (8), and the client builds a new map texture only when the player
-- enters a new grid cell (9).
--
-- Glide: the texture of a cell is a disc of T base pixels, larger than the
-- visible hole of C (the window) by the most the player can be off the cell
-- centre (half a cell diagonally, d) plus a margin of COVER texels. Moving
-- it so the player's own pixel lies at the centre keeps the hole covered; an opaque bezel of
-- outer radius R (base pixels) covers the overhang, since HUD images are
-- never clipped. The scale f (screen pixels per base pixel) is a whole
-- multiple of 1/grid, so neighbouring cells' textures sit a whole number of
-- screen pixels apart: swapping the texture on a cell change moves no pixel.

local V = {}

-- Twice the zoom of Round 27's 880 (Round 32 §2.1): quest givers and
-- trainers sit twice as far apart on the minimap, so players can tell them
-- apart. The base image is the same; at normal each base pixel is drawn
-- twice as large (66 px across the hole at normal, 220 at high).
V.WINDOW_NODES = 440
-- The bezel art (textures/grug_map_minimap_bezel.png): hole radius over
-- outer radius. The hole shows the C-pixel window, so R = C / 2 / BEZEL_HOLE.
-- The art is fully opaque only out to BEZEL_OPAQUE of its radius (its outer
-- edge is anti-aliased; tools/r27_minimap/render_icons.py checks it), so
-- the map disc must stay inside that.
V.BEZEL_HOLE = 0.83
V.BEZEL_OPAQUE = 0.975
V.RIM_FRAMES = 16
-- The snap grid in base pixels per map quality (ruling 9): 2 px (13 nodes)
-- at normal, 8 px (16 nodes) at high. A new texture is built every cell;
-- the bezel must cover the texture's overhang, about 1.4 cells, so a finer
-- grid is a slimmer bezel (about 22 px at 1080p) for more textures. Round
-- 32's zoom draws a base pixel twice as large, so the grid shrank with it:
-- at high to half (the same screen geometry as before); at normal 3 px
-- would overhang the bezel's opaque band by about a pixel, so 2 px. Its
-- price: the scale steps by half a screen pixel per base pixel, so the
-- bezel fills 0.79-0.99 of the native box by window (0.89 at 1080p), where
-- Round 27's normal filled 0.88-0.98.
V.GRID = {normal = 2, high = 8}
-- High quality's cell texture is halved on the client (`[resize`) for a
-- quarter of the client memory. The trade-off: since Round 32's zoom the
-- HUD draws a base pixel about a screen pixel wide at 1080p (f 1.0; 0.625
-- at 720p, 2.0 at 4K), so the half-size texture is drawn larger than it is
-- and high shows less detail than it could, though still more than normal
-- (f 3.0 at 1080p, 6.7 nodes per base pixel). The texture is combined one pixel
-- short (one base pixel less), because `[resize` (CImage::copyToScaling) then
-- steps exactly 2.0 from its first pixel: texel u is base pixel 2u, a cell
-- is a whole number of texels, and a swap moves no pixel.
V.REDUCE = {normal = 1, high = 2}
-- Extra texels of texture beyond the hole at the worst offset: the mask's
-- soft edge, nearest sampling and the half pixel of rounding need them.
V.COVER = 1.5

-- `base` is the `minimap` base of base.lua's install (quality, width,
-- height, tiles): normal size on every server since Round 37 (user ruling
-- 2026-10-06), so the game uses the normal rows above; the high rows still
-- describe a high-size base for the geometry fixture. `bounds` the atlas
-- world bounds.
function V.new(base, bounds)
	local npp = (bounds.max_x - bounds.min_x) / base.width
	local crop = math.floor(V.WINDOW_NODES / npp + 0.5)
	local grid = V.GRID[base.quality] or V.GRID.normal
	-- The disc must cover the hole with the player half a cell off-centre
	-- diagonally: T >= C + 2 d; T is a whole number of cells.
	local d = math.sqrt(2) * grid / 2
	local reduce = V.REDUCE[base.quality] or 1
	local texture = math.ceil((crop + 2 * (d + V.COVER * reduce)) / grid) * grid
	-- `texture` is in base pixels, `combined` the base pixels combined
	-- before any resize, `pixels` the texture's own size.
	return {npp = npp, crop = crop, grid = grid, tiles = base.tiles,
		texture = texture, pixels = texture / reduce, reduce = reduce,
		combined = reduce > 1 and texture - 1 or texture,
		d = d, outer = crop / 2 / V.BEZEL_HOLE,
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
-- least as large as the texture) combined, halved at high quality, cut to a
-- disc by `mask` (made at the texture's own size). Parts outside the base
-- stay transparent.
function V.texture(v, ox, oy, mask)
	local size = v.combined
	local parts = {("[combine:%dx%d"):format(size, size)}
	for _, tile in ipairs(v.tiles) do
		if tile.x < ox + size and tile.x + tile.w > ox and
				tile.y < oy + size and tile.y + tile.h > oy then
			parts[#parts + 1] = ("%d,%d=%s"):format(tile.x - ox, tile.y - oy, tile.name)
		end
	end
	local resize = v.reduce > 1 and ("^[resize:%dx%d"):format(v.pixels, v.pixels) or ""
	return table.concat(parts, ":") .. resize .. "^[mask:" .. mask
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
		-- the arrow's pixel: the centre rounded; the map is placed on it
		arrow_x = math.floor(right - diameter / 2 + 0.5),
		arrow_y = math.floor(top + diameter / 2 + 0.5),
		hole = v.crop / 2 * f, hud = box.hud, width = box.width, height = box.height}
end

-- The top-left screen pixel of cell cx/cy's texture with the player at base
-- pixel px/py: the player's pixel lands on the arrow's pixel. The cell's whole k
-- pixels are added after the rounding, so every cell rounds the same value
-- and neighbours stay exactly k pixels apart whatever the floating point
-- does.
function V.map_corner(v, frame, cx, cy, px, py)
	local shift = (v.grid - v.texture) / 2
	return math.floor(frame.arrow_x - px * frame.f + shift * frame.f + 0.5) + cx * frame.k,
		math.floor(frame.arrow_y - py * frame.f + shift * frame.f + 0.5) + cy * frame.k
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

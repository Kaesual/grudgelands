-- The minimap's geometry (Round 27, WP50): which part of the base image a
-- player sees, the texture that shows it, and where markers go on screen.
-- PURE Lua: it calls nothing from `core`, so the portable fixture loads the
-- real file.
--
-- Rulings: north up (6), one window of about 900 nodes (7), markers are
-- separate HUD elements and party members outside the window become rim
-- arrows (8), the window snaps to a coarse grid so the client builds a new
-- texture only when the player enters a new grid cell (9).

local V = {}

V.WINDOW_NODES = 900
-- Ring art (textures/grug_map_minimap_ring.png, 256 px): markers stay inside
-- RING_INNER of the radius, the dark band covers the rest. The mask is inset
-- by MASK_INSET of the radius so its edge lies under the band.
V.RING_INNER = 1 - 2 * 8 / 256
V.MASK_INSET = 3 / 256
V.RIM_FRAMES = 16

-- `base` is what base.lua's install returned (width, height, minimap_grid,
-- tiles); `bounds` the atlas world bounds. The window is `crop` base pixels
-- square: 135 at normal quality, 450 at high.
function V.new(base, bounds)
	local npp = (bounds.max_x - bounds.min_x) / base.width
	local crop = math.floor(V.WINDOW_NODES / npp + 0.5)
	return {npp = npp, crop = crop, grid = base.minimap_grid, tiles = base.tiles,
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

-- The window's top-left base pixel for a cell: the window is centred on the
-- cell's centre, so the player stays within half a cell of the middle.
function V.origin(v, cx, cy)
	local shift = math.floor((v.grid - v.crop) / 2)
	return cx * v.grid + shift, cy * v.grid + shift
end

-- The window's texture: the tiles it overlaps (at most four, since a tile
-- is at least as large as the window) combined into a crop x crop square,
-- then cut round by `mask`. Parts outside the base stay transparent.
function V.texture(v, ox, oy, mask)
	local parts = {("[combine:%dx%d"):format(v.crop, v.crop)}
	for _, tile in ipairs(v.tiles) do
		if tile.x < ox + v.crop and tile.x + tile.w > ox and
				tile.y < oy + v.crop and tile.y + tile.h > oy then
			parts[#parts + 1] = ("%d,%d=%s"):format(tile.x - ox, tile.y - oy, tile.name)
		end
	end
	return table.concat(parts, ":") .. "^[mask:" .. mask
end

-- Screen position (real pixels) of world x/z on the minimap `box`
-- (grug_core.hud_layout.minimap_box) showing the window at ox/oy, and its
-- distance from the minimap's centre.
function V.place(v, box, ox, oy, x, z)
	local px, py = V.base_pixel(v, x, z)
	local f = box.size / v.crop
	local dx = (px - ox - v.crop / 2) * f
	local dy = (py - oy - v.crop / 2) * f
	return box.center_x + dx, box.center_y + dy, math.sqrt(dx * dx + dy * dy)
end

-- The radius (real pixels) inside which a marker of half-size `half` is
-- drawn whole.
function V.inner_radius(box, half)
	return box.size / 2 * V.RING_INNER - (half or 0)
end

-- A rim arrow for a point at dx/dy (screen, y down) from the centre: its
-- position on the rim and the frame of its 16 directions (frame 0 points up,
-- frames turn clockwise).
function V.rim(box, dx, dy, half)
	local angle = math.atan2(dx, -dy)
	local r = V.inner_radius(box, half)
	local frame = math.floor(angle / (2 * math.pi) * V.RIM_FRAMES + 0.5) % V.RIM_FRAMES
	return box.center_x + r * math.sin(angle), box.center_y - r * math.cos(angle), frame
end

return V

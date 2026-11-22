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
-- twice as large (66 px across the hole at normal, 196 at high).
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
-- at normal, 8 px (18 nodes) at high. A new texture is built every cell;
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
--
-- `claim` (fix 0.50.2; nil: none) is the claim layer: optional tiles
-- (`claim.tiles`) after the map's, which `[combine` blends by their alpha,
-- and one `[fill` per rectangle of `claim.rects` (V.claim_rect,
-- V.claim_frame, V.chunk_cells: inside the combined texture, never empty)
-- in its own `color` or else `claim.color`, in list order, before any
-- resize and the mask. Since Round 86 the claim mode's chunk fills, its
-- grid and the frames are all rectangles (minimap.lua claim_layer).
-- `flight` (fix 0.53.1; nil: none) are the no-fly overlay's tiles (base.lua
-- flight_overlay), added after the map's and before the claim layer.
function V.texture(v, ox, oy, mask, claim, flight)
	local size = v.combined
	local parts = {("[combine:%dx%d"):format(size, size)}
	local function add(tiles)
		for _, tile in ipairs(tiles) do
			if tile.x < ox + size and tile.x + tile.w > ox and
					tile.y < oy + size and tile.y + tile.h > oy then
				parts[#parts + 1] = ("%d,%d=%s"):format(tile.x - ox, tile.y - oy, tile.name)
			end
		end
	end
	add(v.tiles)
	if flight then add(flight) end
	local fills = ""
	if claim then
		if claim.tiles then add(claim.tiles) end
		local list = {}
		for index, rect in ipairs(claim.rects) do
			list[index] = ("^[fill:%dx%d:%d,%d:%s"):format(rect.w, rect.h, rect.x, rect.y,
				rect.color or claim.color)
		end
		fills = table.concat(list)
	end
	local resize = v.reduce > 1 and ("^[resize:%dx%d"):format(v.pixels, v.pixels) or ""
	return table.concat(parts, ":") .. fills .. resize .. "^[mask:" .. mask
end

-- The claims' geometry on the cell texture (fix 0.50.2; docs/design/
-- world_map.md "Minimap"). A claim covers the columns cx - radius .. cx +
-- radius (and the same in z), each node its column +- 0.5.
--
-- Every rectangle is in pixels of the combined texture of the cell whose
-- top-left base pixel is ox/oy, clipped to the texture, and left out when
-- nothing of it lies on the texture. The engine refuses a `[fill` whose x
-- or y lies outside the image or whose width or height is 0, and leaves the
-- part out with an error line per build (imagesource.cpp `[fill`,
-- CHECK_DIM), so no other rectangle may reach a recipe.
-- The claim's box rounded outward, in pixels of that texture and not yet
-- clipped: left, top, right, bottom (right and bottom exclusive).
local function claim_box(v, ox, oy, cx, cz, radius)
	local left, top = V.base_pixel(v, cx - radius - 0.5, cz + radius + 0.5)
	local right, bottom = V.base_pixel(v, cx + radius + 0.5, cz - radius - 0.5)
	return math.floor(left) - ox, math.floor(top) - oy, math.ceil(right) - ox,
		math.ceil(bottom) - oy
end

-- The pixels x0 .. x1 - 1, y0 .. y1 - 1 clipped to a `size` square texture:
-- {x, y, w, h}, or nil when nothing is left.
local function clip(size, x0, y0, x1, y1)
	x0, y0 = math.max(0, x0), math.max(0, y0)
	x1, y1 = math.min(size, x1), math.min(size, y1)
	if x1 <= x0 or y1 <= y0 then return nil end
	return {x = x0, y = y0, w = x1 - x0, h = y1 - y0}
end

-- The claim's outward-rounded box clipped (the rectangle claim_frame
-- borders): {x, y, w, h}, or nil.
function V.claim_rect(v, ox, oy, cx, cz, radius)
	return clip(v.combined, claim_box(v, ox, oy, cx, cz, radius))
end

-- A frame one pixel wide just inside the unclipped box x0 .. x1 - 1, y0 ..
-- y1 - 1 of a `size` texture, appended to `list` in `color` as rectangles
-- {x, y, w, h, color}, each clipped (top and bottom the box's whole width,
-- left and right between them, so no pixel is drawn twice); an edge with
-- nothing on the texture is left out. Returns `list`.
local function frame_edges(size, x0, y0, x1, y1, color, list)
	local edges = {clip(size, x0, y0, x1, y0 + 1), clip(size, x0, y1 - 1, x1, y1),
		clip(size, x0, y0 + 1, x0 + 1, y1 - 1), clip(size, x1 - 1, y0 + 1, x1, y1 - 1)}
	for index = 1, 4 do
		local rect = edges[index]
		if rect then
			rect.color = color
			list[#list + 1] = rect
		end
	end
	return list
end

-- The claims outside claim mode (fix 0.50.2 ruling H4): a frame one base
-- pixel wide just inside the claim's outward-rounded box, no fill.
function V.claim_frame(v, ox, oy, cx, cz, radius, color, list)
	local x0, y0, x1, y1 = claim_box(v, ox, oy, cx, cz, radius)
	return frame_edges(v.combined, x0, y0, x1, y1, color, list)
end

-- The world rectangle (inclusive columns) the combined texture of the cell
-- at ox/oy shows, one column more on each side: the claims to ask for.
function V.texture_area(v, ox, oy)
	local size = v.combined
	return math.floor(v.min_x + ox * v.npp) - 1, math.floor(v.max_z - (oy + size) * v.npp) - 1,
		math.ceil(v.min_x + (ox + size) * v.npp) + 1, math.ceil(v.max_z - oy * v.npp) + 1
end

-- The claim preview's chunk grid (Round 86 lane PREVIEW;
-- docs/design/world_map.md "Minimap", claim mode): the map chunks (`chunk`
-- nodes a side, chunk 0 starting at node `origin`) that meet the combined
-- texture of the cell at ox/oy, as pixel ranges of that texture. A chunk
-- edge (a node edge, half a node outside its first or last column) is
-- rounded to the nearest pixel, one formula for both chunks beside it, so
-- the grid tiles the texture without gap or overlap. Returns `cols`
-- {{c, x0, x1, a, b}, ...} west to east and `rows` {{c, y0, y1, a, b}, ...}
-- north to south: c the chunk index, x0 .. x1 - 1 (y0 .. y1 - 1) its pixels
-- clipped to the texture (a chunk with none is left out), a .. b - 1 the
-- same unclipped (a: its west or north edge, on the texture when a >= 0).
function V.chunk_cells(v, ox, oy, chunk, origin)
	local size, floor = v.combined, math.floor
	local min_x, min_z, max_x, max_z = V.texture_area(v, ox, oy)
	local function west(c) return floor((origin + chunk * c - 0.5 - v.min_x) / v.npp + 0.5) - ox end
	local function north(c)
		return floor((v.max_z - (origin + chunk * (c + 1) - 0.5)) / v.npp + 0.5) - oy
	end
	local function add(list, c, a, b)
		local x0, x1 = math.max(0, a), math.min(size, b)
		if x1 > x0 then list[#list + 1] = {c, x0, x1, a, b} end
	end
	local cols, rows = {}, {}
	for c = floor((min_x - origin) / chunk), floor((max_x - origin) / chunk) do
		add(cols, c, west(c), west(c + 1))
	end
	for c = floor((max_z - origin) / chunk), floor((min_z - origin) / chunk), -1 do
		add(rows, c, north(c), north(c - 1))
	end
	return cols, rows
end

-- A frame one pixel wide just inside the chunk of cell `col` x `row`
-- (V.chunk_cells), clipped as claim_frame's.
function V.cell_frame(v, col, row, color, list)
	return frame_edges(v.combined, col[4], row[4], col[5], row[5], color, list)
end

-- The drawing frame for a minimap `box` (grug_core.hud_layout.minimap_box):
-- the largest scale f = k / grid (k whole) whose bezel fits the box, the
-- bezel's diameter and centre (its top-right corner at the box's), the
-- texture's drawn size and the hole radius, all in real screen pixels;
-- `hud` and `gui` are the box's HUD and GUI scaling.
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
		hole = v.crop / 2 * f, hud = box.hud, gui = box.gui or 1, width = box.width,
		height = box.height}
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

-- The "Now playing" box (0.45.1): while a capital's music plays, a small
-- box under the location line (in the top-right corner while the minimap
-- is hidden or unavailable, Round 48) with a music-note icon on the left and two
-- left-aligned lines right of it, the title and the artist (the name alone:
-- "by" made the line longer and said nothing the second line does not).
-- Its text is HUD text in the location line's default font, sized by GUI
-- scaling; the icon is scaled with it, as high as the two lines (36 GUI px,
-- the 24 px art at 1.5 times), so both are in GUI units here. HUD
-- text cannot be measured, so the width comes from the longer line's
-- characters at `char_em` of the font size each: the font (Arimo Regular,
-- 16 px at GUI scaling 1) measures 0.40-0.59 em per character over the
-- shipped titles and artists ("Town Theme" the widest per character,
-- "Fantasy Orchestral Theme" the longest at 11.8 em), so 0.6 em holds every
-- one. One font line is `line_em` high.
V.NOW_PLAYING = {gap = 4, pad = 4, icon = 36, icon_gap = 6, line = 20,
	font = 16, char_em = 0.6, line_em = 1.15}

-- The box's height at GUI scaling `gui` (two lines and the padding; the
-- width depends on the text).
function V.now_playing_height(gui)
	local P = V.NOW_PLAYING
	return 2 * math.floor(P.pad * gui + 0.5) + math.ceil(2 * P.line * gui)
end

-- The box for `title` and `artist` at GUI scaling `gui`, placed by `place`
-- (width -> top-left x/y).
local function playing_box(gui, title, artist, place)
	local P = V.NOW_PLAYING
	local chars = math.max(#title, #artist)
	local text_w = math.ceil(chars * P.char_em * P.font * gui)
	local pad, icon = math.floor(P.pad * gui + 0.5), math.floor(P.icon * gui + 0.5)
	local icon_gap = math.floor(P.icon_gap * gui + 0.5)
	local w = pad + icon + icon_gap + text_w + pad
	local h = V.now_playing_height(gui)
	local x, y = place(w)
	local text_h = 2 * P.line_em * P.font * gui
	return {x = x, y = y, w = w, h = h,
		icon_x = x + pad, icon_y = y + math.floor((h - icon) / 2 + 0.5), icon = icon,
		text_x = x + pad + icon + icon_gap, text_y = y + math.floor((h - text_h) / 2 + 0.5)}
end

-- The box for `title` and `artist` with the location line's top at
-- `line_top` (real screen pixels): the box's top-left x/y, width and height,
-- the icon's top-left and size, and the text's top-left. The box sits `gap`
-- HUD px below the location line's slot (`line` GUI px), centred under the
-- bezel; a box wider than the bezel ends at the bezel's right edge (the
-- window's right margin) and grows to the left.
function V.now_playing_box(frame, line_top, title, artist)
	local P, gui = V.NOW_PLAYING, frame.gui
	local right = frame.center_x + frame.diameter / 2
	return playing_box(gui, title, artist, function(w)
		return math.floor(math.min(frame.center_x - w / 2, right - w) + 0.5),
			math.floor(line_top + P.line * gui + P.gap * frame.hud + 0.5)
	end)
end

-- The same box in the top-right corner while the minimap is hidden or
-- unavailable (Round 48 ruling 2.1): its right edge on `right`, its top at
-- `top` (side_layout's playing_right and playing_top); it grows to the left.
function V.now_playing_corner(box, right, top, title, artist)
	return playing_box(box.gui or 1, title, artist, function(w)
		return math.floor(right - w + 0.5), top
	end)
end

-- Claim mode's line and its box (Round 86 lane PREVIEW, fix round 1): the
-- line left of the bezel stands on the "Now playing" box's dark fill, so it
-- reads against a bright sky. HUD text cannot be measured, so its width is
-- estimated from the glyph advances of the HUD font (Arimo has Arial's
-- metrics: thousandths of the em, an unknown character as a digit); on the
-- shipped hints the estimate lies 1-3 % above the drawn text (measured in
-- Round 86's screenshots, tools/r86_preview pins them). Text is sized by GUI
-- scaling: `font` GUI px a line's em, `line_em` ems a line, `pad` GUI px
-- around the text.
V.HINT = {font = 16, line_em = 1.15, pad = 4}
local ADVANCE = {[" "] = 278, ["'"] = 191, [":"] = 278, ["."] = 278, [","] = 278,
	["-"] = 333, ["+"] = 584, ["("] = 333, [")"] = 333}
do
	local lower = {556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556,
		556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500}
	local upper = {667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722,
		778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611}
	for i = 1, 26 do
		ADVANCE[string.char(96 + i)] = lower[i]
		ADVANCE[string.char(64 + i)] = upper[i]
	end
end

-- The widest line of `text` in px at a font of `font` px, and its lines.
function V.text_width(text, font)
	local widest, lines = 0, 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local sum = 0
		for i = 1, #line do sum = sum + (ADVANCE[line:sub(i, i)] or 556) end
		widest, lines = math.max(widest, sum), lines + 1
	end
	return widest * font / 1000, lines
end

-- The box for claim mode's line `text`: its right edge `gap` HUD px left of
-- the bezel, its bottom on the bezel's bottom. {x, y, w, h} (the box's
-- top-left, size) and text_x, text_y (the right-aligned text's right edge
-- and bottom), in real screen pixels.
function V.hint_box(frame, text, gap)
	local H, gui = V.HINT, frame.gui
	local pad = math.floor(H.pad * gui + 0.5)
	local width, lines = V.text_width(text, H.font * gui)
	local w = math.ceil(width) + 2 * pad
	local h = math.ceil(lines * H.line_em * H.font * gui) + 2 * pad
	local right = math.floor(frame.center_x - frame.diameter / 2 - gap * frame.hud + 0.5)
	local bottom = math.floor(frame.center_y + frame.diameter / 2 + 0.5)
	return {x = right - w, y = bottom - h, w = w, h = h, text_x = right - pad,
		text_y = bottom - pad}
end

-- The minimap's side elements (Round 48 lane HUD; docs/design/world_map.md
-- "Minimap"): the mail icon and the daytime band. Both are finished images
-- (tools/r48_hud/gen_hud_textures.py): the band BAND_W x BAND_H texture px,
-- one 20-minute cycle with the "now" marker in the middle; the mail icon
-- MAIL_W x MAIL_H, the envelope with the count beside it. Their drawn sizes
-- follow the minimap's box (25 % of the window height), as the bezel does:
-- the band `band` of the box wide (Round 48 HUD2: 75 % of lane HUD's 0.45;
-- 92 x 23 px at 1080p, 60 x 15 at 720p), the mail icon exactly as high as
-- the band (the user's ruling of 2026-10-14; 72 x 23 at 1080p, room for
-- "9+" beside the envelope). The announcements icon (Round 84 default 15)
-- ANNOUNCE_W x ANNOUNCE_H, the announcement badge with the count beside
-- it, is drawn at the mail icon's scale (one pixel higher: the badge's art
-- is 29 px): under the mail icon while letters are unread, in its place
-- otherwise (side_stack). `row_gap` HUD px separate the band from the mail
-- icon, `gap` the mail icon from the bezel, the two icons from each other
-- and the stack from "Now playing".
V.SIDE = {band_w = 160, band_h = 40, mail_w = 87, mail_h = 28, announce_w = 87,
	announce_h = 29, band = 0.3375, gap = 4, row_gap = 8}

-- The height the client draws a `tw` x `th` texture at that minimap.lua's
-- exact() scales to `w` px wide: the client truncates th x scale x HUD
-- factor (hud.cpp), and exact() adds a quarter pixel to the width.
local function drawn_height(w, tw, th)
	return math.floor(th * (w + 0.25) / tw)
end

-- The narrowest width at which that texture is drawn `h` px high: the
-- fifth of a pixel keeps the height off the truncation edge.
local function width_for(h, tw, th)
	return math.ceil(h * tw / th - 0.2)
end

-- Where the side elements go in the minimap `box`
-- (grug_core.hud_layout.minimap_box): one row, band left, mail icon right,
-- both the same height and vertically centred on the row (Round 48 HUD2,
-- the user's variant A). With the minimap shown (`frame`, the bezel's
-- V.frame) the row stands left of the bezel, its top on the bezel's top.
-- With the minimap hidden or unavailable (frame nil) it stands right-aligned
-- in the box's top-right corner, and "Now playing" goes below it
-- (playing_right, playing_top; Round 48 ruling 2.1). The mail icon's place
-- in the row stays reserved while it is hidden, so the band never moves.
-- The announcements icon has two places (Round 84; side_stack picks one):
-- `announce_top` in the row where the mail icon stands, top-aligned with
-- it, and `announce` under the mail icon, left-aligned with it. Returns
-- {mail = {x, y, w, h}, announce = {...}, announce_top = {...}, band =
-- {...}} in real screen pixels (w and h as the client draws them), plus,
-- when hidden, playing_right and the tops of "Now playing" below one row
-- (playing_top) and below both icons (playing_top_two).
function V.side_layout(box, frame)
	local S = V.SIDE
	-- the band's height from its share of the box at the image's aspect,
	-- then both widths that the client draws at exactly that height
	local bh = math.floor(box.size * S.band * S.band_h / S.band_w + 0.5)
	local bw = width_for(bh, S.band_w, S.band_h)
	local mw = width_for(bh, S.mail_w, S.mail_h)
	bh = drawn_height(bw, S.band_w, S.band_h)
	local mh = drawn_height(mw, S.mail_w, S.mail_h)
	local row = math.max(bh, mh)
	local right, top
	if frame then
		right = frame.center_x - frame.diameter / 2 - S.gap * box.hud
		top = frame.center_y - frame.diameter / 2
	else
		right = box.center_x + box.size / 2
		top = box.center_y - box.size / 2
	end
	top = math.floor(top + 0.5)
	local mail = {w = mw, h = mh, x = math.floor(right - mw + 0.5),
		y = top + math.floor((row - mh) / 2)}
	local band = {w = bw, h = bh, x = math.floor(mail.x - S.row_gap * box.hud - bw + 0.5),
		y = top + math.floor((row - bh) / 2)}
	local ah = drawn_height(mw, S.announce_w, S.announce_h)
	local announce = {w = mw, h = ah, x = mail.x, y = math.floor(top + row + S.gap * box.hud + 0.5)}
	local out = {mail = mail, announce = announce, band = band,
		announce_top = {w = mw, h = ah, x = mail.x, y = top}}
	if not frame then
		out.playing_right = right
		out.playing_top = math.floor(top + math.max(row, ah) + S.gap * box.hud + 0.5)
		out.playing_top_two = math.floor(announce.y + ah + S.gap * box.hud + 0.5)
	end
	return out
end

-- The announcements icon's place for the unread counts in side layout `L`
-- (Round 84, the user's correction of 2026-11-21): under the mail icon
-- while letters are unread too, else in the mail icon's place, so no empty
-- slot stands above it. With the minimap hidden also the top of "Now
-- playing", below the icons that show (nil with the minimap shown).
function V.side_stack(L, letters, announcements)
	local both = (letters or 0) > 0 and (announcements or 0) > 0
	return both and L.announce or L.announce_top, both and L.playing_top_two or L.playing_top
end

-- The daytime band's position (sell plan §3.6.2): 0 .. positions - 1 over
-- one world day, one per 30 real seconds. The world clock runs at two
-- speeds (grug_core.DAY_TIME_SPEED in the day phase, NIGHT_TIME_SPEED at
-- night), so `timeofday` is not linear in real time: the day phase
-- [day_start, day_end) maps linearly onto the first `day` positions (900
-- real seconds), the night onto the rest (300). 04:30 is 0, 19:30 is 30.
V.DAYTIME = {positions = 40, day = 30}
function V.daytime_position(timeofday, day_start, day_end)
	local D = V.DAYTIME
	local at
	if timeofday >= day_start and timeofday < day_end then
		at = (timeofday - day_start) / (day_end - day_start) * D.day
	else
		local night = (timeofday - day_end) % 1 / (1 - (day_end - day_start))
		at = D.day + night * (D.positions - D.day)
	end
	-- the small margin keeps a whole position from flooring to the one
	-- before through rounding
	local position = math.floor(at + 1e-6)
	if position < 0 then return 0 end
	if position >= D.positions then return D.positions - 1 end
	return position
end

function V.daytime_texture(position)
	return ("grug_map_daytime_%02d.png"):format(position)
end

-- The mail icon for `count` unread letters (mail plan ruling 14): none for
-- 0, the digit 1-9, "9+" above.
function V.mail_texture(count)
	count = math.floor(tonumber(count) or 0)
	if count <= 0 then return "" end
	if count <= 9 then return ("grug_map_mail_%d.png"):format(count) end
	return "grug_map_mail_9p.png"
end

-- The announcements icon for `count` unread announcements (Round 84
-- default 15), as the mail icon.
function V.announce_texture(count)
	count = math.floor(tonumber(count) or 0)
	if count <= 0 then return "" end
	if count <= 9 then return ("grug_map_announce_%d.png"):format(count) end
	return "grug_map_announce_9p.png"
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

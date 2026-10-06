-- Round 40 lane V4: the cooldown overlay's arithmetic (round40-plan.md §2.1,
-- §3.1). PURE Lua, so the portable fixture loads this very file.
--
-- The hotbar's slot rectangles are the engine's integer arithmetic
-- (reference_projects/luanti/src/client/hud.cpp):
--   readScalingSetting (138-145): size = s32(floor(48 * density + 0.5)),
--     then size = s32(size * hud_scaling) (truncated); padding = size / 12
--     (integer division); m_scale_factor = hud_scaling * density.
--   drawHotbar (793-821): n = min(main list size, hotbar item count); one
--     row while n * (size + 2 * padding) / window width <= hud_hotbar_max_width,
--     else the first n/2 items in an upper row lifted by size + padding and
--     the rest below.
--   drawItems (235-296): the row's top left is the element position plus
--     s32(offset * scale_factor) (builtin hotbar: position {0.5, 1}, offset
--     {0, -4}, alignment {0, -1}: builtin/game/hud.lua:270-277), then
--     x += -(width / 2) as a float truncated back to s32, y -= height; slot k
--     of the row sits at (padding + k * (size + 2 * padding), padding).
--   An image element (496-506) is drawn at the element position plus
--     s32(offset * scale_factor) with s32(image px * scale * scale_factor)
--     pixels; a text element (386-436) uses the font size (times size.x),
--     never hud_scaling, and is centred on its offset point with
--     alignment {0, 0}.
-- HUD positions round with floor(p * screen + 0.5).

local hudmath = {}

local floor, ceil = math.floor, math.ceil

hudmath.FRAMES = 72   -- 5 degree steps (§2.1)
hudmath.ICON = 48     -- HOTBAR_IMAGE_SIZE (src/hud_element.h:45)
hudmath.MAX_WIDTH = 1.0 -- hud_hotbar_max_width default (src/defaultsettings.cpp:303)

local function trunc(x)
	if x < 0 then return ceil(x) end
	return floor(x)
end
hudmath.trunc = trunc

-- §2.1: the remaining time without decimals or unit; above 60 s the minutes
-- rounded up ("5m" from 5:00 down to 4:01, "2m" at 1:01), then "60" ... "1".
-- "" once nothing remains.
function hudmath.cooldown_text(remaining)
	local s = ceil(remaining)
	if s <= 0 then return "" end
	if s > 60 then return ceil(s / 60) .. "m" end
	return tostring(s)
end

-- The pie frame for the elapsed share: 0 (fully covered) .. FRAMES - 1. The
-- frame count is fixed by the angle step, never by the cooldown's length.
function hudmath.frame_index(elapsed, duration)
	if duration <= 0 then return hudmath.FRAMES - 1 end
	local k = floor(elapsed / duration * hudmath.FRAMES)
	if k < 0 then return 0 end
	if k > hudmath.FRAMES - 1 then return hudmath.FRAMES - 1 end
	return k
end

-- The engine's slot rectangles in window pixels.
--   p = {width, height (window px), density, hud_scaling, count (items),
--        max_width (hud_hotbar_max_width)}
-- Returns {size, pad, pitch, rows, scale_factor, anchor = {x, y},
--          slots = {[1..count] = {x, y}}} (top left of each item rectangle).
function hudmath.engine_slots(p)
	local density, hs = p.density, p.hud_scaling
	local size = trunc(floor(hudmath.ICON * density + 0.5) * hs)
	local pad = trunc(size / 12)
	local pitch = size + 2 * pad
	local n = p.count
	local sf = hs * density
	local anchor = {x = floor(0.5 * p.width + 0.5), y = floor(p.height + 0.5)}
	local base_y = anchor.y + trunc(-4 * sf)
	local slots = {}
	local function row(first, last, lift)
		local w = (last - first + 1) * pitch
		local x = trunc(anchor.x - w * 0.5)
		local y = base_y - lift - pitch
		for i = first, last do
			slots[i + 1] = {x = x + pad + (i - first) * pitch, y = y + pad}
		end
	end
	local rows = 1
	if n * pitch / p.width <= (p.max_width or hudmath.MAX_WIDTH) then
		row(0, n - 1, 0)
	else
		rows = 2
		local upper = floor(n / 2)
		row(0, upper - 1, size + pad)
		row(upper, n - 1, 0)
	end
	return {size = size, pad = pad, pitch = pitch, rows = rows,
		scale_factor = sf, anchor = anchor, slots = slots}
end

-- A HUD offset (in HUD units) that the engine's s32(offset * scale_factor)
-- turns into exactly `px` pixels: half a pixel away from zero survives the
-- truncation toward zero and any float error.
local function offset_for(px, sf)
	if px > 0 then return (px + 0.5) / sf end
	if px < 0 then return (px - 0.5) / sf end
	return 0
end
hudmath.offset_for = offset_for

-- HUD placement per slot for an element at position {0.5, 1}:
--   cover: alignment {1, 1} (top left), offset and scale for an image of
--          `img` px so that it covers exactly the slot's item rectangle;
--   centre: the slot centre as an offset (for alignment {0, 0} elements);
--   px: the slot size in window pixels (for digit images).
-- mode "exact" uses the window information (pixel exact at any scaling,
-- two rows when the engine splits); mode "plain" knows nothing about the
-- window and assumes density 1 and one row: offsets in HUD units that the
-- engine scales (exact only where the integer rounding agrees).
function hudmath.layout(mode, p, img)
	local out = {}
	if mode == "plain" then
		local n = p.count
		for i = 1, n do
			local x = -n * 28 + 4 + (i - 1) * 56
			out[i] = {
				cover = {x = x, y = -56}, scale = hudmath.ICON / img,
				centre = {x = x + 24, y = -32}, px = hudmath.ICON, sf = 1,
			}
		end
		return out, {rows = 1, size = hudmath.ICON, scale_factor = 1}
	end
	local g = hudmath.engine_slots(p)
	local sf = g.scale_factor
	for i, s in ipairs(g.slots) do
		local dx, dy = s.x - g.anchor.x, s.y - g.anchor.y
		-- The centre for alignment {0, 0}: the engine centres on the offset
		-- point, so an odd size sits half a pixel left/up (it truncates).
		local cx, cy = dx + floor(g.size / 2), dy + floor(g.size / 2)
		out[i] = {
			cover = {x = offset_for(dx, sf), y = offset_for(dy, sf)},
			scale = (g.size + 0.5) / (img * sf),
			centre = {x = offset_for(cx, sf), y = offset_for(cy, sf)},
			px = g.size, sf = sf,
		}
	end
	return out, g
end

-- The image-digit texture for a number: one [combine of the glyph files.
-- glyphs: {[char] = {file, w}}, h: glyph height, gap: px between glyphs.
function hudmath.digit_texture(text, glyphs, h, gap)
	local parts, x = {}, 0
	for i = 1, #text do
		local glyph = glyphs[text:sub(i, i)]
		if glyph then
			parts[#parts + 1] = ("%d,0=%s"):format(x, glyph.file)
			x = x + glyph.w + gap
		end
	end
	if #parts == 0 then return "blank.png", 0 end
	local w = x - gap
	return ("[combine:%dx%d:%s"):format(w, h, table.concat(parts, ":")), w
end

return hudmath

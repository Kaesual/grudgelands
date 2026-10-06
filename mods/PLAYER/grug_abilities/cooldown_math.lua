-- The cooldown overlay's arithmetic (classes.md "The cooldown overlay"; Round
-- 40 plan §2.1, §2.13, §3.1). PURE Lua: it calls nothing from `core`, so the
-- portable fixture (tools/r40_cd/portable_test.lua) loads this very file.
--
-- The hotbar's slot rectangles are the engine's integer arithmetic
-- (reference_projects/luanti/src/client/hud.cpp, verified exact by the Round
-- 40 V4 probe):
--   readScalingSetting (138-145): size = s32(floor(48 * density + 0.5)),
--     then size = s32(size * hud_scaling) (truncated); padding = size / 12
--     (integer division); m_scale_factor = hud_scaling * density.
--   drawHotbar (806-821): n = min(main list size, hotbar item count); one
--     row while n * (size + 2 * padding) / window width <= hud_hotbar_max_width
--     (a client setting, default 1.0, src/defaultsettings.cpp:303), else the
--     first n/2 items in an upper row lifted by size + padding and the rest
--     below.
--   drawItems (235-296): the row's top left is the element position plus
--     s32(offset * scale_factor) (builtin hotbar: position {0.5, 1}, offset
--     {0, -4}, alignment {0, -1}: builtin/game/hud.lua:270-277), then
--     x += -(width / 2) truncated back to s32, y -= height; slot k of the row
--     sits at (padding + k * (size + 2 * padding), padding).
--   An image element (496-506) is drawn at the element position plus
--     s32(offset * scale_factor), s32(image px * scale * scale_factor) big,
--     shifted by (alignment - 1) * size / 2.
-- HUD positions round with floor(p * screen + 0.5).
--
-- The server knows the window size, real_hud_scaling (hud_scaling x
-- density) and real_gui_scaling (gui_scaling x density)
-- (src/clientdynamicinfo.cpp:14-28), not the density alone: the density is
-- taken as real_gui_scaling, i.e. gui_scaling is assumed to be 1. It only
-- matters where 48 x density is not a whole number.

local M = {}

local floor, ceil = math.floor, math.ceil

M.FRAMES = 72        -- 5 degree steps (§2.1); the frame count never depends on the duration
M.ICON = 48          -- HOTBAR_IMAGE_SIZE (src/hud_element.h)
M.MAX_WIDTH = 1.0    -- hud_hotbar_max_width's default
M.PIE_PX = 96        -- the generated cover frames are PIE_PX square
-- The image digits (pick N3; tools/r40_cd/gen_cooldown_textures.py): a glyph
-- image is GLYPH_W x GLYPH_H cells of GLYPH_CELL px (outline included);
-- glyphs stand GLYPH_ADVANCE cells apart (their outlines overlap).
M.GLYPH_CELL = 4
M.GLYPH_W, M.GLYPH_H = 7, 9
M.GLYPH_ADVANCE = 6
-- One glyph cell is DIGIT_SHARE of the slot size on screen, rounded to whole
-- pixels (at least one): 2 px at the 48 px slot, so a digit is 14 px tall
-- plus its outline, as on the accepted preview page. Raise it for bigger
-- numbers.
M.DIGIT_SHARE = 1 / 24

M.PIE = "grug_abilities_cd_pie_%02d.png"
M.DIGIT = "grug_abilities_cd_digit_%s.png"

local function trunc(x)
	if x < 0 then return ceil(x) end
	return floor(x)
end
M.trunc = trunc

-- §2.1: the remaining time without decimals or unit; above 60 s the minutes
-- rounded up ("5m" from 5:00 down to 4:01, "2m" at 1:01), then "60" ... "1".
-- "" once nothing remains.
function M.text(remaining)
	local s = ceil(remaining)
	if s <= 0 then return "" end
	if s > 60 then return ceil(s / 60) .. "m" end
	return tostring(s)
end

-- The cover frame for the elapsed share: 0 (fully covered) .. FRAMES - 1.
function M.frame(elapsed, duration)
	if duration <= 0 then return M.FRAMES - 1 end
	local k = floor(elapsed / duration * M.FRAMES)
	if k < 0 then return 0 end
	if k > M.FRAMES - 1 then return M.FRAMES - 1 end
	return k
end

function M.pie_texture(frame)
	return M.PIE:format(frame)
end

-- The number as one image: a [combine of the glyph files, GLYPH_ADVANCE
-- cells apart. The client builds each distinct string once and caches it,
-- and there are at most 64 of them ("1" .. "60", "2m" .. "5m").
function M.digit_texture(text)
	local parts, step = {}, M.GLYPH_ADVANCE * M.GLYPH_CELL
	for i = 1, #text do
		parts[#parts + 1] = ("%d,0=%s"):format((i - 1) * step,
			M.DIGIT:format(text:sub(i, i)))
	end
	if #parts == 0 then return "" end
	local w = ((#text - 1) * M.GLYPH_ADVANCE + M.GLYPH_W) * M.GLYPH_CELL
	return ("[combine:%dx%d:%s"):format(w, M.GLYPH_H * M.GLYPH_CELL,
		table.concat(parts, ":"))
end

-- The engine's slot rectangles in window pixels.
--   p = {width, height (window px), density, hud_scaling, count (items),
--        max_width (hud_hotbar_max_width)}
-- Returns {size, pad, pitch, rows, anchor = {x, y},
--          slots = {[1..count] = {x, y}}} (top left of each item rectangle).
function M.engine_slots(p)
	local size = trunc(floor(M.ICON * p.density + 0.5) * p.hud_scaling + 1e-6)
	local pad = trunc(size / 12)
	local pitch = size + 2 * pad
	local n = p.count
	local sf = p.hud_scaling * p.density
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
	if n * pitch / p.width <= (p.max_width or M.MAX_WIDTH) then
		row(0, n - 1, 0)
	else
		rows = 2
		local upper = floor(n / 2)
		row(0, upper - 1, size + pad)
		row(upper, n - 1, 0)
	end
	return {size = size, pad = pad, pitch = pitch, rows = rows,
		anchor = anchor, slots = slots}
end

-- A HUD offset that the engine's s32(offset * scale_factor) turns into
-- exactly `px` pixels: half a pixel away from zero survives the truncation
-- toward zero and any float error.
local function offset_for(px, sf)
	if px > 0 then return (px + 0.5) / sf end
	if px < 0 then return (px - 0.5) / sf end
	return 0
end
M.offset_for = offset_for

-- One slot's placement for elements at position {0.5, 1}: the cover
-- (alignment {1, 1}, top left on the slot's item rectangle, a PIE_PX image
-- scaled to exactly `size` px) and the number (alignment {0, 0}, centred on
-- the slot, a glyph cell scaled to a whole number of pixels).
local function place(dx, dy, size, sf)
	local cell = math.max(1, floor(size * M.DIGIT_SHARE + 0.5))
	-- The engine centres on the offset point; an odd size sits half a pixel
	-- left/up (it truncates).
	local half = floor(size / 2)
	return {
		cover = {x = offset_for(dx, sf), y = offset_for(dy, sf)},
		cover_scale = (size + 0.5) / (M.PIE_PX * sf),
		centre = {x = offset_for(dx + half, sf), y = offset_for(dy + half, sf)},
		-- A glyph image is GLYPH_H cells tall: GLYPH_H * cell px plus half a
		-- pixel, which also keeps the widest number (13 cells) exact.
		digit_scale = (M.GLYPH_H * cell + 0.5) / (M.GLYPH_H * M.GLYPH_CELL * sf),
		size = size, cell = cell,
	}
end

-- The layout of `count` hotbar slots for a player's window information
-- (`info`, nil when the client sends none): {key, rows, slots = {[i] = place}}.
-- `key` changes whenever an input does, so a caller re-places its elements
-- only then. Without window information the slots are fixed HUD units for
-- density 1 and one row, which the engine scales (exact where its integer
-- rounding agrees: hud_scaling 1, 1.5, 2 ...).
function M.layout(info, count)
	local size_x = info and info.size and info.size.x
	local hud = info and tonumber(info.real_hud_scaling)
	local gui = info and tonumber(info.real_gui_scaling)
	if not (size_x and hud and gui and hud > 0 and gui > 0) then
		local out = {key = "plain " .. count, rows = 1, slots = {}}
		for i = 1, count do
			local x = -count * 28 + 4 + (i - 1) * 56
			out.slots[i] = place(x, -56, M.ICON, 1)
		end
		return out
	end
	local key = ("%d %d %.4f %.4f %d"):format(size_x, info.size.y, hud, gui, count)
	local density = gui
	local g = M.engine_slots({width = size_x, height = info.size.y,
		density = density, hud_scaling = hud / density, count = count})
	local out = {key = key, rows = g.rows, slots = {}}
	for i, s in ipairs(g.slots) do
		out.slots[i] = place(s.x - g.anchor.x, s.y - g.anchor.y, g.size, hud)
	end
	return out
end

return M

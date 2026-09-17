-- The bottom-centre HUD column, in ONE place (docs/research/hud-bars.md).
--
-- Before this file the column was four negative pixel offsets (-70, -85,
-- -110, -135) spread over three mods, and inserting anything at the bottom
-- meant editing all of them. grug_core is below every consumer in the
-- dependency graph, so the stack lives here and grug_abilities, grug_xp and
-- grug_money read it instead of carrying a constant each.
--
-- Everything is measured UPWARDS from the top edge of the builtin hotbar, in
-- the pixel units `hud_add`'s `offset` uses. Those units are multiplied by
-- `m_scale_factor` (`hud_scaling` x display density) at draw time, exactly
-- like an `image` element's positive `scale` -- so offsets and bar widths
-- stay in step at any HUD scaling (src/client/hud.cpp:496-506).
--
-- This file is PURE Lua: it calls nothing from `core`, so
-- tools/ui/hud_bars_kat.lua loads the real thing rather than a copy.

local layout = {}
grug_core.hud_layout = layout

-- The builtin hotbar is drawn at position {x = 0.5, y = 1} with
-- alignment.y = -1 and offset.y = -4 (builtin/game/hud.lua:270-277). One row
-- is `m_hotbar_imagesize + 2 * m_padding` = 48 + 8 = 56 px tall and its
-- background box adds m_padding/2 (src/client/hud.cpp:239, 268-269), so the
-- first thing above the slots starts at -62.
local HOTBAR_TOP = -62

layout.POSITION = {x = 0.5, y = 1}

-- A bar is one 1x1 strip stretched to these pixel dimensions. The width is
-- also the foreground's maximum `scale.x`, because the source strip is one
-- pixel wide: scale.x IS the drawn width in pixels.
layout.BAR_WIDTH = 180
layout.BAR_HEIGHT = 16
layout.BAR_TEXTURE = "grug_core_hud_bar.png"

-- The smallest and largest fill a partial bar may draw. Below 1 px the
-- engine's `int` truncation would erase a living player's last hit points
-- entirely; 2 px keeps that true down to hud_scaling 0.5. The same margin at
-- the top stops 324/325 from reading as untouched.
layout.MIN_FILL = 2

-- The whole bar palette. Mana and rage are the colours classes.md section 1
-- already decided; life, breath and the empty track are this lane's choice
-- and are a look question for the playtest, not a user ruling.
layout.COLOR = {
	track = 0x141414,
	life = 0x4caf50,
	mana = 0x4a9bd8,
	rage = 0xc41e3a,
	breath = 0x8fd9f2,
	text = 0xffffff,
}

-- The column, bottom first. `gap` is the empty space BELOW the row.
--
-- `breath` is reserved even though its bar is only drawn under water, and
-- `secondary` is reserved even for a character that has no class yet: a row
-- that appears or disappears must not move the rows above it.
local STACK = {
	{id = "secondary", kind = "bar", height = 16, gap = 2},
	{id = "life", kind = "bar", height = 16, gap = 4},
	{id = "breath", kind = "bar", height = 16, gap = 4},
	{id = "skill", kind = "text", height = 20, gap = 2},
	{id = "money", kind = "text", height = 20, gap = 2},
	{id = "xp", kind = "text", height = 20, gap = 2},
}

-- id -> {kind, index, top, bottom, height, middle}. y grows DOWNWARDS, so
-- `top` is the more negative number and `bottom = top + height`.
layout.rows = {}
layout.order = {}

do
	local edge = HOTBAR_TOP
	for i = 1, #STACK do
		local row = STACK[i]
		local top = edge - row.gap - row.height
		layout.rows[row.id] = {
			id = row.id,
			kind = row.kind,
			index = i,
			height = row.height,
			top = top,
			bottom = top + row.height,
			middle = top + row.height / 2,
		}
		layout.order[i] = row.id
		edge = top
	end
end

-- Elements that are not part of the column. They are here for the same
-- reason the rows are: so that "where does the error flash sit?" has one
-- answer.
layout.anchors = {
	flash = {position = {x = 0.5, y = 0.35}, offset = {x = 0, y = 0}},
	reticle = {position = {x = 0.5, y = 0.5}, offset = {x = 0, y = 0}},
	status_list = {
		position = {x = 1, y = 0},
		offset = {x = -20, y = 20},
		alignment = {x = -1, y = 1},
	},
}

local function place(id)
	local row = layout.rows[id]
	if row then
		return layout.POSITION, {x = 0, y = row.middle}
	end
	local anchor = layout.anchors[id]
	if anchor then
		return anchor.position, anchor.offset
	end
	return nil
end

local function copy_into(out, def)
	if def then
		for key, value in pairs(def) do
			out[key] = value
		end
	end
	return out
end

-- A centred text element on a column row or on a free anchor. `def` carries
-- the caller's own fields (`number`, `text`, `z_index`, ...).
function layout.text_element(id, def)
	local position, offset = place(id)
	if not position then
		return nil
	end
	local out = copy_into({}, def)
	out.type = "text"
	out.position = {x = position.x, y = position.y}
	out.offset = {x = offset.x, y = offset.y}
	out.alignment = {x = 0, y = 0}
	return out
end

-- A centred image element on a free anchor (the weapon-ready reticle).
function layout.image_element(id, def)
	local position, offset = place(id)
	if not position then
		return nil
	end
	local out = copy_into({}, def)
	out.type = "image"
	out.position = {x = position.x, y = position.y}
	out.offset = {x = offset.x, y = offset.y}
	out.alignment = {x = 0, y = 0}
	out.scale = out.scale or {x = 1, y = 1}
	return out
end

-- One layer of a bar. `alignment.x = 1` puts the LEFT edge of the image on
-- the anchor (src/client/hud.cpp:502-503: offset.X = (align.X - 1) *
-- width / 2), so a shrinking foreground drains to the right instead of
-- collapsing towards its own centre; `alignment.y = 1` does the same
-- vertically, which is why `top` and not `middle` is the anchor here.
--
-- `width` is in the same pixels as BAR_WIDTH and becomes `scale.x` unchanged
-- (the strip is 1 px wide). A `width` of 0 draws nothing.
function layout.bar_element(id, width, color, z_index)
	local row = layout.rows[id]
	if not row or row.kind ~= "bar" then
		return nil
	end
	return {
		type = "image",
		position = {x = layout.POSITION.x, y = layout.POSITION.y},
		offset = {x = -layout.BAR_WIDTH / 2, y = row.top},
		alignment = {x = 1, y = 1},
		scale = {x = width, y = row.height},
		text = layout.bar_texture(color),
		z_index = z_index or 0,
	}
end

-- The tint. One shared white strip plus `[colorize`, the way the ability
-- icons are tinted (classes.md section 2c). No colour is the empty texture
-- name, which the engine skips without drawing anything
-- (src/client/hud.cpp:489-491) -- that is how a row is reserved but blank.
function layout.bar_texture(color)
	if not color then
		return ""
	end
	return ("%s^[colorize:#%06x:255"):format(layout.BAR_TEXTURE, color)
end

-- value/maximum -> the foreground's drawn width in whole pixels.
--
-- Whole pixels because `hud_change` sends a packet on EVERY call, changed or
-- not (src/script/lua_api/l_object.cpp:2026 "FIXME: only send when actually
-- changed"): quantizing to what the screen can actually show is what lets
-- the caller skip the write when nothing moved.
--
-- The two guards are the point of the whole element. A 325 HP Warrior
-- (combat_stats.md section 2) at 324 HP must not read as untouched, and at
-- 1 HP must not read as dead; the exact number is in the centred label, and
-- the bar never contradicts it.
function layout.bar_fill(value, maximum)
	local width = layout.BAR_WIDTH
	if type(value) ~= "number" or type(maximum) ~= "number" then
		return 0
	end
	if maximum <= 0 or value <= 0 then
		return 0
	end
	if value >= maximum then
		return width
	end
	local px = math.floor(value / maximum * width + 0.5)
	if px < layout.MIN_FILL then
		px = layout.MIN_FILL
	elseif px > width - layout.MIN_FILL then
		px = width - layout.MIN_FILL
	end
	return px
end

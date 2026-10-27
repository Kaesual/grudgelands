-- The bottom-centre HUD column, in ONE place (docs/research/hud-bars.md).
--
-- Before this file the column was four negative pixel offsets (-70, -85,
-- -110, -135) spread over three mods, and inserting anything at the bottom
-- meant editing all of them. grug_core is below every consumer in the
-- dependency graph, so grug_abilities and grug_xp share this layout. Money
-- is displayed on Character instead of occupying a HUD row.
--
-- Everything is measured UPWARDS from the top edge of the builtin hotbar, in
-- the pixel units `hud_add`'s `offset` uses. Those units are multiplied by
-- `m_scale_factor` (`hud_scaling` x display density) at draw time, exactly
-- like an `image` element's positive `scale` -- so offsets and bar widths
-- stay in step at any HUD scaling (src/client/hud.cpp:496-506).
--
-- This file is PURE Lua: it calls nothing from `core`, so an
-- offline check can load the real thing rather than a copy.

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
layout.XP_WIDTH = 360
layout.PARTY_ROW_GAP = 6
layout.PARTY_BAR_HEIGHT = 6
layout.PARTY_TEXT_HEIGHT = 20
-- The class icon left of each party row (Round 26 ruling 22): as tall as the
-- name line plus its bar (layout.party_icon_size), then a gap before the text.
layout.PARTY_ICON_GAP = 6
-- The status icon row (Round 26 ruling 17). Icons are 64 px art drawn at
-- STATUS_ICON px (user choice after the first screenshot: 40, not 32);
-- slots are STATUS_PITCH apart so a four-character caption ("4:59") under
-- each icon stays clear of its neighbour. Ten slots span 480 px.
layout.STATUS_ICON = 40
layout.STATUS_PITCH = 48
layout.STATUS_LIMIT = 10
-- The combat icon right of the health bar keeps 32 px: it sits beside a 16 px
-- bar, right of every bar of the column, so it never overlaps one.
layout.COMBAT_ICON = 32
-- The caption line under an icon (GUI units: 16 px font plus a margin) and
-- the widest caption ("4:59", about nine GUI units per character).
layout.STATUS_CAPTION = 18
layout.STATUS_CAPTION_WIDTH = 40
-- HUD units between the top of the status icon row and the feed's lowest
-- line (the anchor below uses it, so it is set first).
layout.FEED_GAP = 6
-- Widest quest-tracker line in characters (the box's title row and its
-- objective line; layout.quest_boxes).
layout.QUEST_WRAP = 38
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
	xp = 0xffd100,
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
	{id = "xp", kind = "bar", width = 360, height = 6, gap = 8},
	{id = "secondary", kind = "bar", height = 16, gap = 8},
	{id = "life", kind = "bar", height = 16, gap = 4},
	{id = "breath", kind = "bar", height = 16, gap = 4},
	{id = "skill", kind = "text", height = 20, gap = 2},
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
			width = row.width or layout.BAR_WIDTH,
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
	combat = {position = {x = 0.5, y = 1},
		offset = {x = layout.BAR_WIDTH / 2 + 12, y = layout.rows.life.middle}},
	flash = {position = {x = 0.5, y = 0.35}, offset = {x = 0, y = 0}},
	reticle = {position = {x = 0.5, y = 0.5}, offset = {x = 0, y = 0}},
	-- The paused-character-creation hint (Round 24 ruling 32): below the
	-- screen centre, clear of the flash line above it and the reticle.
	creation_hint = {position = {x = 0.5, y = 0.65}, offset = {x = 0, y = 0}},
	-- The status icon row: centred above the column, with its caption line
	-- between the icons and the skill row, so the player's own state sits
	-- next to their own bars and the top centre belongs to the target frame
	-- alone. `offset.y` is the icon CENTRE of the row.
	status_row = {
		position = {x = 0.5, y = 1},
		offset = {x = 0, y = layout.rows.skill.top - 4 - layout.STATUS_CAPTION -
			2 - layout.STATUS_ICON / 2},
	},
	-- The quest tracker (Round 65 ruling 4): one box per tracked quest (at
	-- most grug_quests.MAX_TRACKED = 10) at the right edge, the stack
	-- centred on the window's middle where it fits. Its boxes, their heights
	-- and how many fit between the minimap block above and the bottom-centre
	-- column below are layout.quest_boxes (after minimap_box, which it
	-- reads); the offsets it returns are from this anchor.
	quest_list = {
		position = {x = 1, y = 0.5},
		offset = {x = -20, y = 0},
	},
	party_list = {
		position = {x = 0, y = 0.5},
		offset = {x = 20, y = 0},
		alignment = {x = 1, y = 1},
	},
	-- The message feed (Round 28 ruling 20, feed.lua): its lines stack upwards
	-- from FEED_GAP above the TOP of the status icon row, which itself sits
	-- right above the skill-name row. The row is reserved even when no status
	-- runs, so the feed never jumps; `offset.y` is the bottom edge of the
	-- lowest (newest) line. layout.feed_line_offset places each line.
	feed = {
		position = {x = 0.5, y = 1},
		offset = {x = 0, y = layout.rows.skill.top - 4 - layout.STATUS_CAPTION -
			2 - layout.STATUS_ICON - layout.FEED_GAP},
	},
	-- The level-up announcement (ruling 20): large, above the flash line.
	banner = {position = {x = 0.5, y = 0.25}, offset = {x = 0, y = 0}},
}

-- Feed geometry: at most FEED_LINES lines of FEED_LINE GUI units each (the
-- default 16 px font plus a small gap).
layout.FEED_LINES = 3
layout.FEED_LINE = 20

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
		offset = {x = -row.width / 2, y = row.top},
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
function layout.bar_fill(value, maximum, width)
	width = width or layout.BAR_WIDTH
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

-- HUD images/offsets use HUD scaling; fonts independently use GUI scaling.
-- Convert a conservative 20-GUI-unit label slot to HUD units before positioning
-- the life bar. This includes default 16px-font ascenders/descenders and a gap.
local function scales(window)
	window = window or {}
	return math.max(0.1, tonumber(window.real_hud_scaling) or 1),
		math.max(0.1, tonumber(window.real_gui_scaling) or 1)
end

-- Side blocks use their actual content height, not a fixed ten-row box.
-- The name and bar start right of the class icon column.
function layout.party_row_offset(index, count, bar, window)
	local anchor = layout.anchors.party_list
	local hud, gui = scales(window)
	local bar_y = math.ceil(layout.PARTY_TEXT_HEIGHT * gui / hud)
	local row_height = bar_y + layout.PARTY_BAR_HEIGHT + layout.PARTY_ROW_GAP
	local height = (count - 1) * row_height + bar_y + layout.PARTY_BAR_HEIGHT
	return {x = anchor.offset.x + layout.party_icon_size(window) +
		layout.PARTY_ICON_GAP,
		y = anchor.offset.y - height / 2 +
		(index - 1) * row_height + (bar and bar_y or 0)}
end

-- The class icon of party row `index`: top-left aligned with the row's name
-- line, at the anchor's own x.
function layout.party_icon_offset(index, count, window)
	local row = layout.party_row_offset(index, count, false, window)
	return {x = layout.anchors.party_list.offset.x, y = row.y}
end

-- The class icon's drawn size: it spans the name line and the bar, so it
-- grows with the label slot when GUI scaling exceeds HUD scaling.
function layout.party_icon_size(window)
	local hud, gui = scales(window)
	return math.ceil(layout.PARTY_TEXT_HEIGHT * gui / hud) +
		layout.PARTY_BAR_HEIGHT
end

-- Slot `index` of `count` shown statuses, centred on the row anchor:
-- the icon's centre and the top of its caption, both as HUD offsets.
-- Captions are text, sized by GUI scaling: their line height and width are
-- converted to HUD units (as for the party rows), so a larger GUI scale
-- lifts the row instead of pushing captions into the skill row, and widens
-- the pitch instead of letting neighbouring captions touch.
function layout.status_slot(index, count, window)
	local anchor = layout.anchors.status_row
	local hud, gui = scales(window)
	local caption_h = math.ceil(layout.STATUS_CAPTION * gui / hud)
	local pitch = math.max(layout.STATUS_PITCH,
		math.ceil(layout.STATUS_CAPTION_WIDTH * gui / hud) + 4)
	local x = anchor.offset.x + (index - (count + 1) / 2) * pitch
	local y = anchor.offset.y - (caption_h - layout.STATUS_CAPTION)
	return {x = x, y = y}, {x = x, y = y + layout.STATUS_ICON / 2 + 2}
end

-- The centre of feed line `slot` (1 = the lowest, newest line) as a HUD
-- offset. Text is sized by GUI scaling, so the line pitch is converted to HUD
-- units, and the whole feed rises by the same amount status_slot lifts the
-- icon row, so a larger GUI scale never pushes a line into the icons.
function layout.feed_line_offset(slot, window)
	local hud, gui = scales(window)
	local lift = math.ceil(layout.STATUS_CAPTION * gui / hud) -
		layout.STATUS_CAPTION
	local line = math.ceil(layout.FEED_LINE * gui / hud)
	return {x = layout.anchors.feed.offset.x,
		y = layout.anchors.feed.offset.y - lift - line / 2 - (slot - 1) * line}
end

-- The zone entry banner (Round 28 M1, grug_map location.lua): the name of a
-- zone, start town or capital city the player enters, top centre, at
-- ZONE_BANNER_SIZE times the default font (HUD text sizes are fractional:
-- the client multiplies the font size by size.x). The top centre already
-- holds the target frame's one line (grug_mobs target_frame.lua: position
-- {0.5, 0}, offset y TARGET_FRAME_Y, centred); the banner sits
-- ZONE_BANNER_GAP HUD px below that line, clear of the level-up banner at
-- 0.25 H and the flash line at 0.35 H.
layout.TARGET_FRAME_Y = 40
layout.ZONE_BANNER_SIZE = 2.5
layout.ZONE_BANNER_GAP = 8

-- The banner's centre as a HUD offset from the top centre. Its line and the
-- target frame's are text, sized by GUI scaling, so both heights are
-- converted to HUD units (as for the feed lines).
function layout.zone_banner_offset(window)
	local hud, gui = scales(window)
	local target = math.ceil(layout.FEED_LINE * gui / hud)
	local banner = math.ceil(layout.FEED_LINE * layout.ZONE_BANNER_SIZE * gui / hud)
	return {x = 0, y = layout.TARGET_FRAME_Y + target / 2 + layout.ZONE_BANNER_GAP +
		banner / 2}
end

layout.anchors.zone_banner = {position = {x = 0.5, y = 0},
	offset = layout.zone_banner_offset(nil)}

-- The banner's second line (Round 31's PvP subtitle, since Round 32 the
-- territory line, grug_map location.lua: "Contested Territory (PvP)"): one
-- default line, ZONE_SUBTITLE_GAP below the zone banner's bottom.
layout.ZONE_SUBTITLE_GAP = 4

function layout.zone_subtitle_offset(window)
	local hud, gui = scales(window)
	local banner = layout.zone_banner_offset(window)
	local banner_h = math.ceil(layout.FEED_LINE * layout.ZONE_BANNER_SIZE * gui / hud)
	local line = math.ceil(layout.FEED_LINE * gui / hud)
	return {x = 0, y = banner.y + banner_h / 2 + layout.ZONE_SUBTITLE_GAP + line / 2}
end

layout.anchors.zone_subtitle = {position = {x = 0.5, y = 0},
	offset = layout.zone_subtitle_offset(nil)}

-- The mount's flight-boundary warning (grug_mounts entity.lua): one default
-- line, ZONE_SUBTITLE_GAP below the subtitle's line, so all three can show at
-- once. At scale 1 it spans about 136-156 HUD px from the top; the level-up
-- banner (size 2, centred at 0.25 H) starts about 20 GUI px above 0.25 H, so
-- the two clear while H >= 4 x (156 hud + 20 gui): 704 px at scale 1.
function layout.flight_warning_offset(window)
	local hud, gui = scales(window)
	local subtitle = layout.zone_subtitle_offset(window)
	local line = math.ceil(layout.FEED_LINE * gui / hud)
	return {x = 0, y = subtitle.y + line + layout.ZONE_SUBTITLE_GAP}
end

layout.anchors.flight_warning = {position = {x = 0.5, y = 0},
	offset = layout.flight_warning_offset(nil)}

-- The minimap's box (grug_map, Round 27 ruling 6), in real screen pixels:
-- the builtin minimap's square of MINIMAP_PERCENT of the window height, its
-- top-right corner MINIMAP_EDGE HUD px from the top and right edges. The
-- quest tracker (layout.quest_boxes) stays below exactly this box. `window` is
-- the player's window information; nil gives a 1280 x 720 window at HUD
-- scaling 1. Returns {size, center_x, center_y, hud, gui, width, height}
-- (`gui` sizes the text under the minimap: its location line and, since
-- 0.45.1, the "Now playing" box).
layout.MINIMAP_PERCENT = 25
layout.MINIMAP_EDGE = 10

function layout.minimap_box(window)
	local hud, gui = scales(window)
	local size = window and window.size or {x = 1280, y = 720}
	local width = math.max(1, tonumber(size.x) or 1280)
	local height = math.max(1, tonumber(size.y) or 720)
	local side = math.floor(height * layout.MINIMAP_PERCENT / 100)
	local edge = layout.MINIMAP_EDGE * hud
	return {size = side, center_x = width - edge - side / 2,
		center_y = edge + side / 2, hud = hud, gui = gui, width = width, height = height}
end

function layout.xp_label(text)
	local out = layout.text_element("xp", {number = layout.COLOR.xp, text = text})
	out.offset.x = layout.XP_WIDTH / 2 + 8
	out.alignment.x = 1
	return out
end

-- Reserve the combat column even in a narrow window. Window information is
-- supplied by consumers; the layout remains independent of engine callbacks.
-- Nine GUI units per character estimate the default font; reserve the combat
-- column and edge padding in HUD units, then divide the remaining pixel space
-- by GUI-scaled character width.
function layout.side_text_width(window)
	if not window or not window.size then return layout.QUEST_WRAP end
	local hud, gui = scales(window)
	local width = (window.size.x - layout.BAR_WIDTH * hud) / 2 - 32 * hud
	return math.max(12, math.min(layout.QUEST_WRAP,
		math.floor(width / (9 * gui))))
end

-- The quest tracker's boxes (Round 65 ruling 4; grug_quests hud.lua). A box
-- holds two text lines of QUEST_BOX.line GUI px -- the title row with the
-- level label, then the objective -- inside QUEST_BOX.pad GUI px of padding
-- (48 px at GUI scaling 1); boxes stand QUEST_BOX.gap HUD px apart. Its
-- width is side_text_width's characters at QUEST_BOX.char GUI px each plus
-- the padding (350 px at 38 characters). Text is sized by GUI scaling and
-- offsets by HUD scaling, so the geometry is worked out in screen pixels
-- and returned in HUD units.
--
-- The stack stays inside a free band:
-- * Top: QUEST_BOX.block_gap HUD px below the minimap block -- the
--   minimap's box (minimap_box; the bezel is never larger), its location
--   line (LOCATION_GAP HUD px and one line) and, while `playing`, the "Now
--   playing" box (NOW_PLAYING_GAP HUD px and NOW_PLAYING_HEIGHT GUI px;
--   grug_map minimap_view.lua V.NOW_PLAYING, pinned by tools/r65_hud).
--   With the minimap hidden its side row and "Now playing" stay inside
--   the same box (world_map.md), so the band never needs to know.
-- * Bottom: QUEST_BOX.margin HUD px above the window's bottom edge, or
--   above the bottom-centre column where the box reaches over it: the XP
--   row's label (XP_LABEL_CHARS characters right of the XP bar) where the
--   box's left edge is left of the label's end, and the feed's top line
--   where it is left of the status icon row's or the feed's half width.
-- `count` boxes all show when they fit; otherwise as many as fit together
-- with one "+N more" line (one line) below them. The stack is centred on
-- the window's middle (the anchor's y) and pushed down below the band's top
-- or up from its bottom where needed.
--
-- Returns {shown, more, chars, width, height, pad, line, gap, tops[i],
-- more_top}: `shown` boxes and the `more` count, the characters per line,
-- the box width and height, its padding and line height, every box's top
-- and the "+N more" line's top as HUD offsets from the anchor (the boxes'
-- right edge is the anchor's x).
layout.QUEST_BOX = {pad = 4, line = 20, gap = 4, block_gap = 8, margin = 20,
	char = 9}
layout.LOCATION_GAP = 4
layout.NOW_PLAYING_GAP = 4
layout.NOW_PLAYING_HEIGHT = 48
layout.XP_LABEL_CHARS = 18

function layout.quest_boxes(window, count, playing)
	local Q = layout.QUEST_BOX
	local box = layout.minimap_box(window)
	local hud, gui, height = box.hud, box.gui, box.height
	local chars = layout.side_text_width(window)
	local pad, line = math.floor(Q.pad * gui + 0.5), math.ceil(Q.line * gui)
	local box_h, gap = 2 * pad + 2 * line, Q.gap * hud
	local width = chars * Q.char * gui + 2 * pad
	local top = (layout.MINIMAP_EDGE + layout.LOCATION_GAP) * hud + box.size + line
	if playing then
		top = top + layout.NOW_PLAYING_GAP * hud +
			math.ceil(layout.NOW_PLAYING_HEIGHT * gui)
	end
	top = top + Q.block_gap * hud
	-- The box's left edge, in px right of the window's centre.
	local left = box.width / 2 - (width - layout.anchors.quest_list.offset.x * hud)
	local bottom = height - Q.margin * hud
	if left < (layout.XP_WIDTH / 2 + 8) * hud + layout.XP_LABEL_CHARS * Q.char * gui then
		bottom = height + layout.rows.xp.middle * hud - line / 2 - Q.block_gap * hud
	end
	local status = math.max(layout.STATUS_PITCH,
		math.ceil(layout.STATUS_CAPTION_WIDTH * gui / hud) + 4) * layout.STATUS_LIMIT / 2
	if left < math.max(status * hud, layout.QUEST_WRAP * Q.char * gui / 2) then
		bottom = height + layout.feed_line_offset(layout.FEED_LINES, window).y * hud -
			line / 2 - Q.block_gap * hud
	end
	local function span(n, more)
		return n * (box_h + gap) - gap + (more and gap + line or 0)
	end
	local shown = count
	if span(count, false) > bottom - top then
		shown = 0
		while shown < count - 1 and span(shown + 1, true) <= bottom - top do
			shown = shown + 1
		end
	end
	local more = count - shown
	local total = span(shown, more > 0)
	local y = math.max(top, math.min(height / 2 - total / 2, bottom - total))
	local out = {shown = shown, more = more, chars = chars, width = width / hud,
		height = box_h / hud, pad = pad / hud, line = line / hud, gap = Q.gap, tops = {}}
	for i = 1, shown do
		out.tops[i] = (y + (i - 1) * (box_h + gap) - height / 2) / hud
	end
	if more > 0 then
		out.more_top = (y + shown * (box_h + gap) - height / 2) / hud
	end
	return out
end

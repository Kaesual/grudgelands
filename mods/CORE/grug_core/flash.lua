-- The shared one-line screen flash (moved here from grug_abilities in Round
-- 24 so mining hints can use it too). One text element per player at
-- hud_layout.anchors.flash; a message stays 1.5 s unless a newer one replaces
-- it. Red is the error colour (skill failures); callers may pass another.
-- Since Round 86 a message may carry an icon drawn before it (the house icon
-- of a home's protection hint), centred together with the text
-- (hud_layout.icon_before_offsets); its element is added at the first icon.

local FLASH_SECONDS = 1.5
grug_core.FLASH_COLOR = {error = 0xff4444, notice = 0xf0e6c8}
-- The icon textures' side in pixels (the house icon is 32 px).
local ICON_PX = 32

local flash_huds = {} -- player name -> {id = hud id, token = n, color = n, ...}

core.register_on_joinplayer(function(player)
	flash_huds[player:get_player_name()] = {token = 0,
		color = grug_core.FLASH_COLOR.error, offset_x = 0,
		id = player:hud_add(grug_core.hud_layout.text_element("flash",
			{number = grug_core.FLASH_COLOR.error, text = ""}))}
end)

core.register_on_leaveplayer(function(player)
	flash_huds[player:get_player_name()] = nil
end)

-- The icon before the line, or none (`icon` nil); only changes are sent.
local function place_icon(player, rec, message, icon)
	local layout = grug_core.hud_layout
	local anchor = layout.anchors.flash
	local g
	if icon then
		g = layout.icon_before_offsets(message, nil, false,
			core.get_player_window_information(player:get_player_name()), ICON_PX)
		if not rec.icon then
			rec.icon = player:hud_add(layout.image_element("flash", {text = "", z_index = 0}))
			rec.icon_text, rec.icon_x, rec.icon_scale = "", anchor.offset.x, 1
		end
	end
	local x = anchor.offset.x + (g and g.text_x or 0)
	if rec.offset_x ~= x then
		rec.offset_x = x
		player:hud_change(rec.id, "offset", {x = x, y = anchor.offset.y})
	end
	if not rec.icon then return end
	if g and rec.icon_x ~= anchor.offset.x + g.icon_x then
		rec.icon_x = anchor.offset.x + g.icon_x
		player:hud_change(rec.icon, "offset", {x = rec.icon_x, y = anchor.offset.y})
	end
	if g and rec.icon_scale ~= g.scale then
		rec.icon_scale = g.scale
		player:hud_change(rec.icon, "scale", {x = g.scale, y = g.scale})
	end
	local texture = icon or ""
	if rec.icon_text ~= texture then
		rec.icon_text = texture
		player:hud_change(rec.icon, "text", texture)
	end
end

-- Show `message` in the flash line. `color` is an optional 0xRRGGBB number;
-- it defaults to the error red. `icon` (optional) is a texture drawn before
-- the line.
function grug_core.flash(player, message, color, icon)
	local name = player and player.get_player_name and player:get_player_name()
	local rec = name and flash_huds[name]
	if not rec then
		return false
	end
	color = color or grug_core.FLASH_COLOR.error
	if rec.color ~= color then
		rec.color = color
		player:hud_change(rec.id, "number", color)
	end
	rec.token = rec.token + 1
	local token = rec.token
	place_icon(player, rec, message, icon)
	player:hud_change(rec.id, "text", message)
	core.after(FLASH_SECONDS, function()
		local p = core.get_player_by_name(name)
		local r = flash_huds[name]
		if p and r and r.token == token then
			p:hud_change(r.id, "text", "")
			place_icon(p, r, "", nil)
		end
	end)
	return true
end

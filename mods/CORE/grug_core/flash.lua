-- The shared one-line screen flash (moved here from grug_abilities in Round
-- 24 so mining hints can use it too). One text element per player at
-- hud_layout.anchors.flash; a message stays 1.5 s unless a newer one replaces
-- it. Red is the error colour (skill failures); callers may pass another.

local FLASH_SECONDS = 1.5
grug_core.FLASH_COLOR = {error = 0xff4444, notice = 0xf0e6c8}

local flash_huds = {} -- player name -> {id = hud id, token = n, color = n}

core.register_on_joinplayer(function(player)
	flash_huds[player:get_player_name()] = {token = 0,
		color = grug_core.FLASH_COLOR.error,
		id = player:hud_add(grug_core.hud_layout.text_element("flash",
			{number = grug_core.FLASH_COLOR.error, text = ""}))}
end)

core.register_on_leaveplayer(function(player)
	flash_huds[player:get_player_name()] = nil
end)

-- Show `message` in the flash line. `color` is an optional 0xRRGGBB number;
-- it defaults to the error red.
function grug_core.flash(player, message, color)
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
	player:hud_change(rec.id, "text", message)
	core.after(FLASH_SECONDS, function()
		local p = core.get_player_by_name(name)
		local r = flash_huds[name]
		if p and r and r.token == token then
			p:hud_change(r.id, "text", "")
		end
	end)
	return true
end

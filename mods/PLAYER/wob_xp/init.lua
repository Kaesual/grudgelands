wob_xp = {}

local META_XP = "wob_xp:xp"

wob_xp.MAX_LEVEL = 60
-- Anteil des Fortschritts im aktuellen Level, der beim Tod verloren geht.
-- Es gibt kein De-Leveling: Verlust reicht maximal bis zum Levelanfang.
wob_xp.DEATH_XP_LOSS = 0.25

--
-- Level-Kurve: kumulative XP fuer Level L (Level 1 = 0 XP).
-- Quadratisch: Level 2 = 100, Level 10 = 8100, Level 60 = 348100.
--

function wob_xp.xp_for_level(level)
	level = math.min(level, wob_xp.MAX_LEVEL)
	return 100 * (level - 1) * (level - 1)
end

function wob_xp.level_from_xp(xp)
	-- 1e-9: schuetzt vor sqrt-Rundung knapp unter der Levelgrenze
	local level = math.floor(math.sqrt(xp / 100) + 1e-9) + 1
	return math.min(level, wob_xp.MAX_LEVEL)
end

--
-- API
--

local level_change_callbacks = {}

-- func(player, old_level, new_level) — wird bei Level-Aenderung gerufen
-- (auch beim Join, mit old_level = nil, zum Initialisieren von Stats/HUD).
function wob_xp.register_on_level_change(func)
	table.insert(level_change_callbacks, func)
end

local function run_level_callbacks(player, old_level, new_level)
	for _, func in ipairs(level_change_callbacks) do
		func(player, old_level, new_level)
	end
end

function wob_xp.get_xp(player)
	return player:get_meta():get_int(META_XP)
end

function wob_xp.get_level(player)
	return wob_xp.level_from_xp(wob_xp.get_xp(player))
end

local hud_update -- forward (unten definiert)

function wob_xp.set_xp(player, xp)
	xp = math.max(0, math.floor(xp))
	local old_level = wob_xp.get_level(player)
	player:get_meta():set_int(META_XP, xp)
	local new_level = wob_xp.level_from_xp(xp)
	if new_level ~= old_level then
		run_level_callbacks(player, old_level, new_level)
		if new_level > old_level then
			core.chat_send_player(player:get_player_name(),
				core.colorize("#ffd100", "Level " .. new_level .. " erreicht!"))
		end
	end
	hud_update(player)
end

function wob_xp.add_xp(player, amount)
	wob_xp.set_xp(player, wob_xp.get_xp(player) + amount)
end

--
-- XP-Verlust beim Tod: Anteil des Fortschritts im aktuellen Level.
--

core.register_on_dieplayer(function(player)
	local xp = wob_xp.get_xp(player)
	local level = wob_xp.level_from_xp(xp)
	local floor_xp = wob_xp.xp_for_level(level)
	local progress = xp - floor_xp
	local loss = math.floor(progress * wob_xp.DEATH_XP_LOSS)
	if loss > 0 then
		wob_xp.set_xp(player, xp - loss)
		core.chat_send_player(player:get_player_name(),
			core.colorize("#ff4444", "Du hast " .. loss .. " XP verloren."))
	end
end)

--
-- HUD: "Level 12  —  3.400 / 12.100 XP" unten mittig ueber der Hotbar.
--

local hud_ids = {}

local function hud_text(player)
	local xp = wob_xp.get_xp(player)
	local level = wob_xp.level_from_xp(xp)
	if level >= wob_xp.MAX_LEVEL then
		return "Level " .. level .. " (Max)"
	end
	local floor_xp = wob_xp.xp_for_level(level)
	local next_xp = wob_xp.xp_for_level(level + 1)
	return ("Level %d  |  %d / %d XP"):format(level, xp - floor_xp, next_xp - floor_xp)
end

hud_update = function(player)
	local id = hud_ids[player:get_player_name()]
	if id then
		player:hud_change(id, "text", hud_text(player))
	end
end

core.register_on_joinplayer(function(player)
	hud_ids[player:get_player_name()] = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 1},
		offset = {x = 0, y = -110},
		alignment = {x = 0, y = 0},
		number = 0xffd100,
		text = hud_text(player),
	})
	run_level_callbacks(player, nil, wob_xp.get_level(player))
end)

core.register_on_leaveplayer(function(player)
	hud_ids[player:get_player_name()] = nil
end)

--
-- Debug-/Admin-Kommando
--

core.register_chatcommand("xp", {
	params = "[<anzahl>]",
	description = "Eigene XP anzeigen oder (als Admin) XP hinzufügen",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false
		end
		if param ~= "" then
			local amount = tonumber(param)
			if not amount then
				return false, "Ungültige Zahl: " .. param
			end
			if not core.check_player_privs(name, {server = true}) then
				return false, "Dafür brauchst du das 'server'-Privileg."
			end
			wob_xp.add_xp(player, amount)
		end
		return true, hud_text(player)
	end,
})

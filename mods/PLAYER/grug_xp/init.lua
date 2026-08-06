grug_xp = {}

local META_XP = "grug_xp:xp"

grug_xp.MAX_LEVEL = 60
-- Share of the progress within the current level that is lost on death.
-- There is no de-leveling: the loss reaches at most the level floor.
grug_xp.DEATH_XP_LOSS = 0.25

--
-- Level curve: cumulative XP for level L (level 1 = 0 XP).
-- Quadratic: level 2 = 100, level 10 = 8100, level 60 = 348100.
--

function grug_xp.xp_for_level(level)
	level = math.min(level, grug_xp.MAX_LEVEL)
	return 100 * (level - 1) * (level - 1)
end

function grug_xp.level_from_xp(xp)
	-- 1e-9: guards against sqrt rounding just below the level boundary
	local level = math.floor(math.sqrt(xp / 100) + 1e-9) + 1
	return math.min(level, grug_xp.MAX_LEVEL)
end

--
-- API
--

local level_change_callbacks = {}

-- func(player, old_level, new_level) — called on level change (also on
-- join, with old_level = nil, to initialize stats/HUD).
function grug_xp.register_on_level_change(func)
	table.insert(level_change_callbacks, func)
end

local function run_level_callbacks(player, old_level, new_level)
	for _, func in ipairs(level_change_callbacks) do
		func(player, old_level, new_level)
	end
end

function grug_xp.get_xp(player)
	return player:get_meta():get_int(META_XP)
end

function grug_xp.get_level(player)
	return grug_xp.level_from_xp(grug_xp.get_xp(player))
end

local hud_update -- forward (defined below)

function grug_xp.set_xp(player, xp)
	xp = math.max(0, math.floor(xp))
	local old_level = grug_xp.get_level(player)
	player:get_meta():set_int(META_XP, xp)
	local new_level = grug_xp.level_from_xp(xp)
	if new_level ~= old_level then
		run_level_callbacks(player, old_level, new_level)
		if new_level > old_level then
			core.chat_send_player(player:get_player_name(),
				core.colorize("#ffd100", "Reached level " .. new_level .. "!"))
		end
	end
	hud_update(player)
end

-- `source` (optional) tags where the XP comes from ("kill", "quest", ...)
-- and lets race passives scale it (world.md §7: human +10% quest XP).
-- grug_classes loads after grug_xp, hence the runtime global probe. No
-- caller passes "quest" yet — the quest framework (WP8) gets the bonus
-- for free by tagging its rewards.
function grug_xp.add_xp(player, amount, source)
	if source and core.global_exists("grug_classes") then
		amount = math.floor(amount * grug_classes.get_xp_bonus(player, source) + 0.5)
	end
	grug_xp.set_xp(player, grug_xp.get_xp(player) + amount)
end

--
-- XP loss on death: a share of the progress within the current level.
--

core.register_on_dieplayer(function(player)
	local xp = grug_xp.get_xp(player)
	local level = grug_xp.level_from_xp(xp)
	local floor_xp = grug_xp.xp_for_level(level)
	local progress = xp - floor_xp
	local loss = math.floor(progress * grug_xp.DEATH_XP_LOSS)
	if loss > 0 then
		grug_xp.set_xp(player, xp - loss)
		core.chat_send_player(player:get_player_name(),
			core.colorize("#ff4444", "You lost " .. loss .. " XP."))
	end
end)

--
-- HUD: "Level 12  |  3400 / 12100 XP" bottom center above the hotbar.
--

local hud_ids = {}

local function hud_text(player)
	local xp = grug_xp.get_xp(player)
	local level = grug_xp.level_from_xp(xp)
	if level >= grug_xp.MAX_LEVEL then
		return "Level " .. level .. " (max)"
	end
	local floor_xp = grug_xp.xp_for_level(level)
	local next_xp = grug_xp.xp_for_level(level + 1)
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
	run_level_callbacks(player, nil, grug_xp.get_level(player))
end)

core.register_on_leaveplayer(function(player)
	hud_ids[player:get_player_name()] = nil
end)

--
-- Debug/admin command
--

core.register_chatcommand("xp", {
	params = "[<amount>]",
	description = "Show your XP or (as admin) add XP",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false
		end
		if param ~= "" then
			local amount = tonumber(param)
			if not amount then
				return false, "Not a number: " .. param
			end
			if not core.check_player_privs(name, {server = true}) then
				return false, "You need the 'server' privilege for this."
			end
			grug_xp.add_xp(player, amount)
		end
		return true, hud_text(player)
	end,
})

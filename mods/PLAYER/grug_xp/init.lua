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

-- Resolve grug_core's dependency-free level stub now that the XP owner is
-- loaded. Combat consumers never read player meta or duplicate the curve.
grug_core.get_player_level = grug_xp.get_level

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
-- XP loss on death: 25% of the whole current-level span, clamped to the
-- current level floor. A low-progress death therefore reaches the floor but
-- never de-levels. Level 60 has no following span and loses no XP.
--

core.register_on_dieplayer(function(player)
	local xp = grug_xp.get_xp(player)
	local level = grug_xp.level_from_xp(xp)
	local floor_xp = grug_xp.xp_for_level(level)
	local next_xp = grug_xp.xp_for_level(math.min(grug_xp.MAX_LEVEL, level + 1))
	local span = next_xp - floor_xp
	local wanted = math.floor(span * grug_xp.DEATH_XP_LOSS)
	local loss = math.min(xp - floor_xp, wanted)
	if loss > 0 then
		grug_xp.set_xp(player, xp - loss)
		core.chat_send_player(player:get_player_name(),
			core.colorize("#ff4444", "You lost " .. loss .. " XP."))
	end
end)

--
-- Thin gold progress above the hotbar. Exact XP remains in /xp.
-- All geometry comes from grug_core.hud_layout.
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

local function hud_progress(player)
	local layout = grug_core.hud_layout
	local xp = grug_xp.get_xp(player)
	local level = grug_xp.level_from_xp(xp)
	local width = layout.XP_WIDTH
	if level < grug_xp.MAX_LEVEL then
		local floor_xp = grug_xp.xp_for_level(level)
		width = layout.bar_fill(xp - floor_xp,
			grug_xp.xp_for_level(level + 1) - floor_xp, layout.XP_WIDTH)
	end
	return width, "Lv " .. level
end

hud_update = function(player)
	local row = hud_ids[player:get_player_name()]
	if not row then return end
	local width, label = hud_progress(player)
	local layout = grug_core.hud_layout
	if row.width ~= width then
		player:hud_change(row.fill, "scale", {x = width, y = layout.rows.xp.height})
		row.width = width
	end
	if row.text ~= label then
		player:hud_change(row.label, "text", label)
		row.text = label
	end
end

core.register_on_joinplayer(function(player)
	local layout = grug_core.hud_layout
	local width, label = hud_progress(player)
	hud_ids[player:get_player_name()] = {
		track = player:hud_add(layout.bar_element("xp", layout.XP_WIDTH, layout.COLOR.track, 0)),
		fill = player:hud_add(layout.bar_element("xp", width, layout.COLOR.xp, 1)),
		label = player:hud_add(layout.xp_label(label)),
		width = width, text = label,
	}
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

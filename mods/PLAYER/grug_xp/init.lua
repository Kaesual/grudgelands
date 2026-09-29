grug_xp = {}

local META_XP = "grug_xp:xp"

grug_xp.MAX_LEVEL = 60

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
	if type(xp) ~= "number" or xp ~= xp or
			xp == math.huge or xp == -math.huge then
		return false, 0
	end
	local maximum = grug_xp.xp_for_level(grug_xp.MAX_LEVEL)
	xp = math.max(0, math.min(maximum, math.floor(xp)))
	local old_xp = grug_xp.get_xp(player)
	local old_level = grug_xp.get_level(player)
	player:get_meta():set_int(META_XP, xp)
	local new_level = grug_xp.level_from_xp(xp)
	if new_level ~= old_level then
		run_level_callbacks(player, old_level, new_level)
		if new_level > old_level then
			core.chat_send_player(player:get_player_name(),
				core.colorize("#ffd100", "Reached level " .. new_level .. "!"))
			local pos = player:get_pos()
			if pos then
				core.add_particlespawner({
					amount = 18,
					time = 0.2,
					pos = {min = vector.offset(pos, -0.5, 0.2, -0.5),
						max = vector.offset(pos, 0.5, 1.8, 0.5)},
					vel = {min = vector.new(-1, 1, -1),
						max = vector.new(1, 3, 1)},
					exptime = {min = 0.35, max = 0.7},
					size = {min = 1.5, max = 3},
					texture = "default_item_smoke.png^[multiply:#ffd100",
				})
			end
		end
	end
	hud_update(player)
	return true, xp - old_xp
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
	return grug_xp.set_xp(player, grug_xp.get_xp(player) + amount)
end

--
-- Gathering XP (Round 24 ruling 28), the one place of its factors and formula:
--
--   XP = factor x min(reference level, player level + 5), rounded half up
--
-- The reference level is the top of a ten-level band: 10 x harvest tier for
-- an ore or gem node (T1 10 .. T5 50), 10 x the water's zone band for a fish
-- (10 .. 60). No gray rule: T1 always pays. Source "gathering" carries no race
-- or class bonus (grug_classes.get_xp_bonus scales only "quest").
--
grug_xp.GATHERING_XP_FACTOR = {ore = 1.5, gem = 3, fish = 5}
grug_xp.GATHERING_LEVEL_OFFSET = 5

function grug_xp.gathering_reference_level(tier_or_band)
	return 10 * tier_or_band
end

function grug_xp.gathering_xp(kind, reference_level, player_level)
	local factor = grug_xp.GATHERING_XP_FACTOR[kind]
	if not factor then
		error("[grug_xp] unknown gathering kind " .. tostring(kind))
	end
	local level = math.min(reference_level,
		player_level + grug_xp.GATHERING_LEVEL_OFFSET)
	return math.floor(factor * level + 0.5)
end

-- Awards and returns the gathering XP of one ore/gem node or one fish.
function grug_xp.award_gathering(player, kind, reference_level)
	local amount = grug_xp.gathering_xp(kind, reference_level,
		grug_xp.get_level(player))
	grug_xp.add_xp(player, amount, "gathering")
	return amount
end

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
	if level >= grug_xp.MAX_LEVEL then
		return width, "Lv " .. level .. " (max)"
	end
	local floor_xp = grug_xp.xp_for_level(level)
	local interval = grug_xp.xp_for_level(level + 1) - floor_xp
	return width, ("Lv %d (%d/%d)"):format(level, xp - floor_xp, interval)
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
	params = "[give <player> <amount>]",
	description = "Show your XP or grant XP to an online player",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player is not online."
		end
		if param == "" then
			return true, hud_text(player)
		end
		local target_name, amount_text = param:match("^give%s+(%S+)%s+(%S+)%s*$")
		if not target_name then
			return false, "Usage: /xp give <player> <positive amount>"
		end
		if not core.check_player_privs(name, {server = true}) then
			return false, "You need the 'server' privilege for this."
		end
		local amount = tonumber(amount_text)
		if not amount or amount ~= amount or amount == math.huge or
				amount == -math.huge or amount < 1 or amount % 1 ~= 0 then
			return false, "Amount must be a positive whole number."
		end
		local target = core.get_player_by_name(target_name)
		if not target then
			return false, "Player is not online: " .. target_name
		end
		local ok, granted = grug_xp.add_xp(target, amount)
		if not ok then
			return false, "Amount must be a finite whole number."
		end
		return true, target_name .. ": granted " .. granted .. " XP; " ..
			hud_text(target)
	end,
})

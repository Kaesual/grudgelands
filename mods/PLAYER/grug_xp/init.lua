grug_xp = {}

local META_XP = "grug_xp:xp"
-- The level, stored for tools outside the game (the realm website reads player
-- meta, never game code; contract: docs/technical/module-guide.md "Player meta
-- read by external tools"). Derived from XP on every XP change and every join;
-- XP stays the authority and get_level never reads it.
local META_LEVEL = "grug_xp:level"

grug_xp.MAX_LEVEL = 60

--
-- XP units (Round 28 rulings 30-32, progression.md). Every XP amount is
-- measured in kill equivalents: M(L), the XP of one normal-tier kill at level
-- L. Kills, the level curve, quest rewards and gathering all derive from it,
-- so retuning means editing this block only. tools/r28_design/r28common.py
-- implements the same formulas for the design ledger; tools/r28_b3_xp
-- cross-checks both.
--

-- A reward reads its level at most this far above the player's (kill and
-- gathering XP).
grug_xp.LEVEL_OFFSET = 5

-- M(L) = 25 + 5L: L1 30, L10 75, L30 175, L60 325.
function grug_xp.mob_xp(level)
	return 25 + 5 * level
end

-- XP from `level` to `level + 1`: M(L) x k(L) rounded to tens, with
-- k(L) = 8 + 0.29 (L - 1) same-level kill equivalents (8 at L1, about 25
-- at L59). Same operation order as the ledger, so both round identically.
function grug_xp.level_xp(level)
	return 10 * math.floor(grug_xp.mob_xp(level) * (8 + 0.29 * (level - 1)) / 10 + 0.5)
end

-- Quest reward of `weight` kill equivalents at the quest's reward level,
-- rounded half up. The race bonus is applied later by add_xp (source "quest").
function grug_xp.quest_reward(level, weight)
	return math.floor(weight * grug_xp.mob_xp(level) + 0.5)
end

-- LEVEL_START[L] = cumulative XP at which level L starts (level 1 = 0 XP):
-- 4,200 at level 10, 194,220 at level 60.
local LEVEL_START = {0}
for level = 1, grug_xp.MAX_LEVEL - 1 do
	LEVEL_START[level + 1] = LEVEL_START[level] + grug_xp.level_xp(level)
end

function grug_xp.xp_for_level(level)
	return LEVEL_START[math.max(1, math.min(level, grug_xp.MAX_LEVEL))]
end

function grug_xp.level_from_xp(xp)
	local level = 1
	while level < grug_xp.MAX_LEVEL and xp >= LEVEL_START[level + 1] do
		level = level + 1
	end
	return level
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

-- The level-up banner (Round 28 ruling 20): "Reached level N!", plus a second
-- line naming the talent points the jump earned (Round 36 §2.14.4), "+1 Talent
-- Point" or "+2 Talent Points" over several levels. grug_classes owns the
-- point rule (talent_points_at) and loads after grug_xp, hence the runtime
-- global probe, as in add_xp below.
function grug_xp.level_up_text(old_level, new_level)
	local text = "Reached level " .. new_level .. "!"
	if core.global_exists("grug_classes") and grug_classes.talent_points_at then
		local gained = grug_classes.talent_points_at(new_level)
			- grug_classes.talent_points_at(old_level)
		if gained > 0 then
			text = text .. "\nYou gained +" .. gained ..
				(gained == 1 and " Talent Point" or " Talent Points")
		end
	end
	return text
end

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
	player:get_meta():set_int(META_LEVEL, new_level)
	if new_level ~= old_level then
		run_level_callbacks(player, old_level, new_level)
		if new_level > old_level then
			-- Round 28 ruling 20: a large centre announcement, no chat line.
			grug_core.banner(player, grug_xp.level_up_text(old_level, new_level),
				grug_core.hud_layout.COLOR.xp)
			grug_sounds.play("level_up", player)
			local pos = player:get_pos()
			if pos then
				grug_core.particles.play("level_up", {caster = pos})
			end
		end
	end
	hud_update(player)
	return true, xp - old_xp
end

-- `source` (optional) tags where the XP comes from ("kill", "quest", ...)
-- and lets race passives scale it (world.md §7: human +10% quest XP).
-- grug_classes loads after grug_xp, hence the runtime global probe. Only
-- "quest" is scaled today (grug_quests tags its rewards); kill and
-- gathering XP carry no race bonus.
-- Every positive grant shows in the message feed (Round 28 ruling 20,
-- grug_core.feed_xp) unless `quiet` is true: a caller that already names
-- the XP in its own feed line (a fishing catch) passes it.
function grug_xp.add_xp(player, amount, source, quiet)
	if source and core.global_exists("grug_classes") then
		amount = math.floor(amount * grug_classes.get_xp_bonus(player, source) + 0.5)
	end
	local ok, granted = grug_xp.set_xp(player, grug_xp.get_xp(player) + amount)
	if ok and not quiet and granted > 0 then grug_core.feed_xp(player, granted) end
	return ok, granted
end

--
-- Gathering XP (Round 24 ruling 28, in kill equivalents since Round 28
-- ruling 32):
--
--   XP = ratio x M(min(reference level, player level + 5)), rounded half up
--
-- The reference level is the top of a ten-level band: 10 x harvest tier for
-- an ore or gem node (T1 10 .. T6 60), 10 x the water's zone band for a fish
-- (10 .. 60). No gray rule: T1 always pays. Source "gathering" carries no race
-- or class bonus (grug_classes.get_xp_bonus scales only "quest").
--
grug_xp.GATHER_XP_RATIO = {ore = 0.10, gem = 0.20, fish = 0.33}

function grug_xp.gathering_reference_level(tier_or_band)
	return 10 * tier_or_band
end

function grug_xp.gather_xp(kind, reference_level, player_level)
	local ratio = grug_xp.GATHER_XP_RATIO[kind]
	if not ratio then
		error("[grug_xp] unknown gathering kind " .. tostring(kind))
	end
	local level = math.min(reference_level, player_level + grug_xp.LEVEL_OFFSET)
	return math.floor(ratio * grug_xp.mob_xp(level) + 0.5)
end

-- Awards and returns the gathering XP of one ore/gem node or one fish.
-- `quiet` as in add_xp.
function grug_xp.award_gathering(player, kind, reference_level, quiet)
	local amount = grug_xp.gather_xp(kind, reference_level,
		grug_xp.get_level(player))
	grug_xp.add_xp(player, amount, "gathering", quiet)
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
	player:get_meta():set_int(META_LEVEL, grug_xp.get_level(player))
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

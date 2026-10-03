-- The status icon registry (Round 26 rulings 17-21,
-- docs/planning/status-icons-2026-09-29.md "User decisions").
--
-- One table answers "which picture and which frame does status <id> get?".
-- Every status id the game shows is listed here with its frame category:
--   buff    green frame  (grug_status_frame_buff.png)
--   debuff  red frame    (grug_status_frame_debuff.png)
--   neutral gold frame   (grug_status_frame_neutral.png), for states that are
--           neither: the combat state and the two PvP tags.
-- The art is a 64x64 opaque plate; the frame is a 64x64 overlay with a
-- transparent centre, composited by texture modifier (`icon^frame`).
--
-- Cooldowns never become statuses (ruling 21): the potion cooldown and the
-- talent-trigger clocks stay off this table on purpose.
--
-- This file is PURE Lua: it calls nothing from `core`, so the portable
-- fixture (tools/r26_status_icons) loads the real thing.

local icons = {}
grug_core.status_icons = icons

icons.FRAME = {
	buff = "grug_status_frame_buff.png",
	debuff = "grug_status_frame_debuff.png",
	neutral = "grug_status_frame_neutral.png",
}

-- The plate colour of the delivered art (every grug_status_* corner pixel),
-- used behind a food item's own inventory image so it reads like the rest.
icons.PLATE = "#151f2d"
icons.GENERIC_FOOD = "grug_status_food.png"
-- Only reachable for an id missing from the table below, which the portable
-- fixture forbids for every set_status call site; drawn as a bare plate.
icons.FALLBACK = "[fill:64x64:" .. icons.PLATE

local function art(id)
	return "grug_status_" .. id .. ".png"
end

local function skill(id)
	return "grug_abilities_skill_" .. id .. ".png"
end

-- id -> {kind = frame category, name, detail, icon = texture,
--        variants = {name -> texture}}
-- A variant picks the picture only; the frame always follows the id's kind.
-- `name` and `detail` are the Character page Effects tab defaults; a caller's
-- `label` / `detail` (set_status) replace them with the specific ones
-- ("Elixir of Focus III", "+6% HP/5s").
local function def(kind, name, detail, icon, variants)
	return {kind = kind, name = name, detail = detail, icon = icon,
		variants = variants}
end

icons.STATUS = {
	-- Consumables. Food shows the eaten item's own image when it has one
	-- (see item_icon); the generic plate is the fallback.
	food = def("buff", "Food", "Regeneration out of combat",
		icons.GENERIC_FOOD),
	elixir = def("buff", "Elixir", "", art("elixir_vigor"), {
		vigor = art("elixir_vigor"),
		focus = art("elixir_focus"),
		precision = art("elixir_precision"),
		stoneskin = art("elixir_stoneskin"),
		deepwater = art("elixir_deepwater"),
	}),
	alchemy_swiftness = def("buff", "Swiftness Draught", "+10% movement speed",
		art("alchemy_swiftness")),
	alchemy_cave = def("buff", "Cave Draught", "Night vision",
		art("alchemy_cave")),
	-- Planned (items_crafting.md Warding Draught); art delivered, no caller yet.
	warding_draught = def("buff", "Warding Draught",
		"Less damage from one race", art("warding_draught")),

	-- Movement and mounts.
	mount = def("buff", "Mount", "", art("mount_land"), {
		land = art("mount_land"),
		flight = art("mount_flight"),
		water = art("mount_water"),
	}),
	move_immune = def("buff", "Unstoppable", "Cannot be rooted or slowed",
		art("move_immune")),

	-- Ability buffs reuse their Round-18 skill icon (user decision).
	scout_sprint = def("buff", "Sprint", "+50% movement speed", skill("sprint")),
	sidestep = def("buff", "Sidestep", "+15 dodge chance", skill("sidestep")),
	renew = def("buff", "Renew", "Heals every 3 s", skill("renew")),
	-- One generic shield for every absorb source (user decision).
	shield = def("buff", "Shield", "Absorbs damage", art("shield")),

	-- Talent windows (skill_trees.md section 3.2).
	talent_unbroken = def("buff", "Unbroken", "+15 armor rating",
		art("talent_unbroken")),
	talent_ruination = def("buff", "Ruination", "+20 crit chance",
		art("talent_ruination")),
	talent_whitehot = def("buff", "Whitehot", "Cheaper, stronger Fireball",
		art("talent_whitehot")),
	talent_turn_aside = def("buff", "Turn Aside",
		"Extra dodge while the shield holds", art("talent_turn_aside")),
	talent_last_word = def("buff", "Last Word", "Word of Ruin drain heals 150%",
		art("talent_last_word")),
	talent_untouchable = def("buff", "Untouchable", "+25 dodge chance",
		art("talent_untouchable")),

	-- Hostile effects. One slow icon for every slow (user decision).
	poisoned = def("debuff", "Poisoned", "Damage over time", art("poisoned")),
	slowed = def("debuff", "Slowed", "Movement speed reduced", art("slowed")),
	rooted = def("debuff", "Rooted", "Cannot move", art("rooted")),
	stunned = def("debuff", "Stunned", "Cannot act or move", art("stunned")),
	scorched = def("debuff", "Scorched", "Burning ground", art("scorched")),

	-- Neither buff nor debuff. in_combat is drawn next to the health bar by
	-- combat_hud.lua, not on the status row (ruling 19). The PvP flag
	-- (Round 31, grug_pvp/hud.lua, a status source): pvp_tagged with the
	-- countdown while the button or PvP contact flags the player, untimed
	-- pvp_contested while the location does (its label names contested or
	-- enemy territory).
	in_combat = def("neutral", "In combat", "No eating, mounting or regeneration",
		art("in_combat")),
	pvp_tagged = def("neutral", "PvP flagged", "Flagged enemies can attack you",
		art("pvp_tagged")),
	pvp_contested = def("neutral", "Contested Territory",
		"Flagged enemies can attack you", art("pvp_contested")),
}

-- The Effects tab's remaining time: coarse on purpose, so the cached page
-- only needs a rebuild when this text changes (about once a minute).
function icons.remaining_text(remaining_us, untimed)
	if untimed then
		return "active"
	end
	local seconds = math.max(0, math.ceil((tonumber(remaining_us) or 0) / 1e6))
	if seconds < 60 then
		return "under 1 min left"
	elseif seconds < 5400 then
		return math.ceil(seconds / 60) .. " min left"
	end
	return math.ceil(seconds / 3600) .. " h left"
end

-- The talent windows that become statuses, talent id -> status id. Hold
-- Ground's window is not listed: what the player sees of it is the shield and
-- the movement immunity, both of which have their own status. Turn Aside is
-- not a started window but a modifier riding on a shield, so combat.lua
-- reports talent_turn_aside itself.
icons.TALENT_WINDOWS = {
	unbroken = "talent_unbroken",
	ruination = "talent_ruination",
	whitehot = "talent_whitehot",
	last_word = "talent_last_word",
	untouchable = "talent_untouchable",
}

-- Row order: buffs, then debuffs, then neutral states; inside one kind by id,
-- so an icon keeps its place while others come and go.
icons.KIND_RANK = {buff = 1, debuff = 2, neutral = 3}
-- Which statuses keep a slot when there are more than the row holds:
-- debuffs first, then neutral states, buffs last.
icons.KEEP_RANK = {debuff = 1, neutral = 2, buff = 3}

function icons.kind_of(id)
	local def = icons.STATUS[id]
	return def and def.kind or nil
end

-- A food item's own picture on the icon plate. `image` is the item's
-- inventory image (or its wield image); anything else -- a node drawn as an
-- inventory cube, an empty string, a missing definition -- is not
-- "straightforward" (ruling 20) and gets the generic food icon.
function icons.item_icon(item_definition)
	if type(item_definition) ~= "table" then
		return nil
	end
	for _, key in ipairs({"inventory_image", "wield_image"}) do
		local image = item_definition[key]
		if type(image) == "string" and image ~= "" then
			-- The item art is usually 16 px with a transparent background: a
			-- plate of the same size goes under it, the pair is scaled to the
			-- 64 px of the frame (nearest neighbour keeps pixel art crisp).
			return "[fill:16x16:" .. icons.PLATE .. "^(" .. image ..
				")^[resize:64x64"
		end
	end
	return nil
end

-- The full texture for one status: picture (explicit override, else the
-- variant, else the id's own) plus the frame of its kind.
function icons.texture(id, variant, override)
	local def = icons.STATUS[id]
	local kind = def and def.kind or "buff"
	local picture = override
	if not picture and def then
		picture = variant and def.variants and def.variants[variant] or def.icon
	end
	return (picture or icons.FALLBACK) .. "^" .. icons.FRAME[kind]
end

-- The text under an icon. Seconds below a minute, M:SS below ten minutes,
-- then whole minutes, hours and days, each rounded up so a status never
-- reads as over while it still runs.
function icons.countdown(remaining_us)
	local seconds = math.max(0, math.ceil((tonumber(remaining_us) or 0) / 1e6))
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 600 then
		return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
	elseif seconds < 3600 then
		return math.ceil(seconds / 60) .. "m"
	elseif seconds < 172800 then
		return math.ceil(seconds / 3600) .. "h"
	end
	return math.ceil(seconds / 86400) .. "d"
end

-- A value (the remaining shield) is shown instead of the countdown; an
-- untimed status without a value shows nothing.
function icons.caption(value, untimed, remaining_us)
	if value ~= nil then
		return tostring(math.max(0, math.floor(tonumber(value) or 0)))
	end
	if untimed then
		return ""
	end
	return icons.countdown(remaining_us)
end

-- The class icon for the party UI (ruling 22): plate only, no frame.
icons.CLASSES = {"warrior", "mage", "priest", "scout"}

function icons.class_icon(class_id)
	if type(class_id) ~= "string" or class_id == "" then
		return ""
	end
	for _, id in ipairs(icons.CLASSES) do
		if id == class_id then
			return "grug_class_" .. id .. ".png"
		end
	end
	return ""
end

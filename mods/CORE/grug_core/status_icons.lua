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

-- id -> {kind = frame category, icon = texture, variants = {name -> texture}}
-- A variant picks the picture only; the frame always follows the id's kind.
icons.STATUS = {
	-- Consumables. Food shows the eaten item's own image when it has one
	-- (see item_icon); the generic plate is the fallback.
	food = {kind = "buff", icon = icons.GENERIC_FOOD},
	elixir = {kind = "buff", icon = art("elixir_vigor"), variants = {
		vigor = art("elixir_vigor"),
		focus = art("elixir_focus"),
		precision = art("elixir_precision"),
		stoneskin = art("elixir_stoneskin"),
		deepwater = art("elixir_deepwater"),
	}},
	alchemy_swiftness = {kind = "buff", icon = art("alchemy_swiftness")},
	alchemy_cave = {kind = "buff", icon = art("alchemy_cave")},
	-- Planned (items_crafting.md Warding Draught); art delivered, no caller yet.
	warding_draught = {kind = "buff", icon = art("warding_draught")},

	-- Movement and mounts.
	mount = {kind = "buff", icon = art("mount_land"), variants = {
		land = art("mount_land"),
		flight = art("mount_flight"),
	}},
	move_immune = {kind = "buff", icon = art("move_immune")},

	-- Ability buffs reuse their Round-18 skill icon (user decision).
	scout_sprint = {kind = "buff", icon = skill("sprint")},
	sidestep = {kind = "buff", icon = skill("sidestep")},
	renew = {kind = "buff", icon = skill("renew")},
	-- One generic shield for every absorb source (user decision).
	shield = {kind = "buff", icon = art("shield")},

	-- Talent windows (skill_trees.md section 3.2).
	talent_unbroken = {kind = "buff", icon = art("talent_unbroken")},
	talent_ruination = {kind = "buff", icon = art("talent_ruination")},
	talent_whitehot = {kind = "buff", icon = art("talent_whitehot")},
	talent_turn_aside = {kind = "buff", icon = art("talent_turn_aside")},
	talent_last_word = {kind = "buff", icon = art("talent_last_word")},
	talent_untouchable = {kind = "buff", icon = art("talent_untouchable")},

	-- Hostile effects. One slow icon for every slow (user decision).
	poisoned = {kind = "debuff", icon = art("poisoned")},
	slowed = {kind = "debuff", icon = art("slowed")},
	rooted = {kind = "debuff", icon = art("rooted")},
	stunned = {kind = "debuff", icon = art("stunned")},
	scorched = {kind = "debuff", icon = art("scorched")},

	-- Neither buff nor debuff. in_combat is drawn next to the health bar by
	-- combat_hud.lua, not on the status row (ruling 19). The PvP tags are
	-- WP41's; their art and frame are ready for its set_status calls.
	in_combat = {kind = "neutral", icon = art("in_combat")},
	pvp_tagged = {kind = "neutral", icon = art("pvp_tagged")},
	pvp_contested = {kind = "neutral", icon = art("pvp_contested")},
}

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

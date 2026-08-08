-- The six-tier material ladder (WP25; items_crafting.md §3.0, world.md §2 R6).
--
-- One tier per ten character levels, and the thing that actually enforces it
-- is the ROCK, not a level check: below every tier boundary the stone is a
-- different node carrying a `level` group, and a pickaxe only digs it if its
-- `groupcaps.cracky.maxlevel` is at least that high (§3.0.4 — the engine
-- refuses the dig outright, it does not merely slow it down). Depth therefore
-- gates the metal ladder, and the server has to police nothing.
--
-- This mod is the home of everything that ladder is made of:
--   init.lua       tier table, public API, the five new stratum nodes
--   ores.lua       the four new ore nodes and their raw craftitems
--   overrides.lua  the default:* re-parameterisation (mese -> Emberstone,
--                  ore levels, the pickaxe maxlevel ladder)
--
-- What is deliberately NOT here: recipes. Smelting is WP26, gem cutting is
-- WP10. grug_traders runs three startup audits over craft/cook recipes at
-- every server start, and a half-priced placeholder recipe would trip them.

grug_materials = {}

--
-- The tier table -- PUBLIC CONTRACT.
--
-- Consumed by WP24 (housing isles build the same six layers under an isle,
-- world.md §2 R6: "identical on the continent and on the housing isles"),
-- and by WP26/WP29 (which material a tier's tools and bars are made of).
-- Nothing outside this mod may hardcode a boundary y or a node name; go
-- through TIERS / tier_at / stratum_node_for / level_for_tier instead.
--
-- Bands are INCLUSIVE on both ends and listed top-down, so a plain scan from
-- index 1 finds the tier of a y. Tier 1 reuses `default:stone` -- the surface
-- rock stays exactly what every vendored recipe and decoration expects.
-- `level` is the group value the stratum node carries and the `maxlevel` a
-- pickaxe needs to break it; T1 is level 0, i.e. no gate at all.
grug_materials.TIERS = {
	{level = 0, node = "default:stone",                y_max =  31000, y_min =   -100},
	{level = 1, node = "grug_materials:slate",         y_max =   -101, y_min =   -300},
	{level = 2, node = "grug_materials:basalt",        y_max =   -301, y_min =   -500},
	{level = 3, node = "grug_materials:granite",       y_max =   -501, y_min =   -700},
	{level = 4, node = "grug_materials:emberrock",     y_max =   -701, y_min =  -1000},
	{level = 5, node = "grug_materials:abyssal_rock",  y_max =  -1001, y_min = -31000},
}

local TIERS = grug_materials.TIERS
local TIER_COUNT = #TIERS

-- Tier of a world y, always 1..6 and never nil: everything above the map is
-- tier 1, everything below the last band is tier 6. Callers ask this for
-- mapgen positions, which can legitimately sit outside the map limits (and a
-- nil here would silently become "no stratum" == a hole in the gate).
-- A six-step scan is fine -- this runs per mapchunk column, not per node; if
-- a caller ever needs it per node it should hoist the lookup, not this
-- function get cleverer.
function grug_materials.tier_at(y)
	for i = 1, TIER_COUNT do
		if y >= TIERS[i].y_min then
			return i
		end
	end
	return TIER_COUNT
end

-- Itemstring of the rock that belongs at this depth ("default:stone" for T1).
function grug_materials.stratum_node_for(y)
	return TIERS[grug_materials.tier_at(y)].node
end

-- The `level` group / required pickaxe `maxlevel` of a tier, 0..5.
-- Clamped, for the same reason tier_at is: callers derive tiers by
-- arithmetic (tier + 1 for "one tier above") and must not get nil back.
function grug_materials.level_for_tier(tier)
	if tier < 1 then
		tier = 1
	elseif tier > TIER_COUNT then
		tier = TIER_COUNT
	end
	return TIERS[tier].level
end

--
-- The five new stratum nodes
--
-- Tint only -- `default_stone.png` recolored by an engine texture modifier,
-- so the mod ships no media of its own (see LICENSE-media.md). The colors go
-- cool-grey -> near-black -> rust -> ember -> void as you descend, so a
-- player reads their depth off the wall.
local STRATUM_COLORS = {
	slate         = "#4a5a6e:70",
	basalt        = "#2a2a2e:90",
	granite       = "#8a5a52:60",
	emberrock     = "#7a2a10:90",
	abyssal_rock  = "#241830:150",
}

local STRATUM_NAMES = {
	slate        = "Slate",
	basalt       = "Basalt",
	granite      = "Granite",
	emberrock    = "Emberrock",
	abyssal_rock = "Abyssal Rock",
}

for i = 2, TIER_COUNT do
	local tier = TIERS[i]
	local name = tier.node:match("^grug_materials:(.+)$")

	core.register_node(tier.node, {
		description = STRATUM_NAMES[name],
		tiles = {"default_stone.png^[colorize:" .. STRATUM_COLORS[name]},

		-- `stone = 1` is deliberately NOT set. `default:furnace`'s recipe and
		-- default's whole stone-tool ladder take `group:stone`
		-- (mods/BASE/default/nodes.lua, crafting.lua), and a wall of abyssal
		-- rock must not be a furnace ingredient -- that would hand a T6
		-- material to a T1 recipe and make the deep strata a building
		-- shortcut. Players get their building stone from the drop below.
		--
		-- `cracky = 3` is identical on ALL six steps ON PURPOSE: the gate is
		-- the hard engine refusal via `level`, never a slower dig
		-- (items_crafting.md §3.0.4). A player either has the tool tier or
		-- the rock does not move at all; there is no grind in between.
		--
		-- `grug_stratum` is the dispatch group (AGENTS.md: groups, not name
		-- lists) -- WP25/T3 hangs the underground mob spawn whitelists off it,
		-- and anything else that needs "which layer am I in" can read it off
		-- the node instead of re-deriving it from y.
		groups = {cracky = 3, grug_stratum = i, level = tier.level},

		-- Binding, world.md §2 R6: the strata gate ACCESS, not building
		-- material. Every layer drops the same plain cobble the surface does,
		-- so nobody builds a status wall out of depth.
		drop = "default:cobble",

		is_ground_content = true,
		sounds = default.node_sound_stone_defaults(),

		-- No `_grug_sell_price`: cobble is what a player actually carries out,
		-- and the node itself is not a tradeable item.
	})
end

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/ores.lua")
dofile(modpath .. "/overrides.lua")

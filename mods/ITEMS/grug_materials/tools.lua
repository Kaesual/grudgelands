-- The four tool tiers `default` never had (WP13 round 2, items_crafting.md
-- §3.0.3 "default's tool ladder is replaced by the six-tier ladder").
--
-- WHAT WAS ALREADY TRUE, and is only written down here: `overrides.lua` gives
-- `default:pick_bronze` the group `grug_pick_tier = 1` and `default:pick_steel`
-- `grug_pick_tier = 3`, which is exactly §3.0.1's ladder -- T1 Bronze, T3
-- Steel. So the two vendored metal steps ARE the T1 and T3 rungs and nothing
-- about them changes; what was missing was T2, T4, T5 and T6.
--
-- IRON (T2) EXISTS AND THEREFORE GETS TOOLS. `grug_materials:iron_bar` is a
-- real registered item (registry.lua, TIERS[2].bar_item) -- it is what
-- upstream's "steel ingot" migrated to, because §3.0.1 reads a smelted iron
-- ore as Iron, not as Steel. With Iron a full material tier owning a depth
-- band (-101..-300) and a pick tier of its own in `PICK_PROFILES`, a ladder
-- that jumps Bronze -> Steel would leave §3.0.4's T2 row without a pick at
-- all. So T2 tools are registered here like the other three.
--
-- NAMESPACE. The four new tiers are `grug_materials:` and the two old ones
-- stay `default:`. That split is deliberate rather than pretty: registering
-- into a foreign mod's namespace needs the `:` escape hatch, and re-registering
-- Bronze and Steel here would either duplicate two live items or force this
-- lane to re-author their shipped, WP25-calibrated capabilities. WP29 owns the
-- final unified catalog; until then `grug_pick_tier` -- not the namespace -- is
-- what any consumer reads.
--
-- NO RECIPES, on purpose. `default:pick_steel` is already a non-craftable
-- verification tool (content_curation.lua) and no TOOL registered here has a
-- craft recipe (WP29 owns the tool catalog; the four new BARS do have their
-- smelting recipes since WP26 shipped `grug_smelting`). Handing the
-- deep picks a recipe here would move the progression gate, which is not this
-- lane's business; these registrations complete the LADDER, not the economy.
--
-- The capability numbers below are provisional in exactly the sense
-- `PICK_PROFILES` already is (items_crafting.md §3.0.4's "the numbers stay
-- open"): picks come straight out of that published profile table, and the axe
-- and shovel rows continue `default`'s own bronze -> steel steps monotonically.
-- WP22 calibrates, WP29 authors the final table.

local TIERS_WITH_TOOLS = {2, 4, 5, 6}

-- Continuations of default's axe/shovel ladder. Bronze and Steel are quoted
-- from `mods/BASE/default/tools.lua` in the comments so the steps are visible.
local AXE_PROFILES = {
	-- bronze (T1, default): choppy 2.75 / 1.70 / 1.15, uses 20
	[2] = {times = {[1] = 2.62, [2] = 1.55, [3] = 1.07}, uses = 24},
	-- steel (T3, default): choppy 2.50 / 1.40 / 1.00, uses 20
	[4] = {times = {[1] = 2.25, [2] = 1.25, [3] = 0.90}, uses = 32},
	[5] = {times = {[1] = 2.00, [2] = 1.10, [3] = 0.80}, uses = 40},
	[6] = {times = {[1] = 1.75, [2] = 0.95, [3] = 0.70}, uses = 48},
}

local SHOVEL_PROFILES = {
	-- bronze (T1, default): crumbly 1.65 / 1.05 / 0.45, uses 25
	[2] = {times = {[1] = 1.58, [2] = 0.98, [3] = 0.43}, uses = 28},
	-- steel (T3, default): crumbly 1.50 / 0.90 / 0.40, uses 30
	[4] = {times = {[1] = 1.35, [2] = 0.80, [3] = 0.36}, uses = 40},
	[5] = {times = {[1] = 1.20, [2] = 0.70, [3] = 0.32}, uses = 50},
	[6] = {times = {[1] = 1.05, [2] = 0.60, [3] = 0.28}, uses = 60},
}

-- One sprite per metal per family, in the single diagonal convention the wield
-- transform is derived for (grip bottom-left). Generated, with the licence
-- trail, by `tools/wp13/gen_weapon_ladder.py`.
local function texture(tier_key, family)
	return "grug_materials_tool_" .. tier_key .. family .. ".png"
end

for _, id in ipairs(TIERS_WITH_TOOLS) do
	local tier = grug_materials.TIERS[id]

	core.register_tool("grug_materials:pick_" .. tier.key, {
		description = tier.name .. " Pickaxe",
		inventory_image = texture(tier.key, "pick"),
		tool_capabilities = grug_materials.build_pick_capabilities(id),
		sound = {breaks = "default_tool_breaks"},
		groups = {pickaxe = 1, grug_pick_tier = id},
	})

	local axe = AXE_PROFILES[id]
	core.register_tool("grug_materials:axe_" .. tier.key, {
		description = tier.name .. " Woodcutting Axe",
		inventory_image = texture(tier.key, "axe"),
		tool_capabilities = {
			full_punch_interval = 1.0,
			max_drop_level = 1,
			groupcaps = {
				choppy = {times = axe.times, uses = axe.uses, maxlevel = 2},
			},
			damage_groups = {fleshy = 4},
		},
		sound = {breaks = "default_tool_breaks"},
		groups = {axe = 1},
	})

	local shovel = SHOVEL_PROFILES[id]
	core.register_tool("grug_materials:shovel_" .. tier.key, {
		description = tier.name .. " Shovel",
		inventory_image = texture(tier.key, "shovel"),
		-- Deliberately NO `wield_image`: default's shovels carry a
		-- `^[transformR90` one, which would hold this shovel at a different
		-- angle from every other item in the game. `overrides.lua` strips it
		-- from theirs for the same reason.
		tool_capabilities = {
			full_punch_interval = 1.1,
			max_drop_level = 1,
			groupcaps = {
				crumbly = {times = shovel.times, uses = shovel.uses,
					maxlevel = 2},
			},
			damage_groups = {fleshy = 3},
		},
		sound = {breaks = "default_tool_breaks"},
		groups = {shovel = 1},
	})
end

core.log("action", "[grug_materials] " .. (#TIERS_WITH_TOOLS * 3) ..
	" tools completing the six-tier pick/axe/shovel ladder")

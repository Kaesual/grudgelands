-- The pick/axe/shovel catalog: every grade under `grug_materials:`.
--
-- ONE NAMESPACE (Round 26 ruling 14). Wood, Stone, Bronze and Steel come from
-- the vendored `default` mod; Iron, Silversteel, Embersteel and Abyssal Steel
-- are registered here. The four vendored grades are cloned into this
-- namespace unchanged (the clone pattern `derivatives.lua` uses) BEFORE
-- `overrides.lua` gives them their tier groups and capabilities, so every
-- later pass -- overrides, lifetimes, tooltips, recipes, prices, quests --
-- names only the canonical `grug_materials:<family>_<grade>` item.
--
-- The old `default:` names become engine aliases: the ruling keeps them so a
-- stray reference never turns into an unknown item. This is not a saved-world
-- migration (the fresh-server rule still holds) and nothing in the repo uses
-- the old names. Aliases are absent from `pairs(core.registered_items)`, so
-- consumers that iterate registrations see exactly the canonical tools.
--
-- `grug_pick_tier`, `grug_axe_tier` and `grug_shovel_tier` remain the contract
-- consumers read; the namespace carries no rule. Metal tool recipes belong to
-- `grug_professions/base_recipes.lua`; the Wood and Stone recipes and the
-- wooden fuel values are re-registered here with default's own shapes.

grug_materials.TOOL_ALIASES = {}

local VENDORED_GRADES = {"wood", "stone", "bronze", "steel"}
local FAMILIES = {"pick", "axe", "shovel"}

for _, family in ipairs(FAMILIES) do
	for _, grade in ipairs(VENDORED_GRADES) do
		local old = "default:" .. family .. "_" .. grade
		local new = "grug_materials:" .. family .. "_" .. grade
		local source = rawget(core.registered_items, old)
		if not source then
			error("grug_materials: missing vendored tool " .. old)
		end
		local def = table.copy(source)
		def.name = nil
		def.type = nil
		def.mod_origin = nil
		core.clear_craft({output = old})
		if grade == "wood" then
			core.clear_craft({type = "fuel", recipe = old})
		end
		core.unregister_item(old)
		core.register_tool(new, def)
		core.register_alias(old, new)
		grug_materials.TOOL_ALIASES[old] = new
	end
end

-- default's own shapes (mods/BASE/default/tools.lua, `craft_ingreds` loop).
for _, row in ipairs({{"wood", "group:wood"}, {"stone", "group:stone"}}) do
	local grade, mat = row[1], row[2]
	core.register_craft({output = "grug_materials:pick_" .. grade, recipe = {
		{mat, mat, mat}, {"", "group:stick", ""}, {"", "group:stick", ""},
	}})
	core.register_craft({output = "grug_materials:shovel_" .. grade, recipe = {
		{mat}, {"group:stick"}, {"group:stick"},
	}})
	core.register_craft({output = "grug_materials:axe_" .. grade, recipe = {
		{mat, mat}, {mat, "group:stick"}, {"", "group:stick"},
	}})
end
for _, row in ipairs({{"pick", 6}, {"shovel", 4}, {"axe", 6}}) do
	core.register_craft({type = "fuel",
		recipe = "grug_materials:" .. row[1] .. "_wood", burntime = row[2]})
end

-- The four tiers `default` never had (WP13 round 2, items_crafting.md
-- §3.0.3). Iron (T2) is a full material tier with its own tier rock and pick
-- profile, so the ladder does not jump Bronze -> Steel. Picks take their
-- numbers from the published pick profiles (`PICK_PROFILES`); the axe and
-- shovel rows continue default's bronze -> steel steps monotonically.
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
		tool_capabilities = grug_materials.build_pick_capabilities(id, {
			loose_times = grug_materials.build_loose_times(
				SHOVEL_PROFILES[id].times),
			loose_maxlevel = 2,
		}),
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
		groups = {axe = 1, grug_axe_tier = id},
	})

	local shovel = SHOVEL_PROFILES[id]
	core.register_tool("grug_materials:shovel_" .. tier.key, {
		description = tier.name .. " Shovel",
		inventory_image = texture(tier.key, "shovel"),
		-- Deliberately NO `wield_image`: default's shovels carry a
		-- `^[transformR90` one, which would hold this shovel at a different
		-- angle from every other item in the game. `overrides.lua` strips it
		-- from the cloned vendored shovels for the same reason.
		tool_capabilities = {
			full_punch_interval = 1.1,
			max_drop_level = 1,
			groupcaps = {
				grug_loose = {times = shovel.times, uses = shovel.uses,
					maxlevel = 2},
			},
			damage_groups = {fleshy = 3},
		},
		sound = {breaks = "default_tool_breaks"},
		groups = {shovel = 1, grug_shovel_tier = id},
	})
end

core.log("action", "[grug_materials] " ..
	(#VENDORED_GRADES + #TIERS_WITH_TOOLS) * #FAMILIES ..
	" pick/axe/shovel tools, " .. #VENDORED_GRADES * #FAMILIES ..
	" default: tool aliases")

-- Current content curation for the standalone Grudgelands material vocabulary.
-- The vendored default and mobs mods load first. Canonical derivative nodes
-- have already copied the few source definitions they need when this file runs.

-- The Mese and Diamond tiers are retired material tiers (items_crafting.md
-- §3.0.1). The Bronze and Steel SWORDS join them for a different reason (WP13
-- round 2): §3.0.3's one-item-per-concept rule, now that `grug_gear` registers
-- the same two concepts as `grug_gear:sword_bronze` and `grug_gear:sword_steel`
-- on the one material ladder. Only the swords go -- the bronze and steel
-- PICK/AXE/SHOVEL are the ladder's own T1 and T3 rungs (see tools.lua), and
-- Wood and Stone remain only as gathering tools.
local REMOVED_TOOLS = {
	"default:pick_mese", "default:shovel_mese", "default:axe_mese",
	"default:sword_mese", "default:pick_diamond", "default:shovel_diamond",
	"default:axe_diamond", "default:sword_diamond",
	"default:sword_bronze", "default:sword_steel",
	"default:sword_wood", "default:sword_stone",
}

local REMOVED_PROCESSED = {
	"default:copper_ingot", "default:copperblock",
	"default:tin_ingot", "default:tinblock",
	"default:bronze_ingot", "default:bronzeblock",
	"default:steel_ingot", "default:steelblock",
	"default:gold_ingot", "default:goldblock",
}

local REMOVED_GEMS_AND_LIGHTS = {
	"default:stone_with_mese", "default:mese", "default:mese_crystal",
	"default:mese_crystal_fragment", "default:meselamp",
	"default:mese_post_light", "default:mese_post_light_acacia_wood",
	"default:mese_post_light_junglewood",
	"default:mese_post_light_pine_wood",
	"default:mese_post_light_aspen_wood", "default:stone_with_diamond",
	"default:diamond", "default:diamondblock",
}

grug_materials.CURATED_VENDOR_REMOVALS = {}
local function append_removals(items)
	for _, item_name in ipairs(items) do
		grug_materials.CURATED_VENDOR_REMOVALS[
			#grug_materials.CURATED_VENDOR_REMOVALS + 1] = item_name
	end
end
append_removals(REMOVED_TOOLS)
append_removals(REMOVED_PROCESSED)
append_removals(REMOVED_GEMS_AND_LIGHTS)
for _, derivative in ipairs(grug_materials.STORAGE_DERIVATIVES) do
	grug_materials.CURATED_VENDOR_REMOVALS[
		#grug_materials.CURATED_VENDOR_REMOVALS + 1] = derivative.source
end

-- Remove every recipe whose output is outside the current vocabulary. This
-- also removes recipes for the vendored shape definitions cloned above.
for _, item_name in ipairs(grug_materials.CURATED_VENDOR_REMOVALS) do
	core.clear_craft({output = item_name})
	core.clear_craft({type = "fuel", recipe = item_name})
end

-- The surviving Steel pick remains a non-craftable verification tool until
-- WP29 installs the final pick catalog.
core.clear_craft({output = "default:pick_steel"})

-- These mobs_redo items remain registered, but their vendored recipes use
-- material concepts that Grudgelands does not expose.
if core.get_modpath("mobs") then
	core.clear_craft({output = "mobs:lasso"})
	core.clear_craft({output = "mobs:protector2"})
end

local function register_tool_recipe(kind, material, ingredient)
	local output = "default:" .. kind .. "_" .. material
	core.clear_craft({output = output})
	local recipe
	if kind == "pick" then
		recipe = {
			{ingredient, ingredient, ingredient},
			{"", "group:stick", ""},
			{"", "group:stick", ""},
		}
	elseif kind == "shovel" then
		recipe = {{ingredient}, {"group:stick"}, {"group:stick"}}
	elseif kind == "axe" then
		recipe = {
			{ingredient, ingredient},
			{ingredient, "group:stick"},
			{"", "group:stick"},
		}
	else
		recipe = {{ingredient}, {ingredient}, {"group:stick"}}
	end
	core.register_craft({output = output, recipe = recipe})
end

-- WP29 owns the final catalog. Until then the surviving Bronze and historical
-- default Steel tool steps remain usable with the canonical Bronze and Iron
-- bars. The Steel pick is deliberately excluded by the gate above, and the two
-- swords are gone entirely (REMOVED_TOOLS) -- their recipes are cleared by the
-- removal loop above, so neither loop may name `sword` any more.
for _, kind in ipairs({"pick", "shovel", "axe"}) do
	register_tool_recipe(kind, "bronze", "grug_materials:bronze_bar")
end
for _, kind in ipairs({"shovel", "axe"}) do
	register_tool_recipe(kind, "steel", "grug_materials:iron_bar")
end

-- Preserve current utility recipes with explicit canonical material inputs.
core.clear_craft({output = "default:chest_locked"})
core.register_craft({
	output = "default:chest_locked",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", "grug_materials:iron_bar", "group:wood"},
		{"group:wood", "group:wood", "group:wood"},
	},
})
core.register_craft({
	type = "shapeless",
	output = "default:chest_locked",
	recipe = {"default:chest", "grug_materials:iron_bar"},
})

if core.get_modpath("mobs") then
	core.clear_craft({output = "mobs:shears"})
	core.register_craft({
		output = "mobs:shears",
		recipe = {
			{"", "grug_materials:iron_bar", ""},
			{"", "default:stick", "grug_materials:iron_bar"},
		},
	})
	core.clear_craft({output = "mobs:protector"})
	core.register_craft({
		output = "mobs:protector",
		recipe = {
			{"default:stone", "default:stone", "default:stone"},
			{"default:stone", "grug_materials:gold_block", "default:stone"},
			{"default:stone", "default:stone", "default:stone"},
		},
	})
	core.clear_craft({output = "mobs:saddle"})
	core.register_craft({
		output = "mobs:saddle",
		recipe = {
			{"group:leather", "group:leather", "group:leather"},
			{"group:leather", "grug_materials:iron_bar", "group:leather"},
			{"group:leather", "grug_materials:iron_bar", "group:leather"},
		},
	})
end

-- Unregistration is the fresh-server content boundary. No alias is installed:
-- removed names are unknown rather than alternate spellings of current items.
for _, item_name in ipairs(grug_materials.CURATED_VENDOR_REMOVALS) do
	if rawget(core.registered_items, item_name) then
		core.unregister_item(item_name)
	end
end

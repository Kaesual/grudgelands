-- One-way saved-world/ItemStack and recipe migration (WP43).

local LEGACY_TOOLS = {
	"default:pick_mese", "default:shovel_mese", "default:axe_mese",
	"default:sword_mese", "default:pick_diamond", "default:shovel_diamond",
	"default:axe_diamond", "default:sword_diamond",
}

-- A force alias removes an item registration, not its already registered
-- recipe. Remove the retired tool recipes first or they become extra Steel
-- recipes through alias resolution.
for _, item_name in ipairs(LEGACY_TOOLS) do
	core.clear_craft({output = item_name})
end

-- The surviving Steel pick is a saved-world/creative verification tool until
-- WP29 registers the final ladder. It must not be craftable from the Iron Bar
-- that legacy `default:steel_ingot` now resolves to.
core.clear_craft({output = "default:pick_steel"})

-- Do not let old pack/unpack or furnace recipes become undeclared canonical
-- material recipes through alias resolution. WP26 owns those recipes.
local legacy_processed_outputs = {
	"default:copper_ingot", "default:copperblock",
	"default:tin_ingot", "default:tinblock",
	"default:bronze_ingot", "default:bronzeblock",
	"default:steel_ingot", "default:steelblock",
	"default:gold_ingot", "default:goldblock",
}
for _, item_name in ipairs(legacy_processed_outputs) do
	core.clear_craft({output = item_name})
end

-- Rough regional gems cannot pack. WP10 owns the later Cut Diamond block
-- recipes, so remove both vendored rough-diamond conversions without adding a
-- replacement recipe here.
core.clear_craft({output = "default:diamondblock"})
core.clear_craft({output = "default:diamond"})

-- Remove the vendored Mese recipe vocabulary. WP10/WP26 own canonical gem,
-- storage and lighting recipes; aliases migrate saved stacks, not recipes.
local legacy_light_outputs = {
	"default:mese", "default:mese_crystal", "default:mese_crystal_fragment",
	"default:meselamp", "default:mese_post_light",
	"default:mese_post_light_acacia_wood",
	"default:mese_post_light_junglewood",
	"default:mese_post_light_pine_wood",
	"default:mese_post_light_aspen_wood",
}
for _, item_name in ipairs(legacy_light_outputs) do
	core.clear_craft({output = item_name})
end

-- mobs_redo consumes the retired ids in the Lasso and Level 2 Protection Rune
-- recipes. Do not silently turn rough Diamond or legacy storage into the new
-- canonical inputs; their replacement recipes belong to the crafting WPs.
if core.get_modpath("mobs") then
	core.clear_craft({output = "mobs:lasso"})
	core.clear_craft({output = "mobs:protector2"})
end

for source, target in pairs(grug_materials.LEGACY_ALIASES) do
	core.register_alias_force(source, target)
end

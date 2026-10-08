-- Current content curation for the standalone Grudgelands material vocabulary.
-- The vendored default and mobs mods load first. Canonical derivative nodes
-- have already copied the few source definitions they need when this file runs.

-- The Mese and Diamond tiers are retired material tiers (items_crafting.md
-- §3.0.1). The Bronze and Steel SWORDS join them for a different reason (WP13
-- round 2): §3.0.3's one-item-per-concept rule, now that `grug_gear` registers
-- the same two concepts as `grug_gear:sword_bronze` and `grug_gear:sword_steel`
-- on the one material ladder. Only the swords go -- the Wood, Stone, Bronze
-- and Steel PICK/AXE/SHOVEL live on as `grug_materials:` tools (tools.lua
-- moves them before this file runs).
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

-- Flint has no use in this game (Round 35, user): gravel drops only gravel
-- (below), and the item goes with the other curated removals.
local REMOVED_UNUSED = {"default:flint"}

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
append_removals(REMOVED_UNUSED)
core.override_item("default:gravel", {drop = "default:gravel"})
for _, derivative in ipairs(grug_materials.STORAGE_DERIVATIVES) do
	grug_materials.CURATED_VENDOR_REMOVALS[
		#grug_materials.CURATED_VENDOR_REMOVALS + 1] = derivative.source
end

-- Clears only what exists: `core.clear_craft` logs a warning for a recipe it
-- cannot find, and a fresh boot should not print one per curated name.
local function clear_output(item_name)
	if core.get_all_craft_recipes(item_name) then
		core.clear_craft({output = item_name})
	end
end
local function clear_fuel(item_name)
	local fuel = core.get_craft_result({method = "fuel", width = 1,
		items = {ItemStack(item_name)}})
	if fuel and fuel.time and fuel.time > 0 then
		core.clear_craft({type = "fuel", recipe = item_name})
	end
end

-- Remove every recipe whose output is outside the current vocabulary. This
-- also removes recipes for the vendored shape definitions cloned above.
for _, item_name in ipairs(grug_materials.CURATED_VENDOR_REMOVALS) do
	clear_output(item_name)
	clear_fuel(item_name)
end

-- Silver sand has no world source (audit D6, Round 26 ruling 13): the whole
-- silver-sandstone recipe family goes. The nodes stay -- authored capital and
-- road builds place them -- but no recipe makes, converts or reshapes them.
grug_materials.REMOVED_SILVER_SANDSTONE_OUTPUTS = {
	"default:silver_sand", "default:silver_sandstone",
	"default:silver_sandstone_brick", "default:silver_sandstone_block",
}
if core.get_modpath("stairs") then
	for _, base in ipairs({"silver_sandstone", "silver_sandstone_brick",
			"silver_sandstone_block"}) do
		for _, shape in ipairs({"slab_", "stair_", "stair_inner_", "stair_outer_"}) do
			local list = grug_materials.REMOVED_SILVER_SANDSTONE_OUTPUTS
			list[#list + 1] = "stairs:" .. shape .. base
		end
	end
end
for _, item_name in ipairs(grug_materials.REMOVED_SILVER_SANDSTONE_OUTPUTS) do
	clear_output(item_name)
end

-- The mobs_redo utility items (nametag, net, lasso, shears, both protection
-- runes, mob repellent, saddle; audit D5, Round 26 ruling 13) are not
-- registered at all: their definitions and recipes are removed in place
-- (`mods/ENTITIES/mobs/crafts.lua`, GRUG PATCH). audit.lua proves it.
grug_materials.REMOVED_MOBS_UTILITIES = {
	"mobs:nametag", "mobs:net", "mobs:lasso", "mobs:shears", "mobs:protector",
	"mobs:protector2", "mobs:mob_repellent", "mobs:saddle",
}

-- The locked chest takes the canonical Iron Bar: its two recipes are Basic
-- (grug_jobs/basic_recipes.lua) since Round 45, like every crafting-grid
-- route. The clears above still matter for the engine's cooking and fuel
-- recipes of removed items.

-- Unregistration is the fresh-server content boundary. No alias is installed:
-- removed names are unknown rather than alternate spellings of current items.
for _, item_name in ipairs(grug_materials.CURATED_VENDOR_REMOVALS) do
	if rawget(core.registered_items, item_name) then
		core.unregister_item(item_name)
	end
end

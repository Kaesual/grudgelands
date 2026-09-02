-- Material, depth and race-region registry (WP43).
--
-- This file is deliberately data-first. Mapgen and later crafting work may
-- consume it, but no consumer owns a second copy of a depth boundary,
-- canonical resource id or race-region material assignment.

grug_materials.TIERS = {
	{id = 1, key = "bronze", name = "Bronze", min_level = 1, max_level = 10,
		ilvl = 3, max_depth = -100, y_max = 31000, y_min = -100,
		node = "default:stone", bar_item = "grug_materials:bronze_bar",
		block_node = "grug_materials:bronze_block"},
	{id = 2, key = "iron", name = "Iron", min_level = 11, max_level = 20,
		ilvl = 10, max_depth = -300, y_max = -101, y_min = -300,
		node = "grug_materials:slate", bar_item = "grug_materials:iron_bar",
		block_node = "grug_materials:iron_block"},
	{id = 3, key = "steel", name = "Steel", min_level = 21, max_level = 30,
		ilvl = 20, max_depth = -500, y_max = -301, y_min = -500,
		node = "grug_materials:basalt", bar_item = "grug_materials:steel_bar",
		block_node = "grug_materials:steel_block"},
	{id = 4, key = "silversteel", name = "Silversteel", min_level = 31,
		max_level = 40, ilvl = 30, max_depth = -700, y_max = -501,
		y_min = -700, node = "grug_materials:granite",
		bar_item = "grug_materials:silversteel_bar",
		block_node = "grug_materials:silversteel_block"},
	{id = 5, key = "embersteel", name = "Embersteel", min_level = 41,
		max_level = 50, ilvl = 40, max_depth = -1000, y_max = -701,
		y_min = -1000, node = "grug_materials:emberrock",
		bar_item = "grug_materials:embersteel_bar",
		block_node = "grug_materials:embersteel_block"},
	{id = 6, key = "abyssal_steel", name = "Abyssal Steel", min_level = 51,
		max_level = 60, ilvl = 50, max_depth = -31000, y_max = -1001,
		y_min = -31000, node = "grug_materials:abyssal_rock",
		bar_item = "grug_materials:abyssal_steel_bar",
		block_node = "grug_materials:abyssal_steel_block"},
}

local TIERS = grug_materials.TIERS
local TIER_COUNT = #TIERS

grug_materials.TIER_BY_KEY = {}
for _, tier in ipairs(TIERS) do
	grug_materials.TIER_BY_KEY[tier.key] = tier
end

-- Tier of a world y, clamped to 1..6 even outside the map limits.
function grug_materials.tier_at(y)
	for i = 1, TIER_COUNT do
		if y >= TIERS[i].y_min then
			return i
		end
	end
	return TIER_COUNT
end

function grug_materials.stratum_node_for(y)
	return TIERS[grug_materials.tier_at(y)].node
end

-- Inclusive lowest natural y a pick tier may reach. The public helper clamps
-- so callers doing tier arithmetic cannot accidentally turn nil into access.
function grug_materials.max_depth_for_pick_tier(tier)
	tier = math.floor(tonumber(tier) or 1)
	if tier < 1 then
		tier = 1
	elseif tier > TIER_COUNT then
		tier = TIER_COUNT
	end
	return TIERS[tier].max_depth
end

-- Generated excavation/ground nodes owned by the current mapgen. The mining
-- transaction classifies by this explicit group contract, never by
-- `is_ground_content`: that engine field defaults to true even for nodes such
-- as saplings. Entries owned by default are normalized in overrides.lua;
-- grug_nodes consumes `natural_groups()` when it registers its own surfaces.
grug_materials.NATURAL_GROUND_NODES = {
	"default:stone",
	"default:dirt",
	"default:dirt_with_grass",
	"default:dirt_with_grass_footsteps",
	"default:dirt_with_dry_grass",
	"default:dirt_with_snow",
	"default:dirt_with_rainforest_litter",
	"default:dirt_with_coniferous_litter",
	"default:dry_dirt",
	"default:dry_dirt_with_dry_grass",
	"default:sand",
	"default:silver_sand",
	"default:gravel",
	"default:clay",
	"default:snow",
	"default:snowblock",
	"grug_nodes:blight_dirt",
	"grug_nodes:dirt_with_bone_litter",
	"grug_nodes:dirt_with_forest_litter",
	"grug_nodes:dirt_with_silver_litter",
	"grug_nodes:dirt_with_canopy_litter",
	"grug_nodes:mud",
	"grug_nodes:mesa_clay",
}

grug_materials.NATURAL_GROUND_SET = {}
for _, node_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
	grug_materials.NATURAL_GROUND_SET[node_name] = true
end

function grug_materials.natural_groups(groups)
	groups = table.copy(groups or {})
	groups.grug_natural = 1
	return groups
end

-- Natural resource taxonomy. `scope` distinguishes universal progression
-- inputs from the G1/G2 species selected by a race-region column.
grug_materials.RESOURCES = {
	{key = "coal", name = "Coal", natural_node = "default:stone_with_coal",
		raw_item = "default:coal_lump", harvest_tier = 1, scope = "universal"},
	{key = "copper", name = "Copper", natural_node = "default:stone_with_copper",
		raw_item = "default:copper_lump", harvest_tier = 1, scope = "universal"},
	{key = "tin", name = "Tin", natural_node = "default:stone_with_tin",
		raw_item = "default:tin_lump", harvest_tier = 1, scope = "universal"},
	{key = "iron", name = "Iron", natural_node = "default:stone_with_iron",
		raw_item = "default:iron_lump", harvest_tier = 1, scope = "universal"},
	{key = "quartz", name = "Quartz",
		natural_node = "grug_materials:stone_with_quartz",
		raw_item = "grug_materials:quartz", cut_item = "grug_materials:cut_quartz",
		harvest_tier = 1, scope = "universal"},
	{key = "gold", name = "Gold", natural_node = "default:stone_with_gold",
		raw_item = "default:gold_lump", harvest_tier = 2, scope = "universal"},
	{key = "citrine", name = "Citrine",
		natural_node = "grug_materials:stone_with_citrine",
		raw_item = "grug_materials:rough_citrine",
		cut_item = "grug_materials:cut_citrine",
		block_node = "grug_materials:citrine_block",
		harvest_tier = 2, scope = "regional", grade = "G1"},
	{key = "garnet", name = "Garnet",
		natural_node = "grug_materials:stone_with_garnet",
		raw_item = "grug_materials:rough_garnet",
		cut_item = "grug_materials:cut_garnet",
		block_node = "grug_materials:garnet_block",
		harvest_tier = 2, scope = "regional", grade = "G1"},
	{key = "jade", name = "Jade",
		natural_node = "grug_materials:stone_with_jade",
		raw_item = "grug_materials:rough_jade",
		cut_item = "grug_materials:cut_jade",
		block_node = "grug_materials:jade_block",
		harvest_tier = 2, scope = "regional", grade = "G1"},
	{key = "silver", name = "Silver",
		natural_node = "grug_materials:stone_with_silver",
		raw_item = "grug_materials:silver_lump", harvest_tier = 3,
		scope = "universal"},
	{key = "emberglass", name = "Emberglass",
		natural_node = "grug_materials:stone_with_emberglass",
		raw_item = "grug_materials:emberglass",
		block_node = "grug_materials:emberglass_block",
		harvest_tier = 4, scope = "universal"},
	{key = "diamond", name = "Diamond",
		natural_node = "grug_materials:stone_with_diamond",
		raw_item = "grug_materials:rough_diamond",
		cut_item = "grug_materials:cut_diamond",
		block_node = "grug_materials:diamond_block",
		harvest_tier = 4, scope = "regional", grade = "G2"},
	{key = "sapphire", name = "Sapphire",
		natural_node = "grug_materials:stone_with_sapphire",
		raw_item = "grug_materials:rough_sapphire",
		cut_item = "grug_materials:cut_sapphire",
		block_node = "grug_materials:sapphire_block",
		harvest_tier = 4, scope = "regional", grade = "G2"},
	{key = "ruby", name = "Ruby",
		natural_node = "grug_materials:stone_with_ruby",
		raw_item = "grug_materials:rough_ruby",
		cut_item = "grug_materials:cut_ruby",
		block_node = "grug_materials:ruby_block",
		harvest_tier = 4, scope = "regional", grade = "G2"},
	{key = "abyssal_crystal", name = "Abyssal Crystal",
		natural_node = "grug_materials:abyssal_crystal_ore",
		raw_item = "grug_materials:abyssal_crystal",
		block_node = "grug_materials:abyssal_crystal_block",
		harvest_tier = 5, scope = "universal"},
}

grug_materials.RESOURCE_BY_KEY = {}
grug_materials.RESOURCE_BY_NODE = {}
for _, resource in ipairs(grug_materials.RESOURCES) do
	grug_materials.RESOURCE_BY_KEY[resource.key] = resource
	grug_materials.RESOURCE_BY_NODE[resource.natural_node] = resource
end

function grug_materials.resource(key)
	return grug_materials.RESOURCE_BY_KEY[key]
end

function grug_materials.resource_for_node(node_name)
	return grug_materials.RESOURCE_BY_NODE[node_name]
end

function grug_materials.resource_node(key)
	local resource = grug_materials.RESOURCE_BY_KEY[key]
	return resource and resource.natural_node or nil
end

-- Universal processed forms. Recipes are deliberately not part of this
-- registry: WP26 owns smelting/alloying and WP10 owns cut-gem storage. `item`
-- is the nine-unit storage input; bars also publish the more specific
-- `bar_item` field consumed by tier/equipment code.
grug_materials.PROCESSED_MATERIALS = {
	{key = "copper", name = "Copper", kind = "bar",
		item = "grug_materials:copper_bar", bar_item = "grug_materials:copper_bar",
		block_node = "grug_materials:copper_block"},
	{key = "tin", name = "Tin", kind = "bar",
		item = "grug_materials:tin_bar", bar_item = "grug_materials:tin_bar",
		block_node = "grug_materials:tin_block"},
	{key = "bronze", name = "Bronze", kind = "bar", tier = 1,
		item = "grug_materials:bronze_bar", bar_item = "grug_materials:bronze_bar",
		block_node = "grug_materials:bronze_block"},
	{key = "iron", name = "Iron", kind = "bar", tier = 2,
		item = "grug_materials:iron_bar", bar_item = "grug_materials:iron_bar",
		block_node = "grug_materials:iron_block", sell_price = 3},
	{key = "steel", name = "Steel", kind = "bar", tier = 3,
		item = "grug_materials:steel_bar", bar_item = "grug_materials:steel_bar",
		block_node = "grug_materials:steel_block"},
	{key = "silver", name = "Silver", kind = "bar",
		item = "grug_materials:silver_bar", bar_item = "grug_materials:silver_bar",
		block_node = "grug_materials:silver_block"},
	{key = "silversteel", name = "Silversteel", kind = "bar", tier = 4,
		item = "grug_materials:silversteel_bar",
		bar_item = "grug_materials:silversteel_bar",
		block_node = "grug_materials:silversteel_block"},
	{key = "emberglass", name = "Emberglass", kind = "resource",
		item = "grug_materials:emberglass",
		block_node = "grug_materials:emberglass_block"},
	{key = "embersteel", name = "Embersteel", kind = "bar", tier = 5,
		item = "grug_materials:embersteel_bar",
		bar_item = "grug_materials:embersteel_bar",
		block_node = "grug_materials:embersteel_block"},
	{key = "abyssal_crystal", name = "Abyssal Crystal", kind = "resource",
		item = "grug_materials:abyssal_crystal",
		block_node = "grug_materials:abyssal_crystal_block"},
	{key = "abyssal_steel", name = "Abyssal Steel", kind = "bar", tier = 6,
		item = "grug_materials:abyssal_steel_bar",
		bar_item = "grug_materials:abyssal_steel_bar",
		block_node = "grug_materials:abyssal_steel_block"},
	{key = "gold", name = "Gold", kind = "bar",
		item = "grug_materials:gold_bar", bar_item = "grug_materials:gold_bar",
		block_node = "grug_materials:gold_block"},
}

grug_materials.PROCESSED_BY_KEY = {}
for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
	grug_materials.PROCESSED_BY_KEY[material.key] = material
end

function grug_materials.processed(key)
	return grug_materials.PROCESSED_BY_KEY[key]
end

grug_materials.GEM_GRADES = {
	G1 = {"citrine", "garnet", "jade"},
	G2 = {"diamond", "sapphire", "ruby"},
}

grug_materials.CULTURAL_MATERIALS = {
	sunwax = {race = "human", key = "sunwax", name = "Sunwax", item = "grug_materials:sunwax",
		source = "wild waxcomb or apiary cache"},
	runeslate = {race = "dwarf", key = "runeslate", name = "Runeslate", item = "grug_materials:runeslate",
		source = "slate inscription seam"},
	moonresin = {race = "elf", key = "moonresin", name = "Moonresin", item = "grug_materials:moonresin",
		source = "resin root or fossil-resin nodule"},
	red_ochre = {race = "orc", key = "red_ochre", name = "Red Ochre", item = "grug_materials:red_ochre",
		source = "ochre clay or outcrop deposit"},
	spirit_resin = {race = "troll", key = "spirit_resin", name = "Spirit Resin",
		item = "grug_materials:spirit_resin",
		source = "resinous root or amber nodule"},
	gravesalt = {race = "undead", key = "gravesalt", name = "Gravesalt",
		item = "grug_materials:gravesalt", source = "salt crust or crystal seam"},
}

-- Existing wood registrations remain owned by default/grug_trees. These ids
-- are the material-side mapping WP40 consumes with the race-region row.
grug_materials.SIGNATURE_WOODS = {
	oak = {race = "human", name = "Oak", tree = "default:tree", wood = "default:wood"},
	mountain_pine = {race = "dwarf", name = "Mountain Pine", tree = "default:pine_tree",
		wood = "default:pine_wood"},
	silverwood = {race = "elf", name = "Silverwood", tree = "grug_trees:silverwood_tree",
		wood = "grug_trees:silverwood_wood"},
	spikethorn_acacia = {race = "orc", name = "Spikethorn Acacia", tree = "default:acacia_tree",
		wood = "default:acacia_wood"},
	kapok = {race = "troll", name = "Kapok", tree = "default:jungletree",
		wood = "default:junglewood"},
	gravewood = {race = "undead", name = "Gravewood", tree = "grug_trees:gravewood_tree",
		wood = "grug_trees:gravewood_wood"},
}

grug_materials.RACE_REGIONS = {
	human = {race = "human", faction = "accord", g1 = "citrine", g2 = "diamond",
		cultural = "sunwax", signature_wood = "oak"},
	dwarf = {race = "dwarf", faction = "accord", g1 = "garnet", g2 = "sapphire",
		cultural = "runeslate", signature_wood = "mountain_pine"},
	elf = {race = "elf", faction = "accord", g1 = "jade", g2 = "sapphire",
		cultural = "moonresin", signature_wood = "silverwood"},
	orc = {race = "orc", faction = "throng", g1 = "garnet", g2 = "diamond",
		cultural = "red_ochre", signature_wood = "spikethorn_acacia"},
	troll = {race = "troll", faction = "throng", g1 = "jade", g2 = "ruby",
		cultural = "spirit_resin", signature_wood = "kapok"},
	undead = {race = "undead", faction = "throng", g1 = "citrine", g2 = "ruby",
		cultural = "gravesalt", signature_wood = "gravewood"},
}

grug_materials.DENSITY = {
	g1 = {
		shape = "sparse_upper_rises_through_t4_flat_t5_t6",
		deep_multiplier = true,
	},
	g2 = {
		harvest_tier = 4,
		host_nodes_per_ore = {[4] = 12000, [5] = 6000, [6] = 3000},
	},
	abyssal_crystal = {
		first_tier = 5,
		host_nodes_per_ore = 2048,
	},
	deep_bands = {
		{y_max = -1500, y_min = -1999, multiplier = 1.25},
		{y_max = -2000, y_min = -31000, multiplier = 1.50},
	},
}

-- This is the shipped R4 respawn roster. WP40 R7 owns natural geometry;
-- this list exists so runtime consumers do not maintain a second ore-name
-- inventory. The name is retained for compatibility until WP34 revises the
-- respawn policy; it no longer describes an engine scatter registration.
grug_materials.CURRENT_SCATTER_RESOURCES = {
	"coal", "tin", "copper", "iron", "gold", "emberglass", "diamond",
	"quartz", "silver", "garnet",
}

-- Saved node/ItemStack migration. Sources are never player-facing parallel
-- items. Targets are concrete registrations, not aliases, so the graph is
-- one-way and one hop.
grug_materials.LEGACY_ALIASES = {
	["mese"] = "grug_materials:emberglass_block",
	["MesePick"] = "default:pick_steel",
	["default:mese_block"] = "grug_materials:emberglass_block",
	["default:stone_with_mese"] = "grug_materials:stone_with_emberglass",
	["default:mese_crystal"] = "grug_materials:emberglass",
	["default:mese_crystal_fragment"] = "grug_materials:emberglass_shard",
	["default:mese"] = "grug_materials:emberglass_block",
	["default:meselamp"] = "grug_materials:emberglass_lamp",
	["default:mese_post_light"] = "grug_materials:emberglass_post_light",
	["default:mese_post_light_acacia_wood"] =
		"grug_materials:emberglass_post_light_acacia_wood",
	["default:mese_post_light_junglewood"] =
		"grug_materials:emberglass_post_light_junglewood",
	["default:mese_post_light_pine_wood"] =
		"grug_materials:emberglass_post_light_pine_wood",
	["default:mese_post_light_aspen_wood"] =
		"grug_materials:emberglass_post_light_aspen_wood",
	["default:stone_with_diamond"] = "grug_materials:stone_with_diamond",
	["default:diamond"] = "grug_materials:rough_diamond",
	["default:diamondblock"] = "grug_materials:diamond_block",
	["steel_ingot"] = "grug_materials:iron_bar",
	["steelblock"] = "grug_materials:iron_block",
	["default:copper_ingot"] = "grug_materials:copper_bar",
	["default:copperblock"] = "grug_materials:copper_block",
	["default:tin_ingot"] = "grug_materials:tin_bar",
	["default:tinblock"] = "grug_materials:tin_block",
	["default:bronze_ingot"] = "grug_materials:bronze_bar",
	["default:bronzeblock"] = "grug_materials:bronze_block",
	["default:steel_ingot"] = "grug_materials:iron_bar",
	["default:steelblock"] = "grug_materials:iron_block",
	["default:gold_ingot"] = "grug_materials:gold_bar",
	["default:goldblock"] = "grug_materials:gold_block",
	["default:pick_mese"] = "default:pick_steel",
	["default:shovel_mese"] = "default:shovel_steel",
	["default:axe_mese"] = "default:axe_steel",
	["default:sword_mese"] = "default:sword_steel",
	["default:pick_diamond"] = "default:pick_steel",
	["default:shovel_diamond"] = "default:shovel_steel",
	["default:axe_diamond"] = "default:axe_steel",
	["default:sword_diamond"] = "default:sword_steel",
	["grug_materials:stone_with_emberstone"] =
		"grug_materials:stone_with_emberglass",
	["grug_materials:emberstone"] = "grug_materials:emberglass",
	["grug_materials:emberstone_crystal"] = "grug_materials:emberglass",
	["grug_materials:emberstone_shard"] = "grug_materials:emberglass_shard",
	["grug_materials:emberstone_block"] = "grug_materials:emberglass_block",
	["grug_materials:quartz_crystal"] = "grug_materials:quartz",
	["grug_materials:garnet_crystal"] = "grug_materials:rough_garnet",
}

-- Existing non-material objects whose recipes consumed default's historical
-- "Steel" ingot. That item now migrates to the canonical Iron Bar, so the
-- visible object names must migrate with it instead of claiming to be Steel.
grug_materials.STORAGE_DERIVATIVES = {
	{source = "default:sign_wall_steel",
		target = "grug_materials:iron_sign_wall", description = "Iron Sign"},
	{source = "default:ladder_steel",
		target = "grug_materials:iron_ladder", description = "Iron Ladder"},
}

if core.get_modpath("stairs") then
	local derivative_materials = {
		{legacy = "steelblock", canonical = "iron_block", name = "Iron"},
		{legacy = "tinblock", canonical = "tin_block", name = "Tin"},
		{legacy = "copperblock", canonical = "copper_block", name = "Copper"},
		{legacy = "bronzeblock", canonical = "bronze_block", name = "Bronze"},
		{legacy = "goldblock", canonical = "gold_block", name = "Gold"},
	}
	local derivative_shapes = {
		{legacy = "stair_", canonical = "stair_", label = "Block Stair"},
		{legacy = "stair_inner_", canonical = "stair_inner_",
			label = "Inner Block Stair"},
		{legacy = "stair_outer_", canonical = "stair_outer_",
			label = "Outer Block Stair"},
		{legacy = "slab_", canonical = "slab_", label = "Block Slab"},
	}
	for _, material in ipairs(derivative_materials) do
		for _, shape in ipairs(derivative_shapes) do
			grug_materials.STORAGE_DERIVATIVES[
				#grug_materials.STORAGE_DERIVATIVES + 1] = {
				source = "stairs:" .. shape.legacy .. material.legacy,
				target = "grug_materials:" .. shape.canonical .. material.canonical,
				description = material.name .. " " .. shape.label,
			}
		end
	end
end

for _, derivative in ipairs(grug_materials.STORAGE_DERIVATIVES) do
	grug_materials.LEGACY_ALIASES[derivative.source] = derivative.target
end

-- No Grudgesteel runtime id ever shipped. Publishing the forbidden stems
-- prevents WP40/WP29 from accidentally creating migration sources as new
-- content while keeping the actual alias table target-resolvable today.
grug_materials.FORBIDDEN_RUNTIME_STEMS = {"emberstone", "grudgesteel"}

function grug_materials.canonical_name(item_name)
	return grug_materials.LEGACY_ALIASES[item_name] or item_name
end

local function registry_error(message)
	error("grug_materials registry: " .. message)
end

local function validate_registry()
	if TIER_COUNT ~= 6 then
		registry_error("expected exactly six tiers, got " .. TIER_COUNT)
	end
	local tier_keys, tier_nodes, tier_bars, tier_blocks = {}, {}, {}, {}
	for i, tier in ipairs(TIERS) do
		if tier.id ~= i or tier_keys[tier.key] or tier_nodes[tier.node] or
				tier_bars[tier.bar_item] or tier_blocks[tier.block_node] then
			registry_error("duplicate or non-contiguous tier at index " .. i)
		end
		if tier.max_depth ~= tier.y_min then
			registry_error("tier " .. tier.key .. " max_depth must equal y_min")
		end
		if i > 1 and tier.y_max ~= TIERS[i - 1].y_min - 1 then
			registry_error("gap or overlap above tier " .. tier.key)
		end
		tier_keys[tier.key], tier_nodes[tier.node] = true, true
		tier_bars[tier.bar_item], tier_blocks[tier.block_node] = true, true
	end
	local natural_nodes = {}
	for _, node_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
		if natural_nodes[node_name] or not grug_materials.NATURAL_GROUND_SET[node_name] then
			registry_error("duplicate or unindexed natural ground " .. node_name)
		end
		natural_nodes[node_name] = true
	end

	local resource_keys, nodes, items = {}, {}, {}
	for _, resource in ipairs(grug_materials.RESOURCES) do
		if resource_keys[resource.key] or nodes[resource.natural_node] or
				items[resource.raw_item] then
			registry_error("duplicate resource key/node/item at " .. resource.key)
		end
		if resource.harvest_tier < 1 or resource.harvest_tier > 5 then
			registry_error("invalid harvest tier for " .. resource.key)
		end
		resource_keys[resource.key] = true
		nodes[resource.natural_node] = true
		items[resource.raw_item] = true
	end

	local processed_keys, processed_items, processed_blocks = {}, {}, {}
	for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
		if processed_keys[material.key] or processed_items[material.item] or
				processed_blocks[material.block_node] then
			registry_error("duplicate processed material " .. material.key)
		end
		if material.item:match("^grug_materials:") == nil or
				material.block_node:match("^grug_materials:") == nil then
			registry_error("non-canonical processed id for " .. material.key)
		end
		if material.kind == "bar" and material.bar_item ~= material.item then
			registry_error("invalid bar id for " .. material.key)
		elseif material.kind ~= "bar" and material.kind ~= "resource" then
			registry_error("invalid processed kind for " .. material.key)
		end
		processed_keys[material.key] = true
		processed_items[material.item] = true
		processed_blocks[material.block_node] = true
	end
	if #grug_materials.PROCESSED_MATERIALS ~= 12 then
		registry_error("expected twelve processed material rows")
	end
	for _, tier in ipairs(TIERS) do
		local material = grug_materials.PROCESSED_BY_KEY[tier.key]
		if not material or material.tier ~= tier.id or
				material.bar_item ~= tier.bar_item or
				material.block_node ~= tier.block_node then
			registry_error("tier processed forms disagree for " .. tier.key)
		end
	end
	for _, key in ipairs({"emberglass", "abyssal_crystal"}) do
		local resource = grug_materials.RESOURCE_BY_KEY[key]
		local material = grug_materials.PROCESSED_BY_KEY[key]
		if not resource or not material or resource.raw_item ~= material.item or
				resource.block_node ~= material.block_node then
			registry_error("resource storage form disagrees for " .. key)
		end
	end

	for grade, keys in pairs(grug_materials.GEM_GRADES) do
		for _, key in ipairs(keys) do
			local resource = grug_materials.RESOURCE_BY_KEY[key]
			if not resource or resource.grade ~= grade or resource.scope ~= "regional" then
				registry_error("invalid " .. grade .. " member " .. key)
			end
		end
	end

	local race_count = 0
	for race, row in pairs(grug_materials.RACE_REGIONS) do
		race_count = race_count + 1
		local g1 = grug_materials.RESOURCE_BY_KEY[row.g1]
		local g2 = grug_materials.RESOURCE_BY_KEY[row.g2]
		local cultural = grug_materials.CULTURAL_MATERIALS[row.cultural]
		local wood = grug_materials.SIGNATURE_WOODS[row.signature_wood]
		if row.race ~= race or not g1 or g1.grade ~= "G1" or not g2 or
				g2.grade ~= "G2" or not cultural or cultural.race ~= race or
				not wood or wood.race ~= race then
			registry_error("incomplete race-region row " .. race)
		end
	end
	if race_count ~= 6 then
		registry_error("expected six race-region rows, got " .. race_count)
	end

	for _, key in ipairs(grug_materials.CURRENT_SCATTER_RESOURCES) do
		if not grug_materials.RESOURCE_BY_KEY[key] then
			registry_error("unknown current scatter resource " .. key)
		end
	end
	for source, target in pairs(grug_materials.LEGACY_ALIASES) do
		if source == target or grug_materials.LEGACY_ALIASES[target] then
			registry_error("alias must be a one-hop edge: " .. source .. " -> " .. target)
		end
	end
	local derivative_sources, derivative_targets = {}, {}
	for _, derivative in ipairs(grug_materials.STORAGE_DERIVATIVES) do
		if derivative_sources[derivative.source] or
				derivative_targets[derivative.target] or
				derivative.target:match("^grug_materials:") == nil or
				grug_materials.LEGACY_ALIASES[derivative.source] ~= derivative.target then
			registry_error("invalid storage derivative " .. derivative.source)
		end
		derivative_sources[derivative.source] = true
		derivative_targets[derivative.target] = true
	end
end

validate_registry()

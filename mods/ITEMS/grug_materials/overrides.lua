-- Wrapper normalization for vendored default/stairs registrations (WP43).
-- core.override_item replaces whole fields, so every group edit starts from a
-- copy of the live definition and preserves unrelated upstream groups.

local function edit_groups(item_name, edit)
	local def = core.registered_items[item_name]
	if not def then
		error("grug_materials: cannot normalize missing item " .. item_name)
	end
	local groups = table.copy(def.groups or {})
	edit(groups)
	core.override_item(item_name, {groups = groups})
end

local function natural_resource(item_name, tier)
	local resource = grug_materials.resource_for_node(item_name)
	if not resource then
		error("grug_materials: missing resource registry row for " .. item_name)
	end
	edit_groups(item_name, function(groups)
		groups.level = nil
		groups.cracky = nil
		groups.grug_natural = 1
		groups.grug_resource = tier
	end)
	core.override_item(item_name, {
		description = grug_materials.resource_ore_description(resource),
	})
end

natural_resource("default:stone_with_coal", 1)
natural_resource("default:stone_with_copper", 1)
natural_resource("default:stone_with_tin", 1)
natural_resource("default:stone_with_iron", 1)
natural_resource("default:stone_with_gold", 2)

edit_groups("default:stone", function(groups)
	groups.level = nil
	groups.grug_natural = 1
	groups.grug_stratum = 1
end)

-- Explicit generated-ground taxonomy. `is_ground_content` is not a safe
-- predicate because the engine's node-definition default is true (including
-- saplings and many decorations). Only the owner list above receives the
-- natural marker.
for _, item_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
	if item_name:match("^default:") and item_name ~= "default:stone" then
		edit_groups(item_name, function(groups)
			groups.grug_natural = 1
		end)
	end
end

-- Exact loose-material membership. Do not derive this from `crumbly`: solid
-- sandstone, clay and snow share that upstream group but are not shovel soil.
local loose_nodes = {
	"default:dirt", "default:dirt_with_grass",
	"default:dirt_with_grass_footsteps", "default:dirt_with_dry_grass",
	"default:dirt_with_snow", "default:dirt_with_rainforest_litter",
	"default:dirt_with_coniferous_litter", "default:dry_dirt",
	"default:dry_dirt_with_dry_grass", "default:sand",
	"default:desert_sand", "default:silver_sand", "default:gravel",
}
for _, item_name in ipairs(loose_nodes) do
	edit_groups(item_name, function(groups)
		groups.grug_loose = groups.crumbly
	end)
end

local normalized_blocks = {
	"default:obsidian", "default:obsidianbrick", "default:obsidian_block",
	"default:steelblock", "default:copperblock", "default:tinblock",
	"default:bronzeblock",
}
for _, item_name in ipairs(normalized_blocks) do
	edit_groups(item_name, function(groups)
		groups.level = nil
	end)
end

local function pick_groups(item_name, tier)
	edit_groups(item_name, function(groups)
		groups.grug_pick_tier = tier
	end)
end

local function current_pick_values(item_name, values)
	local def = core.registered_items[item_name]
	local caps = def and def.tool_capabilities or {}
	values = values or {}
	values.punch_attack_uses = caps.punch_attack_uses
	return values
end

local function current_shovel_values(item_name)
	local def = core.registered_items[item_name]
	local caps = assert(def and def.tool_capabilities,
		"missing shovel capabilities for " .. item_name)
	local crumbly = assert(caps.groupcaps and caps.groupcaps.crumbly,
		"missing shovel crumbly capability for " .. item_name)
	return {
		full_punch_interval = caps.full_punch_interval,
		max_drop_level = caps.max_drop_level,
		punch_attack_uses = caps.punch_attack_uses,
		groupcaps = {
			grug_loose = {times = table.copy(crumbly.times),
				uses = crumbly.uses, maxlevel = crumbly.maxlevel},
		},
		damage_groups = table.copy(caps.damage_groups or {}),
	}
end

local starter_shovels = {
	{"default:shovel_wood", 1}, {"default:shovel_stone", 1},
	{"default:shovel_bronze", 1}, {"default:shovel_steel", 3},
}
local starter_shovel_times = {}
for _, row in ipairs(starter_shovels) do
	local values = current_shovel_values(row[1])
	starter_shovel_times[row[1]] = values.groupcaps.grug_loose.times
	edit_groups(row[1], function(groups)
		groups.grug_shovel_tier = row[2]
	end)
	core.override_item(row[1], {tool_capabilities = values})
end

-- Preserve WP25's effective ordinary-rock values while retiring maxlevel as
-- an authority. The three starter picks deliberately share T1 depth access;
-- their differing speeds and uses remain their ordinary equipment quality.
pick_groups("default:pick_wood", 1)
core.override_item("default:pick_wood", {
	tool_capabilities = grug_materials.build_pick_capabilities(1, {
		ordinary_time = 1.60, uses = 30, full_punch_interval = 1.2,
		cracky_times = {[3] = 1.60}, damage_groups = {fleshy = 2},
		loose_times = grug_materials.build_loose_times(
			starter_shovel_times["default:shovel_wood"]),
		loose_maxlevel = 1,
		punch_attack_uses = current_pick_values("default:pick_wood").punch_attack_uses,
	}),
})

pick_groups("default:pick_stone", 1)
core.override_item("default:pick_stone", {
	tool_capabilities = grug_materials.build_pick_capabilities(1, {
		ordinary_time = 1.00, uses = 60, full_punch_interval = 1.3,
		cracky_times = {[2] = 2.0, [3] = 1.00}, damage_groups = {fleshy = 3},
		loose_times = grug_materials.build_loose_times(
			starter_shovel_times["default:shovel_stone"]),
		loose_maxlevel = 1,
		punch_attack_uses = current_pick_values("default:pick_stone").punch_attack_uses,
	}),
})

pick_groups("default:pick_bronze", 1)
core.override_item("default:pick_bronze", {
	tool_capabilities = grug_materials.build_pick_capabilities(1, current_pick_values(
		"default:pick_bronze", {
		max_drop_level = 1,
		loose_times = grug_materials.build_loose_times(
			starter_shovel_times["default:shovel_bronze"]),
		loose_maxlevel = 2,
	})),
})

pick_groups("default:pick_steel", 3)
core.override_item("default:pick_steel", {
	tool_capabilities = grug_materials.build_pick_capabilities(3, current_pick_values(
		"default:pick_steel", {
		max_drop_level = 1,
		loose_times = grug_materials.build_loose_times(
			starter_shovel_times["default:shovel_steel"]),
		loose_maxlevel = 2,
	})),
})

-- ONE SPRITE CONVENTION FOR THE DIAGONAL TOOL LADDER (WP13 round 2). The
-- visible weapon/tool is an attached `wielditem` entity, and the engine builds
-- that extruded mesh from `wield_image` when an item declares one
-- (src/client/wieldmesh.cpp), falling back to the inventory image otherwise.
--
-- Plenty of vendored items declare a `wield_image` -- the torch, every sapling,
-- the doors, the xpanes, the grasses, the beds -- and none of those matters
-- here, because none of them is a diagonal tool sprite: `grug_visuals` holds
-- anything outside the `sword`/`axe`/`pickaxe`/`shovel`/`staff` families in its
-- own upright pose, which makes no assumption about the image at all.
--
-- default's four shovels are the exception, and the only one: they are IN the
-- tool ladder, so they are held by the grip pixel the diagonal convention puts
-- at (3.4, 12.6) -- and their `wield_image` is that same sprite turned
-- `^[transformR90`, which moves the grip out from under the fist and lays the
-- shovel across the hand at 90 degrees to every sword, axe and pick. Clearing
-- the key makes the engine fall back to the inventory image, which is in the
-- convention `grug_visuals/wield_geometry.lua` derives the hand from.
for _, shovel in ipairs({"default:shovel_wood", "default:shovel_stone",
		"default:shovel_bronze", "default:shovel_steel"}) do
	core.override_item(shovel, {wield_image = ""})
end

-- stairs is optional for a standalone grug_materials load, but ordered before
-- us when present through mod.conf. Normalize all four generated shapes.
if core.get_modpath("stairs") then
	local bases = {"obsidian", "obsidianbrick", "obsidian_block"}
	local shapes = {"stair_", "stair_inner_", "stair_outer_", "slab_"}
	for _, base in ipairs(bases) do
		for _, shape in ipairs(shapes) do
			edit_groups("stairs:" .. shape .. base, function(groups)
				groups.level = nil
			end)
		end
	end
end

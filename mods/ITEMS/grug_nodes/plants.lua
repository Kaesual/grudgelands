-- Round 51 lane LP: the land plants the user picked in the land viewer
-- (tools/r47_sw/land.js ITEMS, land plan §4; art ARTL, tools/r51_land/plants).
--
-- Every plant here is decoration. Since Round 70 (round70-plan.md §2.3, which
-- ends land plan ruling 11) each drops itself and can be placed where it
-- grows. The two reasons of the old rule stay answered: the tooltip says it
-- is decoration and no recipe uses it, so nobody takes one for a gathering
-- source, and a stack is worth 1c (group `grug_decor_plant`: tier 1, a bulk
-- good of grug_traders/prices.lua, economy.md §2), so nobody farms them.
-- None glows (ruling 10). The world generator places them as decoration rows
-- (wp40/r7_r6_manifest.lua, the Round 51 LP block) and the wild renewal
-- brings them back (grug_farming/renewal.lua through the vegetation
-- authority, ruling 18). The jungle's lianas are grug_trees' (they belong to
-- their trees); the water plants are grug_mapgen's (world_nodes.lua), placed
-- by the two functions below.

-- The tooltip of a carried plant: its name, the one decoration line and how
-- it is placed. grug_trees and grug_mapgen's world_nodes.lua write the same
-- line (tools/r70_plants checks all of them).
local function decor_description(description, how)
	return description .. "\nDecoration: no recipe uses it.\n" .. how
end

local ON_GROUND = "Plant it on the ground."
local AS_BLOCK = "Place it like a block."

-- Whether the player may change every position; a refusal reports itself.
local function may_change(placer, positions)
	local name = placer and placer:get_player_name() or ""
	for _, pos in ipairs(positions) do
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return false
		end
	end
	return true
end

local function spend(itemstack, placer)
	if not core.is_creative_enabled(placer and placer:get_player_name() or "") then
		itemstack:take_item()
	end
	return itemstack
end

local function water_source(pos)
	local name = core.get_node(pos).name
	local def = core.registered_nodes[name]
	return def ~= nil and def.liquidtype == "source" and core.get_item_group(name, "water") > 0
end

-- The waterlily's on_place: it stands in the air over the source water the
-- player points at (the item has liquids_pointable), turned at random as the
-- generator turns it.
function grug_nodes.place_waterlily(itemstack, placer, pointed)
	local clicked = grug_core.node_rightclick(itemstack, placer, pointed)
	if clicked then return clicked end
	if pointed.type ~= "node" then return itemstack end
	local water = pointed.under
	local pos = {x = water.x, y = water.y + 1, z = water.z}
	if not water_source(water) or core.get_node(pos).name ~= "air" or
			not may_change(placer, {pos}) then
		return itemstack
	end
	core.set_node(pos, {name = itemstack:get_name(), param2 = math.random(0, 3)})
	return spend(itemstack, placer)
end

-- A rooted water plant's on_place: the plant replaces the plain sand bed the
-- player points at, as the generator's does, so it needs that bed under
-- source water; digging it leaves the bed again. choose(depth) names the node
-- and its param2 for that many water nodes above the bed (counted up to
-- WATER_LOOKUP), or nil when the water is too shallow.
local WATER_LOOKUP = 5
function grug_nodes.place_rooted(itemstack, placer, pointed, choose)
	local clicked = grug_core.node_rightclick(itemstack, placer, pointed)
	if clicked then return clicked end
	if pointed.type ~= "node" then return itemstack end
	local bed = pointed.under
	if core.get_node(bed).name ~= "default:sand" then return itemstack end
	local depth = 0
	while depth < WATER_LOOKUP and
			water_source({x = bed.x, y = bed.y + depth + 1, z = bed.z}) do
		depth = depth + 1
	end
	local name, param2 = choose(depth)
	if not name then return itemstack end
	-- `leveled`: a rooted plant's param2 is its height in sixteenths.
	local top = {x = bed.x, y = bed.y + math.max(1, param2 / 16), z = bed.z}
	if not may_change(placer, {bed, top}) then return itemstack end
	core.set_node(bed, {name = name, param2 = param2})
	return spend(itemstack, placer)
end

-- The on_place of a plant with variants (default's fern does the same): any
-- of the nodes grows, the carried item stays the first.
local function place_variant(names)
	return function(itemstack, placer, pointed)
		local stack = ItemStack(names[math.random(1, #names)])
		local ret = core.item_place(stack, placer, pointed)
		return ItemStack(names[1] .. " " .. itemstack:get_count() - (1 - ret:get_count()))
	end
end

-- A small plant on the ground: plantlike, not walkable, anything may be built
-- into it, it goes with its ground. `low` (sixteenths): the height of its
-- selection box above the node's floor.
local function ground_plant(name, description, texture, low)
	core.register_node("grug_nodes:" .. name, {
		description = decor_description(description, ON_GROUND),
		drawtype = "plantlike",
		waving = 1,
		tiles = {texture},
		inventory_image = texture,
		wield_image = texture,
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		is_ground_content = false,
		selection_box = {type = "fixed",
			fixed = {-5 / 16, -0.5, -5 / 16, 5 / 16, -0.5 + low / 16, 5 / 16}},
		groups = {snappy = 3, flammable = 2, attached_node = 1, grug_decor_plant = 1},
		sounds = default.node_sound_leaves_defaults(),
	})
end

-- Flowers (ruling 11): three in strong colours for the jungle, three in
-- pastels for the elves.
ground_plant("flower_ruby_fan", "Ruby Fan", "grug_nodes_flower_ruby_fan.png", 10)
ground_plant("flower_ember_star", "Ember Star", "grug_nodes_flower_ember_star.png", 10)
ground_plant("flower_violet_fan", "Violet Fan", "grug_nodes_flower_violet_fan.png", 10)
ground_plant("flower_blush_star", "Blush Star", "grug_nodes_flower_blush_star.png", 10)
ground_plant("flower_lilac_bells", "Lilac Bells", "grug_nodes_flower_lilac_bells.png", 10)
ground_plant("flower_cream_cups", "Cream Cups", "grug_nodes_flower_cream_cups.png", 10)
-- Small alpine plants of the crags (the art fills the lowest seven rows).
ground_plant("alpine_cushion", "Alpine Cushion", "grug_nodes_alpine_cushion.png", 7)
ground_plant("alpine_windshrub", "Alpine Windshrub", "grug_nodes_alpine_windshrub.png", 7)

-- Lichen: a crust on gravel and stone, a carpet 1/16 high like the moss
-- carpet, in two variants (the generator alternates them); its texture is
-- mostly open, so the ground shows through (alpha clip). Both variants drop
-- the first, which places either, so they share one stack.
local LICHEN = {"grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b"}
local function lichen(name, texture, groups, on_place)
	groups.snappy, groups.attached_node, groups.flammable = 3, 3, 2
	core.register_node(name, {
		description = decor_description("Lichen", ON_GROUND),
		drawtype = "nodebox",
		tiles = {texture},
		inventory_image = texture,
		wield_image = texture,
		use_texture_alpha = "clip",
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		floodable = true,
		is_ground_content = false,
		drop = LICHEN[1],
		node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -7 / 16, 0.5}},
		groups = groups,
		sounds = default.node_sound_leaves_defaults(),
		on_place = on_place,
	})
end
lichen(LICHEN[1], "grug_nodes_lichen_carpet_top.png", {grug_decor_plant = 1}, place_variant(LICHEN))
lichen(LICHEN[2], "grug_nodes_lichen_carpet_top_b.png", {not_in_creative_inventory = 1})

-- Bush foliage on the default bush shapes: the jungle's large-leaved bush
-- (bush.mts) and the badlands' withered bush (acacia_bush.mts). The leaves
-- drop themselves (no sapling grows these bushes), but not when they decay:
-- leaf decay skips a drop that is one of its own leaves. The stems stay
-- default's and drop themselves. They decay with their stem like the default
-- bush leaves (radius 1); default.register_leafdecay replaces a stem's
-- after_destruct, so each stem lists its default leaves too.
local function bush_leaves(name, description, texture)
	core.register_node("grug_nodes:" .. name, {
		description = decor_description(description, AS_BLOCK),
		drawtype = "allfaces_optional",
		waving = 1,
		tiles = {texture},
		paramtype = "light",
		is_ground_content = false,
		groups = {snappy = 3, flammable = 2, leaves = 1, grug_decor_plant = 1},
		sounds = default.node_sound_leaves_defaults(),
		after_place_node = default.after_place_leaves,
	})
end
bush_leaves("jungle_bush_leaves", "Jungle Bush Leaves", "grug_nodes_jungle_bush_leaves.png")
bush_leaves("withered_bush_leaves", "Withered Bush Leaves", "grug_nodes_withered_bush_leaves.png")
default.register_leafdecay({
	trunks = {"default:bush_stem"},
	leaves = {"default:bush_leaves", "grug_nodes:jungle_bush_leaves"},
	radius = 1,
})
default.register_leafdecay({
	trunks = {"default:acacia_bush_stem"},
	leaves = {"default:acacia_bush_leaves", "grug_nodes:withered_bush_leaves"},
	radius = 1,
})

-- What default registers: ferns and marram grass (their variants drop the
-- first, as upstream) and the corals, which join the decoration by their
-- tooltip and price; Cyan, Green and Pink stand on a skeleton under water.
local function decor_item(name, how)
	local def = core.registered_nodes[name]
	local groups = table.copy(def.groups)
	groups.grug_decor_plant = 1
	core.override_item(name, {description = decor_description(def.description, how),
		groups = groups})
end
decor_item("default:fern_1", ON_GROUND)
decor_item("default:marram_grass_1", ON_GROUND)
decor_item("default:coral_brown", AS_BLOCK)
decor_item("default:coral_orange", AS_BLOCK)
for _, colour in ipairs({"cyan", "green", "pink"}) do
	decor_item("default:coral_" .. colour, "Place it on a Coral Skeleton under water.")
end

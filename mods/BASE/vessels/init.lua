-- vessels/init.lua

-- Minetest Game mod: vessels
-- See README.txt for licensing and other information.

-- Load support for MT game translation.
local S = minetest.get_translator("vessels")


-- GRUG PATCH: the shelf UI opens server-side from on_rightclick
-- (default/node_formspec.lua); no formspec is stored in node metadata.
-- GRUG PATCH: shift-click goes to the inbox (grug_inventory/inbox.lua):
-- main[9..] and the bags.
-- GRUG PATCH (0.49.1 VIEW): built per viewer, below the shelf the player's
-- whole combined bag (grug_inventory.station_formspec, real coordinates);
-- `context` is the node_formspec session's.
-- GRUG PATCH (Round 67 CONTAINERS): three tiers (default/containers.lua) of
-- 32, 64 and 96 slots; the box, the scrolling list and the Upgrade come
-- from there. A shelf made before Round 67 (16 slots) grows to 32 when it
-- is opened.
local function vessels_shelf_formspec(pos, player, context)
	local content, bottom = default.containers.form(pos, player, context,
		"vessels_shelf_slot.png")
	return grug_inventory.station_formspec(player, content, bottom, context, 4)
end

local function update_vessels_shelf(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local invlist = inv:get_list("vessels") or {}

	local n_items = 0
	for i = 1, #invlist do
		local stack = invlist[i]
		if not stack:is_empty() then
			n_items = n_items + stack:get_count()
		end
	end
	local def = minetest.registered_nodes[minetest.get_node(pos).name]
	local title = def and def.description or S("Vessels Shelf")
	if n_items == 0 then
		meta:set_string("infotext", S("Empty @1", title))
	else
		meta:set_string("infotext", S("@1 (@2 items)", title, n_items))
	end
	default.node_formspec.refresh(pos)
end

for tier, info in ipairs(default.containers.TIERS) do
	local name = default.containers.tier_name("vessels:shelf", tier)
	local side = tier == 1 and "default_wood.png" or "default_shelf" .. info.suffix .. "_side.png"
	local front = "vessels_shelf" .. info.suffix .. ".png"
	default.containers.register(name, {base = "vessels:shelf", tier = tier,
		list = "vessels", kind = "shelf", refresh = update_vessels_shelf})
	local vessels_shelf_def = {
		description = S(default.containers.description("Vessels Shelf", tier)),
		tiles = {side, side, side, side, front, front},
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3},
		sounds = default.node_sound_wood_defaults(),

		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("vessels", info.slots)
			update_vessels_shelf(pos)
		end,
		on_rightclick = function(pos, node, clicker, itemstack)
			default.containers.ensure_size(pos)
			default.node_formspec.show(clicker, pos, vessels_shelf_formspec)
			return itemstack
		end,
		on_receive_fields = function(pos, formname, fields, sender)
			default.containers.receive(pos, sender, fields)
		end,
		-- Close open viewers of a dug or replaced shelf.
		after_destruct = function(pos)
			default.node_formspec.refresh(pos)
		end,
		can_dig = function(pos,player)
			local inv = minetest.get_meta(pos):get_inventory()
			return inv:is_empty("vessels")
		end,
		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if minetest.get_item_group(stack:get_name(), "vessel") ~= 0 then
				return stack:get_count()
			end
			return 0
		end,
		on_blast = function(pos)
			local drops = {}
			default.get_inventory_drops(pos, "vessels", drops)
			drops[#drops + 1] = name
			minetest.remove_node(pos)
			return drops
		end,
		on_metadata_inventory_put = function(pos)
			update_vessels_shelf(pos)
		end,
		on_metadata_inventory_take = function(pos)
			update_vessels_shelf(pos)
		end,
		on_metadata_inventory_move = function(pos)
			update_vessels_shelf(pos)
		end,
	}
	default.set_inventory_action_loggers(vessels_shelf_def, "vessels shelf")
	minetest.register_node(name, vessels_shelf_def)
end

minetest.register_craft({
	output = "vessels:shelf",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:vessel", "group:vessel", "group:vessel"},
		{"group:wood", "group:wood", "group:wood"},
	}
})

minetest.register_node("vessels:glass_bottle", {
	description = S("Empty Glass Bottle"),
	drawtype = "plantlike",
	tiles = {"vessels_glass_bottle.png"},
	inventory_image = "vessels_glass_bottle.png",
	wield_image = "vessels_glass_bottle.png",
	paramtype = "light",
	is_ground_content = false,
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-0.25, -0.5, -0.25, 0.25, 0.3, 0.25}
	},
	groups = {vessel = 1, dig_immediate = 3, attached_node = 1},
	sounds = default.node_sound_glass_defaults(),
})

minetest.register_craft( {
	output = "vessels:glass_bottle 10",
	recipe = {
		{"default:glass", "", "default:glass"},
		{"default:glass", "", "default:glass"},
		{"", "default:glass", ""}
	}
})

minetest.register_node("vessels:drinking_glass", {
	description = S("Empty Drinking Glass"),
	drawtype = "plantlike",
	tiles = {"vessels_drinking_glass.png"},
	inventory_image = "vessels_drinking_glass_inv.png",
	wield_image = "vessels_drinking_glass.png",
	paramtype = "light",
	is_ground_content = false,
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-0.25, -0.5, -0.25, 0.25, 0.3, 0.25}
	},
	groups = {vessel = 1, dig_immediate = 3, attached_node = 1},
	sounds = default.node_sound_glass_defaults(),
})

minetest.register_craft( {
	output = "vessels:drinking_glass 14",
	recipe = {
		{"default:glass", "", "default:glass"},
		{"default:glass", "", "default:glass"},
		{"default:glass", "default:glass", "default:glass"}
	}
})

-- GRUG PATCH: the Heavy Steel Bottle, its craft recipe and its cooking return
-- are removed. Both referenced `default:steel_ingot`, which
-- grug_materials/content_curation.lua retires and unregisters (the canonical
-- bar is grug_materials:iron_bar), so the node could neither be crafted nor
-- smelted back into anything that exists.

-- Glass recycling

minetest.register_craftitem("vessels:glass_fragments", {
	description = S("Glass Fragments"),
	inventory_image = "vessels_glass_fragments.png",
})

minetest.register_craft( {
	type = "shapeless",
	output = "vessels:glass_fragments",
	recipe = {
		"vessels:glass_bottle",
		"vessels:glass_bottle",
	},
})

minetest.register_craft( {
	type = "shapeless",
	output = "vessels:glass_fragments",
	recipe = {
		"vessels:drinking_glass",
		"vessels:drinking_glass",
	},
})

minetest.register_craft({
	type = "cooking",
	output = "default:glass",
	recipe = "vessels:glass_fragments",
})

minetest.register_craft({
	type = "fuel",
	recipe = "vessels:shelf",
	burntime = 30,
})

-- GRUG PATCH: the `dungeon_loot` registration is removed - Grudgelands does not
-- ship that mod, so the `minetest.global_exists` guard was permanently false.

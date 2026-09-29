
local S = core.get_translator("mobs")
local FS = function(...) return core.formspec_escape(S(...)) end
local mc2 = core.get_modpath("mcl_core")
local mod_def = core.get_modpath("default")

-- determine which sounds to use, default or mcl_sounds

local function sound_helper(snd)

	mobs[snd] = (mod_def and default[snd]) or (mc2 and mcl_sounds[snd])
			or function() return {} end
end

sound_helper("node_sound_defaults")
sound_helper("node_sound_stone_defaults")
sound_helper("node_sound_dirt_defaults")
sound_helper("node_sound_sand_defaults")
sound_helper("node_sound_gravel_defaults")
sound_helper("node_sound_wood_defaults")
sound_helper("node_sound_leaves_defaults")
sound_helper("node_sound_ice_defaults")
sound_helper("node_sound_metal_defaults")
sound_helper("node_sound_water_defaults")
sound_helper("node_sound_snow_defaults")
sound_helper("node_sound_glass_defaults")

-- helper function to add {eatable} group to food items

function mobs.add_eatable(item, hp, ftype)

	local def = core.registered_items[item]

	if def then

		local groups = table.copy(def.groups) or {}

		groups.eatable = hp ; groups.flammable = 2 ; groups.food = ftype or 2

		core.override_item(item, {groups = groups})
	end
end

-- recipe items

local items = {
	paper = mc2 and "mcl_core:paper" or "default:paper",
	dye_black = mc2 and "mcl_dye:black" or "dye:black",
	dye_red = mc2 and "mcl_dye:red" or "dye:red",
	string = mc2 and "mcl_mobitems:string" or "farming:string",
	stick = mc2 and "mcl_core:stick" or "default:stick",
	diamond = mc2 and "mcl_core:diamond" or "default:diamond",
	steel_ingot = mc2 and "mcl_core:iron_ingot" or "default:steel_ingot",
	gold_block = mc2 and "mcl_core:goldblock" or "default:goldblock",
	diamond_block = mc2 and "mcl_core:diamondblock" or "default:diamondblock",
	stone = mc2 and "mcl_core:stone" or "default:stone",
	mese_crystal = mc2 and "mcl_core:gold_ingot" or "default:mese_crystal",
	wood = mc2 and "mcl_core:wood" or "default:wood",
	fence_wood = mc2 and "group:fence_wood" or "default:fence_wood",
	meat_raw = mc2 and "mcl_mobitems:beef" or "group:food_meat_raw",
	meat_cooked = mc2 and "mcl_mobitems:cooked_beef" or "group:food_meat",
	obsidian = mc2 and "mcl_core:obsidian" or "default:obsidian"
}

-- GRUG PATCH: the name tag is not registered (Round 26 ruling 13; no mob
-- naming or taming in Grudgelands). Its texture is removed as well.

-- leather

core.register_craftitem("mobs:leather", {
	description = S("Leather"),
	inventory_image = "mobs_leather.png",
	groups = {flammable = 2, leather = 1}
})

-- raw meat

core.register_craftitem("mobs:meat_raw", {
	description = S("Raw Meat"),
	inventory_image = "mobs_meat_raw.png",
	on_use = core.item_eat(3),
	groups = {food_meat_raw = 1}
})

mobs.add_eatable("mobs:meat_raw", 3)

-- cooked meat

core.register_craftitem("mobs:meat", {
	description = S("Meat"),
	inventory_image = "mobs_meat.png",
	on_use = core.item_eat(8),
	groups = {food_meat = 1}
})

mobs.add_eatable("mobs:meat", 8)

core.register_craft({
	type = "cooking",
	output = "mobs:meat",
	recipe = "mobs:meat_raw",
	cooktime = 5
})

-- GRUG PATCH: lasso, net, shears, both protection runes, the mob repellent
-- and the saddle are not registered (Round 26 ruling 13: no capture, taming,
-- shearing, mob protection or spawn blocking; mounts are skills). Their
-- recipes and textures are removed with them. Upstream api.lua still compares
-- wielded names against them; those branches are simply never reached.
-- GRUG PATCH: no historical item-name aliases during first-release development.

-- register mob fence if default found

if mod_def and default.register_fence then

	-- mob fence (looks like normal fence but collision is 2 high)
	default.register_fence("mobs:fence_wood", {
		description = S("Mob Fence"),
		texture = "default_wood.png",
		material = "default:fence_wood",
		groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2},
		sounds = mobs.node_sound_wood_defaults(),
		collision_box = {
			type = "fixed", fixed = {{-0.5, -0.5, -0.5, 0.5, 1.9, 0.5}}
		}
	})
end

-- mob fence top (has enlarged collisionbox to stop mobs getting over)

core.register_node("mobs:fence_top", {
	description = S("Mob Fence Top"),
	drawtype = "nodebox",
	tiles = {"default_wood.png"},
	paramtype = "light",
	is_ground_content = false,
	groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, axey = 1},
	sounds = mobs.node_sound_wood_defaults(),
	node_box = {type = "fixed", fixed = {-0.2, -0.5, -0.2, 0.2, 0, 0.2}},
	collision_box = {type = "fixed", fixed = {-0.4, -1.5, -0.4, 0.4, 0, 0.4}},
	selection_box = {type = "fixed", fixed = {-0.4, -1.5, -0.4, 0.4, 0, 0.4}}
})

core.register_craft({
	output = "mobs:fence_top 12",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"", items.fence_wood, ""}
	}
})

-- items that can be used as fuel

-- GRUG PATCH: no fuel rows for the removed name tag, lasso, net and saddle.
core.register_craft({type = "fuel", recipe = "mobs:leather", burntime = 4})
core.register_craft({type = "fuel", recipe = "mobs:fence_wood", burntime = 7})
core.register_craft({type = "fuel", recipe = "mobs:fence_top", burntime = 2})


-- this tool spawns same mob and adds owner, protected, nametag info
-- then removes original entity, this is used for fixing any issues.
-- also holding sneak while punching mob lets you change texture name.

local tex_obj

core.register_tool(":mobs:mob_reset_stick", {
	description = S("Mob Reset Stick"),
	inventory_image = "default_stick.png^[colorize:#ff000050",
	stack_max = 1,
	groups = {not_in_creative_inventory = 1},

	on_use = function(itemstack, user, pointed_thing)

		if pointed_thing.type ~= "object" then return end

		local obj = pointed_thing.ref
		local control = user:get_player_control()
		local sneak = control and control.sneak

		-- spawn same mob with saved stats, with random texture
		if obj and not sneak then

			local self = obj:get_luaentity()
			local obj2 = core.add_entity(obj:get_pos(), self.name)

			if obj2 then

				local ent2 = obj2:get_luaentity()

				ent2.protected = self.protected
				ent2.owner = self.owner
				-- GRUG PATCH: reset preserves the current canonical nametag field.
				ent2._nametag = self._nametag
				ent2.gotten = self.gotten
				ent2.tamed = self.tamed
				ent2.health = self.health
				ent2.order = self.order

				if self.child then
					obj2:set_velocity({x = 0, y = self.jump_height, z = 0})
				end

				obj2:set_properties({nametag = ""})

				obj:remove()
			end
		end

		-- display form to enter texture name ending in .png
		if obj and sneak then

			tex_obj = obj

			-- get base texture
			local bt = tex_obj:get_luaentity().base_texture[1]

			if type(bt) ~= "string" then bt = "" end

			local name = user:get_player_name()

			core.show_formspec(name, "mobs_texture", "size[8,4]"
			.. "field[0.5,1;7.5,0;name;"
			.. FS("Enter texture:") .. ";" .. bt .. "]"
			.. "button_exit[2.5,3.5;3,1;mob_texture_change;"
			.. FS("Change") .. "]")
		end
	end
})

core.register_on_player_receive_fields(function(player, formname, fields)

	-- right-clicked with nametag and name entered?
	if formname == "mobs_texture" and fields.name and fields.name ~= "" then

		-- does mob still exist?
		if not tex_obj or not tex_obj:get_luaentity() then return end

		-- make sure nametag is being used to name mob
		local item = player:get_wielded_item()

		if item:get_name() ~= "mobs:mob_reset_stick" then return end

		-- limit name entered to 64 characters long
		if fields.name:len() > 64 then fields.name = fields.name:sub(1, 64) end

		-- update texture
		local self = tex_obj:get_luaentity()

		self.base_texture = {fields.name}

		tex_obj:set_properties({textures = {fields.name}})

		-- reset external variable
		tex_obj = nil
	end
end)

-- Meat Block

core.register_node("mobs:meatblock", {
	description = S("Meat Block"),
	tiles = {"mobs_meat_top.png", "mobs_meat_bottom.png", "mobs_meat_side.png"},
	paramtype2 = "facedir",
	groups = {choppy = 1, oddly_breakable_by_hand = 1, axey = 1, handy = 1},
	is_ground_content = false,
	sounds = mobs.node_sound_dirt_defaults(),
	on_place = core.rotate_node,
	on_use = core.item_eat(20),
	_mcl_hardness = 0.8,
	_mcl_blast_resistance = 1
})

mobs.add_eatable("mobs:meatblock", 20)

core.register_craft({
	output = "mobs:meatblock",
	recipe = {
		{items.meat_cooked, items.meat_cooked, items.meat_cooked},
		{items.meat_cooked, items.meat_cooked, items.meat_cooked},
		{items.meat_cooked, items.meat_cooked, items.meat_cooked}
	}
})

-- Meat Block (raw)

core.register_node("mobs:meatblock_raw", {
	description = S("Raw Meat Block"),
	tiles = {"mobs_meat_raw_top.png", "mobs_meat_raw_bottom.png", "mobs_meat_raw_side.png"},
	paramtype2 = "facedir",
	groups = {choppy = 1, oddly_breakable_by_hand = 1, axey = 1, handy = 1},
	is_ground_content = false,
	sounds = mobs.node_sound_dirt_defaults(),
	on_place = core.rotate_node,
	on_use = core.item_eat(20),
	_mcl_hardness = 0.8,
	_mcl_blast_resistance = 1
})

mobs.add_eatable("mobs:meatblock_raw", 20)

core.register_craft({
	output = "mobs:meatblock_raw",
	recipe = {
		{items.meat_raw, items.meat_raw, items.meat_raw},
		{items.meat_raw, items.meat_raw, items.meat_raw},
		{items.meat_raw, items.meat_raw, items.meat_raw}
	}
})

core.register_craft({
	type = "cooking",
	output = "mobs:meatblock",
	recipe = "mobs:meatblock_raw",
	cooktime = 30
})

-- hearing vines (if mesecons active it acts like blinkyplant)

local mod_mese = core.get_modpath("mesecons")

core.register_node("mobs:hearing_vines", {
	description = S("Hearing Vines"),
	drawtype = "firelike",
	waving = 1,
	tiles = {"mobs_hearing_vines.png"},
	inventory_image = "mobs_hearing_vines.png",
	wield_image = "mobs_hearing_vines.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	groups = {snappy = 3, flammable = 3, attached_node = 1, on_sound = 1},
	sounds = mobs.node_sound_leaves_defaults(),
	selection_box = {
		type = "fixed", fixed = {-6 / 16, -0.5, -6 / 16, 6 / 16, -0.25, 6 / 16},
	},
	on_sound = function(pos, def)
		if def.loudness > 0.5 then
			core.set_node(pos, {name = "mobs:hearing_vines_active"})
		end
	end
})

core.register_node("mobs:hearing_vines_active", {
	description = S("Active Hearing Vines"),
	drawtype = "firelike",
	waving = 1,
	tiles = {"mobs_hearing_vines_active.png"},
	inventory_image = "mobs_hearing_vines_active.png",
	wield_image = "mobs_hearing_vines_active.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	light_source = 1,
	damage_per_second = 4,
	drop = "mobs:hearing_vines",
	groups = {snappy = 3, flammable = 3, attached_node = 1, not_in_creative_inventory = 1},
	sounds = mobs.node_sound_leaves_defaults(),
	selection_box = {
		type = "fixed", fixed = {-6 / 16, -0.5, -6 / 16, 6 / 16, -0.25, 6 / 16},
	},
	on_construct = function(pos)
		core.get_node_timer(pos):start(1)
		if mod_mese then mesecon.receptor_on(pos) end
	end,
	on_timer = function(pos)
		core.set_node(pos, {name = "mobs:hearing_vines"})
		if mod_mese then mesecon.receptor_off(pos) end
	end
})

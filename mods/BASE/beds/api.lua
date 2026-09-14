-- GRUG PATCH: beds are DECORATION ONLY in Grudgelands. Everything that made a
-- bed a gameplay object is removed from this file: `beds.on_rightclick`
-- (lie down / sleep), `beds.can_dig` (the "someone is lying here" veto),
-- `beds.remove_spawns_at` / `beds.kick_player_at` (respawn bookkeeping) and the
-- `on_rotate` screwdriver hook (Grudgelands ships no `screwdriver` mod).
-- Player spawn is owned by grug_core and is never touched here.
-- What remains is placement of the two halves, their shared destruction and the
-- craft recipe.

-- Removes a node without calling on on_destruct()
-- We use this to mess with bed nodes without causing unwanted recursion.
local function remove_no_destruct(pos)
	minetest.swap_node(pos, {name = "air"})
	minetest.remove_node(pos) -- Now clear the meta
	minetest.check_for_falling(pos)
end

--- returns the position of the other bed half (or nil on failure)
local function get_other_bed_pos(pos, n)
	local node = core.get_node(pos)
	local dir = core.facedir_to_dir(node.param2)
	if not dir then
		return -- There are 255 possible param2 values. Ignore bad ones.
	end
	local other
	if n == 2 then
		other = vector.subtract(pos, dir)
	elseif n == 1 then
		other = vector.add(pos, dir)
	else
		return nil
	end

	local onode = core.get_node(other)
	if onode.param2 == node.param2 and core.get_item_group(onode.name, "bed") ~= 0 then
		return other
	end
	return nil
end

local function destruct_bed(pos, n)
	-- GRUG PATCH: only the paired half is removed; the spawn-point and
	-- kick-sleeper bookkeeping that used to run here is gone with the rest of
	-- the sleeping logic.
	local other = get_other_bed_pos(pos, n)
	if other then
		remove_no_destruct(other)
	end
end

function beds.register_bed(name, def)
	minetest.register_node(name .. "_bottom", {
		description = def.description,
		inventory_image = def.inventory_image,
		wield_image = def.wield_image,
		drawtype = "nodebox",
		tiles = def.tiles.bottom,
		use_texture_alpha = "clip",
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		stack_max = 1,
		groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 3, bed = 1},
		sounds = def.sounds or default.node_sound_wood_defaults(),
		node_box = {
			type = "fixed",
			fixed = def.nodebox.bottom,
		},
		selection_box = {
			type = "fixed",
			fixed = def.selectionbox,
		},

		on_place = function(itemstack, placer, pointed_thing)
			local under = pointed_thing.under
			local node = minetest.get_node(under)
			local udef = minetest.registered_nodes[node.name]
			if udef and udef.on_rightclick and
					not (placer and placer:is_player() and
					placer:get_player_control().sneak) then
				return udef.on_rightclick(under, node, placer, itemstack,
					pointed_thing) or itemstack
			end

			local pos
			if udef and udef.buildable_to then
				pos = under
			else
				pos = pointed_thing.above
			end

			local player_name = placer and placer:get_player_name() or ""

			if minetest.is_protected(pos, player_name) and
					not minetest.check_player_privs(player_name, "protection_bypass") then
				minetest.record_protection_violation(pos, player_name)
				return itemstack
			end

			local node_def = minetest.registered_nodes[minetest.get_node(pos).name]
			if not node_def or not node_def.buildable_to then
				return itemstack
			end

			local dir = placer and placer:get_look_dir() and
				minetest.dir_to_facedir(placer:get_look_dir()) or 0
			local botpos = vector.add(pos, minetest.facedir_to_dir(dir))

			if minetest.is_protected(botpos, player_name) and
					not minetest.check_player_privs(player_name, "protection_bypass") then
				minetest.record_protection_violation(botpos, player_name)
				return itemstack
			end

			local botdef = minetest.registered_nodes[minetest.get_node(botpos).name]
			if not botdef or not botdef.buildable_to then
				return itemstack
			end

			minetest.set_node(pos, {name = name .. "_bottom", param2 = dir})
			minetest.set_node(botpos, {name = name .. "_top", param2 = dir})

			if not minetest.is_creative_enabled(player_name) then
				itemstack:take_item()
			end
			return itemstack
		end,

		on_destruct = function(pos)
			destruct_bed(pos, 1)
		end,
	})

	minetest.register_node(name .. "_top", {
		drawtype = "nodebox",
		tiles = def.tiles.top,
		use_texture_alpha = "clip",
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 3, bed = 2,
				not_in_creative_inventory = 1},
		sounds = def.sounds or default.node_sound_wood_defaults(),
		drop = "",
		node_box = {
			type = "fixed",
			fixed = def.nodebox.top,
		},
		selection_box = {
			type = "fixed",
			-- Small selection box to allow digging stray top nodes
			fixed = {-0.3, -0.3, -0.3, 0.3, -0.1, 0.3},
		},
		on_destruct = function(pos)
			destruct_bed(pos, 2)
		end,
	})

	-- GRUG PATCH: upstream registered the alias `<name>` -> `<name>_bottom` only
	-- so that the recipe below could name the short form. The recipe names the
	-- real node instead; fresh-server mode allows no item-name aliases.
	minetest.register_craft({
		output = name .. "_bottom",
		recipe = def.recipe
	})
end

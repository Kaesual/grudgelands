default.chest = {}

-- support for MT game translation.
local S = default.get_translator

-- GRUG PATCH: shift-click goes to the inbox (grug_inventory/inbox.lua):
-- main[9..] and the bags.
-- GRUG PATCH (0.49.1 VIEW): built per viewer, below the chest the player's
-- whole combined bag (grug_inventory.station_formspec, real coordinates).
-- GRUG PATCH (Round 50 HOTBAR): `context` (optional) keeps the bag view's
-- scroll position; only the view's hotbar switch re-shows the open form.
function default.chest.get_chest_formspec(pos, player, context)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local station = grug_inventory.STATION
	local box, bottom = grug_inventory.station_box(S("Chest"),
		4 * station.pitch - 0.25)
	return grug_inventory.station_formspec(player, box ..
		("list[nodemeta:%s;main;%.3f,%.3f;8,4;]"):format(spos, station.x, station.y) ..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;grug_inbox]" ..
		"listring[current_player;main]",
		bottom, context)
end

function default.chest.chest_lid_obstructed(pos)
	local above = {x = pos.x, y = pos.y + 1, z = pos.z}
	local def = minetest.registered_nodes[minetest.get_node(above).name]
	-- allow ladders, signs, wallmounted things and torches to not obstruct
	if def and
			(def.drawtype == "airlike" or
			def.drawtype == "signlike" or
			def.drawtype == "torchlike" or
			(def.drawtype == "nodebox" and def.paramtype2 == "wallmounted")) then
		return false
	end
	return true
end

function default.chest.chest_lid_close(pn)
	local chest_open_info = default.chest.open_chests[pn]
	local pos = chest_open_info.pos
	local sound = chest_open_info.sound
	local swap = chest_open_info.swap

	default.chest.open_chests[pn] = nil
	for k, v in pairs(default.chest.open_chests) do
		if vector.equals(v.pos, pos) then
			-- another player is also looking at the chest
			return true
		end
	end

	local node = minetest.get_node(pos)
	minetest.after(0.2, function()
		local current_node = minetest.get_node(pos)
		if current_node.name ~= swap .. "_open" then
			-- the chest has already been replaced, don't try to replace what's there.
			return
		end
		minetest.swap_node(pos, {name = swap, param2 = node.param2})
		minetest.sound_play(sound, {gain = 0.3, pos = pos,
			max_hear_distance = 10}, true)
	end)
end

default.chest.open_chests = {}

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pn = player:get_player_name()

	if formname ~= "default:chest" then
		if default.chest.open_chests[pn] then
			default.chest.chest_lid_close(pn)
		end

		return
	end

	-- GRUG PATCH (Round 50 HOTBAR): the bag view's scroll value of every
	-- event, and the hotbar switch, which shows the chest form again while
	-- the chest is still there.
	local open = default.chest.open_chests[pn]
	if open and not fields.quit then
		grug_inventory.keep_scroll(open.context, fields)
		local node = core.get_node(open.pos).name
		if grug_inventory.hotbar_switch_fields(player, fields) and
				(node == open.swap or node == open.swap .. "_open") then
			core.show_formspec(pn, "default:chest",
				default.chest.get_chest_formspec(open.pos, player, open.context))
		end
		return
	end

	if not (fields.quit and default.chest.open_chests[pn]) then
		return
	end

	default.chest.chest_lid_close(pn)

	return true
end)

minetest.register_on_leaveplayer(function(player)
	local pn = player:get_player_name()
	if default.chest.open_chests[pn] then
		default.chest.chest_lid_close(pn)
	end
end)

function default.chest.register_chest(prefixed_name, d)
	local name = prefixed_name:sub(1,1) == ':' and prefixed_name:sub(2,-1) or prefixed_name
	local def = table.copy(d)
	def.drawtype = "mesh"
	def.visual = "mesh"
	def.paramtype = "light"
	def.paramtype2 = "facedir"
	-- GRUG PATCH: no pre-release mapblock-format conversion flags.
	def.is_ground_content = false

	if def.protected then
		def.on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", S("Locked Chest"))
			meta:set_string("owner", "")
			local inv = meta:get_inventory()
			inv:set_size("main", 8*4)
		end
		def.after_place_node = function(pos, placer)
			local meta = minetest.get_meta(pos)
			meta:set_string("owner", placer:get_player_name() or "")
			meta:set_string("infotext", S("Locked Chest (owned by @1)", meta:get_string("owner")))
		end
		def.can_dig = function(pos,player)
			local meta = minetest.get_meta(pos);
			local inv = meta:get_inventory()
			return inv:is_empty("main") and
					default.can_interact_with_node(player, pos)
		end
		def.allow_metadata_inventory_move = function(pos, from_list, from_index,
				to_list, to_index, count, player)
			if not default.can_interact_with_node(player, pos) then
				return 0
			end
			return count
		end
		def.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if not default.can_interact_with_node(player, pos) then
				return 0
			end
			return stack:get_count()
		end
		def.allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			if not default.can_interact_with_node(player, pos) then
				return 0
			end
			return stack:get_count()
		end
		def.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if not default.can_interact_with_node(clicker, pos) then
				return itemstack
			end

			local cn = clicker:get_player_name()

			if default.chest.open_chests[cn] then
				default.chest.chest_lid_close(cn)
			end

			minetest.sound_play(def.sound_open, {gain = 0.3,
					pos = pos, max_hear_distance = 10}, true)
			if not default.chest.chest_lid_obstructed(pos) then
				minetest.swap_node(pos,
						{ name = name .. "_open",
						param2 = node.param2 })
			end
			-- GRUG PATCH (Round 50 HOTBAR): the session's view context.
			local context = {}
			minetest.after(0.2, minetest.show_formspec, cn,
					"default:chest", default.chest.get_chest_formspec(pos, clicker, context))
			default.chest.open_chests[cn] = { pos = pos,
					sound = def.sound_close, swap = name, context = context }
		end
		def.on_blast = function() end
		def.on_key_use = function(pos, player)
			local secret = minetest.get_meta(pos):get_string("key_lock_secret")
			local itemstack = player:get_wielded_item()
			local key_meta = itemstack:get_meta()

			if itemstack:get_meta():get_string("") == "" then
				return
			end

			if key_meta:get_string("secret") == "" then
				key_meta:set_string("secret", minetest.parse_json(itemstack:get_meta():get_string("")).secret)
				itemstack:set_metadata("")
			end

			if secret ~= key_meta:get_string("secret") then
				return
			end

			minetest.show_formspec(
				player:get_player_name(),
				"default:chest_locked",
				default.chest.get_chest_formspec(pos, player)
			)
		end
		def.on_skeleton_key_use = function(pos, player, newsecret)
			local meta = minetest.get_meta(pos)
			local owner = meta:get_string("owner")
			local pn = player:get_player_name()

			-- verify placer is owner of lockable chest
			if owner ~= pn then
				minetest.record_protection_violation(pos, pn)
				minetest.chat_send_player(pn, S("You do not own this chest."))
				return nil
			end

			local secret = meta:get_string("key_lock_secret")
			if secret == "" then
				secret = newsecret
				meta:set_string("key_lock_secret", secret)
			end

			return secret, S("a locked chest"), owner
		end
	else
		def.on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", S("Chest"))
			local inv = meta:get_inventory()
			inv:set_size("main", 8*4)
		end
		def.can_dig = function(pos,player)
			local meta = minetest.get_meta(pos);
			local inv = meta:get_inventory()
			return inv:is_empty("main")
		end
		def.on_rightclick = function(pos, node, clicker)
			local cn = clicker:get_player_name()

			if default.chest.open_chests[cn] then
				default.chest.chest_lid_close(cn)
			end

			minetest.sound_play(def.sound_open, {gain = 0.3, pos = pos,
					max_hear_distance = 10}, true)
			if not default.chest.chest_lid_obstructed(pos) then
				minetest.swap_node(pos, {
						name = name .. "_open",
						param2 = node.param2 })
			end
			-- GRUG PATCH (Round 50 HOTBAR): the session's view context.
			local context = {}
			minetest.after(0.2, minetest.show_formspec,
					cn,
					"default:chest", default.chest.get_chest_formspec(pos, clicker, context))
			default.chest.open_chests[cn] = { pos = pos,
					sound = def.sound_close, swap = name, context = context }
		end
		def.on_blast = function(pos)
			local drops = {}
			default.get_inventory_drops(pos, "main", drops)
			drops[#drops+1] = name
			minetest.remove_node(pos)
			return drops
		end
	end

	default.set_inventory_action_loggers(def, "chest")

	local def_opened = table.copy(def)
	local def_closed = table.copy(def)

	def_opened.mesh = "chest_open.obj"
	for i = 1, #def_opened.tiles do
		if type(def_opened.tiles[i]) == "string" then
			def_opened.tiles[i] = {name = def_opened.tiles[i], backface_culling = true}
		elseif def_opened.tiles[i].backface_culling == nil then
			def_opened.tiles[i].backface_culling = true
		end
	end
	def_opened.drop = name
	def_opened.groups.not_in_creative_inventory = 1
	def_opened.selection_box = {
		type = "fixed",
		fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
	}
	def_opened.can_dig = function()
		return false
	end
	def_opened.on_blast = function() end

	def_closed.mesh = nil
	def_closed.drawtype = nil
	def_closed.tiles[6] = def.tiles[5] -- swap textures around for "normal"
	def_closed.tiles[5] = def.tiles[3] -- drawtype to make them match the mesh
	def_closed.tiles[3] = def.tiles[3].."^[transformFX"

	minetest.register_node(prefixed_name, def_closed)
	minetest.register_node(prefixed_name .. "_open", def_opened)

	-- GRUG PATCH: no old chest format conversion in fresh worlds.

	-- close opened chests on load
	local modname, chestname = prefixed_name:match("^(:?.-):(.*)$")
	minetest.register_lbm({
		label = "close opened chests on load",
		name = modname .. ":close_" .. chestname .. "_open",
		nodenames = {prefixed_name .. "_open"},
		run_at_every_load = true,
		action = function(pos, node)
			node.name = prefixed_name
			minetest.swap_node(pos, node)
		end
	})
end

default.chest.register_chest("default:chest", {
	description = S("Chest"),
	tiles = {
		"default_chest_top.png",
		"default_chest_top.png",
		"default_chest_side.png",
		"default_chest_side.png",
		"default_chest_front.png",
		"default_chest_inside.png"
	},
	sounds = default.node_sound_wood_defaults(),
	sound_open = "default_chest_open",
	sound_close = "default_chest_close",
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
})

default.chest.register_chest("default:chest_locked", {
	description = S("Locked Chest"),
	tiles = {
		"default_chest_top.png",
		"default_chest_top.png",
		"default_chest_side.png",
		"default_chest_side.png",
		"default_chest_lock.png",
		"default_chest_inside.png"
	},
	sounds = default.node_sound_wood_defaults(),
	sound_open = "default_chest_open",
	sound_close = "default_chest_close",
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	protected = true,
})

minetest.register_craft({
	output = "default:chest",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", "", "group:wood"},
		{"group:wood", "group:wood", "group:wood"},
	}
})

minetest.register_craft({
	output = "default:chest_locked",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", "default:steel_ingot", "group:wood"},
		{"group:wood", "group:wood", "group:wood"},
	}
})

minetest.register_craft( {
	type = "shapeless",
	output = "default:chest_locked",
	recipe = {"default:chest", "default:steel_ingot"},
})

minetest.register_craft({
	type = "fuel",
	recipe = "default:chest",
	burntime = 30,
})

minetest.register_craft({
	type = "fuel",
	recipe = "default:chest_locked",
	burntime = 30,
})

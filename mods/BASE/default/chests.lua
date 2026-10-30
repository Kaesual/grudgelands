default.chest = {}

-- support for MT game translation.
local S = default.get_translator

-- GRUG PATCH: shift-click goes to the inbox (grug_inventory/inbox.lua):
-- main[9..] and the bags.
-- GRUG PATCH (0.49.1 VIEW): built per viewer, below the chest the player's
-- whole combined bag (grug_inventory.station_formspec, real coordinates).
-- GRUG PATCH (Round 50 HOTBAR): `context` (optional) keeps the bag view's
-- scroll position; only the view's hotbar switch re-shows the open form.
-- GRUG PATCH (Round 67 CONTAINERS): the chest's box, list and action row
-- (label, Sort, Upgrade) come from default/containers.lua; its list
-- scrolls beyond four rows.
function default.chest.get_chest_formspec(pos, player, context)
	local content, bottom = default.containers.form(pos, player, context)
	return grug_inventory.station_formspec(player, content, bottom, context, 4)
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
	-- GRUG PATCH (Round 67 CONTAINERS): the action row's fields (label,
	-- Sort, Upgrade; default/containers.lua) while the chest is there.
	local open = default.chest.open_chests[pn]
	if open and not fields.quit then
		local pure = grug_inventory.keep_scroll(open.context, fields)
		local node = core.get_node(open.pos).name
		if pure or not (node == open.swap or node == open.swap .. "_open") then
			return
		end
		if grug_inventory.hotbar_switch_fields(player, fields) then
			core.show_formspec(pn, "default:chest",
				default.chest.get_chest_formspec(open.pos, player, open.context))
			return
		end
		default.containers.receive(open.pos, player, fields, open.context)
		return
	end

	if not (fields.quit and default.chest.open_chests[pn]) then
		return
	end

	default.chest.chest_lid_close(pn)

	return true
end)

-- GRUG PATCH (Round 67 CONTAINERS): an upgrade swapped the chest at `pos`
-- to the tier `name` (default/containers.lua): every viewer's remembered
-- node follows, so closing the lid lands on the new tier, and each viewer's
-- form shows the grown list at its kept scroll position.
function default.chest.retarget(pos, name)
	for pn, open in pairs(default.chest.open_chests) do
		if vector.equals(open.pos, pos) then
			open.swap = name
			local player = core.get_player_by_name(pn)
			if player then
				core.show_formspec(pn, "default:chest",
					default.chest.get_chest_formspec(open.pos, player, open.context))
			end
		end
	end
end

minetest.register_on_leaveplayer(function(player)
	local pn = player:get_player_name()
	if default.chest.open_chests[pn] then
		default.chest.chest_lid_close(pn)
	end
end)

-- GRUG PATCH (Round 67 CONTAINERS): `d._grug_container` = {base, tier}
-- registers the chest and its open variant as a container tier
-- (default/containers.lua): the list has the tier's slots, the hover text
-- carries the label.
function default.chest.register_chest(prefixed_name, d)
	local name = prefixed_name:sub(1,1) == ':' and prefixed_name:sub(2,-1) or prefixed_name
	local def = table.copy(d)
	def.drawtype = "mesh"
	def.visual = "mesh"
	def.paramtype = "light"
	def.paramtype2 = "facedir"
	-- GRUG PATCH: no pre-release mapblock-format conversion flags.
	def.is_ground_content = false
	local container = def._grug_container or {base = name, tier = 1}
	def._grug_container = nil
	local slots = default.containers.TIERS[container.tier].slots
	default.containers.register(name, {base = container.base, tier = container.tier,
		list = "main", kind = def.protected and "locked" or "chest",
		open = name .. "_open", refresh = default.containers.update_infotext})

	if def.protected then
		def.on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", def.description)
			meta:set_string("owner", "")
			local inv = meta:get_inventory()
			inv:set_size("main", slots)
		end
		def.after_place_node = function(pos, placer)
			local meta = minetest.get_meta(pos)
			meta:set_string("owner", placer:get_player_name() or "")
			default.containers.update_infotext(pos)
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
			meta:set_string("infotext", def.description)
			local inv = meta:get_inventory()
			inv:set_size("main", slots)
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

-- GRUG PATCH (Round 67 CONTAINERS): every chest and locked chest in the
-- three tiers of default/containers.lua, on the same model; a tier above
-- the first has its own textures (default_chest_<tier>_*.png).
for tier, info in ipairs(default.containers.TIERS) do
	local function tile(part)
		return "default_chest" .. info.suffix .. "_" .. part .. ".png"
	end
	default.chest.register_chest(default.containers.tier_name("default:chest", tier), {
		description = S(default.containers.description("Chest", tier)),
		tiles = {
			tile("top"),
			tile("top"),
			tile("side"),
			tile("side"),
			tile("front"),
			tile("inside")
		},
		sounds = default.node_sound_wood_defaults(),
		sound_open = "default_chest_open",
		sound_close = "default_chest_close",
		groups = {choppy = 2, oddly_breakable_by_hand = 2},
		_grug_container = {base = "default:chest", tier = tier},
	})

	default.chest.register_chest(default.containers.tier_name("default:chest_locked", tier), {
		description = S(default.containers.description("Chest", tier, "Locked")),
		tiles = {
			tile("top"),
			tile("top"),
			tile("side"),
			tile("side"),
			tile("lock"),
			tile("inside")
		},
		sounds = default.node_sound_wood_defaults(),
		sound_open = "default_chest_open",
		sound_close = "default_chest_close",
		groups = {choppy = 2, oddly_breakable_by_hand = 2},
		protected = true,
		_grug_container = {base = "default:chest_locked", tier = tier},
	})
end

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


local S = core.get_translator("mobs")
local FS = function(...) return core.formspec_escape(S(...)) end
local max_per_block = tonumber(core.settings:get("max_objects_per_block") or 99)

-- helper functions

local function is_player(player)

	if player and type(player) == "userdata" and core.is_player(player) then
		return true
	end
end

local square = math.sqrt

local function get_distance(a, b)

	if not a or not b then return 50 end -- nil check and default distance

	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z

	return square(x * x + y * y + z * z)
end

-- mob spawner

local spawner_default = "mobs_animal:pumba 10 15 0 0 0"

-- GRUG PATCH: server-side settings form. A formspec stored in node metadata
-- is opened by the client itself on RMB, before the server can decide
-- anything; one session per player remembers which spawner the open form
-- belongs to, and every submission is validated (range, node) before it
-- reaches on_receive_fields.
local FORMNAME = "mobs:spawner_settings"
local MAX_DISTANCE = 10
local sessions = {} -- [player name] = spawner pos

local function spawner_formspec(pos)

	local head = S("(mob name) (min light) (max light) (amount)"
			.. " (player distance) (Y offset)")

	local esc = core.formspec_escape

	return "size[10,3.5]"
		.. "label[0.1,0.3;" .. core.formspec_escape(head) .. "]"
		.. "field[0.5,1.8;9.5,0.8;text;" .. S("Command:")
		.. ";" .. esc(core.get_meta(pos):get_string("command")) .. "]"
		.. "button_exit[3.5,2.7;3,1;mob_spawner;" .. esc(FS("Done")) .. "]"
end

core.register_node("mobs:spawner", {
	tiles = {"mob_spawner.png"},
	drawtype = "glasslike",
	paramtype = "light",
	walkable = true,
	description = S("Mob Spawner"),
	groups = {cracky = 1, pickaxey = 3},
	is_ground_content = false,
	_mcl_hardness = 1,
	_mcl_blast_resistance = 5,
	sounds = mobs.node_sound_stone_defaults(),

	-- GRUG PATCH: the settings form opens server-side from on_rightclick
	-- (the former `on_right_click` was a misspelled no-op); no formspec is
	-- stored in node metadata, and the stored command is filled in
	-- explicitly instead of the meta-only `${command}` substitution.
	on_construct = function(pos)

		local meta = core.get_meta(pos)

		meta:set_string("infotext", S("Spawner Not Active (enter settings)"))
		meta:set_string("command", spawner_default)
	end,

	on_rightclick = function(pos, node, clicker, itemstack)

		if clicker and clicker.is_player and clicker:is_player() then
			local name = clicker:get_player_name()
			local at = vector.new(pos.x, pos.y, pos.z)

			sessions[name] = at
			core.show_formspec(name, FORMNAME, spawner_formspec(at))
		end

		return itemstack
	end,

	on_receive_fields = function(pos, formname, fields, sender)

		if not fields.text or fields.text == "" then return end

		local meta = core.get_meta(pos)
		local comm = fields.text:split(" ")
		local name = sender:get_player_name()

		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return
		end

		local mob = comm[1] or "" -- mob to spawn
		local mlig = tonumber(comm[2]) -- min light
		local xlig = tonumber(comm[3]) -- max light
		local num = tonumber(comm[4]) -- total mobs in area
		local pla = tonumber(comm[5]) -- player distance (0 to disable)
		local yof = tonumber(comm[6]) or 0 -- Y offset to spawn mob

		if mob ~= "" and mobs.spawning_mobs[mob] and num and num >= 0 and num <= 10
		and mlig and mlig >= 0 and mlig <= 15 and xlig and xlig >= 0 and xlig <= 15
		and pla and pla >= 0 and pla <= 20 and yof and yof > -10 and yof < 10 then

			meta:set_string("command", fields.text)
			meta:set_string("infotext", S("Spawner Active (@1)", mob))
		else
			core.chat_send_player(name, S("Mob Spawner settings failed!"))
			core.chat_send_player(name,
				S("Syntax: “name min_light[0-14] max_light[0-14] "
				.. "max_mobs_in_area[0 to disable] player_distance[1-20] "
				.. "y_offset[-10 to 10]”"))
		end
	end
})

core.register_on_player_receive_fields(function(player, formname, fields)

	if formname ~= FORMNAME then return end

	local name = player:get_player_name()
	local pos = sessions[name]

	if not pos then return true end

	if fields.quit then sessions[name] = nil end

	local node = core.get_node_or_nil(pos)
	local at = player:get_pos()

	if not node or node.name ~= "mobs:spawner" or not at
	or get_distance(at, pos) > MAX_DISTANCE then
		sessions[name] = nil
		core.close_formspec(name, FORMNAME)
		return true
	end

	core.registered_nodes["mobs:spawner"].on_receive_fields(
			vector.new(pos.x, pos.y, pos.z), formname, fields, player)

	return true
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)

-- spawner abm

core.register_abm({
	label = "Mob spawner node",
	nodenames = {"mobs:spawner"},
	interval = 10,
	chance = 4,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)

		-- return if too many entities already
		if active_object_count_wider >= max_per_block then return end

		-- get meta and command
		local meta = core.get_meta(pos)
		local comm = meta:get_string("command"):split(" ")

		-- get settings from command
		local mob = comm[1]
		local mlig = tonumber(comm[2])
		local xlig = tonumber(comm[3])
		local num = tonumber(comm[4])
		local pla = tonumber(comm[5]) or 0
		local yof = tonumber(comm[6]) or 0

		-- if amount is 0 then do nothing
		if num == 0 then return end

		-- are we spawning a registered mob?
		if not mobs.spawning_mobs[mob] or not core.registered_entities[mob] then
			--print ("--- mob doesn't exist", mob)
			return
		end

		-- check objects inside 9x9 area around spawner
		local objs = core.get_objects_inside_radius(pos, 9)
		local count = 0
		local ent

		-- count mob objects of same type in area
		for _, obj in ipairs(objs) do

			ent = obj:get_luaentity()

			if ent and ent.name and ent.name == mob then count = count + 1 end
		end

		-- is there too many of same type?
		if count >= num then return end

		-- when player distance above 0, spawn mob if player detected and in range
		if pla > 0 then

			local in_range, player
			local players = core.get_connected_players()

			for i = 1, #players do

				player = players[i]

				if get_distance(player:get_pos(), pos) <= pla then
					in_range = true ; break
				end
			end

			-- player not found
			if not in_range then return end
		end

		-- set medium mob usually spawns in (defaults to air)
		local reg = core.registered_entities[mob].fly_in

		if type(reg) ~= "table" then reg = {reg or "air"} end

		-- find air blocks within 5 nodes of spawner
		local air = core.find_nodes_in_area(
				{x = pos.x - 5, y = pos.y + yof, z = pos.z - 5},
				{x = pos.x + 5, y = pos.y + yof, z = pos.z + 5}, reg)

		-- spawn in random air block
		if air and #air > 0 then

			local pos2 = air[math.random(#air)]
			local lig = core.get_node_light(pos2) or 0

			-- only if light levels are within range
			if lig >= mlig and lig <= xlig  then

				pos2.y = pos2.y + 0.5

				core.add_entity(pos2, mob)
			end
		end
	end
})

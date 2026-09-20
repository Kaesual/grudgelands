-- Live service witness for one fully generated capital. This helper observes
-- production sockets, nodes and entities; it never invokes placement itself.
return function(params)
	local core = core
	local fail = params.fail
	local key, race = params.key, params.race
	local plots, anchor = params.plots, params.anchor
	local worldpath = params.worldpath
	local services = dofile(params.wp13 .. "/capital_services.lua")
	local expected_plots = assert(services.PLOTS[key])
	local station_nodes = {forge = "grug_jobs:forge",
		tailor_bench = "grug_jobs:tailor_bench",
		brewing_stand = "grug_brewing:brewing_stand",
		tanning_rack = "grug_jobs:tanning_rack",
		carving_bench = "grug_jobs:carving_bench",
		jewellers_bench = "grug_jobs:jewellers_bench", furnace = "default:furnace"}
	local professions = {weaponsmith = true, armorsmith = true, tailor = true,
		alchemist = true, cooking = true, leatherworker = true,
		woodcarver = true, goldsmith = true}
	local faction = {human = "accord", dwarf = "accord", elf = "accord",
		orc = "throng", undead = "throng", troll = "throng"}
	local service_roles = {public_station = true, trainer = true,
		riding_trainer = true, mount_display = true, gear_display = true}
	local villager_entity = "grug_mobs:villager_" .. race
	-- Production capital_displays.lua positions the catalog's authored stand
	-- frame so this measured foot coordinate lands 0.02 nodes above the saved
	-- floor. Keep the witness independent of that private implementation table:
	-- a catalog/property match alone would not prove absolute grounding.
	local foot_y = {dwarf = -0.011460670, elf = -0.000000103,
		expert_accord = -0.160746604, expert_throng = 0.636211494,
		human = -0.001113216, master_accord = -0.214328805,
		master_throng = 0.890696092, orc = -0.006643265,
		t1_accord = -0.001113216, t1_throng = -0.001113216,
		troll = -0.016625724, undead = -0.018340415}

	local plot_by_id, boxes, plot_count = {}, {}, 0
	local canonical_ids = {}
	for _, plot in ipairs(plots) do plot_by_id[plot.id] = plot end
	for service, plot_id in pairs(expected_plots) do
		local plot = plot_by_id[plot_id]
		if not plot then fail("service plot is absent: " .. service .. "/" .. plot_id) end
		if boxes[plot_id] then fail("service plot is reused: " .. plot_id) end
		local bounds = plot.composition.bounds
		local base = grug_zones.terrain_height_at(
			anchor.x + plot.x + plot.composition.reference.x,
			anchor.z + plot.z + plot.composition.reference.z)
		boxes[plot_id] = {id = plot_id, service = service,
			min_x = anchor.x + plot.x + bounds.min.x,
			max_x = anchor.x + plot.x + bounds.max.x,
			min_y = base + bounds.min.y, max_y = base + bounds.max.y,
			min_z = anchor.z + plot.z + bounds.min.z,
			max_z = anchor.z + plot.z + bounds.max.z}
		plot_count = plot_count + 1
		local prefix = plot_id .. "/" .. plot_id .. "_"
		if service == "riding" then
			canonical_ids[prefix .. "riding"] = "riding_trainer"
			for tier = 1, 4 do
				canonical_ids[prefix .. "mount_" .. tier] = "mount_display"
			end
		else
			canonical_ids[prefix .. "station"] = "public_station"
			if service == "forge" then
				canonical_ids[prefix .. "weaponsmith"] = "trainer"
				canonical_ids[prefix .. "armorsmith"] = "trainer"
				canonical_ids[prefix .. "weapon"] = "gear_display"
				canonical_ids[prefix .. "armor"] = "gear_display"
			else
				canonical_ids[prefix .. service] = "trainer"
				if service == "goldsmith" then
					canonical_ids[prefix .. "jewel"] = "gear_display"
				end
			end
		end
	end
	if plot_count ~= 8 then fail("service plot count differs: " .. plot_count) end

	local sockets = grug_core.settlement_sockets_at(key)
	local selected, expected_entities = {}, {}
	local counts = {station = 0, trainer = 0, riding = 0, mount = 0, gear = 0}
	local seen_profession, seen_station, seen_mount, seen_gear = {}, {}, {}, {}
	local function owning_plot(socket)
		for plot_id, box in pairs(boxes) do
			if socket.id:sub(1, #plot_id + 1) == plot_id .. "/" then return box end
		end
		return nil
	end
	local function expect_position(socket, box)
		local p = socket.pos
		if p.x < box.min_x or p.x > box.max_x or p.y < box.min_y or
				p.y > box.max_y or p.z < box.min_z or p.z > box.max_z then
			fail("service socket left fitted plot: " .. socket.id)
		end
	end
	for _, socket in ipairs(sockets) do
		local box = owning_plot(socket)
		if service_roles[socket.role] then
			if not box then
				fail("service socket is outside mapped premises: " .. socket.id)
			end
			if canonical_ids[socket.id] ~= socket.role then
				fail("service socket canonical id/role differs: " .. socket.id)
			end
			expect_position(socket, box)
			selected[#selected + 1] = {socket = socket, box = box}
			if socket.role == "public_station" then
				local tag = socket.tags and socket.tags[1]
				if not station_nodes[tag] or seen_station[tag] then
					fail("public station tag differs: " .. tostring(tag))
				end
				seen_station[tag], counts.station = true, counts.station + 1
			elseif socket.role == "trainer" then
				if not professions[socket.profession] or seen_profession[socket.profession] then
					fail("profession trainer differs: " .. tostring(socket.profession))
				end
				seen_profession[socket.profession] = true
				counts.trainer = counts.trainer + 1
				expected_entities[socket.id] = socket
			elseif socket.role == "riding_trainer" then
				counts.riding = counts.riding + 1
				expected_entities[socket.id] = socket
			elseif socket.role == "mount_display" then
				local tag = socket.tags and socket.tags[1]
				if not ({["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true})[tag]
						or seen_mount[tag] then fail("mount display tag differs") end
				seen_mount[tag], counts.mount = true, counts.mount + 1
				expected_entities[socket.id] = socket
			else
				local tag = socket.tags and socket.tags[1]
				if not ({weapon = true, armor = true, jewel = true})[tag] or seen_gear[tag] then
					fail("gear display tag differs")
				end
				seen_gear[tag], counts.gear = true, counts.gear + 1
				expected_entities[socket.id] = socket
			end
		end
	end
	if counts.station ~= 7 or counts.trainer ~= 8 or counts.riding ~= 1 or
			counts.mount ~= 4 or counts.gear ~= 3 then
		fail("service socket totals differ")
	end

	local function same_list(a, b)
		if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
		for index = 1, #a do if a[index] ~= b[index] then return false end end
		return true
	end
	local function close_number(a, b)
		return type(a) == "number" and type(b) == "number" and
			a == a and b == b and a ~= math.huge and a ~= -math.huge and
			b ~= math.huge and b ~= -math.huge and math.abs(a - b) <= 0.00001
	end
	local function same_pair(a, b)
		return type(a) == "table" and type(b) == "table" and
			close_number(a.x, b.x) and close_number(a.y, b.y)
	end
	local function same_numeric_list(a, b)
		if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
		for index = 1, #a do
			if not close_number(a[index], b[index]) then return false end
		end
		return true
	end
	local function expected_mount(tag)
		local tier = tonumber(tag)
		local side = assert(faction[race])
		local id = tier == 1 and "t1_" .. side or tier == 2 and race or
			(tier == 3 and "expert_" or "master_") .. side
		return assert(grug_mounts.MODELS[id]), id
	end
	local function expected_gear(tag)
		return tag == "weapon" and grug_gear.weapon_item("sword", 1) or
			tag == "armor" and grug_gear.armor_item("chest", "metal", 1) or
			grug_gear.trinket_item("manawell", 1)
	end
	local function validate_node(row)
		local socket, p = row.socket, row.socket.pos
		local node = core.get_node_or_nil(p)
		if not node or node.name == "ignore" then return false, "unloaded:" .. socket.id end
		if socket.role == "public_station" then
			local wanted = station_nodes[socket.tags[1]]
			if node.name ~= wanted or not core.registered_nodes[node.name] then
				fail("public station node differs: " .. socket.id .. "/" .. node.name)
			end
			return true
		end
		local head = core.get_node_or_nil({x = p.x, y = p.y + 1, z = p.z})
		local ground = core.get_node_or_nil({x = p.x, y = p.y - 1, z = p.z})
		local ground_def = ground and core.registered_nodes[ground.name]
		local node_def = core.registered_nodes[node.name]
		local head_def = head and core.registered_nodes[head.name]
		if not ground_def or not ground_def.walkable or not node_def or node_def.walkable or
				not head_def or head_def.walkable then
			fail("service socket ground/headroom differs: " .. socket.id)
		end
		return true
	end

	local held, held_keys, hold_refused = {}, {}, 0
	local function hold(box)
		for x = math.floor(box.min_x / 16), math.floor(box.max_x / 16) do
			for y = math.floor(box.min_y / 16), math.floor(box.max_y / 16) do
				for z = math.floor(box.min_z / 16), math.floor(box.max_z / 16) do
					local p = {x = x * 16, y = y * 16, z = z * 16}
					local block_key = p.x .. ":" .. p.y .. ":" .. p.z
					if not held_keys[block_key] then
						if core.forceload_block(p, true) then
							held_keys[block_key] = true
							held[#held + 1] = p
						else
							hold_refused = hold_refused + 1
						end
					end
				end
			end
		end
	end
	local function release()
		for _, p in ipairs(held) do core.forceload_free_block(p, true) end
		held, held_keys, hold_refused = {}, {}, 0
	end

	local function inspect_entities()
		local found = {}
		for _, box in pairs(boxes) do
			local objects = core.get_objects_in_area(
				{x = box.min_x, y = box.min_y, z = box.min_z},
				{x = box.max_x, y = box.max_y, z = box.max_z})
			for _, object in ipairs(objects) do
				local entity = object:get_luaentity()
				if entity and entity._grug_start == key and
						service_roles[entity._grug_socket_role] then
					if not expected_entities[entity._grug_socket] then
						fail("unexpected service entity: " .. tostring(entity._grug_socket))
					end
					if found[entity._grug_socket] then
						fail("duplicate service entity: " .. entity._grug_socket)
					end
					found[entity._grug_socket] = entity
				end
			end
		end
		local missing = {}
		for id in pairs(expected_entities) do
			if not found[id] then missing[#missing + 1] = id end
		end
		table.sort(missing)
		return found, missing
	end

	local function validate_entity(socket, entity)
		if entity._grug_socket_role ~= socket.role then fail("entity role differs") end
		local p = entity.object:get_pos()
		if not p or math.abs(p.x - socket.pos.x) > 0.25 or
				math.abs(p.z - socket.pos.z) > 0.25 then
			fail("service entity left its authored position: " .. socket.id)
		end
		if socket.role == "trainer" then
			if entity.name ~= villager_entity or entity._grug_display_race ~= nil or
					entity._grug_profession ~= socket.profession or entity._grug_walker ~= false then
				fail("trainer configuration differs: " .. socket.id)
			end
		elseif socket.role == "riding_trainer" then
			if entity.name ~= villager_entity or entity._grug_display_race ~= nil or
					entity._grug_npc_name ~= "Riding Trainer" or entity._grug_walker ~= false then
				fail("Riding trainer configuration differs")
			end
		else
			local tag = socket.tags[1]
			if entity.name ~= "grug_mobs:capital_display" or
					entity._grug_display_race ~= race or entity._grug_display_tag ~= tag or
					entity._grug_display_floor ~= socket.pos.y - 0.5 then
				fail("display persisted configuration differs: " .. socket.id)
			end
			local props = entity.object:get_properties()
			local armor = entity.object:get_armor_groups()
			if props.physical ~= false or props.pointable ~= false or
					props.collide_with_objects ~= false or
					type(armor) ~= "table" or armor.immortal ~= 1 then
				fail("display intrinsic properties differ: " .. socket.id)
			end
			if socket.role == "mount_display" then
				local model, model_id = expected_mount(tag)
				local frames, speed, blend, loop = entity.object:get_animation()
				local stand = model.animation and model.animation.stand
				if props.visual ~= "mesh" or props.mesh ~= model.mesh or
						not same_list(props.textures, model.textures) or
						not same_pair(props.visual_size, model.visual_size) or
						not same_numeric_list(props.collisionbox, model.collisionbox) or
						props.nametag ~= model.description or not stand or
						not same_pair(frames, {x = stand[1], y = stand[1]}) or
						not close_number(speed, 0) or not close_number(blend, 0) or
						loop ~= false then
					fail("mount display catalog properties differ: " .. socket.id)
				end
				local expected_y = entity._grug_display_floor + 0.02 -
					assert(foot_y[model_id])
				if math.abs(p.y - expected_y) > 0.0001 then
					fail("mount display grounding differs: " .. socket.id)
				end
			else
				local item = expected_gear(tag)
				if props.visual ~= "wielditem" or props.textures[1] ~= item then
					fail("gear display item differs: " .. socket.id)
				end
				if not same_numeric_list(props.collisionbox, {0, 0, 0, 0, 0, 0}) then
					fail("gear display collision box differs: " .. socket.id)
				end
				if math.abs(p.y - socket.pos.y) > 0.25 then
					fail("gear display grounding differs: " .. socket.id)
				end
			end
		end
	end

	local function write_report(found, attempts)
		local rows = {"capital\tplot\tservice\tsocket\trole\ttag\tnode\tentity\tx\ty\tz\n"}
		table.sort(selected, function(a, b) return a.socket.id < b.socket.id end)
		for _, row in ipairs(selected) do
			local socket = row.socket
			local entity = found[socket.id]
			rows[#rows + 1] = table.concat({key, row.box.id, row.box.service,
				socket.id, socket.role,
				tostring(socket.profession or socket.tags and socket.tags[1] or ""),
				core.get_node(socket.pos).name, entity and entity.name or "-",
				socket.pos.x, socket.pos.y, socket.pos.z}, "\t") .. "\n"
		end
		local file = assert(io.open(worldpath .. "/" .. key .. "-services.tsv", "wb"))
		file:write(table.concat(rows)); assert(file:close())
		params.log({"event=services", "capital=" .. key, "plots=8", "stations=7",
			"profession_trainers=8", "riding_trainers=1", "mount_displays=4",
			"gear_displays=3", "entity_attempts=" .. attempts, "status=PASS"})
	end

	return function(done)
		local ordered = {}
		for _, box in pairs(boxes) do ordered[#ordered + 1] = box end
		table.sort(ordered, function(a, b) return a.id < b.id end)
		local pending, trouble = #ordered, 0
		for _, box in ipairs(ordered) do
			core.emerge_area({x = box.min_x, y = box.min_y, z = box.min_z},
				{x = box.max_x, y = box.max_y, z = box.max_z},
				function(_, action, calls_remaining)
					if action == core.EMERGE_ERRORED or action == core.EMERGE_CANCELLED then
						trouble = trouble + 1
					end
					if calls_remaining ~= 0 then return end
					pending = pending - 1
					if pending ~= 0 then return end
					if trouble ~= 0 then fail("service emerge failed: " .. trouble) end
					for _, held_box in ipairs(ordered) do hold(held_box) end
					if hold_refused ~= 0 then
						local refused = hold_refused
						release(); fail("service forceload refused: " .. refused)
					end
					local attempts = 0
					local function retry()
						attempts = attempts + 1
						local nodes_loaded = true
						for _, row in ipairs(selected) do
							local loaded = validate_node(row)
							if not loaded then nodes_loaded = false end
						end
						local found, missing = inspect_entities()
						if nodes_loaded and #missing == 0 then
							for id, socket in pairs(expected_entities) do
								validate_entity(socket, found[id])
							end
							write_report(found, attempts); release(); return done()
						end
						if attempts >= 16 then
							release(); fail("service nodes/entities absent after bounded heartbeat retries: " ..
								(nodes_loaded and table.concat(missing, ",") or "unloaded-node"))
						end
						core.after(1, retry)
					end
					core.after(0, retry)
				end)
		end
	end
end

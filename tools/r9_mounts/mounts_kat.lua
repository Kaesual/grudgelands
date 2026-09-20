return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/")

	local serialized, serial_id = {}, 0
	local registered_entities, registered_items = {}, {}
	local callbacks = {hp = {}, die = {}, leave = {}, shutdown = {}, join = {},
		allow_inventory = {}, inventory = {}}
	local players = {}
	local zone_mode = "ocean"
	local surface_height = 0
	local combat = false

	local function clone_table(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for key, item in pairs(value) do out[key] = clone_table(item) end
		return out
	end

	local Stack = {}
	Stack.__index = Stack
	function Stack:get_name() return self.name end
	function Stack:get_wear() return self.wear or 0 end
	function Stack:add_wear(amount) self.wear = (self.wear or 0) + amount end
	function Stack:get_meta()
		local owner = self
		return {
			set_string = function(_, key, value) owner.meta[key] = value end,
			get_string = function(_, key) return owner.meta[key] or "" end,
		}
	end
	function Stack:is_empty() return self.name == "" end
	function Stack:copy()
		local out = setmetatable({name = self.name, wear = self.wear or 0,
			meta = {}}, Stack)
		for key, value in pairs(self.meta) do out.meta[key] = value end
		return out
	end

	function ItemStack(value)
		if getmetatable(value) == Stack then return value:copy() end
		local name = tostring(value or ""):match("^(%S*)") or ""
		return setmetatable({name = name, wear = 0, meta = {}}, Stack)
	end

	local Inventory = {}
	Inventory.__index = Inventory
	function Inventory:get_lists() return {main = self.main} end
	function Inventory:get_size(name) return #(self[name] or {}) end
	function Inventory:get_stack(name, index)
		return (self[name][index] or ItemStack("")):copy()
	end
	function Inventory:set_stack(name, index, stack) self[name][index] = ItemStack(stack) end
	function Inventory:room_for_item(name)
		for index = 1, #self[name] do
			if self[name][index]:is_empty() then return true end
		end
		return false
	end
	function Inventory:add_item(name, stack)
		for index = 1, #self[name] do
			if self[name][index]:is_empty() then
				self[name][index] = ItemStack(stack)
				return ItemStack("")
			end
		end
		return ItemStack(stack)
	end

	local function new_player(name, level, faction, race)
		local meta_values = {}
		local player = {
			name = name, level = level, faction = faction, race = race,
			balance = 1000000, pos = {x = -100, y = 20, z = -100},
			velocity = {x = 2, y = 3, z = 4},
			properties = {hp_max = 100, eye_height = 1.625,
				visual_size = {x = 0.9, y = 0.9}},
			inventory = setmetatable({main = {}}, Inventory),
			control = {}, hud = {}, hp = 100,
		}
		for index = 1, 16 do player.inventory.main[index] = ItemStack("") end
		function player:is_player() return true end
		function player:get_player_name() return self.name end
		function player:get_meta()
			return {
				get_int = function(_, key) return meta_values[key] or 0 end,
				set_int = function(_, key, value) meta_values[key] = value end,
				get_string = function(_, key) return meta_values[key] or "" end,
				set_string = function(_, key, value) meta_values[key] = value end,
			}
		end
		function player:get_inventory() return self.inventory end
		function player:get_wielded_item()
			return self.inventory:get_stack("main", self.wield_index or 1)
		end
		function player:set_wielded_item(stack)
			self.wield_writes = (self.wield_writes or 0) + 1
			self.inventory:set_stack("main", self.wield_index or 1, stack)
		end
		function player:get_pos() return clone_table(self.pos) end
		function player:set_pos(pos) self.pos = clone_table(pos) end
		function player:get_velocity() return clone_table(self.velocity) end
		function player:add_velocity(value)
			self.velocity.x = self.velocity.x + value.x
			self.velocity.y = self.velocity.y + value.y
			self.velocity.z = self.velocity.z + value.z
		end
		function player:set_attach(object) self.attached = object end
		function player:get_attach() return self.attached end
		function player:set_detach() self.attached = nil end
		function player:set_eye_offset() end
		function player:set_properties(props)
			for key, value in pairs(props) do self.properties[key] = clone_table(value) end
		end
		function player:get_properties() return clone_table(self.properties) end
		function player:get_player_control() return self.control end
		function player:get_look_horizontal() return 0 end
		function player:get_look_dir() return {x = 0, y = 0, z = 1} end
		function player:get_eye_offset() return {x = 0, y = 0, z = 0} end
		function player:get_hp() return self.hp end
		function player:get_luaentity() return nil end
		function player:hud_add(def)
			local id = #self.hud + 1
			self.hud[id] = clone_table(def)
			return id
		end
		function player:hud_change(id, stat, value) self.hud[id][stat] = value end
		function player:hud_remove(id) self.hud[id] = nil end
		function player:punch(puncher, _, _, _)
			self.punches = (self.punches or 0) + 1
			self.was_attached_when_punched = self.attached ~= nil
			if self.replace_attacker_wield then
				puncher.inventory:set_stack("main", puncher.wield_index or 1,
					ItemStack(self.replace_attacker_wield))
				self.replace_attacker_wield = nil
			end
			if self.punch_result == "zero" then
				for _, callback in ipairs(callbacks.hp) do callback(self, 0, {}) end
			elseif self.punch_result == "damage" then
				self.hp = self.hp - 5
				for _, callback in ipairs(callbacks.hp) do callback(self, -5, {}) end
			end
			return self.punch_wear or 0
		end
		players[name] = player
		return player
	end

	local function new_object(pos)
		local object = {valid = true, pos = clone_table(pos),
			velocity = {x = 0, y = 0, z = 0}, yaw = 0}
		function object:is_valid() return self.valid end
		function object:is_player() return false end
		function object:get_pos() return clone_table(self.pos) end
		function object:set_pos(value) self.pos = clone_table(value) end
		function object:get_velocity() return clone_table(self.velocity) end
		function object:set_velocity(value) self.velocity = clone_table(value) end
		function object:set_acceleration(value) self.acceleration = clone_table(value) end
		function object:get_yaw() return self.yaw end
		function object:set_yaw(value) self.yaw = value end
		function object:set_properties(value) self.properties = clone_table(value) end
		function object:set_armor_groups(value) self.armor = clone_table(value) end
		function object:set_animation(value, speed) self.animation = {value, speed} end
		function object:get_luaentity() return self.entity end
		function object:remove() self.valid = false end
		return object
	end

	core = {
		registered_nodes = {air = {walkable = false, liquidtype = "none"}},
		registered_items = registered_items,
		get_current_modname = function() return "grug_mounts" end,
		get_modpath = function(name)
			if name == "grug_mounts" then return root .. "/mods/PLAYER/grug_mounts" end
			return root .. "/mods/PLAYER/" .. name
		end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
		formspec_escape = function(value) return tostring(value) end,
		serialize = function(value)
			serial_id = serial_id + 1
			local token = "serial:" .. serial_id
			serialized[token] = clone_table(value)
			return token
		end,
		deserialize = function(token) return clone_table(serialized[token]) end,
		register_entity = function(name, def) registered_entities[name] = def end,
		register_craftitem = function(name, def)
			registered_items[name] = def
		end,
		register_on_player_hpchange = function(func) callbacks.hp[#callbacks.hp + 1] = func end,
		register_on_dieplayer = function(func) callbacks.die[#callbacks.die + 1] = func end,
		register_on_leaveplayer = function(func) callbacks.leave[#callbacks.leave + 1] = func end,
		register_on_shutdown = function(func) callbacks.shutdown[#callbacks.shutdown + 1] = func end,
		register_on_joinplayer = function(func) callbacks.join[#callbacks.join + 1] = func end,
		register_allow_player_inventory_action = function(func)
			callbacks.allow_inventory[#callbacks.allow_inventory + 1] = func
		end,
		register_on_player_inventory_action = function(func)
			callbacks.inventory[#callbacks.inventory + 1] = func
		end,
		get_item_group = function(name, group)
			local definition = registered_items[name]
			return definition and definition.groups and definition.groups[group] or 0
		end,
		get_player_by_name = function(name) return players[name] end,
		after = function(_, func, ...) func(...) end,
		get_node_or_nil = function() return {name = "air"} end,
		chat_send_player = function(name, message)
			local player = players[name]
			if player then player.last_chat = message end
		end,
		show_formspec = function() end,
	}

	function core.add_entity(pos, name, staticdata)
		local def = assert(registered_entities[name])
		local object = new_object(pos)
		local entity = setmetatable({object = object}, {__index = def})
		object.entity = entity
		def.on_activate(entity, staticdata, 0)
		return object
	end

	vector = {
		new = function(x, y, z)
			if type(x) == "table" then return clone_table(x) end
			return {x = x, y = y, z = z}
		end,
		add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
		multiply = function(a, scale)
			return {x = a.x * scale, y = a.y * scale, z = a.z * scale}
		end,
		distance = function(a, b)
			local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
			return math.sqrt(x * x + y * y + z * z)
		end,
		normalize = function(a)
			local length = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
			return length == 0 and {x = 0, y = 0, z = 0} or
				{x = a.x / length, y = a.y / length, z = a.z / length}
		end,
	}
	player_api = {player_attached = {}, set_animation = function() end}
	grug_core = {
		in_combat = function() return combat end,
		get_player_faction = function(name)
			local player = players[name]
			return player and player.faction or nil
		end,
	}
	grug_visuals = {
		apply = function(player)
			local visual_size = {x = 0.9, y = 0.9}
			player:set_properties({visual_size = visual_size})
			return {visual_size = visual_size}
		end,
	}
	grug_xp = {get_level = function(player) return player.level end}
	grug_money = {
		take = function(player, amount)
			if player.balance < amount then return false end
			player.balance = player.balance - amount
			return true
		end,
		format = function(amount) return amount .. "c" end,
	}
	grug_factions = {
		get_faction = function(player) return player.faction end,
		register_on_faction_chosen = function(func) callbacks.faction = func end,
		hostile = function(first, second)
			return first.faction ~= nil and second.faction ~= nil and
				first.faction ~= second.faction
		end,
		same_faction = function(first, second)
			return first.faction ~= nil and first.faction == second.faction
		end,
	}
	grug_mobs = {is_noncombatant = function() return false end}
	grug_classes = {
		get_race = function(player) return player.race end,
		register_on_race_chosen = function(func) callbacks.race = func end,
	}
	grug_jobs = {register_trainer_hook = function(func) callbacks.trainer = func end}
	grug_zones = {
		water_class_at = function(x, z)
			if zone_mode == "ocean" and x >= 0 then return "deep_ocean" end
			if zone_mode == "review_bay" and x <= 615 and
					math.abs(z + 2200) < 0.01 then
				return "deep_ocean"
			end
			return "land"
		end,
		territory_rule_at = function(pos)
			if zone_mode == "vertical" and pos.y < 0 then return "contested_land" end
			if zone_mode == "battleground" then return "holy_grounds" end
			if zone_mode == "protected" or zone_mode == "protected_enemy" or
					zone_mode == "protected_contested" or
					zone_mode == "battleground_protected" then
				return "hard_protected"
			end
			if zone_mode == "enemy" and pos.z >= 0 then return "throng_home" end
			return "accord_home"
		end,
		at = function(pos)
			if zone_mode == "battleground" then
				return {territory_rule = "holy_grounds"}
			elseif zone_mode == "battleground_protected" and
					(pos.x == -2000 or pos.x == 2000) then
				return {territory_rule = "holy_grounds"}
			elseif zone_mode == "enemy" and pos.z >= 0 then
				return {territory_rule = "throng_home"}
			elseif zone_mode == "protected_enemy" then
				return {territory_rule = "throng_home"}
			elseif zone_mode == "protected_contested" then
				return {territory_rule = "contested_land"}
			elseif zone_mode == "oblique" and pos.x + pos.z >= 0 then
				return {territory_rule = "throng_home"}
			end
			return {territory_rule = "accord_home"}
		end,
		terrain_height_at = function() return surface_height end,
	}

	dofile(root .. "/mods/PLAYER/grug_mounts/init.lua")
	assert(grug_mounts.PRICES == grug_mounts.COORDINATOR_PLACEHOLDER_PRICES)
	assert(grug_mounts.PRICES[1] == 200 and grug_mounts.PRICES[2] == 1500 and
		grug_mounts.PRICES[3] == 24000 and grug_mounts.PRICES[4] == 100000)

	local buyer = new_player("buyer", 60, "accord", "human")
	assert(grug_mounts.purchase(buyer, 1))
	assert(buyer.inventory.main[1]:get_name() == grug_mounts.TIERS[1].item)
	assert(buyer.inventory.main[1]:get_meta():get_string("grug_mounts:owner") == "buyer")
	assert(grug_mounts.purchase(buyer, 2))
	assert(buyer.inventory.main[1]:get_name() == grug_mounts.TIERS[2].item)
	for index = 1, #buyer.inventory.main do
		assert(buyer.inventory.main[index]:get_name() ~= grug_mounts.TIERS[1].item)
	end
	assert(grug_mounts.purchase(buyer, 3))
	assert(grug_mounts.purchase(buyer, 4))
	local names = {}
	for index = 1, #buyer.inventory.main do
		local name = buyer.inventory.main[index]:get_name()
		if name ~= "" then names[name] = (names[name] or 0) + 1 end
	end
	assert(names[grug_mounts.TIERS[2].item] == 1)
	assert(names[grug_mounts.TIERS[4].item] == 1)
	assert(names[grug_mounts.TIERS[3].item] == nil)
	local function mount_count(player, mode)
		local count, stale = 0, 0
		for index = 1, #player.inventory.main do
			local stack = player.inventory.main[index]
			local definition = registered_items[stack:get_name()]
			if definition and definition._grug_mount_tier then
				local tier = grug_mounts.TIERS[definition._grug_mount_tier]
				if tier.mode == mode then count = count + 1 end
				if grug_mounts.highest_owned(player, tier.mode) ~=
						definition._grug_mount_tier then
					stale = stale + 1
				end
			end
		end
		return count, stale
	end
	local outbound = buyer.inventory.main[1]:copy()
	for _, callback in ipairs(callbacks.allow_inventory) do
		assert(callback(buyer, "take", buyer.inventory,
			{listname = "main", index = 1, stack = outbound}) == 0)
	end
	for _, callback in ipairs(callbacks.allow_inventory) do
		assert(callback(buyer, "move", buyer.inventory,
			{from_list = "main", to_list = "main", from_index = 1,
				to_index = 2, count = 1}) == nil)
	end
	-- A stale stack left in an external inventory before this rule can still be
	-- recovered. Relog first restores the canonical item; the subsequent put is
	-- reconciled immediately and cannot create a second usable mount.
	local chest_stack = ItemStack(grug_mounts.TIERS[1].item)
	chest_stack:get_meta():set_string("grug_mounts:owner", "buyer")
	for _, callback in ipairs(callbacks.join) do callback(buyer) end
	buyer.inventory.main[3] = chest_stack
	for _, callback in ipairs(callbacks.inventory) do
		callback(buyer, "put", buyer.inventory,
			{listname = "main", index = 3, stack = chest_stack})
	end
	local land_count, stale_count = mount_count(buyer, "land")
	assert(land_count == 1 and stale_count == 0)

	local upgrader = new_player("upgrader", 60, "accord", "human")
	assert(grug_mounts.purchase(upgrader, 1))
	local stashed = upgrader.inventory.main[1]:copy()
	assert(grug_mounts.purchase(upgrader, 2))
	upgrader.inventory.main[2] = stashed
	for _, callback in ipairs(callbacks.inventory) do
		callback(upgrader, "put", upgrader.inventory,
			{listname = "main", index = 2, stack = stashed})
	end
	land_count, stale_count = mount_count(upgrader, "land")
	assert(land_count == 1 and stale_count == 0 and
		upgrader.inventory.main[1]:get_name() == grug_mounts.TIERS[2].item)
	local thief = new_player("thief", 60, "accord", "human")
	thief:get_meta():set_int("grug_mounts:land_tier", 2)
	local stolen = buyer.inventory.main[1]
	registered_items[stolen:get_name()].on_use(stolen, thief)
	assert(grug_mounts.active.thief == nil and
		thief.last_chat == "That mount is not bound to this character.")

	for tier_id = 1, 4 do
		local tier = grug_mounts.TIERS[tier_id]
		local low = new_player("low" .. tier_id, tier.level - 1, "accord", "human")
		if tier_id > 1 then
			low:get_meta():set_int("grug_mounts:land_tier", tier_id >= 3 and 2 or 1)
		end
		if tier_id == 4 then low:get_meta():set_int("grug_mounts:flight_tier", 3) end
		local ok = grug_mounts.purchase(low, tier_id)
		assert(not ok, "level gate missing for tier " .. tier_id)
	end

	local rider = new_player("rider", 60, "accord", "human")
	rider:get_meta():set_int("grug_mounts:land_tier", 2)
	rider:get_meta():set_int("grug_mounts:flight_tier", 4)
	combat = true
	local mounted, message = grug_mounts.mount(rider, 1)
	assert(not mounted and message:find("combat", 1, true))
	combat = false

	zone_mode = "battleground"
	assert(grug_mounts.flight_state(rider, {x = 10, y = 30, z = 10}))
	zone_mode = "battleground_protected"
	assert(grug_mounts.flight_state(rider, {x = -2000, y = 100, z = 0}))
	assert(grug_mounts.flight_state(rider, {x = 2000, y = 100, z = 0}))
	zone_mode = "protected"
	assert(grug_mounts.flight_state(rider, {x = 10, y = 30, z = 10}))
	zone_mode = "protected_enemy"
	local legal, kind = grug_mounts.flight_state(rider, {x = 10, y = 30, z = 10})
	assert(not legal and kind == "enemy")
	zone_mode = "protected_contested"
	legal, kind = grug_mounts.flight_state(rider, {x = 10, y = 30, z = 10})
	assert(not legal and kind == "enemy")
	zone_mode = "vertical"
	assert(grug_mounts.flight_state(rider, {x = -100, y = 100, z = -100}))
	assert(grug_mounts.flight_state(rider, {x = -100, y = -701, z = -100}),
		"horizontal home ownership changed with altitude")
	zone_mode = "enemy"
	legal, kind = grug_mounts.flight_state(rider, {x = 10, y = 30, z = 1})
	assert(not legal and kind == "enemy")
	zone_mode = "ocean"
	assert(grug_mounts.warning_state(rider, {x = -47.9, y = 30, z = 0}) == "ocean")
	assert(grug_mounts.warning_state(rider, {x = -48.1, y = 30, z = 0}) == nil)
	zone_mode = "oblique"
	assert(grug_mounts.warning_state(rider,
		{x = -47.9 * math.sqrt(2), y = 30, z = 0}) == "enemy")
	assert(grug_mounts.warning_state(rider,
		{x = -48.1 * math.sqrt(2), y = 30, z = 0}) == nil)
	zone_mode = "open"
	local flight_state = grug_mounts.flight_state
	local probe_count = 0
	grug_mounts.flight_state = function(...)
		probe_count = probe_count + 1
		return flight_state(...)
	end
	assert(grug_mounts.warning_state(rider, {x = -100, y = 30, z = -100}) == nil)
	assert(probe_count == 112, "warning probe budget differs: " .. probe_count)
	grug_mounts.flight_state = flight_state
	zone_mode = "review_bay"
	assert(grug_mounts.flight_state(rider, {x = 616, y = 100, z = -2200}))
	assert(not grug_mounts.flight_state(rider, {x = 615, y = 100, z = -2200}))
	assert(grug_mounts.warning_state(rider,
		{x = 616, y = 100, z = -2200}) == "ocean",
		"reviewer bay-edge witness did not warn")
	local wp40 = root .. "/mods/MAPGEN/grug_mapgen/wp40"
	local common = dofile(root .. "/tools/wp40/r6/common.lua")
	local production_source = dofile(wp40 .. "/source/simple_map.lua")
	local production_module = dofile(wp40 .. "/zones.lua")({
		source = production_source,
		schemas = dofile(wp40 .. "/schemas.lua"),
		canonical = dofile(wp40 .. "/canonical.lua"),
		deterministic = dofile(wp40 .. "/deterministic.lua"),
		index128 = dofile(wp40 .. "/index128.lua"),
		horizontal_factory = dofile(wp40 .. "/simple_map.lua"),
		coupled_grade = dofile(wp40 .. "/coupled_grade.lua")(),
		height_factory = dofile(wp40 .. "/height.lua"),
		raw_sha256 = common.new_sha256(),
	})
	local fixture_zones = grug_zones
	grug_zones = production_module.new_with_planner_source_runtime("0", 1)
	assert(grug_zones.flight_boundary_distance == nil,
		"retired flight-boundary API remains public")
	assert(grug_mounts.flight_state(rider, {x = 616, y = 100, z = -2200}))
	assert(not grug_mounts.flight_state(rider, {x = 615, y = 100, z = -2200}))
	assert(grug_mounts.warning_state(rider,
		{x = 616, y = 100, z = -2200}) ~= nil,
		"production reviewer bay-edge witness did not warn")
	grug_zones = fixture_zones

	surface_height = 20
	rider.pos = {x = -100, y = 19, z = -100}
	mounted, message = grug_mounts.mount(rider, 3)
	assert(not mounted and message:find("underground", 1, true))
	surface_height = 0
	rider.pos = {x = -100, y = 30, z = -100}
	assert(grug_mounts.mount(rider, 3))
	local record = grug_mounts.active[rider.name]
	zone_mode = "open"
	rider.control = {}
	local warning_state = grug_mounts.warning_state
	local warning_calls = 0
	grug_mounts.warning_state = function(...)
		warning_calls = warning_calls + 1
		return warning_state(...)
	end
	for _ = 1, 3 do record.object.entity:on_step(0.25) end
	assert(warning_calls == 0, "warning scan ran before one second")
	record.object.entity:on_step(0.25)
	assert(warning_calls == 1, "warning scan did not run at one second")
	record.object.entity:on_step(0.5)
	assert(warning_calls == 1, "warning scan ran twice within one second")
	record.object.entity:on_step(0.5)
	assert(warning_calls == 2, "warning scan cadence differs")
	grug_mounts.warning_state = warning_state
	record.object.pos = {x = -100, y = 601, z = -100}
	rider.control = {jump = true}
	record.object.entity:on_step(0.1)
	assert(record.object.pos.y == 600 and record.object.velocity.y == 0)
	zone_mode = "ocean"
	record.object.pos = {x = 0, y = 100, z = -100}
	rider.velocity = {x = 3, y = 4, z = 5}
	record.object.entity:on_step(0.1)
	assert(grug_mounts.active[rider.name] == nil)
	assert(rider.velocity.x == 0 and rider.velocity.y == 0 and rider.velocity.z == 0)

	rider.pos = {x = -100, y = 30, z = -100}
	rider.control = {}
	assert(grug_mounts.mount(rider, 3))
	record = grug_mounts.active[rider.name]
	assert(record.object.armor.immortal == 1)
	assert(grug_mounts.entity_definition.initial_properties.pointable == true)
	assert(grug_mounts.entity_definition.initial_properties.static_save == false)
	assert(grug_mounts.entity_definition.drops == nil)
	assert(record.object.entity._grug_rider == rider)
	assert(math.abs(rider.properties.visual_size.x - 0.3) < 0.000001 and
		math.abs(rider.properties.visual_size.y - 0.3) < 0.000001)
	grug_visuals.apply(rider)
	assert(math.abs(rider.properties.visual_size.x - 0.3) < 0.000001 and
		math.abs(rider.properties.visual_size.y - 0.3) < 0.000001)

	-- Build ray hits from the actual selection geometry. This proves that the
	-- pointable mount covers the rendered rider instead of fabricating a hit.
	local attacker = new_player("attacker", 60, "throng", "orc")
	local box_indices = {x = {1, 4}, y = {2, 5}, z = {3, 6}}
	local function segment_box_hit(origin, destination, box, position)
		local enter, leave = 0, 1
		for _, axis in ipairs({"x", "y", "z"}) do
			local delta = destination[axis] - origin[axis]
			local indices = box_indices[axis]
			local lower = position[axis] + box[indices[1]]
			local upper = position[axis] + box[indices[2]]
			if math.abs(delta) < 0.0000001 then
				if origin[axis] < lower or origin[axis] > upper then return nil end
			else
				local first = (lower - origin[axis]) / delta
				local second = (upper - origin[axis]) / delta
				if first > second then first, second = second, first end
				enter = math.max(enter, first)
				leave = math.min(leave, second)
				if enter > leave then return nil end
			end
		end
		return {
			x = origin.x + (destination.x - origin.x) * enter,
			y = origin.y + (destination.y - origin.y) * enter,
			z = origin.z + (destination.z - origin.z) * enter,
		}
	end
	local mount_pos = record.object:get_pos()
	local seat_y = record.model.attach_y * record.model.visual_size.y / 10
	local aim_y = mount_pos.y + seat_y + 1.4
	attacker.pos = {x = mount_pos.x, y = aim_y - attacker.properties.eye_height,
		z = mount_pos.z - 3}
	attacker.look_dir = {x = 0, y = 0, z = 1}
	function attacker:get_look_dir() return clone_table(self.look_dir) end
	core.raycast = function(origin, destination)
		local hit = segment_box_hit(origin, destination,
			record.object.properties.selectionbox, mount_pos)
		local yielded = false
		return function()
			if yielded or not hit then return nil end
			yielded = true
			return {type = "object", ref = record.object,
				intersection_point = hit}
		end
	end
	dofile(root .. "/mods/CORE/grug_core/combat_ray.lua")
	local function acquire_mount_hit()
		return grug_core.combat_ray(attacker, 4)
	end
	local swing_target = acquire_mount_hit()
	local cast_target = acquire_mount_hit()
	assert(swing_target.status == "target" and swing_target.target == rider)
	assert(cast_target.status == "target" and cast_target.target == rider)
	assert(swing_target.pointed.ref == record.object and
		cast_target.pointed.ref == record.object)

	-- Swept projectiles retain the mount intersection point but settle on the
	-- rider through the production collision seam.
	grug_projectiles = {}
	dofile(root .. "/mods/ENTITIES/grug_projectiles/collision.lua")
	local projectile = {}
	local origin = {x = mount_pos.x, y = aim_y, z = mount_pos.z - 3}
	local projectile_hit = grug_projectiles.trace_segment(attacker, projectile,
		origin, {x = mount_pos.x, y = aim_y, z = mount_pos.z + 3})
	assert(projectile_hit.kind == "object" and projectile_hit.target == rider and
		projectile_hit.pointed.ref == record.object)

	-- mobs_redo redirects a melee hit on an attached player to get_attach().
	-- The pointable mount forwards it through PlayerRef:punch; only accepted HP
	-- loss reaches the existing final HP callback and dismounts.
	local function attached_mob_melee(target, puncher)
		local redirected = target:get_attach() or target
		redirected:get_luaentity():on_punch(puncher, 1,
			{damage_groups = {fleshy = 5}}, {x = 1, y = 0, z = 0})
	end
	local tool_attacker = new_player("tool_attacker", 60, "throng", "orc")
	tool_attacker.inventory.main[1] = ItemStack("test:old_tool")
	rider.punch_result = "zero"
	rider.punch_wear = 321
	rider.replace_attacker_wield = "test:replacement_tool"
	attached_mob_melee(rider, tool_attacker)
	assert(tool_attacker:get_wielded_item():get_name() == "test:replacement_tool" and
		tool_attacker:get_wielded_item():get_wear() == 321 and
		tool_attacker.wield_writes == 1,
		"forwarded wear was not written to the post-punch wielded stack")
	tool_attacker.inventory.main[1] = ItemStack("grug_abilities:strike")
	rider.punch_wear = 0
	local writes_before = tool_attacker.wield_writes
	attached_mob_melee(rider, tool_attacker)
	assert(tool_attacker:get_wielded_item():get_wear() == 0 and
		tool_attacker.wield_writes == writes_before,
		"use-zero ability stack received forwarded wear")
	local punches_before = rider.punches
	local friendly_mob = new_object({x = 0, y = 0, z = 0})
	rider.punch_result = "friendly"
	attached_mob_melee(rider, friendly_mob)
	assert(rider.punches == punches_before + 1 and rider.was_attached_when_punched and
		grug_mounts.active[rider.name] ~= nil)
	rider.punch_result = "zero"
	attached_mob_melee(rider, friendly_mob)
	assert(rider.punches == punches_before + 2 and grug_mounts.active[rider.name] ~= nil)
	rider.punch_result = "damage"
	attached_mob_melee(rider, friendly_mob)
	assert(rider.punches == punches_before + 3 and rider.hp == 95 and
		grug_mounts.active[rider.name] == nil)
	assert(math.abs(rider.properties.visual_size.x - 0.9) < 0.000001 and
		math.abs(rider.properties.visual_size.y - 0.9) < 0.000001)

	local price_viewer = new_player("price_viewer", 60, "accord", "human")
	local extension = callbacks.trainer({action = "formspec", player = price_viewer,
		profession = "blacksmith"})
	assert(extension.size == "size[9.25,5.15]" and #extension.fragments >= 7)
	local trainer_text = table.concat(extension.fragments, "|")
	for _, price in ipairs(grug_mounts.PRICES) do
		assert(trainer_text:find("Buy " .. price .. "c", 1, true))
	end

	local ledgers = {
		[root .. "/mods/PLAYER/grug_mounts/LICENSE-media.md"] = true,
		[root .. "/mods/ENTITIES/grug_mobs/LICENSE-media.md"] = true,
	}
	local ledger_text = ""
	for path in pairs(ledgers) do
		local file = assert(io.open(path, "rb"))
		ledger_text = ledger_text .. assert(file:read("*a"))
		file:close()
	end
	local seen = {}
	local seen_icons = {}
	local expected_ranges = {
		grug_mounts_horse = {1, 41}, grug_mounts_tiger = {1, 300},
		grug_mobs_ibex = {1, 400}, grug_mobs_stag = {1, 150},
		grug_mobs_boar = {1, 82}, grug_mobs_wolf = {1, 92},
		grug_mobs_eagle = {1, 350}, grug_mobs_cave_bat = {1, 81},
	}
	local expected_attachment_heights = {
		t1_accord = 1.26, t1_throng = 1.26, human = 1.26,
		dwarf = 1.2325, elf = 1.52, orc = 1.271, undead = 1.428,
		troll = 1.189, expert_accord = 1.86, master_accord = 2.56,
		expert_throng = 1.92, master_throng = 2.856,
	}
	local audit_b3d = dofile(root .. "/tools/r9_mounts/b3d_audit.lua")
	for _, model in pairs(grug_mounts.MODELS) do
		assert(type(model.icon) == "string" and
			model.icon:match("^grug_mounts_icon_[%w_]+%.png$"),
			model.id .. " has no rendered inventory icon")
		assert(not seen_icons[model.icon], model.id .. " shares a rendered icon")
		seen_icons[model.icon] = true
		local icon_file = assert(io.open(root ..
			"/mods/PLAYER/grug_mounts/textures/" .. model.icon, "rb"))
		icon_file:close()
		assert(ledger_text:find("`grug_mounts_icon_*.png`", 1, true),
			"rendered mount icons have no ledger row")
		local effective_attachment = model.attach_y * model.visual_size.y / 10
		assert(math.abs(effective_attachment -
			expected_attachment_heights[model.id]) < 0.000001,
			model.id .. " effective attachment height differs")
		local rider_ray_y = effective_attachment + 1.79
		assert(segment_box_hit({x = -4, y = rider_ray_y, z = 0},
			{x = 4, y = rider_ray_y, z = 0}, model.selectionbox,
			{x = 0, y = 0, z = 0}),
			model.id .. " selection box misses the seated rider")
		assert(not segment_box_hit({x = -4, y = model.selectionbox[5] + 0.01, z = 0},
			{x = 4, y = model.selectionbox[5] + 0.01, z = 0},
			model.selectionbox, {x = 0, y = 0, z = 0}),
			model.id .. " geometric ray helper accepted a ray above the box")
		assert(model.selectionbox[5] > model.collisionbox[5],
			model.id .. " has no dedicated rider selection region")
		if not seen[model.mesh] then
			seen[model.mesh] = true
			local path
			if model.mesh:find("^grug_mounts_") then
				path = root .. "/mods/PLAYER/grug_mounts/models/" .. model.mesh
			else
				path = root .. "/mods/ENTITIES/grug_mobs/models/" .. model.mesh
			end
			local audit = audit_b3d(path)
			local stem = model.mesh:gsub("%.b3d$", "")
			local range = assert(expected_ranges[stem])
			assert(audit.min_frame == range[1] and audit.max_frame == range[2],
				model.mesh .. " keyed range differs")
			assert(ledger_text:find("`" .. model.mesh .. "`", 1, true),
				model.mesh .. " has no ledger row")
		end
		local maximum = expected_ranges[model.mesh:gsub("%.b3d$", "")][2]
		assert(model.animation.stand[2] <= maximum and
			model.animation.move[2] <= maximum,
			model.id .. " animation exceeds its mesh")
	end
	local icon_count = 0
	for _ in pairs(seen_icons) do icon_count = icon_count + 1 end
	assert(icon_count == 12, "mount icon count differs")

	return "r9_mounts_v3|tiers=4|models=12|warning=48|warning_probes=112|" ..
		"warning_interval=1|ceiling=600|assets=" ..
		tostring((function() local count = 0 for _ in pairs(seen) do count = count + 1 end return count end)()) .. "\n"
end

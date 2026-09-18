-- R8-TAGS known-answer test for observer-managed tag carriers and the real
-- mob/NPC/vendor text paths.
-- Usage: lua kat.lua /absolute/repository/root
-- MUTATION=1 distance, 2 owner exclusion, 3 productive mob text call,
-- 4 orphan removal, 5 static_save, 6 pointable, 7 duplicate carrier,
-- 8 vendor install,
-- 9 villager install, 10 forbidden parent write.

local function run(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")
	local mutation = tonumber(os.getenv("MUTATION") or "") or 0
	local saved = {
		core = rawget(_G, "core"),
		grug_core = rawget(_G, "grug_core"),
		grug_mobs = rawget(_G, "grug_mobs"),
		grug_zones = rawget(_G, "grug_zones"),
		mobs = rawget(_G, "mobs"),
		vector = rawget(_G, "vector"),
		grug_traders = rawget(_G, "grug_traders"),
		grug_classes = rawget(_G, "grug_classes"),
		grug_factions = rawget(_G, "grug_factions"),
		math_round = math.round,
	}

	local function equal(actual, expected, label)
		if actual ~= expected then
			error("r8 tags: " .. label .. ": expected " .. tostring(expected) ..
				", got " .. tostring(actual), 0)
		end
	end

	local function keys(set)
		local result = {}
		for key in pairs(set or {}) do result[#result + 1] = key end
		table.sort(result)
		return table.concat(result, ",")
	end

	local function read(path)
		local file = assert(io.open(path, "rb"))
		local value = file:read("*a")
		file:close()
		return value
	end

	local callbacks = {globalstep = {}, mods_loaded = {}}
	local entity_defs = {}
	local mob_defs = {}
	local players = {}
	local add_entity_calls = 0

	local function new_object(properties)
		local object = {
			valid = true,
			properties = properties or {},
			property_writes = 0,
			observer_writes = 0,
			observers = nil,
			pos = {x = 0, y = 0, z = 0},
		}
		function object:is_valid() return self.valid end
		function object:get_pos() return self.pos end
		function object:get_properties() return self.properties end
		function object:set_properties(values)
			self.property_writes = self.property_writes + 1
			for key, value in pairs(values) do self.properties[key] = value end
		end
		function object:set_attach(parent) self.parent = parent end
		function object:get_attach() return self.parent end
		function object:set_observers(value)
			self.observer_writes = self.observer_writes + 1
			self.observers = value
		end
		function object:get_luaentity() return self.entity end
		function object:set_armor_groups(value) self.armor_groups = value end
		function object:set_yaw(value) self.yaw = value end
		function object:get_velocity() return {x = 0, y = 0, z = 0} end
		function object:remove()
			if mutation ~= 4 then self.valid = false end
		end
		return object
	end

	core = {
		registered_entities = entity_defs,
		registered_items = {},
		registered_nodes = {},
		get_connected_players = function() return players end,
		register_globalstep = function(fn)
			callbacks.globalstep[#callbacks.globalstep + 1] = fn
		end,
		register_on_mods_loaded = function(fn)
			callbacks.mods_loaded[#callbacks.mods_loaded + 1] = fn
		end,
		register_entity = function(name, def)
			entity_defs[name:gsub("^:", "")] = def
		end,
		add_entity = function(pos, name)
			add_entity_calls = add_entity_calls + 1
			local def = assert(entity_defs[name], "registered carrier entity")
			local object = new_object({})
			object.pos = {x = pos.x, y = pos.y, z = pos.z}
			object.entity = {name = name, object = object}
			def.on_activate(object.entity)
			return object
		end,
		global_exists = function() return false end,
		log = function() end,
		after = function(_, fn) fn() end,
		get_gametime = function() return 0 end,
		chat_send_player = function() end,
		dir_to_yaw = function() return 0 end,
		get_objects_inside_radius = function() return {} end,
		find_path = function() return nil end,
	}

	vector = {
		distance = function(a, b)
			local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
			return math.sqrt(dx * dx + dy * dy + dz * dz)
		end,
	}
	math.round = function(value) return math.floor(value + 0.5) end
	grug_core = {}
	dofile(repo .. "/mods/CORE/grug_core/tag_carrier.lua")

	local carrier_def = assert(entity_defs["grug_core:tag_carrier"])
	if mutation == 5 then carrier_def.initial_properties.static_save = true end
	if mutation == 6 then carrier_def.initial_properties.pointable = true end
	equal(carrier_def.initial_properties.static_save, false, "carrier is unsaved")
	equal(carrier_def.initial_properties.pointable, false, "carrier is non-pointable")
	equal(carrier_def.on_step, nil, "carrier has no per-step callback")

	local function tick()
		for index = 1, #callbacks.globalstep do callbacks.globalstep[index](1) end
	end

	local function new_player(name, x)
		local player = new_object({
			selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
		})
		player.name = name
		player.pos = {x = x, y = 0, z = 0}
		function player:get_player_name() return self.name end
		function player:is_player() return true end
		return player
	end

	local parent = new_object({
		selectionbox = {-0.4, -0.2, -0.4, 0.4, 2.1, 0.4},
		nametag = "",
	})
	local alice = new_player("Alice", 24)
	local bob = new_player("Bob", 27)
	local cara = new_player("Cara", 31)
	players = {alice, bob, cara}

	local carrier = assert(grug_core.create_tag_carrier(parent), "carrier created")
	local real_create = grug_core.create_tag_carrier
	if mutation == 7 then
		grug_core.create_tag_carrier = function(object)
			local duplicate = core.add_entity(object:get_pos(),
				"grug_core:tag_carrier")
			duplicate:set_attach(object)
			return duplicate
		end
	end
	local second_carrier = grug_core.create_tag_carrier(parent)
	equal(second_carrier == carrier, true, "one carrier per parent")
	grug_core.create_tag_carrier = real_create
	equal(add_entity_calls, 1, "duplicate carrier creation avoided")
	equal(carrier.parent, parent, "carrier attachment")
	equal(carrier.properties.selectionbox[5], 2.1,
		"parent nametag height retained")
	equal(carrier.observer_writes, 1,
		"activation writes empty observer set once")

	tick()
	if mutation == 1 then carrier.observers.Cara = true end
	equal(keys(carrier.observers), "Alice", "initial per-viewer show set")
	equal(carrier.observer_writes, 2, "initial set written once")
	tick()
	equal(carrier.observer_writes, 2, "unchanged set not resent")

	alice.pos.x = 27
	bob.pos.x = 24
	tick()
	equal(keys(carrier.observers), "Alice,Bob",
		"independent hysteresis states")
	alice.pos.x = 31
	tick()
	equal(keys(carrier.observers), "Bob", "hide beyond thirty")

	local owner = "Alice"
	if mutation == 2 then owner = nil end
	local player_carrier = grug_core.create_tag_carrier(alice, owner)
	alice.pos.x = 0
	bob.pos.x = 10
	cara.pos.x = 40
	tick()
	equal(keys(player_carrier.observers), "Bob",
		"owner excluded from own carrier")

	parent.valid = false
	tick()
	equal(carrier.valid, false, "central pass removes orphan")

	-- Real combat-mob text path: levels.lua owns tier, telegraph and HP text,
	-- and its update_tag writes through the real carrier module above.
	grug_mobs = {}
	function grug_mobs.ensure_tag_carrier(entity)
		entity.temp = entity.temp or {}
		local child = entity.temp.grug_tag_carrier
		if child and child:is_valid() then return child end
		child = grug_core.create_tag_carrier(entity.object)
		entity.temp.grug_tag_carrier = child
		entity.object:set_properties({nametag = ""})
		return child
	end
	mobs = {scale_mob = function() end}
	grug_zones = {mob_level_at = function() return 8 end,
		guard_level_at = function() return 8 end}
	grug_core.format_k = function(value) return tostring(value) end
	dofile(repo .. "/mods/ENTITIES/grug_mobs/levels.lua")

	local mob_parent = new_object({hp_max = 10, selectionbox =
		{-0.4, -0.2, -0.4, 0.4, 1.5, 0.4}, nametag = "forbidden"})
	local mob = {name = "test:boar", description = "Boar", object = mob_parent,
		health = 10, base_texture = {"boar.png"}, armor = 100}
	mob_parent.entity = mob
	grug_mobs.register_level_cfg(mob.name,
		{_grug_tier = "elite", _grug_fixed_level = 8})
	local real_text_writer = grug_core.set_tag_carrier_text
	if mutation == 3 then grug_core.set_tag_carrier_text = function() return false end end
	grug_mobs.ensure_init(mob)
	local mob_carrier = assert(mob.temp.grug_tag_carrier,
		"real mob update created carrier")
	equal(mob_parent.properties.nametag, "", "combat parent remains empty")
	equal(mob_carrier.properties.nametag, grug_mobs.tag_text(mob),
		"real tier and HP text propagation")
	mob.health = 21
	mob.temp.grug_telegraph = true
	grug_mobs.update_tag(mob)
	equal(mob_carrier.properties.nametag,
		"!! Elite Boar [Lv 8] 21/307",
		"real telegraph and changed HP propagation")
	grug_core.set_tag_carrier_text = real_text_writer

	-- Minimal registration environment, but the files and after_activate
	-- closures are the real production villager and vendor install paths.
	function grug_mobs.set_plain_tag(entity, text)
		grug_core.set_tag_carrier_text(grug_mobs.ensure_tag_carrier(entity), text)
	end
	function grug_mobs.noncombatant(definition) return definition end
	function grug_mobs.face_yaw() end
	function grug_mobs.start_npc_claim() return true end
	function grug_mobs.stall_clear() end
	function grug_mobs.stall_clock() return 0 end
	function grug_mobs.walk_toward() end
	function grug_mobs.snap_try() return false end
	function grug_mobs.nearest_player_d2() return nil end
	mobs.register_mob = function(_, name, definition) mob_defs[name] = definition end
	grug_core.start_identities = function()
		return {{race_id = "dwarf", faction_id = "accord"}}
	end
	grug_core.faction_ids = {"accord"}
	grug_core.factions = {accord = {name = "Accord"}}
	grug_core.capital_anchor = function() return {x = 0, y = 0, z = 0} end
	grug_core.settlement_socket_settlements = function() return {} end
	grug_core.settlement_sockets_at = function() return {} end
	grug_classes = {registered_races = {
		dwarf = {name = "Dwarf", faction = "accord"},
	}}
	grug_factions = {}
	grug_traders = {RACE_DISCOUNT = 0.1,
		discounted_price = function(value) return value end,
		show_trade = function() end}

	dofile(repo .. "/mods/ENTITIES/grug_mobs/start_villagers.lua")
	dofile(repo .. "/mods/ENTITIES/grug_traders/vendors.lua")

	local function tagged_entity(name)
		local object = new_object({selectionbox =
			{-0.3, 0, -0.3, 0.3, 1.7, 0.3}, nametag = ""})
		local entity = {name = name, object = object, temp = {}}
		object.entity = entity
		return entity
	end

	local vendor = tagged_entity("grug_traders:vendor_general_accord")
	local real_plain_tag = grug_mobs.set_plain_tag
	if mutation == 8 then grug_mobs.set_plain_tag = function() end end
	assert(mob_defs[vendor.name] and mob_defs[vendor.name].after_activate,
		"real vendor definition registered")
	mob_defs[vendor.name].after_activate(vendor)
	equal(vendor.temp.grug_tag_carrier ~= nil, true,
		"real vendor install created carrier")
	equal(vendor.temp.grug_tag_carrier.properties.nametag,
		"Accord Quartermaster", "real vendor install text")
	grug_mobs.set_plain_tag = real_plain_tag

	local villager = tagged_entity("grug_mobs:villager_dwarf")
	if mutation == 9 then grug_mobs.set_plain_tag = function() end end
	assert(mob_defs[villager.name] and mob_defs[villager.name].after_activate,
		"real villager definition registered")
	mob_defs[villager.name].after_activate(villager)
	equal(villager.temp.grug_tag_carrier ~= nil, true,
		"real villager install created carrier")
	equal(villager.temp.grug_tag_carrier.properties.nametag,
		"Vale Dwarf", "real villager install text")
	grug_mobs.set_plain_tag = real_plain_tag

	-- Pin every remaining parent write: mobs_redo's base updater and reset
	-- stick may only clear the parent, while players use the alpha-zero seam.
	local api_source = read(repo .. "/mods/ENTITIES/mobs/api.lua")
	if mutation == 10 then
		api_source = api_source .. "\nnametag = self._nametag\n"
	end
	equal(api_source:find("nametag = self._nametag", 1, true) == nil, true,
		"vendored base updater cannot expose a parent nametag")
	assert(api_source:find('set_properties({nametag = ""})', 1, true),
		"vendored base updater does not permanently clear parent")
	local crafts_source = read(repo .. "/mods/ENTITIES/mobs/crafts.lua")
	assert(crafts_source:find('set_properties({nametag = ""})', 1, true),
		"mob reset can expose a parent nametag")
	local faction_source = read(repo .. "/mods/PLAYER/grug_factions/init.lua")
	assert(faction_source:find("local TAG_HIDDEN = {a = 0", 1, true),
		"player parent tag is not alpha-zero")

	local output = table.concat({
		"r8_tags=central_1hz observers_Alice_then_Alice+Bob_then_Bob",
		"owner_excluded unsaved_nonpointable single_carrier lifecycle_removed",
		"real_mob=elite_telegraph_hp real_vendor real_villager parent_empty",
	}, " ") .. "\n"

	rawset(_G, "core", saved.core)
	rawset(_G, "grug_core", saved.grug_core)
	rawset(_G, "grug_mobs", saved.grug_mobs)
	rawset(_G, "grug_zones", saved.grug_zones)
	rawset(_G, "mobs", saved.mobs)
	rawset(_G, "vector", saved.vector)
	rawset(_G, "grug_traders", saved.grug_traders)
	rawset(_G, "grug_classes", saved.grug_classes)
	rawset(_G, "grug_factions", saved.grug_factions)
	math.round = saved.math_round
	return output
end

return run

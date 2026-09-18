-- Round-6 H6 known-answer test. Loads the real combat/ability, suffocation
-- and Character-page modules under minimal Lua 5.1 engine stubs.
--
-- MUTATION=1 restores invalid-explicit friendly refusal.
-- MUTATION=2 removes the noclip suffocation exemption.
-- MUTATION=3 restores current/max pool text on the Character page.
-- MUTATION=4 forces an unchanged tooltip metadata write.
-- MUTATION=5 makes the shield tooltip use the flooring damage scaler.
-- MUTATION=6 makes the Smite tooltip depend on the current absorb state.
-- MUTATION=7 restores a separate item-level multiplier on the Help page.

return function(repo)
	local mutation = tonumber(os.getenv("MUTATION") or "") or 0

	local function fail(message)
		error("r6 hotfix: " .. message, 0)
	end

	local function want(condition, message)
		if not condition then
			fail(message)
		end
	end

	local function equal(actual, expected, message)
		if actual ~= expected then
			fail(message .. ": expected " .. tostring(expected) ..
				", got " .. tostring(actual))
		end
	end

	local function load_in(env, path)
		local chunk, load_error = loadfile(repo .. "/" .. path)
		if not chunk then
			fail("cannot load " .. path .. ": " .. tostring(load_error))
		end
		setfenv(chunk, env)
		local ok, result = pcall(chunk)
		if not ok then
			fail("loading " .. path .. " failed: " .. tostring(result))
		end
		return result
	end

	local function stub_table(fields)
		return setmetatable(fields or {}, {__index = function(t, key)
			local noop = function() end
			rawset(t, key, noop)
			return noop
		end})
	end

	local vector_stub = {}
	function vector_stub.new(x, y, z)
		if type(x) == "table" then
			return {x = x.x, y = x.y, z = x.z}
		end
		return {x = x or 0, y = y or 0, z = z or 0}
	end
	function vector_stub.add(a, b)
		return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
	end
	function vector_stub.subtract(a, b)
		return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z}
	end
	function vector_stub.multiply(a, n)
		return {x = a.x * n, y = a.y * n, z = a.z * n}
	end
	function vector_stub.offset(a, x, y, z)
		return {x = a.x + x, y = a.y + y, z = a.z + z}
	end
	function vector_stub.distance(a, b)
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end
	function vector_stub.length(a)
		return vector_stub.distance(a, {x = 0, y = 0, z = 0})
	end
	function vector_stub.normalize(a)
		local length = vector_stub.length(a)
		if length == 0 then
			return {x = 0, y = 0, z = 0}
		end
		return {x = a.x / length, y = a.y / length, z = a.z / length}
	end
	function vector_stub.direction(a, b)
		return vector_stub.normalize(vector_stub.subtract(b, a))
	end
	function vector_stub.round(a)
		return vector_stub.new(a)
	end

	local Stack = {}
	Stack.__index = Stack
	local function new_stack(value)
		local stack = setmetatable({name = "", wear = 0, strings = {}, floats = {},
			set_string_calls = 0}, Stack)
		if getmetatable(value) == Stack then
			stack.name = value.name
			stack.wear = value.wear
			stack.caps = value.caps
			for key, item in pairs(value.strings) do
				stack.strings[key] = item
			end
			for key, item in pairs(value.floats) do
				stack.floats[key] = item
			end
		elseif type(value) == "string" then
			stack.name = value
		end
		return stack
	end
	function Stack:get_name() return self.name end
	function Stack:is_empty() return self.name == "" end
	function Stack:equals(other) return self.name == other.name end
	function Stack:get_wear() return self.wear end
	function Stack:set_wear(value) self.wear = value end
	function Stack:get_tool_capabilities()
		return self.caps or {full_punch_interval = 0.9,
			damage_groups = {fleshy = 1}}
	end
	function Stack:get_meta()
		local owner = self
		return {
			get_string = function(_, key) return owner.strings[key] or "" end,
			set_string = function(_, key, value)
				owner.strings[key] = value
				owner.set_string_calls = owner.set_string_calls + 1
			end,
			get_float = function(_, key) return owner.floats[key] or 0 end,
			set_float = function(_, key, value) owner.floats[key] = value end,
			set_tool_capabilities = function(_, value) owner.caps = value end,
			set_wear_bar_params = function() end,
		}
	end

	local registered_items = {}
	local projectile_defs = {}
	local ability_env
	local core_stub = {
		registered_items = registered_items, registered_tools = registered_items,
		registered_nodes = {}, registered_entities = {},
		get_us_time = function() return 0 end,
		get_gametime = function() return 0 end,
		get_connected_players = function() return {} end,
		get_objects_inside_radius = function() return {} end,
		get_player_by_name = function() return nil end,
		get_current_modname = function() return "grug_abilities" end,
		get_modpath = function(name)
			if name == "grug_core" then
				return repo .. "/mods/CORE/grug_core"
			end
			return repo .. "/mods/PLAYER/" .. name
		end,
		register_tool = function(name, def)
			registered_items[name] = def
		end,
		global_exists = function() return false end,
		colorize = function(_, text) return text end,
		log = function() end,
	}
	setmetatable(core_stub, {__index = function(t, key)
		local noop = function() end
		rawset(t, key, noop)
		return noop
	end})

	local class_callbacks, talent_callbacks, level_callbacks = {}, {}, {}
	local class_defs = {
		warrior = {name = "Warrior", resource = "rage", growth = {str = 3, int = 0}},
		mage = {name = "Mage", resource = "mana", growth = {str = 0, int = 3}},
		priest = {name = "Priest", resource = "mana", growth = {str = 1, int = 2}},
	}
	local classes = {
		registered_classes = class_defs,
		get_class = function(player) return player.class end,
		get_class_def = function(player) return class_defs[player.class] end,
		get_race_perk = function() return 0 end,
		get_talent_bonus = function(player, key)
			return player.talents and player.talents[key] or 0
		end,
		get_spell_power_bonus = function(player)
			local growth = class_defs[player.class].growth.int
			return math.floor((10 + growth * (player.level - 1)) / 10)
		end,
		get_melee_bonus = function() return 1 end,
		get_max_mana = function() return 30 end,
		register_on_class_chosen = function(fn)
			class_callbacks[#class_callbacks + 1] = fn
		end,
		register_on_talents_changed = function(fn)
			talent_callbacks[#talent_callbacks + 1] = fn
		end,
	}
	local xp = {
		get_level = function(player) return player.level end,
		register_on_level_change = function(fn)
			level_callbacks[#level_callbacks + 1] = fn
		end,
	}
	local factions = {
		same_faction = function(a, b) return a.faction == b.faction end,
		hostile = function(a, b) return a.faction ~= b.faction end,
		get_faction = function(player) return player.faction end,
	}
	local projectiles = {
		register = function(id, def) projectile_defs[id] = def end,
		spawn = function() return true end,
	}
	ability_env = {
		core = core_stub, minetest = core_stub, vector = vector_stub,
		grug_core = {}, grug_classes = classes, grug_xp = xp,
		grug_factions = factions,
		grug_mobs = {is_noncombatant = function() return false end},
		grug_inventory = stub_table({equipment_slots = {}}),
		grug_projectiles = projectiles,
		grug_gear = stub_table({BRACKETS = {}}),
		ItemStack = new_stack,
		math = math, table = table, string = string, os = os, io = io,
		type = type, pairs = pairs, ipairs = ipairs, next = next,
		tostring = tostring, tonumber = tonumber, select = select,
		unpack = unpack, error = error, assert = assert, pcall = pcall,
		setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal,
	}
	ability_env._G = ability_env
	ability_env.dofile = function(path)
		local relative = path:match("(mods/.+)$")
		if relative then
			return load_in(ability_env, relative)
		end
		fail("unexpected dofile path " .. tostring(path))
	end

	load_in(ability_env, "mods/CORE/grug_core/combat.lua")
	ability_env.grug_core.get_player_level = function(player) return player.level end
	load_in(ability_env, "mods/PLAYER/grug_abilities/init.lua")

	local abilities = ability_env.grug_abilities
	local function player(name, class, faction, level, pos)
		local obj = {name = name, class = class, faction = faction, level = level or 1,
			hp = 30, pos = pos or {x = 0, y = 0, z = 0}}
		function obj:get_player_name() return self.name end
		function obj:get_hp() return self.hp end
		function obj:get_pos() return self.pos end
		function obj:is_player() return true end
		function obj:get_luaentity() return nil end
		return obj
	end
	local hostile = {
		is_player = function() return false end,
		get_pos = function() return {x = 2, y = 0, z = 0} end,
		get_luaentity = function() return {_cmi_is_mob = true, health = 20} end,
	}
	local def = abilities.registered.flash_heal
	if mutation == 1 then
		local original = abilities.resolve_friendly_target
		abilities.resolve_friendly_target = function(user, pointed, ability)
			if pointed and pointed.type == "object" and
					not abilities.valid_target(user, pointed.ref, ability.target_kind) then
				return nil, "Invalid target."
			end
			return original(user, pointed, ability)
		end
	end

	local caster = player("caster", "priest", "accord", 1)
	local ally = player("ally", "warrior", "accord", 1, {x = 4, y = 0, z = 0})
	equal(abilities.resolve_friendly_target(caster,
		{type = "object", ref = ally}, def), ally, "pointed valid ally")
	abilities.set_target(caster, ally, true)
	equal(abilities.resolve_friendly_target(caster,
		{type = "object", ref = hostile}, def), ally,
		"pointed hostile falls through to ally memory")
	equal(abilities.resolve_friendly_target(caster,
		{type = "node"}, def), ally, "pointed non-object uses ally memory")
	local solo = player("solo", "priest", "accord", 1)
	equal(abilities.resolve_friendly_target(solo,
		{type = "object", ref = hostile}, def), solo,
		"pointed hostile falls through to self")
	equal(abilities.resolve_friendly_target(solo, nil, def), solo,
		"no ally memory falls through to self")

	local tooltip_rows = {}
	for _, level in ipairs({1, 25, 60}) do
		local priest = player("priest" .. level, "priest", "accord", level)
		local row = {level = level}
		for _, id in ipairs({"smite", "flash_heal"}) do
			local ability = abilities.registered[id]
			local values = ability.values(priest)
			local raw = values.damage or values.heal
			local expected = id == "flash_heal"
				and math.floor(ability_env.grug_core.scale_player_value(priest, raw))
				or ability_env.grug_core.scale_player_damage(priest, nil, raw)
			local description = ability.description_for(priest, ability)
			want(description:find(tostring(expected), 1, true) ~= nil,
				id .. " tooltip has current-level value at L" .. level)
			row[id] = expected
		end
		local shield = abilities.registered.power_word_shield
		if mutation == 5 then
			shield.description_for = function(user, ability)
				return ("Shields the pointed ally (or yourself): absorbs %d damage\n" ..
					"for 15 s or until consumed."):format(
						ability_env.grug_core.scale_player_damage(user, nil,
							ability.values(user).absorb))
			end
		end
		ability_env.grug_core.set_absorb(priest, shield.values(priest).absorb,
			15, priest)
		local settled_absorb = ability_env.grug_core.get_absorb(priest)
		local expected_absorb = math.floor(settled_absorb)
		local original_damage_scaler = ability_env.grug_core.scale_player_damage
		ability_env.grug_core.scale_player_damage = function()
			return expected_absorb + 1000
		end
		local shield_description = shield.description_for(priest, shield)
		ability_env.grug_core.scale_player_damage = original_damage_scaler
		want(shield_description:find("absorbs " .. expected_absorb .. " damage",
			1, true) ~= nil,
			"shield tooltip floors the real absorb seam at L" .. level)
		row.power_word_shield = expected_absorb
		tooltip_rows[#tooltip_rows + 1] = row
	end

	local smite_def = abilities.registered.smite
	if mutation == 6 then
		smite_def.description_for = function(user, ability)
			return ("Smites an enemy up to 20 m away for %d damage."):format(
				ability_env.grug_core.scale_player_damage(user, nil,
					ability.values(user).damage))
		end
	end
	local unshielded_priest = player("smite_unshielded", "priest", "accord", 60)
	local plain_description = smite_def.description_for(
		unshielded_priest, smite_def)
	local plain_damage = ability_env.grug_core.scale_player_damage(
		unshielded_priest, nil, smite_def.values(unshielded_priest).damage)
	equal(plain_damage, 438, "L60 Smite damage without Warded Wrath")
	ability_env.grug_core.set_absorb(unshielded_priest, 1, 15,
		unshielded_priest)
	local plain_shielded_damage = ability_env.grug_core.scale_player_damage(
		unshielded_priest, nil, smite_def.values(unshielded_priest).damage)
	equal(plain_shielded_damage, 438,
		"L60 Smite damage stays 438 without Warded Wrath")
	equal(smite_def.description_for(unshielded_priest, smite_def),
		plain_description, "untalented Smite tooltip ignores absorb state")
	want(plain_description:find("438 damage.", 1, true) ~= nil,
		"untalented L60 Smite tooltip shows 438")
	want(plain_description:find("while shielded", 1, true) == nil,
		"untalented Smite tooltip has no shielded suffix")

	local warded_priest = player("smite_warded", "priest", "accord", 60)
	warded_priest.talents = {smite_damage_while_shielded_add = 4}
	local warded_description = smite_def.description_for(warded_priest, smite_def)
	local warded_unshielded_damage = ability_env.grug_core.scale_player_damage(
		warded_priest, nil, smite_def.values(warded_priest).damage)
	equal(warded_unshielded_damage, 438,
		"L60 Warded Wrath Smite damage without absorb")
	want(warded_description:find("438 damage (+32 while shielded).", 1, true)
		~= nil, "Warded Wrath tooltip separates the scaled shielded bonus")
	local warded_stack = new_stack("grug_abilities:smite")
	want(abilities.update_stack_description(
		warded_stack, smite_def, warded_priest),
		"initial Warded Wrath tooltip write")
	equal(warded_stack.set_string_calls, 1,
		"one metadata write for initial Warded Wrath tooltip")
	ability_env.grug_core.set_absorb(warded_priest, 1, 15, warded_priest)
	local warded_shielded_damage = ability_env.grug_core.scale_player_damage(
		warded_priest, nil, smite_def.values(warded_priest).damage)
	equal(warded_shielded_damage, 470,
		"L60 Warded Wrath Smite damage with absorb")
	equal(smite_def.description_for(warded_priest, smite_def),
		warded_description, "Warded Wrath tooltip ignores absorb state")
	want(not abilities.update_stack_description(
		warded_stack, smite_def, warded_priest),
		"absorb-only change does not rewrite Smite tooltip")
	equal(warded_stack.set_string_calls, 1,
		"absorb-only change spends no metadata write")

	local stack = new_stack("grug_abilities:smite")
	if mutation == 4 then
		local original = abilities.update_stack_description
		abilities.update_stack_description = function(item, ability, owner)
			local changed = original(item, ability, owner)
			item:get_meta():set_string("description",
				item:get_meta():get_string("description"))
			return changed
		end
	end
	local tooltip_player = player("tooltip", "priest", "accord", 1)
	want(abilities.update_stack_description(stack, smite_def, tooltip_player),
		"initial tooltip write")
	equal(stack.set_string_calls, 1, "one metadata write for initial tooltip")
	want(not abilities.update_stack_description(stack, smite_def, tooltip_player),
		"unchanged tooltip returns false")
	equal(stack.set_string_calls, 1, "unchanged tooltip writes nothing")
	tooltip_player.level = 60
	want(abilities.update_stack_description(stack, smite_def, tooltip_player),
		"level-changed tooltip rewrites")
	equal(stack.set_string_calls, 2, "one metadata write after value change")

	local stale_fallback = {
		charge = "dealing 3 damage",
		fireball = "6 + spell power damage",
		smite = "4 + spell power damage",
		flash_heal = "8 + 2x spell power",
		power_word_shield = "8 + 2x spell power",
		renew = "3 + spell power",
	}
	for id, stale in pairs(stale_fallback) do
		local fallback = registered_items["grug_abilities:" .. id].description
		want(not fallback:find(stale, 1, true),
			id .. " registered fallback has no stale formula number")
	end

	local suff_callbacks = {}
	local online, privilege_reads = {}, 0
	local suff_core = {
		registered_nodes = {stone = {walkable = true, liquidtype = "none"}},
		register_globalstep = function(fn) suff_callbacks[#suff_callbacks + 1] = fn end,
		get_connected_players = function() return online end,
		get_node = function() return {name = "stone"} end,
		get_player_privs = function(name)
			privilege_reads = privilege_reads + 1
			return name == "noclip" and {noclip = true} or {}
		end,
	}
	local suff_grug_core = {}
	local suff_env = {
		core = suff_core, grug_core = suff_grug_core,
		math = math, table = table, string = string, tonumber = tonumber,
		ipairs = ipairs, pairs = pairs, type = type,
	}
	suff_env._G = suff_env
	load_in(suff_env, "mods/CORE/grug_core/suffocation.lua")
	if mutation == 2 then
		local original = suff_grug_core.should_suffocate
		suff_grug_core.should_suffocate = function(node, stasis, has_noclip)
			return original(node, stasis, false)
		end
	end
	local stone = suff_core.registered_nodes.stone
	want(suff_grug_core.should_suffocate(stone, false, false),
		"solid head node suffocates")
	want(not suff_grug_core.should_suffocate(stone, false, true),
		"noclip exempts suffocation")
	want(not suff_grug_core.should_suffocate(stone, true, false),
		"creation stasis exempts suffocation")
	for hp_max, expected in pairs({[20] = 1, [100] = 5, [2696] = 134,
			[3235] = 161}) do
		equal(suff_grug_core.suffocation_damage(hp_max), expected,
			"suffocation damage at hp_max " .. hp_max)
	end
	local function suff_player(name, hp_max)
		local obj = {name = name, hp = hp_max, hp_max = hp_max}
		function obj:get_player_name() return self.name end
		function obj:get_hp() return self.hp end
		function obj:set_hp(value, reason) self.hp, self.reason = value, reason end
		function obj:get_pos() return {x = 0, y = 0, z = 0} end
		function obj:get_properties() return {eye_height = 1.47, hp_max = self.hp_max} end
		return obj
	end
	local normal = suff_player("normal", 100)
	local noclip = suff_player("noclip", 100)
	online = {normal, noclip}
	suff_callbacks[1](1)
	equal(privilege_reads, 2, "one privilege read per player per check")
	equal(normal.hp, 95, "runtime suffocation uses five percent max HP")
	equal(noclip.hp, 100, "runtime noclip exemption")

	local pages = {}
	local sfinv = {
		pages = {}, pages_unordered = {},
		register_page = function(name, page) pages[name] = page end,
		make_formspec = function(player, context, content) return content end,
		get_homepage_name = function() return "" end,
		get_or_create_context = function() return {page = ""} end,
		set_page = function() end,
	}
	local page_classes = {
		get_class_def = function(player) return player.class_def end,
		get_race_def = function() return {name = "Human"} end,
		get_attributes = function() return {str = 10, int = 10, dex = 10} end,
		get_max_mana = function() return 30 end,
		get_max_hp = function() return 30 end,
		get_pool_breakdown = function(player, pool)
			return {base = 26, class_factor = pool == "hp" and 1 or 1,
				gear_percent = 0, talent_percent = 0, final = 30}
		end,
		get_melee_bonus = function() return 1 end,
		get_spell_power_bonus = function() return 1 end,
		get_crit_chance = function() return 0.06 end,
		get_dodge_chance = function() return 0.01 end,
	}
	local page_env = {
		core = {
			formspec_escape = function(text) return text end,
			log = function() end,
		},
		sfinv = sfinv,
		grug_inventory = {equipment_slots = {}, BAG_COUNT = 4,
			bag_list = function(index) return "bag" .. index end,
			bag_slots_of = function() return 0 end,
			content_list = function(index) return "bag" .. index .. "_contents" end},
		grug_classes = page_classes,
		grug_factions = {get_faction_def = function() return {name = "Accord"} end},
		grug_xp = {get_level = function() return 1 end,
			register_on_level_change = function() end},
		grug_core = {register_on_equipment_change = function() end,
			get_armor_percent = function() return 0 end},
		player_api = {registered_models = {['character.b3d'] = {
			textures = {"character.png"}}}},
		math = math, table = table, string = string, ipairs = ipairs, pairs = pairs,
		type = type, tostring = tostring,
	}
	page_env._G = page_env
	load_in(page_env, "mods/PLAYER/grug_inventory/pages.lua")
	local page_player = {
		class_def = {name = "Priest", resource = "mana"},
		get_player_name = function() return "Page" end,
		get_hp = function() return 20 end,
		get_properties = function()
			return {visual = "mesh", mesh = "character.b3d",
				textures = {"character.png"}}
		end,
		get_inventory = function()
			return {get_stack = function()
				return {is_empty = function() return true end}
			end}
		end,
	}
	local formspec = pages["grug_inventory:character"].get(nil, page_player, {})
	if mutation == 3 then
		formspec = formspec:gsub("HP 30=", "HP 20 / 30 ", 1)
	end
	want(formspec:find("HP 30=B26xC1.00x(100+G0+T0)%", 1, true)
		~= nil, "Character page shows Max HP derivation")
	want(formspec:find("Mana 30=B26xC1.00x(100+G0+T0)%", 1, true) ~= nil,
		"Character page shows Max Mana")
	want(formspec:find("HP %d+ / %d+") == nil,
		"Character page never shows current/max HP")
	page_player.class_def = {name = "Warrior", resource = "rage"}
	local rage_formspec = pages["grug_inventory:character"].get(
		nil, page_player, {})
	want(rage_formspec:find("Rage 100=fixed; no C/G/T scaling", 1, true) ~= nil,
		"Character page retains the rage label")
	want(rage_formspec:find("Mana:", 1, true) == nil,
		"rage Character page does not show mana")
	local help_formspec = pages["grug_inventory:help"].get(
		nil, page_player, {})
	if mutation == 7 then
		help_formspec = help_formspec:gsub(
			"there is no separate item%-level multiplier",
			"item level adds a separate multiplier", 1)
	end
	want(help_formspec:find(
		"Item level is counted once, in the weapon's base damage; your character level applies the shared damage fit; there is no separate item-level multiplier.",
		1, true) ~= nil, "Help page states the single item-level damage axis")
	want(help_formspec:find(
		"At level 60, an item-level 70 weapon gives about 9% more effective swing damage than item level 60, while item level 50 gives about 7% less, before enchants.",
		1, true) ~= nil, "Help page shows the measured L60 item-level examples")
	want(help_formspec:find("Crit multiplies damage by 1.5.", 1, true) ~= nil,
		"Help page explains Crit")
	want(help_formspec:find("Dodge avoids the hit entirely.", 1, true) ~= nil,
		"Help page explains Dodge")
	want(help_formspec:find(
		"Each Armor point reduces incoming punch damage by 1 percentage point.",
		1, true) ~= nil, "Help page explains Armor")

	for _, row in ipairs(tooltip_rows) do
		io.write(("tooltip L%d smite=%d flash_heal=%d shield=%d\n"):format(
			row.level, row.smite, row.flash_heal, row.power_word_shield))
	end
	io.write("heal_target=pointed_ally invalid_to_memory invalid_to_self node_to_memory\n")
	io.write("suffocation=20:1 100:5 2696:134 3235:161 noclip_exempt\n")
	io.write("character=derived_Max_HP Max_Mana no_current_pool help=single_ilvl_axis_l60_examples\n")
	io.write("tooltip_writes=changed_only\n")
	io.write(("smite_l60=%d/%d shielded_bonus=32 absorb_tooltip=floor_seam\n")
		:format(warded_unshielded_damage, warded_shielded_damage))
end

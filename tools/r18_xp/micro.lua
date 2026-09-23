-- Round 18 XP development fixture. Loads the real XP, stats and ability
-- modules, then drives their registered level callbacks through set_xp.
return function(repo)
	local hooks = {level = {}, die = {}, chat = {}, particles = {}, players = {}}
	local noop = function() end
	local function stub(fields)
		return setmetatable(fields or {}, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end
	local core = stub({registered_items = {}, registered_nodes = {},
		registered_tools = {}, registered_entities = {}})
	function core.global_exists(name) return name == "grug_classes" end
	function core.colorize(_, text) return text end
	function core.chat_send_player(_, text) hooks.chat[#hooks.chat + 1] = text end
	function core.add_particlespawner(def) hooks.particles[#hooks.particles + 1] = def end
	function core.register_on_dieplayer(fn) hooks.die[#hooks.die + 1] = fn end
	function core.register_chatcommand(name, def) hooks[name] = def end
	function core.get_player_by_name(name) return hooks.players[name] end
	function core.check_player_privs() return true end
	function core.get_modpath() return repo .. "/mods/PLAYER/grug_abilities" end
	function core.get_current_modname() return "grug_abilities" end
	function core.get_connected_players() return {} end
	local vector = stub({})
	function vector.new(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x or 0, y = y or 0, z = z or 0}
	end
	function vector.offset(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end
	local grug_core = stub({hud_layout = {COLOR = {mana = 1, rage = 2}}})
	function grug_core.base_pool(level) return 20 + level * level end
	function grug_core.status_modifier_sum() return 0 end
	function grug_core.absorb_modifier() return 0 end
	local classes = stub({registered_classes = {
		mage = {resource = "mana", growth = {int = 2}},
		warrior = {resource = "rage", growth = {str = 3}},
	}})
	function classes.get_class(player) return player.class_id end
	function classes.get_class_def(player) return classes.registered_classes[player.class_id] end
	function classes.get_talent_bonus() return 0 end
	function classes.get_scout_dodge_add() return 0 end
	function classes.get_scout_dodge_cap() return 30 end
	function classes.get_race_perk() return 1 end
	function classes.on_level_change_talents() end
	local env = setmetatable({core = core, vector = vector, grug_core = grug_core,
		grug_classes = classes, dofile = noop}, {__index = _G})
	local function load(path)
		local fn = assert(loadfile(repo .. "/" .. path))
		setfenv(fn, env)
		fn()
	end
	load("mods/PLAYER/grug_xp/init.lua")
	-- XP already owns its private dispatch list; wrap registration before the
	-- consumers load and mirror each real callback into the observable list.
	local original_register = env.grug_xp.register_on_level_change
	env.grug_xp.register_on_level_change = function(fn)
		hooks.level[#hooks.level + 1] = fn
		original_register(fn)
	end
	load("mods/PLAYER/grug_classes/stats.lua")
	load("mods/PLAYER/grug_abilities/init.lua")

	local function player(name, class_id, xp, hp)
		local p = {name = name, class_id = class_id, xp = xp, hp = hp,
			props = {hp_max = 20}}
		function p:get_player_name() return self.name end
		function p:get_meta()
			return {get_int = function() return self.xp end,
				set_int = function(_, _, value) self.xp = value end}
		end
		function p:get_properties() return self.props end
		function p:set_properties(value) self.props.hp_max = value.hp_max end
		function p:get_hp() return self.hp end
		function p:set_hp(value) self.hp = math.max(0, math.min(value, self.props.hp_max)) end
		function p:get_pos() return {x = 1, y = 2, z = 3} end
		function p:get_inventory()
			return {get_size = function() return 0 end}
		end
		return p
	end

	local mage = player("mage", "mage", 0, 7)
	hooks.players.mage = mage
	env.grug_abilities.restore_mana(mage, 9)
	assert(env.grug_abilities.get_mana(mage) == 9)
	local ok, gained = env.grug_xp.set_xp(mage, env.grug_xp.xp_for_level(4))
	assert(ok and gained == 900 and env.grug_xp.get_level(mage) == 4)
	assert(mage.hp == classes.get_max_hp(mage), "upward transition did not fill HP")
	assert(env.grug_abilities.get_mana(mage) == classes.get_max_mana(mage),
		"upward transition did not fill mana")
	assert(#hooks.particles == 1, "multi-level transition must make one burst")
	local login = player("login", "mage", 100, 5)
	env.grug_abilities.restore_mana(login, 3)
	for _, fn in ipairs(hooks.level) do fn(login, nil, 2) end
	assert(login.hp == 5 and env.grug_abilities.get_mana(login) == 3,
		"join-style callback refilled resources")

	local warrior = player("warrior", "warrior", 0, 8)
	env.grug_abilities.add_rage(warrior, 37)
	env.grug_xp.set_xp(warrior, 100)
	assert(env.grug_abilities.get_rage(warrior) == 37, "level-up changed rage")
	local bursts = #hooks.particles
	env.grug_xp.set_xp(warrior, 0)
	assert(warrior.hp <= warrior.props.hp_max and #hooks.particles == bursts,
		"downward transition refilled or emitted a burst")

	local dead = player("dead", "mage", 0, 0)
	env.grug_xp.set_xp(dead, 100)
	assert(dead.hp == 0, "XP resurrected a dead player")
	local maximum = env.grug_xp.xp_for_level(60)
	local capped = player("capped", "mage", maximum - 5, 10)
	local _, actual = env.grug_xp.add_xp(capped, 1000000000)
	assert(capped.xp == maximum and actual == 5, "shared setter did not clamp overflow")
	local _, zero = env.grug_xp.add_xp(capped, 1)
	assert(zero == 0, "capped grant was not a successful no-op")
	hooks.players.capped = capped
	local command_ok, command_text = hooks.xp.func("mage", "give capped 999999999")
	assert(command_ok and command_text:find("granted 0 XP", 1, true),
		"capped command did not report a successful zero grant")
	local invalid_ok = hooks.xp.func("mage", "give capped 1e999")
	assert(not invalid_ok, "non-finite command input was accepted")
	local before = capped.xp
	assert(env.grug_xp.set_xp(capped, 0) and capped.xp == 0,
		"admin downward setter was lost")
	assert(not env.grug_xp.set_xp(capped, 0 / 0) and capped.xp == 0,
		"non-finite setter input mutated XP")
	capped.xp = before
	for _, fn in ipairs(hooks.die) do fn(capped) end
	assert(capped.xp == before, "death changed XP")

	return "r18_xp\tPASS\thp=full\tmana=full\trage=unchanged\tburst=once\tcap=" ..
		maximum .. "\tdeath=preserved\n"
end

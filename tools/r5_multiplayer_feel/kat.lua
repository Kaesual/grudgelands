-- Known-answer test for round-5 Lane N. It loads the shipped faction tag and
-- all three new grug_core modules against a minimal engine stub.
--
-- MUTATION=1 inverts the nametag distance gate.
-- MUTATION=2 turns fall deaths into fallback deaths.
-- MUTATION=3 makes walkable solid nodes non-suffocating.
-- MUTATION=4 inverts the liquid-step node decision.
-- MUTATION=5 restores the old fixed 0.6 land stepheight.
-- MUTATION=6 drops the suffocation death reason.

local repo = arg[1] or "."
local mutation = tonumber(os.getenv("MUTATION") or "") or 0

local function fail(message)
	error("r5 multiplayer feel: " .. message, 0)
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

local saved = {
	core = rawget(_G, "core"),
	grug_core = rawget(_G, "grug_core"),
	grug_factions = rawget(_G, "grug_factions"),
	grug_xp = rawget(_G, "grug_xp"),
	vector = rawget(_G, "vector"),
}

local callbacks = {
	globalstep = {}, hpchange = {}, dieplayer = {}, joinplayer = {},
	leaveplayer = {}, mods_loaded = {},
}
local online = {}
local chat_count = 0
local node_name = "air"

local function register(list)
	return function(fn, modifier)
		list[#list + 1] = {fn = fn, modifier = modifier}
	end
end

core = {
	registered_nodes = {},
	register_globalstep = register(callbacks.globalstep),
	register_on_player_hpchange = register(callbacks.hpchange),
	register_on_dieplayer = register(callbacks.dieplayer),
	register_on_joinplayer = register(callbacks.joinplayer),
	register_on_leaveplayer = register(callbacks.leaveplayer),
	register_on_mods_loaded = register(callbacks.mods_loaded),
	register_on_player_receive_fields = function() end,
	register_on_respawnplayer = function() end,
	register_on_punchplayer = function() end,
	register_chatcommand = function() end,
	get_connected_players = function() return online end,
	get_player_by_name = function(name)
		for index = 1, #online do
			if online[index]:get_player_name() == name then
				return online[index]
			end
		end
	end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	chat_send_all = function(message)
		chat_count = chat_count + 1
		core.last_chat = message
	end,
	formspec_escape = function(text) return text end,
	after = function() end,
	colorize = function(_, text) return text end,
	close_formspec = function() end,
	show_formspec = function() end,
	check_player_privs = function() return true end,
	get_node = function() return {name = node_name} end,
}

vector = {
	offset = function(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end,
}

grug_core = {
	factions = {
		accord = {name = "Accord", color = "#3f6fce"},
		throng = {name = "Throng", color = "#c41e3a"},
	},
	zone_authority_installed = function() return true end,
}

local level_callback
grug_xp = {
	get_level = function(player) return player.level end,
	register_on_level_change = function(fn) level_callback = fn end,
}

local function fake_player(name, pos)
	local meta_values = {['grug_factions:faction'] = "accord"}
	local meta = {}
	function meta:get_string(key) return meta_values[key] or "" end
	function meta:set_string(key, value) meta_values[key] = value end
	function meta:get_int(key) return tonumber(meta_values[key]) or 0 end
	function meta:set_int(key, value) meta_values[key] = value end
	local player = {
		name = name, pos = pos, hp = 30, hp_max = 30, level = 1,
		stepheight = 0.6, nametag_writes = 0, property_writes = 0,
	}
	function player:get_player_name() return self.name end
	function player:get_meta() return meta end
	function player:get_pos() return self.pos end
	function player:get_hp() return self.hp end
	function player:set_hp(value, reason)
		local was_alive = self.hp > 0
		self.hp = value
		self.hp_reason = reason
		if was_alive and value <= 0 then
			for index = 1, #callbacks.dieplayer do
				callbacks.dieplayer[index].fn(self, reason)
			end
		end
	end
	function player:get_properties()
		return {hp_max = self.hp_max, eye_height = 1.47,
			stepheight = self.stepheight}
	end
	function player:set_properties(properties)
		if properties.stepheight then self.stepheight = properties.stepheight end
		self.property_writes = self.property_writes + 1
	end
	function player:set_nametag_attributes(attributes)
		self.nametag = attributes
		self.nametag_writes = self.nametag_writes + 1
	end
	function player:is_player() return true end
	function player:get_inventory()
		return {add_item = function() end}
	end
	return player
end

local ok, failure = pcall(function()
	dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")
	dofile(repo .. "/mods/CORE/grug_core/death_messages.lua")
	dofile(repo .. "/mods/CORE/grug_core/suffocation.lua")
	dofile(repo .. "/mods/CORE/grug_core/liquid_step.lua")

	if mutation == 1 then
		local original = grug_factions.player_tag_visible
		grug_factions.player_tag_visible = function(shown, distance)
			return not original(shown, distance)
		end
	elseif mutation == 2 then
		local original = grug_core.death_message
		grug_core.death_message = function(name, reason)
			if reason and reason.type == "fall" then
				return original(name, {type = "set_hp"})
			end
			return original(name, reason)
		end
	elseif mutation == 3 then
		local original = grug_core.should_suffocate
		grug_core.should_suffocate = function(def, stasis)
			if def and def.walkable then return false end
			return original(def, stasis)
		end
	elseif mutation == 4 then
		local original = grug_core.liquid_step_for_node
		grug_core.liquid_step_for_node = function(def)
			return not original(def)
		end
	elseif mutation == 5 then
		local original = grug_core.update_liquid_step
		grug_core.update_liquid_step = function(player, in_liquid)
			if not in_liquid and player:get_properties().stepheight ~= 0.6 then
				player:set_properties({stepheight = 0.6})
				return true
			end
			return original(player, in_liquid)
		end
	elseif mutation == 6 then
		local original = grug_core.death_message
		grug_core.death_message = function(name, reason)
			if reason and reason.custom_type == "grug_core:suffocation" then
				return original(name, {type = reason.type})
			end
			return original(name, reason)
		end
	end

	-- Player tag text, pure distance gate and send-on-change behavior.
	equal(grug_factions.player_tag_text("Thomas", 5, 35, 60),
		"Thomas [Lv 5] 35/60", "player tag text")
	want(grug_factions.player_tag_visible(false, 24 * 24), "show below 25 m")
	want(not grug_factions.player_tag_visible(false, 27 * 27),
		"hidden state retained in hysteresis band")
	want(grug_factions.player_tag_visible(true, 27 * 27),
		"shown state retained in hysteresis band")
	want(not grug_factions.player_tag_visible(true, 31 * 31),
		"hide above 30 m")

	local thomas = fake_player("Thomas", {x = 0, y = 0, z = 0})
	local ada = fake_player("Ada", {x = 24, y = 0, z = 0})
	online = {thomas, ada}
	for index = 1, #callbacks.joinplayer do
		callbacks.joinplayer[index].fn(thomas)
		callbacks.joinplayer[index].fn(ada)
	end
	equal(thomas.nametag_writes, 1, "join hides tag once")
	callbacks.globalstep[1].fn(1)
	equal(thomas.nametag_writes, 2, "near player shows tag once")
	equal(thomas.nametag.text, "Thomas [Lv 1] 30/30", "shown tag text")
	callbacks.globalstep[1].fn(1)
	equal(thomas.nametag_writes, 2, "unchanged gate writes nothing")
	callbacks.hpchange[1].fn(thomas, -5, {type = "punch"})
	equal(thomas.nametag_writes, 3, "HP change refreshes visible tag")
	equal(thomas.nametag.text, "Thomas [Lv 1] 25/30", "predicted HP tag")
	thomas.hp = 25
	for index = 1, #callbacks.mods_loaded do callbacks.mods_loaded[index].fn() end
	thomas.level = 5
	level_callback(thomas, 1, 5)
	equal(thomas.nametag_writes, 4, "level-up refreshes visible tag")
	equal(thomas.nametag.text, "Thomas [Lv 5] 25/30", "level-up tag text")
	ada.pos.x = 31
	callbacks.globalstep[1].fn(1)
	equal(thomas.nametag_writes, 5, "far player hides tag once")
	callbacks.globalstep[1].fn(1)
	equal(thomas.nametag_writes, 5, "hidden unchanged gate writes nothing")

	-- Death message categories and actor display names.
	local category, line = grug_core.death_message("Thomas", {type = "fall"})
	equal(category, "fall", "fall death category")
	want(line:find("Thomas", 1, true) ~= nil, "fall line names victim")
	equal((grug_core.death_message("Thomas", {type = "drown"})),
		"drown", "drowning category")
	equal((grug_core.death_message("Thomas", {
		type = "node_damage", node = "default:lava_source"})),
		"node_damage", "node damage category")
	local mob = {
		is_player = function() return false end,
		get_luaentity = function() return {description = "Grimtusk"} end,
	}
	category, line = grug_core.death_message("Thomas",
		{type = "punch", object = mob})
	equal(category, "mob", "mob death category")
	want(line:find("Grimtusk", 1, true) ~= nil, "mob line uses display name")
	local killer = fake_player("Ada", {x = 0, y = 0, z = 0})
	category, line = grug_core.death_message("Thomas",
		{type = "punch", object = killer})
	equal(category, "player", "player death category")
	want(line:find("Ada", 1, true) ~= nil, "player line names killer")
	equal((grug_core.death_message("Thomas", {type = "set_hp"})),
		"fallback", "fallback death category")
	callbacks.dieplayer[1].fn(thomas, {type = "fall"})
	equal(chat_count, 1, "one broadcast per death")
	want(core.last_chat:find("Thomas", 1, true) ~= nil,
		"broadcast names the dead player")

	-- Suffocation is solid-head-only and character stasis wins.
	local stone = {walkable = true, liquidtype = "none"}
	local water = {walkable = false, liquidtype = "source"}
	local plant = {walkable = false, liquidtype = "none"}
	want(grug_core.should_suffocate(stone, false), "stone suffocates")
	want(not grug_core.should_suffocate(water, false), "liquid does not suffocate")
	want(not grug_core.should_suffocate(plant, false), "plant does not suffocate")
	want(not grug_core.should_suffocate(stone, true), "stasis is exempt")
	core.registered_nodes.stone = stone
	local trapped = fake_player("Trapped", {x = 0, y = 0, z = 0})
	trapped.hp = 1
	online = {trapped}
	node_name = "stone"
	local chats_before_suffocation = chat_count
	for index = 1, #callbacks.globalstep do
		callbacks.globalstep[index].fn(1)
	end
	equal(trapped.hp, 0, "suffocation set_hp kills at one HP")
	equal(trapped.hp_reason.custom_type, "grug_core:suffocation",
		"suffocation set_hp keeps custom reason")
	equal(chat_count, chats_before_suffocation + 1,
		"suffocation death broadcasts once")
	want(core.last_chat:find("suffocated", 1, true) ~= nil,
		"full suffocation death path selects suffocation template")
	equal((grug_core.death_message("Thomas", {
		type = "set_hp", custom_type = "grug_core:suffocation"})),
		"suffocation", "suffocation category")
	node_name = "air"

	-- Liquid step preserves the live land value and never resends equal values.
	local swimmer = fake_player("Swimmer", {x = 0, y = 0, z = 0})
	swimmer.stepheight = 0.8
	want(not grug_core.update_liquid_step(swimmer, false),
		"land without active override needs no write")
	equal(swimmer.stepheight, 0.8, "land preserves live stepheight")
	equal(swimmer.property_writes, 0, "land without override writes nothing")
	want(grug_core.liquid_step_for_node(water), "water is liquid step state")
	want(grug_core.update_liquid_step(swimmer, true), "entering water writes")
	equal(swimmer.stepheight, 1.1, "water stepheight")
	equal(swimmer.property_writes, 1, "one enter write")
	want(not grug_core.update_liquid_step(swimmer, true),
		"unchanged water state writes nothing")
	equal(swimmer.property_writes, 1, "still one write in water")
	want(grug_core.update_liquid_step(swimmer, false), "leaving water writes")
	equal(swimmer.stepheight, 0.8, "saved live stepheight restored")
	equal(swimmer.property_writes, 2, "one enter and one leave write")
	want(not grug_core.update_liquid_step(swimmer, false),
		"land after restore writes nothing")
	equal(swimmer.property_writes, 2, "restored land remains write-free")
end)

rawset(_G, "core", saved.core)
rawset(_G, "grug_core", saved.grug_core)
rawset(_G, "grug_factions", saved.grug_factions)
rawset(_G, "grug_xp", saved.grug_xp)
rawset(_G, "vector", saved.vector)

if not ok then
	error(failure, 0)
end

io.write(table.concat({
	"player_tag=Thomas [Lv 5] 35/60",
	"tag_gate=show24 hold27 hide31 no_resend",
	"death=fall drown node_damage suffocation mob player fallback",
	"suffocation=solid_only stasis_exempt",
	"liquid_step=0.8>1.1>0.8 writes2 land_no_write",
}, "\n"), "\n")

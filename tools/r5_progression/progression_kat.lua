-- Round-5 Lane P known-answer test. Loads the real progression modules under
-- a minimal Lua-5.1 engine stub and exercises their public/runtime seams.

local repo = arg[1] or "."
local callbacks = {die = {}, join = {}, leave = {}, hp = {}}
local globalsteps = {}
local players = {}
local chat = {}

local function noop() end
local function assert_equal(actual, expected, label)
	if actual ~= expected then
		error(label .. ": expected " .. tostring(expected) .. ", got " ..
			tostring(actual), 0)
	end
end

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then
		return {x = x.x, y = x.y, z = x.z}
	end
	return {x = x or 0, y = y or 0, z = z or 0}
end
function vector.offset(pos, x, y, z)
	return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
end

core = {
	registered_items = {}, registered_nodes = {}, registered_entities = {},
	get_us_time = function() return 1000000 end,
	get_gametime = function() return 100 end,
	get_connected_players = function() return {} end,
	get_objects_inside_radius = function() return {} end,
	get_current_modname = function() return "grug_mobs" end,
	get_modpath = function(name) return repo .. "/mods/ENTITIES/" .. name end,
	colorize = function(color, text) return text end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ":" .. text end,
	log = noop,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_player_hpchange = function(fn, modifier)
		callbacks.hp[#callbacks.hp + 1] = {fn = fn, modifier = modifier}
	end,
	register_chatcommand = noop,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	is_player = function(obj) return obj and obj.is_player and obj:is_player() end,
	get_player_by_name = function(name) return players[name] end,
}
setmetatable(core, {__index = function(t, key)
	rawset(t, key, noop)
	return noop
end})

grug_core = {
	hud_layout = {text_element = function(name, def) return def end},
	zone_authority_installed = function() return true end,
}
grug_classes = {get_xp_bonus = function() return 1 end}

dofile(repo .. "/mods/CORE/grug_core/combat.lua")

local lines = {}
local function record(label, values)
	lines[#lines + 1] = label .. "=" .. table.concat(values, ",")
end

record("scale", {
	string.format("%.2f", grug_core.level_scale(1)),
	string.format("%.2f", grug_core.level_scale(10)),
	string.format("%.2f", grug_core.level_scale(60)),
})
assert_equal(grug_core.level_scale(1), 1, "level scalar L1")
assert_equal(grug_core.level_scale(10), 1.54, "level scalar L10")
assert_equal(grug_core.level_scale(60), 4.54, "level scalar L60")

local malus = {}
for _, mob_level in ipairs({15, 16, 20, 30}) do
	malus[#malus + 1] = string.format("%.1f",
		grug_core.level_malus(10, mob_level))
end
record("malus", malus)
assert_equal(table.concat(malus, ","), "1.0,0.9,0.5,0.1", "level malus")

local formatted = {}
for _, value in ipairs({999, 1000, 9999, 10000, 51234}) do
	formatted[#formatted + 1] = grug_core.format_k(value)
end
record("format", formatted)
assert_equal(table.concat(formatted, ","), "999,1.0k,9.9k,10k,51k",
	"k-format boundaries")

local function combat_player(name, level)
	return {
		name = name, level = level,
		is_player = function() return true end,
		get_player_name = function(self) return self.name end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
	}
end

local attacker = combat_player("caster", 10)
grug_core.get_player_level = function(player) return player.level end
grug_core.get_crit_chance = function() return 0 end
grug_core.get_dodge_chance = function() return 0 end
local punched
local mob_target = {
	is_player = function() return false end,
	get_luaentity = function() return {_grug_level = 10} end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
	punch = function(self, source, interval, caps)
		punched = caps.damage_groups.fleshy
	end,
}
-- 10 base + 2 flat talent add, then x1.54 = floor(18.48) = 18. Scaling
-- the base first and adding the talent afterwards would incorrectly yield 17.
local dealt = grug_core.deal_ability_damage(attacker, mob_target, 10 + 2)
assert_equal(dealt, 18, "ability return after flat add")
assert_equal(punched, 18, "ability punch after flat add")
record("ability", {dealt, punched})

mob_target.get_luaentity = function() return {_grug_level = 16} end
dealt = grug_core.deal_ability_damage(attacker, mob_target, 12)
assert_equal(dealt, 16, "ability level malus")
record("ability_malus", {dealt})

local effective_heal
grug_core.register_on_effective_heal(function(healer, target, amount)
	effective_heal = amount
end)
local heal_target = {
	hp = 10, name = "patient",
	is_player = function() return true end,
	get_player_name = function(self) return self.name end,
	get_hp = function(self) return self.hp end,
	set_hp = function(self, value) self.hp = value end,
	get_properties = function() return {hp_max = 100} end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
}
assert_equal(grug_core.heal_player(attacker, heal_target, 12), 18,
	"scaled heal")
assert_equal(effective_heal, 18, "effective-heal hook")
assert_equal(grug_core.heal_player(attacker, heal_target, 15, {no_crit = true}),
	23, "percentage consumable scaled once")
grug_core.set_absorb(heal_target, 12, 15, attacker)
assert_equal(grug_core.get_absorb(heal_target), 18.48, "scaled absorb")
record("support", {18, 23, string.format("%.2f", grug_core.get_absorb(heal_target))})

grug_mobs = {}
mobs = {scale_mob = noop}
grug_zones = {mob_level_at = function() return 1 end,
	guard_level_at = function() return 1 end}
dofile(repo .. "/mods/ENTITIES/grug_mobs/levels.lua")
local level_api = grug_mobs

local expected_rows = {
	{1, 26, 2.3, 10}, {10, 136, 5.5, 100}, {20, 384, 10, 200},
	{40, 1276, 22, 400}, {60, 2696, 38, 600},
}
local stat_lines = {}
for i = 1, #expected_rows do
	local row = expected_rows[i]
	local hp, damage, xp = grug_mobs.stats_for(row[1], "normal")
	assert_equal(hp, row[2], "normal HP L" .. row[1])
	assert_equal(damage, row[3], "normal damage L" .. row[1])
	assert_equal(xp, row[4], "normal XP L" .. row[1])
	stat_lines[#stat_lines + 1] = table.concat({row[1], hp, damage, xp}, "/")
end
record("stats", stat_lines)

local hp_elite, damage_elite, xp_elite = grug_mobs.stats_for(60, "elite")
local hp_rare, damage_rare, xp_rare = grug_mobs.stats_for(60, "rare")
local hp_boss = grug_mobs.stats_for(60, "boss")
assert_equal(table.concat({hp_elite, damage_elite, xp_elite}, ","),
	"8088,68.4,2400", "elite multipliers")
assert_equal(table.concat({hp_rare, damage_rare, xp_rare}, ","),
	"13480,83.6,3600", "rare multipliers")
assert_equal(hp_boss, 53920, "boss HP multiplier")
local critter_hp, _, critter_xp = grug_mobs.stats_for(60, "critter")
assert_equal(critter_hp, 1, "critter HP")
assert_equal(critter_xp, 0, "critter XP")
record("tiers", {hp_elite, hp_rare, hp_boss, critter_hp, critter_xp})

local tag = grug_mobs.tag_text({
	description = "Test", _grug_level = 60, _grug_tier = "boss",
	health = 2300, hp_max = hp_boss,
})
assert_equal(tag, "Boss Test [Lv 60] 2.3k/54k", "tag k-format")
record("tag", {tag})

grug_mobs.register_level_cfg("test:mob", {})
assert_equal(grug_mobs.kill_xp({name = "test:mob", _grug_level = 60,
	_grug_tier = "elite"}, 10), 600, "recipient XP level cap")
record("xp_cap", {600})

-- Load the real XP owner. Its death callback is the last one registered here.
grug_xp = nil
dofile(repo .. "/mods/PLAYER/grug_xp/init.lua")

local Meta = {}
Meta.__index = Meta
function Meta:get_int(key) return self[key] or 0 end
function Meta:set_int(key, value) self[key] = value end
function Meta:get_string(key) return self[key] or "" end
function Meta:set_string(key, value) self[key] = value end

local function xp_player(name, pos, faction, xp)
	local player = {
		name = name, pos = pos, faction = faction, hp = 30,
		meta = setmetatable({}, Meta),
	}
	player.meta["grug_xp:xp"] = xp or 8100
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_pos() return self.pos end
	function player:get_meta() return self.meta end
	function player:hud_change() end
	function player:get_hp() return self.hp end
	function player:set_hp(value) self.hp = value end
	function player:get_properties() return {hp_max = 100} end
	players[name] = player
	return player
end

local death_player = xp_player("death", {x = 0, y = 0, z = 0}, "accord", 9000)
callbacks.die[#callbacks.die](death_player)
assert_equal(grug_xp.get_xp(death_player), 8525, "quarter-level-span death loss")
grug_xp.set_xp(death_player, 8200)
callbacks.die[#callbacks.die](death_player)
assert_equal(grug_xp.get_xp(death_player), 8100, "death loss level floor")
record("death", {8525, 8100})

-- Load only the real grug_mobs main chunk. Its submodules are separately real
-- above; skipping the roster keeps this fixture bounded and lets us drive the
-- accepted lethal boundary directly.
local mob_env = setmetatable({
	core = core, vector = vector, mobs = mobs, grug_core = grug_core,
	grug_xp = grug_xp, grug_zones = grug_zones,
	grug_factions = {
		same_faction = function(a, b)
			local ent = b and b:get_luaentity()
			return a.faction ~= nil and ent and a.faction == ent._grug_faction
		end,
	},
	dofile = noop,
}, {__index = _G})
local mob_chunk = assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/init.lua"))
setfenv(mob_chunk, mob_env)
mob_chunk()
local mob_api = mob_env.grug_mobs
mob_api.kill_xp = level_api.kill_xp
mob_api.tag_player = noop
mob_api.rare_killed = noop
mob_api.register_level_cfg = noop
mob_api.register_spawn_role = noop
mob_api.install_flight_nudge = noop
grug_core.run_player_hit_mob = noop

local death_def
mobs.register_mob = function(self, name, def)
	if name == "test:death" then death_def = def end
end
mob_api.register_mob("test:death", {})
assert(death_def and death_def.on_death == nil and death_def.on_die == nil,
	"XP settlement must not replace mobs_redo death callbacks")
local old_on_die = noop
local on_die_def = {on_die = old_on_die}
mob_api.register_mob("test:on_die", on_die_def)
assert_equal(on_die_def.on_die, old_on_die, "original on_die callback preserved")

local function find_upvalue(func, wanted, seen)
	seen = seen or {}
	if seen[func] then return nil end
	seen[func] = true
	local index = 1
	while true do
		local name, value = debug.getupvalue(func, index)
		if not name then return nil end
		if name == wanted then return value end
		if type(value) == "function" then
			local found = find_upvalue(value, wanted, seen)
			if found then return found end
		end
		index = index + 1
	end
end
local participant_index = assert(find_upvalue(
	mob_api.mark_xp_participant, "participant_mobs"))

-- Load the real vendored mobs_redo API in an isolated engine fixture. Death
-- tests below call its actual check_for_death boundary; lifecycle cleanup uses
-- the registered prototype -> shared mob class lookup used by live entities.
local function copy_table(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy_table(child) end
	return result
end
local api_table = {}
for key, value in pairs(table) do api_table[key] = value end
api_table.copy = copy_table
local api_vector = {
	new = function(x, y, z)
		return type(x) == "table" and copy_table(x)
			or {x = x or 0, y = y or 0, z = z or 0}
	end,
	add = function(a, b) return {x=a.x+b.x, y=a.y+b.y, z=a.z+b.z} end,
	subtract = function(a, b) return {x=a.x-b.x, y=a.y-b.y, z=a.z-b.z} end,
	multiply = function(a, n) return {x=a.x*n, y=a.y*n, z=a.z*n} end,
	direction = function() return {x=1, y=0, z=0} end,
	distance = function() return 1 end,
}
local api_entities = {}
local smoke_effects = 0
local api_settings = {
	get = function() return nil end,
	get_bool = function(_, name) return name == "enable_damage" end,
}
local api_core = {
	settings = api_settings,
	registered_aliases = {},
	registered_nodes = {air={groups={}}, ignore={groups={}}},
	registered_items = {},
	registered_entities = api_entities,
	get_translator = function() return function(text) return text end end,
	formspec_escape = function(text) return text end,
	global_exists = function() return false end,
	get_modpath = function() return nil end,
	check_player_privs = function() return false end,
	is_player = function(obj) return obj and obj.is_player and obj:is_player() end,
	register_entity = function(name, def) api_entities[name] = def end,
	register_on_player_receive_fields = noop,
	register_chatcommand = noop,
	log = noop,
	sound_play = noop,
	add_particlespawner = function() smoke_effects = smoke_effects + 1 end,
	after = noop,
	get_objects_inside_radius = function() return {} end,
}
local api_env = setmetatable({
	core = api_core, minetest = api_core, table = api_table,
	vector = api_vector, grug_mobs = mob_api, grug_core = grug_core,
}, {__index = _G})
local api_chunk = assert(loadfile(repo .. "/mods/ENTITIES/mobs/api.lua"))
setfenv(api_chunk, api_env)
api_chunk()
local vendor_mob_class = api_env.mobs.mob_class
mob_api.registered_cadence["test:mob"] = true

local function settle_through_mobs_redo(ent)
	ent.old_health = 10
	ent.health = 0
	ent.state = "stand"
	ent.sounds = ent.sounds or {}
	ent.item_drop = noop
	ent.mob_sound = noop
	ent.update_tag = noop
	ent.death_anim = vendor_mob_class.death_anim
	ent.object.removed = false
	ent.object.remove = function(self) self.removed = true end
	ent.object.get_properties = function() return {hp_max = 100} end
	ent.object.set_properties = noop
	ent.object.get_luaentity = function() return ent end
	assert_equal(vendor_mob_class.check_for_death(ent,
		{type = "environment"}), true, "mobs_redo death boundary")
	assert_equal(ent.object.removed, true, "ordinary death fallback removal")
end

local alice = xp_player("alice", {x = 0, y = 0, z = 0}, "accord", 8100)
local bob = xp_player("bob", {x = 2, y = 0, z = 0}, "accord", 8100)
local cara = xp_player("cara", {x = 41, y = 0, z = 0}, "accord", 8100)

api_env.mobs:register_mob("test:lifecycle", {
	description = "Lifecycle", type = "animal", visual = "cube",
	textures = {{"blank.png"}}, sounds = {},
})
mob_api.registered_cadence["test:lifecycle"] = true
local lifecycle_def = assert(api_entities[":test:lifecycle"])
local unloaded = {name = "test:lifecycle", health = 100, temp = {}}
unloaded.object = {
	get_luaentity = function() return unloaded end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
}
mob_api.mark_xp_participant(unloaded, alice)
assert(participant_index.alice, "deactivation setup missing reverse index")
-- start_npcs installs its class callback only after settlement entities have
-- already been registered. The prototype must therefore keep no direct field:
-- a live instance resolves the runtime-current class callback, which then
-- chains to the earlier progression cleanup callback.
assert_equal(rawget(lifecycle_def, "on_deactivate"), nil,
	"prototype must not shadow shared deactivation callback")
local progression_deactivate = vendor_mob_class.on_deactivate
local later_deactivate_calls = 0
vendor_mob_class.on_deactivate = function(self, removal)
	later_deactivate_calls = later_deactivate_calls + 1
	assert_equal(removal, false, "shared deactivation removal argument")
	return progression_deactivate(self, removal)
end
setmetatable(unloaded, {__index = lifecycle_def})
unloaded:on_deactivate(false)
assert_equal(later_deactivate_calls, 1, "later shared deactivation callback")
assert_equal(participant_index.alice, nil, "deactivation reverse-index cleanup")
assert_equal(unloaded.temp.grug_xp_participants, nil,
	"deactivation entity participation cleanup")

local enemy = {name = "test:mob", health = 100, _grug_level = 10,
	_grug_tier = "normal", _grug_faction = "throng", temp = {}}
local enemy_object = {
	is_player = function() return false end,
	get_luaentity = function() return enemy end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
}
enemy.object = enemy_object

-- A fractional packet that has not committed one HP is not participation.
mob_api.accepted_player_punch(enemy, bob, 0.4, 0, 0.2)
assert_equal(enemy.temp.grug_xp_participants and
	enemy.temp.grug_xp_participants.bob, nil, "bank-only packet participation")
mob_api.accepted_player_punch(enemy, alice, 10, 10, 1)
mob_api.accepted_player_punch(enemy, cara, 10, 10, 1)
-- Alice is already a participant; healing her makes Bob one through the real
-- effective-heal callback. Cara remains tracked but is out of range at death.
alice.hp = 20
grug_core.heal_player(bob, alice, 1)
enemy.health = 10
mob_api.accepted_player_punch(enemy, alice, 10, 10, 1)
-- The final player hit only records participation. An unrelated environmental
-- death crosses mobs_redo's real shared boundary and a repeated settlement is
-- inert. With no on_die/on_death/animation, its ordinary smoke fallback stays.
assert_equal(grug_xp.get_xp(alice), 8100, "XP before universal death")
local smoke_before = smoke_effects
settle_through_mobs_redo(enemy)
assert_equal(grug_xp.get_xp(alice), 8150, "damager split XP")
assert_equal(grug_xp.get_xp(bob), 8150, "healer split XP")
assert_equal(grug_xp.get_xp(cara), 8100, "out-of-range participant XP")
assert_equal(enemy.temp.grug_xp_settled, true, "death settlement flag")
assert_equal(mob_api.award_kill_xp(enemy), false, "idempotent XP settlement")
assert_equal(grug_xp.get_xp(alice), 8150, "no duplicate settled XP")
assert_equal(participant_index.alice, nil, "damager reverse-index cleanup")
assert_equal(participant_index.bob, nil, "healer reverse-index cleanup")
assert_equal(participant_index.cara, nil, "range reverse-index cleanup")
assert_equal(smoke_effects, smoke_before + 1, "ordinary death smoke fallback")
record("split", {grug_xp.get_xp(alice), grug_xp.get_xp(bob),
	grug_xp.get_xp(cara)})

local guard = {name = "test:mob", health = 10, _grug_level = 10,
	_grug_tier = "normal", _grug_faction = "accord", temp = {}}
guard.object = {
	is_player = function() return false end,
	get_luaentity = function() return guard end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
}
mob_api.accepted_player_punch(guard, alice, 10, 10, 1)
settle_through_mobs_redo(guard)
assert_equal(grug_xp.get_xp(alice), 8150, "own-faction kill XP")
record("friendly", {grug_xp.get_xp(alice)})

local veteran = xp_player("veteran", {x = 0, y = 0, z = 0}, "accord", 10000)
local gray = {name = "test:mob", health = 10, _grug_level = 1,
	_grug_tier = "normal", _grug_faction = "throng", temp = {}}
gray.object = {
	is_player = function() return false end,
	get_luaentity = function() return gray end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
}
mob_api.accepted_player_punch(gray, veteran, 10, 10, 1)
settle_through_mobs_redo(gray)
assert_equal(grug_xp.get_xp(veteran), 10000, "gray kill XP")
record("gray", {grug_xp.get_xp(veteran)})

lines[#lines + 1] = "R5_PROGRESSION_OK"
return table.concat(lines, "\n") .. "\n"

-- Round-11 armor/provenance known-answer test. Loads the real combat module
-- under a small engine stub and drives its registered HP-change consumers.

local repo = arg[1] or "."
local hp_callbacks = {}
local function noop() end
local function check(condition, label)
	if not condition then error(label, 0) end
end
local function equal(actual, expected, label)
	check(actual == expected, label .. ": expected " .. tostring(expected) ..
		", got " .. tostring(actual))
end

vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x or 0, y = y or 0, z = z or 0}
	end,
	offset = function(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end,
}
core = {
	registered_items = {}, get_us_time = function() return 1000000 end,
	get_gametime = function() return 1 end,
	get_connected_players = function() return {} end,
	get_objects_inside_radius = function() return {} end,
	register_on_player_hpchange = function(fn, modifier)
		hp_callbacks[#hp_callbacks + 1] = {fn = fn, modifier = modifier}
	end,
	register_on_leaveplayer = noop, register_globalstep = noop,
	register_chatcommand = noop, chat_send_player = noop, colorize = function(_, s) return s end,
	log = noop, is_player = function(obj) return obj and obj:is_player() end,
}
setmetatable(core, {__index = function(t, key) rawset(t, key, noop) return noop end})
grug_core = {hud_layout = {text_element = function(_, def) return def end}}
dofile(repo .. "/mods/CORE/grug_core/combat.lua")

equal(grug_core.armor_k(1), 20.5, "K1")
equal(grug_core.armor_k(60), 50, "K60")
equal(grug_core.armor_k(65), 92.5, "K65")
equal(grug_core.armor_k(70), 135, "K70")
equal(string.format("%.4f", grug_core.armor_reduction(210, 70)),
	"0.6087", "Ruin L70")
equal(string.format("%.4f", grug_core.armor_reduction(294, 70)),
	"0.6853", "Bulwark L70")
equal(string.format("%.4f", grug_core.armor_reduction(309, 70)),
	"0.6959", "Unbroken window L70")
equal(grug_core.armor_reduction(10000, 1), 0.70, "final cap only")

local player = {
	hp = 1000, level = 60,
	is_player = function() return true end,
	get_player_name = function() return "target" end,
	get_hp = function(self) return self.hp end,
	get_properties = function() return {hp_max = 1000} end,
	get_pos = function() return {x = 0, y = 0, z = 0} end,
}
grug_core.get_player_level = function(object) return object.level end
grug_core.get_armor_rating = function() return 210 end
grug_core.get_dodge_chance = function() return 0 end

local function resolve(change, reason)
	for index = 1, #hp_callbacks do
		if hp_callbacks[index].modifier then
			change = hp_callbacks[index].fn(player, change, reason)
		end
	end
	return change
end
local pvp = {level = 70, is_player = function() return true end}
equal(resolve(-100, {type = "punch", object = pvp}), -40,
	"PvP attacker level")

local projectile = {
	is_player = function() return false end,
	get_luaentity = function() return {_grug_attacker_level = 70} end,
}
-- Raw 47.5 L70 damage is pressure-fitted with the existing L60 ceiling to
-- 124, then 210 rating against the immutable launch level leaves ceil(48.52).
equal(resolve(-47.5, {type = "punch", object = projectile}), -49,
	"projectile launch snapshot")
local unknown = {
	is_player = function() return false end,
	get_luaentity = function() return {} end,
}
equal(resolve(-12.5, {type = "punch", object = unknown}), -12.5,
	"unattributed bypass")
equal(resolve(-12.5, {type = "node_damage"}), -12.5,
	"environment bypass")
grug_core.get_armor_rating = function() return 0 end
equal(grug_core.apply_player_armor(player, 3.25, 70), 3.25,
	"no-rating fraction remains unrounded")

local source = assert(io.open(repo ..
	"/mods/ENTITIES/grug_mobs/boss_dragons.lua", "r")):read("*a")
check(source:find('_grug_fixed_level = 70', 1, true) ~= nil,
	"dragon actual level is not 70")
print("r11_combat_armor_kat\tPASS")

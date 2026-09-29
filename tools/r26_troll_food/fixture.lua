-- Round 26 follow-up portable fixture (LuaJIT): the Troll racial passive
-- scales food healing.
--
--   luajit tools/r26_troll_food/fixture.lua "$PWD"
--
-- Loads the real race registrations (the register_race block of
-- grug_classes/init.lua), the real grug_classes/perks.lua and the real
-- grug_food/init.lua under small stubs, then eats the same food as a Troll
-- and as every other race and runs its regeneration ticks:
--   * instant HP and every HP tick are 1.5x for the Troll, 1x otherwise;
--   * food mana ticks are not scaled (the perk's mana half is natural regen);
--   * a tick in combat heals nobody; eating in combat is refused;
--   * healing never exceeds maximum HP.
-- Prints "R26 TROLL FOOD FIXTURE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit fixture.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path) return assert(io.open(repo .. "/" .. path)):read("*a") end

local noop = function() end
local function permissive(t)
	return setmetatable(t, {__index = function() return noop end})
end

-- Engine stub: every item exists, so the food list registers.
_G.core = permissive({
	registered_items = setmetatable({}, {__index = function() return {} end}),
	get_modpath = function() return repo .. "/mods/ITEMS/grug_food" end,
	get_current_modname = function() return "grug_food" end,
	get_us_time = function() return 0 end,
})
_G.minetest = core
_G.ItemStack = function() return permissive({}) end
_G.vector = permissive({})

-- The status the food starts, captured with its tick.
local statuses = {}
_G.grug_core = permissive({
	set_status = function(player, id, def)
		statuses[player.name] = def
		return {id = id}
	end,
	in_combat = function(player) return player.combat == true end,
	can_use_item_level = function() return true end,
})
local mana_restored = {}
_G.grug_abilities = permissive({
	restore_mana = function(player, amount)
		mana_restored[player.name] = (mana_restored[player.name] or 0) + amount
		return amount
	end,
})
_G.grug_gathering = permissive({p9g_sources = function() return {} end})

-- Real race registrations and perk accessor.
_G.grug_classes = {registered_races = {}, race_ids = {}}
function grug_classes.register_race(def)
	grug_classes.registered_races[def.id] = def
end
function grug_classes.get_race_def(player)
	return grug_classes.registered_races[player.race]
end
function grug_classes.get_max_hp(player) return player.max_hp end
function grug_classes.get_max_mana(player) return player.max_mana end
local classes_init = read("mods/PLAYER/grug_classes/init.lua")
local first = assert(classes_init:find("grug_classes.register_race({", 1, true))
local last = assert(classes_init:find("local modpath", first, true))
assert(loadstring(classes_init:sub(first, last - 1), "=race registrations"))()
assert(loadfile(repo .. "/mods/PLAYER/grug_classes/perks.lua"))()
check(grug_classes.registered_races.troll.perks.ooc_regen_mult == 1.5,
	"troll perk is 1.5")

assert(loadfile(repo .. "/mods/ITEMS/grug_food/init.lua"))()

local function new_player(name, race, hp, max_hp)
	local player = {name = name, race = race, hp = hp, max_hp = max_hp,
		max_mana = 1000}
	function player.get_hp(self) return self.hp end
	function player.set_hp(self, value) self.hp = value end
	function player.is_player() return true end
	function player.get_player_name(self) return self.name end
	return player
end
local stack = permissive({})
function stack.take_item() end

-- Tier 3 caster dish: 40 instant HP, 6% HP and 6% mana per tick.
local TIER, KIND, ROLE = 3, "dish", "caster"
local MAX_HP = 1000
local function eat_and_tick(race, ticks)
	local player = new_player(race, race, 100, MAX_HP)
	grug_food.eat(stack, player, TIER, KIND, ROLE)
	local after_instant = player.hp
	local status = assert(statuses[player.name], race .. " food status")
	for _ = 1, ticks do status.on_tick(player) end
	return player, after_instant - 100, player.hp - after_instant
end

local troll, troll_instant, troll_ticks = eat_and_tick("troll", 3)
check(troll_instant == 60, "troll instant 40 x 1.5 = 60 (" .. troll_instant .. ")")
check(troll_ticks == 3 * 90, "troll ticks 3 x floor(1000 x 6% x 1.5) = 270 (" ..
	troll_ticks .. ")")
check(mana_restored.troll == 3 * 60, "troll food mana not scaled")
for race in pairs(grug_classes.registered_races) do
	if race ~= "troll" then
		local _, instant, ticks = eat_and_tick(race, 3)
		check(instant == 40, race .. " instant 40 (" .. instant .. ")")
		check(ticks == 3 * 60, race .. " ticks 3 x 60 (" .. ticks .. ")")
		check(mana_restored[race] == 3 * 60, race .. " food mana")
		print(("%-8s instant %3d  3 ticks %3d"):format(race, instant, ticks))
	end
end
print(("%-8s instant %3d  3 ticks %3d"):format("troll", troll_instant, troll_ticks))

-- Combat: the tick pauses, eating is refused.
local fighter = new_player("fighter", "troll", 500, MAX_HP)
grug_food.eat(stack, fighter, TIER, KIND, ROLE)
fighter.combat = true
statuses.fighter.on_tick(fighter)
check(fighter.hp == 560, "no troll tick in combat")
statuses.refused = nil
local refused = new_player("refused", "troll", 500, MAX_HP)
refused.combat = true
grug_food.eat(stack, refused, TIER, KIND, ROLE)
check(statuses.refused == nil and refused.hp == 500, "no eating in combat")

-- Capped at maximum HP.
local near_full = new_player("near_full", "troll", MAX_HP - 10, MAX_HP)
grug_food.eat(stack, near_full, TIER, KIND, ROLE)
statuses.near_full.on_tick(near_full)
check(near_full.hp == MAX_HP, "troll healing capped at maximum HP")

-- The race text players see.
check(grug_classes.registered_races.troll.description:find(
	"+50% food healing", 1, true), "troll description names the food bonus")

print("R26 TROLL FOOD FIXTURE PASS checks=" .. checks)

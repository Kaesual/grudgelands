-- 0.53.1 lane GEAR portable test (LuaJIT; round53-fix-plan.md rulings 3, 4).
--
--   luajit tools/r531_gear/portable_test.lua [repo]
--
--   A  through tools/r44_ch/harness.lua (the REAL grug_gear permissions and
--      grug_inventory equipment.lua): "Usable by" follows the hand rules
--      (shield: Warrior; spellbook: Mage, Priest; each weapon family its
--      classes), armour its armour class, trinkets every class; the same
--      trinket goes into both slots by a drag and by shift-click, without a
--      refusal line;
--   B  the REAL grug_gear/trinkets.lua and grug_trinkets/init.lua under a
--      small stub: simple specials add (two equal T6 double, every cap holds,
--      an over-cap pair is clamped); Last Light and Reclaimer's Mark fire once
--      from the stronger copy times (1 + the other copy's tier share
--      5..30 %) for every tier pairing in either slot order, with one shared
--      cooldown; the tooltip line "Worn twice: ..." on exactly those
--      trinkets, N = the item's own tier share.
-- Prints "R531 GEAR PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-9,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

--
-- A. Usable by, and two equal trinkets in the slots.
--
do
	local H = dofile(ROOT .. "/tools/r44_ch/harness.lua")(ROOT)
	local function usable(item) return grug_gear.usable_by(ItemStack(item)) end
	eq(usable("grug_gear:shield_bronze"), "Usable by: Warrior", "A shield: the Warrior only")
	eq(usable("grug_gear:spellbook_bronze"), "Usable by: Mage, Priest",
		"A spellbook: Mage and Priest")
	eq(usable("grug_gear:sword_bronze"), "Usable by: Warrior, Scout", "A sword")
	eq(usable("grug_gear:dagger_bronze"), "Usable by: All classes", "A dagger")
	eq(usable("grug_gear:greataxe_bronze"), "Usable by: Warrior", "A greataxe")
	eq(usable("grug_gear:bow_bronze"), "Usable by: Scout", "A bow")
	eq(usable("grug_gear:staff_bronze"), "Usable by: Mage, Priest", "A staff")
	eq(usable("grug_gear:wand_bronze"), "Usable by: Mage, Priest", "A wand")
	eq(usable("grug_gear:head_metal"), "Usable by: Warrior", "A metal armour")
	eq(usable("grug_gear:head_leather"), "Usable by: Warrior, Scout", "A leather armour")
	eq(usable("grug_gear:head_cloth"), "Usable by: All classes", "A cloth armour")
	eq(usable("grug_gear:ring_a"), "Usable by: All classes", "A a trinket")

	-- Cross-check: a class is named exactly when one of its hands takes the
	-- piece (the rule that decides equipping).
	local names = {warrior = "Warrior", scout = "Scout", mage = "Mage", priest = "Priest"}
	for _, item in ipairs({"grug_gear:shield_bronze", "grug_gear:spellbook_bronze",
			"grug_gear:sword_bronze", "grug_gear:dagger_bronze", "grug_gear:greataxe_bronze",
			"grug_gear:bow_bronze", "grug_gear:staff_bronze", "grug_gear:wand_bronze"}) do
		local text = usable(item)
		for class, name in pairs(names) do
			local takes = grug_inventory.hand_accepts(class, "grug_weapon", ItemStack(item)) or
				grug_inventory.hand_accepts(class, "grug_offhand", ItemStack(item))
			local named = text == "Usable by: All classes" or text:find(name, 1, true) ~= nil
			eq(named, takes, "A " .. item .. " names " .. class .. " exactly when a hand takes it")
		end
	end

	-- The same trinket twice: a drag onto the free slot, then shift-click.
	local feeds_before = #H.feed
	local p = H.player("twin", "priest")
	H.put(p, "grug_trinket1", 1, "grug_gear:ring_a")
	H.put(p, "main", 9, "grug_gear:ring_a")
	eq(H.move(p, "main", 9, "grug_trinket2", 1, 1, false), 1, "A a drag puts the twin in slot 2")
	eq(H.get(p, "grug_trinket2", 1), "grug_gear:ring_a", "A ... it is equipped")
	H.put(p, "grug_trinket2", 1, "")
	H.put(p, "main", 10, "grug_gear:ring_a")
	H.shift(p, H.page(p, "stats"), "main", 10)
	eq(H.get(p, "grug_trinket1", 1) .. "|" .. H.get(p, "grug_trinket2", 1),
		"grug_gear:ring_a|grug_gear:ring_a", "A shift-click puts the twin in the free slot")
	-- Swapping the two equipped copies stays allowed.
	eq(H.move(p, "grug_trinket1", 1, "grug_trinket2", 1, 1, false), 1,
		"A the two copies swap slots")
	eq(#H.feed, feeds_before, "A no refusal line for the twin")
end

--
-- B. The specials of two worn trinkets.
--
local registered = {}
local leave_callbacks, equipment_callbacks = {}, {}
core = {
	registered_items = registered,
	colorize = function(color, text) return "{" .. color .. "}" .. text end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_on_leaveplayer = function(f) leave_callbacks[#leave_callbacks + 1] = f end,
}
minetest = core
local BRACKET_ILVL = {1, 11, 21, 31, 41, 51}
grug_gear = {BRACKETS = {}, required_level = function(ilvl) return ilvl end}
for tier = 1, 6 do grug_gear.BRACKETS[tier] = {ilvl = BRACKET_ILVL[tier]} end
assert(loadfile(ROOT .. "/mods/ITEMS/grug_gear/trinkets.lua"))()

local absorbs, rage_added, mana_restored, flashes = {}, {}, {}, {}
grug_core = {
	register_on_equipment_change = function(f) equipment_callbacks[#equipment_callbacks + 1] = f end,
	add_absorb = function(player, key, amount, seconds)
		absorbs[#absorbs + 1] = {key = key, amount = amount, seconds = seconds}
	end,
	proc_flash = function(_, key) flashes[#flashes + 1] = key end,
	get_melee_weapon = function() return true end,
}
local CLASS_DEFS = {warrior = {resource = "rage"}, mage = {resource = "mana"}}
grug_classes = {
	get_max_hp = function(player) return player.hp_max end,
	get_max_mana = function() return 1000 end,
	get_class_def = function(player) return CLASS_DEFS[player.class_id] end,
}
grug_abilities = {
	add_rage = function(_, amount) rage_added[#rage_added + 1] = amount end,
	restore_mana = function(_, amount) mana_restored[#mana_restored + 1] = amount end,
}
assert(loadfile(ROOT .. "/mods/PLAYER/grug_trinkets/init.lua"))()

local function new_player(name, class_id)
	local lists = {grug_trinket1 = "", grug_trinket2 = ""}
	local meta = {}
	local player = {class_id = class_id, hp = 200, hp_max = 200}
	function player:get_player_name() return name end
	function player:get_inventory()
		return {get_stack = function(_, list)
			local item = lists[list] or ""
			return {is_empty = function() return item == "" end,
				get_name = function() return item end}
		end}
	end
	function player:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	function player:get_properties() return {hp_max = self.hp_max} end
	function player:get_hp() return self.hp end
	function player:set_hp(hp) self.hp = hp end
	function player:wear(first, second)
		lists.grug_trinket1, lists.grug_trinket2 = first or "", second or ""
		for _, f in ipairs(equipment_callbacks) do f(self, "grug_trinket1") end
	end
	function player:clear_cooldowns() for k in pairs(meta) do meta[k] = nil end end
	return player
end
local function item(key, tier) return grug_gear.trinket_item(key, tier) end

-- B1. Simple specials add; two equal T6 double, the caps hold.
local p = new_player("adder", "mage")
p:wear(item("manawell", 6), item("manawell", 6))
near(grug_trinkets.mana_regen(p), 1.00, "B1 two T6 Manawell double (0.50 + 0.50)")
p:wear(item("manawell", 6))
near(grug_trinkets.mana_regen(p), 0.50, "B1 one T6 Manawell")
p:wear(item("manawell", 6), item("manawell", 3))
near(grug_trinkets.mana_regen(p), 0.65, "B1 T6 + T3 Manawell add")
p:wear(item("mercy_seal", 6), item("mercy_seal", 6))
near(grug_trinkets.modify_outgoing_heal(p, 100), 112, "B1 two T6 Mercy Seals: +12 %")
p:wear(item("apothecary_loop", 6), item("apothecary_loop", 6))
near(grug_trinkets.modify_instant_potion(p, 100), 130, "B1 two T6 Apothecary Loops: +30 %")
local w = new_player("beat", "warrior")
w:wear(item("battlebeat", 6), item("battlebeat", 6))
rage_added = {}
grug_trinkets.accepted_weapon_hit(w)
near(rage_added[1], 4, "B1 two T6 Battlebeat Bands: 4 Rage per hit")
-- Every additive cap is at least twice its T6 value, so equal T6 double.
for _, identity in ipairs(grug_gear.TRINKETS) do
	if identity.stacking == "additive" then
		check(identity.cap >= 2 * identity.values[6] - 1e-9,
			"B1 " .. identity.key .. "'s cap holds two T6")
	end
end
-- The cap clamps a pair above it.
registered["test:big_well"] = {_grug_trinket_identity = "manawell",
	_grug_trinket_kind = "mana_regen", _grug_trinket_value = 0.8,
	_grug_trinket_stacking = "additive", _grug_trinket_cap = 1.00}
p:wear("test:big_well", "test:big_well")
near(grug_trinkets.mana_regen(p), 1.00, "B1 the cap holds (0.8 + 0.8 -> 1.00)")

-- B2. Last Light and Reclaimer's Mark: every tier pairing, both orders.
local SHARE = {5, 10, 15, 20, 25, 30}
local function pair_value(identity, a, b, field)
	local values = field == "rage" and identity.rage or identity.values
	local strong, other = a, b
	if values[b] > values[a] then strong, other = b, a end
	return values[strong] * (1 + SHARE[other] / 100)
end
local last_light, reclaimer
for _, identity in ipairs(grug_gear.TRINKETS) do
	if identity.key == "last_light" then last_light = identity end
	if identity.key == "reclaimers_mark" then reclaimer = identity end
end

-- Last Light through after_player_hit: a 200-HP player dropped below 25 %.
local function last_light_absorb(first, second)
	local q = new_player("ll", "mage")
	q:wear(first, second)
	absorbs = {}
	q.hp = 60
	grug_trinkets.after_player_hit(q, -20, {type = "punch"})
	return absorbs[1], q
end
local all_pairs_ok = true
for a = 1, 6 do
	for b = 1, 6 do
		local absorb = last_light_absorb(item("last_light", a), item("last_light", b))
		local want = math.max(1, math.floor(200 * pair_value(last_light, a, b) / 100 + 0.5))
		if not absorb or absorb.amount ~= want or absorb.seconds ~= 120 then
			all_pairs_ok = false
			print(("  Last Light T%d + T%d: got %s, expected %d"):format(a, b,
				tostring(absorb and absorb.amount), want))
		end
	end
end
check(all_pairs_ok, "B2 Last Light: every tier pairing is the stronger x (1 + the other's share)")
eq((last_light_absorb(item("last_light", 6), item("last_light", 1))).amount, 21,
	"B2 Last Light T6 + T1: 10 % x 1.05 = 10.5 % of 200")
eq((last_light_absorb(item("last_light", 3), item("last_light", 3))).amount, 12,
	"B2 Last Light T3 + T3: 5 % x 1.15 = 5.75 % of 200")
eq((last_light_absorb(item("last_light", 1), item("last_light", 6))).amount, 21,
	"B2 Last Light T1 + T6: the stronger copy in slot 2 fires, T1 strengthens it")
eq((last_light_absorb(item("last_light", 6))).amount, 20, "B2 Last Light T6 alone: 10 %")
eq((last_light_absorb(item("last_light", 6), item("manawell", 6))).amount, 20,
	"B2 another trinket does not strengthen Last Light")
-- One shared cooldown: the pair fires once in 120 s.
do
	local absorb, q = last_light_absorb(item("last_light", 6), item("last_light", 6))
	check(absorb ~= nil, "B2 the pair fires")
	absorbs = {}
	q.hp = 60
	grug_trinkets.after_player_hit(q, -20, {type = "punch"})
	eq(#absorbs, 0, "B2 the pair shares one cooldown (no second absorb)")
end

-- Reclaimer's Mark through xp_eligible_kill: HP and Mana for a Mage, Rage
-- for a Warrior; the 10-s shared cooldown.
local function reclaim(class_id, first, second)
	local q = new_player("rm_" .. class_id, class_id)
	q:wear(first, second)
	q.hp = 100
	rage_added, mana_restored = {}, {}
	grug_trinkets.xp_eligible_kill(q)
	return q
end
local reclaim_ok = true
for a = 1, 6 do
	for b = 1, 6 do
		local q = reclaim("mage", item("reclaimers_mark", a), item("reclaimers_mark", b))
		local percent = pair_value(reclaimer, a, b)
		local hp = 100 + math.max(1, math.floor(200 * percent / 100 + 0.5))
		local mana = math.max(1, math.floor(1000 * percent / 100 + 0.5))
		local r = reclaim("warrior", item("reclaimers_mark", a), item("reclaimers_mark", b))
		local rage = pair_value(reclaimer, a, b, "rage")
		if q.hp ~= hp or mana_restored[1] ~= nil or r.hp ~= hp or
				math.abs((rage_added[1] or -1) - rage) > 1e-9 then
			reclaim_ok = false
			print(("  Reclaimer T%d + T%d: hp %s/%d rage %s/%s"):format(a, b,
				tostring(r.hp), hp, tostring(rage_added[1]), tostring(rage)))
		end
		q = reclaim("mage", item("reclaimers_mark", a), item("reclaimers_mark", b))
		if mana_restored[1] ~= mana then
			reclaim_ok = false
			print(("  Reclaimer T%d + T%d: mana %s/%d"):format(a, b,
				tostring(mana_restored[1]), mana))
		end
	end
end
check(reclaim_ok, "B2 Reclaimer's Mark: every tier pairing, HP, Mana and Rage")
do
	local q = reclaim("mage", item("reclaimers_mark", 6), item("reclaimers_mark", 1))
	eq(mana_restored[1], 42, "B2 Reclaimer T6 + T1: 4 % x 1.05 = 4.2 % of 1000 Mana")
	eq(q.hp, 108, "B2 ... and 8 of 200 HP")
	q = reclaim("warrior", item("reclaimers_mark", 3), item("reclaimers_mark", 3))
	near(rage_added[1], 3 * 1.15, "B2 Reclaimer T3 + T3: 3 Rage x 1.15")
	reclaim("mage", item("reclaimers_mark", 1), item("reclaimers_mark", 6))
	eq(mana_restored[1], 42, "B2 Reclaimer T1 + T6: the same as T6 + T1")
	-- One shared cooldown.
	q = reclaim("mage", item("reclaimers_mark", 6), item("reclaimers_mark", 6))
	mana_restored = {}
	grug_trinkets.xp_eligible_kill(q)
	eq(#mana_restored, 0, "B2 the pair shares one cooldown (no second restore)")
end

-- B3. The tooltip line: exactly Last Light and Reclaimer's Mark, N = the
-- item's own tier share.
local LINE = "Worn twice: the second one strengthens the effect by %d%%."
for _, identity in ipairs(grug_gear.TRINKETS) do
	for tier = 1, 6 do
		local def = registered[item(identity.key, tier)]
		local line = LINE:format(SHARE[tier])
		local has = def.description:find(line, 1, true) ~= nil
		if identity.stacking == "highest" then
			check(has, "B3 " .. identity.key .. " T" .. tier .. " names " .. SHARE[tier] .. " %")
			eq(grug_gear.trinket_pair_line(def), line,
				"B3 " .. identity.key .. " T" .. tier .. " the stored-description line")
		else
			check(def.description:find("Worn twice", 1, true) == nil,
				"B3 " .. identity.key .. " T" .. tier .. " has no pair line")
			eq(grug_gear.trinket_pair_line(def), nil,
				"B3 " .. identity.key .. " T" .. tier .. " no stored-description line")
		end
	end
end

if failures > 0 then
	error(("R531 GEAR PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
print(("R531 GEAR PORTABLE PASS checks=%d"):format(checks))

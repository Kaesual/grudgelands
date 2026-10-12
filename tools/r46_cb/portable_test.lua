-- Round 46 lane CB portable test (round46-plan.md §4.5, rulings 9 and 10).
-- Cuts the REAL code out of the shipped files under small stubs and checks:
--   A. rage per landed swing = (8 + Stoke) x the weapon's BASE swing interval
--      / 1 s: the same rage per second for dagger, sword, battle axe, staff,
--      wand and the bare hand, with and without Stoke; the attack-speed
--      enchant (a shorter interval in the stack's meta) leaves the per-hit
--      grant alone; fractions are kept;
--   B. the swing path carries the base interval from attempt_swing's
--      transaction through prepare into the three grants of the real
--      finish_authoritative_swing;
--   C. the Strike tooltip names the equipped weapon's per-hit value;
--   D. the spell base (ruling 10, option B): an own-level staff or wand
--      reproduces today's Bw(L) at every level, a first-tier weapon at L30
--      and L60 gives the option-B value, no caster weapon adds 0 (the
--      user, 2026-10-12: half the base); the real caster lookup reads the Weapon slot's staff or wand
--      at its effective item level and ignores other weapons;
--   E. the real Fireball and Ice Nova value functions use the spell base, no
--      spell site reads baseline_weapon_damage any more, Smite uses it;
--   F. the staff and wand tooltip line matches the combat value.
--   G. the caster talent amounts (the user's answer of 2026-10-12): the real
--      talent_level_amount gives a Mage or Priest damage key its share of
--      the base hit times spell base / Bw(L): today's numbers with an
--      own-level staff or wand at L1/30/60, scaled with a first-tier weapon
--      and halved without one; Warrior and Scout keys stay on the base hit.
--
-- Usage (repo root): luajit tools/r46_cb/portable_test.lua [REPO]
local ROOT = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function near(a, b, label)
	check(math.abs(a - b) < 1e-9, label .. " (" .. tostring(a) .. " vs " ..
		tostring(b) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(text, pattern, label)
	local found = text:match(pattern)
	check(found ~= nil, label .. " found")
	return found
end

local INIT = read("mods/PLAYER/grug_abilities/init.lua")
local KITS = read("mods/PLAYER/grug_abilities/kits.lua")
local COMBAT = read("mods/CORE/grug_core/combat.lua")
local GEAR = read("mods/ITEMS/grug_gear/init.lua")

-- The real fit formulas of grug_core, the new helpers included.
grug_core = {}
assert(loadstring(cut(COMBAT, "(function grug_core%.base_pool%(level%).-\n" ..
	"function grug_core%.level_scale%(level%).-\nend)\n", "the fit block")))()
check(type(grug_core.spell_base) == "function" and
	type(grug_core.caster_weapon_value) == "function", "the spell base helpers")

-- The real weapon families: their base intervals and factors.
local WEAPONS = assert(loadstring(cut(GEAR, "\n(local WEAPONS = %b{})\n",
	"WEAPONS") .. "\nreturn WEAPONS"))()
local FAMILY = {}
for _, w in ipairs(WEAPONS) do FAMILY[w.key] = w end
check(FAMILY.dagger.fpi == 0.7 and FAMILY.sword.fpi == 1.0 and
	FAMILY.greataxe.fpi == 1.4 and FAMILY.staff.fpi == 1.4 and
	FAMILY.wand.fpi == 1.0, "the family base intervals")

-- Stacks: a definition, item meta and per-stack capabilities.
local function stack_of(family, opts)
	opts = opts or {}
	local w = family and FAMILY[family]
	local groups = {grug_equip_weapon = 1}
	if w then
		groups[w.group] = 1
		if w.caster then groups.grug_caster_weapon = 1 end
	end
	local def = w and {
		groups = groups,
		_grug_weapon_family = family,
		_grug_ilvl = opts.def_ilvl or 1,
		tool_capabilities = {full_punch_interval = w.fpi,
			damage_groups = {fleshy = 5}},
	}
	return {
		_ilvl = opts.ilvl,
		is_empty = function() return def == nil end,
		get_definition = function() return def end,
		get_tool_capabilities = function()
			local fpi = w and w.fpi or 0.9
			return {full_punch_interval = fpi / (1 + (opts.speed or 0) / 100),
				damage_groups = {fleshy = 5}}
		end,
	}
end

------------------------------------------------------------------------------
-- A: rage per swing by the weapon's base interval.
------------------------------------------------------------------------------
local equipped, stoke = nil, 0
grug_core.get_melee_weapon = function() return equipped end
grug_classes = {get_talent_bonus = function(_, key)
	return key == "rage_per_swing_add" and stoke or 0
end}
grug_abilities = {}
local bare = cut(KITS, "\n(local bare_hand = %b{})\n", "bare_hand")
local base_interval = cut(KITS, "\n(function grug_abilities%.base_swing_interval%(" ..
	".-\nend)\n", "base_swing_interval")
assert(loadstring(bare .. "\n" .. base_interval))()
local rage_block = cut(INIT, "\n(grug_abilities%.RAGE_PER_SWING = 8\n.-" ..
	"grug_abilities%.swing_rage = swing_rage)\n", "the rage block")
assert(loadstring(rage_block))()
local swing_rage = grug_abilities.swing_rage
check(grug_abilities.RAGE_PER_HIT_TAKEN == 3, "rage per hit taken unchanged")

local cases = {{"dagger", 0.7}, {"sword", 1.0}, {"greataxe", 1.4},
	{"staff", 1.4}, {"wand", 1.0}, {nil, 0.9}}
for rank = 0, 4 do
	stoke = rank
	for _, case in ipairs(cases) do
		local name = (case[1] or "hand") .. " Stoke " .. rank
		equipped = case[1] and stack_of(case[1]) or nil
		local interval = grug_abilities.base_swing_interval({})
		near(interval, case[2], "A base interval " .. name)
		local per_hit = swing_rage({})
		near(per_hit, (8 + rank) * case[2], "A rage per hit " .. name)
		near(per_hit / interval, 8 + rank, "A rage per second " .. name)
		near(swing_rage({}, interval), per_hit, "A an explicit interval " .. name)
	end
end
stoke = 0
equipped = stack_of("dagger")
near(swing_rage({}), 5.6, "A a dagger keeps the fraction 5.6")
-- Attack speed shortens the stack's interval; the base stays.
equipped = stack_of("greataxe", {speed = 25})
near(equipped:get_tool_capabilities().full_punch_interval, 1.12,
	"A the enchanted axe swings faster")
near(swing_rage({}), 11.2, "A attack speed leaves the per-hit grant at 11.2")
local empty = {is_empty = function() return true end}
near(grug_abilities.base_swing_interval({}, empty), 0.9, "A an empty stack is the hand")

------------------------------------------------------------------------------
-- B: the base interval travels through prepare and finish.
------------------------------------------------------------------------------
check(INIT:find("\t\tbase_fpi = grug_abilities.base_swing_interval(player, weapon),\n",
	1, true) ~= nil, "B attempt_swing's transaction carries the base interval")
grug_core.valid_authoritative_swing = function() return true end
local swing_context = {weapon_damage = 5, fpi = 0.56, base_fpi = 0.7,
	melee_bonus = 1, raw_damage = 6, scaled_damage = 6, threat_mult = 1}
grug_core.get_authoritative_swing_context = function() return swing_context end
local prepare = assert(loadstring(cut(INIT,
	"\n(local function prepare_authoritative_swing%(.-\nend)\n", "prepare") ..
	"\nreturn prepare_authoritative_swing"))()
local context = prepare({}, {}, {})
near(context.base_fpi, 0.7, "B prepare hands on the base interval, not the hastened one")

local granted = {}
grug_abilities.add_rage = function(_, amount) granted[#granted + 1] = amount end
grug_abilities.reset_charge = function() end
grug_core.run_settled_outgoing_action = function() end
grug_core.combat_debug_due = function() return false end
grug_core.add_threat = function() end
local spend_ok = true
core = {log = function() end}
local finish = assert(loadstring("local spend, swing_rage, play_skill_pose = ...\n" ..
	cut(INIT, "\n(local function finish_authoritative_swing%(.-\nend)\n", "finish") ..
	"\nreturn finish_authoritative_swing", "=finish"))(
	function() return spend_ok end, swing_rage, function() end)
equipped = stack_of("sword") -- the context's interval wins over the slot's
local function settle(proc)
	granted = {}
	finish({player = {}, proc = proc, proc_cost = {}, base_fpi = 0.7,
		threat_mult = 1}, {landed = true, grant_rage = true})
	return granted[1]
end
near(settle(nil), 5.6, "B Strike grants the dagger's 5.6")
near(settle({id = "mighty_blow"}), 5.6, "B a proc swing grants the dagger's 5.6")
spend_ok = false
near(settle({id = "mighty_blow"}), 5.6, "B the lost-resource path grants 5.6")
spend_ok = true

------------------------------------------------------------------------------
-- C: the Strike tooltip.
------------------------------------------------------------------------------
local describe = assert(loadstring(cut(KITS,
	"\n(local strike_description = .-prevents click spam%.\")\n", "description") ..
	"\nreturn " .. cut(KITS, "\n\tdescription_for = (function%(player%)\n" ..
	"\t\tlocal class_def = .-\n\tend),\n", "Strike's description_for")))()
grug_classes.get_class_def = function() return {resource = "rage"} end
equipped = stack_of("dagger")
check(describe({}):find("Generates 5.6 rage when it lands.", 1, true),
	"C a dagger shows 5.6")
equipped = stack_of("greataxe")
check(describe({}):find("Generates 11.2 rage when it lands.", 1, true),
	"C a battle axe shows 11.2")
equipped = stack_of("sword")
check(describe({}):find("Generates 8 rage when it lands.", 1, true),
	"C a sword shows 8")
stoke = 3
equipped = stack_of("dagger")
check(describe({}):find("Generates 7.7 rage when it lands.", 1, true),
	"C a dagger with Stoke 3/4 shows 7.7")
stoke = 0
grug_classes.get_class_def = function() return {resource = "mana"} end
check(not describe({}):find("rage", 1, true), "C a caster sees no rage")

------------------------------------------------------------------------------
-- D: the spell base.
------------------------------------------------------------------------------
for level = 1, 60 do
	local bw = grug_core.baseline_weapon_damage(level)
	near(grug_core.spell_base(level, level), bw, "D own level equals Bw at L" .. level)
	near(grug_core.caster_weapon_value(level), bw, "D the weapon value at L" .. level)
end
near(grug_core.spell_base(1, nil), 0.5 * grug_core.baseline_weapon_damage(1),
	"D level 1 without a caster weapon: the level half alone")
near(grug_core.spell_base(30, 1), 0.5 * 15 + 0.5 * 4, "D a T1 weapon at L30: 9.5")
near(grug_core.spell_base(60, 1), 0.5 * 25 + 0.5 * 4, "D a T1 weapon at L60: 14.5")
near(grug_core.spell_base(60, nil), 12.5, "D no caster weapon at L60: 25 / 2")
near(grug_core.spell_base(30, nil), 7.5, "D no caster weapon at L30: 15 / 2")
near(grug_core.spell_base(60, 70), 0.5 * 25 + 0.5 * 29, "D item level 70 at L60")

local level, slot = 60, nil
grug_core.get_player_level = function() return level end
grug_core.get_equipped_weapon = function() return slot end
grug_items = {effective_ilvl = function(stack)
	return stack._ilvl or stack:get_definition()._grug_ilvl
end}
assert(loadstring(cut(KITS, "\n(function grug_abilities%.caster_weapon_ilvl%(player%).-\n" ..
	"function grug_abilities%.spell_base%(player%).-\nend)\n", "caster lookup")))()
slot = stack_of("staff", {def_ilvl = 1})
near(grug_abilities.spell_base({}), 14.5, "D the Bronze Staff at L60")
slot = stack_of("wand", {def_ilvl = 51, ilvl = 60})
near(grug_abilities.spell_base({}), 25, "D an upgraded own-level wand at L60")
slot = stack_of("staff", {def_ilvl = 51, ilvl = 60})
near(grug_abilities.spell_base({}), 25, "D an upgraded own-level staff at L60")
slot = stack_of("sword", {def_ilvl = 51, ilvl = 60})
near(grug_abilities.spell_base({}), 12.5, "D a sword is no caster weapon")
slot = stack_of("dagger", {def_ilvl = 51, ilvl = 60})
near(grug_abilities.spell_base({}), 12.5, "D a dagger is no caster weapon")
slot = nil
near(grug_abilities.spell_base({}), 12.5, "D an empty Weapon slot")
level = 30
slot = stack_of("wand", {def_ilvl = 21, ilvl = 30})
near(grug_abilities.spell_base({}), 15, "D an own-level wand at L30")
grug_items = nil
slot = stack_of("wand", {def_ilvl = 21})
near(grug_abilities.spell_base({}), 0.5 * 15 + 0.5 * 11, "D without grug_items the definition's ilvl")

------------------------------------------------------------------------------
-- E: the spell sites.
------------------------------------------------------------------------------
check(not KITS:find("baseline_weapon_damage", 1, true), "E no spell reads Bw(L) directly")
local _, uses = KITS:gsub("grug_abilities%.spell_base%(user%)", "")
check(uses == 3, "E Fireball, Ice Nova and Smite use the spell base (" .. uses .. ")")
check(KITS:find("local damage = (grug_abilities.spell_base(user)\n" ..
	"\t\t\t+ grug_classes.get_spell_power_bonus(user)) * 1.5", 1, true) ~= nil,
	"E Smite's base is the spell base")
local power, talent = 3, 0
grug_classes.get_talent_bonus = function() return talent end
grug_classes.get_spell_power_bonus = function() return power end
grug_classes.get_spell_damage_percent = function() return 0 end
local values = assert(loadstring(cut(KITS, "\n(local function spell_damage_value.-\nend)\n",
	"spell_damage_value") .. "\n" ..
	cut(KITS, "\n(local function fireball_values%(user%).-\nend)\n", "fireball_values") .. "\n" ..
	cut(KITS, "\n(local function nova_values%(user%).-\nend)\n", "nova_values") ..
	"\nreturn fireball_values, nova_values"))
local fireball_values, nova_values = values()
level = 60
grug_items = {effective_ilvl = function(stack) return stack._ilvl end}
slot = stack_of("staff", {ilvl = 60})
near(fireball_values({}).damage, 25 + 3, "E an own-level Fireball is today's 28")
near(nova_values({}).damage, (25 + 3) / 4, "E an own-level Ice Nova is today's 7")
slot = stack_of("staff", {ilvl = 1})
near(fireball_values({}).damage, 14.5 + 3, "E a Bronze Staff Fireball at L60")
near(nova_values({}).damage, (14.5 + 3) / 4, "E a Bronze Staff Ice Nova at L60")
slot = nil
near(fireball_values({}).damage, 12.5 + 3, "E a Fireball without a caster weapon at L60")

------------------------------------------------------------------------------
-- F: the staff and wand tooltip line.
------------------------------------------------------------------------------
grug_gear = {}
assert(loadstring(cut(GEAR, "\n(local function one_hand_damage%(ilvl%).-\nend)\n",
	"one_hand_damage") .. "\n" .. cut(GEAR,
	"\n(function grug_gear%.spell_base_line%(family, ilvl%).-\nend)\n", "spell_base_line")))()
for ilvl = 1, 75 do
	local expected = grug_core.caster_weapon_value(ilvl) ..
		" spell base: half of your spells' base damage"
	check(grug_gear.spell_base_line("staff", ilvl) == expected, "F staff line at ilvl " .. ilvl)
	check(grug_gear.spell_base_line("wand", ilvl) == expected, "F wand line at ilvl " .. ilvl)
end
check(grug_gear.spell_base_line("sword", 30) == nil and
	grug_gear.spell_base_line("greataxe", 30) == nil and
	grug_gear.spell_base_line("dagger", 30) == nil and
	grug_gear.spell_base_line("bow", 30) == nil, "F no line on other families")

------------------------------------------------------------------------------
-- G: the caster talent amounts.
------------------------------------------------------------------------------
grug_xp = {get_level = function() return level end}
grug_core.armor_k = function(l) return 20 + 0.5 * l end
assert(loadstring(cut(read("mods/PLAYER/grug_classes/talents.lua"),
	"\n(local LEVEL_SCALED_KEYS = %b{}.-\nfunction grug_classes%.talent_level_amount" ..
	"%(player, key, value%).-\nend)\n", "the talent level amounts")))()
local SPELL = {"fireball_damage_add", "fireball_splash", "whitehot_damage",
	"cinderfall_damage", "control_damage_add", "smite_damage_add",
	"smite_damage_while_shielded_add", "word_of_ruin_damage"}
local spell_set = {}
for _, key in ipairs(SPELL) do
	spell_set[key] = true
	check(grug_classes.TALENT_SPELL_KEYS[key] == true, "G " .. key .. " follows the weapon")
end
for key, unit in pairs(grug_classes.TALENT_LEVEL_SCALED_KEYS) do
	if not spell_set[key] then
		check(not grug_classes.TALENT_SPELL_KEYS[key], "G " .. key .. " stays on the base hit")
	end
end
grug_items = {effective_ilvl = function(stack) return stack._ilvl end}
local amount = grug_classes.talent_level_amount
for _, l in ipairs({1, 30, 60}) do
	level = l
	local today = 20 * grug_core.baseline_melee_total(l) / 100
	local ratio = grug_core.spell_base(l, 1) / grug_core.baseline_weapon_damage(l)
	for _, key in ipairs(SPELL) do
		slot = stack_of("wand", {ilvl = l})
		check(amount({}, key, 20) == today, "G own-level wand " .. key .. " at L" .. l)
		slot = stack_of("staff", {ilvl = l})
		check(amount({}, key, 20) == today, "G own-level staff " .. key .. " at L" .. l)
		slot = stack_of("staff", {ilvl = 1})
		near(amount({}, key, 20), today * ratio, "G T1 staff " .. key .. " at L" .. l)
		slot = nil
		near(amount({}, key, 20), today * 0.5, "G no weapon " .. key .. " at L" .. l)
	end
	for _, key in ipairs({"melee_damage_add", "loose_damage_add", "longshot_damage_add"}) do
		slot = nil
		check(amount({}, key, 20) == today, "G " .. key .. " unchanged at L" .. l)
	end
end
level = 60
slot = stack_of("staff", {ilvl = 1})
near(amount({}, "fireball_damage_add", 20), 20 * 43.7 / 100 * 14.5 / 25,
	"G Tinder 5/5 with the Bronze Staff at L60")
check(amount({}, "crit_chance_add", 5) == 5, "G an unscaled key is its value")

print(("R46 CB PASS (%d checks)"):format(checks))

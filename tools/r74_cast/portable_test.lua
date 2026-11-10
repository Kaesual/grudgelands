-- Round 74 lane CAST portable test (LuaJIT; round74-plan.md §4 CAST): a self
-- or support skill pressed while the action clock is busy waits for it.
--
--   luajit tools/r74_cast/portable_test.lua [repo]
--
-- Loads the REAL grug_abilities/input.lua on a fake engine (the pattern of
-- tools/r53_hooks section F) whose clocks follow init.lua's action clock
-- (D2, K9): a swing holds casts back until the next swing is due, a cast
-- holds the next cast back its occupied_cast and the next swing its
-- occupied_swing; the swing clock never swings before it is due. Input
-- passes run every 0.09 s (one engine step). Every case prints one
-- "CASE <id> <observed>" line, so a run on the old input.lua gives the
-- "before" column.
--   R  the user's finding (2026-11-10): Ruination pressed with a mob in the
--      crosshair while Strike's swing occupies the clock (released and
--      pressed again, carried across a hotbar switch, Hold Ground too) fires
--      at the first pass its clock allows, with no swing of that press
--      before it;
--   C  a series of short clicks on Ruination at a mob, swept over weapon
--      intervals, click lengths and phases: the first click casts, at the
--      first pass the clock allows (the old code: the held part of every
--      click swung Strike and kept the clock busy);
--   M  other classes: Ice Nova (an offensive self skill) and Blink after a
--      Fiery Spark, a Heal at an ally after a Smite; a waiting heal keeps
--      the recipient its press aimed at (the ally, or the caster); the
--      wait covers a cast's occupied time longer than the weapon interval
--      (Shield after Heal with a wand, Sidestep after Arrowfall with a
--      dagger);
--   Q  the queue's limits: cost and cooldown refusals stay immediate and
--      loud (and fall back as before), a free clock casts at once, a lock
--      longer than the weapon interval is waited out, a lock pushed further
--      while waiting ends the wait after what held it at the press (at
--      least one weapon interval) plus the grace (reported, the held
--      fallback resumes), on a hotbar switch, a row switch, an RMB
--      interaction, death and a stun,
--      and when another refusal appears (reported); a new press replaces the
--      waiting one; a hostile-target skill never waits;
--   W  the accessor the cooldown overlay reads (input.waiting, Round 74
--      HUD): the waiting def while it waits, nil once it fired or dropped.
-- Prints "R74 CAST PORTABLE PASS checks=<n>" or the failures (an error).

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
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function case(id, observed) print(("CASE %-4s %s"):format(id, observed)) end

------------------------------------------------------------------------------
-- The fake engine (the subset input.lua uses).
------------------------------------------------------------------------------
vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.distance(a, b)
	local d = vector.subtract(a, b)
	return math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
end

local STEP = 90000 -- one engine step (dedicated_server_step 0.09 s)
local clock = 0
local EYE = vector.new(0, 1.47, 0)
local function actor(kind)
	local ref = {kind = kind}
	function ref:get_pos() return vector.new(0, 1, 2) end
	function ref:is_player() return kind == "ally" end
	function ref:get_luaentity()
		return kind == "mob" and {name = "test:mob", health = 10, _cmi_is_mob = true, temp = {}} or nil
	end
	return ref
end
local mob, ally, forbidden = actor("mob"), actor("ally"), actor("ally")
local aim = "mob" -- what the crosshair is on: "mob", "ally" or "air"
-- "forbidden": an ally the PvP flag forbids supporting.
local function aimed()
	return aim == "mob" and mob or aim == "ally" and ally or aim == "forbidden" and forbidden or nil
end
local loaded, on_die = {}, {}
core = {
	registered_nodes = {}, registered_entities = {["__builtin:item"] = {on_punch = function() end}},
	get_us_time = function() return clock end,
	check_player_privs = function() return true end,
	get_node_or_nil = function() return {name = "air"} end,
	is_protected = function() return false end,
	get_item_group = function(name, group)
		return group == "grug_ability" and name:sub(1, 15) == "grug_abilities:" and 1 or 0
	end,
	override_item = function() end,
	register_on_mods_loaded = function(f) loaded[#loaded + 1] = f end,
	register_on_dieplayer = function(f) on_die[#on_die + 1] = f end,
	register_on_leaveplayer = function() end,
	register_on_joinplayer = function() end,
}
grug_mobs = {evade_notice = function() end}
grug_inventory = {HOTBAR_STORE = "grug_hotbar_store"}
rawset(_G, "ItemStack", function() return {get_tool_capabilities = function() return {} end} end)
local stunned, on_stun = false, {}
grug_core = {
	combat_eye_pos = function() return vector.copy(EYE) end,
	combat_actor = function(ref) return ref end,
	aim_raycast = function()
		local ref, done = aimed(), false
		return function()
			if done or not ref then return nil end
			done = true
			return {type = "object", ref = ref, intersection_point = vector.new(0, 1.47, 2)}
		end
	end,
	unseen_by = function() return false end,
	is_stunned = function() return stunned end,
	player_has_live_mount = function() return false end,
	register_on_stun = function(f) on_stun[#on_stun + 1] = f end,
	combat_ray = function()
		local ref = aimed()
		if not ref then return {status = "none", reason = "nothing"} end
		return {target = ref, distance = 2, status = "target",
			reason = ref == mob and "hostile" or "friendly",
			pointed = {intersection_point = vector.new(0, 1.47, 2)}}
	end,
}

------------------------------------------------------------------------------
-- The skills (their shipped clock values) and the action clock.
------------------------------------------------------------------------------
local defs = {
	strike = {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike",
		occupied_cast = "weapon"},
	ruination = {id = "ruination", kind = "cast", target_kind = "self", name = "Ruination",
		cost = 20, cooldown = 60, occupied_cast = 0.35, occupied_swing = 0.35},
	hold_ground = {id = "hold_ground", kind = "cast", target_kind = "self", name = "Hold Ground",
		cost = 25, cooldown = 24, occupied_cast = 0.35, occupied_swing = 0.35},
	charge = {id = "charge", kind = "cast", target_kind = "hostile", name = "Charge",
		cost = 0, cooldown = 10, occupied_cast = 0.75},
	fiery_spark = {id = "fiery_spark", kind = "cast", target_kind = "hostile", name = "Fiery Spark",
		cost = 0, cooldown = 0, cast_interval = 1, occupied_cast = 1},
	ice_nova = {id = "ice_nova", kind = "cast", target_kind = "self", offensive = true,
		name = "Ice Nova", cost = 0, cooldown = 12, occupied_cast = 1},
	blink = {id = "blink", kind = "cast", target_kind = "self", repeat_policy = "once",
		name = "Blink", cost = 0, cooldown = 15, occupied_cast = 0},
	smite = {id = "smite", kind = "cast", target_kind = "hostile", name = "Smite",
		cost = 0, cooldown = 0, cast_interval = 1, occupied_cast = 1},
	heal = {id = "heal", kind = "cast", target_kind = "friendly", name = "Heal",
		cost = 0, cooldown = 0, occupied_cast = 1.5},
	shield = {id = "shield", kind = "cast", target_kind = "friendly", name = "Shield",
		cost = 0, cooldown = 0, occupied_cast = 1},
	arrowfall = {id = "arrowfall", kind = "cast", target_kind = "hostile", name = "Arrowfall",
		cost = 0, cooldown = 0, occupied_cast = 2.5},
	sidestep = {id = "sidestep", kind = "cast", target_kind = "self", name = "Sidestep",
		cost = 0, cooldown = 0, occupied_cast = 0.25},
}
-- Hotbar slots (a switch is a change of the wield index).
local SLOT = {strike = 1, ruination = 2, hold_ground = 3, charge = 4, fiery_spark = 1,
	ice_nova = 2, blink = 3, smite = 1, heal = 2, shield = 3, arrowfall = 4, sidestep = 5}
local basic = defs.strike
local weapon = 1.8 -- seconds, the melee weapon's interval
local w -- the clocks of the one test player
local log
local function fresh_world(interval, rage)
	weapon = interval or 1.8
	w = {swing_due = 0, cast_clock = 0, cooldown = {}, next_cast = {}, rage = rage or 100}
	log = {casts = {}, swings = {}, flashes = {}}
end
fresh_world()
local function refusal_of(def)
	if (w.cooldown[def.id] or 0) > clock then return def.name .. " is not ready.", "cooldown" end
	if (w.next_cast[def.id] or 0) > clock then
		return def.name .. " cast interval is not ready.", "interval"
	end
	if w.cast_clock > clock then return "You are still busy.", "busy" end
	if (def.cost or 0) > w.rage then return "Not enough rage.", "cost" end
	return nil
end
local api = {
	selected = function(player) return defs[player.wielded] end,
	swing = function(_, def)
		if clock < w.swing_due then return false end
		w.swing_due = clock + weapon * 1e6
		w.cast_clock = math.max(w.cast_clock, w.swing_due) -- K9
		log.swings[#log.swings + 1] = {id = def.id, at = clock}
		return true
	end,
	cast_refusal = function(_, def) return refusal_of(def) end,
	cast_wait = function(_, def)
		local until_us = math.max(w.cast_clock, w.next_cast[def.id] or 0)
		return math.max(0, (until_us - clock) / 1e6)
	end,
	swing_refusal = function() return nil end,
	delay_strike = function(_, def)
		local seconds = def and type(def.occupied_swing) == "number" and def.occupied_swing or weapon
		w.swing_due = math.max(w.swing_due, clock + seconds * 1e6)
	end,
	within_hand_reach = function() return true end,
}
grug_abilities = {
	registered = defs,
	is_unlocked = function() return true end,
	current_form = function(_, def) return def == defs.strike and basic or def end,
	get_range = function() return 3 end,
	valid_target = function(_, ref, kind)
		return (kind == "hostile" and ref == mob) or (kind == "friendly" and ref == ally)
	end,
	evading_target = function() return false end,
	support_refused = function(_, ref) return ref == forbidden end,
	flash = function(_, message) log.flashes[#log.flashes + 1] = message end,
	swing_stats = function() return 10, weapon end,
	-- A friendly skill's aimed ally (kits.lua aimed_target), else nil.
	aimed_target = function(_, def)
		local ray = grug_core.combat_ray()
		return def.target_kind == "friendly" and aim == "ally" and ally or nil, ray
	end,
	try_cast = function(_, def, _, notify)
		local message = refusal_of(def)
		if message then notify(message); return end
		-- resolve_friendly_target: a forbidden aimed ally refuses at no cost.
		if def.target_kind == "friendly" and aim == "forbidden" then
			notify("refused: forbidden ally"); return
		end
		-- A heal goes to the ally in the crosshair now, else to the caster
		-- (kits.lua resolve_friendly_target).
		log.casts[#log.casts + 1] = {id = def.id, at = clock, to = aim == "ally" and "ally" or "self"}
		w.rage = w.rage - (def.cost or 0)
		w.cooldown[def.id] = clock + (def.cooldown or 0) * 1e6
		if def.cast_interval then w.next_cast[def.id] = clock + def.cast_interval * 1e6 end
		w.cast_clock = math.max(w.cast_clock, clock + (def.occupied_cast or 0) * 1e6)
		return true
	end,
}
local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")(api)
for _, f in ipairs(loaded) do f() end

local controls = {dig = false, place = false}
local function stack(name)
	local st = {name = name or "", meta = {}}
	function st:get_name() return self.name end
	function st:get_meta()
		local m = self.meta
		return {get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) m[k] = v ~= "" and v or nil end}
	end
	return st
end
local player = {wielded = "strike", hp = 20}
function player.get_player_name() return "c" end
function player.get_player_control() return controls end
function player.get_inventory()
	return {get_stack = function(_, _, i)
		for id, slot in pairs(SLOT) do
			if slot == i and id == player.wielded then return stack("grug_abilities:" .. id) end
		end
		return stack("")
	end, set_stack = function() end}
end
function player.get_wield_list() return "main" end
function player.get_wield_index() return SLOT[player.wielded] end
function player.get_wielded_item() return stack("grug_abilities:" .. player.wielded) end
function player.set_wielded_item() return true end
function player.get_hp() return player.hp end
function player.get_pos() return vector.new(0, 0, 0) end
function player.get_look_dir() return vector.new(0, 0, 1) end

-- One input pass after one engine step.
local function pass(n)
	for _ = 1, n or 1 do
		clock = clock + STEP
		input.step(player)
	end
end
local function wield(id) player.wielded = id end
local function cast_at(id, since)
	for _, c in ipairs(log.casts) do
		if c.id == id and c.at >= (since or 0) then return c.at end
	end
end
local function swings_between(from, to)
	local n = 0
	for _, s in ipairs(log.swings) do
		if s.at >= from and (not to or s.at < to) then n = n + 1 end
	end
	return n
end
-- Releases everything and lets the clocks run out.
local function settle()
	controls.dig = false
	wield("strike")
	pass(4)
	clock = clock + 120 * 1e6
	pass(2)
end
local function ms(us) return us and ("%d ms"):format(math.floor(us / 1000 + 0.5)) or "never" end

------------------------------------------------------------------------------
-- R: Ruination pressed while a swing occupies the clock.
------------------------------------------------------------------------------
-- A held Strike on the mob for `strike_s`, released one pass, Ruination
-- selected and pressed (held `hold_s`, then released for `after_s`).
-- Returns the press time, the cast time (or nil), the swings between them
-- and when the clock allowed the cast.
local function strike_then(skill, strike_s, hold_s, after_s)
	settle(); fresh_world(1.8, 100); aim = "mob"; basic = defs.strike
	wield("strike"); controls.dig = true
	pass(math.floor(strike_s * 1e6 / STEP))
	controls.dig = false; pass(1)
	wield(skill); pass(1)
	local free = w.cast_clock
	controls.dig = true
	local pressed = clock + STEP
	pass(math.floor(hold_s * 1e6 / STEP))
	controls.dig = false; pass(math.floor((after_s or 0.18) * 1e6 / STEP))
	local at = cast_at(skill, pressed)
	return pressed, at, swings_between(pressed, at), free
end
do
	local pressed, at, swings, free = strike_then("ruination", 1.0, 4)
	case("R1", ("Ruination held at a mob mid-swing: cast %s after the press, %d swing(s) before it, %s")
		:format(at and ms(at - pressed) or "never", swings, table.concat(log.flashes, "|")))
	check(at ~= nil, "R1 Ruination pressed mid-swing is cast")
	check(at and at >= free and at - free < STEP + 1, "R1 ...at the first pass the clock allows")
	eq(swings, 0, "R1 ...and no swing of the press before it")
	eq(#log.flashes, 0, "R1 ...without a busy notice (it waits)")
	check(swings_between(at or math.huge) >= 1, "R1 held on, the press swings Strike after the cast")
	check(log.swings[#log.swings] and at and log.swings[#log.swings].at - at >= 0.35e6,
		"R1 ...the first swing after it waits the cast's occupied 0.35 s")

	pressed, at, swings, free = strike_then("hold_ground", 1.0, 4)
	case("R2", ("Hold Ground held at a mob mid-swing: cast %s after the press, %d swing(s) before it")
		:format(at and ms(at - pressed) or "never", swings))
	check(at ~= nil and at - free < STEP + 1, "R2 Hold Ground pressed mid-swing is cast when the clock allows")
	eq(swings, 0, "R2 ...no swing before it")

	-- The press carried across a hotbar switch (Strike held, the number key
	-- selects Ruination): the key-down decision after the 0.2 s settle.
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("strike"); controls.dig = true
	pass(12)
	local switched = clock
	wield("ruination"); pass(math.floor(4 * 1e6 / STEP))
	controls.dig = false; pass(2)
	at = cast_at("ruination", switched)
	case("R3", ("Strike held, switched to Ruination: cast %s after the switch, %d swing(s) before it, %d notice(s)")
		:format(at and ms(at - switched) or "never", swings_between(switched, at), #log.flashes))
	check(at ~= nil, "R3 a press carried onto Ruination casts it")
	eq(swings_between(switched, at), 0, "R3 ...no swing before it")
	eq(#log.flashes, 0, "R3 ...quietly (a carried press reports nothing)")

	-- Released before the clock allows: the waiting cast still fires.
	pressed, at, swings, free = strike_then("ruination", 1.0, 0.27, 2)
	case("R4", ("Ruination clicked once mid-swing (0.27 s): cast %s after the press")
		:format(at and ms(at - pressed) or "never"))
	check(at ~= nil and at - free < STEP + 1, "R4 a single click mid-swing casts once the clock allows")
end

------------------------------------------------------------------------------
-- C: a series of short clicks on Ruination at a mob.
------------------------------------------------------------------------------
-- After a held Strike, Ruination is selected and clicked: `held` passes down,
-- `gap` passes up, until it casts or 12 clicks have passed. Returns the
-- click that cast (or nil), the swings before the cast and the delay
-- between the clock allowing a cast (or the first click, if later) and the
-- cast. Every click while the clock is busy replaces the waiting cast, so
-- the click that casts is the one during which the clock runs out.
local function click_series(interval, held, gap, phase)
	settle(); fresh_world(interval, 100); aim = "mob"; basic = defs.strike
	wield("strike"); controls.dig = true
	pass(10 + phase)
	controls.dig = false; pass(1)
	wield("ruination"); pass(1)
	local start = clock
	local free = math.max(w.cast_clock, start + STEP)
	for click = 1, 12 do
		controls.dig = true; pass(held)
		controls.dig = false; pass(gap)
		local at = cast_at("ruination", start)
		if at then return click, swings_between(start, at), at - free end
	end
	return nil, swings_between(start), nil
end
do
	local runs, first, never, late, swung, worst = 0, 0, 0, 0, 0, 0
	local clicks, swings_total = 0, 0
	for tenth = 10, 30, 2 do
		for _, pattern in ipairs({{1, 2}, {2, 2}, {2, 3}, {3, 2}, {3, 3}, {2, 5}, {4, 4}}) do
			for phase = 0, 4 do
				runs = runs + 1
				local click, swings, delay = click_series(tenth / 10, pattern[1], pattern[2], phase)
				if not click then never = never + 1 else clicks = clicks + click end
				swings_total = swings_total + swings
				if click == 1 then first = first + 1 end
				if swings > 0 then swung = swung + 1 end
				if delay and delay >= STEP + 1 then late = late + 1 end
				if delay and delay > worst then worst = delay end
			end
		end
	end
	case("C1", ("%d click series (weapon 1.0-3.0 s, 7 click patterns, 5 phases): cast in the first click %d, "
		.. "never in 12 clicks %d, mean click that casts %.1f, swings before the cast in %d (%.1f per series), "
		.. "cast later than one pass after the clock allows %d")
		:format(runs, first, never, clicks / math.max(1, runs - never), swung, swings_total / runs, late))
	eq(never, 0, "C1 every click series casts Ruination")
	eq(swung, 0, "C1 ...with no swing before it")
	eq(late, 0, "C1 ...at the first pass the clock allows (worst " .. ms(worst) .. ")")
end

------------------------------------------------------------------------------
-- M: the other classes.
------------------------------------------------------------------------------
do
	-- Mage: Fiery Spark held at the mob (its 1 s occupied), then Ice Nova
	-- (an offensive self skill) clicked once and Blink clicked once.
	for _, skill in ipairs({"ice_nova", "blink"}) do
		settle(); fresh_world(1.8, 100); aim = "mob"; basic = defs.fiery_spark
		wield("fiery_spark"); controls.dig = true
		pass(15)
		controls.dig = false; wield(skill); pass(1)
		local free, pressed = w.cast_clock, clock + STEP
		controls.dig = true; pass(2); controls.dig = false; pass(14)
		local at = cast_at(skill, pressed)
		local sparks = 0
		for _, c in ipairs(log.casts) do
			if c.id == "fiery_spark" and c.at >= pressed and (not at or c.at < at) then sparks = sparks + 1 end
		end
		case(skill == "ice_nova" and "M1" or "M2", ("%s clicked after a held Fiery Spark: cast %s after the press, "
			.. "%d Fiery Spark(s) before it"):format(defs[skill].name, at and ms(at - pressed) or "never", sparks))
		check(at ~= nil and at - free < STEP + 1, "M " .. skill .. " clicked while busy casts when the clock allows")
		eq(sparks, 0, "M " .. skill .. " ...no fallback Fiery Spark before it")
	end
	-- Priest: Smite, then a click of Heal at an ally (it waits for Smite's 1 s).
	settle(); fresh_world(1.8, 100); aim = "mob"; basic = defs.smite
	wield("smite"); controls.dig = true; pass(3)
	controls.dig = false; wield("heal"); aim = "ally"; pass(1)
	local free, pressed = w.cast_clock, clock + STEP
	controls.dig = true; pass(2); controls.dig = false; pass(12)
	local at = cast_at("heal", pressed)
	case("M3", ("Heal clicked at an ally after a Smite: cast %s after the press")
		:format(at and ms(at - pressed) or "never"))
	check(at ~= nil and at - free < STEP + 1, "M3 a Heal clicked while busy casts when the clock allows")
	aim = "mob"

	-- A waiting heal keeps the recipient its press aimed at (classes.md
	-- §2b): the aimed ally, never the caster instead; the caster, never an
	-- ally walking into the crosshair. `aims`: the crosshair per pass after
	-- the click (the last one stays).
	local function heal_after_smite(at_press, aims)
		settle(); fresh_world(1.8, 100); aim = "mob"; basic = defs.smite
		wield("smite"); controls.dig = true; pass(3)
		controls.dig = false; wield("heal"); aim = at_press; pass(1)
		local start = clock
		controls.dig = true; pass(1); controls.dig = false
		for i = 1, 30 do aim = aims[math.min(i, #aims)]; pass(1) end
		for _, c in ipairs(log.casts) do
			if c.id == "heal" and c.at > start then return c.to, c.at - start, #log.flashes end
		end
		return "none", nil, #log.flashes
	end
	local mob_then_ally = {}
	for i = 1, 14 do mob_then_ally[i] = "mob" end
	mob_then_ally[15] = "ally"
	local to, after = heal_after_smite("ally", mob_then_ally)
	case("M4", ("Heal pressed at an ally, crosshair off it until 1.4 s: %s after %s"):format(to, ms(after)))
	eq(to, "ally", "M4 a waiting heal never goes to the caster instead of the aimed ally")
	check(after and after >= 1.3e6, "M4 ...it waits until the ally is aimed at again")
	local flashes
	to, after, flashes = heal_after_smite("ally", {"mob"})
	case("M5", ("Heal pressed at an ally, crosshair gone for good: %s, %d notice(s)"):format(to, flashes))
	eq(to, "none", "M5 the aimed ally never comes back: no heal")
	eq(flashes, 0, "M5 ...and the wait ends silently")
	to = heal_after_smite("air", {"air", "ally"})
	case("M6", ("Heal pressed at air, an ally walks into the crosshair: %s"):format(to))
	eq(to, "none", "M6 a waiting self heal never goes to an ally walking in")
	to = heal_after_smite("air", {"air", "ally", "ally", "ally", "ally", "ally", "ally", "air"})
	eq(to, "self", "M6 ...and fires on the caster once the ally has left the crosshair")
	-- A heal pressed at an ally the PvP flag forbids is never a self-cast
	-- (Round 31 ruling 9), also when the crosshair leaves that ally while
	-- the heal waits; still on that ally, it is refused as at a free clock.
	to, after, flashes = heal_after_smite("forbidden", {"air"})
	case("M8", ("Heal pressed at a forbidden ally, crosshair to air: %s, %d notice(s)"):format(to, flashes))
	eq(to, "none", "M8 a waiting heal at a forbidden ally never heals the caster")
	eq(flashes, 0, "M8 ...and ends silently")
	to, after, flashes = heal_after_smite("forbidden", {"forbidden"})
	eq(to, "none", "M8 still aimed at the forbidden ally: no heal")
	eq(flashes, 1, "M8 ...the refusal once, when the clock allows")
	aim = "mob"

	-- The wait covers a cast's occupied time longer than the weapon
	-- interval: Shield right after Heal (1.5 s) with a wand (1.0 s),
	-- Sidestep right after Arrowfall (2.5 s) with a dagger (0.7 s).
	for _, pair in ipairs({{"heal", "shield", 1.0, "ally", "ally"},
			{"arrowfall", "sidestep", 0.7, "mob", "air"}}) do
		settle(); fresh_world(pair[3], 100); aim = pair[4]; basic = defs.strike
		wield(pair[1]); pass(1)
		controls.dig = true; pass(1)
		controls.dig = false; wield(pair[2]); aim = pair[5]; pass(1)
		local free, pressed = w.cast_clock, clock + STEP
		controls.dig = true; pass(1); controls.dig = false; pass(35)
		at = cast_at(pair[2], pressed)
		case("M7", ("%s right after %s, weapon %.1f s: cast %s after the press")
			:format(defs[pair[2]].name, defs[pair[1]].name, pair[3], at and ms(at - pressed) or "never"))
		check(at ~= nil and at - free < STEP + 1, "M7 " .. pair[2] .. " waits out " .. pair[1] ..
			"'s occupied time, longer than the weapon interval")
	end
	aim = "mob"
end

------------------------------------------------------------------------------
-- Q: the queue's limits.
------------------------------------------------------------------------------
do
	-- Not enough rage: refused at once, loud, and the press falls back.
	settle(); fresh_world(1.8, 5); aim = "mob"; basic = defs.strike
	wield("ruination"); pass(1)
	controls.dig = true; pass(3); controls.dig = false; pass(20)
	case("Q1", ("Ruination without rage: casts %d, notices %s, swings %d")
		:format(#log.casts, table.concat(log.flashes, "|"), #log.swings))
	eq(#log.casts, 0, "Q1 no rage: no cast, ever")
	eq(log.flashes[1], "Not enough rage.", "Q1 ...the rage notice at once")
	eq(#log.swings, 1, "Q1 ...and the held fallback swings Strike (K8)")

	-- On cooldown: refused at once, loud.
	settle(); fresh_world(1.8, 100); aim = "mob"
	w.cooldown.ruination = clock + 30e6
	wield("ruination"); pass(1)
	controls.dig = true; pass(1); controls.dig = false; pass(20)
	eq(log.flashes[1], "Ruination is not ready.", "Q2 a cooldown is reported at once")
	eq(#log.casts, 0, "Q2 ...and nothing waits")

	-- A free clock casts on the press itself.
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("ruination"); pass(1)
	local pressed = clock + STEP
	controls.dig = true; pass(1)
	eq(cast_at("ruination", pressed), pressed, "Q3 a free clock casts on the press")
	controls.dig = false; pass(2)

	-- The wait lasts what the clocks still hold back (here 3 s, longer than
	-- the weapon interval), so the press casts then.
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("ruination"); pass(1)
	w.cast_clock = clock + 3e6
	local free = w.cast_clock
	pressed = clock + STEP
	controls.dig = true; pass(math.floor(4 * 1e6 / STEP))
	local at = cast_at("ruination", pressed)
	case("Q4", ("busy for 3 s: cast %s after the press, %d swing(s) before it")
		:format(at and ms(at - pressed) or "never", swings_between(pressed, at)))
	check(at ~= nil and at - free < STEP + 1, "Q4 a lock longer than the weapon interval: the cast waits it out")
	eq(swings_between(pressed, at), 0, "Q4 ...with no swing before it")
	controls.dig = false; pass(2)

	-- A lock pushed further while the press waits (by something else): the
	-- wait ends at what held it back at the press (at least one weapon
	-- interval) plus the grace, reported; the held press then falls back
	-- again.
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("ruination"); pass(1)
	w.cast_clock = clock + 1e6
	pressed = clock + STEP
	controls.dig = true; pass(1)
	w.cast_clock = clock + 10e6
	pass(math.floor(3 * 1e6 / STEP))
	case("Q4b", ("lock pushed to 10 s while waiting: casts %d, notices %s, first swing %s after the press")
		:format(#log.casts, table.concat(log.flashes, "|"),
			log.swings[1] and ms(log.swings[1].at - pressed) or "never"))
	eq(#log.casts, 0, "Q4b a lock pushed past the wait: no cast")
	eq(log.flashes[1], "You are still busy.", "Q4b ...the dropped wait reports busy")
	check(log.swings[1] and log.swings[1].at - pressed >= 1.8e6 and log.swings[1].at - pressed < 2.3e6,
		"Q4b ...and only then the held press falls back to Strike")
	controls.dig = false; pass(2)

	-- A hotbar switch drops the wait.
	local function waiting(then_do)
		settle(); fresh_world(1.8, 100); aim = "mob"
		wield("ruination"); pass(1)
		w.cast_clock = clock + 1e6
		controls.dig = true; pass(1); controls.dig = false; pass(1)
		then_do()
		pass(30)
		return #log.casts
	end
	eq(waiting(function() wield("strike") end), 0, "Q5 a slot switch drops the wait")
	eq(waiting(function() input.cancel(player) end), 0, "Q5 a row switch (input.cancel) drops the wait")
	eq(waiting(function() input.interaction(player) end), 0, "Q5 an RMB interaction drops the wait")
	eq(waiting(function() player.hp = 0; for _, f in ipairs(on_die) do f(player) end end), 0,
		"Q5 death drops the wait")
	player.hp = 20
	eq(waiting(function() stunned = true; for _, f in ipairs(on_stun) do f(player) end; pass(2); stunned = false end),
		0, "Q5 a stun drops the wait")
	-- Another refusal while waiting: the rage is spent elsewhere.
	eq(waiting(function() w.rage = 0 end), 0, "Q6 rage gone while waiting: no cast")
	eq(log.flashes[1], "Not enough rage.", "Q6 ...the refusal that ended the wait is reported")

	-- A new press replaces the waiting one: one cast.
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("ruination"); pass(1)
	w.cast_clock = clock + 1e6
	controls.dig = true; pass(1); controls.dig = false; pass(2)
	controls.dig = true; pass(1); controls.dig = false; pass(20)
	eq(#log.casts, 1, "Q7 two presses while busy: one cast")

	-- A hostile-target skill never waits (Charge refused busy).
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("charge"); pass(1)
	w.cast_clock = clock + 0.5e6
	controls.dig = true; pass(1); controls.dig = false; pass(15)
	eq(#log.casts, 0, "Q8 a hostile-target skill refused busy does not wait")
	eq(log.flashes[1], "You are still busy.", "Q8 ...and reports busy as before")
end

------------------------------------------------------------------------------
-- W: the waiting cast's accessor (Round 74 HUD: the overlay marks its slot).
------------------------------------------------------------------------------
do
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("ruination"); pass(1)
	eq(input.waiting(player), nil, "W nothing waits before the press")
	w.cast_clock = clock + 0.5e6
	controls.dig = true; pass(1); controls.dig = false; pass(1)
	eq(input.waiting(player), defs.ruination, "W a press refused busy: its def waits")
	pass(10)
	check(cast_at("ruination") ~= nil, "W ...it fires once the clock allows")
	eq(input.waiting(player), nil, "W ...and waits no longer")
	settle(); fresh_world(1.8, 100); aim = "mob"
	wield("hold_ground"); pass(1)
	w.cast_clock = clock + 1e6
	controls.dig = true; pass(1); controls.dig = false; pass(1)
	eq(input.waiting(player), defs.hold_ground, "W Hold Ground waits")
	wield("strike"); pass(1)
	eq(input.waiting(player), nil, "W a slot switch drops it: nothing waits")
end

if failures == 0 then
	print("R74 CAST PORTABLE PASS checks=" .. checks)
else
	error(("R74 CAST PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end

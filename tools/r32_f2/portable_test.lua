-- Round 32 Lane F2 portable test (LuaJIT): combat input and quest labels
-- (round32-plan.md §2.4 and §2.5).
--
--   luajit tools/r32_f2/portable_test.lua [repo]
--
-- Loads the REAL grug_abilities/input.lua on a fake engine and the REAL
-- grug_quests/labels.lua and grug_core/item_names.lua over the shipped data.
-- Checks:
--   G  the LMB hold state machine (the user's rule and rulings of
--      2026-10-03): every hold starts as gather, a key-down on a fightable
--      hostile starts it in combat with that foe; a held gather switches to
--      combat on any fightable hostile in the crosshair and in reach (a
--      neutral mob and a critter too, a PvP-harmable player; never a
--      protected player, an NPC, an ally or a hostile out of reach), and only
--      while an attacking skill is selected; Ward, Blink and Heal never fire
--      from a hold on their own (a mob or an ally walking in, a later air
--      step, an ally after its own press ended, a refused ally while held,
--      a hostile while held), a fresh press on an ally heals it and keeps
--      healing that ally only; combat hits whatever hostile is in the crosshair, never digs
--      beside a living foe, and the last hostile it aimed at is its foe; the
--      foe dead, despawned, no longer fightable (a PvP flag dropped, a mob
--      evading after a leash reset) or fled beyond 2 x reach returns it to
--      gather (briefly out of reach keeps the lock), and the same foe back in
--      reach locks it again; a hostile in sight then keeps combat without a
--      range rewrite; release and a slot change reset; a key-down on air is
--      gather; cost: no combat ray while the crosshair rests on a solid node,
--      one per step behind a plant, loot or an actor.
--   L  quest labels: every shipped kill objective names each target by its
--      zone display name (a leader's zone, else the area's zone, else the
--      quest's zone); how many quests and zones that changes (30 and 13 at
--      the start of Round 32); the item objectives that name such a source
--      show the item's own name.
-- Prints "R32 F2 PORTABLE PASS checks=<n>" or the failures.

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
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

------------------------------------------------------------------------------
-- vector (the subset input.lua uses).
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

------------------------------------------------------------------------------
-- G: input.lua on a fake engine.
------------------------------------------------------------------------------
local EYE = vector.new(0, 1.47, 0)
local clock = 0
local raycasts, combat_rays = 0, 0
local hits = {} -- what the next ray returns, nearest first
local swings, casts = {}, {}
local joins, leaves = {}, {}

-- Actors. A mob has health, a disposition (aggressive unless given), an
-- attack target and a distance from the player (z), and may despawn; a
-- player has hp and may be harmable (grug_pvp.can_harm) or not; an NPC is
-- never hostile.
local function new_mob(name, disposition)
	local m = {kind = "mob", health = 10, gone = false, name = name, z = 2,
		disposition = disposition or "aggressive"}
	function m:get_pos() return not self.gone and vector.new(0, 1, self.z) or nil end
	function m:is_player() return false end
	function m:get_luaentity()
		if self.gone then return nil end
		return {name = "test:mob", health = self.health, _cmi_is_mob = true,
			_grug_disposition = self.disposition, attack = self.attack,
			temp = {grug_evading = self.evading}}
	end
	return m
end
local function new_player(harmable)
	local p = {kind = "player", hp = 20, harmable = harmable}
	function p:get_pos() return vector.new(0, 1, 2) end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_luaentity() return nil end
	return p
end
local npc = {kind = "npc"}
function npc:get_pos() return vector.new(0, 1, 2) end
function npc:is_player() return false end
function npc:get_luaentity() return {name = "test:npc", _cmi_is_mob = true, health = 10} end
local ally = {kind = "ally"}
function ally:get_pos() return vector.new(0, 1, 2) end
function ally:is_player() return true end
function ally:get_hp() return 20 end
function ally:get_luaentity() return nil end
local ally2 = {kind = "ally"}
for k, v in pairs(ally) do if type(v) == "function" then ally2[k] = v end end
local refused = {kind = "refused"}
for k, v in pairs(ally) do if type(v) == "function" then refused[k] = v end end
local drop = {kind = "drop"}
function drop:get_pos() return vector.new(0, 1, 1) end
function drop:is_player() return false end
function drop:get_luaentity() return {name = "__builtin:item"} end

local function alive(ref)
	if not ref:get_pos() then return false end
	if ref:is_player() then return ref:get_hp() > 0 end
	local ent = ref:get_luaentity()
	return ent ~= nil and (ent.health or 0) > 0
end
local function hostile(ref)
	if ref.kind == "mob" then return alive(ref) end
	if ref.kind == "player" then return alive(ref) and ref.harmable end
	return false
end

core = {
	registered_nodes = {
		["test:dirt"] = {walkable = true, groups = {crumbly = 3}},
		["test:grass"] = {walkable = false, groups = {snappy = 3}},
	},
	registered_entities = {},
	get_us_time = function() return clock end,
	check_player_privs = function() return true end,
	get_node_or_nil = function(pos)
		return {name = pos.z == 1 and pos.y == 1 and "test:grass" or "test:dirt"}
	end,
	is_protected = function() return false end,
	-- Bare hands dig crumbly and snappy nodes.
	get_dig_params = function(groups) return {diggable = (groups.crumbly or groups.snappy) ~= nil} end,
	get_item_group = function(name, group)
		return group == "grug_ability" and name:sub(1, 15) == "grug_abilities:" and 1 or 0
	end,
	raycast = function()
		raycasts = raycasts + 1
		local i = 0
		return function()
			i = i + 1
			return hits[i]
		end
	end,
	register_on_mods_loaded = function() end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function(f) leaves[#leaves + 1] = f end,
	register_on_joinplayer = function(f) joins[#joins + 1] = f end,
}

local function new_stack(name, meta)
	local st = {name = name or "", meta = {}}
	for k, v in pairs(meta or {}) do st.meta[k] = v end
	function st:get_name() return self.name end
	function st:get_tool_capabilities() return {} end
	function st:get_meta()
		local m = self.meta
		return {
			get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) if v == "" then m[k] = nil else m[k] = v end end,
		}
	end
	return st
end
local function copy_stack(st) return new_stack(st.name, st.meta) end
function ItemStack(name) return new_stack(type(name) == "string" and name or "") end

local main = {}
for i = 1, 8 do main[i] = new_stack("") end
local writes = 0
local wield_index = 1
local inventory = {
	get_stack = function(_, _, i) return copy_stack(main[i]) end,
	set_stack = function(_, _, i, st) main[i] = copy_stack(st); writes = writes + 1 end,
	get_list = function()
		local out = {}
		for i, st in ipairs(main) do out[i] = copy_stack(st) end
		return out
	end,
}

grug_mobs = {disposition = function(ent) return ent._grug_disposition end,
	evade_notice = function() end}
grug_core = {
	combat_eye_pos = function() return vector.copy(EYE) end,
	combat_actor = function(ref) return ref end,
	-- The aiming ray (grug_core.aim_raycast, tested in tools/r35_t): the
	-- engine ray here.
	aim_raycast = function(o, d, liquids) return core.raycast(o, d, true, liquids) end,
	-- Every object here is seen by everyone (grug_core.unseen_by, Round 36 E).
	unseen_by = function() return false end,
	is_stunned = function() return false end,
	player_has_live_mount = function() return false end,
	register_on_stun = function() end,
	-- The combat-ray rules over the same hit list: non-walkable nodes and
	-- dropped items are passed through, a walkable node ends the ray, the
	-- first actor is classified (a protected player and an NPC are blockers,
	-- out_of_range beyond `range`).
	combat_ray = function(_, range)
		combat_rays = combat_rays + 1
		for _, hit in ipairs(hits) do
			local d = vector.distance(EYE, hit.intersection_point)
			if hit.type == "node" then
				if core.registered_nodes[core.get_node_or_nil(hit.under).name].walkable then
					return {status = "aim_miss", reason = "node"}
				end
			elseif hit.ref.kind ~= "drop" then
				local r = {target = hit.ref, distance = d, pointed = hit, status = "aim_miss", reason = "object"}
				if d > range then
					r.reason = "out_of_range"
				elseif hostile(hit.ref) then
					r.status, r.reason = "target", "hostile"
				end
				return r
			end
		end
		return {status = "aim_miss", reason = "empty"}
	end,
}

local defs = {
	strike = {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike"},
	fireball = {id = "fireball", kind = "cast", target_kind = "hostile", name = "Fireball"},
	loose = {id = "loose", kind = "cast", target_kind = "hostile", name = "Loose"},
	blink = {id = "blink", kind = "cast", target_kind = "self", name = "Blink", repeat_policy = "once"},
	ward = {id = "ward", kind = "cast", target_kind = "self", name = "Ward"},
	heal = {id = "heal", kind = "cast", target_kind = "friendly", name = "Heal"},
}
grug_abilities = {
	registered = defs,
	is_unlocked = function() return true end,
	get_range = function(_, def) return def.id == "fireball" and 20 or 3 end,
	-- The real predicate refuses a mob evading home (Round 36 §2.14.1); the
	-- combat ray above still reports it as a hostile target, as the real one
	-- does.
	valid_target = function(_, ref, kind)
		if kind == "friendly" then return ref.kind == "ally" end
		return kind == "hostile" and hostile(ref) and not ref.evading
	end,
	evading_target = function(_, ref) return ref.kind == "mob" and alive(ref) and ref.evading == true end,
	-- An ally the PvP flag forbids supporting (Round 31 ruling 9).
	support_refused = function(_, ref) return ref.kind == "refused" end,
	flash = function() end,
	cancel_bow_draw = function() end,
	start_bow_draw = function() return true end,
	try_cast = function(_, def)
		casts[#casts + 1] = def.id
		return true
	end,
}

local function wielded_def()
	local name = main[wield_index].name
	return name:sub(1, 15) == "grug_abilities:" and defs[name:sub(16)] or nil
end
local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
	selected = function() return wielded_def() end,
	swing = function(_, def) swings[#swings + 1] = def.id end,
	cast_refusal = function() return nil end,
	swing_refusal = function() return nil end,
	delay_strike = function() end,
	within_hand_reach = function() return true end,
})

local controls = {dig = false, place = false}
local player = {
	get_player_name = function() return "p" end,
	get_player_control = function() return controls end,
	get_inventory = function() return inventory end,
	get_wield_list = function() return "main" end,
	get_wield_index = function() return wield_index end,
	get_wielded_item = function() return copy_stack(main[wield_index]) end,
	set_wielded_item = function(_, st)
		main[wield_index] = copy_stack(st)
		writes = writes + 1
		return true
	end,
	get_hp = function() return 20 end,
	get_pos = function() return vector.new(0, 0, 0) end,
	get_look_dir = function() return vector.new(0, 0, 1) end,
}

-- Hits: a node 1.5 m ahead (hand-diggable dirt), grass 0.6 m ahead, an actor
-- at 1 m (in front of the node) or 10 m.
local NODE = {type = "node", under = vector.new(0, 1, 2), above = vector.new(0, 1, 1),
	intersection_point = vector.new(0, 1.47, 1.5)}
local GRASS = {type = "node", under = vector.new(0, 1, 1), above = vector.new(0, 1, 0),
	intersection_point = vector.new(0, 1.47, 0.6)}
local function at(ref, z) return {type = "object", ref = ref, intersection_point = vector.new(0, 1.47, z or 1)} end
local function aim(...) hits = {...} end
local function step()
	clock = clock + 50000
	input.step(player)
end
local function press() controls.dig = true; step() end
local function release() controls.dig = false; step(); step(); step(); step() end
local function hold(n) for _ = 1, n or 1 do step() end end
local function select(id)
	main[wield_index] = new_stack("grug_abilities:" .. id)
	controls.dig, controls.place = false, false
	clock = clock + 1000000
	step()
	swings, casts, writes = {}, {}, 0
end
local function range0() return main[wield_index].meta.range == "0" end
local function can_dig() return input.can_dig(player, NODE.under, core.get_node_or_nil(NODE.under)) end
local function swung_since(n) return #swings > n end

do -- G1 a gather hold switches to combat on a hostile in the crosshair and reach.
	select("strike")
	aim(NODE)
	press()
	check(not range0() and can_dig(), "G1 key-down on a node: gather, may dig")
	hold(3)
	check(#swings == 0, "G1 gather does not swing")
	local a = new_mob("a")
	aim(at(a), NODE) -- an aggressive mob steps in front of the node
	hold()
	check(range0() and writes == 1, "G1 switched to combat: zero range, one write")
	check(#swings == 1, "G1 the same step's hit goes to the hostile")
	check(not can_dig(), "G1 combat refuses the dig")
	-- G2 a miss while fighting: the crosshair on the ground beside the living
	-- foe digs nothing and swings at nothing.
	aim(NODE)
	local n = #swings
	hold(5)
	check(range0() and not can_dig() and #swings == n, "G2 a miss beside the living foe never digs")
	-- G3 switching enemies is free; the new one becomes the lock.
	local b = new_mob("b", "neutral") -- once in combat any valid hostile is hit
	aim(at(b), NODE)
	hold(2)
	check(#swings > n, "G3 hits go to the hostile now in the crosshair, a neutral one too")
	a.health = 0 -- the first one dies: b is the one to wait for
	aim(NODE)
	hold(3)
	check(range0() and not can_dig(), "G3 retarget locks again until that one is gone")
	b.health = 0
	hold()
	check(not range0() and can_dig(), "G3 the last foe dead: gather again, the node digs")
	eq(writes, 2, "G3 range written twice in all (switch and back)")
	-- G4 despawned or unloaded counts as gone.
	local c = new_mob("c")
	aim(at(c), NODE)
	hold()
	check(range0(), "G4 a new threat switches the gather hold again")
	c.gone = true
	aim(NODE)
	hold()
	check(not range0() and can_dig(), "G4 despawned / unloaded counts as gone")
	-- G5 fled: beyond FLEE_REACH (2) x reach (Strike: hand reach 4 m) = 8 m.
	local d = new_mob("d")
	aim(at(d), NODE)
	hold()
	d.z = 6 -- out of reach, inside the flee distance: the lock holds
	aim(NODE)
	hold(3)
	check(range0() and not can_dig(), "G5 a foe briefly out of reach keeps the lock")
	d.z = 7.9
	hold()
	check(range0(), "G5 still inside 8 m")
	d.z = 8.2
	hold()
	check(not range0() and can_dig(), "G5 a foe beyond 8 m has fled: gather again")
	-- G6 the foe dies while another hostile is in sight: combat, no rewrite.
	local e, f = new_mob("e"), new_mob("f")
	aim(at(e), NODE)
	hold()
	local w = writes
	aim(at(f), NODE)
	e.health = 0
	hold(2)
	check(range0() and writes == w, "G6 another hostile in sight at the death: combat, no range rewrite")
	f.health = 0
	aim(NODE)
	hold()
	check(not range0(), "G6 then its death returns to gather")
	-- G7 release resets everything.
	local g = new_mob("g")
	aim(at(g), NODE)
	hold()
	check(range0(), "G7 combat again")
	release()
	check(not range0(), "G7 release restores the range")
	aim(NODE)
	press()
	check(not range0() and can_dig(), "G7 a new press on the node is gather although g lives")
	release()
end

do -- G8 a slot change resets everything.
	select("strike")
	main[2] = new_stack("grug_abilities:fireball")
	aim(NODE)
	press()
	aim(at(new_mob("h")), NODE)
	hold()
	check(range0(), "G8 switched on slot 1")
	wield_index = 2
	hold()
	check(main[1].meta.range == nil and main[2].meta.range == nil, "G8 slot change restores the old stack")
	release()
	aim(NODE)
	press()
	check(not range0() and can_dig(), "G8 the next press on the node is gather")
	release()
	wield_index = 1
end

do -- G9 what never switches a gather hold, and what does.
	select("strike")
	aim(NODE)
	press()
	aim(at(new_player(false)), NODE)
	hold(3)
	check(not range0() and #swings == 0, "G9 a player PvP does not allow: no switch")
	aim(at(npc), NODE)
	hold(3)
	check(not range0() and #swings == 0, "G9 a friendly NPC: no switch")
	aim(at(new_mob("far"), 10), NODE) -- 10 m: beyond Strike's reach (hand reach 4 m)
	hold(3)
	check(not range0() and #swings == 0, "G9 a hostile out of reach: no switch")
	aim(at(ally), NODE)
	hold(3)
	check(not range0() and #swings == 0, "G9 an ally: no switch")
	aim(at(new_mob("neutral", "neutral")), NODE)
	hold()
	check(range0() and #swings == 1, "G9 a neutral mob: switch and hit (the user, 2026-10-03)")
	release()
	aim(NODE)
	press()
	aim(at(new_mob("rabbit", "critter")), NODE)
	hold()
	check(range0() and #swings == 2, "G9 a critter combat accepts: switch and hit")
	release()
	aim(NODE)
	press()
	aim(at(new_player(true)), NODE)
	hold()
	check(range0() and #swings == 3, "G9 a player PvP allows: switch and hit")
	release()
end

do -- G14 the same foe back in reach after it fled locks the hold again.
	select("strike")
	aim(NODE)
	press()
	local m = new_mob("runner")
	aim(at(m), NODE)
	hold()
	check(range0(), "G14 combat with the runner")
	m.z = 9 -- fled beyond 8 m
	aim(NODE)
	hold()
	check(not range0() and can_dig(), "G14 fled: gather")
	m.z = 2 -- back in reach and in the crosshair
	aim(at(m), NODE)
	hold()
	check(range0(), "G14 the same foe back: combat again")
	release()
end

do -- G10 key-down on a hostile: the same machine, starting in combat.
	select("strike")
	local m = new_mob("m", "neutral")
	aim(at(m), NODE)
	press()
	check(range0() and #swings == 1, "G10 key-down on a neutral mob: combat with it as the foe")
	aim(NODE)
	hold(3)
	check(range0() and not can_dig(), "G10 a miss beside the living foe never digs")
	m.health = 0
	hold()
	check(not range0() and can_dig(), "G10 the foe dead: the hold gathers, the node digs")
	local n = new_mob("n")
	aim(at(n), NODE)
	hold()
	check(range0(), "G10 a threat in the crosshair: combat again")
	n.health = 0
	aim(NODE)
	hold()
	check(not range0() and can_dig(), "G10 and gather after it")
	release()
	-- Key-down on air starts as gather and switches like any gather hold.
	local before = #swings
	aim()
	press()
	check(not range0() and #swings == before, "G10 key-down on air: gather")
	aim(at(new_mob("o")))
	hold()
	check(range0() and #swings == before + 1, "G10 a threat in sight: combat")
	release()
end

do -- G13 a foe no longer fightable is gone: a PvP flag dropped, a mob evading.
	select("strike")
	local enemy = new_player(true)
	aim(at(enemy), NODE)
	press()
	check(range0(), "G13 key-down on a PvP-harmable player: combat")
	enemy.harmable = false -- the PvP flag dropped: can_harm is false now
	hold()
	check(not range0() and #swings == 1, "G13 the foe turned unharmable: gather, no further hit")
	local w = writes
	hold(4)
	check(not range0() and writes == w and #swings == 1,
		"G13 it stays gather (no flip-flop on the protected player)")
	aim(NODE)
	hold()
	check(can_dig(), "G13 the node beside it digs")
	release()
	aim(NODE)
	press()
	local m = new_mob("evader")
	aim(at(m), NODE)
	hold()
	check(range0(), "G13 a threat switches the hold")
	m.evading = true -- leash reset: running home, taking no damage
	hold()
	check(not range0(), "G13 an evading foe is gone: gather")
	w = writes
	hold(4)
	check(not range0() and writes == w, "G13 an evading mob in the crosshair never re-locks the hold")
	m.evading = false
	hold()
	check(range0(), "G13 back from evading it is a threat again")
	release()
end

do -- G11 a self or support skill never fires because a mob walked in.
	select("ward")
	aim(NODE)
	press()
	aim(at(new_mob("p")), NODE)
	hold(4)
	check(not range0() and #casts == 0 and #swings == 0, "G11 Ward: the hold stays gather, nothing cast")
	aim() -- the crosshair to air while held: no empty-space self cast either
	hold(3)
	check(#casts == 0, "G11 no self cast on a later air step")
	release()
	select("blink")
	aim(NODE)
	press()
	aim(at(new_mob("q")), NODE)
	hold(2)
	aim()
	hold(2)
	check(#casts == 0 and not range0(), "G11 Blink: a miner is never teleported")
	release()
	-- An ally passing the crosshair of a held gather press is never healed,
	-- nor does Ward or Blink fire at it.
	for _, id in ipairs({"heal", "ward", "blink"}) do
		select(id)
		aim(NODE)
		press()
		aim(at(ally), NODE)
		hold(5)
		check(#casts == 0, "G11 " .. id .. ": an ally walking into a gather hold gets nothing")
		release()
	end
	-- A fresh press on an ally heals it, held on that ally only.
	select("heal")
	aim(at(ally), NODE)
	press()
	check(#casts == 1, "G11 a fresh press on an ally heals it")
	hold(3)
	check(#casts == 4, "G11 held on the same ally: today's repeats (" .. #casts .. ")")
	aim(at(ally2), NODE)
	hold(3)
	check(#casts == 4, "G11 no retarget to another ally mid-hold")
	release()
	-- The ally belongs to its own press: after a release, a new gather hold
	-- (a fresh one, and one begun while RMB was held, which is never fresh)
	-- does not heal it when it walks in.
	select("heal")
	aim(at(ally), NODE)
	press()
	release()
	casts = {}
	aim(NODE)
	press()
	aim(at(ally), NODE)
	hold(3)
	check(#casts == 0, "G11 a new press on a node: the earlier ally is not healed")
	release()
	aim(at(ally), NODE)
	press()
	release()
	casts = {}
	aim(NODE)
	controls.place = true
	step()
	controls.dig = true -- LMB pressed while RMB is held
	step()
	controls.place = false
	step()
	aim(at(ally), NODE)
	hold(3)
	check(#casts == 0, "G11 an LMB press begun under RMB: the earlier ally is not healed")
	release()
	-- An ally PvP forbids supporting: the refusal on the fresh press only.
	casts = {}
	aim(at(refused), NODE)
	press()
	hold(4)
	check(#casts == 1, "G11 a refused ally: one refused cast on the fresh press, none held (" ..
		#casts .. ")")
	release()
	-- A self skill pressed at a hostile fires once; held, the hold strikes.
	select("ward")
	aim(at(new_mob("r")), NODE)
	press()
	hold(4)
	check(#casts == 1 and #swings == 4 and range0(),
		"G11 Ward at a hostile: one cast, then Strike while held (casts " .. #casts .. ", swings " ..
		#swings .. ")")
	release()
	select("blink")
	aim() -- a key-down on air still casts the self skill once
	press()
	check(#casts == 1, "G11 a fresh press on air casts Blink once")
	release()
end

do -- G12 cost: no combat ray on a solid node, one per step otherwise.
	select("strike")
	aim(NODE)
	press()
	combat_rays, raycasts = 0, 0
	hold(10)
	eq(combat_rays, 0, "G12 gather on a solid node: no combat ray")
	eq(raycasts, 10, "G12 gather on a solid node: the hand ray only")
	aim(GRASS, NODE)
	combat_rays = 0
	hold(10)
	eq(combat_rays, 10, "G12 behind a plant: one combat ray per step")
	aim(at(drop), NODE)
	combat_rays = 0
	hold(10)
	eq(combat_rays, 10, "G12 behind loot: one combat ray per step")
	aim(GRASS, at(new_mob("behind_grass"), 1.2), NODE)
	hold()
	check(range0(), "G12 a threat behind a plant switches the hold")
	release()
	-- A Fireball (20 m) gather hold switches on a threat 10 m away.
	select("fireball")
	aim(NODE)
	press()
	aim(at(new_mob("far"), 10))
	hold()
	check(range0() and #casts == 1, "G12 a 20 m skill reaches 10 m: switch and cast")
	release()
end

------------------------------------------------------------------------------
-- L: quest labels over the shipped data.
------------------------------------------------------------------------------
local json = dofile(ROOT .. "/tools/r28_b4_quests/json.lua")
local function read_json(path)
	local handle = assert(io.open(path, "r"))
	local data = json.decode(handle:read("*a"))
	handle:close()
	return data
end
local function list_dir(dir)
	local names = {}
	local pipe = assert(io.popen('ls "' .. dir .. '"'))
	for name in pipe:lines() do names[#names + 1] = name end
	pipe:close()
	table.sort(names)
	return names
end

local MOBS = ROOT .. "/mods/ENTITIES/grug_mobs/data"
local QUESTS = ROOT .. "/mods/PLAYER/grug_quests/data/zones"
local subtypes = {}
for _, row in ipairs(read_json(MOBS .. "/subtypes.json")) do subtypes[row.role] = row end
local leader_zone = {}
for _, name in ipairs(list_dir(MOBS .. "/zones")) do
	local zone = name:match("^(.+)%.spawns%.json$")
	local data = zone and read_json(MOBS .. "/zones/" .. name)
	for _, leader in ipairs(data and data.recipe and data.recipe.leaders or {}) do
		leader_zone[leader.role] = zone
	end
end
local existing = read_json(ROOT .. "/docs/planning/round28/items/existing.json")

core = {registered_items = {}, registered_aliases = {}, registered_entities = {}}
for name, row in pairs(existing.items) do core.registered_items[name] = {description = row.description} end
for name, row in pairs(existing.entities) do core.registered_entities[name] = {description = row.description} end
for _, row in ipairs(read_json(MOBS .. "/items.json")) do core.registered_items[row.id] = {description = row.name} end
grug_core = {}
dofile(ROOT .. "/mods/CORE/grug_core/item_names.lua")
grug_mobs = {
	subtype = function(name)
		local row = subtypes[name:match("^grug_mobs:(.+)$") or name]
		return row and {display = row.display, display_by_zone = row.display_by_zone or {}} or nil
	end,
	spawn_regions = {
		leader = function(role) return leader_zone[role] and {zone = leader_zone[role]} or nil end,
	},
}
grug_quests = {}
dofile(ROOT .. "/mods/PLAYER/grug_quests/labels.lua")
local Q = grug_quests

-- The name the player sees, derived from the data alone.
local function seen_name(role, quest_zone, area)
	local row = subtypes[role]
	if not row then
		local def = core.registered_entities["grug_mobs:" .. role]
		return def and def.description
	end
	local zone = leader_zone[role] or (area and area:match("^([^/]+)/")) or quest_zone
	return (row.display_by_zone or {})[zone] or row.display
end

local changed_quests, changed_zones, item_rows = {}, {}, {}
local n_changed_quests, n_changed_zones, kills, garrison_kills = 0, 0, 0, 0
for _, name in ipairs(list_dir(QUESTS)) do
	local zone = name:match("^(.+)%.front%.quests%.json$") or name:match("^(.+)%.quests%.json$")
	for _, quest in ipairs(zone and read_json(QUESTS .. "/" .. name).quests or {}) do
		for index, objective in ipairs(quest.objectives) do
			local roles = objective.roles or {}
			local area = objective.area and (objective.area:find("/", 1, true) and objective.area or
				zone .. "/" .. objective.area)
			local mobs, expected, differs, known = {}, {}, false, true
			for i, role in ipairs(roles) do
				mobs[i] = "grug_mobs:" .. role
				expected[i] = seen_name(role, zone, area)
				-- The PvP garrisons' entities are registered after the dump
				-- (their names are not sub-type names; Round 32 leaves them).
				if not expected[i] then known, expected[i] = false, "" end
				if subtypes[role] and expected[i] ~= subtypes[role].display then differs = true end
			end
			if objective.type == "kill" and not known then
				garrison_kills = garrison_kills + 1
			elseif objective.type == "kill" then
				kills = kills + 1
				local row = {type = "kill", mobs = mobs, zones = Q.target_zones(mobs, area, zone)}
				eq(Q.objective_subject(row), table.concat(expected, " or "),
					("L %s objective %d names its targets as met"):format(quest.id, index))
			elseif objective.type == "item" and differs then
				item_rows[#item_rows + 1] = {id = quest.id, label = Q.objective_action({type = "item",
					item = objective.item}), expected = "Bring " .. grug_core.item_name(objective.item),
					mob = expected[1]}
			end
			if differs then
				if not changed_quests[quest.id] then
					changed_quests[quest.id], n_changed_quests = true, n_changed_quests + 1
				end
				local where = area and area:match("^([^/]+)/") or zone
				if not changed_zones[where] then
					changed_zones[where], n_changed_zones = true, n_changed_zones + 1
				end
			end
		end
	end
end
check(kills > 300, "L the shipped kill objectives were read (" .. kills .. ", " .. garrison_kills ..
	" garrison kills not checked)")
local kill_quests = 0
for id in pairs(changed_quests) do
	local item_only = false
	for _, row in ipairs(item_rows) do if row.id == id then item_only = true end end
	if not item_only then kill_quests = kill_quests + 1 end
end
print(("labels: %d quests with a kill objective now named by its zone, %d item objectives with such a " ..
	"source, %d zones"):format(kill_quests, #item_rows, n_changed_zones))
eq(kill_quests, 30, "L kill quests whose label changes (Round 32 start)")
eq(#item_rows, 4, "L item objectives naming such a source (Round 32 start)")
eq(n_changed_zones, 13, "L zones affected (Round 32 start)")
for _, row in ipairs(item_rows) do
	eq(row.label, row.expected, "L " .. row.id .. " shows the dropped item's own name")
	check(not row.label:find(row.mob, 1, true), "L " .. row.id .. " is not renamed after the mob")
end
-- Spot checks.
local function subject(roles, zone, area)
	local mobs = {}
	for i, role in ipairs(roles) do mobs[i] = "grug_mobs:" .. role end
	return Q.objective_subject({type = "kill", mobs = mobs, zones = Q.target_zones(mobs, area, zone)})
end
eq(subject({"small_boar"}, "kragmar_kapok_cradle", "kragmar_kapok_cradle/yam_beds"), "Small Jungle Boar",
	"L Kapok's small boar")
eq(subject({"small_boar"}, "elandor_dawnmere_fields"), "Small Boar", "L Dawnmere's small boar")
eq(subject({"last_watch_zombie"}, "elandor_highcourt", "front_stormscale_summit/wreck_shore"),
	"Overgrown Watchman", "L a front quest names the area's zone, not its file's")
eq(subject({"small_boar"}, "kragmar_kapok_cradle"), "Small Jungle Boar", "L without an area: the quest's zone")
eq(Q.objective_subject({type = "kill", mobs = {"grug_mobs:small_boar"}}), "Small Boar",
	"L a row without zones: the generic display name")

if failures == 0 then
	print("R32 F2 PORTABLE PASS checks=" .. checks)
else
	error(("R32 F2 PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end

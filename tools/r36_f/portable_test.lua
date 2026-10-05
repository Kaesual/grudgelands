-- Round 36 lane F portable test (LuaJIT): the user's Round 35 GUI findings
-- (round36-plan.md §2.14).
--
--   luajit tools/r36_f/portable_test.lua [repo]
--
--   P  one target predicate (§2.14.1). The REAL grug_core/combat_ray.lua,
--      grug_abilities/input.lua and crosshair.lua, with the real predicate
--      (valid_target, evading_target) cut out of grug_abilities/init.lua,
--      the real aimed_target out of kits.lua and the real evade_notice out of
--      grug_mobs/init.lua, on a fake engine. For each target state (a live
--      hostile, a mob evading home, a dead mob, an own-faction guard, a
--      non-combatant, an owned/tamed mob, out of skill range, an enemy player
--      with and without PvP, an ally, a flagged ally, an ally on a mount, the
--      player mounted) the crosshair is red/green exactly when a fresh press
--      acts (a swing that lands or a cast at that target); a press at an
--      evading mob shows "Evading" once, a held press and a second press
--      within 1.5 s do not repeat it; a self skill still fires at an evader.
--   E  free mobs run home only from outside their wander radius (§2.14.2):
--      the REAL grug_mobs/aggro.lua on stub entities. A free (damage-pursuit)
--      mob reset inside WANDER_RADIUS only heals and drops its target;
--      outside it runs home and is a normal mob again once back inside the
--      radius (not at 4 m). Camp members, guards, rares, bosses, patrollers,
--      royals and dragons keep their thresholds and the 4 m arrival. The 15 s
--      damage clock still starts at the first aggro.
--   B  the level-up banner (§2.14.4): the REAL grug_xp/init.lua with the real
--      grug_classes.talent_points_at cut out of talents.lua: "+1 Talent
--      Point" on even levels, "+2 Talent Points" over a jump, nothing on odd
--      levels.
--   C  the ability item's timing line follows the effective cooldown (the
--      real description_prefix and effective_cooldown).
-- Prints "R36 F PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(path, pattern, label)
	local block = read(path):match(pattern)
	assert(block, label .. " not found in " .. path)
	return block
end
local function run(block, name)
	assert(loadstring(block, "=" .. name))()
end

------------------------------------------------------------------------------
-- vector (the subset the loaded files use).
------------------------------------------------------------------------------
vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.normalize(v)
	local l = vector.length(v)
	return l > 0 and vector.multiply(v, 1 / l) or vector.new(0, 0, 0)
end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.equals(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
function vector.offset(p, x, y, z) return vector.new(p.x + x, p.y + y, p.z + z) end

------------------------------------------------------------------------------
-- P: one target predicate.
------------------------------------------------------------------------------
do
	local clock = 0
	local EYE = vector.new(0, 1.5, 0)
	local hits = {}
	local acted, flashes = {}, {}
	local mounted = false

	core = {
		registered_nodes = {["test:dirt"] = {walkable = true, groups = {crumbly = 3}}},
		registered_entities = {},
		get_us_time = function() return clock end,
		check_player_privs = function() return true end,
		get_node_or_nil = function() return {name = "test:dirt"} end,
		is_protected = function() return false end,
		get_dig_params = function(groups) return {diggable = groups.crumbly ~= nil} end,
		get_item_group = function() return 0 end,
		get_player_window_information = function() return nil end,
		register_on_mods_loaded = function() end,
		register_on_dieplayer = function() end,
		register_on_leaveplayer = function() end,
		register_on_joinplayer = function() end,
		is_player = function(o) return type(o) == "table" and o.player == true end,
	}
	local function new_stack(name)
		local st = {name = name or "", meta = {}}
		function st:get_name() return self.name end
		function st:get_tool_capabilities() return {} end
		function st:get_meta()
			local m = self.meta
			return {get_string = function(_, k) return m[k] or "" end,
				set_string = function(_, k, v) m[k] = v ~= "" and v or nil end}
		end
		return st
	end
	function ItemStack(name) return new_stack(type(name) == "string" and name or "") end

	local factions = {me = "accord", foe = "throng", pal = "accord", pal2 = "accord", rider = "accord"}
	local flagged = {}
	grug_factions = {
		get_faction = function(p) return factions[p:get_player_name()] end,
		same_faction = function(a, b)
			return a:is_player() and b:is_player() and
				factions[a:get_player_name()] == factions[b:get_player_name()]
		end,
		hostile = function(a, b)
			local fa, fb = factions[a:get_player_name()], factions[b:get_player_name()]
			return fa ~= nil and fb ~= nil and fa ~= fb
		end,
	}
	grug_pvp = {
		can_harm = function(a, b)
			return flagged[a:get_player_name()] == true and flagged[b:get_player_name()] == true
		end,
		can_support = function(a, b)
			return not flagged[b:get_player_name()] or flagged[a:get_player_name()] == true
		end,
	}
	grug_mobs = {is_noncombatant = function(ent) return ent._grug_noncombatant == true end}
	grug_core = {
		get_player_faction = function(name) return factions[name] end,
		pvp_can_harm = function(a, b) return grug_pvp.can_harm(a, b) end,
		is_stunned = function() return false end,
		player_has_live_mount = function() return mounted end,
		register_on_stun = function() end,
		hud_layout = {image_element = function(_, d) return d end},
		flash = function(_, text) flashes[#flashes + 1] = text end,
	}
	dofile(ROOT .. "/mods/CORE/grug_core/combat_ray.lua")
	-- The fake engine's ray: the scenario's hit list, nearest first.
	grug_core.aim_raycast = function()
		local i = 0
		return function() i = i + 1; return hits[i] end
	end
	grug_core.combat_eye_pos = function() return vector.copy(EYE) end

	local defs = {
		strike = {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike", range = 3},
		fireball = {id = "fireball", kind = "cast", target_kind = "hostile", name = "Fireball", range = 20},
		ward = {id = "ward", kind = "cast", target_kind = "self", name = "Ward", range = 0},
		heal = {id = "heal", kind = "cast", target_kind = "friendly", name = "Heal", range = 20},
	}
	grug_abilities = {
		registered = defs,
		is_unlocked = function() return true end,
		get_range = function(_, def) return def.range end,
		flash = function(_, text) flashes[#flashes + 1] = text end,
		cancel_bow_draw = function() end,
		start_bow_draw = function() return true end,
		support_refused = function(user, obj)
			return obj ~= nil and obj ~= user and obj:is_player() and obj:get_hp() > 0
				and grug_factions.same_faction(user, obj)
				and not grug_pvp.can_support(user, obj)
		end,
	}
	run(cut("mods/PLAYER/grug_abilities/init.lua",
		"\n(local function hostile_mob%(.-\nfunction grug_abilities%.evading_target%(.-\nend)\n",
		"the target predicate"), "valid_target")
	run(cut("mods/PLAYER/grug_abilities/kits.lua",
		"\n(local function valid_ally%(.-\nfunction grug_abilities%.aimed_target%(.-\nend)\n",
		"aimed_target"), "aimed_target")
	run(cut("mods/ENTITIES/grug_mobs/init.lua",
		"\n(local EVADE_NOTICE_US.-\nfunction grug_mobs%.evade_hit_notice%(.-\nend)\n",
		"evade_notice"), "evade_notice")

	-- The casts: a hostile cast lands on the aimed target (kits.lua
	-- current_enemy_target), a heal on the aimed ally or the caster, a
	-- refused ally refuses (resolve_friendly_target), a self skill always fires.
	grug_abilities.try_cast = function(user, def, _, notify)
		if def.target_kind == "self" then
			acted[#acted + 1] = "cast:" .. def.id
			return true
		end
		local target, ray = grug_abilities.aimed_target(user, def)
		if def.target_kind == "friendly" then
			if target then
				acted[#acted + 1] = "heal:" .. target:get_player_name()
				return true
			end
			if ray.reason == "friendly" and grug_abilities.support_refused(user, ray.target) then
				notify("refused")
				return false
			end
			acted[#acted + 1] = "heal:self"
			return true
		end
		if not target then
			notify("No hostile target in your crosshair.")
			return false
		end
		acted[#acted + 1] = "cast:" .. def.id
		return true
	end

	local wielded = "strike"
	local selected = function() return defs[wielded] end
	-- The swing: grug_abilities attempt_swing's own ray and predicate.
	local function swing(player, def)
		local ray = grug_core.combat_ray(player, grug_abilities.get_range(player, def))
		if ray.status == "target" and grug_abilities.valid_target(player, ray.target, def.target_kind) then
			acted[#acted + 1] = "swing:" .. def.id
		end
	end
	local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
		selected = selected, swing = swing,
		cast_refusal = function() return nil end,
		swing_refusal = function() return nil end,
		delay_strike = function() end,
		within_hand_reach = function() return true end,
	})
	grug_abilities.input = input
	local C = dofile(ROOT .. "/mods/PLAYER/grug_abilities/crosshair.lua")({selected = selected})

	local controls = {dig = false, place = false}
	local main = {ItemStack("grug_abilities:strike")}
	local function player_ref(name, fields)
		local p = {player = true, name = name, hp = 20}
		function p:get_player_name() return self.name end
		function p:is_player() return true end
		function p:get_hp() return self.hp end
		function p:get_pos() return self.pos or vector.new(0, 0, 0) end
		function p:get_luaentity() return nil end
		function p:get_attach() return self.attached end
		for k, v in pairs(fields or {}) do p[k] = v end
		return p
	end
	local me = player_ref("me")
	me.get_player_control = function() return controls end
	me.get_inventory = function()
		return {get_stack = function(_, _, i) return main[i] end,
			set_stack = function(_, _, i, st) main[i] = st end}
	end
	me.get_wield_list = function() return "main" end
	me.get_wield_index = function() return 1 end
	me.get_wielded_item = function() return main[1] end
	me.set_wielded_item = function(_, st) main[1] = st; return true end
	me.get_look_dir = function() return vector.new(0, 0, 1) end

	local function mob(fields)
		local ent = {name = "test:mob", _cmi_is_mob = true, health = 10, temp = {}}
		for k, v in pairs(fields or {}) do ent[k] = v end
		local o = {ent = ent}
		function o:get_pos() return self.pos end
		function o:is_player() return false end
		function o:get_luaentity() return self.ent end
		return o
	end
	-- Put `obj` at distance z in front of the eye (a solid node behind it).
	local function place(obj, z)
		obj.pos = vector.new(0, 1, z)
		hits = {
			{type = "object", ref = obj, intersection_point = vector.new(0, 1.5, z)},
			{type = "node", under = vector.new(0, 1, z + 3), above = vector.new(0, 1, z + 2),
				intersection_point = vector.new(0, 1.5, z + 2.5)},
		}
	end
	local function step() clock = clock + 50000; input.step(me) end
	local function release()
		controls.dig = false
		for _ = 1, 4 do step() end
	end
	-- One scenario: the crosshair state, then one fresh press; what it did.
	local function probe(skill)
		wielded = skill
		main[1] = ItemStack("grug_abilities:" .. skill)
		release()
		clock = clock + 400000 -- past the crosshair's unchanged-ray window
		local state = C.state(me)
		acted, flashes = {}, {}
		controls.dig = true
		step()
		local did = acted[1]
		release()
		return state, did
	end
	local function agree(skill, state_kind, label)
		local state, did = probe(skill)
		if state_kind then
			eq(state, state_kind, "P " .. label .. ": crosshair " .. state_kind)
			check(did ~= nil, "P " .. label .. ": a press acts (" .. tostring(did) .. ")")
		else
			eq(state, nil, "P " .. label .. ": crosshair neutral")
			eq(did, nil, "P " .. label .. ": a press does nothing")
		end
		return state, did
	end

	-- A live hostile in skill range: red, and a press acts.
	local rat = mob()
	place(rat, 10)
	local _, did = agree("fireball", "hostile", "a live hostile at 10 m, Fireball")
	eq(did, "cast:fireball", "P the press casts Fireball at it")
	place(rat, 2)
	_, did = agree("strike", "hostile", "a live hostile at 2 m, Strike")
	eq(did, "swing:strike", "P the press swings at it")

	-- The user's finding: a rat evading home after a leash reset.
	rat.ent.temp.grug_evading = {started = 0}
	place(rat, 10)
	agree("fireball", nil, "an evading rat, Fireball")
	eq(#flashes, 1, "P a press at the evader flashes once")
	eq(flashes[1], "Evading", "P the flash says Evading")
	place(rat, 2)
	agree("strike", nil, "an evading rat, Strike")
	eq(#flashes, 0, "P a second press within 1.5 s repeats nothing")
	clock = clock + 1500000
	acted, flashes = {}, {}
	controls.dig = true
	step()
	eq(flashes[1], "Evading", "P a press after 1.5 s says it again")
	for _ = 1, 40 do step() end -- held for two seconds
	eq(#flashes, 1, "P a held press never repeats it")
	eq(#acted, 0, "P a held press at the evader never acts")
	-- The native punch packets a held button keeps sending: the input seam
	-- (input.press) and the do_punch cancel (evade_hit_notice), for 3 s.
	for _ = 1, 12 do
		clock = clock + 250000
		input.press(me)
		grug_mobs.evade_hit_notice(me)
	end
	eq(#flashes, 1, "P a held press's native punches stay quiet")
	release()
	-- A cast or projectile already under way that reaches the evader says so.
	clock = clock + 1500000
	grug_core.in_ability_punch = true
	check(grug_mobs.evade_hit_notice(me), "P a projectile hitting the evader says Evading")
	grug_core.in_ability_punch = nil
	eq(flashes[#flashes], "Evading", "P ... in the flash line")
	check(not grug_mobs.evade_hit_notice({}), "P a non-player hitter says nothing")
	check(read("mods/ENTITIES/grug_mobs/init.lua"):find(
		"grug_core.flash(player, \"Evading\")", 1, true) and
		read("mods/ENTITIES/grug_mobs/init.lua"):match(
		"if self%.temp and self%.temp%.grug_evading then%s+grug_mobs%.evade_hit_notice%(hitter%)%s+return true"),
		"P the do_punch cancel goes through evade_hit_notice")
	_, did = probe("ward")
	eq(did, "cast:ward", "P a self skill still fires at an evader")
	eq(#flashes, 0, "P ... without the Evading notice")
	rat.ent.temp.grug_evading = nil
	place(rat, 10)
	agree("fireball", "hostile", "the rat home again")

	-- Dead, own faction, non-combatant: never a target, never acted on.
	place(mob({health = 0}), 10)
	agree("fireball", nil, "a dead mob")
	place(mob({_grug_faction = "accord"}), 10)
	agree("fireball", nil, "an own-faction guard")
	place(mob({_grug_faction = "throng"}), 10)
	agree("fireball", "hostile", "an enemy-faction guard")
	place(mob({_grug_noncombatant = true}), 10)
	agree("fireball", nil, "a non-combatant")
	-- No taming in the game; an owned mob is judged like any other.
	place(mob({tamed = true, owner = "foe"}), 10)
	agree("fireball", "hostile", "an owned, tamed mob")

	-- Out of the skill's range.
	place(mob(), 25)
	agree("fireball", nil, "a hostile beyond Fireball's 20 m")
	place(mob(), 3.5)
	agree("strike", nil, "a hostile at 3.5 m, beyond Strike's 3 m")

	-- Players: an enemy only with PvP on both, an ally, a flagged ally.
	local foe = player_ref("foe")
	place(foe, 10)
	agree("fireball", nil, "an enemy player without PvP")
	flagged.me, flagged.foe = true, true
	agree("fireball", "hostile", "an enemy player, both flagged")
	flagged.me, flagged.foe = nil, nil
	local pal = player_ref("pal")
	place(pal, 10)
	_, did = agree("heal", "friendly", "an ally, Heal")
	eq(did, "heal:pal", "P the press heals the ally")
	agree("fireball", nil, "an ally, Fireball")
	flagged.pal = true
	local state
	state, did = probe("heal")
	eq(state, nil, "P a flagged ally (me unflagged): crosshair neutral")
	eq(did, nil, "P ... and the press heals nobody")
	eq(flashes[1], "refused", "P ... but says why")
	flagged.pal = nil

	-- An ally on a mount: the ray hits the mount, its rider is the actor.
	local horse = {ent = {name = "grug_mounts:mount"}}
	function horse:get_pos() return self.pos end
	function horse:is_player() return false end
	function horse:get_luaentity() return self.ent end
	local rider = player_ref("pal2", {attached = horse})
	horse.ent._grug_rider = rider
	place(horse, 10)
	_, did = agree("heal", "friendly", "an ally on a mount, Heal")
	eq(did, "heal:pal2", "P the press heals the rider")

	-- The player mounted: no press acts, so no colour either.
	place(mob(), 10)
	mounted = true
	state, did = probe("fireball")
	eq(state, nil, "P mounted: crosshair neutral")
	eq(did, nil, "P mounted: a press does nothing")
	check(C.recent_aim(me, 1000000) and C.recent_aim(me, 1000000).ray.status == "target",
		"P mounted: the ray still feeds the Target Frame")
	mounted = false
end

------------------------------------------------------------------------------
-- E: free mobs run home only from outside their wander radius.
------------------------------------------------------------------------------
do
	local now = 1000
	local nudges = 0
	core = {is_player = function(o) return type(o) == "table" and o.is_player_ref == true end}
	grug_core = {
		mono_time = function() return now end,
		recheck_switch = function() end,
		prune_engagement = function() end,
		clear_threat = function() end,
	}
	grug_mobs = {
		walk_toward = function() nudges = nudges + 1 end,
		idle_health_tick = function() end,
		place_on_ground = function() end,
		roam_avoid_tick = function() end,
	}
	dofile(ROOT .. "/mods/ENTITIES/grug_mobs/aggro.lua")
	local R = grug_mobs.WANDER_RADIUS
	eq(R, 32, "E the wander radius is 32 nodes")

	local function mob(fields, x)
		local self = {type = "monster", state = "attack", health = 3, hp_max = 20,
			_grug_home = {x = 0, y = 10, z = 0}, temp = {}}
		for k, v in pairs(fields) do self[k] = v end
		local pos = {x = x, y = 10, z = 0}
		self.object = {get_pos = function() return pos end}
		self.move = function(nx) pos = {x = nx, y = 10, z = 0} end
		self.attack = {}
		self.stop_attack = function(s) s.attack = nil; s.state = "stand" end
		return self
	end
	local function tick(self)
		now = now + 1
		grug_mobs.leash_tick(self, 1)
	end
	local free = {_grug_damage_pursuit_candidate = true}

	-- Inside the wander radius: heal and drop the target, nothing else.
	for _, x in ipairs({0, 4.5, 20, R}) do
		local m = mob(free, x)
		grug_mobs.leash_reset(m)
		check(m.temp.grug_evading == nil, "E a free mob reset " .. x .. " m out does not run home")
		check(m.health == 20 and m.attack == nil, "E ... it is healed and drops its target")
	end
	-- Outside: it runs home, untouchable, until it is back inside the radius.
	do
		local m = mob(free, 60)
		grug_mobs.leash_reset(m)
		check(m.temp.grug_evading ~= nil, "E a free mob reset 60 m out runs home")
		check(m.health == 20 and m.attack == nil, "E ... healed, target dropped")
		m.move(R + 1)
		tick(m)
		check(m.temp.grug_evading ~= nil, "E ... still running 1 m outside the radius")
		m.move(R - 1)
		tick(m)
		check(m.temp.grug_evading == nil, "E ... a normal mob again once inside the radius")
	end

	-- Every other kind keeps its threshold and the 4 m arrival.
	local kinds = {
		{"camp member", {_grug_camp_pos = {x = 0, y = 10, z = 0}, _grug_leash_range = 25}, 25},
		{"guard", {type = "npc", _grug_leash_range = 30}, 30},
		{"named rare", {_grug_damage_pursuit_candidate = true, _grug_rare_id = "r"}, 40},
		{"boss", {_grug_damage_pursuit_candidate = true, _grug_boss_id = "king:orc"}, 40},
		{"royal", {_grug_no_leash = true, _grug_royal_summon = true}, 40},
	}
	for _, row in ipairs(kinds) do
		local label, fields, range = row[1], row[2], row[3]
		local inside = mob(fields, range - 1)
		grug_mobs.leash_reset(inside)
		check(inside.temp.grug_evading == nil, "E " .. label .. " inside its " .. range .. " m stays")
		local m = mob(fields, range + 5)
		grug_mobs.leash_reset(m)
		check(m.temp.grug_evading ~= nil, "E " .. label .. " beyond " .. range .. " m runs home")
		m.move(10)
		tick(m)
		check(m.temp.grug_evading ~= nil, "E " .. label .. " still running 10 m from home")
		m.move(3)
		tick(m)
		check(m.temp.grug_evading == nil, "E " .. label .. " arrives within 4 m")
	end
	local patroller = mob({_grug_camp_pos = {x = 0, y = 10, z = 0}, _grug_patrol_route = {}}, 500)
	grug_mobs.leash_reset(patroller)
	check(patroller.temp.grug_evading == nil, "E the patroller never runs home")
	local dragon = mob({_grug_no_leash = true, _grug_boss_id = "dragon:x"}, 500)
	grug_mobs.leash_reset(dragon)
	check(dragon.temp.grug_evading == nil, "E a dragon flies home instead")

	-- Not changed: the 15 s damage clock starts at the first aggro.
	do
		local target_pos = {x = 5, y = 10, z = 0}
		local target = {is_player_ref = true, get_pos = function() return target_pos end,
			get_hp = function() return 20 end}
		local m = mob(free, 0)
		m.health, m.attack = 20, target
		local first = now + 1
		tick(m)
		eq(m.temp.grug_damage_at, first, "E the damage clock starts at the first aggro")
		for _ = 1, 5 do tick(m) end
		eq(m.temp.grug_damage_at, first, "E fighting alone does not refresh it")
		for _ = 1, 12 do target_pos = {x = target_pos.x + 1, y = 10, z = 0}; tick(m) end
		check(m.attack == nil and m.temp.grug_evading == nil,
			"E 15 s without damage reset it; inside the radius it stays")
	end
end

------------------------------------------------------------------------------
-- B: the level-up banner names the talent points.
------------------------------------------------------------------------------
do
	local banners = {}
	core = {
		log = function() end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
		get_player_by_name = function() return nil end,
	}
	setmetatable(core, {__index = function() return function() end end})
	grug_sounds = {play = function() end}
	grug_core = {
		hud_layout = {COLOR = {xp = 0}},
		banner = function(_, text) banners[#banners + 1] = text end,
		feed_xp = function() end,
	}
	grug_classes = nil
	dofile(ROOT .. "/mods/PLAYER/grug_xp/init.lua")
	eq(grug_xp.level_up_text(1, 2), "Reached level 2!", "B without grug_classes: one line")
	local talents = "mods/PLAYER/grug_classes/talents.lua"
	grug_classes = {TALENT_LEVELS_PER_POINT = tonumber(read(talents):match(
		"grug_classes%.TALENT_LEVELS_PER_POINT = (%d+)"))}
	eq(grug_classes.TALENT_LEVELS_PER_POINT, 2, "B one point every two levels")
	run(cut(talents, "\n(function grug_classes%.talent_points_at%(.-\nend)\n",
		"talent_points_at"), "talent_points_at")
	check(read(talents):find("return grug_classes.talent_points_at(grug_xp.get_level(player))", 1, true),
		"B talent_points_total reads the same rule")
	eq(grug_xp.level_up_text(1, 2), "Reached level 2!\nYou gained +1 Talent Point", "B level 2")
	eq(grug_xp.level_up_text(2, 3), "Reached level 3!", "B level 3 (odd): no line")
	eq(grug_xp.level_up_text(59, 60), "Reached level 60!\nYou gained +1 Talent Point", "B level 60")
	eq(grug_xp.level_up_text(3, 6), "Reached level 6!\nYou gained +2 Talent Points", "B 3 to 6")
	eq(grug_xp.level_up_text(2, 4), "Reached level 4!\nYou gained +1 Talent Point", "B 2 to 4")
	eq(grug_xp.level_up_text(4, 5), "Reached level 5!", "B 4 to 5")
	eq(grug_xp.level_up_text(1, 60), "Reached level 60!\nYou gained +30 Talent Points", "B 1 to 60")
	-- Through the real set_xp.
	local store = {}
	local p = {get_meta = function()
		return {get_int = function(_, k) return store[k] or 0 end,
			set_int = function(_, k, v) store[k] = v end}
	end, get_player_name = function() return "p" end, get_pos = function() return nil end}
	grug_xp.set_xp(p, grug_xp.xp_for_level(5))
	eq(banners[#banners], "Reached level 5!\nYou gained +2 Talent Points", "B set_xp 1 to 5")
	grug_xp.set_xp(p, grug_xp.xp_for_level(6))
	eq(banners[#banners], "Reached level 6!\nYou gained +1 Talent Point", "B set_xp 5 to 6")
	grug_xp.set_xp(p, grug_xp.xp_for_level(7))
	eq(banners[#banners], "Reached level 7!", "B set_xp 6 to 7")
	grug_classes = nil
end

------------------------------------------------------------------------------
-- C: the timing line follows the effective cooldown.
------------------------------------------------------------------------------
do
	local bonus = 0
	grug_classes = {get_talent_bonus = function() return bonus end}
	grug_abilities = {mana_cost = function() return 10 end,
		effective_charge = function() return 2 end}
	local init = "mods/PLAYER/grug_abilities/init.lua"
	run(cut(init, "\n(function grug_abilities%.effective_cooldown%(.-\nend)\n",
		"effective_cooldown"), "effective_cooldown")
	run(cut(init, "\n(function grug_abilities%.description_prefix%(.-\nend)\n",
		"description_prefix"), "description_prefix")
	local taunt = {name = "Taunt", kind = "cast", cost = {rage = 10}, cooldown = 8,
		cooldown_talent = "taunt_cooldown_sub", _grug_owner_line = "Warrior",
		_grug_timing_line = "8 s cooldown"}
	local player = {}
	eq(grug_abilities.description_prefix(nil, taunt), "Taunt (Warrior)\n10 rage, 8 s cooldown\n",
		"C without a player: the static line")
	eq(grug_abilities.description_prefix(player, taunt), "Taunt (Warrior)\n10 rage, 8 s cooldown\n",
		"C no talent: the base cooldown")
	bonus = 2
	eq(grug_abilities.description_prefix(player, taunt), "Taunt (Warrior)\n10 rage, 6 s cooldown\n",
		"C Grudge 2 s: 6 s")
	bonus = 1.5
	eq(grug_abilities.description_prefix(player, taunt), "Taunt (Warrior)\n10 rage, 6.5 s cooldown\n",
		"C 1.5 s: 6.5 s")
	bonus = 9
	eq(grug_abilities.description_prefix(player, taunt), "Taunt (Warrior)\n10 rage, no cooldown\n",
		"C clamped at 0: no cooldown")
	local fireball = {name = "Fireball", kind = "cast", cost = {mana_percent = 5}, cooldown = 0,
		_grug_owner_line = "Mage", _grug_timing_line = "no cooldown"}
	eq(grug_abilities.description_prefix(player, fireball),
		"Fireball (Mage)\n5% base mana (10 mana), no cooldown\n", "C a skill without a cooldown talent")
	local text = read(init)
	check(text:find("grug_classes.register_on_talents_changed(function(player)", 1, true) and
		text:find("sync_descriptions(player)", 1, true), "C a talent change re-syncs the descriptions")
end

if failures == 0 then
	print("R36 F PORTABLE PASS checks=" .. checks)
else
	error(("R36 F PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end

-- Disposable engine probe (playtest-fix Lane H, combat exit). Never shipped:
-- tools/pt_fixes/lane_h/run.sh stages it through tools/luanti_headless.sh.
--
-- A headless server has no client, so each "player" is a real, invisible,
-- non-pointable probe entity whose ObjectRef answers the player accessors the
-- combat path reads (is_player, name, hp, meta, inventory, wield, HUD,
-- physics). Everything else is shipped code on the real engine: grug_core's
-- combat state, deal_ability_damage -> ObjectRef:punch -> mobs_redo on_punch
-- -> grug_mobs' accepted-hit seam, the mob death boundary, leash_reset,
-- stop_attack, on_deactivate, the 1 Hz leash tick and grug_food's hold gate.
--
-- The engine only runs player hp-change modifiers and on_dieplayer for real
-- players, so the probe calls grug_core's own registered modifier and death
-- callbacks for its probe players (exactly what the engine would call).

local P = "[combat_exit_probe] "
local BASE = vector.new(704, 290, 704)
local SPACING = 8
local failures, checks = 0, 0

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
end

core.register_entity("grug_probe_combat_exit:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	-- A retaliating mob must not remove the probe "player".
	on_punch = function() return true end,
})

-- A projectile stand-in carrying its shooter like every shipped mob arrow
-- (grug_mobs.stamp_arrow_damage sets `_grug_source`).
core.register_entity("grug_probe_combat_exit:bolt", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
	},
})

--
-- Probe players.
--
local fakes, by_name = {}, {}
local methods

local function install(ref)
	if methods then return end
	methods = getmetatable(ref)
	local function override(name, fn)
		local original = methods[name]
		methods[name] = function(self, ...)
			local fake = fakes[self]
			if fake then return fn(fake, ...) end
			return original(self, ...)
		end
	end
	override("is_player", function() return true end)
	override("get_player_name", function(f) return f.name end)
	override("get_hp", function(f) return f.hp end)
	override("get_player_control", function() return {} end)
	override("get_player_control_bits", function() return 0 end)
	override("get_look_dir", function() return vector.new(0, 0, 1) end)
	override("get_look_horizontal", function() return 0 end)
	override("get_look_vertical", function() return 0 end)
	override("get_meta", function(f) return f.holder:get_meta() end)
	override("get_inventory", function(f) return f.inv end)
	override("get_wield_list", function() return "main" end)
	override("get_wield_index", function() return 1 end)
	override("get_wielded_item", function(f) return f.inv:get_stack("main", 1) end)
	override("set_wielded_item", function(f, stack)
		return f.inv:set_stack("main", 1, stack)
	end)
	override("hud_add", function(f, def)
		f.hud_next = f.hud_next + 1
		f.huds[f.hud_next] = table.copy(def)
		return f.hud_next
	end)
	override("hud_change", function(f, id, stat, value)
		local hud = f.huds[id]
		if not hud then return false end
		hud[stat] = value
		return true
	end)
	override("hud_remove", function(f, id) f.huds[id] = nil end)
	override("hud_get_flags", function(f) return table.copy(f.flags) end)
	override("hud_set_flags", function(f, flags)
		for key, value in pairs(flags) do f.flags[key] = value end
	end)
	override("set_physics_override", function(f, o)
		for key, value in pairs(o) do f.physics[key] = value end
	end)
	override("get_physics_override", function(f) return table.copy(f.physics) end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
end

local function make_player(label, pos)
	local ref = core.add_entity(pos, "grug_probe_combat_exit:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_" .. label, {})
	inv:set_size("main", 8)
	inv:set_stack("main", 1, ItemStack("default:apple 5"))
	local fake = {
		name = name, ref = ref, hp = 100, holder = ItemStack("default:stick"),
		inv = inv, huds = {}, hud_next = 0, flags = {wielditem = true},
		physics = {},
	}
	fakes[ref] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	ref:get_meta():set_string("grug_classes:class", "warrior")
	return ref, fake
end

local function spawn_mob(pos)
	local obj = core.add_entity(pos, "grug_mobs:bandit")
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = 1
	grug_mobs.ensure_init(ent)
	ent.health = ent.hp_max
	ent.old_health = ent.health
	return obj, ent
end

--
-- The shipped paths.
--
-- An accepted ability hit: deal_ability_damage -> ObjectRef:punch -> mobs_redo
-- on_punch -> grug_mobs.accepted_player_punch -> run_player_hit_mob.
local function hit(ref, target, amount)
	return grug_core.deal_ability_damage(ref, target, amount or 1)
end

-- ToolCapabilities damage groups are 16-bit in the engine: stay below 32767.
local KILL = 20000

-- What the engine does when a mob, projectile or player punches a real
-- player: run the hp-change modifiers. Only grug_core's, which owns combat.
local function hit_player(ref, source)
	for _, fn in ipairs(core.registered_on_player_hpchanges.modifiers) do
		local origin = core.callback_origins[fn]
		if origin and origin.mod == "grug_core" then
			local ok, err = pcall(fn, ref, -1, {type = "punch", object = source,
				custom_type = grug_core.ARMOR_APPLIED_CUSTOM_TYPE})
			check(ok, "hp-change modifier ran without error" ..
				(ok and "" or (" (" .. tostring(err) .. ")")))
		end
	end
end

-- The engine's death: HP reaches 0, then on_dieplayer.
local function die(ref, fake)
	fake.hp = 0
	for _, fn in ipairs(core.registered_on_dieplayers) do
		local origin = core.callback_origins[fn]
		if origin and origin.mod == "grug_core" then
			fn(ref, {type = "punch"})
		end
	end
end

local function engaged(ent, ref)
	local edges = ent and ent.temp and ent.temp.grug_engaged
	return edges ~= nil and edges[ref:get_player_name()] == true
end

local function dead(obj, ent)
	return not obj:get_pos() or ent.state == "die" or (ent.health or 0) <= 0
end

local function can_eat(ref)
	local ok = grug_food.begin_hold(ref)
	if ok then grug_food.end_hold(ref) end
	return ok
end

local function in_combat(ref) return grug_core.in_combat(ref) end

--
-- Scenarios: {label, build(origin) -> list of {t, fn}} run one after another.
--
local scenarios = {}
local function scenario(label, build)
	scenarios[#scenarios + 1] = {label = label, build = build}
end

local spawned = {}
local function mob_at(origin, dx, dz)
	local obj, ent = spawn_mob(vector.offset(origin, dx, 0, dz))
	spawned[#spawned + 1] = obj
	return obj, ent
end

scenario("kill_last", function(o)
	local ref = make_player("kill_last", o)
	local obj, ent = mob_at(o, 0, 3)
	return {
		{0, function()
			hit(ref, obj)
			check(in_combat(ref), "kill_last: a hit on the mob puts the player in combat")
			check(engaged(ent, ref), "kill_last: the mob holds the engagement")
			check(ent.temp.grug_threat and (ent.temp.grug_threat[ref:get_player_name()] or 0) > 0,
				"kill_last: the hit is on the threat table")
			check(not can_eat(ref), "kill_last: eating refused while the mob lives")
			hit(ref, obj, KILL)
			check(dead(obj, ent), "kill_last: the mob died")
			check(not in_combat(ref), "kill_last: out of combat in the same step as the kill")
			check(can_eat(ref), "kill_last: eating allowed right after the last kill")
		end},
		{0.3, function()
			check(not in_combat(ref), "kill_last: still out of combat on a later step")
		end},
	}
end)

scenario("two_mobs", function(o)
	local ref = make_player("two_mobs", o)
	local a_obj, a = mob_at(o, -2, 3)
	local b_obj, b = mob_at(o, 2, 3)
	return {
		{0, function()
			hit(ref, a_obj)
			hit(ref, b_obj)
			check(engaged(a, ref) and engaged(b, ref), "two_mobs: both mobs engaged")
			hit(ref, a_obj, KILL)
			check(dead(a_obj, a), "two_mobs: first mob died")
			check(in_combat(ref), "two_mobs: still in combat while the second mob lives")
			check(not can_eat(ref), "two_mobs: eating still refused")
			hit(ref, b_obj, KILL)
			check(dead(b_obj, b), "two_mobs: second mob died")
			check(not in_combat(ref), "two_mobs: out of combat once the second mob died")
		end},
	}
end)

scenario("leash_reset", function(o)
	local ref = make_player("leash_reset", o)
	local obj, ent = mob_at(o, 0, 3)
	return {
		{0, function()
			hit(ref, obj)
			check(in_combat(ref), "leash_reset: in combat after the hit")
			grug_mobs.leash_reset(ent)
			check(ent.temp.grug_threat == nil, "leash_reset: threat table cleared")
			check(not engaged(ent, ref), "leash_reset: engagement dropped")
			check(not in_combat(ref), "leash_reset: out of combat at once")
		end},
	}
end)

scenario("stop_attack", function(o)
	local ref = make_player("stop_attack", o)
	local obj, ent = mob_at(o, 0, 3)
	return {
		{0, function()
			hit(ref, obj)
			check(ent.attack ~= nil, "stop_attack: the mob retaliated (has a target)")
			check(in_combat(ref), "stop_attack: in combat after the hit")
			ent:stop_attack()
			check(not in_combat(ref), "stop_attack: a mob giving up its fight ends combat at once")
		end},
	}
end)

-- mobs_redo's get_staticdata clears `attack` without stop_attack when the
-- engine re-saves a moved mob; the 1 Hz leash-tick backstop catches it.
scenario("target_lost", function(o)
	local ref = make_player("target_lost", o)
	local obj, ent = mob_at(o, 0, 3)
	return {
		{0, function()
			hit(ref, obj)
			check(in_combat(ref), "target_lost: in combat after the hit")
			ent.passive = true -- no re-acquisition by general_attack
			ent.attack = nil
			ent.state = "stand"
			check(in_combat(ref), "target_lost: the engagement survives until the mob tick")
		end},
		{1.6, function()
			check(not engaged(ent, ref), "target_lost: the 1 Hz backstop dropped the engagement")
			check(not in_combat(ref), "target_lost: out of combat within one leash tick")
		end},
	}
end)

scenario("removed", function(o)
	local ref = make_player("removed", o)
	local obj = mob_at(o, 0, 3)
	return {
		{0, function()
			hit(ref, obj)
			check(in_combat(ref), "removed: in combat after the hit")
			obj:remove()
			check(not in_combat(ref), "removed: removal/unload without death ends combat at once")
		end},
	}
end)

scenario("mob_first", function(o)
	local ref = make_player("mob_first", o)
	local shot = make_player("mob_first_shot", vector.offset(o, 3, 0, 0))
	local late = make_player("mob_first_late", vector.offset(o, -3, 0, 0))
	local killer = make_player("mob_first_killer", vector.offset(o, 0, 0, -2))
	local obj, ent = mob_at(o, 0, 3)
	local bolt = core.add_entity(vector.offset(o, 0, 1, 1), "grug_probe_combat_exit:bolt")
	bolt:get_luaentity()._grug_source = obj
	return {
		{0, function()
			hit_player(ref, obj)
			check(in_combat(ref), "mob_first: a mob hit on an untouched player puts them in combat")
			check(engaged(ent, ref), "mob_first: ... as an engagement")
			check(not (ent.temp.grug_threat and ent.temp.grug_threat[ref:get_player_name()]),
				"mob_first: ... without any threat entry")
			hit_player(shot, bolt)
			check(engaged(ent, shot), "mob_first: a projectile hit engages its shooter")
			hit(killer, obj, KILL)
			check(dead(obj, ent), "mob_first: the mob died")
			check(not in_combat(ref), "mob_first: hit player out of combat at the kill")
			check(not in_combat(shot), "mob_first: shot player out of combat at the kill")
			check(not in_combat(killer), "mob_first: killer out of combat at the kill")
			hit_player(late, bolt)
			check(not in_combat(late), "mob_first: a projectile of a dead shooter holds no fight")
			bolt:remove()
		end},
	}
end)

scenario("death", function(o)
	local ref, fake = make_player("death", o)
	local rival = make_player("death_rival", vector.offset(o, 3, 0, 0))
	local obj, ent = mob_at(o, 0, 3)
	return {
		{0, function()
			hit(ref, obj)
			hit_player(ref, rival) -- a PvP hit arms the timer as well
			check(in_combat(ref), "death: in combat (mob engagement + PvP timer)")
			die(ref, fake)
			check(not in_combat(ref), "death: out of combat immediately at death")
			check(not engaged(ent, ref), "death: the mob no longer holds the dead player")
			-- The killing blow's own bookkeeping after death must not re-arm.
			grug_core.mark_in_combat(ref)
			grug_core.engage_mob(ent, ref)
			grug_core.mark_player_hit(ref, obj)
			grug_core.add_threat(ent, ref, 5)
			check(not in_combat(ref), "death: post-death marks do not re-arm combat")
		end},
		{0.5, function()
			fake.hp = 100 -- respawn
			check(not in_combat(ref), "death: the respawned player starts out of combat")
		end},
		{1.0, function()
			check(not in_combat(ref), "death: still out of combat after the respawn")
			hit(ref, obj)
			check(in_combat(ref), "death: a new hit after the respawn engages again")
			obj:remove()
			check(not in_combat(ref), "death: ... and ends with the mob")
		end},
	}
end)

-- A player who hit the mob and then left (beyond the 40 m threat radius) is
-- forgotten by the next mob tick while the fight goes on with its target.
scenario("left_fight", function()
	local near_pos = vector.offset(BASE, 0.5, 0, 0.5)
	local tank = make_player("left_fight_tank", near_pos)
	local runner, runner_fake = make_player("left_fight_runner",
		vector.offset(near_pos, 2, 0, 0))
	local obj, ent = mob_at(near_pos, 0, 1.5)
	return {
		{0, function()
			hit(runner, obj) -- first, so the later tank hit takes the target
			hit(tank, obj, 3)
			check(ent.attack == tank, "left_fight: the mob targets the tank")
			check(engaged(ent, tank) and engaged(ent, runner), "left_fight: both engaged")
			-- The far arena corner: about 43 m from the mob, still loaded.
			runner:set_pos(vector.offset(BASE, 31.5, 0, 31.5))
			check(in_combat(runner), "left_fight: runner still in combat until the mob tick")
		end},
		{1.3, function()
			log(("left_fight: runner at %.1f m from the mob"):format(
				vector.distance(runner:get_pos(), obj:get_pos())))
			check(runner_fake.hp > 0 and runner:get_pos() ~= nil,
				"left_fight: runner is alive and loaded (a distance test, not a removal)")
			check(not in_combat(runner), "left_fight: the runner left combat")
			check(in_combat(tank), "left_fight: the tank stays in combat")
			obj:remove()
			check(not in_combat(tank), "left_fight: the tank leaves with the mob")
		end},
	}
end)

scenario("pvp", function(o)
	local a = make_player("pvp_a", o)
	local b = make_player("pvp_b", vector.offset(o, 0, 0, 2))
	return {
		{0, function()
			hit(a, b)
			hit_player(b, a) -- the engine's modifier call for the victim
			check(in_combat(a), "pvp: attacker in combat with no mob engaged")
			check(in_combat(b), "pvp: victim in combat with no mob engaged")
			check(can_eat(a) == false, "pvp: eating refused during the PvP window")
		end},
		{4.5, function()
			check(in_combat(a) and in_combat(b), "pvp: both still in combat at 4.5 s")
		end},
		{5.3, function()
			check(not in_combat(a) and not in_combat(b), "pvp: both out of combat after 5 s")
			check(can_eat(a), "pvp: eating allowed after the window")
		end},
	}
end)

-- Relative cost of the event paths (reported, not gated).
local function measure()
	local o = vector.offset(BASE, 0, 0, 25)
	local ref = make_player("measure", o)
	local obj, ent = mob_at(o, 0, 2)
	hit(ref, obj)
	local n = 100000
	local t0 = core.get_us_time()
	for _ = 1, n do grug_core.in_combat(ref) end
	local t1 = core.get_us_time()
	local m = 20000
	for _ = 1, m do
		grug_core.disengage_mob(ent)
		grug_core.engage_mob(ent, ref)
	end
	local t2 = core.get_us_time()
	log(("cost in_combat %.3f us/call; engage+disengage %.3f us/pair"):format(
		(t1 - t0) / n, (t2 - t1) / m))
	obj:remove()
	check(not in_combat(ref), "measure: cleanup ends combat")
end

local function finish()
	for _, obj in ipairs(spawned) do
		if obj:get_pos() then obj:remove() end
	end
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("combat exit probe done", false, 0)
end

local function run_scenario(index)
	local sc = scenarios[index]
	if not sc then
		local ok, err = pcall(measure)
		check(ok, "measure ran without error" .. (ok and "" or (" (" .. tostring(err) .. ")")))
		finish()
		return
	end
	local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
	local origin = vector.offset(BASE, 2 + col * SPACING, 0, 2 + row * SPACING)
	log("scenario " .. sc.label)
	local ok, steps = pcall(sc.build, origin)
	check(ok, sc.label .. ": setup ran without error" ..
		(ok and "" or (" (" .. tostring(steps) .. ")")))
	if not ok then
		core.after(0, run_scenario, index + 1)
		return
	end
	local last = 0
	for _, step in ipairs(steps) do
		last = math.max(last, step[1])
		core.after(step[1], function()
			local sok, err = pcall(step[2])
			check(sok, sc.label .. ": step at " .. step[1] .. " s ran without error" ..
				(sok and "" or (" (" .. tostring(err) .. ")")))
		end)
	end
	core.after(last + 0.3, run_scenario, index + 1)
end

-- One cleared arena: a stone floor under an air box high above the terrain.
local function build_arena(minp, maxp)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_floor = core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y == minp.y and c_floor or c_air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

core.after(2, function()
	-- 32 x 32 nodes inside one block row: four forceloaded blocks.
	local minp = vector.offset(BASE, 0, -1, 0)
	local maxp = vector.offset(BASE, 31, 6, 31)
	log("emerging arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build_arena(minp, maxp)
			-- No real player keeps these blocks active; without a forceload
			-- the probe entities are deactivated (and, unsaved, removed).
			for x = minp.x, maxp.x, 16 do
				for z = minp.z, maxp.z, 16 do
					assert(core.forceload_block(vector.new(x, BASE.y, z), true, -1))
				end
			end
			core.after(2, run_scenario, 1)
		end)
	end)
end)

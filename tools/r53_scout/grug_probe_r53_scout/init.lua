-- Disposable engine probe: Round 53 lane SCOUT (round53-plan.md K13). Never
-- shipped: tools/r53_scout/run.sh stages it through tools/luanti_headless.sh.
--
-- The tools/r52_bench pattern: each "player" is an invisible probe entity
-- whose ObjectRef answers the player accessors the skill path reads; the rest
-- is the shipped code on the real engine (input.step, try_cast, the kit,
-- the authoritative swing, the projectiles, deal_ability_damage).
--
-- Four arenas, one Scout each, in front of passive dummies (bandits that
-- neither move nor attack, with a huge health pool): "quarry" casts every bow
-- skill once (Loose held), "veil" every blade skill (Bladecraft LMB and RMB,
-- Parry then Opening, Flourish, Close Dance then swings), "stairs" and "cave"
-- cast the two areas (Flourish's cone, Split Shot's splash) at dummies one
-- and two nodes up a stair and under a cave ceiling. Every action is logged
-- with its time: try (cost), cd, dmg (deal_ability_damage's raw amount and
-- its share of R or M: the calculator's coefficient), swing (raw and share),
-- absorb (amount and share of P), launch (arrows), flash (a refusal).
-- Deterministic: crit and dodge chance are 0.

local P = "[r53_scout] "
local MOB = "grug_mobs:bandit"
local BASE = vector.new(600, 300, 600)
local SPACING = 32

local ARENAS = {
	{name = "quarry", ranks = {"quarry_true_draw", "quarry_snare_shot", "quarry_split_shot",
		"quarry_arrowfall"}, distance = 6, phases = {
		{id = "loose", hold = 2.0}, {id = "true_draw", hold = 0.3, gap = 1.6},
		{id = "snare_shot", hold = 0.3}, {id = "split_shot", hold = 0.3, gap = 1.2},
		{id = "arrowfall", hold = 0.3, gap = 2.8}, {id = "sidestep", hold = 0.3},
		{id = "sprint", hold = 0.3},
	}},
	{name = "veil", ranks = {"veil_bladecraft", "veil_opening", "veil_parry", "veil_flourish",
		"veil_close_dance"}, distance = 2.2, phases = {
		{id = "bladecraft", hold = 2.5}, {id = "bladecraft", hold = 0.3, rmb = true},
		{id = "parry", hold = 0.3}, {id = "opening", hold = 1.2}, {id = "opening", hold = 1.2,
			wait = 8.5}, {id = "flourish", hold = 0.3, gap = 1.2},
		{id = "close_dance", hold = 0.3}, {id = "bladecraft", hold = 3.0},
	}},
	{name = "stairs", ranks = {"veil_bladecraft", "veil_flourish", "quarry_split_shot"},
		distance = 2.2, stairs = true, phases = {
		{id = "flourish", hold = 0.3, gap = 1.2}, {id = "split_shot", hold = 0.3, gap = 1.2},
	}},
	{name = "cave", ranks = {"veil_bladecraft", "veil_flourish", "quarry_split_shot"},
		distance = 2.2, cave = true, phases = {
		{id = "flourish", hold = 0.3, gap = 1.2}, {id = "split_shot", hold = 0.3, gap = 1.2},
	}},
}
local GAP = 1.0
local SETTLE = 2.0

local lines = {}
local active
local function log(msg) core.log("action", P .. msg) end
local function record(kind, text)
	if not active then return end
	local t = (core.get_us_time() - active.t0) / 1e6
	local phase = active.spec.phases[active.phase]
	lines[#lines + 1] = ("%s %.3f %s %s %s"):format(active.spec.name, t,
		phase and phase.id or "-", kind, text)
	log("R " .. lines[#lines])
end

core.register_entity("grug_probe_r53_scout:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

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
	override("get_player_control", function(f) return f.controls end)
	override("get_player_control_bits", function() return 0 end)
	override("get_look_dir", function(f) return vector.copy(f.look) end)
	override("get_look_horizontal", function(f) return f.yaw end)
	override("get_look_vertical", function(f) return f.pitch end)
	override("get_meta", function(f) return f.holder:get_meta() end)
	override("get_inventory", function(f) return f.inv end)
	override("get_wield_list", function() return "main" end)
	override("get_wield_index", function(f) return f.index end)
	override("get_wielded_item", function(f) return f.inv:get_stack("main", f.index) end)
	override("set_wielded_item", function(f, stack) return f.inv:set_stack("main", f.index, stack) end)
	override("hud_get_hotbar_itemcount", function() return 8 end)
	override("hud_add", function(f)
		f.huds = f.huds + 1
		return f.huds
	end)
	override("hud_change", function() end)
	override("hud_remove", function() end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
	local talent_rank = grug_classes.talent_rank
	grug_classes.talent_rank = function(player, id)
		local fake = player and fakes[player]
		if fake then return fake.ranks[id] or 0 end
		return talent_rank(player, id)
	end
end

-- R and M of the active Scout (raw, before the level scalar), P at its level.
local function units(ref)
	local bow = grug_core.get_equipped_weapon(ref)
	local caps = bow and bow:get_tool_capabilities() or {}
	local r = ((caps.damage_groups or {}).fleshy or 0) + grug_classes.get_ranged_bonus(ref)
	local damage = grug_abilities.swing_stats(ref)
	local m = damage + grug_classes.get_melee_bonus(ref)
	return r, m, grug_core.base_pool(grug_core.get_player_level(ref))
end
local BLADE = {bladecraft = true, opening = true, flourish = true, close_dance = true, parry = true}

local function wrap_all()
	grug_core.get_crit_chance = function() return 0 end
	grug_core.get_dodge_chance = function() return 0 end
	local try_cast = grug_abilities.try_cast
	grug_abilities.try_cast = function(user, def, ...)
		local fake = fakes[user]
		local mana = grug_abilities.get_mana(user)
		local ok = try_cast(user, def, ...)
		if fake and ok then
			local _, _, pool = units(user)
			record("try", ("%s mana %d->%d (%.2f %% of P)"):format(def.id, mana,
				grug_abilities.get_mana(user), (mana - grug_abilities.get_mana(user)) / pool * 100))
		end
		return ok
	end
	local deal = grug_core.deal_ability_damage
	grug_core.deal_ability_damage = function(attacker, target, amount, opts)
		if fakes[attacker] then
			local r, m = units(attacker)
			local phase = active and active.spec.phases[active.phase]
			local unit = phase and BLADE[phase.id] and not phase.rmb and m or r
			local ent = target and target:get_luaentity()
			record("dmg", ("%s raw=%.3f share=%.3f %s"):format(ent and ent.name or "?",
				amount or 0, (amount or 0) / unit, unit == m and "M" or "R"))
		end
		return deal(attacker, target, amount, opts)
	end
	local begin = grug_core.begin_authoritative_swing
	grug_core.begin_authoritative_swing = function(player, target, tx)
		if fakes[player] then
			local _, m = units(player)
			local tyaw = target and not target:is_player() and target:get_yaw()
			record("swing", ("proc=%s raw=%.3f share=%.3f M fpi=%.3f target_yaw=%s"):format(
				tx.proc and tx.proc.id or "none", tx.raw_damage or 0, (tx.raw_damage or 0) / m,
				tx.fpi or 0, tyaw and ("%.2f"):format(tyaw) or "-"))
		end
		return begin(player, target, tx)
	end
	local arm = grug_abilities.arm_cooldown
	grug_abilities.arm_cooldown = function(player, def, duration)
		if fakes[player] and duration and duration > 0 then
			record("cd", ("%s %.3f"):format(def.id, duration))
		end
		return arm(player, def, duration)
	end
	local reset_charge = grug_abilities.reset_charge
	grug_abilities.reset_charge = function(player, def)
		if fakes[player] and def.charge then record("charge", def.id) end
		return reset_charge(player, def)
	end
	local absorb = grug_core.add_absorb
	grug_core.add_absorb = function(player, id, amount, duration, ...)
		if fakes[player] then
			local _, _, pool = units(player)
			record("absorb", ("%s %.3f (%.2f %% of P) for %.2f s"):format(id, amount or 0,
				(amount or 0) / pool * 100, duration or 0))
		end
		return absorb(player, id, amount, duration, ...)
	end
	local spawn_batch = grug_projectiles.spawn_batch
	grug_projectiles.spawn_batch = function(id, launches, commit)
		local ok = spawn_batch(id, launches, commit)
		local owner = launches[1] and launches[1].owner
		if owner and fakes[owner] then
			record("launch", ("%s x%d ok=%s"):format(id, #launches, tostring(ok)))
		end
		return ok
	end
	local flash = grug_abilities.flash
	grug_abilities.flash = function(player, msg)
		if fakes[player] then record("flash", tostring(msg)) end
		return flash(player, msg)
	end
end

--
-- Arenas: a stone floor; stairs (one and two nodes up) or a cave ceiling
-- three nodes above the floor where the arena asks for it.
--
local function build(minp, maxp)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_stone = core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y == minp.y and c_stone or c_air
			end
		end
	end
	for index, spec in ipairs(ARENAS) do
		local o = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
		if spec.stairs then
			-- Step 1 under the first dummy, step 2 under the second.
			for x = -1, 0 do
				data[area:index(o.x + x, o.y, o.z + 2)] = c_stone
			end
			data[area:index(o.x + 1, o.y, o.z + 2)] = c_stone
			data[area:index(o.x + 1, o.y + 1, o.z + 2)] = c_stone
			data[area:index(o.x + 1, o.y, o.z + 3)] = c_stone
			data[area:index(o.x + 1, o.y + 1, o.z + 3)] = c_stone
		end
		if spec.cave then
			for z = o.z - 4, o.z + 8 do
				for x = o.x - 5, o.x + 5 do
					data[area:index(x, o.y + 3, z)] = c_stone
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

local function aim(r)
	local ref, fake = r.ref, r.fake
	local eye = vector.offset(ref:get_pos(), 0, ref:get_properties().eye_height or 1.625, 0)
	local cb = r.mob:get_properties().collisionbox or {0, 0, 0, 0, 1, 0}
	local centre = vector.offset(r.mob:get_pos(), 0, (cb[2] + cb[5]) / 2, 0)
	local dir = vector.direction(eye, centre)
	fake.look = dir
	fake.yaw = core.dir_to_yaw(dir)
	fake.pitch = -math.asin(dir.y)
end

local function spawn_dummy(pos, yaw)
	local obj = core.add_entity(pos, MOB)
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = 1
	ent.do_custom = function() return false end
	ent.knock_back = false
	ent.hp_max, ent.hp_min = 1000000, 1000000
	ent.health, ent.old_health = 1000000, 1000000
	obj:set_yaw(yaw or math.pi) -- facing the Scout
	return obj
end

local function start_arena(index, spec)
	math.randomseed(5300 + index)
	local origin = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
	local ref = core.add_entity(origin, "grug_probe_r53_scout:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "scout_" .. spec.name
	local inv = core.create_detached_inventory("grug_probe_r53_scout_" .. spec.name, {})
	inv:set_size("main", 32)
	inv:set_size("grug_weapon", 1)
	inv:set_size("grug_offhand", 1)
	local fake = {name = name, controls = {}, look = vector.new(0, 0, 1), yaw = 0,
		pitch = 0, holder = ItemStack("grug_abilities:strike"), inv = inv, index = 1,
		ranks = {}, huds = 0}
	fakes[ref] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	ref:get_meta():set_string("grug_classes:class", "scout")
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local origin_rec = core.callback_origins[fn]
		if origin_rec and origin_rec.mod == "grug_projectiles" then fn(ref, nil) end
	end
	inv:set_stack("grug_offhand", 1, grug_gear.weapon_item("sword", 1))
	inv:set_stack("grug_weapon", 1, grug_gear.weapon_item("bow", 1))
	inv:set_stack("main", 30, "grug_gear:arrow 99")
	for _, id in ipairs(spec.ranks) do fake.ranks[id] = 1 end
	local slots, used = {}, 0
	for _, phase in ipairs(spec.phases) do
		if not slots[phase.id] then
			used = used + 1
			slots[phase.id] = used
			local stack = grug_abilities.stack_for(ref, phase.id)
			if not stack then log("FAIL " .. spec.name .. ": " .. phase.id .. " is not unlocked") end
			inv:set_stack("main", slots[phase.id], stack or "")
		end
		phase.slot = slots[phase.id]
	end
	grug_abilities.restore_mana(ref, 1000000)
	local d = spec.distance
	local mob = spawn_dummy(vector.offset(origin, 0, spec.stairs and 1 or 0, d))
	-- A second dummy beside the first: in Flourish's cone and within 3 m of
	-- the first (Split Shot's splash); up a second step on the stairs.
	local second = spawn_dummy(vector.offset(origin, 1, spec.stairs and 2 or 0, d + 0.3))
	active = {spec = spec, ref = ref, fake = fake, mob = mob, second = second,
		origin = origin, phase = 1, t0 = core.get_us_time()}
	active.phase_start = active.t0
	fake.index = spec.phases[1].slot
	local r, m, pool = units(ref)
	record("start", ("level=%d R=%.3f M=%.3f P=%d mana=%d arrows=%d"):format(
		grug_core.get_player_level(ref), r, m, pool, grug_abilities.get_mana(ref),
		grug_inventory.ammo_count(ref)))
end

local queue = {}
local function finish()
	log(("RESULT DONE records=%d"):format(#lines))
	core.request_shutdown("r53 scout probe done", false, 0)
end

local FORCELOAD_WAIT = 3
local loaded = {}
local function forceload(index)
	for _, pos in ipairs(loaded) do core.forceload_free_block(pos, true) end
	loaded = {}
	if not index then return end
	local origin = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
	for dx = -16, 16, 16 do
		for dz = -16, 16, 16 do
			local pos = vector.offset(origin, dx, 0, dz)
			if core.forceload_block(pos, true) then loaded[#loaded + 1] = pos end
		end
	end
end

local function next_arena()
	if active then
		record("end", ("mana=%d arrows=%d"):format(grug_abilities.get_mana(active.ref),
			grug_inventory.ammo_count(active.ref)))
		fakes[active.ref] = nil
		active.ref:remove()
		active.mob:remove()
		active.second:remove()
		active = nil
	end
	local item = table.remove(queue, 1)
	if not item then
		forceload(nil)
		finish()
		return
	end
	forceload(item[1])
	core.after(FORCELOAD_WAIT, function() start_arena(item[1], item[2]) end)
end

core.register_globalstep(function()
	if not active then return end
	local r = active
	local now = core.get_us_time()
	local phase = r.spec.phases[r.phase]
	local elapsed = (now - r.phase_start) / 1e6
	if not phase then
		if elapsed >= SETTLE then next_arena() end
		return
	end
	if elapsed >= (phase.wait or 0) + phase.hold + (phase.gap or GAP) then
		r.phase = r.phase + 1
		r.phase_start = now
		phase = r.spec.phases[r.phase]
		if not phase then
			r.fake.controls = {}
			return
		end
		r.fake.index = phase.slot
		record("phase", phase.id .. (phase.rmb and " (RMB)" or ""))
		elapsed = 0
	end
	local wait = phase.wait or 0
	local held = elapsed >= wait and elapsed < wait + phase.hold
	r.fake.controls = held and (phase.rmb and {place = true} or {dig = true}) or {}
	if not r.ref:get_pos() or not r.mob:get_pos() then
		log(("FAIL %s: lost the %s"):format(r.spec.name, r.ref:get_pos() and "dummy" or "player"))
		active = nil
		return
	end
	aim(r)
	grug_abilities.input.step(r.ref)
end)

core.after(2, function()
	local minp = vector.offset(BASE, -8, -1, -6)
	local maxp = vector.offset(BASE, SPACING * #ARENAS + 8, 8, 16)
	log("emerging arenas " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build(minp, maxp)
			wrap_all()
			for index, spec in ipairs(ARENAS) do queue[#queue + 1] = {index, spec} end
			core.after(0.5, next_arena)
		end)
	end)
end)

-- Disposable engine probe: the Round 52 CORE-A PvE bench. Never shipped:
-- tools/r52_bench/run.sh stages it through tools/luanti_headless.sh, on this
-- branch or on an exported main, and compare.py diffs the two logs.
--
-- Built on tools/r22_ability_punch: each "player" is a real, invisible probe
-- entity whose ObjectRef answers the player accessors the skill path reads.
-- Everything else is the shipped code on the real engine: input.step (the LMB
-- hold machine), try_cast, the kit casts, the authoritative swing, projectiles,
-- deal_ability_damage, the status pass and Mend.
--
-- One class at a time fights a passive dummy (a bandit that neither moves nor
-- attacks, with a huge health pool) in its own arena: a timed list of phases,
-- each selecting one skill on the hotbar, holding LMB for `hold` seconds and
-- releasing for `gap`. Every action is logged with its time since the class
-- began: try (a cast that went through try_cast: cost paid), swing (proc, raw
-- and scaled damage), hit (damage a mob took), cd (cooldown armed), charge,
-- heal / tick (a heal inside a cast / outside one: Mend's ticks), absorb,
-- flash (a refusal shown). Deterministic inside the probe: crit and dodge
-- chance are 0 and math.random is seeded per class. Timings follow the
-- server step, so compare.py compares them within one step.

local P = "[r52_bench] "
local MOB = "grug_mobs:bandit"
local BASE = vector.new(400, 300, 400)
local SPACING = 32
local DISTANCE = 3

local CLASSES = {
	{class = "warrior", hand = {"grug_weapon", "sword"}, rage = 100, phases = {
		{id = "strike", hold = 3.5}, {id = "mighty_blow", hold = 2.5},
		{id = "hamstring", hold = 2.5}, {id = "taunt", hold = 0.3},
		{id = "hold_ground", hold = 0.3}, {id = "charge", hold = 0.3},
	}},
	-- Round 53: the new kits (the Mage's and the Priest's basic attack
	-- replaced Strike; Cinderfall, Glacial Ward and Pinning Shot are retired).
	{class = "mage", hand = {"grug_weapon", "staff"}, phases = {
		{id = "fiery_spark", hold = 3.0}, {id = "fireball", hold = 3.5},
		{id = "ice_wave", hold = 2.0}, {id = "meteor", hold = 0.3},
		{id = "rime_mantle", hold = 0.3}, {id = "blink", hold = 0.3},
	}},
	{class = "priest", hand = {"grug_weapon", "staff"}, hp = 30, phases = {
		{id = "smite", hold = 3.0},
		{id = "heal", hold = 0.3}, {id = "shield_spell", hold = 0.3},
		{id = "mend", hold = 0.3, gap = 14}, {id = "word_of_ruin", hold = 0.3},
	}},
	{class = "scout", hand = {"grug_offhand", "dagger"}, bow = true, phases = {
		{id = "strike", hold = 2.5}, {id = "snare_shot", hold = 0.3},
		{id = "true_draw", hold = 0.3}, {id = "opening", hold = 2.5},
		{id = "sidestep", hold = 0.3}, {id = "sprint", hold = 0.3},
	}},
}
local GAP = 1.0
local SETTLE = 2.0 -- after the last phase, for projectiles in flight

local lines = {}
local active -- the running class record
local function log(msg) core.log("action", P .. msg) end
local function record(kind, text)
	if not active then return end
	local t = (core.get_us_time() - active.t0) / 1e6
	lines[#lines + 1] = ("%s %.3f %s %s"):format(active.class, t, kind, text)
	log("R " .. lines[#lines])
end

core.register_entity("grug_probe_r52_bench:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

--
-- Probe players: per-object overrides on the shared ObjectRef method table
-- (tools/r22_ability_punch), plus the HUD calls of the cooldown overlay.
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
	-- Talent-gated skills: a probe player names its ranks directly.
	local talent_rank = grug_classes.talent_rank
	grug_classes.talent_rank = function(player, id)
		local fake = player and fakes[player]
		if fake then return fake.ranks[id] or 0 end
		return talent_rank(player, id)
	end
end

--
-- Determinism and the action log around the shipped transactions.
--
local depth = 0
local function wrap_all()
	grug_core.get_crit_chance = function() return 0 end
	grug_core.get_dodge_chance = function() return 0 end
	for _, def in pairs(grug_abilities.registered) do
		if def.cast then
			local original = def.cast
			def.cast = function(...)
				depth = depth + 1
				local results = {pcall(original, ...)}
				depth = depth - 1
				if not results[1] then error(results[2], 0) end
				return unpack(results, 2)
			end
		end
	end
	local try_cast = grug_abilities.try_cast
	grug_abilities.try_cast = function(user, def, ...)
		local fake = fakes[user]
		local mana, rage = grug_abilities.get_mana(user), grug_abilities.get_rage(user)
		local ok = try_cast(user, def, ...)
		if fake and ok then
			record("try", ("%s mana %d->%d rage %d->%d"):format(def.id, mana,
				grug_abilities.get_mana(user), rage, grug_abilities.get_rage(user)))
		end
		return ok
	end
	local begin = grug_core.begin_authoritative_swing
	grug_core.begin_authoritative_swing = function(player, target, tx)
		if fakes[player] then
			record("swing", ("proc=%s raw=%.3f scaled=%.3f fpi=%.3f"):format(
				tx.proc and tx.proc.id or "none", tx.raw_damage or 0,
				tx.scaled_damage or 0, tx.fpi or 0))
		end
		return begin(player, target, tx)
	end
	local hit = grug_core.run_player_hit_mob
	grug_core.run_player_hit_mob = function(player, ent, damage)
		if player and fakes[player] then
			record("hit", ("%s dmg=%.3f"):format(ent and ent.name or "?", damage or 0))
		end
		return hit(player, ent, damage)
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
	local heal = grug_core.heal_player
	grug_core.heal_player = function(healer, target, amount, opts)
		if (healer and fakes[healer]) or (target and fakes[target]) then
			record(depth > 0 and "heal" or "tick", ("%s->%s amount=%.3f"):format(
				healer and healer:get_player_name() or "?",
				target and target:get_player_name() or "?", amount or 0))
		end
		return heal(healer, target, amount, opts)
	end
	local absorb = grug_core.add_absorb
	grug_core.add_absorb = function(player, id, amount, ...)
		if fakes[player] then record("absorb", ("%s %.3f"):format(id, amount or 0)) end
		return absorb(player, id, amount, ...)
	end
	local flash = grug_abilities.flash
	grug_abilities.flash = function(player, msg)
		if fakes[player] then record("flash", tostring(msg)) end
		return flash(player, msg)
	end
	-- The status pass (grug_core/status.lua) visits connected players only:
	-- let it see the probe players too, for Mend's ticks on this branch.
	local wrapped = false
	for i, fn in ipairs(core.registered_globalsteps) do
		local info = debug.getinfo(fn, "S")
		if info and info.source and info.source:find("grug_core[/\\]status%.lua$") then
			local wrapper = function(dtime)
				local get = core.get_connected_players
				core.get_connected_players = function()
					local list = get()
					if active then list[#list + 1] = active.ref end
					return list
				end
				local ok, err = pcall(fn, dtime)
				core.get_connected_players = get
				if not ok then error(err, 0) end
			end
			core.callback_origins[wrapper] = core.callback_origins[fn]
			core.registered_globalsteps[i] = wrapper
			wrapped = true
		end
	end
	log("status pass wrapped: " .. tostring(wrapped))
end

--
-- Arenas, players and the dummy.
--
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

local function spawn_dummy(pos)
	local obj = core.add_entity(pos, MOB)
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = 1
	grug_mobs.ensure_init(ent)
	-- Passive: no movement, no attack, no knockback, never dies.
	ent.do_custom = function() return false end
	ent.knock_back = false
	ent.hp_max, ent.hp_min = 1000000, 1000000
	ent.health, ent.old_health = 1000000, 1000000
	return obj, ent
end

local function start_class(index, spec)
	math.randomseed(5200 + index)
	local origin = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
	local ref = core.add_entity(origin, "grug_probe_r52_bench:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "bench_" .. spec.class
	local inv = core.create_detached_inventory("grug_probe_r52_bench_" .. spec.class, {})
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
	ref:get_meta():set_string("grug_classes:class", spec.class)
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local origin_rec = core.callback_origins[fn]
		if origin_rec and origin_rec.mod == "grug_projectiles" then fn(ref, nil) end
	end
	-- Gear before anything reads the hands (grug_inventory caches them).
	inv:set_stack(spec.hand[1], 1, grug_gear.weapon_item(spec.hand[2], 1))
	if spec.bow then
		inv:set_stack("grug_weapon", 1, grug_gear.weapon_item("bow", 1))
		inv:set_stack("main", 30, "grug_gear:arrow 99")
	end
	for i, phase in ipairs(spec.phases) do
		local def = grug_abilities.registered[phase.id]
		if def.talent_gated then fake.ranks[def.talent or def.id] = 1 end
		phase.slot = i
	end
	for i, phase in ipairs(spec.phases) do
		local stack = grug_abilities.stack_for(ref, phase.id)
		if not stack then log("FAIL " .. spec.class .. ": " .. phase.id .. " is not unlocked") end
		inv:set_stack("main", i, stack or "")
	end
	grug_abilities.restore_mana(ref, 1000000)
	if spec.rage then grug_abilities.add_rage(ref, spec.rage) end
	if spec.hp then ref:set_hp(spec.hp) end
	local mob = spawn_dummy(vector.offset(origin, 0, 0, DISTANCE))
	active = {class = spec.class, spec = spec, ref = ref, fake = fake, mob = mob,
		origin = origin, phase = 1, t0 = core.get_us_time()}
	active.phase_start = active.t0
	fake.index = spec.phases[1].slot
	record("start", ("mana=%d rage=%d hp=%d"):format(grug_abilities.get_mana(ref),
		grug_abilities.get_rage(ref), ref:get_hp()))
	record("phase", spec.phases[1].id)
end

local queue = {}
local steps = {n = 0, max = 0, sum = 0}
local function finish()
	log(("STEPS n=%d mean=%.4f max=%.4f"):format(steps.n,
		steps.n > 0 and steps.sum / steps.n or 0, steps.max))
	log(("RESULT DONE records=%d"):format(#lines))
	core.request_shutdown("r52 bench done", false, 0)
end

-- A headless server has no player, so no block is active and every object
-- would be deactivated at once: each class's arena is force-loaded (transient)
-- for its run, a few seconds before its objects are added.
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
	log(("class arena %d: %d blocks force-loaded"):format(index, #loaded))
end

local function next_class()
	if active then
		record("end", ("mana=%d rage=%d hp=%d"):format(grug_abilities.get_mana(active.ref),
			grug_abilities.get_rage(active.ref), active.ref:get_hp()))
		fakes[active.ref] = nil
		active.ref:remove()
		active.mob:remove()
		active = nil
	end
	local item = table.remove(queue, 1)
	if not item then
		forceload(nil)
		finish()
		return
	end
	forceload(item[1])
	core.after(FORCELOAD_WAIT, function()
		log(("class %s starts at server time %.1f s"):format(item[2].class,
			core.get_us_time() / 1e6))
		start_class(item[1], item[2])
	end)
end

core.register_globalstep(function(dtime)
	if not active then return end
	steps.n, steps.sum = steps.n + 1, steps.sum + dtime
	steps.max = math.max(steps.max, dtime)
	local r = active
	local now = core.get_us_time()
	local phase = r.spec.phases[r.phase]
	local elapsed = (now - r.phase_start) / 1e6
	if not phase then
		if elapsed >= SETTLE then next_class() end
		return
	end
	if elapsed >= phase.hold + (phase.gap or GAP) then
		r.phase = r.phase + 1
		r.phase_start = now
		phase = r.spec.phases[r.phase]
		if not phase then
			r.fake.controls = {}
			return
		end
		r.fake.index = phase.slot
		record("phase", phase.id)
		elapsed = 0
	end
	r.fake.controls = elapsed < phase.hold and {dig = true} or {}
	if not r.ref:get_pos() or not r.mob:get_pos() then
		-- Not expected (the arena is force-loaded); at shutdown the server
		-- removes the entities.
		log(("FAIL %s: lost the %s"):format(r.class, r.ref:get_pos() and "dummy" or "player"))
		active = nil
		return
	end
	aim(r)
	grug_abilities.input.step(r.ref)
end)

core.after(2, function()
	local minp = vector.offset(BASE, -6, -1, -6)
	local maxp = vector.offset(BASE, SPACING * #CLASSES + 6, 8, 16)
	log("emerging arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build_arena(minp, maxp)
			wrap_all()
			for index, spec in ipairs(CLASSES) do queue[#queue + 1] = {index, spec} end
			core.after(0.5, next_class)
		end)
	end)
end)

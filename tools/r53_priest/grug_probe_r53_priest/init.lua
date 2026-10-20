-- Disposable engine probe (Round 53 lane PRIEST, round53-plan.md K13): one
-- level-31 Priest with an own-level staff casts each of the ten skills once at
-- a passive dummy through the real input machine and try_cast, then Censure
-- again with the dummy on a one-node stair and under a cave ceiling. Every
-- action is logged beside the calculator's value (the formulas of
-- combat_stats.md §2, written out below). Never shipped: tools/r53_priest/
-- run.sh stages it through tools/luanti_headless.sh. The probe builds its own
-- arena, stair and ceiling in the throwaway world; the game writes no node.
--
-- The probe player is the tools/r52_bench pattern: a real, invisible entity
-- whose ObjectRef answers the player accessors the skill path reads. Crit and
-- dodge chance are 0, so every number is deterministic.

local P = "[r53_priest] "
local MOB = "grug_mobs:bandit"
local LEVEL = 31
local STAFF_BRACKET = 4 -- item level 31: an own-level staff
local BASE = vector.new(400, 300, 400)
local DISTANCE = 4
local GAP = 1.6 -- longer than the longest occupied time (1.5 s)

-- The calculator (combat_stats.md §2): P pool, W weapon, B base hit, U the
-- Priest's spell unit with natural Intelligence, S the damage scalar.
local function round(x) return math.floor(x + 0.5) end
local CP = round(20 + 5 * LEVEL + 0.66 * LEVEL * LEVEL)
local CW = round(4 + 0.35 * LEVEL)
local CB = CW + (10 + 3 * (LEVEL - 1)) / 10
local CU = CW + (10 + 2 * (LEVEL - 1)) / 10
local CS = CP / (8 * CB)
local function hit(coef) return math.max(1, math.floor(coef * CU * CS)) end
local function pool(pct) return CP * pct / 100 end
local function mana(pct) return math.max(1, math.floor(CP * pct / 100 + 0.5)) end
local CALC = {
	smite = ("damage %d, free, interval 1, occupied 1"):format(hit(1)),
	heal = ("heal %.2f, mana %d, cd 5, occupied 1.5"):format(pool(25), mana(10)),
	shield_spell = ("absorb %.2f for 10 s, mana %d, cd 12, occupied 1"):format(pool(24), mana(9)),
	mend = ("4 ticks of %.2f every 3 s, mana %d, cd 12, occupied 1"):format(pool(7), mana(8)),
	hearten = ("heal %.2f each, cap 4, mana %d, cd 20, occupied 1.5"):format(pool(15), mana(14)),
	haven = ("6 ticks of %.2f every 2 s, mana %d, cd 60, occupied 1.5"):format(pool(7), mana(22)),
	rebuke = ("damage %d, mana %d, cd 6, occupied 1"):format(hit(1.8), mana(6)),
	word_of_ruin = ("damage %d, heal min(dealt/2, %.2f), mana %d, cd 16, occupied 1"):format(
		hit(1.6), pool(6), mana(10)),
	censure = ("damage %d to <= 4 after 0.75 s, radius 3, mana %d, cd 18, occupied 1"):format(
		hit(1.2), mana(12)),
	final_word = ("damage %d, mana %d, cd 60, occupied 1.5"):format(hit(2.8), mana(20)),
}

-- The phases: one press each (a held support skill at a hostile would fire
-- Smite, K8), `setup` before the press.
local PHASES = {
	{id = "smite"}, {id = "heal"}, {id = "shield_spell"}, {id = "mend", gap = 13},
	{id = "hearten"}, {id = "haven", gap = 13}, {id = "rebuke"}, {id = "word_of_ruin"},
	{id = "censure", label = "flat"},
	{id = "censure", label = "stair", setup = "stair"},
	{id = "censure", label = "cave", setup = "cave"},
	{id = "final_word"},
}
local KIT = {"smite", "heal", "shield_spell", "mend", "hearten", "haven", "rebuke",
	"word_of_ruin", "censure", "final_word"}
local HOLD = 0.05
local SETTLE = 2.0

local active
local count = 0
local function log(msg) core.log("action", P .. msg) end
local function record(kind, text)
	if not active then return end
	count = count + 1
	log(("R %.3f %s %s"):format((core.get_us_time() - active.t0) / 1e6, kind, text))
end

core.register_entity("grug_probe_r53_priest:hero", {
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
	-- The probe player's level and its unlocked nodes.
	local level = grug_xp.get_level
	grug_xp.get_level = function(player)
		if player and fakes[player] then return LEVEL end
		return level(player)
	end
	grug_core.get_player_level = grug_xp.get_level
	local talent_rank = grug_classes.talent_rank
	grug_classes.talent_rank = function(player, id)
		local fake = player and fakes[player]
		if fake then return fake.ranks[id] or 0 end
		return talent_rank(player, id)
	end
end

local function describe(obj)
	if not obj then return "?" end
	if obj:is_player() then return "player:" .. obj:get_player_name() end
	local ent = obj:get_luaentity()
	return ent and ent.name or "?"
end

local function wrap_all()
	grug_core.get_crit_chance = function() return 0 end
	grug_core.get_dodge_chance = function() return 0 end
	local try_cast = grug_abilities.try_cast
	grug_abilities.try_cast = function(user, def, ...)
		local mana_before = grug_abilities.get_mana(user)
		local ok = try_cast(user, def, ...)
		if fakes[user] then
			record(ok and "cast" or "refused", ("%s mana %d->%d"):format(def.id, mana_before,
				grug_abilities.get_mana(user)))
		end
		return ok
	end
	local deal = grug_core.deal_ability_damage
	grug_core.deal_ability_damage = function(attacker, target, amount, opts)
		local dealt = deal(attacker, target, amount, opts)
		if fakes[attacker] then
			record("damage", ("%s raw=%.3f dealt=%d"):format(describe(target), amount or 0, dealt or 0))
		end
		return dealt
	end
	local heal = grug_core.heal_player
	grug_core.heal_player = function(healer, target, amount, opts)
		if (healer and fakes[healer]) or (target and fakes[target]) then
			record("heal", ("%s amount=%.3f no_crit=%s"):format(describe(target), amount or 0,
				tostring(opts and opts.no_crit or false)))
		end
		return heal(healer, target, amount, opts)
	end
	local absorb = grug_core.add_absorb
	grug_core.add_absorb = function(player, id, amount, duration, ...)
		if fakes[player] then record("absorb", ("%s %.3f for %g s"):format(id, amount or 0, duration or 0)) end
		return absorb(player, id, amount, duration, ...)
	end
	local set_status = grug_core.set_status
	grug_core.set_status = function(player, id, def)
		if fakes[player] and def.on_tick then
			record("status", ("%s %g s every %g s"):format(id, def.duration or 0, def.interval or 0))
		end
		return set_status(player, id, def)
	end
	local arm = grug_abilities.arm_cooldown
	grug_abilities.arm_cooldown = function(player, def, duration)
		if fakes[player] then record("cd", ("%s %.3f"):format(def.id, duration or 0)) end
		return arm(player, def, duration)
	end
	local flash = grug_abilities.flash
	grug_abilities.flash = function(player, msg)
		if fakes[player] then record("flash", tostring(msg)) end
		return flash(player, msg)
	end
	local play = grug_core.particles.play
	grug_core.particles.play = function(id, frame)
		if active and (id == "censure_warning" or id == "censure_fall" or id == "censure_impact") then
			record("fx", ("%s at %s reach=%s height=%s"):format(id,
				frame.target and core.pos_to_string(frame.target, 2) or "-",
				tostring(frame.reach), tostring(frame.height)))
		end
		return play(id, frame)
	end
	local sound = grug_sounds.play
	grug_sounds.play = function(event, target)
		if active and event == "censure_impact" then
			record("sound", event .. " at " .. (type(target) == "table" and target.x and
				core.pos_to_string(target, 2) or describe(target)))
		end
		return sound(event, target)
	end
	-- The status pass visits connected players only: let it see the probe
	-- player too, for Mend's and Haven's ticks.
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
		end
	end
end

local c_air, c_stone
local function fill(minp, maxp, content)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = content(x, y, z)
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
	ent.do_custom = function() return false end
	ent.knock_back = false
	ent.hp_max, ent.hp_min = 1000000, 1000000
	ent.health, ent.old_health = 1000000, 1000000
	return obj
end

local SETUPS = {
	-- A one-node step under the dummy and one more node in front of it.
	stair = function(r)
		local at = vector.round(r.mob:get_pos())
		fill(vector.offset(at, -2, 0, 0), vector.offset(at, 2, 0, 2), function() return c_stone end)
		r.mob:set_pos(vector.offset(at, 0, 1, 0))
		record("setup", "stair: the dummy on a step at " .. core.pos_to_string(vector.offset(at, 0, 1, 0)))
	end,
	-- Back on the floor, under a stone ceiling four nodes above it.
	cave = function(r)
		local at = vector.round(r.mob:get_pos())
		local floor = vector.offset(at, 0, -1, 0)
		fill(vector.offset(floor, -2, 0, 0), vector.offset(floor, 2, 0, 2), function() return c_air end)
		r.mob:set_pos(floor)
		local ceiling = vector.offset(floor, 0, 4, 0)
		fill(vector.offset(ceiling, -6, 0, -6), vector.offset(ceiling, 6, 0, 6), function() return c_stone end)
		record("setup", "cave: the dummy at " .. core.pos_to_string(floor) .. ", ceiling at y " .. ceiling.y)
	end,
}

local FORCELOAD_WAIT = 3
local loaded = {}

local function finish()
	for _, pos in ipairs(loaded) do core.forceload_free_block(pos, true) end
	log(("RESULT DONE records=%d"):format(count))
	core.request_shutdown("r53 priest probe done", false, 0)
end

local function start()
	math.randomseed(5300)
	local ref = core.add_entity(BASE, "grug_probe_r53_priest:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_priest"
	local inv = core.create_detached_inventory("grug_probe_r53_priest", {})
	inv:set_size("main", 32)
	inv:set_size("grug_weapon", 1)
	inv:set_size("grug_offhand", 1)
	local fake = {name = name, controls = {}, look = vector.new(0, 0, 1), yaw = 0,
		pitch = 0, holder = ItemStack("grug_abilities:heal"), inv = inv, index = 1,
		ranks = {}, huds = 0}
	fakes[ref] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	ref:get_meta():set_string("grug_classes:class", "priest")
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local origin = core.callback_origins[fn]
		if origin and origin.mod == "grug_projectiles" then fn(ref, nil) end
	end
	inv:set_stack("grug_weapon", 1, grug_gear.weapon_item("staff", STAFF_BRACKET))
	local slots = {}
	for i, id in ipairs(KIT) do
		local def = grug_abilities.registered[id]
		if def.talent_gated then fake.ranks[def.talent] = 1 end
		slots[id] = i
	end
	for i, id in ipairs(KIT) do
		local stack = grug_abilities.stack_for(ref, id)
		if not stack then log("FAIL " .. id .. " is not unlocked") end
		inv:set_stack("main", i, stack or "")
	end
	for _, phase in ipairs(PHASES) do phase.slot = slots[phase.id] end
	grug_abilities.restore_mana(ref, 1000000)
	ref:set_hp(30)
	local mob = spawn_dummy(vector.offset(BASE, 0, 0, DISTANCE))
	active = {ref = ref, fake = fake, mob = mob, phase = 1, t0 = core.get_us_time()}
	active.phase_start = active.t0
	fake.index = PHASES[1].slot
	log(("calc level %d: P=%d W=%d B=%.2f unit=%.2f S=%.5f; spell_base in game %.2f, " ..
		"current_form(strike)=%s"):format(LEVEL, CP, CW, CB, CU, CS,
		grug_abilities.spell_base(ref),
		(grug_abilities.current_form(ref, grug_abilities.registered.strike) or {}).id or "-"))
	for _, id in ipairs(KIT) do log("calc " .. id .. ": " .. CALC[id]) end
	record("start", ("mana=%d hp=%d"):format(grug_abilities.get_mana(ref), ref:get_hp()))
	record("phase", PHASES[1].id)
end

local function stop()
	record("end", ("mana=%d hp=%d"):format(grug_abilities.get_mana(active.ref), active.ref:get_hp()))
	fakes[active.ref] = nil
	active.ref:remove()
	active.mob:remove()
	active = nil
	finish()
end

core.register_globalstep(function()
	if not active then return end
	local r = active
	local now = core.get_us_time()
	local phase = PHASES[r.phase]
	local elapsed = (now - r.phase_start) / 1e6
	if not phase then
		if elapsed >= SETTLE then stop() end
		return
	end
	if elapsed >= HOLD + (phase.gap or GAP) then
		r.phase = r.phase + 1
		r.phase_start = now
		phase = PHASES[r.phase]
		if not phase then
			r.fake.controls = {}
			return
		end
		r.fake.index = phase.slot
		-- Full mana for each skill (the pool would run dry before the last).
		grug_abilities.restore_mana(r.ref, 1000000)
		if phase.setup then
			-- The same skill again: its cooldown is the probe's to lift.
			grug_abilities.clear_cooldown(r.ref, phase.id)
			SETUPS[phase.setup](r)
		end
		record("phase", phase.id .. (phase.label and (" " .. phase.label) or ""))
		elapsed = 0
	end
	r.fake.controls = elapsed < HOLD and {dig = true} or {}
	if not r.ref:get_pos() or not r.mob:get_pos() then
		log("FAIL lost the " .. (r.ref:get_pos() and "dummy" or "player"))
		active = nil
		return
	end
	aim(r)
	grug_abilities.input.step(r.ref)
end)

core.after(2, function()
	c_air, c_stone = core.get_content_id("air"), core.get_content_id("default:stone")
	local minp = vector.offset(BASE, -8, -1, -8)
	local maxp = vector.offset(BASE, 8, 8, 16)
	log("emerging arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			fill(minp, maxp, function(_, y) return y == minp.y and c_stone or c_air end)
			wrap_all()
			-- The arena's blocks and the ones above it (an unloaded node counts
			-- as solid for the falling seal's ceiling).
			for dx = -16, 16, 16 do
				for dy = 0, 16, 16 do
					for dz = -16, 16, 16 do
						local pos = vector.offset(BASE, dx, dy, dz)
						if core.forceload_block(pos, true) then loaded[#loaded + 1] = pos end
					end
				end
			end
			core.after(FORCELOAD_WAIT, start)
		end)
	end)
end)

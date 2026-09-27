-- Disposable engine probe (Round 22, ability-punch recursion). Never shipped:
-- tools/r22_ability_punch/run.sh stages it through tools/luanti_headless.sh.
--
-- A headless server has no client, so each "player" is a real, invisible,
-- non-pointable probe entity whose ObjectRef answers the player accessors the
-- skill path reads (is_player, name, controls, look, meta, inventory, wield).
-- Everything else is the shipped code on the real engine: input.step,
-- try_cast, the kit casts, grug_core.deal_ability_damage, ObjectRef:punch,
-- mobs_redo on_punch with its native-input seam, projectiles and the
-- authoritative swing transaction.
--
-- Each scenario presses LMB once at a fresh hostile grug mob and asserts:
-- exactly one cast (or one authoritative swing), no nested cast, one resource
-- payment, the cooldown armed, and the mob's health dropped.

local P = "[ability_punch_probe] "
local MOB = "grug_mobs:bandit"
local BASE = vector.new(160, 300, 160)
local SPACING = 16
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

core.register_entity("grug_probe_ability_punch:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	-- A retaliating mob must not remove the probe "player".
	on_punch = function() return true end,
})

--
-- Probe players: per-object overrides on the shared ObjectRef method table.
--
local fakes, by_name = {}, {}
local methods

local function install(ref)
	if methods then return end
	methods = getmetatable(ref) -- the ObjectRef method table (__metatable)
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
	override("get_wielded_item", function(f)
		return f.inv:get_stack("main", f.index)
	end)
	override("set_wielded_item", function(f, stack)
		return f.inv:set_stack("main", f.index, stack)
	end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
	-- Talent ranks need level, budget and chain gates; the cleave scenario
	-- only needs its one effect key, so a probe player may name it directly.
	local get_talent_bonus = grug_classes.get_talent_bonus
	grug_classes.get_talent_bonus = function(player, key)
		local fake = player and fakes[player]
		if fake and fake.talents and fake.talents[key] then
			return fake.talents[key]
		end
		return get_talent_bonus(player, key)
	end
end

local function make_player(label, class, pos)
	local ref = core.add_entity(pos, "grug_probe_ability_punch:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_" .. label, {})
	inv:set_size("main", 32)
	fakes[ref] = {
		name = name, controls = {}, look = vector.new(0, 0, 1), yaw = 0,
		pitch = 0, holder = ItemStack("grug_abilities:strike"), inv = inv,
		index = 1,
	}
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	ref:get_meta():set_string("grug_classes:class", class)
	-- Only the projectile session join; no HUD/kit/formspec join work.
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local origin = core.callback_origins[fn]
		if origin and origin.mod == "grug_projectiles" then fn(ref, nil) end
	end
	return ref, fakes[ref]
end

local function aim(ref, fake, target)
	local eye = vector.offset(ref:get_pos(), 0,
		ref:get_properties().eye_height or 1.625, 0)
	local cb = target:get_properties().collisionbox or {0, 0, 0, 0, 1, 0}
	local centre = vector.offset(target:get_pos(), 0, (cb[2] + cb[5]) / 2, 0)
	local dir = vector.direction(eye, centre)
	fake.look = dir
	fake.yaw = core.dir_to_yaw(dir)
	fake.pitch = -math.asin(dir.y)
end

local function spawn_mob(pos)
	local obj = core.add_entity(pos, MOB)
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	-- Same level as the probe player (no level malus), at full health. The
	-- second ensure_init re-derives the level's maximum (reassert_max), which
	-- every later punch would otherwise do and so fake a health drop.
	ent._grug_level = 1
	grug_mobs.ensure_init(ent)
	ent.health = ent.hp_max
	ent.old_health = ent.health
	return obj, ent
end

--
-- Counters around the shipped transactions.
--
-- casts/swings/max_depth are per scenario; the totals are never reset, so a
-- projectile's late hit is judged against every scenario that ran meanwhile.
local counts = {casts = 0, depth = 0, max_depth = 0, swings = 0,
	total_casts = 0, total_swings = 0}

local function wrap_transactions()
	for _, def in pairs(grug_abilities.registered) do
		if def.cast then
			local original = def.cast
			def.cast = function(...)
				counts.casts = counts.casts + 1
				counts.total_casts = counts.total_casts + 1
				counts.depth = counts.depth + 1
				counts.max_depth = math.max(counts.max_depth, counts.depth)
				if counts.depth > 4 then
					-- Bound an unfixed build's recursion so the probe reports it
					-- instead of overflowing the C stack.
					counts.depth = counts.depth - 1
					return false, "probe recursion cap"
				end
				local ok, err = original(...)
				counts.depth = counts.depth - 1
				return ok, err
			end
		end
	end
	local begin = grug_core.begin_authoritative_swing
	grug_core.begin_authoritative_swing = function(...)
		counts.swings = counts.swings + 1
		counts.total_swings = counts.total_swings + 1
		return begin(...)
	end
end

local function press(ref, fake)
	fake.controls = {dig = true}
	grug_abilities.input.step(ref)
	fake.controls = {}
	grug_abilities.input.step(ref)
end

-- label, class, ability, mob distance, expected casts, expected swings.
local scenarios = {
	{label = "smite", class = "priest", ability = "smite", distance = 3,
		casts = 1, swings = 0},
	{label = "frost_nova", class = "mage", ability = "frost_nova", distance = 3,
		casts = 1, swings = 0},
	{label = "charge", class = "warrior", ability = "charge", distance = 8,
		casts = 1, swings = 0, rage = 15},
	{label = "strike", class = "warrior", ability = "strike", distance = 2,
		casts = 0, swings = 1},
	{label = "fireball", class = "mage", ability = "fireball", distance = 8,
		casts = 1, swings = 0, deferred = true},
	-- Broadstroke: the proc's cleave punches a second mob inside the swing.
	{label = "mighty_blow_cleave", class = "warrior", ability = "mighty_blow",
		distance = 2, casts = 0, swings = 1, start_rage = 50, rage = 8 - 25,
		talents = {mighty_blow_cleave = 3}, cleave = true},
}

local function run_scenario(index, sc)
	local origin = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
	local ref, fake = make_player(sc.label, sc.class, origin)
	local mob, ent = spawn_mob(vector.offset(origin, 0, 0, sc.distance))
	local second, second_health
	if sc.cleave then
		-- Beside the target, outside the aim ray, inside the 3 m cleave.
		second = select(2, spawn_mob(vector.offset(origin, 1.5, 0, sc.distance)))
		second_health = second.health
		fake.talents = sc.talents
	end
	local def = grug_abilities.registered[sc.ability]
	check(grug_abilities.is_unlocked(ref, sc.ability),
		sc.label .. ": ability unlocked for " .. sc.class)
	check(grug_abilities.valid_target(ref, mob, "hostile"),
		sc.label .. ": " .. MOB .. " is a valid hostile target")
	fake.inv:set_stack("main", 1, grug_abilities.stack_for(ref, sc.ability))
	grug_abilities.restore_mana(ref, 1000000)
	if sc.start_rage then grug_abilities.add_rage(ref, sc.start_rage) end
	aim(ref, fake, mob)
	local cost = grug_abilities.cost_for(ref, def.cost, sc.ability).mana or 0
	local before = {
		mana = grug_abilities.get_mana(ref), rage = grug_abilities.get_rage(ref),
		health = ent.health,
	}
	counts.casts, counts.depth, counts.max_depth, counts.swings = 0, 0, 0, 0
	press(ref, fake)
	local mana_after = grug_abilities.get_mana(ref)
	log(("%s: casts=%d max_depth=%d swings=%d mana %d->%d (cost %d) " ..
		"rage %d->%d health %s->%s"):format(sc.label, counts.casts,
		counts.max_depth, counts.swings, before.mana, mana_after, cost,
		before.rage, grug_abilities.get_rage(ref), tostring(before.health),
		tostring(ent.health)))
	check(counts.casts == sc.casts, ("%s: %d cast(s), expected %d"):format(
		sc.label, counts.casts, sc.casts))
	check(counts.max_depth <= 1, ("%s: no nested cast (max depth %d)"):format(
		sc.label, counts.max_depth))
	check(counts.swings == sc.swings, ("%s: %d authoritative swing(s), " ..
		"expected %d"):format(sc.label, counts.swings, sc.swings))
	check(before.mana - mana_after == cost, ("%s: paid %d mana, expected %d")
		:format(sc.label, before.mana - mana_after, cost))
	if sc.rage then
		check(grug_abilities.get_rage(ref) - before.rage == sc.rage,
			("%s: rage changed by %d, expected %d"):format(sc.label,
				grug_abilities.get_rage(ref) - before.rage, sc.rage))
	end
	if second then
		check(second.health < second_health, ("%s: cleave hit the second " ..
			"mob (%s -> %s)"):format(sc.label, tostring(second_health),
			tostring(second.health)))
	end
	if (def.cooldown or 0) > 0 then
		check(not grug_abilities.ready(ref, sc.ability),
			sc.label .. ": cooldown armed")
	end
	local function damage_landed()
		check(ent.health ~= nil and ent.health < before.health,
			("%s: mob health dropped (%s -> %s)"):format(sc.label,
				tostring(before.health), tostring(ent.health)))
	end
	if not sc.deferred then
		damage_landed()
		return nil
	end
	-- Projectile: the hit settles on a later server step.
	-- Deferred checks run after every scenario: `casts`/`swings` are the
	-- totals once all presses are done, before any projectile has landed.
	return function(casts, swings)
		log(("%s (after flight): extra casts=%d extra swings=%d health " ..
			"%s->%s"):format(sc.label, counts.total_casts - casts,
			counts.total_swings - swings, tostring(before.health),
			tostring(ent.health)))
		check(counts.total_casts == casts and counts.total_swings == swings,
			sc.label .. ": the hit started no further cast or swing")
		damage_landed()
	end
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("ability punch probe done", false, 0)
end

local function run_all()
	wrap_transactions()
	local deferred = {}
	for index, sc in ipairs(scenarios) do
		local ok, result = pcall(run_scenario, index, sc)
		check(ok, sc.label .. ": scenario ran without error" ..
			(ok and "" or (" (" .. tostring(result) .. ")")))
		if ok and result then deferred[#deferred + 1] = result end
	end
	local casts, swings = counts.total_casts, counts.total_swings
	core.after(1.5, function()
		for _, fn in ipairs(deferred) do
			local ok, err = pcall(fn, casts, swings)
			check(ok, "deferred check ran without error" ..
				(ok and "" or (" (" .. tostring(err) .. ")")))
		end
		finish()
	end)
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

core.register_on_mods_loaded(function()
	assert(core.registered_entities[MOB], MOB .. " is not registered")
	assert(grug_abilities.input, "grug_abilities.input is missing")
end)

core.after(2, function()
	local minp = vector.offset(BASE, -4, -1, -4)
	local maxp = vector.offset(BASE, SPACING * #scenarios + 4, 6, 12)
	log("emerging arena " .. core.pos_to_string(minp) .. " - " ..
		core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build_arena(minp, maxp)
			core.after(0.5, run_all)
		end)
	end)
end)

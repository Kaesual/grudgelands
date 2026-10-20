-- Disposable engine probe (Round 52 lane CORE-B). Never shipped:
-- tools/r52_core/probe.sh stages it through tools/luanti_headless.sh.
--
-- A test ability registered HERE (never in mods/): a Mage cast that anchors
-- with grug_core.area.anchor, schedules grug_core.area.delayed (1.5 s, the
-- warning and falling particles) and at the impact hits up to four hostiles
-- found by grug_core.area.query (radius 3, band +-3; no line of sight since
-- 0.53.1), through
-- the shipped grug_abilities.try_cast (cost, cooldown, refusals). The cases,
-- each in its own built scene high above the terrain: stairs, stacked
-- floors, a cave, shallow and deep water, a flying mob without ground, a
-- caster who died before the impact, and a group heal whose status keeps
-- running on a recipient who left the area. Per case the log names the
-- anchor, the refusal, mana paid, the cooldown, the hits and the particles
-- per cast. "Players" are invisible probe entities answering the player
-- accessors (the Round 22 ability-punch pattern).

local P = "[r52core] "
local MOB = "grug_mobs:bandit"
local BASE = vector.new(160, 300, 160)
local SPACING = 32
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
	return ok
end
local function ptext(p)
	return p and ("(%.2f,%.2f,%.2f)"):format(p.x, p.y, p.z) or "none"
end

-- Particles: every single particle and every spawner's amount.
local particle_count = 0
local add_particle, add_spawner = core.add_particle, core.add_particlespawner
core.add_particle = function(def)
	particle_count = particle_count + 1
	return add_particle(def)
end
core.add_particlespawner = function(def)
	particle_count = particle_count + (def.amount or 0)
	return add_spawner(def)
end
-- Per effect id: the particles of its last play, and the fall's height.
local effect_particles, fall_starts = {}, {}
local play = grug_core.particles.play
grug_core.particles.play = function(id, frame)
	if id == "area_fall" then fall_starts[#fall_starts + 1] = frame.height end
	local before = particle_count
	play(id, frame)
	effect_particles[id] = particle_count - before
end

core.register_entity("grug_probe_r52_core:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

--
-- Probe players: per-object overrides on the shared ObjectRef method table.
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
			if fake then return fn(fake, self, ...) end
			return original(self, ...)
		end
	end
	local get_hp = methods.get_hp
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
	-- The cooldown overlay of an armed cooldown reads the hotbar size.
	override("hud_get_hotbar_itemcount", function() return 8 end)
	override("get_wield_index", function(f) return f.index end)
	override("get_wielded_item", function(f) return f.inv:get_stack("main", f.index) end)
	override("set_wielded_item", function(f, _, stack)
		return f.inv:set_stack("main", f.index, stack)
	end)
	-- A "dead" probe player answers 0 without the entity being removed.
	override("get_hp", function(f, self)
		if f.dead then return 0 end
		return get_hp(self)
	end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
end

local function make_player(label, class, pos)
	local ref = core.add_entity(pos, "grug_probe_r52_core:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_r52_" .. label, {})
	inv:set_size("main", 32)
	fakes[ref] = {name = name, controls = {}, look = vector.new(0, 0, 1), yaw = 0,
		pitch = 0, holder = ItemStack("grug_abilities:strike"), inv = inv, index = 1}
	by_name[name] = ref
	ref:get_meta():set_string("grug_classes:class", class)
	ref:get_meta():set_string("grug_factions:faction", "accord")
	return ref, fakes[ref]
end

local function aim(ref, fake, point)
	local eye = grug_core.combat_eye_pos(ref)
	local dir = vector.direction(eye, point)
	fake.look = dir
	fake.yaw = core.dir_to_yaw(dir)
	fake.pitch = -math.asin(dir.y)
end

-- A hostile mob with its feet on `feet` (the top of the ground), standing
-- still for the probe.
local function spawn_mob(feet)
	local obj = core.add_entity(feet, MOB)
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = 1
	grug_mobs.ensure_init(ent)
	ent.health = ent.hp_max
	ent.old_health = ent.health
	ent.walk_velocity, ent.run_velocity, ent.walk_chance = 0, 0, 0
	ent.jump = false
	local cb = obj:get_properties().collisionbox
	obj:set_pos(vector.offset(feet, 0, -cb[2], 0))
	obj:set_velocity(vector.zero())
	return obj, ent
end

local function mob_body(obj)
	local cb = obj:get_properties().collisionbox
	return vector.offset(obj:get_pos(), 0, (cb[2] + cb[5]) / 2, 0)
end

--
-- The test ability (probe only).
--
local results = {}
local current

grug_abilities.CAST_SOUNDS.probe_area = "silent"
-- register_ability registers the tool under grug_abilities' prefix; from
-- this mod that name needs the ":" override prefix.
local register_tool = core.register_tool
core.register_tool = function(name, def) return register_tool(":" .. name, def) end
grug_abilities.register_ability({
	id = "probe_area", class = "mage", kind = "cast", target_kind = "hostile",
	name = "Probe Area", description = "Probe only.", color = "#ff7a2a",
	cost = {mana_percent = 5}, cooldown = 1, range = 20,
	cast = function(user, pointed, def)
		local enemy = function(obj) return grug_abilities.valid_target(user, obj, "hostile") end
		local anchor, target = grug_core.area.anchor(user, def.range, {is_enemy = enemy})
		if not anchor then
			return false, target
		end
		local record = current
		record.anchor = anchor
		record.target = target
		return grug_core.area.delayed(user, {anchor = anchor, delay = 1.5, radius = 3,
			color = "#ff7a2a", impact = function(caster, at)
				record.impact_at = at
				record.caster_hp = caster:get_hp()
				-- The burst played just before this callback.
				record.impact_particles = effect_particles.area_impact
				record.in_box = #core.get_objects_in_area(vector.offset(at, -3, -3, -3),
					vector.offset(at, 3, 3, 3))
				local hits = grug_core.area.query(at, {radius = 3, cap = 4,
					filter = function(obj)
						return grug_abilities.valid_target(caster, obj, "hostile")
					end})
				record.hits = {}
				for _, obj in ipairs(hits) do
					local ent = obj:get_luaentity()
					local hp = ent and ent.health
					grug_core.deal_ability_damage(caster, obj, 10, {action_id = {}})
					record.hits[#record.hits + 1] = {obj = obj, before = hp,
						after = ent and ent.health}
				end
			end})
	end,
})
core.register_tool = register_tool

--
-- Scenes. Local coordinates: the floor's top is y = 0.5 (stone at y = 0).
--
local scenes = {}
local function scene(index) return vector.offset(BASE, (index - 1) * SPACING, 0, 0) end
local writes = {}
local function put(origin, x, y, z, name)
	writes[#writes + 1] = {pos = vector.offset(origin, x, y, z), name = name}
end
local function box(origin, x1, y1, z1, x2, y2, z2, name)
	for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do
		put(origin, x, y, z, name)
	end end end
end

-- 1 stairs: four stone stairs rising along +z onto a platform.
scenes[1] = function(o)
	for k = 0, 3 do
		box(o, -2, 1, 8 + k, 2, k, 8 + k, "default:stone")
		box(o, -2, k + 1, 8 + k, 2, k + 1, 8 + k, "stairs:stair_stone")
	end
	box(o, -2, 1, 12, 2, 4, 14, "default:stone")
end
-- 2 stacked floors: an upper floor at y = 4 over open ground; the caster
-- stands on a pillar at its height.
scenes[2] = function(o)
	box(o, -4, 4, 6, 4, 4, 13, "default:stone")
	box(o, 0, 1, 0, 0, 4, 0, "default:stone")
end
-- 3 cave: a closed rock body with a hollow three nodes high.
scenes[3] = function(o)
	box(o, -6, 1, -2, 6, 9, 16, "default:stone")
	box(o, -5, 1, -1, 5, 3, 15, "air")
end
-- 4 water: a shallow pool (2 deep) and a deep one (5 deep).
scenes[4] = function(o)
	box(o, -2, -1, 6, 2, 0, 10, "default:water_source")
	box(o, -2, -4, 14, 2, 0, 18, "default:water_source")
	box(o, -2, -5, 14, 2, -5, 18, "default:stone")
end
-- 5 flying mob, 6 dead caster, 7 group heal: plain floor; 7 has a wall.
scenes[5] = function() end
scenes[6] = function() end
scenes[7] = function(o)
	box(o, -2, 1, -3, 2, 3, -3, "default:stone")
end

local function build(minp, maxp)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_stone = core.get_content_id("default:stone")
	local floor_y = BASE.y
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y <= floor_y and c_stone or c_air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
	for _, w in ipairs(writes) do
		core.set_node(w.pos, {name = w.name})
	end
end

--
-- The cases.
--
local function cast(ref, label, point)
	local fake = fakes[ref]
	aim(ref, fake, point)
	grug_abilities.restore_mana(ref, 1000000)
	local def = grug_abilities.registered.probe_area
	fake.inv:set_stack("main", 1, grug_abilities.stack_for(ref, "probe_area"))
	local record = {label = label}
	current = record
	local mana = grug_abilities.get_mana(ref)
	local before = particle_count
	local refusal
	local ok = grug_abilities.try_cast(ref, def, nil, function(message) refusal = message end)
	record.ok = ok == true
	record.refusal = refusal
	record.paid = mana - grug_abilities.get_mana(ref)
	record.cooldown_armed = not grug_abilities.ready(ref, "probe_area")
	record.cast_particles = particle_count - before
	record.fall = fall_starts[#fall_starts]
	fall_starts = {}
	results[#results + 1] = record
	return record
end

local function report(record)
	local hits = {}
	for _, hit in ipairs(record.hits or {}) do
		hits[#hits + 1] = ("%s %s->%s"):format(ptext(hit.obj:get_pos()),
			tostring(hit.before), tostring(hit.after))
	end
	log(("%s: cast=%s refusal=%s paid=%d cooldown=%s anchor=%s from=%s fall=%s " ..
		"particles cast=%d impact=%s objects in the box=%s hits=%d [%s]"):format(record.label,
		tostring(record.ok), tostring(record.refusal), record.paid,
		tostring(record.cooldown_armed), ptext(record.anchor),
		record.anchor and (record.target and "enemy" or "terrain") or "-",
		tostring(record.fall),
		record.cast_particles, tostring(record.impact_particles),
		tostring(record.in_box), #(record.hits or {}), table.concat(hits, "; ")))
end

local mobs = {}
local pending_checks = {}

local function run_cases()
	-- 1 stairs: aim at the mob on the third stair.
	local o = scene(1)
	local mage = make_player("stairs", "mage", vector.offset(o, 0, 0.5, 0))
	mobs.stair_top = spawn_mob(vector.offset(o, 0, 3.5, 10))
	mobs.stair_low = spawn_mob(vector.offset(o, 1.5, 1.5, 8))
	mobs.stair_floor = spawn_mob(vector.offset(o, -1.5, 0.5, 7))
	local r1 = cast(mage, "stairs", mob_body(mobs.stair_top))
	pending_checks[#pending_checks + 1] = function()
		check(r1.ok and r1.anchor and math.abs(r1.anchor.y - (o.y + 3.5)) < 0.01,
			"stairs: anchored on the stair under the mob")
		check(r1.hits and #r1.hits >= 1, "stairs: the impact hit")
	end

	-- 2 stacked floors: the caster on a pillar at the upper floor's height.
	o = scene(2)
	local mage2 = make_player("floors", "mage", vector.offset(o, 0, 4.5, 0))
	mobs.upper = spawn_mob(vector.offset(o, 0, 4.5, 9))
	mobs.lower = spawn_mob(vector.offset(o, 1, 0.5, 9))
	local r2 = cast(mage2, "stacked floors", mob_body(mobs.upper))
	pending_checks[#pending_checks + 1] = function()
		check(r2.ok and r2.anchor and math.abs(r2.anchor.y - (o.y + 4.5)) < 0.01,
			"stacked floors: anchored on the upper floor")
		local lower_hit = false
		for _, hit in ipairs(r2.hits or {}) do
			if hit.obj == mobs.lower then lower_hit = true end
		end
		check(not lower_hit, "stacked floors: the mob 4 below is outside the band")
	end

	-- 3 cave: the caster inside, a mob on the cave floor.
	o = scene(3)
	local mage3 = make_player("cave", "mage", vector.offset(o, 0, 0.5, 1))
	mobs.cave = spawn_mob(vector.offset(o, 0, 0.5, 9))
	local r3 = cast(mage3, "cave", mob_body(mobs.cave))
	pending_checks[#pending_checks + 1] = function()
		check(r3.ok and r3.anchor and math.abs(r3.anchor.y - (o.y + 0.5)) < 0.01,
			"cave: anchored on the cave floor")
		check(r3.fall and r3.fall <= 2.5 + 1e-6, "cave: the fall starts below the ceiling")
		check(r3.hits and #r3.hits == 1, "cave: the mob was hit")
	end

	-- 4 water: aim at each pool's surface away from the mob.
	o = scene(4)
	local mage4 = make_player("water", "mage", vector.offset(o, 0, 0.5, 0))
	mobs.pool = spawn_mob(vector.offset(o, 1, -1.5, 9))
	local r4 = cast(mage4, "shallow water", vector.offset(o, -1, 0.5, 7.5))
	local mage4b = make_player("water_deep", "mage", vector.offset(o, 0, 0.5, 1))
	local r4b = cast(mage4b, "deep water", vector.offset(o, 0, 0.5, 16))
	pending_checks[#pending_checks + 1] = function()
		check(r4.ok and r4.anchor and math.abs(r4.anchor.y - (o.y - 1.5)) < 0.01,
			"shallow water: anchored on the pool's floor")
		check(r4.hits and #r4.hits == 1, "shallow water: the mob in the water was hit")
		check(not r4b.ok and r4b.refusal == "No ground found.", "deep water: refused")
		check(r4b.paid == 0 and not r4b.cooldown_armed,
			"deep water: no cost, no cooldown")
	end

	-- 5 flying mob without ground (cast in its spawn step: no fall yet).
	o = scene(5)
	local mage5 = make_player("flying", "mage", vector.offset(o, 0, 0.5, 0))
	mobs.flyer = spawn_mob(vector.offset(o, 0, 8.5, 8))
	local r5 = cast(mage5, "flying mob", mob_body(mobs.flyer))
	check(not r5.ok and r5.refusal == "No ground found.", "flying mob: refused")
	check(r5.paid == 0 and not r5.cooldown_armed, "flying mob: no cost, no cooldown")

	-- 6 a caster who dies before the impact still lands it (D9).
	o = scene(6)
	local mage6 = make_player("dead", "mage", vector.offset(o, 0, 0.5, 0))
	mobs.dead_target = spawn_mob(vector.offset(o, 0, 0.5, 6))
	local r6 = cast(mage6, "dead caster", mob_body(mobs.dead_target))
	fakes[mage6].dead = true
	pending_checks[#pending_checks + 1] = function()
		check(r6.impact_at ~= nil and r6.caster_hp == 0,
			"dead caster: the impact ran with the dead caster")
		local hit = r6.hits and r6.hits[1]
		log(("dead caster: the mob's health %s -> %s"):format(
			tostring(hit and hit.before), tostring(hit and hit.after)))
	end
end

-- 7 group heal: the group helper plus set_status with on_tick (C5).
local function run_group()
	local o = scene(7)
	local priest = make_player("priest", "priest", vector.offset(o, 0, 0.5, 0))
	local low = make_player("ally_low", "warrior", vector.offset(o, 3, 0.5, 0))
	local mid = make_player("ally_mid", "mage", vector.offset(o, -4, 0.5, 2))
	local far = make_player("ally_far", "scout", vector.offset(o, 0, 0.5, 20))
	local hidden = make_player("ally_hidden", "scout", vector.offset(o, 0, 0.5, -5))
	low:set_hp(40)
	mid:set_hp(70)
	hidden:set_hp(10)
	far:set_hp(10)
	local group = grug_core.area.group(priest, {radius = 8, cap = 5,
		eligible = function(obj) return grug_abilities.valid_target(priest, obj, "friendly") end})
	local list = {}
	for _, p in ipairs(group) do list[#list + 1] = p:get_player_name() end
	log("group heal recipients: " .. table.concat(list, ","))
	-- 0.53.1 (ruling 1): no line of sight, so the ally behind the wall is in.
	check(table.concat(list, ",") == "probe_ally_hidden,probe_ally_low,probe_ally_mid,probe_priest",
		"group: lowest share first, self included, the ally behind the wall too, the far one left out")
	for _, p in ipairs(group) do
		grug_core.set_status(p, "mend", {label = "Probe heal", duration = 12, interval = 3,
			on_tick = function(target) target:set_hp(target:get_hp() + 1) end})
	end
	low:set_pos(vector.offset(o, 0, 0.5, 28)) -- leaves the area at once
	return low
end

local function finish()
	for _, record in ipairs(results) do report(record) end
	for _, fn in ipairs(pending_checks) do
		local ok, err = pcall(fn)
		check(ok, "a pending check ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))
	end
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r52 core probe done", false, 0)
end

local function run_all()
	local ok, err = pcall(run_cases)
	check(ok, "the cases ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))
	local moved
	ok, err = pcall(function() moved = run_group() end)
	check(ok, "the group case ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))
	core.after(4, function()
		if moved then
			local record = grug_core.get_status(moved, "mend")
			check(record ~= nil, "group: the status still runs on the ally who left")
			-- Probe entities are not connected players, so the status step
			-- never ticks them here; the tick on a moved recipient is the
			-- portable fixture's part F (the real status.lua).
			log(("group: the moved ally's status expires in %.1f s, next tick due in %.1f s"):format(
				record and (record.expiry_us - core.get_us_time()) / 1e6 or -1,
				record and (record.next_tick_us - core.get_us_time()) / 1e6 or -1))
		end
		finish()
	end)
end

core.register_on_mods_loaded(function()
	assert(core.registered_entities[MOB], MOB .. " is not registered")
	assert(core.registered_nodes["stairs:stair_stone"], "no stone stair")
end)

core.after(2, function()
	local minp = vector.offset(BASE, -8, -8, -8)
	local maxp = vector.offset(BASE, SPACING * #scenes, 14, 32)
	for index, fn in ipairs(scenes) do fn(scene(index)) end
	log("emerging " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			-- No player is connected: keep the arena's blocks active, so the
			-- mobs stay in the world for the delayed impacts.
			for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
				for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
					for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
						core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1)
					end
				end
			end
			build(minp, maxp)
			core.after(0.5, run_all)
		end)
	end)
end)

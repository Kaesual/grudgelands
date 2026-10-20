-- Disposable engine probe (Round 53 WARRIOR, plan K13). Never shipped:
-- tools/r53_warrior/run.sh stages it through tools/luanti_headless.sh.
--
-- The tools/r52_bench pattern: each "player" is a real, invisible probe
-- entity whose ObjectRef answers the player accessors the skill path reads;
-- everything else is the shipped code on the real engine (input.step, the
-- LMB hold machine, try_cast, the kit, the authoritative swing, the swing
-- callback, deal_ability_damage, the windows, area.query and area.cone on
-- real nodes). A level-60 Warrior with a tree's sample build casts each skill
-- once at passive dummies (bandits that neither move nor attack, with a huge
-- health pool), in four arenas: Bulwark and Ruin on flat ground, then
-- Broadstroke and Bellow on stairs and in a cave. Crit and dodge are 0.
-- Every action is logged with its time: try (a cast went through: rage),
-- swing (proc, raw, scaled), hit (which dummy, damage), cd, charge, heal,
-- absorb, status, window, taunt, slow, flash (a refusal shown).

local P = "[r53_warrior] "
local MOB = "grug_mobs:bandit"
local BASE = vector.new(400, 300, 400)
local SPACING = 40
local LEVEL = 60

-- Dummies: {tag, dx, dy, dz}; the first is the one aimed at.
local ARENAS = {
	{name = "bulwark_flat", tree = "bulwark", rage = 100, dummies = {
		{"front", 0, 0, 2.5}, {"behind", -2, 0, -3}, {"far", 0, 0, 7.5}},
	phases = {
		{id = "strike", hold = 1.2}, -- Retort, unready
		{id = "strike", hold = 1.2, ready_retort = true}, -- Retort, readied
		{id = "hold_ground", hold = 0.3}, {id = "taunt", hold = 0.3}, -- Bellow
		{id = "unbroken", hold = 0.3}, {id = "charge", hold = 0.3},
	}},
	{name = "ruin_flat", tree = "ruin", rage = 100, dummies = {
		{"primary", 0, 0, 2.2}, {"left", -1, 0, 2.2}, {"right", 1.2, 0, 2.4},
		{"third", 0.4, 0, 2.9}, {"behind", 0, 0, -2.5}},
	phases = {
		{id = "strike", hold = 1.2}, {id = "mighty_blow", hold = 1.2}, -- Broadstroke
		{id = "hamstring", hold = 1.2}, {id = "ruination", hold = 0.3},
		{id = "strike", hold = 1.2}, {id = "mighty_blow", hold = 1.2},
		{id = "charge", hold = 0.3},
	}},
	{name = "stairs", tree = "ruin", extra = {bulwark_taunt = 1, bulwark_bellow = 1},
		rage = 100, stairs = true, dummies = {
		{"primary", 0, 0, 1.5}, {"step1", 1, 1, 2.2}, {"step2", -0.5, 2, 2.9},
		{"step3", 0, 3, 4.6}},
	phases = {{id = "mighty_blow", hold = 1.2}, {id = "taunt", hold = 0.3}}},
	{name = "cave", tree = "ruin", extra = {bulwark_taunt = 1, bulwark_bellow = 1},
		rage = 100, cave = true, dummies = {
		{"primary", 0, 0, 2.2}, {"left", -1, 0, 2.2}, {"right", 1.2, 0, 2.4},
		{"deep", 3, 0, -3}, {"walled", 0, 0, -6.5}},
	phases = {{id = "mighty_blow", hold = 1.2}, {id = "taunt", hold = 0.3}}},
}
local GAP = 1.2
local SETTLE = 1.5

local lines = {}
local active
local function log(msg) core.log("action", P .. msg) end
local function record(kind, text)
	if not active then return end
	local t = (core.get_us_time() - active.t0) / 1e6
	lines[#lines + 1] = ("%s %.3f %s %s"):format(active.name, t, kind, text)
	log("R " .. lines[#lines])
end

core.register_entity("grug_probe_r53_warrior:hero", {
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
	override("set_fov", function() end)
	override("set_bone_override", function() end)
	override("get_bone_override", function() return {} end)
	override("set_physics_override", function() end)
	override("get_physics_override", function() return {speed = 1, jump = 1, gravity = 1} end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
	-- The probe player's extra ranks (Bellow beside a Ruin build).
	local talent_rank = grug_classes.talent_rank
	grug_classes.talent_rank = function(player, id)
		local fake = player and fakes[player]
		if fake and fake.extra[id] then return fake.extra[id] end
		return talent_rank(player, id)
	end
end

local function tag_of(obj)
	local ent = obj and obj.get_luaentity and obj:get_luaentity()
	return ent and ent._probe_tag or (obj and obj.get_player_name and obj:get_player_name()) or "?"
end

local function wrap_all()
	grug_core.get_crit_chance = function() return 0 end
	grug_core.get_dodge_chance = function() return 0 end
	local try_cast = grug_abilities.try_cast
	grug_abilities.try_cast = function(user, def, ...)
		local fake = fakes[user]
		local rage = grug_abilities.get_rage(user)
		local ok = try_cast(user, def, ...)
		if fake and ok then
			record("try", ("%s rage %d->%d"):format(def.id, rage, grug_abilities.get_rage(user)))
		end
		return ok
	end
	local begin = grug_core.begin_authoritative_swing
	grug_core.begin_authoritative_swing = function(player, target, tx)
		if fakes[player] then
			record("swing", ("held=%s proc=%s target=%s raw=%.3f scaled=%.3f fpi=%.3f rage=%d"):format(
				player:get_wielded_item():get_name():gsub("^grug_abilities:", ""),
				tx.proc and tx.proc.id or "none", tag_of(target), tx.raw_damage or 0,
				tx.scaled_damage or 0, tx.fpi or 0, grug_abilities.get_rage(player)))
		end
		return begin(player, target, tx)
	end
	local hit = grug_core.run_player_hit_mob
	grug_core.run_player_hit_mob = function(player, ent, damage)
		if player and fakes[player] then
			record("hit", ("%s dmg=%.3f"):format(ent and ent._probe_tag or "?", damage or 0))
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
		if fakes[player] and def.charge then
			record("charge", ("%s %.3f"):format(def.id, grug_abilities.effective_charge(player, def)))
		end
		return reset_charge(player, def)
	end
	local heal = grug_core.heal_player
	grug_core.heal_player = function(healer, target, amount, opts)
		if target and fakes[target] then
			record("heal", ("amount=%.3f no_crit=%s"):format(amount or 0,
				tostring(opts and opts.no_crit == true)))
		end
		return heal(healer, target, amount, opts)
	end
	local absorb = grug_core.add_absorb
	grug_core.add_absorb = function(player, id, amount, duration, ...)
		if fakes[player] then
			record("absorb", ("%s %.3f for %.2f s"):format(id, amount or 0, duration or 0))
		end
		return absorb(player, id, amount, duration, ...)
	end
	local set_status = grug_core.set_status
	grug_core.set_status = function(player, id, def)
		if fakes[player] and id ~= "shield" then
			local mods = def and def.modifiers or {}
			record("status", ("%s armor=%.3f"):format(id, mods.armor or 0))
		end
		return set_status(player, id, def)
	end
	local open_window = grug_classes.open_window
	grug_classes.open_window = function(player, id, def)
		local ok = open_window(player, id, def)
		if fakes[player] then
			record("window", ("%s %s for %.2f s"):format(id, tostring(ok), def and def.duration or 0))
		end
		return ok
	end
	local taunt = grug_core.taunt
	grug_core.taunt = function(ent, player)
		if fakes[player] then record("taunt", tostring(ent and ent._probe_tag)) end
		return taunt(ent, player)
	end
	local slow = grug_mobs.slow
	grug_mobs.slow = function(ent, duration, factor)
		if active then
			record("slow", ("%s %.2f s x%.2f"):format(tostring(ent and ent._probe_tag), duration, factor))
		end
		return slow(ent, duration, factor)
	end
	local stun = grug_mobs.stun
	grug_mobs.stun = function(ent, duration)
		if active then record("stun", ("%s %.2f s"):format(tostring(ent and ent._probe_tag), duration)) end
		return stun(ent, duration)
	end
	local flash = grug_abilities.flash
	grug_abilities.flash = function(player, msg)
		if fakes[player] then record("flash", tostring(msg)) end
		return flash(player, msg)
	end
end

--
-- Arenas: a floor, then stairs or a cave.
--
local function build_arena(index, spec)
	local origin = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
	local minp = vector.offset(origin, -10, -1, -10)
	local maxp = vector.offset(origin, 10, 8, 10)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_stone = core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local solid = y == minp.y
				local dz = z - origin.z
				if spec.stairs and dz >= 2 and dz <= 5 then
					-- Steps of one node up the +z side: height dz - 1.
					solid = solid or y < origin.y + (dz - 1)
				end
				if spec.cave then
					-- Three nodes of air under a stone ceiling; walls 6 nodes out
					-- and a pillar between the caster and "walled".
					local dx = x - origin.x
					solid = solid or y >= origin.y + 3 or math.abs(dx) >= 6 or
						math.abs(dz) >= 7 or (dx == 0 and dz == -4)
				end
				data[area:index(x, y, z)] = solid and c_stone or c_air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
	return origin
end

local function aim(r)
	local ref, fake = r.ref, r.fake
	local eye = vector.offset(ref:get_pos(), 0, 1.625, 0)
	local cb = r.target:get_properties().collisionbox or {0, 0, 0, 0, 1, 0}
	local centre = vector.offset(r.target:get_pos(), 0, (cb[2] + cb[5]) / 2, 0)
	local dir = vector.direction(eye, centre)
	fake.look = dir
	fake.yaw = core.dir_to_yaw(vector.new(0, 0, 1)) -- facing +z, the cone's axis
	fake.pitch = -math.asin(dir.y)
end

local function spawn_dummy(pos, tag)
	local obj = core.add_entity(pos, MOB)
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = LEVEL
	grug_mobs.ensure_init(ent)
	ent._probe_tag = tag
	ent.do_custom = function() return false end
	ent.knock_back = false
	-- A level-60 dummy: the level's derived maximum would cap a huge pool
	-- (mobs_redo clamps health to the object's hp_max), so both are raised
	-- to the engine's limit; the probe deals a few thousand at most.
	ent.temp = ent.temp or {}
	ent.temp.grug_max_asserted = true
	obj:set_properties({hp_max = 65535})
	ent.hp_max, ent.hp_min = 65535, 65535
	ent.health, ent.old_health = 65535, 65535
	return obj
end

local function start_arena(index, spec)
	math.randomseed(5300 + index)
	local origin = build_arena(index, spec)
	local ref = core.add_entity(origin, "grug_probe_r53_warrior:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. spec.name
	local inv = core.create_detached_inventory("grug_probe_r53_warrior_" .. spec.name, {})
	inv:set_size("main", 32)
	inv:set_size("grug_weapon", 1)
	inv:set_size("grug_offhand", 1)
	local fake = {name = name, controls = {}, look = vector.new(0, 0, 1), yaw = 0,
		pitch = 0, holder = ItemStack("grug_abilities:strike"), inv = inv, index = 1,
		extra = spec.extra or {}, huds = 0}
	fakes[ref] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	local meta = ref:get_meta()
	meta:set_string("grug_classes:class", "warrior")
	meta:set_int("grug_xp:xp", grug_xp.xp_for_level(LEVEL))
	local graph = grug_classes.graph
	meta:set_string("grug_classes:talents", graph.serialize(graph.trees[spec.tree].example_ranks))
	if grug_classes.invalidate_talents then grug_classes.invalidate_talents(ref) end
	inv:set_stack("grug_weapon", 1, grug_gear.weapon_item("sword", 1))
	local slots = {}
	for _, phase in ipairs(spec.phases) do
		if not slots[phase.id] then
			local def = grug_abilities.current_form(ref, grug_abilities.registered[phase.id])
			local stack = def and grug_abilities.stack_for(ref, def.id)
			if not stack then log("FAIL " .. spec.name .. ": " .. phase.id .. " is not unlocked") end
			slots[phase.id] = #slots + 1
			slots[#slots + 1] = phase.id
			inv:set_stack("main", slots[phase.id], stack or "")
			log(("%s: slot %d %s -> %s"):format(spec.name, slots[phase.id], phase.id,
				def and def.id or "none"))
		end
		phase.slot = slots[phase.id]
	end
	grug_abilities.add_rage(ref, spec.rage)
	local dummies = {}
	for _, d in ipairs(spec.dummies) do
		dummies[#dummies + 1] = spawn_dummy(vector.offset(origin, d[2], d[3], d[4]), d[1])
	end
	active = {name = spec.name, spec = spec, ref = ref, fake = fake, target = dummies[1],
		dummies = dummies, origin = origin, phase = 1, t0 = core.get_us_time()}
	active.phase_start = active.t0
	fake.index = spec.phases[1].slot
	record("start", ("level=%d rage=%d hp=%d S_unit_raw=%.3f P=%d K=%.1f"):format(
		grug_core.get_player_level(ref), grug_abilities.get_rage(ref), ref:get_hp(),
		grug_abilities.swing_stats(ref) + grug_classes.get_melee_bonus(ref),
		grug_core.base_pool(LEVEL), grug_core.armor_k(LEVEL)))
	record("phase", spec.phases[1].id)
end

local queue = {}
local function finish()
	log(("RESULT DONE records=%d"):format(#lines))
	core.request_shutdown("r53 warrior probe done", false, 0)
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
		record("end", ("rage=%d hp=%d"):format(grug_abilities.get_rage(active.ref),
			active.ref:get_hp()))
		fakes[active.ref] = nil
		active.ref:remove()
		for _, obj in ipairs(active.dummies) do obj:remove() end
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
	if elapsed >= phase.hold + GAP then
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
		if phase.ready_retort then
			-- A hit that took health is fixture-checked (tools/r53_warrior K3);
			-- the probe opens the same window the settled-hit hook opens.
			grug_classes.open_window(r.ref, "retort", {duration = 4, icd = 6, label = "Retort"})
		end
	end
	r.fake.controls = elapsed < phase.hold and {dig = true} or {}
	if not r.ref:get_pos() or not r.target:get_pos() then
		log(("FAIL %s: lost the %s"):format(r.name, r.ref:get_pos() and "dummy" or "player"))
		active = nil
		return
	end
	aim(r)
	grug_abilities.input.step(r.ref)
end)

core.after(2, function()
	local minp = vector.offset(BASE, -12, -2, -12)
	local maxp = vector.offset(BASE, SPACING * #ARENAS + 12, 10, 12)
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			wrap_all()
			for index, spec in ipairs(ARENAS) do queue[#queue + 1] = {index, spec} end
			core.after(0.5, next_arena)
		end)
	end)
end)

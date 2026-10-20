-- Disposable engine probe (Round 53 lane MAGE, plan K13). Never shipped:
-- tools/r53_mage/probe.sh stages it through tools/luanti_headless.sh.
--
-- Built on tools/r52_bench's probe: the "player" is a real, invisible probe
-- entity whose ObjectRef answers the player accessors the skill path reads;
-- everything else is the shipped code on the real engine (try_cast, the kit
-- casts, projectiles, grug_core.area, deal_ability_damage). The probe player
-- is a level-60 Mage with a top caster staff; its talents are the Ember and
-- Rime example builds of talent_graph_mage.lua (the calculator's full
-- builds), answered through talent_rank and get_talent_bonus.
--
-- Three arenas: flat ground, stairs and a cave (three nodes of air under a
-- stone ceiling). Each action casts one skill once at a passive dummy (or the
-- sky) and logs every hit as a coefficient of D, the untalented Spark hit
-- spell_base + Int/10, beside the calculator's value, plus the area anchors,
-- the delayed impacts with their fall height, the effects and the cues.

local P = "[r53_mage] "
local MOB = "grug_mobs:bandit"
local BASE = vector.new(640, 300, 640)
local SPACING = 48

local function log(msg) core.log("action", P .. msg) end

local graph = grug_classes.graph
local function build(tree)
	if not tree then return {} end
	return graph.apply_order("mage", graph.trees[tree].example, 30)
end
local function sums(ranks)
	local out = {}
	for id, rank in pairs(ranks) do
		for key, values in pairs(graph.nodes[id].effects or {}) do
			out[key] = (out[key] or 0) + values[rank]
		end
	end
	return out
end

-- The calculator (r52/calc data-mage.json, the stored tuning/mage_rime):
-- per build, the damage of each skill in D.
local CALC = {
	none = {fiery_spark = 1.0, ice_wave = 0.25},
	ember = {fiery_spark = 1.2, fireball = 2.10, fireball_splash = 0.36, flame_lance = 2.97,
		meteor = 1.68, fire_rain = 3.0, ice_wave = 0.25},
	rime = {cold_spark = 1.09, cold_spark_shocked = 1.84, ice_nova = 0.65, winter_field = 1.0},
}

-- Arena layouts relative to the arena origin (floor top at origin.y).
-- Actions: {build, skill, at = "mob1"|"sky", pos = caster offset, note}.
local ARENAS = {
	{name = "flat", mobs = {{0, 0, 5}, {1.2, 0, 6}}, actions = {
		{"none", "fiery_spark"}, {"none", "ice_wave", pos = {0, 0, 3}},
		{"ember", "fiery_spark"}, {"ember", "fireball"}, {"ember", "flame_lance"},
		{"ember", "meteor"}, {"ember", "fire_rain"}, {"ember", "ice_wave", pos = {0, 0, 3}},
		{"ember", "meteor", at = "sky", note = "aimed at the sky"},
		{"rime", "cold_spark"}, {"rime", "ice_nova", pos = {0, 0, 3}},
		{"rime", "cold_spark", note = "inside Cold Shock", key = "cold_spark_shocked", gap = 1.2},
		{"rime", "rime_mantle"}, {"rime", "winter_field"}, {"rime", "blink"},
	}},
	{name = "stairs", stairs = true, mobs = {{0, 2, 6}, {0, 3, 8}}, actions = {
		{"ember", "meteor"}, {"ember", "fire_rain"}, {"rime", "winter_field"},
		{"ember", "ice_wave", pos = {0, 1, 3.5}}, {"rime", "ice_nova", pos = {0, 1, 3.5}},
	}},
	{name = "cave", cave = true, mobs = {{0, 0, 5}, {1.2, 0, 7}}, actions = {
		{"ember", "meteor"}, {"ember", "fire_rain"}, {"rime", "winter_field"},
		{"ember", "ice_wave", pos = {0, 0, 3}}, {"rime", "ice_nova", pos = {0, 0, 3}},
	}},
}
local GAP = 2.0

core.register_entity("grug_probe_r53_mage:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 1000, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

--
-- The probe player (tools/r22_ability_punch, r52_bench).
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
	override("get_player_control", function() return {} end)
	override("get_player_control_bits", function() return 0 end)
	override("get_look_dir", function(f) return vector.copy(f.look) end)
	override("get_look_horizontal", function(f) return f.yaw end)
	override("get_look_vertical", function(f) return f.pitch end)
	override("get_meta", function(f) return f.holder:get_meta() end)
	override("get_inventory", function(f) return f.inv end)
	override("get_wield_list", function() return "main" end)
	override("get_wield_index", function() return 1 end)
	override("get_wielded_item", function(f) return f.inv:get_stack("main", 1) end)
	override("set_wielded_item", function(f, stack) return f.inv:set_stack("main", 1, stack) end)
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
	local bonus = grug_classes.get_talent_bonus
	grug_classes.get_talent_bonus = function(player, key)
		local fake = player and fakes[player]
		if not fake then return bonus(player, key) end
		local total = fake.bonus[key] or 0
		if total ~= 0 and graph.LEVEL_SCALED_KEYS[key] then
			return graph.level_amount(key, total, 60)
		end
		return total
	end
end

--
-- The log around the shipped calls.
--
local current -- {arena, build, skill, key, t0, fx = {}}
local function D(ref)
	return grug_abilities.spell_base(ref) + grug_classes.get_spell_power_bonus(ref)
end
local function wrap_all(ref)
	grug_core.get_crit_chance = function() return 0 end
	grug_core.get_dodge_chance = function() return 0 end
	local deal = grug_core.deal_ability_damage
	grug_core.deal_ability_damage = function(attacker, target, amount, opts)
		local result = deal(attacker, target, amount, opts)
		if current and fakes[attacker] then
			local key = current.key
			if current.skill == "fireball" and current.hits > 0 then key = "fireball_splash" end
			current.hits = current.hits + 1
			local calc = CALC[current.build] and CALC[current.build][key]
			local ent = target:get_luaentity()
			log(("HIT %s %s/%s %s target=%s raw=%.2f coef=%.3f calc=%s scaled=%d t=%.2f"):format(
				current.arena, current.build, current.skill, current.note or "",
				ent and ent._probe_tag or "?", amount, amount / D(attacker),
				calc and ("%.3f"):format(calc) or "-", result or 0,
				(core.get_us_time() - current.t0) / 1e6))
		end
		return result
	end
	local area = grug_core.area
	local anchor = area.anchor
	area.anchor = function(player, range, opts)
		local at, target = anchor(player, range, opts)
		if current and fakes[player] then
			log(("ANCHOR %s %s range=%g -> %s target=%s"):format(current.arena, current.skill,
				range, at and core.pos_to_string(at, 2) or tostring(target),
				type(target) == "userdata" and "enemy" or "-"))
		end
		return at, target
	end
	local delayed = area.delayed
	area.delayed = function(caster, spec)
		if current and fakes[caster] then
			log(("DELAYED %s %s radius=%g delay=%g fall_height=%.2f warning=%s fall=%s burst=%s"):format(
				current.arena, current.skill, spec.radius, spec.delay,
				area.fall_height(spec.anchor, spec.radius), tostring(spec.warning or "area_warning"),
				tostring(spec.fall), tostring(spec.burst)))
		end
		return delayed(caster, spec)
	end
	local play = grug_core.particles.play
	grug_core.particles.play = function(id, frame)
		if current then current.fx[#current.fx + 1] = id end
		return play(id, frame)
	end
	local sound = grug_sounds.play
	grug_sounds.play = function(event, target)
		if current then current.fx[#current.fx + 1] = "sound:" .. event end
		return sound(event, target)
	end
	local absorb = grug_core.add_absorb
	grug_core.add_absorb = function(player, id, amount, duration, ...)
		if current and fakes[player] then
			log(("ABSORB %s %s amount=%.1f (%.3f P) duration=%g"):format(current.arena, id,
				amount, amount / grug_core.base_pool(60), duration))
		end
		return absorb(player, id, amount, duration, ...)
	end
	local status = grug_core.set_status
	grug_core.set_status = function(player, id, def)
		if current and fakes[player] and def and def.modifiers and def.modifiers.armor then
			log(("STATUS %s %s armor=%.2f (%.3f K) duration=%s"):format(current.arena, id,
				def.modifiers.armor, def.modifiers.armor / grug_core.armor_k(60),
				tostring(def.duration)))
		end
		return status(player, id, def)
	end
	local slow = grug_mobs.slow
	grug_mobs.slow = function(ent, duration, factor)
		if current then
			log(("SLOW %s %s %s factor=%.2f for %g s"):format(current.arena, current.skill,
				ent._probe_tag or "?", factor, duration))
		end
		return slow(ent, duration, factor)
	end
	local root = grug_mobs.root
	grug_mobs.root = function(ent, duration)
		if current then
			log(("ROOT %s %s %s for %g s"):format(current.arena, current.skill,
				ent._probe_tag or "?", duration))
		end
		return root(ent, duration)
	end
	local _ = ref
end

--
-- Arenas: flat stone, stairs (one node up every two along +z from z = 3),
-- a cave (air from the floor up three nodes, a stone ceiling and walls).
--
local function build_arena(origin, spec)
	local minp = vector.offset(origin, -8, -1, -4)
	local maxp = vector.offset(origin, 8, 14, 16)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local va = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_stone = core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				local rel = {x = x - origin.x, y = y - origin.y, z = z - origin.z}
				local solid = rel.y < 0
				if spec.stairs and rel.z >= 3 then
					solid = rel.y < math.floor((rel.z - 3) / 2) + 1
				end
				if spec.cave then
					solid = rel.y < 0 or rel.y >= 3 or math.abs(rel.x) >= 7 or
						rel.z <= -3 or rel.z >= 15
				end
				data[va:index(x, y, z)] = solid and c_stone or c_air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

local function spawn_dummy(pos, tag)
	local obj = core.add_entity(pos, MOB)
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = 60
	grug_mobs.ensure_init(ent)
	ent.do_custom = function() return false end
	ent.knock_back = false
	ent.hp_max, ent.hp_min = 1000000, 1000000
	ent.health, ent.old_health = 1000000, 1000000
	ent._probe_tag = tag
	return obj
end

local function aim_at(fake, ref, point)
	local eye = vector.offset(ref:get_pos(), 0, ref:get_properties().eye_height or 1.625, 0)
	local dir = vector.direction(eye, point)
	fake.look, fake.yaw, fake.pitch = dir, core.dir_to_yaw(dir), -math.asin(dir.y)
end

local loaded = {}
local function forceload(origin)
	for _, pos in ipairs(loaded) do core.forceload_free_block(pos, true) end
	loaded = {}
	if not origin then return end
	-- Two block layers: the fall height reads up to 12 nodes above the
	-- floor, and an unloaded node counts as a ceiling.
	for dx = -16, 16, 16 do
		for dy = 0, 16, 16 do
			for dz = -16, 32, 16 do
				local pos = vector.offset(origin, dx, dy, dz)
				if core.forceload_block(pos, true) then loaded[#loaded + 1] = pos end
			end
		end
	end
end

local hero, fake, mobs
local function new_hero(origin)
	local ref = core.add_entity(origin, "grug_probe_r53_mage:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_mage"
	local inv = core.create_detached_inventory("grug_probe_r53_mage", {})
	inv:set_size("main", 32)
	inv:set_size("grug_weapon", 1)
	inv:set_size("grug_offhand", 1)
	local f = {name = name, look = vector.new(0, 0, 1), yaw = 0, pitch = 0,
		holder = ItemStack("grug_abilities:strike"), inv = inv, ranks = {}, bonus = {}, huds = 0}
	fakes[ref] = f
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	ref:get_meta():set_string("grug_classes:class", "mage")
	ref:get_meta():set_int("grug_xp:xp", grug_xp.xp_for_level(60))
	for _, fn in ipairs(core.registered_on_joinplayers) do
		local rec = core.callback_origins[fn]
		if rec and rec.mod == "grug_projectiles" then fn(ref, nil) end
	end
	inv:set_stack("grug_weapon", 1, grug_gear.weapon_item("staff", #grug_gear.MATERIALS))
	return ref, f
end

local function run_action(arena, origin, action, done)
	local ref = hero
	-- A dummy that died anyway (or unloaded) comes back for the next cast.
	for i, offset in ipairs(arena.mobs) do
		local ent = mobs[i]:get_luaentity()
		if not mobs[i]:get_pos() or not ent or (ent.health or 0) <= 0 then
			log(("RESPAWN %s mob%d"):format(arena.name, i))
			if mobs[i]:get_pos() then mobs[i]:remove() end
			mobs[i] = spawn_dummy(vector.offset(origin, offset[1], offset[2], offset[3]),
				"mob" .. i)
		else
			ent.health = 1000000
		end
	end
	fake.ranks = build(action[1] ~= "none" and action[1] or nil)
	fake.bonus = sums(fake.ranks)
	local skill = action[2]
	local pos = action.pos or {0, 0, 0}
	ref:set_pos(vector.offset(origin, pos[1], pos[2], pos[3]))
	grug_abilities.restore_mana(ref, 1000000)
	local def = grug_abilities.registered[skill]
	grug_abilities.clear_cooldown(ref, skill)
	current = {arena = arena.name, build = action[1], skill = skill, key = action.key or skill,
		note = action.note, hits = 0, fx = {}, t0 = core.get_us_time()}
	if action.at == "sky" then
		fake.look, fake.yaw, fake.pitch = vector.new(0, 1, 0), 0, -math.pi / 2
	else
		local mob = mobs[1]
		local cb = mob:get_properties().collisionbox or {0, 0, 0, 0, 1, 0}
		aim_at(fake, ref, vector.offset(mob:get_pos(), 0, (cb[2] + cb[5]) / 2, 0))
	end
	local refusal
	local mana = grug_abilities.get_mana(ref)
	local ok = grug_abilities.try_cast(ref, def, nil, function(msg) refusal = msg end)
	log(("CAST %s %s/%s %s ok=%s refusal=%s mana_paid=%d (%.2f%% P) unlocked=%s"):format(
		arena.name, action[1], skill, action.note or "", tostring(ok == true), tostring(refusal),
		mana - grug_abilities.get_mana(ref), (mana - grug_abilities.get_mana(ref)) /
			grug_core.base_pool(60) * 100, tostring(grug_abilities.is_unlocked(ref, skill))))
	core.after(action.gap or GAP, function()
		log(("EFFECTS %s %s %s"):format(arena.name, skill, table.concat(current.fx, ",")))
		current = nil
		done()
	end)
end

local function run_arena(index, after)
	local arena = ARENAS[index]
	if not arena then return after() end
	local origin = vector.offset(BASE, (index - 1) * SPACING, 0, 0)
	forceload(origin)
	core.after(3, function()
		if not hero then
			hero, fake = new_hero(origin)
			wrap_all(hero)
			log(("PLAYER level=%d D=%.2f (spell_base %.2f + Int/10 %.2f) P=%d K=%.1f"):format(
				grug_xp.get_level(hero), D(hero), grug_abilities.spell_base(hero),
				grug_classes.get_spell_power_bonus(hero), grug_core.base_pool(60), grug_core.armor_k(60)))
		end
		mobs = {}
		for i, offset in ipairs(arena.mobs) do
			mobs[i] = spawn_dummy(vector.offset(origin, offset[1], offset[2], offset[3]),
				"mob" .. i)
		end
		local step = 0
		local function next_action()
			step = step + 1
			local action = arena.actions[step]
			if not action then
				for _, m in ipairs(mobs) do m:remove() end
				return run_arena(index + 1, after)
			end
			run_action(arena, origin, action, next_action)
		end
		log("ARENA " .. arena.name .. " at " .. core.pos_to_string(origin))
		next_action()
	end)
end

core.after(2, function()
	local minp = vector.offset(BASE, -8, -1, -4)
	local maxp = vector.offset(BASE, SPACING * #ARENAS + 8, 14, 16)
	log("emerging " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			for index, arena in ipairs(ARENAS) do
				build_arena(vector.offset(BASE, (index - 1) * SPACING, 0, 0), arena)
			end
			run_arena(1, function()
				forceload(nil)
				log("RESULT DONE")
				core.request_shutdown("r53 mage probe done", false, 0)
			end)
		end)
	end)
end)

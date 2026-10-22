-- Disposable engine probe (Round 56 lane MOBAI). Never shipped:
-- tools/r56_mobai/probe.sh stages it through tools/luanti_headless.sh.
--
-- A flat stone platform high above a deep-ocean column, force-loaded, night.
--   A  ranged: a probe player 22 m from a Skeleton Archer on clear ground
--      hits it once (as the playtest's Elf Mage did); the archer must close
--      in to its shot range and its arrows must reach the player. Logged
--      every half second: distance, state, phase, closing flag, velocity,
--      clip; every arrow's lock (granted or refused) and every hit.
--   B  aggro by level: a wolf 10 levels below a probe player 3 m away does
--      not pick the player; moved to 0.9 m it does. A second such wolf, hit
--      by its player, fights back. A control wolf at the player's own level
--      picks its player at 10 m.
-- A headless server has no client, so a "player" is an invisible entity
-- whose ObjectRef answers the player accessors (tools/r51_mobs). The mob
-- code is the shipped code. Lines "[r56mobai] ...", "RESULT PASS".

local P = "[r56mobai] "
local BASE_Y = 300
local SIZE_X, SIZE_Z = 64, 56
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
local function fmt(p)
	return p and ("(%.1f,%.1f,%.1f)"):format(p.x, p.y, p.z) or "nil"
end

--
-- Probe players (tools/r51_mobs).
--
local hits = {} -- player name -> {arrow = n, melee = n}
core.register_entity("grug_probe_r56_mobai:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	-- A hit is counted, never taken: the probe player stays.
	on_punch = function(self, puncher)
		local name = self._probe_name
		local le = puncher and puncher:get_luaentity()
		if name and le then
			local h = hits[name]
			if le.name == "grug_mobs:arrow_entity" then h.arrow = h.arrow + 1
			else h.melee = h.melee + 1 end
		end
		return true
	end,
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
	override("set_wielded_item", function(f, stack) return f.inv:set_stack("main", 1, stack) end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
end

local function make_player(label, pos, level)
	local ref = core.add_entity(pos, "grug_probe_r56_mobai:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_r56_" .. label, {})
	inv:set_size("main", 8)
	local holder = ItemStack("default:stick")
	fakes[ref] = {name = name, holder = holder, inv = inv}
	by_name[name] = ref
	ref:get_luaentity()._probe_name = name
	hits[name] = {arrow = 0, melee = 0}
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	-- The level through the real XP store (grug_xp.get_level reads it).
	holder:get_meta():set_int("grug_xp:xp", grug_xp.xp_for_level(level))
	return ref
end

local function spawn(name, pos, level)
	local obj = core.add_entity(pos, name)
	assert(obj, name .. " was not added at " .. fmt(pos))
	local ent = obj:get_luaentity()
	ent.lifetimer = 20000 -- never despawn during the run
	grug_mobs.ensure_init(ent)
	if level then grug_mobs.relevel(ent, level) end
	return obj, ent
end

-- Keeps a fight going as if the player kept hitting (the ambient pursuit
-- clock, aggro.lua, ends a fight 15 s after the last incoming damage).
local function sustain(ent)
	if ent and ent.temp and ent.attack then ent.temp.grug_damage_at = grug_core.mono_time() end
end

local origin
local function at(x, z) return vector.new(origin.x + x, BASE_Y + 1, origin.z + z) end

local function build_platform()
	local minp = vector.new(origin.x, BASE_Y, origin.z)
	local maxp = vector.new(origin.x + SIZE_X - 1, BASE_Y + 16, origin.z + SIZE_Z - 1)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local air, stone = core.get_content_id("air"), core.get_content_id("default:stone")
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y == BASE_Y and stone or air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
	return minp, maxp
end

-- Every lock of a mob arrow, granted or refused, with the distance.
local locks = {granted = 0, refused = 0}
local function watch_locks()
	local real = grug_core.actor_projectile_lock
	grug_core.actor_projectile_lock = function(owner, target, origin_pos, speed, range, ...)
		local lock = real(owner, target, origin_pos, speed, range, ...)
		local a, b = owner and owner:get_pos(), target and target:get_pos()
		local d = a and b and vector.distance(a, b) or -1
		if lock then locks.granted = locks.granted + 1 else locks.refused = locks.refused + 1 end
		log(("lock %s at %.1f m (range %.1f)"):format(lock and "granted" or "REFUSED", d, range))
		return lock
	end
end

--
-- Scenario A: the archer.
--
local A = {}
local function start_a()
	A.player = make_player("mage", at(27, 8), 1)
	A.obj, A.ent = spawn("grug_mobs:skeleton_archer", at(5, 8))
	-- The player at the archer's level (no level rule in the way).
	A.player:get_meta():set_int("grug_xp:xp", grug_xp.xp_for_level(math.min(A.ent._grug_level, 60)))
	A.ent.order = "stand" -- no idle wander before the hit
	A.min = math.huge
end
local function hit_a()
	local d = vector.distance(A.obj:get_pos(), A.player:get_pos())
	A.ent.order = ""
	local dealt = grug_core.deal_ability_damage(A.player, A.obj, 1)
	log(("A the mage hits the archer (level %d) from %.1f m: dealt %s, state %s"):format(
		A.ent._grug_level, d, tostring(dealt), tostring(A.ent.state)))
	if A.ent.attack ~= A.player then
		log("A the hit did not set the target; do_attack as the hit's retaliation")
		A.ent:do_attack(A.player)
	end
	A.hit_t = A.t
end
local function sample_a(t)
	local pos = A.obj:get_pos()
	if not pos then return end
	local d = vector.distance(pos, A.player:get_pos())
	if d < A.min then A.min = d end
	if d <= mobs.grug_shot_range(A.ent) and not A.inside_t then A.inside_t = t end
	local v = A.obj:get_velocity() or vector.new(0, 0, 0)
	log(("A t=%.1f dist %.1f state %s phase %s closing %s speed %.1f clip %s arrows-hit %d"):format(
		t, d, tostring(A.ent.state), tostring(A.ent.dogshoot_switch),
		tostring(A.ent.temp and A.ent.temp.grug_closing), vector.length(vector.new(v.x, 0, v.z)),
		tostring(A.ent.animation_current), hits.probe_mage.arrow))
end

--
-- Scenario B: aggro by level.
--
local B = {}
local function start_b()
	B.low = make_player("high", at(33, 40), 30)
	B.wolf, B.went = spawn("grug_mobs:wolf", at(30, 40), 20)
	B.hitter = make_player("hitter", at(61, 40), 30)
	B.wolf2, B.went2 = spawn("grug_mobs:wolf", at(58, 40), 20)
	B.even = make_player("even", at(55, 20), 20)
	B.wolf3, B.went3 = spawn("grug_mobs:wolf", at(55, 10), 20)
	for _, e in ipairs({B.went, B.went2, B.went3}) do
		e.order = "stand"
		e.walk_chance = 0
	end
	log(("B wolves at levels %d/%d/%d, players at %d/%d/%d"):format(B.went._grug_level,
		B.went2._grug_level, B.went3._grug_level, grug_core.get_player_level(B.low),
		grug_core.get_player_level(B.hitter), grug_core.get_player_level(B.even)))
end
local function check_b_first()
	local d1 = vector.distance(B.wolf:get_pos(), B.low:get_pos())
	local d2 = vector.distance(B.wolf2:get_pos(), B.hitter:get_pos())
	local d3 = vector.distance(B.wolf3:get_pos(), B.even:get_pos())
	check(B.went.attack == nil, ("B1 a wolf 10 levels below does not pick the player at %.1f m (state %s)"):format(
		d1, tostring(B.went.state)))
	check(B.went2.attack == nil, ("B2 nor the second one at %.1f m"):format(d2))
	check(B.went3.attack == B.even, ("B3 control: a wolf at the player's level picks it at %.1f m"):format(d3))
	-- Move the first player to 0.9 m; hit the second wolf.
	local wp = B.wolf:get_pos()
	B.low:set_pos(vector.new(wp.x + 0.9, wp.y, wp.z))
	local dealt = grug_core.deal_ability_damage(B.hitter, B.wolf2, 1)
	log(("B the hitter hits wolf 2 from %.1f m: dealt %s, state %s"):format(d2, tostring(dealt),
		tostring(B.went2.state)))
	B.hit_attack = B.went2.attack
end
local function check_b_second()
	local d1 = vector.distance(B.wolf:get_pos(), B.low:get_pos())
	check(B.went.attack == B.low, ("B4 at %.1f m it picks the player"):format(d1))
	check(B.hit_attack == B.hitter and B.went2.attack == B.hitter,
		"B5 the hit wolf fights back against its hitter")
end

--
-- Driver
--
local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("r56 mobai probe done", false, 0)
end

local RUN_SECONDS = 32
local function run_all()
	core.set_timeofday(0)
	watch_locks()
	start_a()
	start_b()
	local t, acc, running = 0, 0, true
	A.t = 0
	core.register_globalstep(function(dtime)
		if not running then return end
		t = t + dtime
		A.t = t
		acc = acc + dtime
		core.set_timeofday(0)
		if t >= 1 and not A.hit_t then hit_a() end
		sustain(A.ent)
		sustain(B.went3)
		if B.went.attack then sustain(B.went) end
		if B.went2.attack then sustain(B.went2) end
		if t >= 7 and not B.first then
			B.first = true
			check_b_first()
		end
		if t >= 12 and not B.second then
			B.second = true
			check_b_second()
		end
		if acc >= 0.5 then
			acc = 0
			sample_a(t)
		end
		if t >= RUN_SECONDS then
			running = false
			local range = mobs.grug_shot_range(A.ent)
			log(("A summary: shot range %.1f, closest %.1f m, inside the shot range after %s s, "
				.. "arrows hit %d, melee hits %d, locks granted %d, refused %d"):format(range, A.min,
				A.inside_t and ("%.1f"):format(A.inside_t - (A.hit_t or 0)) or "never",
				hits.probe_mage.arrow, hits.probe_mage.melee, locks.granted, locks.refused))
			check(A.inside_t ~= nil and A.inside_t - A.hit_t <= 10,
				"A1 the archer reaches its shot range within 10 s of the hit")
			check(hits.probe_mage.arrow >= 1, "A2 its arrows reach the player")
			check(locks.granted >= 1, "A3 its shots are locked")
			finish()
		end
	end)
end

-- A deep-ocean column on a coarse grid: open sea, nothing below the platform.
local function find_origin()
	for r = 0, 40 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 256, c[2] * 256
				local ok = true
				for _, d in ipairs({{0, 0}, {SIZE_X, 0}, {0, SIZE_Z}, {SIZE_X, SIZE_Z}}) do
					if grug_zones.water_class_at(x + d[1], z + d[2]) ~= "deep_ocean" then
						ok = false
						break
					end
				end
				if ok then return vector.new(x, 0, z) end
			end
		end
	end
end

core.after(2, function()
	origin = find_origin()
	if not check(origin ~= nil, "found a deep-ocean column for the platform") then
		return finish()
	end
	local minp = vector.new(origin.x, BASE_Y, origin.z)
	local maxp = vector.new(origin.x + SIZE_X - 1, BASE_Y + 16, origin.z + SIZE_Z - 1)
	log("platform " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
		for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1)
			end
		end
	end
	core.emerge_area(vector.offset(minp, -16, -16, -16), vector.offset(maxp, 16, 16, 16),
		function(_, _, remaining)
			if remaining > 0 then return end
			core.after(0, function()
				build_platform()
				core.after(1, run_all)
			end)
		end)
end)

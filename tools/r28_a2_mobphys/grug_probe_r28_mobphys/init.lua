-- Disposable engine probe (Round 28 Lane A2). Never shipped:
-- tools/r28_a2_mobphys/run.sh stages it through tools/luanti_headless.sh.
--
-- A stone arena high above deep ocean, forceloaded, on the real mobs_redo AI
-- with the vendored GRUG PATCHes (the api.lua side the portable test cannot
-- load). Every mob is set to level 30 (764 HP for the normal tier) so that
-- percent and flat amounts are far apart.
--   lava   a normal wolf in a lava pool loses whole multiples of 20 % per
--          tick (vanilla: 4); an elite wolf multiples of 10 %; the King of
--          Highcourt (elite tier, immune) nothing;
--   sun    a zombie at noon loses whole multiples of 5 % per tick (vanilla 2);
--   fall   a wolf dropped 10 nodes takes ceil(hp_max * (d - 6) / 20);
--   sep    two zombies spawned on one spot and set on one dummy target end up
--          apart (no overlap) and outside the target's column.
-- Player hits (knockback, no pause) need a client and are covered by the
-- portable test plus code reading.

local P = "[r28_mobphys_probe] "
local WATCH = 3.4 -- seconds of environment ticks (about three)
local SEP_SECONDS = 8
local LEVEL = 30
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

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r28 mobphys probe done", false, 0)
end

local ARENA = 64
local FLOOR_Y = 300
local origin

local function find_origin()
	for r = 0, 40 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 256, c[2] * 256
				local ok = true
				for _, d in ipairs({{0, 0}, {ARENA, 0}, {0, ARENA}, {ARENA, ARENA}}) do
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

local function arena_bounds()
	return vector.new(origin.x, FLOOR_Y - 2, origin.z),
		vector.new(origin.x + ARENA - 1, FLOOR_Y + 20, origin.z + ARENA - 1)
end

-- Lava pools: 17 x 17 sources, three deep, inside a stone rim, centres
-- listed here (relative to origin). No land within 7 nodes of a centre, so
-- the mobs_redo escape search finds nothing to climb out to, and a mob that
-- floats up still has its feet in lava.
local POOLS = {{x = 12, z = 12}, {x = 12, z = 34}, {x = 34, z = 12}}

local function build_arena()
	local minp, maxp = arena_bounds()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local stone = core.get_content_id("default:stone")
	local lava = core.get_content_id("default:lava_source")
	local air = core.get_content_id("air")
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				data[area:index(x, y, z)] = y <= FLOOR_Y and stone or air
			end
		end
	end
	for _, pool in ipairs(POOLS) do
		for dz = -9, 9 do
			for dx = -9, 9 do
				local rim = math.abs(dx) == 9 or math.abs(dz) == 9
				for y = FLOOR_Y + 1, FLOOR_Y + 4 do
					data[area:index(origin.x + pool.x + dx, y, origin.z + pool.z + dz)] =
						rim and stone or (y <= FLOOR_Y + 3 and lava or air)
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

core.register_entity("grug_probe_r28_mobphys:dummy", {
	initial_properties = {
		physical = true, static_save = false, hp_max = 1000,
		visual = "cube", textures = {"default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3},
	},
	on_punch = function() return true end,
})

local function at(dx, y, dz)
	return vector.new(origin.x + dx, y, origin.z + dz)
end

-- Spawn at level LEVEL with an optional tier; the level is set before the
-- first tick, so ensure_init takes the reactivation path and derives the
-- level-30 pool. Health is topped up once that pool exists.
local function spawn(name, pos, tier)
	local obj = core.add_entity(pos, name)
	if not check(obj ~= nil, "spawned " .. name) then return end
	local ent = obj:get_luaentity()
	ent._grug_level = LEVEL
	ent._grug_tier = tier
	return {name = name, obj = obj, ent = ent, spawn = pos, tier = tier}
end

local function top_up(rec)
	local ent = rec.obj:get_luaentity()
	if not ent then return end
	ent.health = ent.hp_max
	rec.h0 = ent.health
	rec.hp_max = ent.hp_max
end

local function percent_share(hp_max, percent, scale)
	return math.max(1, math.ceil(hp_max * percent * scale / 100))
end

local function check_multiple(rec, label, share)
	local ent = rec.obj:get_luaentity()
	local health = ent and ent.health or 0
	local drop = (rec.h0 or 0) - health
	local ticks = share > 0 and drop / share or 0
	log(("%s: hp_max %s, drop %s, share %s, ticks %.2f"):format(label,
		tostring(rec.hp_max), tostring(drop), tostring(share), ticks))
	check(drop > 0 and ticks == math.floor(ticks) and ticks <= 4,
		label .. ": whole multiples of the share")
end

local function env_phase(done)
	core.set_timeofday(0.5)
	local wolf = spawn("grug_mobs:wolf", at(POOLS[1].x, FLOOR_Y + 1, POOLS[1].z),
		"normal")
	local elite = spawn("grug_mobs:wolf", at(POOLS[2].x, FLOOR_Y + 1, POOLS[2].z),
		"elite")
	local king = spawn("grug_mobs:king_human",
		at(POOLS[3].x, FLOOR_Y + 1, POOLS[3].z))
	local zombie = spawn("grug_mobs:zombie", at(56, FLOOR_Y + 1, 56), "normal")
	local faller = spawn("grug_mobs:wolf", at(56, FLOOR_Y + 11, 34), "normal")
	core.after(0.5, function()
		for _, rec in ipairs({wolf, elite, king, zombie, faller}) do
			if rec then top_up(rec) end
		end
		if faller then
			local ent = faller.obj:get_luaentity()
			faller.old_y = ent and ent.old_y
		end
	end)
	core.after(0.5 + WATCH, function()
		if wolf and wolf.hp_max then
			check_multiple(wolf, "lava normal wolf",
				percent_share(wolf.hp_max, 20, 1))
		end
		if elite and elite.hp_max then
			check_multiple(elite, "lava elite wolf",
				percent_share(elite.hp_max, 20, 0.5))
			check(elite.hp_max > (wolf and wolf.hp_max or 0),
				"elite pool larger than the normal one")
		end
		if king and king.hp_max then
			local ent = king.obj:get_luaentity()
			local in_lava = ent and ent.standing_in
			log("king standing_in " .. tostring(in_lava) .. ", hp " ..
				tostring(ent and ent.health) .. "/" .. tostring(king.hp_max))
			check(in_lava == "default:lava_source", "king stands in lava")
			check(ent and ent.health == king.h0, "king in lava: immune")
		end
		if zombie and zombie.hp_max then
			local light = core.get_node_light(zombie.obj:get_pos())
			log("zombie light " .. tostring(light))
			check_multiple(zombie, "sun zombie", percent_share(zombie.hp_max, 5, 1))
		end
		if faller and faller.hp_max then
			local ent = faller.obj:get_luaentity()
			local pos = faller.obj:get_pos()
			local start_y = faller.spawn.y
			local d = pos and (start_y - pos.y) or 0
			local drop = faller.h0 - (ent and ent.health or 0)
			local expected = math.ceil(faller.hp_max * (d - 6) / 20)
			log(("fall: d %.2f, drop %s, expected %s (vanilla %d)"):format(d,
				tostring(drop), tostring(expected), math.ceil(d - 6)))
			check(math.abs(drop - expected) <= math.ceil(faller.hp_max / 20 * 0.2) + 1,
				"fall damage ceil(hp_max * (d - 6) / 20)")
			check(drop > math.ceil(d - 6) * 5, "fall damage far above the flat vanilla value")
		end
		for _, rec in ipairs({wolf, elite, king, zombie, faller}) do
			if rec and rec.obj:get_pos() then rec.obj:remove() end
		end
		done()
	end)
end

-- `control`: the same pair with grug_mobs.separation_step switched off, as
-- the before/after comparison.
local function sep_phase(done, control, dz0)
	local saved = grug_mobs.separation_step
	if control then grug_mobs.separation_step = function() end end
	local label = control and "control (separation off)" or "separation"
	local target_pos = at(34, FLOOR_Y + 1, dz0 + 8)
	local dummy = core.add_entity(target_pos, "grug_probe_r28_mobphys:dummy")
	-- Zombies at midnight: wolves break off into pack flight, and the sun
	-- would burn a zombie at noon.
	core.set_timeofday(0)
	local a = spawn("grug_mobs:zombie", at(34, FLOOR_Y + 1, dz0), "normal")
	local b = spawn("grug_mobs:zombie", at(34.05, FLOOR_Y + 1, dz0), "normal")
	if not (dummy and a and b) then
		check(false, "separation setup")
		return done()
	end
	a.ent:do_attack(dummy, true)
	b.ent:do_attack(dummy, true)
	local min_gap, samples, inside = math.huge, 0, 0
	local elapsed = 0
	local running = true
	core.register_globalstep(function(dtime)
		if not running then return end
		elapsed = elapsed + dtime
		local pa, pb = a.obj:get_pos(), b.obj:get_pos()
		if not (pa and pb) then
			running = false
			check(false, label .. ": both zombies alive")
			grug_mobs.separation_step = saved
			if dummy:get_pos() then dummy:remove() end
			return done()
		end
		local ea, eb = a.obj:get_luaentity(), b.obj:get_luaentity()
		local states = tostring(ea and ea.state) .. "/" .. tostring(eb and eb.state)
		if states ~= a.last_states then
			a.last_states = states
			log(("t %.2f states %s, a %s b %s"):format(elapsed, states,
				core.pos_to_string(pa, 2), core.pos_to_string(pb, 2)))
		end
		if elapsed > SEP_SECONDS - 2 then
			samples = samples + 1
			local dx, dz = pa.x - pb.x, pa.z - pb.z
			min_gap = math.min(min_gap, math.sqrt(dx * dx + dz * dz))
			for _, p in ipairs({pa, pb}) do
				local tx, tz = p.x - target_pos.x, p.z - target_pos.z
				if math.sqrt(tx * tx + tz * tz) < 0.6 then inside = inside + 1 end
			end
		end
		if elapsed >= SEP_SECONDS then
			running = false
			local ea, eb = a.obj:get_luaentity(), b.obj:get_luaentity()
			log(("%s: last 2 s min gap %.2f over %d samples, column" ..
				" intrusions %d, states %s/%s"):format(label, min_gap, samples, inside,
				tostring(ea and ea.state), tostring(eb and eb.state)))
			check(ea and eb and ea.state == "attack" and eb.state == "attack",
				label .. ": both zombies still engaged")
			if control then
				check(min_gap < 0.55, label .. ": the pair stays overlapped")
			else
				check(min_gap >= 0.55,
					label .. ": engaged zombies no longer overlap (radius sum 0.6)")
				check(inside == 0, label .. ": no zombie inside the target's column")
			end
			grug_mobs.separation_step = saved
			a.obj:remove()
			b.obj:remove()
			dummy:remove()
			done()
		end
	end)
end

core.after(2, function()
	origin = find_origin()
	if not check(origin ~= nil, "found a deep-ocean column for the arena") then
		return finish()
	end
	local minp, maxp = arena_bounds()
	log("arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
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
				build_arena()
				core.after(1, function()
					env_phase(function()
						sep_phase(function()
							sep_phase(finish, false, 42)
						end, true, 50)
					end)
				end)
			end)
		end)
end)

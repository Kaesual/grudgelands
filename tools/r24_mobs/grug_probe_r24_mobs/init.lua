-- Disposable engine probe (Round 24 Lane D). Never shipped:
-- tools/r24_mobs/run.sh stages it through tools/luanti_headless.sh.
--
-- 1. Levels: the installed grug_zones.mob_level_at along each start's line
--    toward the front (1-node steps): start band, band 1 behind, no fall and
--    no jump ahead, band 3 at the front border; the table and border steps
--    are logged (same numbers as tools/r24_mobs/levels_fixture.lua for the
--    same seed), plus the query cost with a cold and a warm border cache.
-- 2. Registry: every registered grug_mobs entity roams at a calm pace; the
--    ranged families roam at 1 and fight at 4.0 without soft de-aggro.
-- 3. Arena high above deep ocean: the real mobs_redo AI on the real engine.
--    Ranged families idle for IDLE_SECONDS: their horizontal speed while idle
--    stays at the calm walk. Free roamers (boar, hyena) stay within the wander
--    radius of their spawn point, and one whose spawn point lies 80 nodes
--    away walks back inside it. Then each ranged mob is set on a dummy target
--    12 m away and must move at its 4.0 combat speed during the melee phase
--    of dogshoot.

local P = "[r24_mobs_probe] "
local IDLE_SECONDS = 90
local COMBAT_SECONDS = 24
local SAMPLE = 0.25
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
	core.request_shutdown("r24 mobs probe done", false, 0)
end

--
-- 1. Levels
--
local STARTS = {
	{race = "dwarf", x = -1800, z = -2550, direction = 1},
	{race = "human", x = 0, z = -2550, direction = 1},
	{race = "elf", x = 1800, z = -2550, direction = 1},
	{race = "undead", x = -1800, z = 2550, direction = -1},
	{race = "orc", x = 0, z = 2550, direction = -1},
	{race = "troll", x = 1800, z = 2550, direction = -1},
}

local function level_at(x, z)
	return grug_zones.mob_level_at({x = x, y = 10, z = z})
end

local function level_test()
	local t0 = core.get_us_time()
	local queries = 0
	for _, start in ipairs(STARTS) do
		local home = grug_zones.id_at(start.x, start.z)
		local previous, border
		for d = -300, 900 do
			local z = start.z + start.direction * d
			local id = grug_zones.id_at(start.x, z)
			local level = level_at(start.x, z)
			queries = queries + 1
			local content = grug_zones.surface_mob_level_at(start.x, z)
			if id == home and content then
				local distance = math.abs(d)
				if distance <= 100 then
					if level ~= 1 then check(false, start.race .. " d " .. d .. ": level 1") end
				elseif distance <= 150 then
					if level ~= 2 then check(false, start.race .. " d " .. d .. ": level 2") end
				elseif d < 0 then
					if level ~= 3 then check(false, start.race .. " d " .. d .. ": band 1 behind") end
				end
				if d > 0 and previous and level and
						(level < previous or level - previous > 1) then
					check(false, ("%s d %d: %d -> %d rises by at most one"):format(
						start.race, d, previous, level))
				end
				if d >= 0 then previous = level or previous end
			elseif d > 0 and previous and id and grug_zones.get(id).level_min > 10 then
				border = {d = d, inside = previous, outside = level}
				break
			end
		end
		local row = {}
		for d = -300, 400, 25 do
			local z = start.z + start.direction * d
			local level = level_at(start.x, z)
			row[#row + 1] = ("%d:%s%s"):format(d, level and tostring(level) or "w",
				grug_zones.id_at(start.x, z) ~= home and "*" or "")
		end
		log(("levels %s %s: %s"):format(start.race, tostring(home), table.concat(row, " ")))
		if check(border ~= nil, start.race .. ": front border found on the start line") then
			log(("border %s: d %d, %d -> %d"):format(start.race, border.d, border.inside,
				border.outside))
			check(border.inside >= 7, start.race .. ": band 3 at the front border")
		end
	end
	local cold = core.get_us_time() - t0
	t0 = core.get_us_time()
	for _, start in ipairs(STARTS) do
		for d = -300, 900 do level_at(start.x, start.z + start.direction * d) end
	end
	local warm = core.get_us_time() - t0
	log(("level query cost: %d queries, cold %.1f us/query, warm %.1f us/query"):format(
		queries, cold / queries, warm / queries))
	check(true, "level scan ran on the installed authority")
end

--
-- 2. Registry audit
--
local RANGED = {"grug_mobs:bandit_archer", "grug_mobs:poacher",
	"grug_mobs:skeleton_archer", "grug_mobs:skeleton_raider", "grug_mobs:frost_stray"}
local BESPOKE_FAST = {["grug_mobs:kraken"] = true, ["grug_mobs:ice_dragon"] = true,
	["grug_mobs:jungle_wyvern"] = true, ["grug_mobs:ice_whelp"] = true,
	["grug_mobs:storm_whelp"] = true}

local function registry_test()
	local fast = {}
	for name, def in pairs(core.registered_entities) do
		if name:sub(1, 10) == "grug_mobs:" and def.walk_velocity and
				def.walk_velocity > grug_mobs.CALM_WALK_MAX then
			fast[#fast + 1] = name .. "=" .. def.walk_velocity
		end
	end
	table.sort(fast)
	log("walk_velocity above the calm cap (hand-set encounter actors): " ..
		(#fast > 0 and table.concat(fast, ", ") or "none"))
	for _, entry in ipairs(fast) do
		local name = entry:match("^(.-)=")
		check(BESPOKE_FAST[name], name .. " above the calm cap is a hand-set encounter actor")
	end
	for _, name in ipairs(RANGED) do
		local def = core.registered_entities[name]
		check(def and def.walk_velocity == 1 and def.run_velocity == 4,
			name .. " roams at 1 and fights at 4.0")
	end
end

--
-- 3. Arena
--
local ARENA = 112
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
		vector.new(origin.x + ARENA - 1, FLOOR_Y + 6, origin.z + ARENA - 1)
end

local function build_arena()
	local minp, maxp = arena_bounds()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local stone = core.get_content_id("default:stone")
	local grass = core.get_content_id("default:dirt_with_grass")
	local air = core.get_content_id("air")
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local wall = x == minp.x or x == maxp.x or z == minp.z or z == maxp.z
			for y = minp.y, maxp.y do
				local id = air
				if y < FLOOR_Y then id = stone
				elseif y == FLOOR_Y then id = grass
				elseif wall and y <= FLOOR_Y + 4 then id = stone end
				data[area:index(x, y, z)] = id
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

core.register_entity("grug_probe_r24_mobs:dummy", {
	initial_properties = {
		physical = true, static_save = false, hp_max = 1000,
		visual = "cube", textures = {"default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png"},
		collisionbox = {-0.4, 0, -0.4, 0.4, 1.8, 0.4},
	},
	on_punch = function() return true end,
})

local tracked = {}
local function spawn(name, dx, dz, role)
	local pos = vector.new(origin.x + ARENA / 2 + dx, FLOOR_Y + 1, origin.z + ARENA / 2 + dz)
	local obj = core.add_entity(pos, name)
	if not check(obj ~= nil, "spawned " .. name) then return end
	local rec = {name = name, obj = obj, ent = obj:get_luaentity(), role = role,
		spawn = pos, idle_max = 0, idle_samples = 0, far = 0, combat_max = 0}
	tracked[#tracked + 1] = rec
	return rec
end

local function horizontal_speed(obj)
	local v = obj:get_velocity()
	if not v then return 0 end
	return math.sqrt(v.x * v.x + v.z * v.z)
end

local function run_arena()
	-- Ranged families along one side, free roamers in the middle.
	for index, name in ipairs(RANGED) do
		spawn(name, -40 + index * 12, -30, "ranged")
	end
	spawn("grug_mobs:boar", -10, 10, "roamer")
	spawn("grug_mobs:hyena", 10, 10, "roamer")
	local returner = spawn("grug_mobs:boar", 40, 40, "returner")
	-- The first do_custom tick records the spawn point; move the returner's
	-- 80 nodes away (diagonal), as if it had wandered off before Round 24.
	core.after(1, function()
		if returner and returner.ent and returner.ent._grug_home then
			local home = vector.new(returner.spawn.x - 56, FLOOR_Y + 1,
				returner.spawn.z - 56)
			returner.ent._grug_home = home
			returner.home = home
			log("returner home moved " .. core.pos_to_string(home))
		end
		for _, rec in ipairs(tracked) do
			if rec.ent and rec.ent._grug_home and not rec.home then
				rec.home = vector.new(rec.ent._grug_home)
			end
		end
	end)

	local elapsed, acc = 0, 0
	local phase = "idle"
	local dummies = {}
	local running = true
	core.register_globalstep(function(dtime)
		if not running then return end
		elapsed = elapsed + dtime
		acc = acc + dtime
		if acc >= SAMPLE then
			acc = acc - SAMPLE
			for _, rec in ipairs(tracked) do
				local ent = rec.obj:get_luaentity()
				local pos = rec.obj:get_pos()
				if ent and pos then
					local speed = horizontal_speed(rec.obj)
					if phase == "idle" and not ent.attack and
							(ent.state == "stand" or ent.state == "walk") then
						if speed > rec.idle_max then rec.idle_max = speed end
						rec.idle_samples = rec.idle_samples + 1
					elseif phase == "combat" and ent.state == "attack" then
						if speed > rec.combat_max then rec.combat_max = speed end
					end
					if rec.home and phase == "idle" then
						local dx, dz = pos.x - rec.home.x, pos.z - rec.home.z
						rec.far = math.sqrt(dx * dx + dz * dz)
						if rec.role == "roamer" and rec.far > (rec.far_max or 0) then
							rec.far_max = rec.far
						end
					end
				end
			end
		end
		if phase == "idle" and elapsed >= IDLE_SECONDS then
			phase = "combat"
			for _, rec in ipairs(tracked) do
				local ent = rec.obj:get_luaentity()
				local pos = rec.obj:get_pos()
				if rec.role == "ranged" and ent and pos then
					local dummy = core.add_entity(vector.offset(pos, 0, 0, 12),
						"grug_probe_r24_mobs:dummy")
					dummies[#dummies + 1] = dummy
					if dummy then ent:do_attack(dummy, true) end
				end
			end
			log("combat phase: ranged mobs set on dummy targets 12 m away")
		elseif phase == "combat" and elapsed >= IDLE_SECONDS + COMBAT_SECONDS then
			running = false
			for _, rec in ipairs(tracked) do
				log(("%s (%s): idle max %.2f m/s over %d samples, combat max %.2f m/s," ..
					" last distance from home %.1f, max %.1f"):format(rec.name, rec.role,
					rec.idle_max, rec.idle_samples, rec.combat_max, rec.far or -1,
					rec.far_max or -1))
				if rec.role == "ranged" then
					check(rec.idle_samples > 0 and rec.idle_max <= 1.3,
						rec.name .. ": roams at the calm walk (idle max " ..
						("%.2f"):format(rec.idle_max) .. ")")
					check(rec.combat_max >= 3.5 and rec.combat_max <= 4.5,
						rec.name .. ": moves at 4.0 in combat (max " ..
						("%.2f"):format(rec.combat_max) .. ")")
				elseif rec.role == "roamer" then
					check((rec.far_max or 0) <= grug_mobs.WANDER_RADIUS + 4,
						rec.name .. ": idle wander stays within the leash radius")
				elseif rec.role == "returner" then
					check((rec.far or 1e9) <= grug_mobs.WANDER_RADIUS + 1,
						rec.name .. ": walked back inside the leash radius")
				end
			end
			for _, dummy in ipairs(dummies) do dummy:remove() end
			finish()
		end
	end)
end

core.after(2, function()
	local ok, err = pcall(level_test)
	check(ok, "level test ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))
	ok, err = pcall(registry_test)
	check(ok, "registry test ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))
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
				core.after(1, run_arena)
			end)
		end)
end)

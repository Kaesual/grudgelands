-- Disposable engine probe (0.53.1 lane SKILLS). Never shipped:
-- tools/r531_skills/probe.sh stages it through tools/luanti_headless.sh.
--
-- One built scene high above the terrain, three parts on a stone floor:
--   query  a ground anchor; bandits in the open, behind a stone wall, on a
--          ledge 3 nodes up behind its edge, and on a pillar 4 nodes up
--   cone   a probe player facing +z; a bandit in the open and one behind a
--          wall, both inside 70 degrees and 5 m
--   group  a probe priest; allies in the open and one behind a wall
-- Everything runs in the step the objects are added (no AI step moves them).
-- Per part the log names who is reached, then times TIMING_CALLS calls of
-- each helper with the shipped filters (valid_target) and logs microseconds
-- per call: the before/after comparison of the line-of-sight removal (same
-- seed, same scene, same probe). "Players" are invisible probe entities
-- answering the player accessors (the r52_core probe's pattern).

local P = "[r531skills] "
local MOB = "grug_mobs:bandit"
local BASE = vector.new(480, 300, 480)
local TIMING_CALLS = 2000
local failures, checks = 0, 0

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		log("FAIL " .. msg)
	end
end

core.register_entity("grug_probe_r531_skills:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	on_punch = function() return true end,
})

-- Probe players: per-object overrides on the shared ObjectRef method table.
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
	override("is_player", function() return true end)
	override("get_player_name", function(f) return f.name end)
	override("get_look_horizontal", function(f) return f.yaw end)
	override("get_look_dir", function(f) return core.yaw_to_dir(f.yaw) end)
	override("get_meta", function(f) return f.holder:get_meta() end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
end

local function make_player(label, class, pos, hp)
	local ref = core.add_entity(pos, "grug_probe_r531_skills:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	fakes[ref] = {name = name, yaw = 0, holder = ItemStack("default:stick")}
	by_name[name] = ref
	ref:get_meta():set_string("grug_classes:class", class)
	ref:get_meta():set_string("grug_factions:faction", "accord")
	if hp then ref:set_hp(hp) end
	return ref
end

local function spawn_mob(feet, label)
	local obj = core.add_entity(feet, MOB)
	local ent = obj and obj:get_luaentity()
	assert(ent, "mob was not added")
	grug_mobs.ensure_init(ent)
	ent._grug_level = 1
	ent.walk_velocity, ent.run_velocity, ent.walk_chance = 0, 0, 0
	ent.jump = false
	obj:set_pos(feet)
	obj:set_velocity(vector.zero())
	ent._probe_label = label
	return obj
end

local function label_of(obj)
	local fake = fakes[obj]
	if fake then return fake.name end
	local ent = obj:get_luaentity()
	return ent and ent._probe_label or "?"
end

local function names(list)
	local out = {}
	for _, obj in ipairs(list) do out[#out + 1] = label_of(obj) end
	table.sort(out)
	return table.concat(out, ",")
end

local function time_calls(label, fn)
	local start = core.get_us_time()
	for _ = 1, TIMING_CALLS do fn() end
	local per = (core.get_us_time() - start) / TIMING_CALLS
	log(("timing %s: %.2f us per call (%d calls)"):format(label, per, TIMING_CALLS))
end

-- Local coordinates: the floor's top is y = 0.5 (stone up to y = 0).
local writes = {}
local function box(origin, x1, y1, z1, x2, y2, z2)
	for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do
		writes[#writes + 1] = vector.offset(origin, x, y, z)
	end end end
end
local Q = BASE
local C = vector.offset(BASE, 24, 0, 0)
local G = vector.offset(BASE, 48, 0, 0)
box(Q, -1, 1, 2, 1, 3, 2)       -- query: a wall 2 m north of the anchor
box(Q, -5, 1, -1, -3, 3, 1)     -- query: a ledge 3 nodes high to the west
box(Q, 0, 1, -3, 0, 4, -3)      -- query: a pillar 4 nodes high to the south
box(C, 0, 1, 2, 2, 3, 2)        -- cone: a wall across the right half
box(G, -2, 1, -3, 2, 3, -3)     -- group: a wall south of the priest

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
				data[area:index(x, y, z)] = y <= BASE.y and c_stone or c_air
			end
		end
	end
	for _, pos in ipairs(writes) do data[area:index(pos.x, pos.y, pos.z)] = c_stone end
	vm:set_data(data)
	vm:write_to_map(true)
end

local function run()
	local area = grug_core.area
	-- query
	local anchor = vector.offset(Q, 0, 0.5, 0)
	local mage = make_player("mage", "mage", vector.offset(Q, 0, 0.5, -8))
	spawn_mob(vector.offset(Q, 2, 0.5, 0), "open")
	spawn_mob(vector.offset(Q, 0, 0.5, 3), "walled")
	spawn_mob(vector.offset(Q, -3.5, 3.5, 0), "ledge")
	spawn_mob(vector.offset(Q, 0, 4.5, -3), "pillar")
	spawn_mob(vector.offset(Q, 1, 0.5, -1), "open2")
	spawn_mob(vector.offset(Q, -1, 0.5, 1), "open3")
	local hostile = grug_abilities.target_filter(mage, "hostile")
	local reach = names(area.query(anchor, {radius = 5, filter = hostile}))
	log("query reaches: " .. reach)
	check(reach == "ledge,open,open2,open3,walled",
		"query: the wall and the ledge edge do not hide; the pillar (+4) is outside the band")
	time_calls("area.query r5", function() area.query(anchor, {radius = 5, filter = hostile}) end)
	-- cone
	local caster = make_player("caster", "mage", vector.offset(C, 0, 0.5, 0))
	spawn_mob(vector.offset(C, -1.5, 0.5, 3), "c_open")
	spawn_mob(vector.offset(C, 1, 0.5, 4), "c_walled")
	spawn_mob(vector.offset(C, 0, 0.5, -2), "c_behind")
	local chostile = grug_abilities.target_filter(caster, "hostile")
	reach = names(area.cone(caster, {radius = 5, angle = 70, filter = chostile}))
	log("cone reaches: " .. reach)
	check(reach == "c_open,c_walled", "cone: the wall does not hide; behind the caster is outside")
	time_calls("area.cone r5 70deg", function()
		area.cone(caster, {radius = 5, angle = 70, filter = chostile})
	end)
	-- group
	local priest = make_player("priest", "priest", vector.offset(G, 0, 0.5, 0), 80)
	make_player("g_open", "warrior", vector.offset(G, 3, 0.5, 0), 40)
	make_player("g_walled", "scout", vector.offset(G, 0, 0.5, -5), 10)
	make_player("g_open2", "mage", vector.offset(G, -3, 0.5, 2), 60)
	local friendly = grug_abilities.target_filter(priest, "friendly")
	reach = names(area.group(priest, {radius = 6, cap = 4, eligible = friendly}))
	log("group reaches: " .. reach)
	check(reach == "probe_g_open,probe_g_open2,probe_g_walled,probe_priest",
		"group: the wall does not hide the ally")
	time_calls("area.group r6 cap4", function()
		area.group(priest, {radius = 6, cap = 4, eligible = friendly})
	end)
	log(("RESULT %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("r531 skills probe done", false, 0)
end

core.after(2, function()
	local minp = vector.offset(BASE, -10, -4, -12)
	local maxp = vector.offset(BASE, 60, 12, 12)
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build(minp, maxp)
			core.after(0.5, function()
				local ok, err = pcall(run)
				if not ok then
					log("FAIL the probe ran (" .. tostring(err) .. ")")
					log("RESULT FAIL")
					core.request_shutdown("r531 skills probe failed", false, 0)
				end
			end)
		end)
	end)
end)

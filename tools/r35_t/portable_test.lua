-- Round 35 Lane T portable test (LuaJIT): the aiming ray through rotated
-- selection boxes (round35-plan.md §2.1, §4.1).
--
--   luajit tools/r35_t/portable_test.lua [repo]
--
-- Loads the REAL grug_core/combat_ray.lua on a fake engine whose raycast
-- behaves like the server's since Luanti 5.12: nodes and unturned boxes are
-- right, a `rotate = true` box is tested unturned (wrong at every yaw but 0).
-- Checks:
--   R  the zombie box and the crocodile box at yaws 0-345 (15 deg steps), rays
--      from eight sides at several heights and offsets: grug_core.aim_raycast
--      hits exactly where the client's turned box is (an independent
--      yaw-only rotation: the model's +z faces (-sin yaw, 0, cos yaw)) and
--      nowhere else, at the client's entry distance; the engine's wrong
--      answer for such a box is never passed on.
--   B  a walkable node in front of the mob blocks (aim_raycast order and the
--      combat ray's "node"), one behind it does not; an object is preferred
--      over a node by one node squared, as the engine sorts.
--   U  an unturned box and a player keep the engine's answer unchanged (same
--      pointed thing); an unpointable or invisible turned mob is not hit;
--      the ray's pointabilities decide for a turned mob as for the engine.
--   C  cost: only objects near the ray read their properties; one candidate
--      query, the engine's own area (the ray's box widened by 5 nodes).
-- Prints "R35 T PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		if failures <= 40 then print("FAIL " .. label) end
	end
	return ok
end

------------------------------------------------------------------------------
-- vector (the subset combat_ray.lua uses).
------------------------------------------------------------------------------
local function vec(x, y, z) return {x = x, y = y, z = z} end
vector = {
	new = vec,
	copy = function(v) return vec(v.x, v.y, v.z) end,
	add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end,
	subtract = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
	multiply = function(a, s) return vec(a.x * s, a.y * s, a.z * s) end,
	length = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
	normalize = function(a)
		local l = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
		return vec(a.x / l, a.y / l, a.z / l)
	end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

------------------------------------------------------------------------------
-- A plain segment/box test for the fake engine and the client truth
-- (independent of combat_ray.lua's): entry t in [0, 1] or nil.
------------------------------------------------------------------------------
local function slab(lo, hi, s, d)
	local t0, t1 = 0, 1
	for i = 1, 3 do
		if math.abs(d[i]) < 1e-12 then
			if s[i] < lo[i] or s[i] > hi[i] then return nil end
		else
			local a, b = (lo[i] - s[i]) / d[i], (hi[i] - s[i]) / d[i]
			if a > b then a, b = b, a end
			t0, t1 = math.max(t0, a), math.min(t1, b)
			if t0 > t1 then return nil end
		end
	end
	return t0
end

-- The client's box: the model turned by yaw around its origin, local +z to
-- (-sin yaw, 0, cos yaw). World offset -> local: the inverse turn.
local function client_entry(box, pos, yaw, from, to)
	local c, s = math.cos(yaw), math.sin(yaw)
	local function into(wx, wy, wz) return {wx * c + wz * s, wy, -wx * s + wz * c} end
	local start = into(from.x - pos.x, from.y - pos.y, from.z - pos.z)
	local d = into(to.x - from.x, to.y - from.y, to.z - from.z)
	return slab({box[1], box[2], box[3]}, {box[4], box[5], box[6]}, start, d)
end

------------------------------------------------------------------------------
-- The fake engine.
------------------------------------------------------------------------------
local objects, nodes = {}, {}
local area_queries, area_volume, property_reads = 0, 0, 0

local function new_object(o)
	o.rot = o.rot or vec(0, 0, 0)
	o.pointable = o.pointable == nil and true or o.pointable
	o.is_visible = o.is_visible == nil and true or o.is_visible
	o.armor = o.armor or {fleshy = 100}
	if o.player then
		o.ent = nil
	else
		-- A mobs_redo mob: its live box in base_selbox, the registered one
		-- behind the metatable (as the engine's prototype).
		local proto = {initial_properties = {selectionbox = o.registered or o.box}}
		proto.__index = proto
		o.ent = setmetatable({name = o.name or "grug_mobs:test", base_selbox = o.base,
			_cmi_is_mob = true, health = 10}, proto)
	end
	function o:get_pos() return vec(self.pos.x, self.pos.y, self.pos.z) end
	function o:get_rotation() return vec(self.rot.x, self.rot.y, self.rot.z) end
	function o:get_luaentity() return self.ent end
	function o:is_player() return self.player == true end
	function o:get_armor_groups() return self.armor end
	function o:get_player_name() return self.player and "other" or "" end
	function o:get_hp() return 20 end
	function o:get_properties()
		property_reads = property_reads + 1
		local b = self.box
		return {selectionbox = {b[1], b[2], b[3], b[4], b[5], b[6], rotate = b.rotate == true},
			pointable = self.pointable, is_visible = self.is_visible}
	end
	objects[#objects + 1] = o
	return o
end

local function engine_hits(from, to, pointabilities)
	local found = {}
	local d = {to.x - from.x, to.y - from.y, to.z - from.z}
	for _, n in ipairs(nodes) do
		local t = slab({n.x - 0.5, n.y - 0.5, n.z - 0.5}, {n.x + 0.5, n.y + 0.5, n.z + 0.5},
			{from.x, from.y, from.z}, d)
		if t then
			found[#found + 1] = {type = "node", under = vec(n.x, n.y, n.z),
				intersection_point = vec(from.x + d[1] * t, from.y + d[2] * t, from.z + d[3] * t),
				_t = t}
		end
	end
	for _, o in ipairs(objects) do
		-- The server's mistake for a rotated box, simplified: the box unturned.
		local b, p = o.box, o.pos
		local t = o.is_visible and slab({b[1], b[2], b[3]}, {b[4], b[5], b[6]},
			{from.x - p.x, from.y - p.y, from.z - p.z}, d)
		local can = o.pointable ~= false
		local rule = pointabilities and pointabilities.objects
		if rule and o.ent and rule[o.ent.name] ~= nil then can = rule[o.ent.name] ~= false end
		if t and can then
			found[#found + 1] = {type = "object", ref = o,
				intersection_point = vec(from.x + d[1] * t, from.y + d[2] * t, from.z + d[3] * t),
				_t = t, _engine = true}
		end
	end
	-- RaycastSort: nearest first, an object preferred by one node squared.
	local length2 = d[1] * d[1] + d[2] * d[2] + d[3] * d[3]
	table.sort(found, function(a, b)
		local da, db = a._t * a._t * length2, b._t * b._t * length2
		if a.type ~= b.type then
			if a.type == "object" then da = da - 1 else db = db - 1 end
		end
		return da < db
	end)
	return found
end

core = {
	raycast = function(from, to, objects_pointable, liquids, pointabilities)
		assert(objects_pointable == true, "aim rays point at objects")
		local list, i = engine_hits(from, to, pointabilities), 0
		return function() i = i + 1; return list[i] end
	end,
	get_objects_in_area = function(minp, maxp)
		area_queries = area_queries + 1
		area_volume = area_volume + (maxp.x - minp.x) * (maxp.y - minp.y) * (maxp.z - minp.z)
		local out = {}
		for _, o in ipairs(objects) do
			local p = o.pos
			if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
					p.z >= minp.z and p.z <= maxp.z then
				out[#out + 1] = o
			end
		end
		return out
	end,
	get_node_or_nil = function(pos)
		for _, n in ipairs(nodes) do
			if n.x == pos.x and n.y == pos.y and n.z == pos.z then return {name = "stone"} end
		end
		return nil
	end,
	registered_nodes = {stone = {walkable = true}},
}
grug_core = {
	get_player_faction = function() return nil end,
}
dofile(ROOT .. "/mods/CORE/grug_core/combat_ray.lua")
assert(type(grug_core.aim_raycast) == "function", "grug_core.aim_raycast")

local function reset()
	objects, nodes = {}, {}
	area_queries, area_volume, property_reads = 0, 0, 0
end

local function all_hits(from, to, pointabilities)
	local out = {}
	for pointed in grug_core.aim_raycast(from, to, false, pointabilities) do
		out[#out + 1] = pointed
	end
	return out
end

local function first_object_hit(from, to, obj)
	for _, p in ipairs(all_hits(from, to)) do
		if p.type == "object" and p.ref == obj then return p end
	end
	return nil
end

------------------------------------------------------------------------------
-- R: zombie and crocodile at every yaw.
------------------------------------------------------------------------------
local ZOMBIE = {-0.45, -0.05, -0.3, 0.45, 1.8, 0.65, rotate = true}
local CROC = {-0.85, -0.05, -2.35, 0.85, 0.55, 1.55, rotate = true}
local BOXES = {{"zombie", ZOMBIE, {0.1, 0.5, 0.9, 1.3, 1.75, 1.95}},
	{"crocodile", CROC, {0.0, 0.3, 0.5, 0.7}}}
local OFFSETS = {-2.5, -1.6, -0.9, -0.5, -0.2, 0, 0.2, 0.5, 0.9, 1.6, 2.5}
local base = vec(10, 5, -20)
local stats = {}
for _, row in ipairs(BOXES) do
	local name, box, heights = row[1], row[2], row[3]
	local st = {hits = 0, misses = 0, wrong = 0, engine_wrong = 0, upper = 0}
	stats[name] = st
	for deg = 0, 345, 15 do
		reset()
		local yaw = math.rad(deg)
		local mob = new_object({name = "grug_mobs:" .. name, pos = base, rot = vec(0, yaw, 0),
			box = box, base = box})
		-- Rays from eight sides, 4 nodes out, level and slightly falling,
		-- passing the axis at an offset across the ray.
		for side = 0, 7 do
			local a = side * math.pi / 4
			local ax, az = math.cos(a), math.sin(a)
			for _, h in ipairs(heights) do
				for _, off in ipairs(OFFSETS) do
					for _, fall in ipairs({0, 0.3}) do
						local cx, cz = base.x - az * off, base.z + ax * off
						local from = vec(cx + ax * 4, base.y + h + fall, cz + az * 4)
						local to = vec(cx - ax * 4, base.y + h - fall, cz - az * 4)
						local truth = client_entry(box, base, yaw, from, to)
						local engine = core.raycast(from, to, true)()
						local hit = first_object_hit(from, to, mob)
						local label = ("R %s yaw %d side %d h %.2f off %.1f fall %.1f"):format(
							name, deg, side, h, off, fall)
						if truth then
							st.hits = st.hits + 1
							if h >= 0.9 and name == "zombie" then st.upper = st.upper + 1 end
							local ok = hit ~= nil and hit._engine == nil
							if ok then
								local want = truth * vector.distance(from, to)
								local got = vector.distance(from, hit.intersection_point)
								ok = math.abs(want - got) < 1e-6
							end
							if not check(ok, label .. " hits the client box") then
								st.wrong = st.wrong + 1
							end
						else
							st.misses = st.misses + 1
							if not check(hit == nil, label .. " misses outside the client box") then
								st.wrong = st.wrong + 1
							end
						end
						if (engine ~= nil) ~= (truth ~= nil) then st.engine_wrong = st.engine_wrong + 1 end
					end
				end
			end
		end
	end
	print(("R %s: %d rays hit the client box, %d miss it, %d wrong here; the unturned engine box was wrong on %d"):format(
		name, st.hits, st.misses, st.wrong, st.engine_wrong))
end
check(stats.zombie.engine_wrong > 0 and stats.crocodile.engine_wrong > 0,
	"R the fake engine's unturned box really differs from the client's")
check(stats.zombie.upper > 0 and stats.crocodile.hits > 0, "R upper-body and crocodile hits sampled")

-- Pitch and roll (no mob uses them today): the engine's own left-handed
-- facts for setPitchYawRollRad (src/test/test_irr_matrix4.cpp LEFT_HANDED)
-- with the client's negated rotation. Pitch rot.x = -90 deg: local +z to
-- world -y. Roll rot.z = -90 deg: local +x to world +y.
do
	reset()
	local ROD_Z = {-0.1, -0.1, 0, 0.1, 0.1, 2, rotate = true}
	local ROD_X = {0, -0.1, -0.1, 2, 0.1, 0.1, rotate = true}
	local pitched = new_object({pos = vec(0, 0, 0), rot = vec(-math.pi / 2, 0, 0), box = ROD_Z, base = ROD_Z})
	check(first_object_hit(vec(-3, -1, 0), vec(3, -1, 0), pitched) ~= nil, "R a pitched rod points down")
	check(first_object_hit(vec(-3, 1, 0), vec(3, 1, 0), pitched) == nil, "R a pitched rod not up")
	reset()
	local rolled = new_object({pos = vec(0, 0, 0), rot = vec(0, 0, -math.pi / 2), box = ROD_X, base = ROD_X})
	check(first_object_hit(vec(0, 1, -3), vec(0, 1, 3), rolled) ~= nil, "R a rolled rod points up")
	check(first_object_hit(vec(0, -1, -3), vec(0, -1, 3), rolled) == nil, "R a rolled rod not down")
end

------------------------------------------------------------------------------
-- B: blocking and order.
------------------------------------------------------------------------------
do
	reset()
	local mob = new_object({pos = vec(0, 0, 5), rot = vec(0, math.pi, 0), box = ZOMBIE, base = ZOMBIE})
	nodes[1] = vec(0, 1, 3)
	local from, to = vec(0, 1.2, 0), vec(0, 1.2, 10)
	local hits = all_hits(from, to)
	check(hits[1] and hits[1].type == "node", "B a wall in front comes first")
	check(hits[2] and hits[2].ref == mob, "B the mob behind the wall still follows on the ray")
	local player = {get_player_name = function() return "me" end}
	local r = grug_core.combat_ray(player, 10, {origin = from, direction = vec(0, 0, 1)})
	check(r.status == "aim_miss" and r.reason == "node", "B the combat ray stops at the wall (" ..
		tostring(r.reason) .. ")")
	nodes[1] = vec(0, 1, 8)
	r = grug_core.combat_ray(player, 10, {origin = from, direction = vec(0, 0, 1)})
	check(r.status == "target" and r.target == mob, "B a wall behind the mob does not block (" ..
		tostring(r.reason) .. ")")
	check(r.pointed and math.abs(r.distance - vector.distance(from, r.pointed.intersection_point)) < 1e-9,
		"B the combat ray's distance is the intersection's")
	-- Yaw 180: the zombie's front face (local z 0.65) turns to z = -0.65.
	local face = 5 - 0.65
	check(math.abs(r.distance - face) < 1e-9, ("B entry at the turned front face (%.3f, want %.3f)"):format(
		r.distance, face))
	-- Object preference: a node 0.3 nearer than the mob still comes after it
	-- when d_obj^2 - 1 < d_node^2 (RaycastSort).
	reset()
	mob = new_object({pos = vec(0, 0, 5), rot = vec(0, math.pi, 0), box = ZOMBIE, base = ZOMBIE})
	-- The mob's face is at 5 - 0.65 = 4.35 (4.35^2 - 1 = 17.92).
	nodes[1] = vec(0, 1, 4) -- face at 3.5 (12.25): the node first
	hits = all_hits(vec(0, 1.2, 0), vec(0, 1.2, 10))
	check(hits[1] and hits[1].type == "node", "B a node 0.85 nearer comes first")
	nodes[1] = vec(0, 1, 4.7) -- face at 4.2 (17.64): the node first
	hits = all_hits(vec(0, 1.2, 0), vec(0, 1.2, 10))
	check(hits[1] and hits[1].type == "node", "B a node 0.15 nearer comes first")
	nodes[1] = vec(0, 1, 4.9) -- face at 4.4, behind the mob's face
	hits = all_hits(vec(0, 1.2, 0), vec(0, 1.2, 10))
	check(hits[1] and hits[1].ref == mob, "B the mob before a node behind it")
	nodes[1] = vec(0, 1, 4.75) -- face at 4.25 (18.06): the mob first
	hits = all_hits(vec(0, 1.2, 0), vec(0, 1.2, 10))
	check(hits[1] and hits[1].ref == mob, "B the engine's object preference: mob before a node 0.1 nearer")
end

------------------------------------------------------------------------------
-- U: unturned boxes, players, pointability.
------------------------------------------------------------------------------
do
	reset()
	local PLAIN = {-0.7, -0.01, -0.7, 0.7, 3.06, 0.7}
	local mount = new_object({name = "grug_mounts:horse", pos = vec(0, 0, 4), box = PLAIN, base = PLAIN,
		rot = vec(0, math.rad(130), 0)})
	local player = new_object({player = true, pos = vec(0, 0, 8),
		box = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}})
	local from, to = vec(0, 2.5, 0), vec(0, 1.0, 12)
	local engine = {}
	for p in core.raycast(from, to, true) do engine[#engine + 1] = p end
	local ours = all_hits(from, to)
	check(#ours == #engine and #ours == 2, "U the same number of hits as the engine (" .. #ours .. ")")
	for i = 1, #engine do
		check(ours[i] and ours[i]._engine and ours[i].ref == engine[i].ref and
			vector.distance(ours[i].intersection_point, engine[i].intersection_point) == 0,
			"U hit " .. i .. " is the engine's own pointed thing")
	end
	check(ours[1] and ours[1].ref == mount and ours[2] and ours[2].ref == player,
		"U the unturned box and the player in the engine's order")
	check(property_reads == 0, "U no property read for objects without a rotated box (" ..
		property_reads .. ")")
	-- Unpointable (a dying mob) and invisible turned mobs are not hit.
	reset()
	local dying = new_object({pos = vec(0, 0, 4), rot = vec(0, 2, 0), box = ZOMBIE, base = ZOMBIE,
		pointable = false})
	local hidden = new_object({pos = vec(0, 0, 6), rot = vec(0, 2, 0), box = ZOMBIE, base = ZOMBIE,
		is_visible = false})
	local behind = new_object({pos = vec(0, 0, 8), rot = vec(0, 2, 0), box = ZOMBIE, base = ZOMBIE})
	local hits = all_hits(vec(0, 1, 0), vec(0, 1, 12))
	check(#hits == 1 and hits[1].ref == behind, "U an unpointable or invisible turned mob is passed")
	-- Pointabilities: the entity's own entry, else an armour group.
	hits = all_hits(vec(0, 1, 0), vec(0, 1, 12),
		{objects = {["grug_mobs:test"] = false}})
	check(#hits == 0, "U pointabilities by name make a turned mob unpointable")
	hits = all_hits(vec(0, 1, 0), vec(0, 1, 12), {objects = {["group:fleshy"] = true}})
	check(#hits == 2 and hits[1].ref == dying and hits[2].ref == behind,
		"U a group rule makes the unpointable mob pointable (as the engine)")
	dying.armor = {fleshy = 100, undead = 1}
	hits = all_hits(vec(0, 1, 0), vec(0, 1, 12),
		{objects = {["group:fleshy"] = "blocking", ["group:undead"] = false}})
	check(#hits == 1 and hits[1].ref == behind, "U a false group rule wins over a blocking one")
	hits = all_hits(vec(0, 1, 0), vec(0, 1, 12),
		{objects = {["group:fleshy"] = "blocking", ["group:undead"] = true}})
	check(#hits == 2 and hits[1].ref == dying, "U a true group rule wins over everything")
	-- A turned mob whose box is not rotated any more (rotate false) is tested
	-- unturned, like the engine would.
	reset()
	local flat = {-0.45, -0.05, -0.3, 0.45, 1.8, 0.65, rotate = false}
	local mob = new_object({pos = vec(0, 0, 4), rot = vec(0, math.rad(90), 0), box = flat, base = ZOMBIE})
	hits = all_hits(vec(0, 1, 0), vec(0, 1, 12))
	check(#hits == 1 and hits[1].ref == mob and
		math.abs(vector.distance(vec(0, 1, 0), hits[1].intersection_point) - 3.7) < 1e-9,
		"U a live box without rotate is tested unturned")
	-- A half-size child (scale_mob without perma): base_selbox keeps the
	-- adult box, the live box is half; the live box decides.
	reset()
	local half = {-0.225, -0.025, -0.15, 0.225, 0.9, 0.325, rotate = true}
	local child = new_object({pos = vec(0, 0, 4), rot = vec(0, math.pi, 0), box = half, base = ZOMBIE})
	check(#all_hits(vec(0, 1.5, 0), vec(0, 1.5, 12)) == 0, "U a child's adult hint alone hits nothing")
	hits = all_hits(vec(0, 0.5, 0), vec(0, 0.5, 12))
	check(#hits == 1 and hits[1].ref == child and
		math.abs(vector.distance(vec(0, 0.5, 0), hits[1].intersection_point) - (4 - 0.325)) < 1e-9,
		"U a child is hit on its own live box")
end

------------------------------------------------------------------------------
-- C: candidates.
------------------------------------------------------------------------------
do
	reset()
	-- 30 turned mobs 3-9 nodes beside a 20-node ray, one on it.
	for i = 1, 30 do
		new_object({pos = vec((i % 2 == 0 and 1 or -1) * (3 + i % 7), 0, i * 0.6),
			rot = vec(0, i * 2.4, 0), box = ZOMBIE, base = ZOMBIE})
	end
	local on = new_object({pos = vec(0, 0, 10), rot = vec(0, 2.2, 0), box = ZOMBIE, base = ZOMBIE})
	local hits = all_hits(vec(0, 1, 0), vec(0, 1, 20))
	check(#hits == 1 and hits[1].ref == on, "C the mob on the ray is hit, no other")
	check(property_reads == 1, "C only the mob within reach of the ray reads its properties (" ..
		property_reads .. " of 31)")
	check(area_queries == 1 and math.abs(area_volume - 10 * 10 * 30) < 1e-9,
		"C one candidate query: the ray's box widened by 5 nodes, as the engine's")
	-- A zero-length ray hits nothing and asks no area.
	reset()
	new_object({pos = vec(0, 0, 0), box = ZOMBIE, base = ZOMBIE, rot = vec(0, 1, 0)})
	area_queries = 0
	all_hits(vec(0, 1, 0), vec(0, 1, 0))
	check(area_queries == 0, "C a zero-length ray asks no area")
end

if failures > 0 then
	print(("R35 T PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R35 T PORTABLE PASS checks=%d"):format(checks))

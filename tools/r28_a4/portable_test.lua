-- Round 28 Lane A4 (combat input), portable test (LuaJIT).
--
--   luajit tools/r28_a4/portable_test.lua [repo]
--
-- Loads the REAL grug_abilities/blink.lua and input.lua on a fake engine.
--   C  Charge destination (ruling 12): the real player box against a voxel
--      world; the spot in front of the target; a one-node gap searched back
--      toward the caster; no room within melee reach -> nil; no spot through
--      a wall; step-up; caster within the gap distance; straight above.
--   B  Blink (unchanged): the shared fit helper still gives the same spots.
--   M  messages (ruling 13): a refusal shows on a fresh press only, never on
--      held repeats; the same message at most once per second, another
--      message at once; the cast-gate, swing-gate, try_cast, tap, empty-air
--      and bow-start refusals all reach the flash line; held retries of a
--      failed cast at most every 0.25 s.
--   L  LMB mode at key-down (ruling 14, Round 32): combat on a mob (plants
--      never hide it); gather otherwise (a hand-diggable or protected node,
--      a dropped item, air, a node bare hands cannot dig); combat holds
--      zero the pointing range once and never dig, gather holds never swing;
--      the grace for a native press; slot change, leave and join restore; the
--      bow shares the zero range. The Round 32 gather -> combat switch within
--      a hold is tools/r32_f2's.
-- Prints "R28 A4 PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end

------------------------------------------------------------------------------
-- vector (the subset blink.lua and input.lua use).
------------------------------------------------------------------------------
vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.normalize(v)
	local l = vector.length(v)
	if l == 0 then return vector.new(0, 0, 0) end
	return vector.multiply(v, 1 / l)
end
function vector.direction(a, b) return vector.normalize(vector.subtract(b, a)) end
function vector.round(v)
	return vector.new(math.floor(v.x + 0.5), math.floor(v.y + 0.5), math.floor(v.z + 0.5))
end

------------------------------------------------------------------------------
-- C/B: a voxel world of full solid cubes (`world` argument of blink.lua).
------------------------------------------------------------------------------
local function new_world()
	local solid = {}
	local w = {}
	local function key(x, y, z) return x .. "," .. y .. "," .. z end
	function w.set(x, y, z) solid[key(x, y, z)] = true end
	function w.fill(x1, y1, z1, x2, y2, z2)
		for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do w.set(x, y, z) end end end
	end
	function w.clear(x, y, z) solid[key(x, y, z)] = nil end
	function w.is_solid(x, y, z) return solid[key(x, y, z)] == true end
	function w.boxes(pos)
		if solid[key(pos.x, pos.y, pos.z)] then return {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}} end
		return nil
	end
	-- Fine-stepped segment walk: first solid cube, its entry point and the
	-- face normal (largest axis of the step that entered it).
	function w.ray(from, to)
		local d = vector.subtract(to, from)
		local len = vector.length(d)
		local n = math.max(1, math.ceil(len / 0.005))
		local prev = vector.round(from)
		for i = 0, n do
			local p = vector.add(from, vector.multiply(d, i / n))
			local c = vector.round(p)
			if solid[key(c.x, c.y, c.z)] then
				local dx, dy, dz = c.x - prev.x, c.y - prev.y, c.z - prev.z
				local normal = vector.new(-dx, -dy, -dz)
				if dx ~= 0 then normal = vector.new(-dx, 0, 0)
				elseif dz ~= 0 then normal = vector.new(0, 0, -dz)
				else normal = vector.new(0, -dy, 0) end
				return p, normal
			end
			prev = c
		end
		return nil
	end
	return w
end

local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local EYE = 1.47
local targeting = dofile(ROOT .. "/mods/PLAYER/grug_abilities/blink.lua")
check(type(targeting.blink) == "function" and type(targeting.charge) == "function",
	"B blink.lua returns {blink, charge}")
local charge = targeting.charge

local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end
local function at(v, x, y, z, tol)
	return v ~= nil and near(v.x, x, tol) and near(v.y, y, tol) and near(v.z, z, tol)
end
local function fmt(v) return v and ("(%.2f, %.2f, %.2f)"):format(v.x, v.y, v.z) or "nil" end

-- Independent room check: the box overlaps no solid cube (sampled on a grid).
local function box_free(world, feet)
	for x = BOX[1] + 0.01, BOX[4] - 0.01 + 1e-9, 0.1 do
		for y = BOX[2] + 0.01, BOX[5] - 0.01 + 1e-9, 0.1 do
			for z = BOX[3] + 0.01, BOX[6] - 0.01 + 1e-9, 0.1 do
				local c = vector.round(vector.new(feet.x + x, feet.y + y, feet.z + z))
				if world.is_solid(c.x, c.y, c.z) then return false end
			end
		end
	end
	return true
end

-- Floor: solid y = -1 everywhere in a 40 x 40 patch, top face at y = -0.5.
local FEET = -0.5
local function floor_world()
	local w = new_world()
	w.fill(-20, -1, -20, 20, -1, 20)
	return w
end

do -- C1 flat ground: 1.3 m in front of the target toward the caster.
	local w = floor_world()
	local d = charge(vector.new(0, FEET, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(at(d, 0, FEET, -1.3), "C1 flat ground gap spot, got " .. fmt(d))
	-- Diagonal approach keeps the 1.3 m horizontal gap.
	d = charge(vector.new(6, FEET, -6), EYE, BOX, vector.new(0, FEET, 0), w)
	check(d and near(math.sqrt(d.x * d.x + d.z * d.z), 1.3, 1e-6) and near(d.y, FEET),
		"C1 diagonal gap 1.3 m, got " .. fmt(d))
	-- Caster on higher ground: the spot is at the target's feet height.
	w.fill(-20, 0, -20, 20, 0, -6)
	d = charge(vector.new(0, FEET + 1, -10), EYE, BOX, vector.new(0, FEET, 0), w)
	check(at(d, 0, FEET, -1.3), "C1 caster above, spot at target feet, got " .. fmt(d))
end

do -- C2 one-node-high gap (the playtest death): searched back to its mouth.
	local w = floor_world()
	-- A hillside over the target: y = 0..3 solid for z in [-2, 2]; the gap is
	-- the air layer y = -0.5 .. 0.5 (one node high).
	w.fill(-3, 0, -2, 3, 3, 2)
	local d = charge(vector.new(0, FEET, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(at(d, 0, FEET, -2.8), "C2 gap searched back to z=-2.8, got " .. fmt(d))
	check(d and box_free(w, d), "C2 destination box is free")
	-- The old rule (tpos + dir * 1.3, y = target y) was inside the roof.
	check(not box_free(w, vector.new(0, FEET, -1.3)), "C2 old spot was blocked")
	-- A roof only one node thick is a one-node step: the caster stands on it.
	w = floor_world()
	w.fill(-3, 0, -2, 3, 0, 2)
	d = charge(vector.new(0, FEET, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(at(d, 0, FEET + 1, -1.3) and box_free(w, d),
		"C2 thin roof: stands on it, got " .. fmt(d))
end

do -- C3 no room within melee reach: nil.
	local w = floor_world()
	w.fill(-3, 0, -5, 3, 3, 2) -- hillside reaches 4.5 m toward the caster
	local d = charge(vector.new(0, FEET, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(d == nil, "C3 roof beyond melee reach -> nil, got " .. fmt(d))
	-- A crack one node wide and one node high reaching 5.5 m toward the
	-- caster (small mob in a crack): nil as well.
	w = floor_world()
	w.fill(-1, 0, -6, -1, 2, 2)
	w.fill(1, 0, -6, 1, 2, 2)
	w.fill(0, 1, -6, 0, 2, 2)
	d = charge(vector.new(0, FEET, -10), EYE, BOX, vector.new(0, FEET, 0), w)
	check(d == nil, "C3 one-node crack -> nil, got " .. fmt(d))
end

do -- C4 never through a wall: the caster's eye must see the destination eye.
	local w = floor_world()
	-- The target behind a three-high wall at z = -1 with a window at eye
	-- level (x = 0, y = 1), so the caster sees it. The 1.3 m spot overlaps
	-- the wall (cube -1.5 .. -0.5, box -1.6 .. -1.0); the search lands in
	-- front of the wall, on the caster's side.
	w.fill(-3, 0, -1, 3, 2, -1)
	w.clear(0, 1, -1)
	local d = charge(vector.new(0, FEET, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(at(d, 0, FEET, -1.8), "C4 wall in the way: in front of it, got " .. fmt(d))
	-- A wall that blocks the destination eye ray entirely: every spot behind
	-- the wall (the target side) is refused even when its box is free.
	w = floor_world()
	w.fill(-3, 0, -3, 3, 3, -3) -- solid wall at z = -3, target and spots behind
	d = charge(vector.new(0, FEET, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(d == nil, "C4 no destination through a solid wall, got " .. fmt(d))
end

do -- C5 step-up of one node and a drop.
	local w = floor_world()
	w.fill(-3, 0, -2, 3, 0, -1) -- one-node step in front of the target
	local d = charge(vector.new(0, FEET + 1, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(d and near(d.y, FEET + 1) and box_free(w, d), "C5 one-node step-up, got " .. fmt(d))
	-- Two-node step: no lift; searched back (still blocked) -> nil.
	w = floor_world()
	w.fill(-3, 0, -4, 3, 1, -1)
	d = charge(vector.new(0, FEET + 2, -8), EYE, BOX, vector.new(0, FEET, 0), w)
	check(d == nil, "C5 two-node wall in front -> nil, got " .. fmt(d))
end

do -- C6 caster within the gap distance and straight above.
	local w = floor_world()
	local d = charge(vector.new(0, FEET, -1), EYE, BOX, vector.new(0, FEET, 0), w)
	check(at(d, 0, FEET, -1.3), "C6 caster at 1 m: the 1.3 m spot, got " .. fmt(d))
	d = charge(vector.new(0, FEET + 4, 0), EYE, BOX, vector.new(0, FEET, 0), w)
	check(at(d, 0, FEET, 0), "C6 straight above: the target column, got " .. fmt(d))
	-- Caster at 1.6 m: the 1.3 m spot is blocked and the search never
	-- passes the caster (the next spot would be 1.8 m).
	w.fill(-3, 0, -1, 3, 3, 1) -- hillside z in [-1, 1]: the 1.3 m spot is blocked
	d = charge(vector.new(0, FEET, -1.6), EYE, BOX, vector.new(0, FEET, 0), w)
	check(d == nil, "C6 never searched past the caster, got " .. fmt(d))
end

do -- B Blink unchanged: ground, wall step-up, no room.
	local w = floor_world()
	local eye = vector.new(0, FEET + EYE, -8)
	local a = math.rad(20)
	local dir = vector.new(0, -math.sin(a), math.cos(a))
	local d = targeting.blink(eye, dir, 10, EYE, BOX, w)
	-- Ray from eye height 1.47 down at 20 degrees meets the floor top at
	-- 1.47 / tan(20) = 4.04 m ahead.
	check(d and near(d.y, FEET) and near(d.z, -8 + EYE / math.tan(a), 0.02),
		"B ground spot, got " .. fmt(d))
	w.fill(-3, 0, -3, 3, 0, -3) -- a one-node block ahead, aimed at its side
	a = math.rad(10)
	d = targeting.blink(eye, vector.new(0, -math.sin(a), math.cos(a)), 10, EYE, BOX, w)
	check(d and near(d.y, FEET + 1) and near(d.z, -3), "B one-node step-up, got " .. fmt(d))
	d = targeting.blink(eye, vector.new(0, 1, 0), 10, EYE, BOX, w)
	check(d and near(d.y, FEET + 10) and near(d.z, -8), "B straight up full distance, got " .. fmt(d))
	w.fill(-3, -1, -7, 3, 3, -7) -- wall 1 m ahead: move shorter than 1.5 m
	d = targeting.blink(eye, vector.new(0, 0, 1), 10, EYE, BOX, w)
	check(d == nil, "B wall right ahead -> nil, got " .. fmt(d))
end

------------------------------------------------------------------------------
-- M: input.lua on a fake engine.
------------------------------------------------------------------------------
local clock = 0
local raycasts = 0 -- input.lua's own rays (the fake combat_ray casts none)
local hits = {} -- what the next raycast returns (in order of distance)
local node_at = {} -- "x,y,z" -> node name (default test:dirt)
local protected = {} -- "x,y,z" -> true
local function pkey(p) return p.x .. "," .. p.y .. "," .. p.z end
local flashes, swings, casts = {}, {}, {}
local mob = {get_luaentity = function() return {name = "test:mob", health = 10} end,
	get_pos = function() return vector.new(0, 1, 2) end, is_player = function() return false end}
local drop = {get_luaentity = function() return {name = "__builtin:item"} end}
local try_cast_result = {} -- id -> {ok, message}
local refusals = {} -- id -> cast or swing refusal message
local joins, leaves = {}, {}

core = {
	registered_nodes = {
		["test:dirt"] = {walkable = true, groups = {crumbly = 3}},
		["test:grass"] = {walkable = false, groups = {snappy = 3}},
		["test:stone"] = {walkable = true, groups = {cracky = 3}},
	},
	registered_entities = {},
	get_us_time = function() return clock end,
	check_player_privs = function() return true end,
	get_node_or_nil = function(pos) return {name = node_at[pkey(pos)] or "test:dirt"} end,
	is_protected = function(pos) return protected[pkey(pos)] == true end,
	-- Bare hands dig crumbly and snappy nodes, never cracky ones.
	get_dig_params = function(groups) return {diggable = (groups.crumbly or groups.snappy) ~= nil} end,
	get_item_group = function(name, group)
		return group == "grug_ability" and name:sub(1, 15) == "grug_abilities:" and 1 or 0
	end,
	raycast = function()
		raycasts = raycasts + 1
		local i = 0
		return function()
			i = i + 1
			return hits[i]
		end
	end,
	register_on_mods_loaded = function() end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function(f) leaves[#leaves + 1] = f end,
	register_on_joinplayer = function(f) joins[#joins + 1] = f end,
}

-- Item stacks with string meta; the inventory stores copies like the engine.
local function new_stack(name, meta)
	local st = {name = name or "", meta = {}}
	for k, v in pairs(meta or {}) do st.meta[k] = v end
	function st:get_name() return self.name end
	function st:get_tool_capabilities() return {} end
	function st:get_meta()
		local m = self.meta
		return {
			get_string = function(_, k) return m[k] or "" end,
			set_string = function(_, k, v) if v == "" then m[k] = nil else m[k] = v end end,
		}
	end
	return st
end
local function copy_stack(st) return new_stack(st.name, st.meta) end
function ItemStack(name) return new_stack(type(name) == "string" and name or "") end

local main = {}
for i = 1, 8 do main[i] = new_stack("") end
local writes = {} -- {via = "wield" | "set_stack", index, range, skip}
local wield_index = 1
local inventory = {
	get_stack = function(_, list, i) assert(list == "main"); return copy_stack(main[i]) end,
	set_stack = function(_, list, i, st)
		assert(list == "main")
		main[i] = copy_stack(st)
		writes[#writes + 1] = {via = "set_stack", index = i, range = st.meta.range or ""}
	end,
	get_list = function(_, list)
		assert(list == "main")
		local out = {}
		for i, st in ipairs(main) do out[i] = copy_stack(st) end
		return out
	end,
}

grug_core = {
	combat_eye_pos = function() return vector.new(0, 1.47, 0) end,
	is_stunned = function() return false end,
	player_has_live_mount = function() return false end,
	register_on_stun = function() end,
	-- Combat-ray rules over the same hit list: non-walkable nodes and dropped
	-- items are passed through, a walkable node ends the ray, the first actor
	-- is classified (out_of_range beyond `range` from the eye).
	combat_ray = function(_, range)
		for _, hit in ipairs(hits) do
			local d = vector.distance(vector.new(0, 1.47, 0), hit.intersection_point)
			local passed = hit.type == "object" and
				hit.ref:get_luaentity().name == "__builtin:item"
			if hit.type == "node" then
				local def = core.registered_nodes[core.get_node_or_nil(hit.under).name]
				if def.walkable then return {status = "aim_miss", reason = "node"} end
			elseif not passed and d > range then
				return {status = "aim_miss", reason = "out_of_range", target = hit.ref,
					distance = d, pointed = hit}
			elseif hit.ref == mob then
				return {status = "target", reason = "hostile", target = mob, distance = d,
					pointed = hit}
			elseif not passed then
				return {status = "aim_miss", reason = "object", target = hit.ref, distance = d,
					pointed = hit}
			end
		end
		return {status = "aim_miss", reason = "empty"}
	end,
}

local defs = {
	strike = {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike"},
	fireball = {id = "fireball", kind = "cast", target_kind = "hostile", name = "Fireball"},
	charge = {id = "charge", kind = "cast", target_kind = "hostile", name = "Charge"},
	mighty_blow = {id = "mighty_blow", kind = "swing", target_kind = "hostile",
		name = "Mighty Blow"},
	blink = {id = "blink", kind = "cast", target_kind = "self", name = "Blink",
		repeat_policy = "once"},
	loose = {id = "loose", kind = "cast", target_kind = "hostile", name = "Loose"},
}
local bow_error
grug_abilities = {
	registered = defs,
	is_unlocked = function() return true end,
	get_range = function() return 20 end,
	valid_target = function(_, ref, kind) return ref == mob and kind == "hostile" end,
	support_refused = function() return false end,
	flash = function(_, msg) flashes[#flashes + 1] = msg end,
	cancel_bow_draw = function() end,
	start_bow_draw = function()
		if bow_error then return false, bow_error end
		return true
	end,
	try_cast = function(_, def, _, notify)
		casts[#casts + 1] = def.id
		local r = try_cast_result[def.id]
		if r and not r.ok then
			notify(r.message)
			return nil
		end
		return true
	end,
}

local function wielded_def()
	local name = main[wield_index].name
	return name:sub(1, 15) == "grug_abilities:" and defs[name:sub(16)] or nil
end
local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
	selected = function() return wielded_def() end,
	swing = function(_, def) swings[#swings + 1] = def.id end,
	cast_refusal = function(_, def) return refusals[def.id] end,
	swing_refusal = function(_, def) return refusals[def.id] end,
	delay_strike = function() end,
	within_hand_reach = function() return true end,
})

local controls = {dig = false, place = false}
local player = {
	get_player_name = function() return "p" end,
	get_player_control = function() return controls end,
	get_inventory = function() return inventory end,
	get_wield_list = function() return "main" end,
	get_wield_index = function() return wield_index end,
	get_wielded_item = function() return copy_stack(main[wield_index]) end,
	set_wielded_item = function(_, st, skip)
		main[wield_index] = copy_stack(st)
		writes[#writes + 1] = {via = "wield", index = wield_index,
			range = st.meta.range or "", skip = skip}
		return true
	end,
	get_hp = function() return 20 end,
	get_pos = function() return vector.new(0, 0, 0) end,
	get_look_dir = function() return vector.new(0, 0, 1) end,
}

local MOB_HIT = {type = "object", ref = mob, intersection_point = vector.new(0, 1.47, 2)}
local NODE_HIT = {type = "node", under = vector.new(0, 1, 2), above = vector.new(0, 1, 1),
	intersection_point = vector.new(0, 1.47, 1.5)}
local GRASS_HIT = {type = "node", under = vector.new(0, 1, 1), above = vector.new(0, 1, 0),
	intersection_point = vector.new(0, 1.47, 0.6)}
local MOB_NEAR = {type = "object", ref = mob, intersection_point = vector.new(0, 1.47, 1)}
local FAR_MOB = {type = "object", ref = mob, intersection_point = vector.new(0, 1.47, 10)}
local DROP_HIT = {type = "object", ref = drop, intersection_point = vector.new(0, 1.2, 1)}
node_at[pkey(GRASS_HIT.under)] = "test:grass"
local function aim(...) hits = {...} end
local function step(dt)
	clock = clock + (dt or 50000)
	input.step(player)
end
local function press(dt) controls.dig = true; step(dt) end
local function release(dt) controls.dig = false; step(dt) end
local function hold(n) for _ = 1, n do step() end end
local function reset_log() flashes, swings, casts, writes = {}, {}, {}, {} end
local function select(id)
	main[wield_index] = new_stack("grug_abilities:" .. id)
	controls.dig, controls.place = false, false
	clock = clock + 1000000 -- past every grace and throttle window
	step()
	reset_log()
end
local function count(list, value)
	local n = 0
	for _, v in ipairs(list) do if v == value then n = n + 1 end end
	return n
end
local function range_of(i) return main[i].meta.range or "" end

do -- M1 cast-gate refusal: fresh press shows, held repeats do not.
	select("fireball")
	refusals.fireball = "Fireball is not ready."
	aim(MOB_HIT)
	press()
	check(#flashes == 1 and flashes[1] == "Fireball is not ready.",
		"M1 fresh press flashes the refusal (got " .. #flashes .. ")")
	check(swings[1] == "strike", "M1 a refused cast still falls back to Strike")
	hold(5) -- held repeats
	check(#flashes == 1, "M1 held repeats stay silent (got " .. #flashes .. ")")
	check(#casts == 0, "M1 a refused cast never reaches try_cast")
	release()
	-- Same message on a new press 0.3 s later: throttled.
	clock = clock + 300000
	press()
	check(#flashes == 1, "M1 same message within 1 s is throttled")
	release()
	-- Another message at once.
	refusals.fireball = "Not enough mana."
	press()
	check(#flashes == 2 and flashes[2] == "Not enough mana.",
		"M1 a different message shows at once")
	release()
	-- The first message again after a second.
	refusals.fireball = "Fireball is not ready."
	clock = clock + 1000000
	press()
	check(#flashes == 3 and flashes[3] == "Fireball is not ready.",
		"M1 the same message shows again after 1 s")
	release()
	refusals.fireball = nil
end

do -- M2 try_cast's own refusal (Charge without room) on a fresh press only.
	select("charge")
	try_cast_result.charge = {ok = false, message = "Not enough room at target."}
	aim(MOB_HIT)
	press()
	check(count(flashes, "Not enough room at target.") == 1,
		"M2 fresh press shows the cast's own refusal")
	hold(10) -- 0.5 s of held steps at 50 ms
	-- Held retries of a cast that failed in try_cast wait 0.25 s each (every
	-- try resets the swing boundary), so 0.5 s of holding retries twice;
	-- the Strike fallback swings on every step.
	check(#casts == 3 and count(flashes, "Not enough room at target.") == 1,
		"M2 held retries reach try_cast silently, at most every 0.25 s (casts " ..
		#casts .. ", expected 3)")
	check(count(swings, "strike") == 11, "M2 Strike falls back on every step (swings " ..
		count(swings, "strike") .. ")")
	release()
	-- A fresh press retries at once, even inside the 0.25 s.
	reset_log()
	press()
	check(#casts == 1, "M2 a fresh press always tries the cast")
	release()
	try_cast_result.charge = nil
	clock = clock + 2000000
	reset_log()
	press()
	check(#flashes == 0 and casts[1] == "charge", "M2 a successful cast shows nothing")
	release()
end

do -- M3 swing-gate refusal (Mighty Blow without rage).
	select("mighty_blow")
	refusals.mighty_blow = "Not enough rage."
	aim(MOB_HIT)
	press()
	check(#flashes == 1 and flashes[1] == "Not enough rage.", "M3 fresh press shows the swing refusal")
	check(swings[1] == "strike", "M3 the plain Strike swings instead")
	hold(10)
	check(#flashes == 1, "M3 held swings stay silent")
	release()
	refusals.mighty_blow = nil
	clock = clock + 2000000
	reset_log()
	press()
	check(#flashes == 0 and swings[1] == "mighty_blow", "M3 ready swing skill: no message")
	release()
end

do -- M4 self skill: empty-air press and the node tap.
	select("blink")
	try_cast_result.blink = {ok = false, message = "No room to blink."}
	aim()
	press()
	check(#flashes == 1 and flashes[1] == "No room to blink.", "M4 empty-air cast refusal shows")
	hold(5)
	check(#flashes == 1 and #casts == 1, "M4 one empty-air attempt per press")
	release()
	try_cast_result.blink = nil
	clock = clock + 2000000
	reset_log()
	-- Tap at a hand-diggable node while Blink is on cooldown: reported at the tap.
	refusals.blink = "Blink is not ready."
	aim(NODE_HIT)
	press()
	check(#flashes == 0, "M4 node press waits for the tap decision")
	release()
	check(#flashes == 1 and flashes[1] == "Blink is not ready.", "M4 the tap reports the refusal")
	-- Holding past 200 ms digs: no message.
	clock = clock + 2000000
	reset_log()
	press()
	hold(6)
	release()
	check(#flashes == 0, "M4 a dig hold reports nothing")
	refusals.blink = nil
end

do -- M5 bow start refusal on the RMB press.
	select("loose")
	bow_error = "You need an arrow."
	aim()
	controls.place = true
	step()
	check(#flashes == 1 and flashes[1] == "You need an arrow.", "M5 bow start refusal shows")
	hold(5)
	check(#flashes == 1, "M5 held RMB stays silent")
	controls.place = false
	step()
	bow_error = nil
end

------------------------------------------------------------------------------
-- L: the LMB mode lock (ruling 14).
------------------------------------------------------------------------------
local function range_writes(value)
	local n = 0
	for _, w in ipairs(writes) do if w.range == value then n = n + 1 end end
	return n
end
local function dig_ok(hit_pos)
	return input.can_dig(player, hit_pos, core.get_node_or_nil(hit_pos))
end

do -- L1 key-down on a mob: combat; zero range for the hold, never digs.
	select("strike")
	aim(MOB_HIT)
	press()
	check(range_of(1) == "0" and #writes == 1 and writes[1].via == "wield" and
		writes[1].skip == true, "L1 combat sets range 0 via set_wielded_item(stack, true)")
	check(swings[1] == "strike", "L1 combat swings at the mob")
	-- The crosshair slips onto the node beside the mob: no dig, no pending.
	aim(NODE_HIT)
	hold(3)
	check(not dig_ok(NODE_HIT.under), "L1 can_dig refuses in a combat hold")
	-- The mob steps back in (retarget freely): swings resume.
	local before = #swings
	aim(MOB_HIT)
	hold(2)
	check(#swings > before, "L1 combat retargets freely")
	check(#writes == 1, "L1 no further range writes while held")
	release()
	check(range_of(1) == "" and #writes == 2 and writes[2].via == "wield" and
		writes[2].skip == true, "L1 release restores the range")
end

do -- L2 key-down on a hand-diggable node: gather; no writes while gathering.
	-- (A hostile walking into the ray switches the hold to combat since Round
	-- 32; tools/r32_f2 covers that state machine.)
	select("strike")
	aim(NODE_HIT)
	press()
	check(#writes == 0 and range_of(1) == "", "L2 gather leaves the range alone")
	check(dig_ok(NODE_HIT.under), "L2 gather may dig the node")
	hold(5)
	check(#swings == 0 and #casts == 0, "L2 gather on a node never swings")
	release()
	hold(4)
	check(#writes == 0, "L2 no range writes at all")
end

do -- L3 key-down on a protected diggable node: gather (Round 24 hint stays).
	select("strike")
	protected[pkey(NODE_HIT.under)] = true
	aim(NODE_HIT)
	press()
	check(#writes == 0, "L3 protected diggable node is gather")
	check(not dig_ok(NODE_HIT.under), "L3 the dig itself is still refused (hint path)")
	release()
	hold(4)
	protected[pkey(NODE_HIT.under)] = nil
end

do -- L4 a plant in front of a mob never hides it: combat.
	select("strike")
	aim(GRASS_HIT, MOB_HIT)
	press()
	check(range_of(1) == "0" and swings[1] == "strike", "L4 grass in front of a mob: combat")
	release()
	hold(4)
	-- Grass alone is a hand-diggable node: gather.
	reset_log()
	aim(GRASS_HIT)
	press()
	check(#writes == 0, "L4 grass alone: gather")
	release()
	hold(4)
end

do -- L5 air, a non-hand node and a dropped item.
	select("blink")
	aim()
	press()
	check(range_of(1) == "" and casts[1] == "blink", "L5 air: gather (Round 32), one empty-space cast")
	release()
	hold(4)
	check(range_of(1) == "", "L5 air hold restored")
	select("strike")
	node_at[pkey(NODE_HIT.under)] = "test:stone"
	aim(NODE_HIT)
	press()
	check(range_of(1) == "" and #swings == 0, "L5 a node bare hands cannot dig: gather (Round 32), no swing")
	release()
	hold(4)
	node_at[pkey(NODE_HIT.under)] = nil
	reset_log()
	aim(DROP_HIT)
	press()
	check(#writes == 0, "L5 dropped item alone: gather")
	hold(3)
	check(#swings == 0, "L5 a pickup press never swings")
	release()
	hold(4)
	-- Loot never hides a hostile behind it: combat, the swing lands through it.
	reset_log()
	aim(DROP_HIT, MOB_HIT)
	press()
	check(range_of(1) == "0" and swings[1] == "strike",
		"L5 drop in front of a mob: combat and a swing")
	release()
	hold(4)
end

do -- L10 a protected wall in a town: gather (the hint path); Blink's tap there.
	select("strike")
	node_at[pkey(NODE_HIT.under)] = "test:stone"
	protected[pkey(NODE_HIT.under)] = true
	aim(NODE_HIT)
	press()
	check(#writes == 0 and range_of(1) == "",
		"L10 protected undiggable wall: gather, the client keeps pointing (hint)")
	check(not dig_ok(NODE_HIT.under), "L10 the dig is refused (protection violation path)")
	hold(5)
	release()
	hold(4)
	check(#swings == 0 and #casts == 0, "L10 nothing else happens")
	-- Blink tapped at protected town ground still casts on release.
	select("blink")
	aim(NODE_HIT)
	press()
	check(#casts == 0, "L10 Blink waits for the tap decision")
	release()
	check(casts[1] == "blink", "L10 Blink tap on protected ground casts")
	-- Holding there casts nothing.
	clock = clock + 2000000
	reset_log()
	press()
	hold(6)
	release()
	check(#casts == 0, "L10 a hold on protected ground casts nothing")
	node_at[pkey(NODE_HIT.under)] = nil
	protected[pkey(NODE_HIT.under)] = nil
end

do -- L11 Loose's LMB reach is hand reach, not the bow range.
	select("loose")
	aim(FAR_MOB)
	press()
	hold(3)
	check(#swings == 0, "L11 Loose: no Strike at a mob 10 m away")
	release()
	hold(4)
	select("strike") -- the fake gives every other skill 20 m
	aim(FAR_MOB)
	press()
	check(swings[1] == "strike", "L11 a 20 m skill does reach it")
	release()
	hold(4)
end

do -- L12 a held combat press casts no hand ray.
	select("strike")
	aim(MOB_HIT)
	press()
	raycasts = 0
	hold(5)
	check(raycasts == 0, "L12 no hand ray while a combat hold is held (" .. raycasts .. ")")
	release()
	hold(4)
end

do -- L6 a native press seen before the control report keeps its mode.
	select("strike")
	aim(MOB_HIT)
	input.press(player) -- native punch: controls.dig not yet reported
	check(range_of(1) == "0", "L6 native press decides combat")
	step() -- control report still false, within the grace
	check(range_of(1) == "0" and #writes == 1, "L6 grace keeps the zero range")
	press() -- the control report arrives
	hold(2)
	check(#writes == 1, "L6 no second decision, no rewrite")
	release()
	hold(3)
	check(range_of(1) == "" and #writes == 2, "L6 release after the grace restores")
end

do -- L7 a slot change mid-hold restores the old stack.
	select("strike")
	main[2] = new_stack("grug_abilities:fireball")
	aim(MOB_HIT)
	press()
	check(range_of(1) == "0", "L7 combat on slot 1")
	wield_index = 2
	step() -- carried press into a new item: cancel
	check(range_of(1) == "" and writes[#writes].via == "set_stack" and
		writes[#writes].index == 1, "L7 slot 1 restored by set_stack after the switch")
	check(range_of(2) == "", "L7 the new item is untouched")
	release()
	hold(4)
	wield_index = 1
end

do -- L8 the bow draw and a combat hold share the zero range.
	select("loose")
	aim(MOB_HIT)
	press()
	input.hold_range(player, "bow", true)
	check(range_of(1) == "0", "L8 both owners: zero range")
	release()
	hold(4) -- LMB ends; the bow still draws
	check(range_of(1) == "0", "L8 LMB release keeps the bow's zero range")
	input.hold_range(player, "bow", false)
	check(range_of(1) == "", "L8 the last owner restores the range")
	input.hold_range(player, "bow", true)
	aim(NODE_HIT)
	press() -- gather press while drawing: the bow keeps its range
	release()
	hold(4)
	check(range_of(1) == "0", "L8 a gather press never clears the bow's range")
	input.hold_range(player, "bow", false)
	check(range_of(1) == "", "L8 bow release restores")
end

do -- L9 leave restores; join clears every saved zero range.
	select("strike")
	aim(MOB_HIT)
	press()
	check(range_of(1) == "0", "L9 combat hold")
	for _, f in ipairs(leaves) do f(player) end
	check(range_of(1) == "", "L9 leave restores before the save")
	controls.dig = false
	main[3] = new_stack("grug_abilities:charge", {range = "0"})
	main[4] = new_stack("test:pick", {range = "0"})
	for _, f in ipairs(joins) do f(player) end
	check(range_of(3) == "" and range_of(4) == "0", "L9 join clears skill stacks only")
	main[3], main[4] = new_stack(""), new_stack("")
end

if failures == 0 then
	print("R28 A4 PORTABLE PASS checks=" .. checks)
else
	error(("R28 A4 PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end

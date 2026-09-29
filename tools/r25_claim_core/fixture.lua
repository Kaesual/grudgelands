-- Round 25 Lane A portable fixture (LuaJIT): the Claim Stone core.
--
--   luajit tools/r25_claim_core/fixture.lua "$PWD" [seed | none]
--
-- Runs the shipped bytes of mods/PLAYER/grug_housing (registry.lua,
-- protection.lua, soulbound.lua, stone.lua) and grug_core/protection.lua
-- against small engine stubs:
--   1. placement validation on a synthetic world: every refusal reason
--      (rulings 2, 3, 5, 6, 9, 22, 23, 27), edge-to-edge accept, overlap
--      refuse, and the zone check's completeness (a single forbidden column
--      anywhere in the 101 x 101 square refuses; a single landmark column or
--      village core anywhere within 16 of it refuses, none beyond);
--   2. protection by permission level, faction (world protection first),
--      protection_bypass, empty claims, the arrival cube; the liquid and the
--      renewal guards;
--   3. fuel arithmetic: accept limits, remaining time, pick-up refund, expiry
--      by the wall clock (fake clock), the expiry report, refuel (ruling 20);
--      Round 26: drafts protect nothing but reserve their square and keep
--      the arrival cube, activation (at least 5 lumps), and the owner digging
--      a buildable_to node (snow) in the arrival cube;
--   4. Round 26: the draft lifetime, the 12 h pick-up lock after activation,
--      no placing lock, and every state transition;
--   5. soulbound refusals (player lists, node inventories, detached
--      inventories) and the stone's drop, dig (no drop, ruling 21) and
--      pick-capability rules;
--   6. persistence: a second model over the same storage reads back the
--      same claims and records;
--   7. (unless "none") the real world of one seed (tools/r25_road_poi/
--      world.lua: zones, roads, settlement cores): hard_footprint_in against
--      a column scan, refusals at every start town, a census of a claim
--      lattice with an exhaustive re-check (the square and its 16-node ring),
--      the nearest feature per kind, a village pair for the engine smoke
--      (20 nodes: refused, 70 nodes: accepted), and the is_protected cost
--      (grug_core alone vs with grug_housing, 0 and 50 claims).
-- Prints "R25 CLAIM CORE FIXTURE PASS checks=<n>" or raises with the
-- failures. The engine counterpart is `run.sh OUT_DIR` (grug_probe_claims,
-- two boots on seed 4242424242). evidence/: fixture.txt (this run),
-- engine.txt (run.sh), pins.txt (the mapgen pins with the masks removed).
local repo = assert(arg[1], "usage: fixture.lua <repo> [seed | none]")
local seed = arg[2] or "4242424242"
local housing_dir = repo .. "/mods/PLAYER/grug_housing"

local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label; print("FAIL " .. label) end
end
local function out(text) print(text) end

-- ---------------------------------------------------------------------------
-- Clock and storage
-- ---------------------------------------------------------------------------
local clock = 1800000000
local function now() return clock end
local function new_storage()
	local data = {}
	return {data = data,
		get_string = function(key) return data[key] or "" end,
		set_string = function(key, value)
			if value == "" then data[key] = nil else data[key] = value end
		end,
		keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end}
end
local registry_factory = dofile(housing_dir .. "/registry.lua")
local function new_model(storage)
	local model = registry_factory({storage = storage, now = now})
	model.load()
	return model
end

-- ---------------------------------------------------------------------------
-- 1. Synthetic world
-- ---------------------------------------------------------------------------
-- z <= -1000 a level 1-10 home zone, z >= 1000 the other faction, x >= 1000
-- a contested level 31-40 zone, -2000 < x <= -1000 a capital zone, x <= -2000
-- open sea; otherwise two home zones (L11-20 west of x = 0, L21-30 east).
-- A town (hard) square around (500, 500), a village box around (-500, 500),
-- a landmark column at (500, -500).
local ZONES = {
	home11 = {id = "home11", faction = "accord", territory_rule = "accord_home",
		level_min = 11, level_max = 20},
	home21 = {id = "home21", faction = "accord", territory_rule = "accord_home",
		level_min = 21, level_max = 30},
	low = {id = "low", faction = "accord", territory_rule = "accord_home",
		level_min = 1, level_max = 10},
	contested = {id = "contested", territory_rule = "contested_land",
		level_min = 31, level_max = 40},
	enemy = {id = "enemy", faction = "throng", territory_rule = "throng_home",
		level_min = 11, level_max = 20},
	capital = {id = "capital", faction = "accord", territory_rule = "accord_home",
		level_min = 20, level_max = 30, civic_no_hostiles = true},
}
local enclave -- optional {min_x, max_x, min_z, max_z}: a level 1-10 enclave
local blocked_cube = {}
local world = {}
-- Water: open ocean west of x = -2000 (no zone); a coastal shelf strip (with
-- an owning home zone, as in zones.lua) at 600..700 / -900..-800; a lake
-- (planned water) at -700..-650 / -100..100.
function world.water_class_at(x, z)
	if x <= -2000 then return "deep_ocean" end
	if x >= 600 and x <= 700 and z >= -900 and z <= -800 then return "coastal_shelf" end
	if x >= -700 and x <= -650 and z >= -100 and z <= 100 then return "planned_water" end
	return "land"
end
function world.zone_at(x, z)
	if enclave and x >= enclave[1] and x <= enclave[2] and z >= enclave[3] and
			z <= enclave[4] then
		return ZONES.low
	end
	if x <= -2000 then return nil end
	if z <= -1000 then return ZONES.low end
	if z >= 1000 then return ZONES.enemy end
	if x >= 1000 then return ZONES.contested end
	if x <= -1000 then return ZONES.capital end
	return x < 0 and ZONES.home11 or ZONES.home21
end
function world.territory_at(x, z)
	if math.abs(x - 500) <= 40 and math.abs(z - 500) <= 40 then
		return "hard_protected"
	end
	local zone = world.zone_at(x, z)
	return zone and zone.territory_rule or "immutable"
end
local BOXES = {
	{id = "town", kind = "town", min_x = 459, max_x = 541, min_z = 459, max_z = 541},
	{id = "village", kind = "site", min_x = -581, max_x = -419, min_z = 419, max_z = 581},
	{id = "landmark", kind = "landmark", min_x = 499, max_x = 501, min_z = -501, max_z = -499},
}
-- Ruling 27: a box within `margin` of the rectangle (in x and in z).
local feature_calls = {}
function world.feature_in(min_x, min_z, max_x, max_z, margin)
	feature_calls[#feature_calls + 1] = margin
	for _, box in ipairs(BOXES) do
		if max_x + margin >= box.min_x and min_x - margin <= box.max_x and
				max_z + margin >= box.min_z and min_z - margin <= box.max_z then
			return box.kind
		end
	end
	return nil
end
function world.cube_clear(pos)
	return not blocked_cube[pos.x .. "/" .. pos.z]
end

local storage = new_storage()
local M = new_model(storage)
local function validate(name, faction, x, y, z)
	local ok, code = M.validate(name, faction, {x = x, y = y, z = z}, world)
	return ok and "ok" or code
end

out("-- validation")
check(M.SAMPLE_COUNT == 101 * 101, "every column checked: " .. M.SAMPLE_COUNT)
check(validate("alice", "accord", -300, 10, 0) == "ok", "accept in an L11-20 zone")
check(validate("alice", "accord", 0, 10, -300) == "ok",
	"accept across the L11-20 / L21-30 border")
check(validate("alice", "accord", 300, -100, 0) == "ok", "accept at y = -100")
check(validate("alice", "accord", 300, -101, 0) == "too_deep", "refuse at y = -101")
check(validate("alice", nil, 300, 10, 0) == "no_faction", "refuse without faction")
check(validate("alice", "throng", 300, 10, 0) == "enemy", "refuse in the other faction's land")
check(validate("alice", "accord", 0, 10, -950) == "low_level",
	"refuse: square reaches an L1-10 zone by one column (z -1000)")
check(validate("alice", "accord", 0, 10, -949) == "ok",
	"accept: square ends one column before the L1-10 zone")
check(validate("alice", "accord", 950, 10, 0) == "high_level", "refuse: reaches L31+ zone")
check(validate("alice", "accord", 0, 10, 950) == "enemy", "refuse: reaches enemy zone")
check(validate("alice", "accord", -950, 10, 0) == "capital_zone",
	"ruling 22: refuse, reaches a capital zone")
check(validate("alice", "accord", -1500, 10, 0) == "capital_zone", "refuse inside a capital zone")
-- Ruling 27: 16 nodes between the claim square and a town, village or
-- landmark (town box z 459, so the square may end at z 442: centre 392).
check(M.SETTLEMENT_MARGIN == 16, "ruling 27: margin 16")
check(validate("alice", "accord", 500, 10, 430) == "town", "refuse: touches a town box")
check(validate("alice", "accord", 500, 10, 393) == "town", "refuse: 15 nodes from the town")
check(validate("alice", "accord", 500, 10, 392) == "ok", "accept 16 nodes from the town")
check(feature_calls[#feature_calls] == 16, "feature_in asked with margin 16")
check(validate("alice", "accord", -500, 10, 353) == "site", "refuse: 15 nodes from a village")
check(validate("alice", "accord", -500, 10, 352) == "ok", "accept 16 nodes from a village")
check(validate("alice", "accord", 433, 10, -500) == "landmark",
	"refuse: 15 nodes from a landmark")
check(validate("alice", "accord", 432, 10, -500) == "ok", "accept 16 nodes from a landmark")
blocked_cube["300/0"] = true
check(validate("alice", "accord", 300, 10, 0) == "cube", "refuse: arrival cube not air")
blocked_cube["300/0"] = nil
-- Hard protection without a feature box (the sampled territory rule).
BOXES[1].min_x = 10 ^ 6
check(validate("alice", "accord", 500, 10, 410) == "town", "refuse: sampled hard column")
BOXES[1].min_x = 459
do
	-- Open sea: the western edge at x = -2000 (nil zone), reached by the square
	-- of a stone at x = -1950 only through its border columns.
	local saved = ZONES.capital.civic_no_hostiles
	ZONES.capital.civic_no_hostiles = nil
	check(validate("alice", "accord", -1950, 10, 0) == "sea", "refuse: reaches the open sea")
	ZONES.capital.civic_no_hostiles = saved
end

-- Ruling 23: lakes, rivers and bay water in an eligible zone are fine; the
-- shelf (which has a zone) and the ocean are not.
check(validate("alice", "accord", -680, 10, 0) == "ok", "ruling 23: a lake inside the claim")
check(validate("alice", "accord", 650, 10, -750) == "shelf",
	"ruling 23: refuse, reaches the coastal shelf by one column")
check(validate("alice", "accord", 650, 10, -749) == "ok", "ruling 23: accept next to the shelf")
check(validate("alice", "accord", 650, 10, -849) == "shelf",
	"ruling 23: refuse, stone on the shelf")
check(validate("alice", "accord", 800, 10, -700) == "ok", "next to the shelf")

-- Every column is checked: a single forbidden column anywhere in the square
-- (border or interior) refuses.
do
	local missed, tried = 0, 0
	for ex = -50, 50 do
		for ez = -50, 50 do
			enclave = {-300 + ex, -300 + ex, ez, ez}
			tried = tried + 1
			if validate("alice", "accord", -300, 10, 0) ~= "low_level" then
				missed = missed + 1
			end
		end
	end
	enclave = nil
	check(missed == 0, "every single-column enclave found (" .. tried .. " positions)")
	check(validate("alice", "accord", -300, 10, 0) == "ok", "no enclave: accepted")
	out(("zone check: %d columns per placement (border 400, interior step %d);" ..
		" %d single-column enclave positions, %d missed"):format(M.SAMPLE_COUNT,
		M.SAMPLE_STEP, tried, missed))
end

-- Ruling 27, brute force: a single landmark column, and a single 3 x 3
-- village core, at every offset within 70 of the centre: refused exactly
-- when it lies within 50 + 16 of the centre in x and in z.
do
	local saved = BOXES
	local wrong, tried = 0, 0
	for _, size in ipairs({{0, "landmark"}, {1, "site"}}) do
		for ox = -70, 70 do
			for oz = -70, 70 do
				local cx, cz = -300 + ox, oz
				BOXES = {{kind = size[2], min_x = cx - size[1], max_x = cx + size[1],
					min_z = cz - size[1], max_z = cz + size[1]}}
				local reach = 66 + size[1]
				local expect = (math.abs(ox) <= reach and math.abs(oz) <= reach) and
					size[2] or "ok"
				tried = tried + 1
				if validate("alice", "accord", -300, 10, 0) ~= expect then wrong = wrong + 1 end
			end
		end
	end
	BOXES = saved
	check(wrong == 0, "ruling 27: every single column / core within 66 refused," ..
		" every one beyond accepted (" .. tried .. " positions)")
	out(("ruling 27: %d single-feature positions around a centre, %d wrong"):format(
		tried, wrong))
end

-- Placement, overlap, edge to edge.
out("-- claims")
local a = M.create("alice", {x = -300, y = 10, z = 0})
check(M.player_state("alice") == "placed", "alice placed")
check(validate("alice", "accord", 300, 10, 0) == "already_placed", "one claim per player")
check(validate("bob", "accord", -300 + 100, 10, 0) == "overlap", "overlap refused at dx 100")
check(validate("bob", "accord", -300, 10, 100) == "overlap", "overlap refused at dz 100")
check(validate("bob", "accord", -300 + 100, 10, 100) == "overlap", "corner overlap refused")
check(validate("bob", "accord", -300 + 101, 10, 0) == "ok", "edge to edge accepted (dx 101)")
check(validate("bob", "accord", -300 + 101, 10, 101) == "ok", "corner to corner accepted")
check(M.claim_at({x = -350, y = 5, z = 50}) == a, "claim_at corner")
check(M.claim_at({x = -351, y = 5, z = 0}) == nil, "claim_at outside x")
check(M.claim_at({x = -300, y = -100, z = 0}) == a, "claim_at y -100")
check(M.claim_at({x = -300, y = -101, z = 0}) == nil, "claim_at y -101")
check(M.claim_at({x = -300, y = 31000, z = 0}) == a, "claim_at unbounded up")
local b = M.create("bob", {x = -199, y = 10, z = 0})
check(M.claim_at({x = -250, y = 0, z = 0}) == a and M.claim_at({x = -249, y = 0, z = 0}) == b,
	"edge-to-edge claims split at the shared edge")

-- ---------------------------------------------------------------------------
-- 2. Protection (grug_housing/protection.lua over a world-protection stub)
-- ---------------------------------------------------------------------------
out("-- protection")
local nodes = {}
local FACTION = {alice = "accord", bob = "accord", carol = "accord",
	dave = "accord", erin = "throng", admin = "accord"}
local guards = {world = {}, renewal = {}}
local core_loaded, core_after = {}, {}
local function install_core()
	_G.core = {
		registered_nodes = {air = {}, ["default:dirt"] = {},
			["default:grass_1"] = {buildable_to = true},
			["default:snow"] = {buildable_to = true}},
		register_on_mods_loaded = function(fn) core_loaded[#core_loaded + 1] = fn end,
		register_on_leaveplayer = function() end,
		after = function(_, fn) core_after[#core_after + 1] = fn end,
		log = function() end,
		get_node_or_nil = function(pos)
			return {name = nodes[pos.x .. "/" .. pos.y .. "/" .. pos.z] or "air"}
		end,
		check_player_privs = function(name, privs)
			return name == "admin" and privs.protection_bypass == true
		end,
	}
	-- World protection: the other faction's home land, everything for "".
	function core.is_protected(pos, name)
		if name == "" then return true end
		if name == "admin" then return false end
		return FACTION[name] ~= "accord"
	end
	_G.grug_core = {
		register_world_alteration_guard = function(fn) guards.world[#guards.world + 1] = fn end,
		register_natural_renewal_guard = function(fn) guards.renewal[#guards.renewal + 1] = fn end,
	}
	_G.grug_housing = {model = M, STONE_ITEM = "grug_housing:claim_stone",
		EMPTY_STONE = "grug_housing:claim_stone_empty",
		DRAFT_STONE = "grug_housing:claim_stone_draft",
		STONE_NODES = {["grug_housing:claim_stone"] = true,
			["grug_housing:claim_stone_empty"] = true,
			["grug_housing:claim_stone_draft"] = true}}
end
install_core()
dofile(housing_dir .. "/protection.lua")
local P = core.is_protected
local function at(x, y, z) return {x = x, y = y, z = z} end
local inside, outside = at(-320, 12, 20), at(-500, 12, 0)
a.permissions.carol = "everything"
a.permissions.dave = "interact"
-- Round 26 ruling 8: a draft protects nothing, keeps the arrival cube and
-- (above) reserves its square against other claims.
check(M.is_draft(a) and not M.is_active(a), "a new claim is a draft, not active")
check(M.draft_remaining(a) == 300, "draft: 5 minutes to activate")
check(P(inside, "bob") == false and P(inside, "erin") == true,
	"draft protects nothing (world protection still applies)")
check(P(at(-299, 13, 1), "alice") == true and P(at(-299, 13, 1), "bob") == true,
	"draft keeps the arrival cube free")
check(M.add_fuel(a, 3) == 0 and M.is_draft(a), "a draft takes no fuel")
-- Ruling 9: activation with at least 5 lumps.
local burnt, why = M.activate(a, 4)
check(burnt == 0 and why == "too_few" and M.is_draft(a), "4 lumps do not activate")
check(M.activate(a, 5) == 5 and not M.is_draft(a) and M.is_active(a),
	"5 lumps activate")
check(a.activated_at == clock and a.paid_until == clock + 5 * M.LUMP_SECONDS,
	"activation starts the fuel at once")
check(select(2, M.activate(a, 5)) == "active", "an active claim is not activated twice")
check(M.draft_remaining(a) == 0, "an activated claim is no draft")
check(P(inside, "alice") == false, "owner digs and places")
check(P(inside, "carol") == false, "everything digs and places")
check(P(inside, "dave") == true, "interact is refused digging and placing")
check(P(inside, "bob") == true, "stranger refused")
check(P(inside, "erin") == true, "enemy faction refused")
a.permissions.erin = "everything"
check(P(inside, "erin") == true, "enemy faction refused even with everything")
a.permissions.erin = nil
check(P(inside, "admin") == false, "protection_bypass passes")
check(P(inside, "") == true, "empty name stays protected")
check(P(outside, "bob") == false, "outside every claim: world rule only")
check(P(at(-300, -101, 0), "bob") == false, "below y -100 not claimed")
check(P(at(-300, 500, 0), "bob") == true, "high above the stone still claimed")
-- Arrival cube: placement targets refused for everyone, fuel or not.
local cube = at(-299, 13, 1)
check(P(cube, "alice") == true, "arrival cube: owner cannot place")
check(P(cube, "carol") == true, "arrival cube: everything cannot place")
nodes["-299/13/1"] = "default:grass_1"
check(P(cube, "alice") == true, "arrival cube: buildable_to counts as placement")
nodes["-299/13/1"] = "default:dirt"
check(P(cube, "alice") == false, "arrival cube: owner may dig a solid node")
nodes["-299/13/1"] = nil
check(P(at(-299, 14, 1), "alice") == false and P(at(-298, 11, 1), "alice") == false,
	"arrival cube is exactly 3 x 3 x 3 above the stone")
-- Guards.
local function world_guard(pos)
	for _, fn in ipairs(guards.world) do if fn(pos) == false then return false end end
	return true
end
local function renewal_guard(pos)
	for _, fn in ipairs(guards.renewal) do if fn(pos) == false then return false end end
	return true
end
check(world_guard(cube) == false, "liquid guard refuses the arrival cube")
check(world_guard(inside) == true, "liquid guard allows the rest of the claim")
check(renewal_guard(inside) == false, "no renewal inside an active claim")
check(renewal_guard(outside) == true, "renewal outside claims")
-- R26 ruling 12: snow (buildable_to) in the arrival cube. Placing into it
-- stays refused; digging it (the dig context the on_dig wrapper sets) is
-- judged like the rest of the claim.
nodes["-299/13/1"] = "default:snow"
for _, fn in ipairs(core_loaded) do fn() end
for _, fn in ipairs(core_after) do fn() end
local snow_def = core.registered_nodes["default:snow"]
check(type(snow_def.on_dig) ~= "function", "stub snow has no on_dig before the test")
do
	local seen = {}
	local function player(name)
		return {is_player = function() return true end,
			get_player_name = function() return name end}
	end
	-- Install the wrapper on a snow def with callbacks, as in the engine.
	core.registered_nodes["default:snow"] = {buildable_to = true,
		on_dig = function(pos, _, digger)
			seen[#seen + 1] = digger:get_player_name() .. ":" .. tostring(P(pos,
				digger:get_player_name()))
			return true
		end,
		on_punch = function(pos, _, puncher)
			seen[#seen + 1] = "punch " .. puncher:get_player_name() .. ":" ..
				tostring(P(pos, puncher:get_player_name()))
		end}
	for _, fn in ipairs(core_after) do fn() end
	local snow = core.registered_nodes["default:snow"]
	check(P(cube, "alice") == true, "snow in the cube: placing into it refused (owner)")
	snow.on_dig(cube, {name = "default:snow"}, player("alice"))
	snow.on_dig(cube, {name = "default:snow"}, player("carol"))
	snow.on_dig(cube, {name = "default:snow"}, player("dave"))
	snow.on_dig(cube, {name = "default:snow"}, player("bob"))
	snow.on_punch(cube, {name = "default:snow"}, player("alice"))
	check(table.concat(seen, ",") ==
		"alice:false,carol:false,dave:true,bob:true,punch alice:false",
		"snow in the cube: owner and everything dig and punch it, interact and " ..
		"strangers not (" .. table.concat(seen, ",") .. ")")
	check(P(cube, "alice") == true, "after the dig the cube refuses placing again")
	nodes["-299/13/1"] = nil
	check(P(cube, "alice") == true, "air in the cube: still refused")
	core.registered_nodes["default:snow"] = snow_def
end

-- Expiry by the wall clock.
clock = clock + 5 * M.LUMP_SECONDS
check(not M.is_active(a), "claim expires by the wall clock")
check(P(inside, "bob") == false, "empty claim protects nothing")
check(P(cube, "bob") == true, "empty claim keeps the arrival cube")
check(renewal_guard(inside) == true, "expired claim renews (ruling 19)")
check(renewal_guard(cube) == false, "no renewal into the arrival cube")
check(world_guard(cube) == false, "empty claim keeps the liquid guard")
check(validate("carol", "accord", -300 + 100, 10, 0) == "overlap",
	"empty claim still blocks other claims")

-- ---------------------------------------------------------------------------
-- 3. Fuel
-- ---------------------------------------------------------------------------
out("-- fuel")
local L = M.LUMP_SECONDS
check(M.remaining_seconds(a) == 0 and M.fuel_room(a) == 99, "empty: room 99")
check(M.add_fuel(a, 0) == 0 and M.add_fuel(a, -5) == 0, "no fuel for count <= 0")
local t0 = clock
check(M.add_fuel(a, 150) == 99, "slot takes at most 99")
check(a.paid_until == t0 + 99 * L, "paid until now + 99 lumps")
check(M.add_fuel(a, 1) == 0, "full slot takes nothing")
clock = t0 + L / 2
check(M.fuel_room(a) == 0, "half a lump burnt: still 99 started lumps")
check(M.refund_lumps(a) == 98, "refund: 98 whole lumps")
clock = t0 + L
check(M.fuel_room(a) == 1 and M.add_fuel(a, 5) == 1, "one burnt lump: room 1, accepted 1")
check(M.remaining_seconds(a) == 99 * L, "remaining after top-up")
clock = t0 + L + 3 * L + 1
check(M.fuel_room(a) == 3 and M.refund_lumps(a) == 95, "3 lumps and a second burnt")
check(#M.expiry_scan() == 0, "no expiry report while fuelled")
clock = a.paid_until
check(not M.is_active(a) and M.remaining_seconds(a) == 0, "expired at paid_until")
local reported = M.expiry_scan()
check(#reported >= 1 and reported[1] == a, "expiry reported")
check(#M.expiry_scan() == 0, "expiry reported once")
check(M.refund_lumps(a) == 0, "nothing to refund when empty")
-- Ruling 20: refuelling an empty stone makes the claim active again.
check(P(inside, "bob") == false, "expired: open to everyone")
check(M.add_fuel(a, 2) == 2 and M.is_active(a), "ruling 20: refuel reactivates")
check(P(inside, "bob") == true, "ruling 20: protection is back")
check(renewal_guard(inside) == false, "ruling 20: renewal stops again")
check(M.remaining_seconds(a) == 2 * L, "refuel counts from now, not from the old expiry")
-- Server downtime counts: jump the clock (as after a restart).
clock = clock + 2 * L + 100
check(not M.is_active(a), "downtime burns fuel")
local again = M.expiry_scan()
check(#again == 1 and again[1] == a, "the new expiry is reported again")

-- ---------------------------------------------------------------------------
-- 4. Daily limits and state transitions
-- ---------------------------------------------------------------------------
out("-- states")
check(M.player_state("zed") == "never" and select(2, M.player_claim("zed")) == "never",
	"unknown player: never")
check(not M.issue("zed", 19, false), "level 19 refused")
check(M.issue("zed", 20, false) and M.player_state("zed") == "carried", "level 20: carried")
check(not M.issue("zed", 20, true), "refused while carrying")
check(M.issue("zed", 20, false) and M.player_state("zed") == "carried",
	"carried but lost (not held): reissued")
check(M.stone_lost("zed") and M.player_state("zed") == "needs_stone", "dropped: needs_stone")
check(M.issue("zed", 25, false) and M.player_state("zed") == "carried", "needs_stone -> carried")
clock = clock + 10 * 86400
local zc = M.create("zed", {x = 300, y = 10, z = 0})
local claim_of, state_of = M.player_claim("zed")
check(claim_of == zc and state_of == "placed", "placed: player_claim returns the claim")
check(not M.issue("zed", 25, false), "refused while placed")
check(not M.is_active(zc) and M.is_draft(zc) and
	select(2, M.player_claim("zed")) == "placed", "a draft is placed")
-- R26 ruling 8: a draft comes back at any time, and no placing lock follows.
check(M.pickup_wait(zc) == 0, "draft: no pick-up lock")
M.remove(zc, "picked_up")
check(M.player_state("zed") == "carried" and M.player_claim("zed") == nil, "picked up: carried")
check(validate("zed", "accord", 300, 10, 0) == "ok",
	"ruling 10: no placing lock, placing again at once after a pick-up")
zc = M.create("zed", {x = 300, y = 10, z = 0})
check(M.activate(zc, 5) == 5, "activated")
-- R26 ruling 10: the only lock, 12 h after activation.
check(M.PICKUP_LOCK_SECONDS == 12 * 3600 and M.pickup_wait(zc) == 12 * 3600,
	"pick-up locked 12 h after activation")
clock = clock + 12 * 3600 - 1
check(M.pickup_wait(zc) == 1, "one second before 12 h still locked")
clock = clock + 1
check(M.pickup_wait(zc) == 0, "pick-up allowed after 12 h")
M.remove(zc, "picked_up")
check(validate("zed", "accord", 300, 10, 0) == "ok", "placing again at once after the pick-up")
zc = M.create("zed", {x = 300, y = 10, z = 0})
M.activate(zc, 5)
M.remove(zc, "destroyed")
check(M.player_state("zed") == "destroyed", "dug: destroyed")
check(M.issue("zed", 30, false) and M.player_state("zed") == "carried", "destroyed -> carried")
check(validate("zed", "accord", 300, 10, 0) == "ok",
	"after destruction a new stone is placed at once (no lock)")
-- R26 ruling 8: a draft lasts 5 minutes; the owner gets a new stone at once.
zc = M.create("zed", {x = 300, y = 10, z = 0})
local function in_draft_scan(claim)
	for _, c in ipairs(M.draft_scan()) do if c == claim then return true end end
	return false
end
check(#M.expiry_scan() == 0, "a draft is never reported as fuel expiry")
clock = clock + M.DRAFT_SECONDS - 1
check(not in_draft_scan(zc) and M.draft_remaining(zc) == 1, "draft alive at 4:59")
clock = clock + 1
check(in_draft_scan(zc) and M.draft_remaining(zc) == 0, "draft expires at 5:00")
M.remove(zc, "draft_expired")
check(M.player_state("zed") == "needs_stone" and M.claim_by_id(zc.id) == nil,
	"expired draft: needs_stone, claim gone")
check(M.issue("zed", 30, false) and M.player_state("zed") == "carried",
	"a new stone at once after the draft expired")
zc = M.create("zed", {x = 300, y = 10, z = 0})
check(M.activate(zc, 150) == 99 and M.remaining_seconds(zc) == 99 * M.LUMP_SECONDS,
	"activation burns at most 99 lumps")
clock = clock + M.DRAFT_SECONDS + 1
check(not in_draft_scan(zc), "an activated claim never expires as a draft")
M.remove(zc, "picked_up")
check(M.set_permission(b, "carol", "interact") and M.permission(b, "carol") == "interact",
	"set permission")
check(not M.set_permission(b, "bob", "everything"), "owner is no list entry")
check(not M.set_permission(b, "x y", "everything"), "invalid name refused")
check(not M.set_permission(b, "carol", "admin"), "unknown level refused")
check(M.set_permission(b, "carol", nil) and M.permission(b, "carol") == nil, "remove permission")
check(M.permission(b, "bob") == "owner", "owner permission")
M.set_permission(b, "dave", "everything")

-- ---------------------------------------------------------------------------
-- 5. Soulbound, the stone and the pick capability (stone.lua, soulbound.lua)
-- ---------------------------------------------------------------------------
out("-- soulbound and stone")
local ItemStackMT = {}
ItemStackMT.__index = ItemStackMT
local function ItemStack(value)
	local name, count = "", 0
	if type(value) == "string" and value ~= "" then
		name = value:match("^(%S+)"); count = tonumber(value:match("%s(%d+)$")) or 1
	elseif type(value) == "table" then name, count = value.name, value.count end
	return setmetatable({name = name, count = count}, ItemStackMT)
end
function ItemStackMT:get_name() return self.name end
function ItemStackMT:get_count() return self.count end
function ItemStackMT:is_empty() return self.count == 0 or self.name == "" end
function ItemStackMT:take_item(n) self.count = self.count - (n or 1); if self.count <= 0 then self.name = "" end end
_G.ItemStack = ItemStack
local registered_items = {}
local item_groups = {}
local mods_loaded, allow_player, globalsteps = {}, {}, {}
local chest_meta = {}
core.registered_items = registered_items
core.registered_nodes = {}
core.detached_inventories = {}
core.get_item_group = function(name, group)
	local def = registered_items[name]
	return def and def.groups and def.groups[group] or 0
end
core.register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end
core.register_allow_player_inventory_action = function(fn) allow_player[#allow_player + 1] = fn end
core.register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end
core.register_node = function(name, def)
	def.name = name
	registered_items[name] = def
	core.registered_nodes[name] = def
end
core.register_tool = function(name, def) def.name = name registered_items[name] = def end
core.override_item = function(name, fields)
	for key, value in pairs(fields) do registered_items[name][key] = value end
end
core.get_meta = function() return {get_inventory = function()
	return {get_stack = function(_, list, index) return chest_meta[list .. index] or ItemStack("") end}
end} end
local created_detached = {}
core.create_detached_inventory = function(name, callbacks)
	core.detached_inventories[name] = callbacks
	created_detached[name] = callbacks
	return {}
end
core.chat_send_player = function() end
core.log = function() end
core.pos_to_string = function(p) return p.x .. "," .. p.y .. "," .. p.z end
table.copy = table.copy or function(t)
	local function copy(v)
		if type(v) ~= "table" then return v end
		local r = {}
		for k, x in pairs(v) do r[k] = copy(x) end
		return r
	end
	return copy(t)
end
grug_core.flash = function() return true end
-- Existing inventories before grug_housing loads.
core.register_node("default:chest", {groups = {}})
core.register_node("default:furnace", {groups = {},
	allow_metadata_inventory_put = function(_, listname, _, stack)
		return listname == "fuel" and stack:get_count() or 0
	end})
core.register_tool("default:pick_wood", {groups = {grug_pick_tier = 1},
	tool_capabilities = {groupcaps = {cracky = {times = {[3] = 1}, maxlevel = 0}}}})
for tier = 1, 6 do
	core.register_tool("grug_materials:pick_t" .. tier, {groups = {grug_pick_tier = tier},
		tool_capabilities = {groupcaps = {cracky = {times = {[3] = 1}, maxlevel = tier - 1}}}})
end
core.register_tool("grug_abilities:strike", {groups = {grug_bound_skill = 1},
	tool_capabilities = {groupcaps = {dig_immediate = {times = {[2] = 0.3}}}}})
core.detached_inventories["creative_trash"] = {}
grug_housing.notify_claim_changed = function(claim, event)
	grug_housing.last_event = {claim = claim, event = event}
end
grug_housing.sync_stone_node = function() end
dofile(housing_dir .. "/stone.lua")
dofile(housing_dir .. "/soulbound.lua")
for _, fn in ipairs(mods_loaded) do fn() end
local STONE = "grug_housing:claim_stone"
local stone = ItemStack(STONE)
local coal = ItemStack("default:coal_lump 5")
local function player_action(action, info, inv)
	for _, fn in ipairs(allow_player) do
		local result = fn({}, action, inv, info)
		if result ~= nil then return result end
	end
	return nil
end
local main_inv = {get_stack = function(_, list, index)
	return list == "main" and index == 1 and stone or ItemStack("")
end}
check(player_action("move", {from_list = "main", from_index = 1, to_list = "main",
	to_index = 5}, main_inv) == nil, "stone moves within main")
for _, list in ipairs({"craft", "grug_bag1_content", "grug_bag1", "grug_equip_offhand"}) do
	check(player_action("move", {from_list = "main", from_index = 1, to_list = list,
		to_index = 1}, main_inv) == 0, "stone refused moving to " .. list)
	check(player_action("put", {listname = list, stack = stone}, main_inv) == 0,
		"stone refused put into " .. list)
end
check(player_action("put", {listname = "craft", stack = coal}, main_inv) == nil,
	"coal moves freely")
local chest = registered_items["default:chest"]
check(chest.allow_metadata_inventory_put(nil, "main", 1, stone) == 0, "chest refuses the stone")
check(chest.allow_metadata_inventory_put(nil, "main", 1, coal) == 5, "chest takes coal")
chest_meta.main1 = stone
check(chest.allow_metadata_inventory_move({}, "main", 1, "main", 2, 1) == 0,
	"chest refuses moving a stone inside it")
local furnace = registered_items["default:furnace"]
check(furnace.allow_metadata_inventory_put(nil, "fuel", 1, stone) == 0 and
	furnace.allow_metadata_inventory_put(nil, "fuel", 1, coal) == 5,
	"furnace refuses the stone, keeps its own rule")
check(core.detached_inventories.creative_trash.allow_put(nil, "main", 1, stone) == 0,
	"existing detached inventory (trash) refuses the stone")
core.create_detached_inventory("grug_jobs_workspace", {allow_put = function() return 7 end})
local ws = created_detached.grug_jobs_workspace
check(ws.allow_put(nil, "input", 1, stone) == 0 and ws.allow_put(nil, "input", 1, coal) == 7,
	"new detached inventory (workspace, trade window) refuses the stone")
local sdef = registered_items[STONE]
check(sdef._grug_sell_price == nil, "stone has no sell price: no vendor trade")
check(sdef.stack_max == 1 and sdef.groups.grug_soulbound == 1, "stone is a soulbound single item")
-- Drop destroys the stone and records needs_stone.
M.issue("yan", 20, false)
local dropper = {is_player = function() return true end,
	get_player_name = function() return "yan" end}
local left = sdef.on_drop(ItemStack(STONE), dropper, {x = 0, y = 0, z = 0})
check(left:is_empty() and M.player_state("yan") == "needs_stone", "drop destroys: needs_stone")
-- Dig rules: fuelled nobody, empty only with a pick; engine caps per tier.
check(sdef.can_dig() == false and next(sdef.groups) and not sdef.groups.grug_claim_stone,
	"fuelled stone: no dig group, can_dig false")
local edef = registered_items["grug_housing:claim_stone_empty"]
check(edef.groups.grug_claim_stone == 1 and edef.drop == "" and sdef.drop == "",
	"empty stone: dig group; ruling 21: no drop from either stone")
-- R26 ruling 8: the draft is half-transparent and nobody digs it.
local ddef = registered_items["grug_housing:claim_stone_draft"]
check(ddef ~= nil and ddef.use_texture_alpha == "blend" and
	ddef.tiles[1]:find("^[opacity:", 1, true) ~= nil, "draft: half-transparent")
check(ddef.can_dig() == false and not ddef.groups.grug_claim_stone and
	not ddef.groups.grug_soulbound and ddef.groups.grug_claim_stone_node == 1 and
	ddef.drop == "", "draft: no dig group, can_dig false, no drop, no item")
local times = {}
for tier = 1, 6 do
	local caps = registered_items["grug_materials:pick_t" .. tier].tool_capabilities
	times[tier] = caps.groupcaps.grug_claim_stone.times[1]
	check(caps.groupcaps.cracky ~= nil, "pick keeps its caps T" .. tier)
end
check(table.concat(times, ",") == "60,50,40,30,20,10", "pick times T1-T6 60..10 s")
check(registered_items["default:pick_wood"].tool_capabilities.groupcaps.grug_claim_stone.times[1] == 60,
	"starter pick digs in the T1 time")
check(registered_items["grug_abilities:strike"].tool_capabilities.groupcaps.grug_claim_stone == nil,
	"skill hand has no claim-stone cap")
local function digger(tool)
	return {is_player = function() return true end, get_player_name = function() return "bob" end,
		get_wielded_item = function() return ItemStack(tool) end}
end
local stone_pos = {x = b.center.x, y = b.center.y, z = b.center.z}
clock = clock + 1
M.activate(b, 5)
check(edef.can_dig(stone_pos, digger("grug_materials:pick_t3")) == false,
	"empty-variant node of a fuelled claim refuses")
clock = b.paid_until + 1
check(edef.can_dig(stone_pos, digger("grug_materials:pick_t3")) == true, "empty claim: pick digs")
check(edef.can_dig(stone_pos, digger("")) == false, "empty claim: hand cannot")
check(edef.can_dig(stone_pos, digger("grug_abilities:strike")) == false,
	"empty claim: skill hand cannot")
core.get_player_by_name = function() return nil end
edef.after_dig_node(stone_pos, {name = "grug_housing:claim_stone_empty"}, nil, digger("x"))
check(M.claim_by_id(b.id) == nil and M.player_state("bob") == "destroyed" and
	grug_housing.last_event.event == "destroyed" and grug_housing.last_event.claim == b,
	"dig removes the claim, bob destroyed, event with the claim table")
-- The periodic check (stone.lua's globalstep): an expired draft crumbles, its
-- node goes, the owner needs a new stone; a standing stone stays.
do
	nodes[a.center.x .. "/" .. a.center.y .. "/" .. a.center.z] = STONE
	M.issue("yan", 20, false)
	local yd = M.create("yan", {x = 9000, y = 0, z = 9000})
	nodes["9000/0/9000"] = "grug_housing:claim_stone_draft"
	local removed = {}
	grug_housing.remove_stone_node = function(claim)
		removed[#removed + 1] = claim.id
		nodes[claim.center.x .. "/" .. claim.center.y .. "/" .. claim.center.z] = nil
	end
	local told = {}
	core.get_player_by_name = function(name)
		return {get_player_name = function() return name end}
	end
	core.chat_send_player = function(name, text) told[#told + 1] = name .. ": " .. text end
	globalsteps[1](5)
	check(M.claim_by_id(yd.id) ~= nil and #removed == 0, "a fresh draft survives the check")
	clock = clock + M.DRAFT_SECONDS
	globalsteps[1](5)
	check(M.claim_by_id(yd.id) == nil and removed[1] == yd.id and
		M.player_state("yan") == "needs_stone" and
		grug_housing.last_event.event == "draft_expired",
		"an expired draft crumbles: node removed, needs_stone, event")
	check(#told == 1 and told[1]:find("Housing Steward", 1, true) ~= nil,
		"the owner is told to fetch a new stone from a Housing Steward")
	check(M.claim_by_id(a.id) ~= nil, "a standing activated stone is kept")
	core.get_player_by_name = function() return nil end
	core.chat_send_player = function() end
end

-- ---------------------------------------------------------------------------
-- 6. Persistence
-- ---------------------------------------------------------------------------
out("-- persistence")
M.create("dave", {x = 5000, y = -40, z = 5000}).permissions = {}
local d = M.player_claim("dave")
M.set_permission(d, "erin", "interact")
M.set_permission(d, "alice", "everything")
M.activate(d, 7)
M.issue("carol", 20, false)
M.create("carol", {x = -5000, y = 3, z = 5000}) -- a draft
local N = new_model(storage)
local function snapshot(model)
	local lines = {}
	for _, claim in ipairs(model.all_claims()) do
		local names = {}
		for name, level in pairs(claim.permissions) do names[#names + 1] = name .. "=" .. level end
		table.sort(names)
		lines[#lines + 1] = table.concat({claim.id, claim.owner, claim.center.x,
			claim.center.y, claim.center.z, claim.placed_at, claim.activated_at,
			claim.paid_until, claim.expired_for, table.concat(names, ",")}, "|")
	end
	for _, name in ipairs({"alice", "bob", "carol", "dave", "zed", "yan", "nobody"}) do
		local claim, state = model.player_claim(name)
		lines[#lines + 1] = name .. ":" .. state .. ":" .. (claim and claim.id or "-") ..
			":" .. model.pickup_wait(claim) .. ":" .. model.draft_remaining(claim)
	end
	return table.concat(lines, "\n")
end
local s1, s2 = snapshot(M), snapshot(N)
check(s1 == s2, "second model reads back the same state")
check(N.claim_at({x = 5050, y = 0, z = 4950}).id == d.id, "claim grid rebuilt on load")
check(N.claim_count() == M.claim_count(), "claim count after load")
out(s2)

-- ---------------------------------------------------------------------------
-- 7. Real world
-- ---------------------------------------------------------------------------
if seed ~= "none" then
	out("-- real world, seed " .. seed)
	-- The real world of tools/r25_road_poi/world.lua: the zones session with
	-- water and roads, the R7 overlay, main's POI, village and camp
	-- blueprints and the world protection built from them (the settlement
	-- cores grug_core.world_feature_boxes_in asks). As there, each capital's
	-- protected city is stood in by a 241-node square round its anchor.
	local started = os.clock()
	local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
	local Z, source = W.session, W.source
	out(("world built in %.1f s"):format(os.clock() - started))
	check(type(Z.hard_footprint_in) == "function" and Z.claim_exclusion_in == nil,
		"overlay publishes hard_footprint_in, no claim_exclusion_in")
	check(Z.housing_eligible_at == nil and Z.housing_mask_id_at == nil,
		"housing masks gone from the session")
	local function hard_at(x, z)
		return Z.hard_protection_kind_at({x = x, y = 30000, z = z})
	end

	-- hard_footprint_in is exact: it equals a column-by-column scan of the
	-- hard protection over 7 x 7 rectangles walked outward from every start
	-- town, capital, apex socket and functional column in eight directions,
	-- across the footprint's edge.
	local landmark_columns = {}
	for _, row in ipairs(W.roster.rows) do
		if row.family == "outpost" or row.family == "bandit" then
			landmark_columns[#landmark_columns + 1] = {x = row.x, z = row.z}
		end
	end
	local town_centres = {}
	for _, row in ipairs(source.hard_protection) do
		if row.recipe_id == "hard_apex_socket_column_v1" then
			landmark_columns[#landmark_columns + 1] = {x = row.center.x, z = row.center.z}
		else
			town_centres[#town_centres + 1] = {x = row.center.x, z = row.center.z,
				reach = row.recipe_id == "hard_capital_city_v1" and 276 or 86}
		end
	end
	do
		local function brute(min_x, min_z, max_x, max_z)
			for z = min_z, max_z do
				for x = min_x, max_x do
					if hard_at(x, z) then return true end
				end
			end
			return false
		end
		local rays = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
		local centres = {}
		for _, t in ipairs(town_centres) do centres[#centres + 1] = t end
		for _, c in ipairs(landmark_columns) do
			centres[#centres + 1] = {x = c.x, z = c.z, reach = 10}
		end
		local tried, differ, hits = 0, 0, 0
		for _, c in ipairs(centres) do
			for _, ray in ipairs(rays) do
				for d = 0, c.reach do
					local x, z = c.x + ray[1] * d, c.z + ray[2] * d
					local found = Z.hard_footprint_in(x - 3, z - 3, x + 3, z + 3) ~= nil
					local truth = brute(x - 3, z - 3, x + 3, z + 3)
					tried = tried + 1
					if found then hits = hits + 1 end
					if found ~= truth then differ = differ + 1 end
				end
			end
		end
		check(differ == 0, "hard_footprint_in equals the column scan (" .. differ ..
			" of " .. tried .. " differ)")
		out(("hard_footprint_in: %d rectangles across %d footprint edges, %d touch," ..
			" %d differ from the column scan"):format(tried, #centres, hits, differ))
	end

	local zone_records = {}
	local real = {}
	function real.zone_at(x, z)
		local id = Z.id_at(x, z)
		if not id then return nil end
		local record = zone_records[id]
		if not record then record = Z.get(id); zone_records[id] = record end
		return record
	end
	function real.territory_at(x, z) return Z.territory_rule_at({x = x, y = 30000, z = z}) end
	-- As api.lua: the settlement cores (grug_core.world_feature_boxes_in), then
	-- the hard footprints of the widened square.
	function real.feature_in(min_x, min_z, max_x, max_z, margin)
		if W.protection.boxes_in(min_x, min_z, max_x, max_z, margin) then return "site" end
		local _, kind = Z.hard_footprint_in(min_x - margin, min_z - margin,
			max_x + margin, max_z + margin)
		return kind
	end
	function real.cube_clear() return true end
	function real.water_class_at(x, z) return Z.water_class_at(x, z) end
	local R = new_model(new_storage())
	local function real_validate(x, z, faction)
		local y = Z.terrain_height_at(x, z) + 1
		local ok, code = R.validate("probe", faction or "accord", {x = x, y = y, z = z}, real)
		return ok and "ok" or code, y
	end

	-- Every start town and a point in every L1-10 zone refuse.
	for _, anchor in ipairs(source.anchors) do
		if anchor.slot_id == "start" then
			local faction = Z.get(Z.id_at(anchor.position.x, anchor.position.z)).faction
			local code = real_validate(anchor.position.x, anchor.position.z + 200, faction)
			check(code ~= "ok", "near start " .. anchor.id .. " refused (" .. code .. ")")
			local at_town = real_validate(anchor.position.x, anchor.position.z, faction)
			check(at_town == "town", "at start " .. anchor.id .. ": town (" .. at_town .. ")")
		end
	end
	-- A lattice of candidate centres (spacing 101, edge to edge) over the map.
	local census, accepted = {}, {}
	local t_start = os.clock()
	local count = 0
	for x = -2600, 2600, 101 do
		for z = -2600, 2600, 101 do
			local id = Z.id_at(x, z)
			local zone = id and real.zone_at(x, z)
			if zone and zone.faction then
				local code = real_validate(x, z, zone.faction)
				count = count + 1
				census[code] = (census[code] or 0) + 1
				if code == "ok" then accepted[#accepted + 1] = {x = x, z = z, zone = zone} end
			end
		end
	end
	local elapsed = os.clock() - t_start
	local codes = {}
	for code, n in pairs(census) do codes[#codes + 1] = code .. " " .. n end
	table.sort(codes)
	out(("census: %d home-faction centres, %s; %.2f ms per validation"):format(count,
		table.concat(codes, ", "), 1000 * elapsed / count))
	check(#accepted > 0, "some eligible spots exist")
	-- Every accepted square: exhaustively re-check all 10201 columns, and the
	-- ring of the square widened by 16 against every hard column and every
	-- settlement core (ruling 27).
	local margin = R.SETTLEMENT_MARGIN
	local boxes = W.wp.settlement_boxes(W.rows)
	local function box_gap(box, x, z)
		local gx = math.max(box.min_x - x, x - box.max_x, 0)
		local gz = math.max(box.min_z - z, z - box.max_z, 0)
		return math.max(gx, gz)
	end
	local exhaustive_bad, ring_bad = 0, 0
	local by_zone = {}
	for _, spot in ipairs(accepted) do
		by_zone[spot.zone.id] = (by_zone[spot.zone.id] or 0) + 1
		for dx = -50, 50 do
			for dz = -50, 50 do
				local zone = real.zone_at(spot.x + dx, spot.z + dz)
				local territory = zone and real.territory_at(spot.x + dx, spot.z + dz)
				local water = real.water_class_at(spot.x + dx, spot.z + dz)
				if (water ~= "land" and water ~= "planned_water") or
						not zone or zone.faction ~= spot.zone.faction or zone.level_min < 11 or
						zone.level_max > 30 or zone.civic_no_hostiles or
						territory ~= zone.faction .. "_home" then
					exhaustive_bad = exhaustive_bad + 1
				end
			end
		end
		local reach = 50 + margin
		for dx = -reach, reach do
			for dz = -reach, reach do
				if (dx < -50 or dx > 50 or dz < -50 or dz > 50) and
						hard_at(spot.x + dx, spot.z + dz) then
					ring_bad = ring_bad + 1
				end
			end
		end
		for _, box in ipairs(boxes) do
			if box_gap(box, spot.x, spot.z) <= reach then ring_bad = ring_bad + 1 end
		end
	end
	check(exhaustive_bad == 0, "accepted squares hold only eligible columns (exhaustive: " ..
		exhaustive_bad .. " bad)")
	check(ring_bad == 0, "ruling 27: no hard column or settlement core within 16 of an" ..
		" accepted square (exhaustive: " .. ring_bad .. " bad)")
	local zone_list = {}
	for id, n in pairs(by_zone) do zone_list[#zone_list + 1] = id .. " " .. n end
	table.sort(zone_list)
	out("accepted by zone: " .. table.concat(zone_list, ", "))
	local first = accepted[1]
	out(("first accepted spot: %d,%d in %s (L%d-%d)"):format(first.x, first.z,
		first.zone.id, first.zone.level_min, first.zone.level_max))

	-- Minimum distance (in x and z: the larger of the two gaps) from an
	-- accepted lattice centre to each kind of feature. By construction at
	-- least 50 + 16 + 1 = 67.
	do
		local best = {}
		local function note(kind, d)
			if not best[kind] or d < best[kind] then best[kind] = d end
		end
		for _, spot in ipairs(accepted) do
			for _, box in ipairs(boxes) do note(box.kind, box_gap(box, spot.x, spot.z)) end
			for _, c in ipairs(landmark_columns) do
				note("landmark", math.max(math.abs(c.x - spot.x), math.abs(c.z - spot.z)))
			end
		end
		-- Towns: the exact distance by bisection on the raw session's query
		-- (no functional columns), for every spot whose town index box is
		-- nearer than the best exact answer so far.
		local order = {}
		for _, spot in ipairs(accepted) do
			local gap = math.huge
			for _, t in ipairs(town_centres) do
				local half = t.reach - 10
				gap = math.min(gap, math.max(math.abs(t.x - spot.x) - half,
					math.abs(t.z - spot.z) - half, 0))
			end
			order[#order + 1] = {spot = spot, gap = gap}
		end
		table.sort(order, function(a, b) return a.gap < b.gap end)
		local raw = W.raw_session
		for _, entry in ipairs(order) do
			if best.town and entry.gap >= best.town then break end
			local s = entry.spot
			local lo, hi = entry.gap, entry.gap + 600
			if raw.hard_footprint_in(s.x - hi, s.z - hi, s.x + hi, s.z + hi) then
				while lo < hi do
					local mid = math.floor((lo + hi) / 2)
					if raw.hard_footprint_in(s.x - mid, s.z - mid, s.x + mid, s.z + mid) then
						hi = mid
					else
						lo = mid + 1
					end
				end
				note("town", lo)
			end
		end
		local kinds = {}
		for kind, d in pairs(best) do
			kinds[#kinds + 1] = kind .. " " .. d
			check(d >= 67, "ruling 27: nearest " .. kind .. " at least 67 from a centre")
		end
		table.sort(kinds)
		out("nearest feature to an accepted lattice centre (max of the x and z gaps): " ..
			table.concat(kinds, ", "))
	end

	-- The engine smoke's village pair: a stone 20 nodes from a village core
	-- (refused) and one 70 nodes away, which the old blend envelope (the
	-- village's 160-node blend square, touched by the 101 square) refused.
	do
		local pairs_found, villages = 0, 0
		for _, box in ipairs(boxes) do
			if box.kind == "village" then
				villages = villages + 1
				local shown = false
				local anchor
				for _, row in ipairs(W.rows) do
					if row.key == box.id then anchor = row.anchor end
				end
				for _, dir in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local function at(d)
						local x = dir[1] > 0 and box.max_x + d or
							(dir[1] < 0 and box.min_x - d or anchor.x)
						local z = dir[2] > 0 and box.max_z + d or
							(dir[2] < 0 and box.min_z - d or anchor.z)
						return x, z
					end
					local fx, fz = at(70)
					local zone = real.zone_at(fx, fz)
					if zone and zone.faction then
						local far = real_validate(fx, fz, zone.faction)
						local nx, nz = at(20)
						local near = real_validate(nx, nz, zone.faction)
						local old = math.abs(fx - anchor.x) <= 81 + 50 and
							math.abs(fz - anchor.z) <= 81 + 50
						if far == "ok" then
							pairs_found = pairs_found + 1
							check(near == "site", "20 from " .. box.id .. " refused as site")
							check(old, "70 from " .. box.id .. " lies in the old blend envelope")
							if not shown then
								shown = true
								out(("village pair %s: 20 away %d,%d %s; 70 away %d,%d %s" ..
									" (inside the old blend envelope: %s)"):format(box.id, nx, nz,
									near, fx, fz, far, tostring(old)))
							end
						end
					end
				end
			end
		end
		check(pairs_found > 0, "a village has an eligible spot 70 from its core")
		out(("village pairs: %d of %d villages x 4 sides accept a stone 70 from the core"):format(
			pairs_found, villages))
	end

	-- is_protected cost: grug_core alone, then with grug_housing (0 / 50 claims).
	out("-- is_protected microbenchmark")
	local function load_core_protection()
		_G.core = {check_player_privs = function() return false end,
			get_node_or_nil = function() return {name = "air"} end,
			registered_nodes = {air = {}},
			register_on_mods_loaded = function() end,
			register_on_leaveplayer = function() end}
		function core.is_protected() return false end
		_G.grug_core = {
			get_player_faction = function() return "accord" end,
			zone_authority_installed = function() return true end,
			world_protected_for_faction = function(pos, faction)
				return Z.compatibility.world_protected_for_faction(pos, faction)
			end,
		}
		_G.grug_zones = Z
		dofile(repo .. "/mods/CORE/grug_core/protection.lua")
	end
	local positions = {}
	local lcg = 12345
	local function rand(n) lcg = (lcg * 1103515245 + 12345) % 2147483648; return lcg % n end
	for i = 1, 2000 do
		local spot = accepted[1 + rand(#accepted)]
		positions[i] = {x = spot.x - 50 + rand(101), y = rand(60), z = spot.z - 50 + rand(101)}
	end
	-- Three independent is_protected chains, measured interleaved; the best
	-- of several repetitions counts (LuaJIT trace and cache noise).
	load_core_protection()
	local base_fn = core.is_protected
	local function housing_chain(model)
		core.is_protected = base_fn
		_G.grug_housing = {model = model}
		dofile(housing_dir .. "/protection.lua")
		return core.is_protected
	end
	local empty_model = new_model(new_storage())
	local zero_fn = housing_chain(empty_model)
	local full_model = new_model(new_storage())
	for i = 1, math.min(50, #accepted) do
		local spot = accepted[i]
		local claim = full_model.create("owner" .. i, {x = spot.x, y = 20, z = spot.z})
		full_model.activate(claim, 10)
	end
	local fifty_fn = housing_chain(full_model)
	local inside = 0
	for i = 1, #positions do
		if full_model.claim_at(positions[i]) then inside = inside + 1 end
	end
	local function run(fn)
		local t = os.clock()
		for _ = 1, 10 do
			for i = 1, #positions do fn(positions[i], "probe") end
		end
		return (os.clock() - t) * 1e9 / (10 * #positions)
	end
	local chains = {{"grug_core only", base_fn}, {"+ grug_housing, 0 claims", zero_fn},
		{"+ grug_housing, " .. full_model.claim_count() .. " claims", fifty_fn}}
	local best = {}
	for _ = 1, 7 do
		for index, chain in ipairs(chains) do
			local ns = run(chain[2])
			if not best[index] or ns < best[index] then best[index] = ns end
		end
	end
	for index, chain in ipairs(chains) do
		out(("%-30s %6.0f ns per call"):format(chain[1], best[index]))
	end
	out(("%d positions (%d inside the %d claims), best of 7 x 10 rounds each;" ..
		" housing adds %.0f ns (0 claims) and %.0f ns (%d claims)"):format(#positions,
		inside, full_model.claim_count(), best[2] - best[1], best[3] - best[1],
		full_model.claim_count()))
	-- A protected answer must match: claimed positions refuse "probe".
	check(fifty_fn(positions[1], "probe") == (full_model.claim_at(positions[1]) ~= nil),
		"benchmark chain answers like the model")
end

if #failures > 0 then
	error(("R25 CLAIM CORE FIXTURE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print(("R25 CLAIM CORE FIXTURE PASS checks=%d"):format(checks))

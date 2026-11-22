-- Round 25 Lane A portable fixture (LuaJIT): the Claim Stone core.
--
--   luajit tools/r25_claim_core/fixture.lua "$PWD" [seed | none]
--
-- Runs the shipped bytes of mods/PLAYER/grug_housing (registry.lua,
-- protection.lua, soulbound.lua, stone.lua) and grug_core/protection.lua
-- against small engine stubs:
--   1. placement validation over a stub claim mask (Round 85: a claim is
--      the map chunk of its stone; the zone, water and settlement rules are
--      the mask's, tools/r85_mask): depth, faction, the mask's refusals with
--      their messages, the stone one node inside its chunk's edge, the
--      cube, the quota naming its kind, no mask; one claim per chunk,
--      neighbouring chunks accepted, claim_at at the chunk's corners;
--   2. protection by permission level, faction (world protection first),
--      protection_bypass, empty claims, the arrival cube; the liquid and the
--      renewal guards;
--   3. fuel arithmetic: accept limits, remaining time, pick-up refund, expiry
--      by the wall clock (fake clock), the expiry report, refuel (ruling 20);
--      Round 26: drafts protect nothing but reserve their chunk and keep
--      the arrival cube, activation (at least 5 lumps), and the owner digging
--      a buildable_to node (snow) in the arrival cube;
--   4. Round 26: the draft lifetime, the 12 h pick-up lock after activation,
--      no placing lock, and every state transition;
--   5. soulbound refusals (player lists but `main` and the bags, node
--      inventories, detached inventories) and the stone's drop, dig (no
--      drop, ruling 21) and pick-capability rules;
--   6. persistence: a second model over the same storage reads back the
--      same claims and records;
--   7. (unless "none") the real world of one seed (tools/r25_road_poi/
--      world.lua: zones, roads, settlement cores): hard_footprint_in against
--      a column scan, and the is_protected cost (grug_core alone vs with
--      grug_housing, 0 and 50 claims). The 101 x 101 placement census that
--      stood here went with the old square (Round 85).
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
-- 1. Placement validation
-- ---------------------------------------------------------------------------
-- Round 85: a claim is the map chunk of its stone, and the zone, water,
-- settlement, road and spawn rules are the claim mask's (claim_mask.lua, its
-- fixture tools/r85_mask), asked once per chunk; the synthetic zone world
-- of the 101 x 101 square went with them. A stub mask here: every chunk is
-- claim ground but those in `refused` (chunk key -> reason id).
local refused, quota_kind = {}, nil
local blocked_cube = {}
local mask = {
	ground = function(_, cx, cz)
		local why = refused[cx .. "," .. cz]
		if why then return false, why end
		return true
	end,
	quota_refusal = function() return quota_kind end,
	add_taken = function(taken) return taken end,
}
local world = {mask = mask, kind_name = function(id) return "the " .. id end}
function world.cube_clear(pos)
	return not blocked_cube[pos.x .. "/" .. pos.z]
end

local storage = new_storage()
local M = new_model(storage)
local function validate(name, faction, x, y, z, w)
	local ok, code = M.validate(name, faction, {x = x, y = y, z = z}, w or world)
	return ok and "ok" or code
end

out("-- validation")
-- x -300 lies in chunk -4 (x -352 .. -273), z 0 in chunk 0 (z -32 .. 47)
check(M.chunk_of(-300) == -4 and M.chunk_of(0) == 0, "the stone's chunk")
check(validate("alice", "accord", -300, 10, 0) == "ok", "accept on claim ground")
check(validate("alice", "accord", -300, -100, 0) == "ok", "accept at y = -100")
check(validate("alice", "accord", -300, -101, 0) == "too_deep", "refuse at y = -101")
check(validate("alice", nil, -300, 10, 0) == "no_faction", "refuse without faction")
for _, reason in ipairs({"enemy", "low_level", "not_home", "town", "site", "road", "camp",
		"leader", "place", "rare", "capital_ring"}) do
	refused["-4,0"] = reason
	check(validate("alice", "accord", -300, 10, 0) == reason, "the mask's refusal: " .. reason)
	local _, _, message = M.validate("alice", "accord", {x = -300, y = 10, z = 0}, world)
	check(message == M.MESSAGES[reason], "its own message: " .. reason)
end
refused["-4,0"] = "an_unknown_reason"
check(validate("alice", "accord", -300, 10, 0) == "not_ground", "an unknown reason: not ground")
refused["-4,0"] = nil
-- the stone at least one node inside its chunk's edge (its arrival cube)
for _, spot in ipairs({{-352, 0}, {-273, 0}, {-300, -32}, {-300, 47}, {-352, -32}, {-273, 47}}) do
	check(validate("alice", "accord", spot[1], 10, spot[2]) == "edge",
		"refuse on the chunk's edge at " .. spot[1] .. "," .. spot[2])
end
for _, spot in ipairs({{-351, 0}, {-274, 0}, {-300, -31}, {-300, 46}, {-351, -31}, {-274, 46}}) do
	check(validate("alice", "accord", spot[1], 10, spot[2]) == "ok",
		"accept one node inside at " .. spot[1] .. "," .. spot[2])
end
blocked_cube["-300/0"] = true
check(validate("alice", "accord", -300, 10, 0) == "cube", "refuse: arrival cube not air")
blocked_cube["-300/0"] = nil
quota_kind = "vale/wolves"
do
	local ok, code, message, kind = M.validate("alice", "accord", {x = -300, y = 10, z = 0}, world)
	check(not ok and code == "quota" and kind == "vale/wolves" and
		message:find("the vale/wolves", 1, true) ~= nil, "refuse: the quota, naming the kind")
end
quota_kind = nil
check(validate("alice", "accord", -300, 10, 0, {cube_clear = world.cube_clear}) == "no_mask",
	"no mask: refused")

-- Placement, one claim per chunk, edge to edge.
out("-- claims")
local a = M.create("alice", {x = -300, y = 10, z = 0})
check(M.player_state("alice") == "placed", "alice placed")
check(a.kind == "" and a.name == "", "a new claim's kind and name are empty")
check(validate("alice", "accord", 300, 10, 0) == "already_placed", "one claim per player")
check(validate("bob", "accord", -280, 10, 20) == "taken", "a second stone in the chunk refused")
check(validate("bob", "accord", -260, 10, 0) == "ok", "the next chunk east accepted")
check(validate("bob", "accord", -300, 10, 60) == "ok", "the next chunk north accepted")
check(M.claim_at({x = -352, y = 5, z = -32}) == a, "claim_at the chunk's first corner")
check(M.claim_at({x = -273, y = 5, z = 47}) == a, "claim_at the chunk's last corner")
check(M.claim_at({x = -353, y = 5, z = 0}) == nil, "claim_at outside x")
check(M.claim_at({x = -300, y = 5, z = 48}) == nil, "claim_at outside z")
check(M.claim_at({x = -300, y = -100, z = 0}) == a, "claim_at y -100")
check(M.claim_at({x = -300, y = -101, z = 0}) == nil, "claim_at y -101")
check(M.claim_at({x = -300, y = 31000, z = 0}) == a, "claim_at unbounded up")
local b = M.create("bob", {x = -199, y = 10, z = 0})
check(M.claim_at({x = -273, y = 0, z = 0}) == a and M.claim_at({x = -272, y = 0, z = 0}) == b,
	"edge-to-edge claims split at the shared chunk edge")

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
check(validate("carol", "accord", -310, 10, 5) == "taken",
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
-- Round 81: a direct paid_until write (the engine probe's faked clock) is
-- seen by the scan only after note_expiry.
check(M.add_fuel(a, 2) == 2, "refuel before the faked expiry")
a.paid_until = clock - 1
check(#M.expiry_scan() == 0, "a direct write alone: the scan returns early")
M.note_expiry(a)
local faked = M.expiry_scan()
check(#faked == 1 and faked[1] == a, "note_expiry: the faked expiry is reported")

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
-- R26: an admin removal has its own state (and wording, interface.lua).
zc = M.create("zed", {x = 300, y = 10, z = 0})
M.remove(zc, "removed")
check(M.player_state("zed") == "removed" and M.claim_by_id(zc.id) == nil,
	"admin removal: state removed, claim gone")
check(new_model(storage).player_state("zed") == "removed", "the removed state persists")
check(M.issue("zed", 30, false) and M.player_state("zed") == "carried",
	"a new stone at once after an admin removal")
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
core.register_tool("grug_materials:pick_wood", {groups = {grug_pick_tier = 1},
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
-- Round 81: the soulbound rule belongs to grug_inventory's bound-item seam
-- (bound.lua) and registers once every mod has loaded.
grug_inventory = {}
dofile(repo .. "/mods/PLAYER/grug_inventory/bound.lua")
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
-- Round 49 ruling 3: every carried list takes it, `main` and the bags.
for _, list in ipairs({"grug_bag1_content", "grug_bag4_content"}) do
	check(player_action("move", {from_list = "main", from_index = 1, to_list = list,
		to_index = 1}, main_inv) == nil, "stone moves into " .. list)
	check(player_action("put", {listname = list, stack = stone}, main_inv) == nil,
		"stone put into " .. list)
end
for _, list in ipairs({"craft", "grug_bag1", "grug_equip_offhand", "grug_mail_out",
		"grug_potion_belt", "grug_quiver_content", "grug_inbox"}) do
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
check(registered_items["grug_materials:pick_wood"].tool_capabilities.groupcaps.grug_claim_stone.times[1] == 60,
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
local told, removed
do
	nodes[a.center.x .. "/" .. a.center.y .. "/" .. a.center.z] = STONE
	M.issue("yan", 20, false)
	local yd = M.create("yan", {x = 9000, y = 0, z = 9000})
	nodes["9000/0/9000"] = "grug_housing:claim_stone_draft"
	removed = {}
	grug_housing.remove_stone_node = function(claim)
		removed[#removed + 1] = claim.id
		nodes[claim.center.x .. "/" .. claim.center.y .. "/" .. claim.center.z] = nil
	end
	told = {}
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

	-- R26: /claim_remove (admin.lua) with its own wording for the owner.
	local commands = {}
	core.register_chatcommand = function(name, def) commands[name] = def end
	core.pos_to_string = function(p) return "(" .. p.x .. "," .. p.y .. "," .. p.z .. ")" end
	_G.vector = {equals = function(p, q) return p.x == q.x and p.y == q.y and p.z == q.z end}
	string.trim = string.trim or function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
	dofile(housing_dir .. "/admin.lua")
	local cmd = commands.claim_remove
	check(cmd ~= nil and cmd.privs.server == true, "/claim_remove needs server")
	M.issue("yan", 20, false)
	local yr = M.create("yan", {x = 9000, y = 0, z = 9000})
	told, removed = {}, {}
	local ok, msg = cmd.func("admin", "yan")
	check(ok and M.claim_by_id(yr.id) == nil and removed[1] == yr.id and
		M.player_state("yan") == "removed" and grug_housing.last_event.event == "removed",
		"/claim_remove <player>: claim and stone gone, state and event removed (" ..
		tostring(msg) .. ")")
	check(#told == 1 and told[1]:find("was removed by an admin", 1, true) ~= nil,
		"the owner is told an admin removed it")
	ok = cmd.func("admin", "yan")
	check(not ok, "/claim_remove of a player without a placed stone refused")
	check(not cmd.func("admin", ""), "/claim_remove without a parameter: usage")
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
check(N.claim_at({x = 4950, y = 0, z = 4990}).id == d.id, "chunk index rebuilt on load")
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
	-- town, capital and functional column in eight directions,
	-- across the footprint's edge.
	local landmark_columns = {}
	for _, row in ipairs(W.roster.rows) do
		if row.family == "outpost" or row.family == "bandit" then
			landmark_columns[#landmark_columns + 1] = {x = row.x, z = row.z}
		end
	end
	local town_centres = {}
	for _, row in ipairs(source.hard_protection) do
		town_centres[#town_centres + 1] = {x = row.center.x, z = row.center.z,
			reach = row.recipe_id == "hard_capital_city_v1" and 276 or 86}
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

	-- Round 85: the real world's placement census (start towns refused, a
	-- 101-node lattice re-checked column by column, the nearest features, the
	-- engine smoke's village pair) judged the 101 x 101 square, which the
	-- claim mask replaced; the mask is checked against the real world by
	-- tools/r85_mask (run.lua, compare.py) and the capacity study. Kept: the
	-- footprint query above and the is_protected cost, on claims in the
	-- middle of one chunk each of the home zones.
	local accepted = {}
	for x = -2600, 2600, 160 do
		for z = -2600, 2600, 160 do
			local cx = 80 * math.floor((x + 32) / 80) + 8
			local cz = 80 * math.floor((z + 32) / 80) + 8
			local id = Z.id_at(cx, cz)
			local zone = id and Z.get(id)
			if zone and zone.faction and zone.level_min >= 11 and zone.level_max <= 30 then
				accepted[#accepted + 1] = {x = cx, z = cz}
			end
		end
	end
	check(#accepted >= 50, "home-zone chunks for the benchmark (" .. #accepted .. ")")

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
		-- the spot is the chunk's first column + 40: its chunk is spot - 40 .. + 39
		positions[i] = {x = spot.x - 40 + rand(80), y = rand(60), z = spot.z - 40 + rand(80)}
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
	-- A protected answer must match: claimed positions refuse "probe", on top
	-- of grug_core's own answer (Round 57 FIX56: bay shore water became claim
	-- ground, so the first sampled position now lies in the other faction's
	-- home, which grug_core refuses by itself).
	check(fifty_fn(positions[1], "probe") == (base_fn(positions[1], "probe") or
		full_model.claim_at(positions[1]) ~= nil),
		"benchmark chain answers like the model")
end

if #failures > 0 then
	error(("R25 CLAIM CORE FIXTURE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print(("R25 CLAIM CORE FIXTURE PASS checks=%d"):format(checks))

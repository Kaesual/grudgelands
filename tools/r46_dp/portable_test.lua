-- Round 46 lane DP portable test (LuaJIT): the depth pulse
-- (round46-plan.md §4.9, ruling 14, the user's decisions on the DP note).
--
--   luajit tools/r46_dp/portable_test.lua [REPO]
--
-- Loads the real grug_mobs/depth_pulse.lua under a stub engine whose world is
-- a voxel grid (stone everywhere but the carved air), with a stepping
-- raycast, so the module's own engine-side world (rays, open nodes, body
-- heights, the ground drop) runs, not a test double of it.
--
-- A. The curve (none above -300; 0.5/min at -300 to 1 at -1000 to 2 at -2000,
--    flat below), the caps 2 / 4 / 6 and the roster per band.
-- B. Placement: an open cave (6-14 nodes, in line of sight), a 1-wide
--    corridor, a sealed 7x7 room (3 to 6 nodes), a sealed 3x3 bunker and a
--    1x2 pocket (no spot), a flyer under a ceiling, a ground arrival on the
--    floor, water and lava never taken.
-- C. The refusals (level, start footprint, hard protection, claim, a player
--    within 3) keep the arrival owed; the cap drops it; at most one owed.
-- D. The 2 s warning: the wind-up at 0 s and 1 s, the body at 2 s with the
--    burst, 32 particles counted from the real presets (particles.lua and
--    particle_effects.lua, their budget check); the re-check at 2 s; one
--    pending arrival per player.
-- E. The arrival: ignore_count, the pulse and no-coin-bag fields on the live
--    entity only, not saved, the underground sight without the elite roll.
-- F. The fade after 10 s without a target (no XP, no loot: removed, not
--    killed); a fighting arrival stays.
-- G. Slicing: each step serves a quarter of the players and of the
--    arrivals; dead players and leavers lose their state.
-- H. The data around it: the deep rows gone, the dofile, the name slot, the
--    creature list, the disposition, the coin-bag flag the drop path reads.
-- Prints "R46 DP PORTABLE PASS checks=<n>" or raises.

local repo = arg and arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function near(a, b, label)
	check(math.abs(a - b) < 1e-9, label .. ": " .. tostring(a) .. " vs " .. tostring(b))
end
local function read(rel)
	local f = assert(io.open(repo .. "/" .. rel, "r"))
	local text = f:read("*a")
	f:close()
	return text
end

-- ---------------------------------------------------------------------------
-- The stub engine
-- ---------------------------------------------------------------------------
_G.vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x or 0, y = y or 0, z = z or 0}
end

local air = {} -- "x,y,z" -> node name (default stone)
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function set(x, y, z, name) air[key(x, y, z)] = name end
local function clear() air = {} end
local function carve(x1, x2, y1, y2, z1, z2, name)
	for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do set(x, y, z, name or "air") end end end
end
local function name_at(pos)
	local x, y, z = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
	return air[key(x, y, z)] or "default:stone"
end

local NODES = {
	air = {walkable = false, drawtype = "airlike"},
	["default:stone"] = {walkable = true},
	["default:water_source"] = {walkable = false, liquidtype = "source"},
	["default:lava_source"] = {walkable = false, liquidtype = "source", damage_per_second = 8},
	["default:torch"] = {walkable = false, drawtype = "torchlike"},
}

local function entity(box, fly)
	return {initial_properties = {collisionbox = box}, fly = fly}
end
local ENTITIES = {
	["grug_mobs:blood_bat"] = entity({-0.31, -0.01, -0.31, 0.31, 1.11, 0.31}, true),
	["grug_mobs:riftwing"] = entity({-0.31, -0.01, -0.31, 0.31, 1.11, 0.31}, true),
	["grug_mobs:glowwing"] = entity({-0.15, -0.01, -0.15, 0.15, 0.3, 0.15}, true),
	["grug_mobs:ember_wisp"] = entity({-0.2, 0.2, -0.2, 0.2, 1, 0.2}, true),
	["grug_mobs:rift_spawn"] = entity({-0.3, -0.01, -0.3, 0.3, 1.69, 0.3}, nil),
	["grug_mobs:land_guard"] = entity({-0.5, -1.01, -0.5, 0.5, 1.6, 0.5}, nil),
}

-- A raycast that steps along the segment and yields every pointable node it
-- enters (air is not pointable), with `above` the node it came from.
local function raycast(from, to)
	local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	local steps = math.max(1, math.ceil(len / 0.02))
	local hits, last = {}, nil
	for i = 0, steps do
		local t = i / steps
		local p = {x = math.floor(from.x + dx * t + 0.5), y = math.floor(from.y + dy * t + 0.5),
			z = math.floor(from.z + dz * t + 0.5)}
		local k = key(p.x, p.y, p.z)
		if k ~= (last and key(last.x, last.y, last.z)) then
			if name_at(p) ~= "air" and last then
				hits[#hits + 1] = {type = "node", under = p, above = last}
			end
			last = p
		end
	end
	local i = 0
	return function()
		i = i + 1
		return hits[i]
	end
end

local globalsteps, leaveplayer = {}, {}
local objects = {} -- live ObjectRef stubs
local particle_calls = {}
local settings = {}
_G.core = {
	settings = {
		get = function(_, k) return settings[k] end,
		get_bool = function(_, k) return settings[k] end,
	},
	registered_nodes = NODES,
	registered_entities = ENTITIES,
	get_node_or_nil = function(pos) return {name = name_at(pos)} end,
	raycast = raycast,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_leaveplayer = function(fn) leaveplayer[#leaveplayer + 1] = fn end,
	get_objects_inside_radius = function(pos, r)
		local out = {}
		for _, obj in ipairs(objects) do
			local p = obj:get_pos()
			if p then
				local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
				if dx * dx + dy * dy + dz * dz <= r * r then out[#out + 1] = obj end
			end
		end
		return out
	end,
	add_particle = function(def) particle_calls[#particle_calls + 1] = {n = 1, def = def} end,
	add_particlespawner = function(def)
		particle_calls[#particle_calls + 1] = {n = def.amount, def = def}
	end,
	log = function() end,
	yaw_to_dir = function(yaw) return vector.new(-math.sin(yaw), 0, math.cos(yaw)) end,
}
_G.minetest = core

-- The real particle helper and catalogue.
_G.grug_core = {}
assert(loadfile(repo .. "/mods/CORE/grug_core/particles.lua"))()
assert(loadfile(repo .. "/mods/CORE/grug_core/particle_effects.lua"))()
local P = grug_core.particles

local function new_object(pos, props)
	local obj = {pos = pos, props = props or {}, removed = false}
	function obj:get_pos() return (not self.removed) and self.pos or nil end
	function obj:is_player() return self.player == true end
	function obj:get_luaentity() return (not self.removed) and self.ent or nil end
	function obj:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function obj:remove() self.removed = true end
	function obj:get_player_name() return self.name end
	function obj:get_hp() return self.hp or 20 end
	objects[#objects + 1] = obj
	return obj
end

local function player(name, pos)
	local obj = new_object(pos)
	obj.player, obj.name, obj.hp = true, name, 20
	return obj
end

local level_at, footprint, protected, claimed = 30, false, nil, false
_G.grug_zones = {
	mob_level_at = function() return level_at end,
	hard_protection_kind_at = function() return protected end,
}
local added, sighted = {}, {}
local add_limit = false
_G.grug_mobs = {
	in_start_footprint = function() return footprint end,
	claim_refuses_spawn = function() return claimed end,
	add_mob = function(pos, def)
		if add_limit then return nil end
		local ent = {name = def.name, health = 10}
		ent.object = new_object({x = pos.x, y = pos.y, z = pos.z}, {static_save = true})
		ent.object.ent = ent
		added[#added + 1] = {pos = pos, def = def, ent = ent}
		return ent
	end,
	underground_spawned = function(ent, pos, skip_elite)
		sighted[#sighted + 1] = {ent = ent, skip_elite = skip_elite}
		ent.view_range = 26
		return false
	end,
}
_G.mobs = {}
function mobs:can_spawn(pos, name)
	if NODES[name_at(pos)].walkable then return nil end
	return {x = pos.x, y = pos.y, z = pos.z}
end

assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/depth_pulse.lua"))()
local DP = grug_mobs.depth_pulse
check(DP and #globalsteps == 1 and #leaveplayer == 1, "the module loads with one globalstep")

-- Particles played by id, counted through the real helper.
local played = {}
local real_effect = DP.effect
DP.effect = function(id, pos)
	played[#played + 1] = id
	real_effect(id, pos)
end
local function particles_of(from)
	local n = 0
	for i = from + 1, #particle_calls do n = n + particle_calls[i].n end
	return n
end

-- Scripted randomness: the queue first, then a fixed value.
local queue, fallback = {}, 0.5
DP.random = function()
	if #queue > 0 then return table.remove(queue, 1) end
	return fallback
end
local function script(...) queue = {...} end

-- ---------------------------------------------------------------------------
-- A. Curve, caps, roster
-- ---------------------------------------------------------------------------
near(DP.rate(-100), 0, "A nothing at -100")
near(DP.rate(-299), 0, "A nothing at -299")
near(DP.rate(-300), 0.5, "A 0.5/min at -300 (one per 120 s)")
near(DP.rate(-650), 0.75, "A linear to -1000")
near(DP.rate(-1000), 1, "A 1/min at -1000 (one per 60 s)")
near(DP.rate(-1500), 1.5, "A linear to -2000")
near(DP.rate(-2000), 2, "A 2/min at -2000 (one per 30 s)")
near(DP.rate(-5000), 2, "A flat below -2000")
check(DP.cap(-300) == 2 and DP.cap(-500) == 2, "A cap 2 down to -500")
check(DP.cap(-501) == 4 and DP.cap(-1000) == 4, "A cap 4 down to -1000")
check(DP.cap(-1001) == 6 and DP.cap(-3000) == 6, "A cap 6 below")
check(DP.pick(-299, 0) == nil, "A no roster above -300")
check(DP.pick(-300, 0) == "blood_bat" and DP.pick(-300, 0.59) == "blood_bat" and
	DP.pick(-300, 0.61) == "glowwing", "A -300..-700: Blood Bat 60, Glowwing 40")
check(DP.pick(-700, 0.99) == "glowwing" and DP.pick(-701, 0.49) == "blood_bat" and
	DP.pick(-701, 0.51) == "ember_wisp" and DP.pick(-1000, 0.81) == "glowwing",
	"A -701..-1000: Blood Bat 50, Ember Wisp 30, Glowwing 20")
check(DP.pick(-1001, 0) == "riftwing" and DP.pick(-1001, 0.61) == "ember_wisp" and
	DP.pick(-1001, 0.81) == "rift_spawn" and DP.pick(-2500, 0.999) == "land_guard",
	"A below -1000: Riftwing 60, Ember Wisp 20, Rift Spawn 15, Bedrock Sentinel 5")
local flyers, total = 0, 0
for _, band in ipairs(DP.ROSTERS) do
	for _, entry in ipairs(band.mobs) do
		total = total + entry[2]
		if ENTITIES["grug_mobs:" .. entry[1]].fly then flyers = flyers + entry[2] end
	end
end
check(flyers / total >= 0.9, "A the roster is flyers above 90 %: " .. flyers / total)

-- ---------------------------------------------------------------------------
-- B. Placement
-- ---------------------------------------------------------------------------
local W = DP.world
local function los(eye, spot)
	for _ in raycast(eye, spot) do return false end
	return true
end
local function dist(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end
local function rnd_seq(...)
	local list = {...}
	return function()
		if #list > 0 then return table.remove(list, 1) end
		return 0.5
	end
end
local EYE = {x = 0, y = 1, z = 0} -- a player standing on the floor y -1 (feet at -0.5)

-- An open cave: 41 x 8 x 41 air.
clear(); carve(-20, 20, 0, 7, -20, 20)
local hits = 0
for i = 0, 15 do
	local spot, d = DP.find_spot(EYE, "blood_bat", W, rnd_seq(i / 16, 0.5, i / 16, 0.3))
	if spot then
		hits = hits + 1
		check(d >= 6 and d <= 14.5, "B open cave distance 6-14: " .. d)
		check(los(EYE, spot), "B open cave spot in line of sight")
		check(W.open(spot) and W.open({x = spot.x, y = spot.y + 1, z = spot.z}),
			"B the bat's two nodes are open")
	end
end
check(hits == 16, "B every open-cave try finds a spot: " .. hits)

-- A 1-wide, 2-high corridor along +x: the ray along it finds a spot far off,
-- the sideways ones hit the wall at once.
clear(); carve(-1, 30, 0, 1, 0, 0)
local spot, d = DP.find_spot(EYE, "blood_bat", W, rnd_seq(0.25, 0.5, 0.25, 0.5, 0.25, 0.5, 0, 0.5))
check(spot and d >= 6 and spot.z == 0 and spot.x > 5, "B corridor: the ray along it")
spot = DP.find_spot(EYE, "blood_bat", W, rnd_seq(0.25, 0.5, 0.25, 0.5, 0.75, 0.5, 0.25, 0.5))
check(spot == nil, "B corridor: only sideways rays -> no spot")

-- A sealed 7 x 3 x 7 room: no spot 6 away, the farthest of at least 3 wins.
clear(); carve(-3, 3, 0, 2, -3, 3)
spot, d = DP.find_spot(EYE, "glowwing", W, rnd_seq(0, 0.5, 0.125, 0.5, 0.25, 0.5, 0.375, 0.5))
check(spot and d >= 3 and d < 6, "B sealed 7x7 room: 3 to 6 nodes: " .. tostring(d))
check(los(EYE, spot), "B sealed room spot in line of sight")
-- A sealed 3 x 3 bunker and a 1 x 2 pocket: no room 3 nodes away -> skip.
clear(); carve(-1, 1, 0, 2, -1, 1)
check(DP.find_spot(EYE, "glowwing", W, rnd_seq(0, 0.5, 0.25, 0.5, 0.5, 0.9, 0.75, 0.1)) == nil,
	"B sealed 3x3 bunker: no spot")
clear(); carve(0, 0, 0, 1, 0, 0)
check(DP.find_spot(EYE, "blood_bat", W, rnd_seq(0, 0.5, 0.25, 0.5, 0.5, 0.9, 0.75, 0.1)) == nil,
	"B 1x2 pocket: no spot")

-- A flyer whose ray ends under a 1-high ceiling niche takes the node below.
clear(); carve(-1, 12, 0, 1, 0, 0); carve(9, 9, 2, 2, 0, 0)
local s2 = W.fits({x = 9, y = 2, z = 0}, "blood_bat")
check(s2 == nil, "B a bat does not fit a 1-high niche")
check(W.fits({x = 9, y = 1, z = 0}, "blood_bat") ~= nil and W.fits({x = 9, y = 2, z = 0},
	"glowwing") ~= nil, "B the bat fits one lower; the small Glowwing fits the niche")

-- A ground arrival settles on the floor.
clear(); carve(-20, 20, 0, 7, -20, 20)
spot, d = DP.find_spot(EYE, "rift_spawn", W, rnd_seq(0, 0.9))
check(spot and spot.y == 0 and NODES[name_at({x = spot.x, y = -1, z = spot.z})].walkable,
	"B a Rift Spawn stands on the floor: " .. tostring(spot and spot.y))
check(W.ground("rift_spawn") and W.ground("land_guard") and not W.ground("riftwing"),
	"B ground and flying arrivals by the entity's fly flag")
check(W.fits({x = 3, y = 6, z = 3}, "land_guard") == nil and
	W.fits({x = 3, y = 5, z = 3}, "land_guard") ~= nil, "B the Sentinel needs three open nodes")
-- Water and lava are never a spot.
clear(); carve(-20, 20, 0, 7, -20, 20); carve(-20, 20, 0, 7, 5, 20, "default:water_source")
check(not W.open({x = 0, y = 2, z = 8}), "B water is not open")
check(W.ray({x = 0, y = 1.5, z = 0}, {x = 0, y = 1.5, z = 14}).above.z == 4,
	"B a ray stops at water")
set(2, 2, 2, "default:lava_source")
check(not W.open({x = 2, y = 2, z = 2}), "B lava is not open")
set(1, 1, 1, "default:torch")
check(W.open({x = 1, y = 1, z = 1}) and W.ray({x = 0, y = 1, z = 1}, {x = 4, y = 1, z = 1}) == nil,
	"B a torch neither blocks a ray nor a body")

-- ---------------------------------------------------------------------------
-- C-E. The per-player state machine
-- ---------------------------------------------------------------------------
clear(); carve(-20, 20, -340, -333, -20, 20)
local function reset_world()
	objects, added, sighted, played, particle_calls = {}, {}, {}, {}, {}
	DP.state, DP.arrivals, DP.stats = {}, {}, {}
	level_at, footprint, protected, claimed, add_limit = 30, false, nil, false, false
end
reset_world()
local p1 = player("one", {x = 0, y = -340.5, z = 0})
-- An open cave at y -340: rate 0.5 + 40 * 0.5 / 700 per minute.
local chance = DP.rate(-340) / 60
script(chance + 0.01)
check(DP.player_tick(p1, 0) == "idle", "C a roll above the chance: nothing")
-- The roll fires (chance - tiny), then pick 0 (Blood Bat), then four rays.
script(chance - 0.0001, 0, 0, 0.5)
check(DP.player_tick(p1, 10) == "placed", "C a roll that fires places a wind-up")
check(DP.stats.rolls == 1 and DP.state.one.pending and DP.state.one.owed == nil,
	"C one roll, one pending, nothing owed")
check(played[1] == "depth_windup" and #played == 1, "D the wind-up starts at once")
local mark = 0
check(particles_of(mark) == 12, "D 12 particles in the first second: " .. particles_of(mark))
check(DP.player_tick(p1, 10.5) == "windup", "D still winding up at 0.5 s")
check(DP.player_tick(p1, 11) == "windup" and played[2] == "depth_windup",
	"D the second wind-up at 1 s")
script(0) -- any roll would fire: a pending player does not roll
check(DP.player_tick(p1, 11.5) == "windup" and DP.stats.rolls == 1, "D no roll while pending")
queue = {}
check(DP.player_tick(p1, 12) == "spawned" and played[3] == "depth_burst",
	"D the body at 2 s with the burst")
check(particles_of(0) == 32, "D 32 particles per arrival: " .. particles_of(0))
check(P.check(P.registered("depth_windup")) == nil and P.check(P.registered("depth_burst")) == nil,
	"D both presets keep the particle budget rules")

-- E. The arrival.
local a = added[1]
check(a and a.def.name == "grug_mobs:blood_bat" and a.def.ignore_count == true and
	not a.def._grug_authored, "E Blood Bat added with ignore_count, not authored (limit 600 holds)")
check(a.ent._grug_pulse == true and a.ent._grug_no_coin_bag == true,
	"E the pulse and no-coin-bag fields on the live entity")
check(a.ent.object.props.static_save == false, "E an arrival is never saved")
check(sighted[1] and sighted[1].ent == a.ent and sighted[1].skip_elite == true,
	"E the underground sight without the elite roll")
check(#DP.arrivals == 1 and DP.arrivals[1].obj == a.ent.object, "E the arrival is tracked")
check(dist(a.pos, {x = 0, y = -339, z = 0}) >= 6, "E 6 or more nodes from the player's eyes")

-- C. The cap counts every pulse arrival within 24 nodes (a group shares it).
local other = {name = "grug_mobs:glowwing", _grug_pulse = true}
other.object = new_object({x = 5, y = -340, z = 5})
other.object.ent = other
script(0)
check(DP.player_tick(p1, 20) == "cap" and DP.state.one.owed == nil,
	"C cap 2 at -340 reached by two arrivals (another player's counts too): dropped, not owed")
other.object.removed = true

-- The refusals keep the arrival owed, at most one.
local function refused_by(setup, reason)
	DP.state = {}
	setup(true)
	script(0, 0, 0, 0.5)
	local out = DP.player_tick(p1, 30)
	check(out == reason and DP.state.one.owed == true and not DP.state.one.pending,
		"C " .. reason .. " keeps the arrival owed: " .. tostring(out))
	-- Owed: the next second tries again without a new roll.
	local rolls = DP.stats.rolls
	script(0, 0, 0.5)
	DP.player_tick(p1, 31)
	check(DP.stats.rolls == rolls, "C an owed arrival retries without rolling again")
	setup(false)
end
added[1].ent.object.removed = true
refused_by(function(on) level_at = (not on) and 30 or nil end, "refused_level")
refused_by(function(on) footprint = on end, "refused_footprint")
refused_by(function(on) protected = on and "town" or nil end, "refused_protected")
refused_by(function(on) claimed = on end, "refused_claim")
local bystander
refused_by(function(on)
	if on then
		-- Another player stands where the first ray will end (16 nodes along +x).
		bystander = player("two", {x = 13, y = -339.5, z = 0})
	else
		bystander.removed = true
	end
end, "refused_player")
-- No spot: the player in a 1x2 pocket.
clear(); carve(0, 0, -340, -339, 0, 0)
DP.state = {}
script(0, 0)
check(DP.player_tick(p1, 40) == "no_spot" and DP.state.one.owed == true, "C no spot -> owed")

-- The re-check at 2 s: the spot filled during the wind-up.
clear(); carve(-20, 20, -340, -333, -20, 20)
DP.state = {}
script(0, 0, 0, 0.5)
check(DP.player_tick(p1, 50) == "placed", "D placed for the re-check")
local pend = DP.state.one.pending.spot
set(pend.x, pend.y, pend.z, "default:stone")
check(DP.player_tick(p1, 51) == "windup", "D wind-up second")
check(DP.player_tick(p1, 52) == "recheck" and DP.state.one.owed == true,
	"D a spot that filled up: no arrival, owed again")
set(pend.x, pend.y, pend.z, "air")
-- The global limit (mobs_redo's 600): add_mob refuses, nothing is added.
DP.state = {}
script(0, 0, 0, 0.5)
DP.player_tick(p1, 60)
add_limit = true
DP.player_tick(p1, 61)
local before = #added
check(DP.player_tick(p1, 62) == "limit" and #added == before, "C the global limit refuses")
add_limit = false

-- Above -300 nothing rolls, and an owed arrival is forgotten.
DP.state = {one = {owed = true}}
p1.pos = {x = 0, y = -250, z = 0}
script(0)
check(DP.player_tick(p1, 70) == "idle" and DP.state.one.owed == nil, "C nothing above -300")
p1.pos = {x = 0, y = -340.5, z = 0}
-- A dead player loses a pending wind-up.
DP.state = {one = {pending = {spot = {x = 6, y = -340, z = 0}, mob = "blood_bat", start = 0,
	phase = 1}}}
p1.hp = 0
check(DP.player_tick(p1, 71) == "idle" and DP.state.one == nil, "C a dead player's state is dropped")
p1.hp = 20
DP.state = {one = {owed = true}}
leaveplayer[1](p1)
check(DP.state.one == nil, "C a leaving player's state is dropped")

-- ---------------------------------------------------------------------------
-- F. The fade
-- ---------------------------------------------------------------------------
reset_world()
local function arrival(attack)
	local ent = {name = "grug_mobs:blood_bat", health = 10, attack = attack}
	ent.object = new_object({x = 3, y = -340, z = 3})
	ent.object.ent = ent
	return ent, {obj = ent.object, lost_since = 0}
end
local idle_ent, idle_rec = arrival(nil)
check(DP.arrival_tick(idle_rec, 9.5) == true and not idle_ent.object.removed, "F not yet at 9.5 s")
check(DP.arrival_tick(idle_rec, 10) == false and idle_ent.object.removed and
	played[#played] == "depth_burst" and DP.stats.faded == 1,
	"F faded at 10 s without a target, with the 8-mote burst")
local target = player("three", {x = 0, y = -340.5, z = 0})
local busy_ent, busy_rec = arrival(target)
check(DP.arrival_tick(busy_rec, 50) == true and busy_rec.lost_since == nil and
	not busy_ent.object.removed, "F a fighting arrival stays")
busy_ent.attack = nil
check(DP.arrival_tick(busy_rec, 51) == true, "F the target lost: the 10 s start")
check(DP.arrival_tick(busy_rec, 61) == false and busy_ent.object.removed, "F faded 10 s later")
local dead_ent, dead_rec = arrival(nil)
dead_ent.health = 0
check(DP.arrival_tick(dead_rec, 100) == false and not dead_ent.object.removed and
	DP.stats.faded == 2, "F a killed arrival is only dropped from the list (its death pays)")

-- ---------------------------------------------------------------------------
-- G. Slicing
-- ---------------------------------------------------------------------------
reset_world()
local served = {}
local real_tick, real_arrival = DP.player_tick, DP.arrival_tick
DP.player_tick = function(pl) served[#served + 1] = pl.name; return "idle" end
local arrival_served = 0
DP.arrival_tick = function() arrival_served = arrival_served + 1; return true end
local list = {}
for i = 1, 8 do list[i] = player("p" .. i, {x = 0, y = -400, z = 0}) end
DP.players = function() return list end
for i = 1, 8 do DP.arrivals[i] = {obj = {}} end
for s = 1, 3 do
	served = {}
	DP.step(s, 0)
	check(#served == 2, "G a step serves a quarter of the players: " .. #served)
end
DP.step(0, 0)
check(arrival_served == 8, "G every arrival once a second")
-- The globalstep: four steps a second, each a slice.
served = {}
for _ = 1, 40 do globalsteps[1](0.1) end
check(#served >= 24 and #served <= 32,
	"G about one tick per player per second: " .. #served)
DP.player_tick, DP.arrival_tick = real_tick, real_arrival

-- ---------------------------------------------------------------------------
-- H. The data around the module
-- ---------------------------------------------------------------------------
local land = read("mods/ENTITIES/grug_mobs/land_guard.lua")
local rift = read("mods/ENTITIES/grug_mobs/rift_spawn.lua")
check(not land:find("mobs:spawn%(", 1), "H the Land Guard has no spawn row")
check(not rift:find("max_height = %-1000", 1) and rift:find("min_height = 0, max_height = 600", 1, true),
	"H the Rift Spawn keeps only its surface row")
local init = read("mods/ENTITIES/grug_mobs/init.lua")
local i_rift = init:find('dofile(modpath .. "/rift_spawn.lua")', 1, true)
local i_pulse = init:find('dofile(modpath .. "/depth_pulse.lua")', 1, true)
check(i_rift and i_pulse and i_pulse > i_rift, "H depth_pulse.lua loads after the roster's mobs")
check(read("mods/ENTITIES/grug_mobs/data/names.json"):find('"world/riftwing/L60-60": "Riftwing"', 1, true),
	"H the Riftwing name slot")
check(read("mods/PLAYER/grug_achievements/creatures.lua"):find('"riftwing"', 1, true),
	"H the Riftwing in the creature list")
check(read("mods/ENTITIES/grug_mobs/disposition.lua"):find('"riftwing"', 1, true),
	"H the Riftwing is aggressive")
local zav = read("mods/ENTITIES/grug_mobs/zero_asset_variants.lua")
local rw = zav:match('local riftwing = hostile_bat_def%("Riftwing",%s*"([^"]+)"%)')
check(rw and rw:find("grug_mobs_cave_bat.png^[multiply:", 1, true),
	"H the Riftwing is the cave-bat texture with a runtime modifier")
check(not zav:find('name = "grug_mobs:riftwing"', 1, true), "H the Riftwing has no spawn row")
check(read("mods/ENTITIES/grug_mobs/aggro.lua"):find("grug_mobs.no_coin_bag(self)", 1, true) and
	read("mods/ENTITIES/grug_mobs/levels.lua"):find("self._grug_no_coin_bag", 1, true),
	"H the coin-bag drop reads the live entity's flag")
check(not read("mods/ENTITIES/grug_mobs/depth_pulse.lua"):find("set_node", 1, true) and
	not read("mods/ENTITIES/grug_mobs/depth_pulse.lua"):find("remove_node", 1, true) and
	not read("mods/ENTITIES/grug_mobs/depth_pulse.lua"):find("grug_sounds", 1, true) and
	not read("mods/ENTITIES/grug_mobs/depth_pulse.lua"):find("sound_play", 1, true),
	"H the pulse changes no node and plays no sound")

print("R46 DP PORTABLE PASS checks=" .. checks)

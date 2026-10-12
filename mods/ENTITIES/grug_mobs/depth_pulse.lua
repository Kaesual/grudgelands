--
-- The depth pulse (Round 46 lane DP; biomes_mobs.md §4.1, the user's
-- decisions of 2026-10-12 on the lane's design note).
--
-- Below y -300 a player meets arrivals from below: mostly flyers, each
-- announced by a 2 s particle wind-up at the spot where it will appear.
-- Depth buys frequency, not stats: an arrival takes the ordinary underground
-- level of its spot (grug_zones.mob_level_at, like every cave mob) and is
-- never rolled elite.
--
--   rate      arrivals per minute: none above -300; 0.5 at -300 rising
--             linearly to 1 at -1000, then to 2 at -2000, flat below
--             (DP.CURVE; rate linear in depth, the interval is 60 / rate).
--   cap       2 down to -500 (the last T3 node), 4 down to -1000, 6 below,
--             counted over every pulse arrival within 24 nodes of the
--             player, whoever's roll brought it: a group shares one cap.
--   roll      once a second per player, chance rate / 60, only while
--             nothing is pending for that player and the cap has room. A
--             roll whose spot cannot be found or is refused stays owed (at
--             most one) and is tried again the next second.
--   spot      up to four rays from the player's eyes in random, mostly
--             horizontal directions, at most 14 nodes long; the spot is the
--             last open node before rock and must fit the body. The first
--             spot 6 or more nodes away wins; failing that the farthest one
--             of at least 3 (a sealed room is not safe); none -> skip.
--             So a spot is always in open line of sight of the player and
--             a flyer has a straight way in. Ground arrivals (below -1000)
--             settle on the floor at most 4 nodes below the ray's spot.
--   refusals  no mob level there (deep-ocean columns), a start footprint,
--             hard-protected ground, an active claim, a player within 3
--             nodes; at the end of the wind-up the spot is checked again
--             (room, nobody standing in it) and mobs_redo's global limit
--             of 600 applies (grug_mobs.add_mob, not authored).
--   warning   "depth_windup" at the spot at 0 s and 1 s (a spawner lives at
--             most 1 s, particles.lua), "depth_burst" when the body appears:
--             12 + 12 + 8 = 32 particles per arrival. Silent: no sound
--             without the user's pick (AGENTS.md "Sound").
--   fade      an arrival without a target for 10 s fades away (8 motes,
--             removed: no XP, no loot) and frees its place under the cap.
--   rewards   a killed arrival pays ordinary kill XP and its family drops
--             but no coin bag (`_grug_no_coin_bag` set on the live entity,
--             so ambient mobs of the same registration keep theirs).
--
-- The pulse never places, digs or removes a node. Arrivals are never saved
-- (static_save = false): an unloaded block takes them with it.
--
-- Cost: one throttled globalstep, the players and the live arrivals spread
-- over four slices of each second (spawn_regions.lua's pattern), so no step
-- serves every player. Per player per second: a y test and a roll; the
-- placement work (four rays, the gates, one 24-node object count) runs only
-- for a roll that fired or an owed arrival.
--
-- The pure parts (curve, cap, roster, find_spot, the per-player state
-- machine) read the world only through DP.world and the DP.* hooks below,
-- so tools/r46_dp/portable_test.lua drives them on a voxel stub.
--

local DP = {}
grug_mobs.depth_pulse = DP

DP.TOP = -300 -- no pulse above
DP.CURVE = {{-300, 0.5}, {-1000, 1}, {-2000, 2}} -- {y, arrivals per minute}
DP.PERIOD = 1 -- s between two ticks of one player
DP.SLICES = 4
DP.MIN_DIST = 6
DP.MAX_DIST = 14
DP.SEALED_MIN = 3
DP.TRIES = 4
DP.EYE = 1.5
DP.PITCH = 0.4 -- largest |y| of a ray direction: mostly horizontal
DP.DROP = 4 -- a ground arrival settles at most this far below its spot
DP.CAP_RADIUS = 24
DP.CLEAR_RADIUS = 3
DP.WINDUP = 2
DP.FADE_AFTER = 10

-- Rosters by depth band (the band is the player's y): {top, {entity, weight}}.
-- Bands follow the tool tiers: T3-T4 from -300, T5 from -701, T6 from -1001.
DP.ROSTERS = {
	{top = -300, mobs = {{"blood_bat", 60}, {"glowwing", 40}}},
	{top = -701, mobs = {{"blood_bat", 50}, {"ember_wisp", 30}, {"glowwing", 20}}},
	{top = -1001, mobs = {{"riftwing", 60}, {"ember_wisp", 20}, {"rift_spawn", 15},
		{"land_guard", 5}}},
}

DP.stats = {}
local function count(reason)
	DP.stats[reason] = (DP.stats[reason] or 0) + 1
	return reason
end

--
-- Pure rules.
--

function DP.rate(y)
	local c = DP.CURVE
	if y > c[1][1] then
		return 0
	end
	for i = 2, #c do
		local y0, r0 = c[i - 1][1], c[i - 1][2]
		local y1, r1 = c[i][1], c[i][2]
		if y >= y1 then
			return r0 + (r1 - r0) * (y0 - y) / (y0 - y1)
		end
	end
	return c[#c][2]
end

function DP.cap(y)
	if y >= -500 then
		return 2
	elseif y >= -1000 then
		return 4
	end
	return 6
end

function DP.roster(y)
	local found
	for _, band in ipairs(DP.ROSTERS) do
		if y <= band.top then
			found = band
		end
	end
	return found
end

-- The entity (short name) for `roll` in [0, 1); nil above the pulse.
function DP.pick(y, roll)
	local band = DP.roster(y)
	if not band then
		return nil
	end
	local total = 0
	for _, entry in ipairs(band.mobs) do
		total = total + entry[2]
	end
	local target = roll * total
	for _, entry in ipairs(band.mobs) do
		target = target - entry[2]
		if target < 0 then
			return entry[1]
		end
	end
	return band.mobs[#band.mobs][1]
end

local function distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function round_pos(p)
	return {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5), z = math.floor(p.z + 0.5)}
end

-- A flyer takes the ray's node or the one below it (a ray that ended at a
-- ceiling); a ground arrival the first open node above a floor within DROP.
local function settle(cand, mob, world)
	if world.ground(mob) then
		for drop = 0, DP.DROP do
			local p = {x = cand.x, y = cand.y - drop, z = cand.z}
			if not world.open(p) then
				return nil
			end
			if world.blocks({x = p.x, y = p.y - 1, z = p.z}) then
				return world.fits(p, mob)
			end
		end
		return nil
	end
	return world.fits(cand, mob) or world.fits({x = cand.x, y = cand.y - 1, z = cand.z}, mob)
end

-- The spot for `mob` seen from `eye`, and its distance; nil when there is
-- none. `rand` returns a number in [0, 1).
function DP.find_spot(eye, mob, world, rand)
	local best, best_d
	for _ = 1, DP.TRIES do
		local yaw = rand() * 2 * math.pi
		local dy = (rand() * 2 - 1) * DP.PITCH
		local flat = math.sqrt(1 - dy * dy)
		local to = {x = eye.x + math.cos(yaw) * flat * DP.MAX_DIST,
			y = eye.y + dy * DP.MAX_DIST, z = eye.z + math.sin(yaw) * flat * DP.MAX_DIST}
		local hit = world.ray(eye, to)
		local cand = hit and hit.above or round_pos(to)
		local spot = cand and settle(cand, mob, world)
		if spot then
			local d = distance(eye, spot)
			if d >= DP.MIN_DIST then
				return spot, d
			end
			if d >= DP.SEALED_MIN and (not best_d or d > best_d) then
				best, best_d = spot, d
			end
		end
	end
	return best, best_d
end

--
-- The engine side (replaced by the portable test).
--

local function node_def(pos)
	local node = core.get_node_or_nil(pos)
	return node and core.registered_nodes[node.name]
end

-- Rock, a wall, any liquid and an unloaded node stop a ray and a body.
local function blocks_def(def)
	return not def or def.walkable ~= false or (def.liquidtype or "none") ~= "none"
end

local box_heights = {}
local function body_height(name)
	local h = box_heights[name]
	if not h then
		local proto = core.registered_entities[name]
		local box = proto and proto.initial_properties and proto.initial_properties.collisionbox
		h = box and math.max(1, math.ceil(box[5] - box[2])) or 2
		box_heights[name] = h
	end
	return h
end

DP.world = {
	blocks = function(pos)
		return blocks_def(node_def(pos))
	end,
	-- Open air a body may stand in: not solid, not liquid, harmless.
	open = function(pos)
		local def = node_def(pos)
		return def ~= nil and not blocks_def(def) and (def.damage_per_second or 0) <= 0
	end,
	ground = function(mob)
		local proto = core.registered_entities["grug_mobs:" .. mob]
		return not (proto and proto.fly)
	end,
	-- The position the mob is added at, or nil when its body does not fit.
	fits = function(pos, mob)
		local name = "grug_mobs:" .. mob
		for dy = 0, body_height(name) - 1 do
			if not DP.world.open({x = pos.x, y = pos.y + dy, z = pos.z}) then
				return nil
			end
		end
		return mobs:can_spawn(pos, name)
	end,
	-- The first blocking node on the segment: {under, above} or nil.
	ray = function(from, to)
		for pointed in core.raycast(from, to, false, false) do
			if pointed.type == "node" and blocks_def(node_def(pointed.under)) then
				return {under = pointed.under, above = pointed.above}
			end
		end
		return nil
	end,
}

DP.random = math.random

-- The player list; the depth probe (tools/r24_density_xp) hands in stand-ins.
function DP.players()
	return core.get_connected_players()
end

function DP.effect(id, pos)
	grug_core.particles.play(id, {caster = pos})
end

local function player_within(pos, radius)
	for _, object in ipairs(core.get_objects_inside_radius(pos, radius)) do
		if object:is_player() then
			return true
		end
	end
	return false
end
DP.player_within = player_within

-- Pulse arrivals within CAP_RADIUS of `pos`, whoever's roll brought them.
function DP.live_near(pos)
	local n = 0
	for _, object in ipairs(core.get_objects_inside_radius(pos, DP.CAP_RADIUS)) do
		local ent = object:get_luaentity()
		if ent and ent._grug_pulse then
			n = n + 1
		end
	end
	return n
end

-- nil when the spot may take `mob`, else the reason.
function DP.refused(mob, spot)
	if grug_zones.mob_level_at(spot) == nil then
		return "refused_level"
	end
	if grug_mobs.in_start_footprint(spot.x, spot.z, spot.y) then
		return "refused_footprint"
	end
	if grug_zones.hard_protection_kind_at(spot) ~= nil then
		return "refused_protected"
	end
	if grug_mobs.claim_refuses_spawn("grug_mobs:" .. mob, spot) then
		return "refused_claim"
	end
	if DP.player_within(spot, DP.CLEAR_RADIUS) then
		return "refused_player"
	end
	return nil
end

DP.arrivals = {} -- {obj = ObjectRef, lost_since = clock or nil}

-- Adds the arrival; its ObjectRef or nil (mobs_redo's limit, no room).
function DP.spawn(mob, spot, now)
	local ent = grug_mobs.add_mob(spot, {name = "grug_mobs:" .. mob, ignore_count = true})
	if not ent then
		return nil
	end
	-- Plain fields on this entity only: the registration is shared with the
	-- ambient mobs of the same name, which keep their coin bags.
	ent._grug_pulse = true
	ent._grug_no_coin_bag = true
	ent.object:set_properties({static_save = false})
	-- The underground sight (view range past the spawn distance), without
	-- the elite roll (D5: never elite; a def-elite stays what it is).
	grug_mobs.underground_spawned(ent, spot, true)
	DP.arrivals[#DP.arrivals + 1] = {obj = ent.object, lost_since = now}
	return ent.object
end

--
-- The per-player state machine (pure apart from the hooks above).
--

DP.state = {} -- player name -> {owed = true|nil, pending = {...}|nil}

local function advance(st, now)
	local p = st.pending
	local age = now - p.start
	if p.phase == 1 and age >= 1 then
		DP.effect("depth_windup", p.spot)
		p.phase = 2
	end
	if age < DP.WINDUP then
		return "windup"
	end
	st.pending = nil
	local at = DP.world.fits(p.spot, p.mob)
	if not at or DP.player_within(p.spot, 1) then
		st.owed = true
		return count("recheck")
	end
	if not DP.spawn(p.mob, at, now) then
		return count("limit")
	end
	DP.effect("depth_burst", p.spot)
	return count("spawned")
end

function DP.player_tick(player, now)
	local name = player:get_player_name()
	local pos = player:get_pos()
	if not pos or (player:get_hp() or 0) <= 0 then
		DP.state[name] = nil
		return "idle"
	end
	local st = DP.state[name]
	if not st then
		st = {}
		DP.state[name] = st
	end
	if st.pending then
		return advance(st, now)
	end
	local rate = DP.rate(pos.y)
	if rate <= 0 then
		st.owed = nil
		return "idle"
	end
	if not st.owed then
		if DP.random() >= rate * DP.PERIOD / 60 then
			return "idle"
		end
		count("rolls")
	end
	if DP.live_near(pos) >= DP.cap(pos.y) then
		st.owed = nil
		return count("cap")
	end
	st.owed = true
	local mob = DP.pick(pos.y, DP.random())
	local eye = {x = pos.x, y = pos.y + DP.EYE, z = pos.z}
	local spot = DP.find_spot(eye, mob, DP.world, DP.random)
	if not spot then
		return count("no_spot")
	end
	local refused = DP.refused(mob, spot)
	if refused then
		return count(refused)
	end
	st.owed = nil
	st.pending = {spot = spot, mob = mob, start = now, phase = 1}
	DP.effect("depth_windup", spot)
	return count("placed")
end

-- One live arrival, once a second: fade it after FADE_AFTER s without a
-- target. Returns false when the record is finished.
function DP.arrival_tick(rec, now)
	local ent = rec.obj and rec.obj:get_luaentity()
	if not ent or (ent.health or 0) <= 0 then
		return false
	end
	local target = ent.attack
	if target and target.get_pos and target:get_pos() then
		rec.lost_since = nil
		return true
	end
	rec.lost_since = rec.lost_since or now
	if now - rec.lost_since < DP.FADE_AFTER then
		return true
	end
	local pos = rec.obj:get_pos()
	if pos then
		DP.effect("depth_burst", pos)
	end
	rec.obj:remove()
	count("faded")
	return false
end

-- One slice of one second: the players and the arrivals whose index falls
-- in it. The finished arrival records are dropped once per second.
function DP.step(slice, now)
	local players = DP.players()
	for i = 1, #players do
		if i % DP.SLICES == slice then
			DP.player_tick(players[i], now)
		end
	end
	local list = DP.arrivals
	for i = 1, #list do
		local rec = list[i]
		if i % DP.SLICES == slice and not rec.done then
			rec.done = DP.arrival_tick(rec, now) == false
		end
	end
	if slice == 0 then
		local kept = {}
		for i = 1, #list do
			if not list[i].done then
				kept[#kept + 1] = list[i]
			end
		end
		DP.arrivals = kept
	end
end

local clock, acc, slice = 0, 0, 0
local spawning = core.settings:get_bool("mobs_spawn") ~= false

core.register_globalstep(function(dtime)
	clock = clock + dtime
	acc = acc + dtime
	if acc < DP.PERIOD / DP.SLICES then
		return
	end
	acc = 0
	if not spawning then
		return
	end
	slice = (slice + 1) % DP.SLICES
	DP.step(slice, clock)
end)

core.register_on_leaveplayer(function(player)
	DP.state[player:get_player_name()] = nil
end)

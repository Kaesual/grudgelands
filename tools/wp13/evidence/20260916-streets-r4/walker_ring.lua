-- WHY A CAPITAL SHIPS A WALKER WITH NOWHERE TO WALK, offline.
--
--     luajit tools/wp13/evidence/20260916-streets-r4/walker_ring.lua <repo> [seed]
--
-- Round 4, goal D. The engine probe reports `min_walker_ring=1` at Highcourt on
-- `main` and has done since wave 3 (`docs/research/wp13-polish-wave3.md`
-- section 5.1, "BOTH ARE PRE-EXISTING"): at least one of its walkers was handed
-- a wander ring of ONE spot, and a ring of one is a walker that never moves.
-- The brief asked this lane to find the CAUSE and to fix it if it turns out to
-- be street or lot geometry.
--
-- It is neither, so this file is the measurement that says so and hands the
-- finding on with a name attached. It replays, with no engine and no world, the
-- two rules that decide a ring:
--
--   * `mods/ENTITIES/grug_mobs/start_npcs.lua`, THE 80/20 SPLIT: among a
--     settlement's `idle` SPAWN sockets in authored order, every fifth one --
--     starting with the first -- hosts a walker;
--   * the same file's `bounded_spots`: a resident's ring is the idle sockets of
--     ITS OWN COMPOSITION within `WALK_RADIUS` (20) of its own socket, and a
--     walker whose ring came out shorter than `WALK_MIN_RING` (3) is topped up
--     from the nearest eligible spots of that same composition -- "and settles
--     for whatever the composition can actually offer".
--
-- A composition that publishes exactly ONE idle socket therefore has nothing to
-- top up from, and if the 80/20 counter lands on that socket the walker's ring
-- is 1. That is a socket-placement property of the composition, not of the
-- streets or of where a lot stands.
--
-- Plain Lua 5.1, LuaJIT in practice (the WP40 height session); no engine.

local repo = assert(arg[1], "repository root required")
local seed = arg[2] or "531802985935182545"

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = common.new_sha256()

local source_map = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source_map,
	schemas = schemas, canonical = canonical, deterministic = deterministic,
	raw_sha256 = sha}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source_map,
	canonical = canonical, deterministic = deterministic, raw_sha256 = sha,
	horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)

-- The two constants and the two rules, read off the production file rather
-- than retyped, so this measurement cannot drift from what the server does.
local npcs = io.open(repo .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")
local npc_text = assert(npcs):read("*a")
npcs:close()
local WALKER_EVERY = tonumber(npc_text:match("local WALKER_EVERY = (%d+)"))
local WALK_RADIUS = tonumber(npc_text:match("local WALK_RADIUS = (%d+)"))
local WALK_MIN_RING = tonumber(npc_text:match("local WALK_MIN_RING = (%d+)"))
assert(WALKER_EVERY and WALK_RADIUS and WALK_MIN_RING,
	"start_npcs.lua no longer spells the three constants this reads")

local function composition_of(socket_id)
	return socket_id:match("^([^/]+)/") or "-"
end

local KEYS = {"highcourt", "dur_brannoc", "gor_drazhak", "lethariel",
	"kezamba", "nhal_veyr"}

io.write("capital\tsockets\tidle\tspares\twalkers\tmin_ring\tworst_socket\t",
	"worst_composition\tcomposition_idle\n")
local worst_overall = nil
for _, key in ipairs(KEYS) do
	local profile
	for index = 1, #settlement.roster do
		if settlement.roster[index].key == key then
			profile = settlement.roster[index]
		end
	end
	assert(profile, "the roster has no " .. key)
	local source = dofile(wp40 .. "/" .. profile.blueprint_file)()
	local prepared = settlement.prepare(profile, source, sha)
	local anchor = {x = profile.x, y = profile.y or 0, z = profile.z}
	local rows = settlement.sockets(prepared, anchor, function(x, z)
		return height.terrain_height_at(x, z)
	end)

	-- The idle groups, per composition, in authored order -- exactly the table
	-- `start_npcs.lua` builds, spares included.
	local groups, order = {}, {}
	local walkers, idle_spawn, spares = {}, 0, 0
	for index = 1, #rows do
		local socket = rows[index]
		if socket.role == "idle" then
			local group = composition_of(socket.id)
			local spots = groups[group]
			if not spots then
				spots = {}
				groups[group] = spots
				order[#order + 1] = group
			end
			spots[#spots + 1] = {x = socket.x, y = socket.y, z = socket.z,
				id = socket.id, spare = socket.spawn == false or nil}
			if socket.spawn == false then
				spares = spares + 1
			else
				idle_spawn = idle_spawn + 1
				if (idle_spawn - 1) % WALKER_EVERY == 0 then
					walkers[socket.id] = #spots
				end
			end
		end
	end

	-- And the ring every walker is handed.
	local min_ring, worst_id, worst_group, worst_size = nil, "-", "-", 0
	local walker_count = 0
	for group_index = 1, #order do
		local group = order[group_index]
		local spots = groups[group]
		for home_index = 1, #spots do
			local home = spots[home_index]
			if walkers[home.id] then
				walker_count = walker_count + 1
				local kept, shortfall = 1, 0
				for other = 1, #spots do
					if other ~= home_index then
						local dx = spots[other].x - home.x
						local dz = spots[other].z - home.z
						if dx * dx + dz * dz <= WALK_RADIUS * WALK_RADIUS then
							kept = kept + 1
						else
							shortfall = shortfall + 1
						end
					end
				end
				if kept < WALK_MIN_RING and shortfall > 0 then
					local room = WALK_MIN_RING - kept
					kept = kept + ((shortfall < room) and shortfall or room)
				end
				if min_ring == nil or kept < min_ring then
					min_ring = kept
					worst_id, worst_group, worst_size = home.id, group, #spots
				end
			end
		end
	end
	io.write(key, "\t", #rows, "\t", idle_spawn, "\t", spares, "\t",
		walker_count, "\t", tostring(min_ring), "\t", worst_id, "\t",
		worst_group, "\t", worst_size, "\n")
	if min_ring ~= nil and (worst_overall == nil or min_ring < worst_overall) then
		worst_overall = min_ring
	end
end
io.write("\nWALKER_EVERY=", WALKER_EVERY, " WALK_RADIUS=", WALK_RADIUS,
	" WALK_MIN_RING=", WALK_MIN_RING, " worst ring over the six capitals=",
	tostring(worst_overall), " seed=", seed, "\n")

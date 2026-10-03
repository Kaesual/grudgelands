-- Round 31 Lane S portable test (LuaJIT): the PvP POI blueprints
-- (`r31_pvp_poi_blueprint.lua`: the fortress per faction and the two camp
-- layouts in all six race palettes) and their registered form
-- (`r31_pvp_catalog.lua`, the `r7_settlement` binding, the fitting
-- profiles, the grug_core socket registry).
--
--   luajit tools/r31_s/portable_test.lua [REPO]
--
-- For every composition (fortress x 2 factions, camp low/high x 6 races) and
-- every quarter turn 0..3:
--   1. the blueprint passes the settlement validator the bandit camps pass
--      (`r7_settlement.prepare`: schema, byte-sorted palette, canonical
--      z/y/x unique cells inside the kind's `r7_settlement.BOUNDS` box,
--      declared bounds equal the cells', anchor support and an empty root);
--      building twice gives the same identity;
--   2. every palette name is a registered node;
--   3. the sockets (`r7_settlement.sockets`): unique ids, the role counts of
--      pvp-plan ruling 17 and its defaults (fortress: 2 gate guards, >= 8
--      inner elites, one General, 2 bodyguards, >= 2 quest givers, one
--      Quartermaster, one waystone, no innkeeper; camps: 4 or 5 guards and
--      one captain), each standing on ground with feet and head air (the
--      waystone socket on its waystone); the grug_core registry accepts them;
--      no id is one of the Round 14 quest ids grug_mobs reads a settlement's
--      kind from;
--   4. walking on the ground course from outside the gate reaches every
--      socket, and the gate is the footprint's only opening at ground level;
--   5. a turn keeps the cell count and moves the gate with it.
-- Then the registered form:
--   6. each kind's fitting core (source/simple_map.lua) holds its box;
--   7. the catalogue: 2 fortresses and 16 camps (per Battlegrounds zone and
--      faction one low and one high), unique keys and slots, level bands;
--   8. the real source binds all 18 rows to its anchors 101..118 (lane M)
--      and the roster carries them; on the source without them, synthetic
--      anchors for every row bind all 18 (template, gate turn rule) and each
--      builds, prepares and registers as the runtime does it, a camp under
--      the race it rolled; anchors for only some rows, or none, are refused;
--   9. the camp race roll is deterministic, always of the camp's faction,
--      and reaches all three races over anchors and seeds.
-- Prints "R31 S PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

_G.core = _G.core or {}
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local build = dofile(dir .. "/r31_pvp_poi_blueprint.lua")
local settlement = dofile(dir .. "/r7_settlement.lua")
local sha = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local rot = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/plot_approach.lua").rot
local catalog = dofile(dir .. "/r31_pvp_catalog.lua")
-- The real socket registry under two engine stubs.
_G.grug_core = {}
core.dir_to_yaw = function(d) return math.atan2(-d.x, d.z) end
_G.vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
local registered_keys = 0
local function register(key, race, rows, label)
	registered_keys = registered_keys + 1
	return grug_core.register_settlement_sockets(key .. "#" .. registered_keys, race,
		{x = 0, y = 10, z = 0}, rows, label)
end

local function read(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

-- Registered node names: the static tile index of the wp13 renderer, the
-- loop-registered wool colours, and grug_mapgen's own node file (the
-- waystone) for the rest.
local tiles = read(repo .. "/tools/wp13/node_tiles.json")
local registered_cache = {}
local function registered(name)
	if registered_cache[name] ~= nil then return registered_cache[name] end
	local ok = name == "air" or tiles:find('"' .. name:gsub("%p", "%%%0") .. '": {', 1) ~= nil
	local colour = name:match("^wool:(.+)$")
	if not ok and colour then
		ok = read(repo .. "/mods/BASE/wool/textures/wool_" .. colour .. ".png") ~= nil
	end
	if not ok then
		local source = read(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua") or ""
		ok = source:find('register_node("' .. name .. '"', 1, true) ~= nil
	end
	registered_cache[name] = ok
	return ok
end

local RACES = {human = "accord", dwarf = "accord", elf = "accord",
	orc = "throng", undead = "throng", troll = "throng"}
local compositions = {
	{kind = "pvp_fortress", faction = "accord"}, {kind = "pvp_fortress", faction = "throng"}}
for _, kind in ipairs({"pvp_camp_low", "pvp_camp_high"}) do
	for _, race in ipairs({"human", "dwarf", "elf", "orc", "undead", "troll"}) do
		compositions[#compositions + 1] = {kind = kind, faction = RACES[race], race = race}
	end
end
local GATE_WIDTH = {pvp_fortress = 5, pvp_camp_low = 3, pvp_camp_high = 3}

local function profile_for(c, turns)
	local stem = "grug_r31_test_" .. c.kind .. "_" .. (c.race or c.faction)
	return {key = stem, label = stem, race = c.race or "human", slot = "pvp_test",
		bounds = c.kind, lazy = true, reserve_anchor_root = true,
		zone_id = "test_zone", anchor_id = "anchor_test", numeric_id = 1, x = 0, z = 0,
		blueprint_file = "r31_pvp_poi_blueprint.lua", blueprint_schema = stem .. "_v1",
		identity_schema = stem .. "_identity_v1", config_schema = stem .. "_config_v1",
		ledger_schema = stem .. "_ledger_v1", metrics_schema = stem .. "_metrics_v1",
		delta_schema = stem .. "_delta_v1",
		art = {kind = c.kind, faction = c.faction, race = c.race, turns = turns}}
end

for _, c in ipairs(compositions) do
	local label0 = c.kind .. " " .. (c.race or c.faction)
	local count0
	for turns = 0, 3 do
		local label = label0 .. " turn " .. turns
		local profile = profile_for(c, turns)
		local bp = build({}, profile)
		local r = bp.bounds.max.x
		-- 1. the validator, twice for the identity
		local ok, prepared = pcall(settlement.prepare, profile, bp, sha)
		check(ok, label .. ": r7_settlement.prepare: " .. tostring(prepared))
		local again = settlement.prepare(profile, build({}, profile), sha)
		check(again.blueprints[1].identity.sha256 == prepared.blueprints[1].identity.sha256,
			label .. ": identity is deterministic")
		if turns == 0 then count0 = #bp.cells end
		check(#bp.cells == count0, label .. ": a turn keeps the cell count")
		-- 2. registered nodes
		for _, name in ipairs(bp.palette) do
			check(registered(name), label .. ": node " .. name .. " is registered")
		end
		-- the cell grid
		local grid = {}
		for _, cell in ipairs(bp.cells) do grid[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name end
		local function at(x, y, z) return grid[x .. ":" .. y .. ":" .. z] end
		local function standing(x, z)
			local ground = at(x, 0, z)
			return ground ~= nil and ground ~= "air" and at(x, 1, z) == "air" and at(x, 2, z) == "air"
		end
		-- 3. sockets
		local rows = settlement.sockets(prepared, {x = 0, y = 0, z = 0})
		local seen, roles, groups = {}, {}, {}
		for _, s in ipairs(rows) do
			check(not seen[s.id], label .. ": socket id " .. s.id .. " unique")
			check(not ({quest_steward = true, quest_scout = true, quest_captive = true,
				quest_host = true})[s.id], label .. ": " .. s.id .. " is no Round 14 POI marker id")
			seen[s.id] = true
			roles[s.role] = (roles[s.role] or 0) + 1
			if s.role == "guard_post" then
				local tag = s.tags and s.tags[1]
				check(tag and #s.tags == 1, label .. ": guard " .. s.id .. " carries one tag")
				groups[tag] = (groups[tag] or 0) + 1
			end
			if s.role == "waypoint" then
				check(at(s.x, 1, s.z) == "grug_mapgen:waystone", label .. ": waystone at its socket")
			else
				check(standing(s.x, s.z), label .. ": socket " .. s.id .. " stands on ground with air above")
			end
		end
		if c.kind == "pvp_fortress" then
			check(groups.gate == 2, label .. ": two gate guards")
			check((groups.inner or 0) >= 8, label .. ": at least 8 inner elites")
			check(roles.guard_post == groups.gate + groups.inner, label .. ": guard groups")
			check(roles.general == 1 and roles.bodyguard == 2, label .. ": General and 2 bodyguards")
			check((roles.quest or 0) >= 2, label .. ": quest givers")
			check(roles.vendor == 1, label .. ": one Quartermaster")
			for _, s in ipairs(rows) do
				if s.role == "vendor" then check(s.kind == "general", label .. ": Quartermaster is the general vendor") end
			end
			check(roles.waypoint == 1 and seen.travel_waypoint, label .. ": one waystone")
			check(roles.innkeeper == nil, label .. ": no innkeeper")
		else
			local guards = c.kind == "pvp_camp_low" and 4 or 5
			check(roles.guard_post == guards and roles.captain == 1,
				label .. ": " .. guards .. " guards and a captain")
			check(groups.gate == 2, label .. ": two of them hold the gate")
		end
		check(register(profile.key, bp.landmarks.race, rows, profile.label) == #rows,
			label .. ": the grug_core registry takes every socket")
		check(bp.landmarks.faction == c.faction and
			bp.landmarks.race == (c.race or catalog.SEAT_RACE[c.faction]),
			label .. ": published race and faction")
		-- 4. walking from outside the gate; the gate is the only way in
		local gx, gz = rot(0, -r, turns)
		check(standing(gx, gz), label .. ": the gate is open at ground level")
		local reached, queue, head = {[gx .. ":" .. gz] = true}, {{gx, gz}}, 1
		while queue[head] do
			local x, z = queue[head][1], queue[head][2]
			head = head + 1
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local nx, nz = x + d[1], z + d[2]
				local k = nx .. ":" .. nz
				if not reached[k] and math.abs(nx) <= r and math.abs(nz) <= r and standing(nx, nz) then
					reached[k] = true
					queue[#queue + 1] = {nx, nz}
				end
			end
		end
		for _, s in ipairs(rows) do
			local near = reached[s.x .. ":" .. s.z]
			if s.role == "waypoint" then
				near = reached[(s.x + 1) .. ":" .. s.z] or reached[(s.x - 1) .. ":" .. s.z] or
					reached[s.x .. ":" .. (s.z + 1)] or reached[s.x .. ":" .. (s.z - 1)]
			end
			check(near, label .. ": socket " .. s.id .. " is reached from the gate")
		end
		local openings = 0
		for x = -r, r do for z = -r, r do
			if math.max(math.abs(x), math.abs(z)) == r and standing(x, z) then
				openings = openings + 1
				-- 5. the opening lies on the turned gate side
				local lx, lz = rot(x, z, (4 - turns) % 4)
				check(lz == -r and math.abs(lx) <= (GATE_WIDTH[c.kind] - 1) / 2,
					label .. ": ground opening only at the gate (" .. x .. "," .. z .. ")")
			end
		end end
		check(openings == GATE_WIDTH[c.kind], label .. ": the gate is " .. GATE_WIDTH[c.kind] .. " wide")
		if turns == 0 then
			print(("  %-26s %2dx%-2d h%-2d %5d cells %3d names, %2d sockets, sha %s"):format(label0,
				2 * r + 1, 2 * r + 1, bp.bounds.max.y, #bp.cells, #bp.palette, #rows,
				prepared.blueprints[1].identity.sha256:sub(1, 12)))
		end
	end
end

-- 6. fitting cores
local source = dofile(dir .. "/source/simple_map.lua")
local fitting = {}
for _, p in ipairs(source.anchor_profiles) do fitting[p.id] = p end
for _, kind in ipairs({"pvp_fortress", "pvp_camp_low", "pvp_camp_high"}) do
	local b, p = settlement.BOUNDS[kind], fitting[kind]
	check(b and p, kind .. ": bounds and fitting profile")
	local half = p.building_core_width / 2
	check(-half <= b.min.x and half - 1 >= b.max.x and -half <= b.min.z and half - 1 >= b.max.z,
		kind .. ": the fitting core holds the blueprint box")
	check(p.fitting_width >= p.building_core_width and p.blend_width > p.fitting_width,
		kind .. ": fitting and blend widths")
end

-- 7. the catalogue
local keys, slots, counts = {}, {}, {}
local zone_of = {}
for i, z in ipairs(source.zones) do zone_of[z.id] = {index = i, row = z} end
for _, row in ipairs(catalog.rows) do
	check(not keys[row.key], "catalogue key " .. row.key .. " unique")
	keys[row.key] = true
	local slot = row.zone_id .. "/" .. row.slot
	check(not slots[slot], "catalogue slot " .. slot .. " unique")
	slots[slot] = true
	check(zone_of[row.zone_id] ~= nil, row.key .. ": zone exists")
	check(settlement.BOUNDS[row.kind] ~= nil and fitting[row.kind] ~= nil, row.key .. ": kind is known")
	counts[row.kind .. "/" .. row.faction] = (counts[row.kind .. "/" .. row.faction] or 0) + 1
	if row.band then
		local z = zone_of[row.zone_id].row
		check(z.id:find("^front_") and z.level_min >= 41, row.key .. ": a Battlegrounds zone")
		local lo, hi = catalog.camp_levels(z.level_min, z.level_max, row.band)
		check(hi - lo == 2 and lo >= z.level_min and hi <= z.level_max, row.key .. ": level band")
		if row.zone_id == "front_broken_causeway" then
			check((row.band == "low" and lo == 41) or (row.band == "high" and lo == 48),
				row.key .. ": ruling 19 example bands")
		end
	end
end
check(#catalog.rows == 18, "18 PvP POIs")
for _, f in ipairs({"accord", "throng"}) do
	check(counts["pvp_fortress/" .. f] == 1 and counts["pvp_camp_low/" .. f] == 4 and
		counts["pvp_camp_high/" .. f] == 4, f .. ": one fortress and 8 camps")
end

-- 8. the binding: the source's anchors 101..118 (lane M) bind every row,
-- and the roster carries them; on the source without them (the first 100
-- anchors) synthetic positions bind, and a missing anchor is refused.
local bound = settlement.pvp_profiles(source)
check(#bound == 18, "the source binds all 18 PvP rows")
local in_roster = 0
for _, profile in ipairs(settlement.roster) do
	if profile.blueprint_file == "r31_pvp_poi_blueprint.lua" then in_roster = in_roster + 1 end
end
check(in_roster == 18, "the roster carries the 18 PvP POIs")
for i, profile in ipairs(bound) do
	check(profile.numeric_id == 100 + i and source.anchors[100 + i].slot_id == profile.slot,
		profile.key .. ": source anchor " .. (100 + i))
end
local function with_anchors(rows)
	local copy = {}
	for k, v in pairs(source) do copy[k] = v end
	copy.anchors = {}
	for i = 1, 100 do copy.anchors[i] = source.anchors[i] end
	for i, row in ipairs(rows) do
		local z = zone_of[row.zone_id]
		local n = #copy.anchors + 1
		-- positions either side of x = 0 and on it (the gate turn rule)
		copy.anchors[n] = {numeric_id = n, id = ("anchor_%03d"):format(n),
			zone_numeric_id = z.index, slot_id = row.slot, template_id = row.kind,
			position = {x = ({-150, 0, 150})[i % 3 + 1], z = 0}}
	end
	return copy
end
local partial = {catalog.rows[1], catalog.rows[3]}
check(not pcall(settlement.pvp_profiles, with_anchors(partial)), "a partial anchor set is refused")
check(not pcall(settlement.pvp_profiles, with_anchors({})), "no anchors at all is refused")
local profiles = settlement.pvp_profiles(with_anchors(catalog.rows))
check(#profiles == 18, "all 18 rows bind their anchors")
for i, profile in ipairs(profiles) do
	local row = catalog.rows[i]
	check(profile.key == row.key and profile.numeric_id == 100 + i and
		profile.bounds == row.kind and profile.slot == row.slot, row.key .. ": bound profile")
	local x = profile.x
	local want = row.kind == "pvp_fortress" and (x > 0 and 1 or x < 0 and 3) or
		(row.faction == "accord" and 0 or 2)
	check(profile.art.turns == want, row.key .. ": gate turn rule")
	for _, seed in ipairs({"42", "7", "-12345678901234"}) do
		local options = {full_seed = seed, raw_sha256 = sha}
		local src = dofile(dir .. "/" .. profile.blueprint_file)(options, profile)
		local prepared = settlement.prepare(profile, src, sha)
		local race = prepared.blueprints[1].landmarks.race
		local again = settlement.prepare(profile, dofile(dir .. "/" .. profile.blueprint_file)(options, profile), sha)
		check(again.blueprints[1].identity.sha256 == prepared.blueprints[1].identity.sha256,
			row.key .. ": identity per seed is deterministic")
		if row.kind == "pvp_fortress" then
			check(race == catalog.SEAT_RACE[row.faction], row.key .. ": fortress race")
		else
			check(race == catalog.camp_race(sha, seed, profile.numeric_id, row.faction), row.key .. ": rolled race")
		end
		local socket_rows = settlement.sockets(prepared, {x = profile.x, y = 20, z = profile.z})
		check(register(profile.key, race, socket_rows, profile.label) == #socket_rows,
			row.key .. ": registers")
	end
end

-- 9. the race roll
for _, faction in ipairs({"accord", "throng"}) do
	local hits = {}
	for n = 101, 118 do
		for _, seed in ipairs({"1", "42", "7", "2026", "99999999999"}) do
			local race = catalog.camp_race(sha, seed, n, faction)
			check(race == catalog.camp_race(sha, seed, n, faction), "roll is deterministic")
			local ok = false
			for _, r in ipairs(catalog.FACTION_RACES[faction]) do ok = ok or r == race end
			check(ok, faction .. ": rolled race " .. tostring(race) .. " is of the faction")
			hits[race] = (hits[race] or 0) + 1
		end
	end
	for _, r in ipairs(catalog.FACTION_RACES[faction]) do
		check((hits[r] or 0) >= 15, faction .. ": " .. r .. " is rolled (" .. (hits[r] or 0) .. " of 90)")
	end
end
-- The seed reshuffles the whole world: the 16 camps' races (anchors
-- 103..118, as the synthetic binding numbers them) form many distinct
-- layouts over 18 seeds, not a few rotations of one pattern.
local layouts, distinct = {}, 0
for s = 1, 18 do
	local seed = tostring(s * 7919 - 40000)
	local parts = {}
	for i, row in ipairs(catalog.rows) do
		if row.band then parts[#parts + 1] = catalog.camp_race(sha, seed, 100 + i, row.faction) end
	end
	local layout = table.concat(parts, ",")
	if not layouts[layout] then layouts[layout] = true; distinct = distinct + 1 end
end
check(distinct >= 10, ("distinct camp race layouts over 18 seeds: %d"):format(distinct))
print(("  camp race layouts over 18 seeds: %d distinct"):format(distinct))
print(("R31 S PORTABLE PASS checks=%d"):format(checks))

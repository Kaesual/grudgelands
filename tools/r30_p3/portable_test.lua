-- Round 30 Lane P3 portable test (LuaJIT): the region-map cache and the
-- compact form (grug_mobs/spawn_regions_cache.lua, spawn_regions.lua
-- SR.start_maps), on the analytic world of one seed.
--
--   luajit tools/r30_p3/portable_test.lua SEED DIR  (repo root; DIR an empty
--                                                   scratch folder, the world's)
--   tools/r30_p3/run.sh                             (seeds 12345 and 42)
--
-- Builds the seed's world with tools/r28_zone_atlas/world.lua (as main builds
-- it) and loads the game's spawn_regions.lua on it under a small `core` stub
-- whose world folder is a scratch directory. Then:
--   1. input coverage: io.open, dofile, loadfile and get_dir_list are wrapped
--      from loading spawn_regions.lua to the end of a cold start; every file
--      read must be covered by the cache key (a builder file, a zone's recipe
--      file, or a Lua file of the mapgen tree, whose digest is the mapgen part;
--      the cache file itself aside);
--   2. a cold start builds every recipe zone and stores the file;
--   3. every zone's compact map equals a fresh full build: the region at every
--      land cell and a one-cell ring (seven points each), every region's
--      fields, leaders, camps, kinds, the zone frame, problems and warnings,
--      and describe for every leader, camp and kind in all three modes;
--   4. a second build encodes byte-identically to the stored file;
--   5. a warm start reads every zone from the file, writes nothing, and its
--      maps equal the full builds again;
--   6. a changed recipe digest rebuilds only that zone; the replaced file is
--      byte-identical to the first;
--   7. every corruption case of decode returns nil, a reason and the damaged
--      flag and never raises; payloads that do not fit the recipe (unknown
--      kind, camp or leader, region id out of range) rebuild only their zone
--      with a warning; a damaged file rebuilds everything with a warning; each
--      replaced file equals the first.
-- Prints "R30 P3 PORTABLE PASS seed=<seed> checks=<n>" or raises.
local repo = "."
local seed = assert(arg[1], "usage: portable_test.lua SEED DIR")
local WORLD = assert(arg[2], "usage: portable_test.lua SEED DIR")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local t_start = os.clock()
local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
local world_seconds = os.clock() - t_start
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha = common.new_sha256()
local function sha256(bytes) return common.hex(raw_sha(bytes)) end
local MOBS = repo .. "/mods/ENTITIES/grug_mobs"
local MAPGEN = repo .. "/mods/MAPGEN/grug_mapgen"

local function read(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local t = f:read("*a")
	f:close()
	return t
end
local function write(path, bytes)
	local f = assert(io.open(path, "wb"))
	f:write(bytes)
	f:close()
end
local FILE = WORLD .. "/grug_region_maps.txt"

-- The zone recipe files, as the engine lists the data directory.
local zone_files = {}
for _, row in ipairs(W.source.zones) do
	if read(MOBS .. "/data/zones/" .. row.id .. ".spawns.json") then
		zone_files[#zone_files + 1] = row.id .. ".spawns.json"
	end
end

-- One game environment: spawn_regions.lua loaded fresh on the shared world,
-- with a log and a write counter.
local function noop() end
local function new_game()
	local G = {logs = {}, writes = 0}
	local env = setmetatable({}, {__index = _G})
	env._G = env
	env.core = {
		get_modpath = function(name)
			if name == "grug_mapgen" then return MAPGEN end
			if name == "grug_core" then return repo .. "/mods/CORE/grug_core" end
			return MOBS
		end,
		get_current_modname = function() return "grug_mobs" end,
		get_dir_list = function() return zone_files end,
		parse_json = json.parse,
		register_globalstep = noop,
		register_on_mods_loaded = noop,
		register_lbm = noop,
		settings = {get = function() return nil end, get_bool = function() return nil end},
		get_us_time = function() return os.clock() * 1e6 end,
		get_worldpath = function() return WORLD end,
		sha256 = sha256,
		safe_file_write = function(path, bytes)
			G.writes = G.writes + 1
			write(path .. ".tmp", bytes)
			return os.rename(path .. ".tmp", path) == true
		end,
		log = function(level, msg) G.logs[#G.logs + 1] = {level, msg} end,
	}
	env.grug_zones = W.session
	env.grug_mapgen = {wp40 = {planner_source = W.planner_source,
		road_polylines = W.wp40.road_polylines,
		world_key = {seed = seed, source = "offline-mapgen-digest",
			settings = "offline", interpreter = tostring(jit and jit.version or _VERSION)}}}
	env.grug_core = {register_level_overlay = noop}
	env.grug_mobs = {storage = {get_int = function() return 0 end, set_int = noop},
		settle_mob_death = noop}
	local chunk = assert(loadfile(MOBS .. "/spawn_regions.lua"))
	setfenv(chunk, env)
	G.env = env
	G.load = function() chunk() end
	return G
end
local function count_logs(G, level, text)
	local n = 0
	for _, row in ipairs(G.logs) do
		if (not level or row[1] == level) and row[2]:find(text, 1, true) then n = n + 1 end
	end
	return n
end
local function summary(G)
	for _, row in ipairs(G.logs) do
		local hits, built = row[2]:match("ready at start in [%d.]+ ms %((%d+) from %S+, (%d+) built")
		if hits then return tonumber(hits), tonumber(built), row end
	end
end

-- ---------------------------------------------------------------------------
-- 1 + 2. Cold start under the input-coverage wrappers
-- ---------------------------------------------------------------------------
local reads = {}
local real_open, real_dofile, real_loadfile = io.open, dofile, loadfile
local function note(path, how)
	reads[#reads + 1] = {tostring(path), how}
end
local cold = new_game()
local real_dir_list = cold.env.core.get_dir_list
io.open = function(path, mode, ...)
	if not mode or mode:find("r") then note(path, "io.open") end
	return real_open(path, mode, ...)
end
rawset(_G, "dofile", function(path, ...) note(path, "dofile"); return real_dofile(path, ...) end)
rawset(_G, "loadfile", function(path, ...) note(path, "loadfile"); return real_loadfile(path, ...) end)
cold.env.core.get_dir_list = function(path, ...) note(path, "get_dir_list"); return real_dir_list(path, ...) end
local ok_load, err_load = pcall(function()
	cold.load()
	cold.env.grug_mobs.spawn_regions.start_maps()
end)
io.open = real_open
rawset(_G, "dofile", real_dofile)
rawset(_G, "loadfile", real_loadfile)
cold.env.core.get_dir_list = real_dir_list
assert(ok_load, err_load)
local SR = cold.env.grug_mobs.spawn_regions
local CACHE, CORE = SR.cache, SR.core

do
	local covered = {}
	for _, f in ipairs(SR.BUILDER_FILES) do
		covered[cold.env.core.get_modpath(f[1]) .. "/" .. f[2]] = true
	end
	local zone_dir = MOBS .. "/data/zones"
	local bad = {}
	for _, row in ipairs(reads) do
		local path = row[1]
		local ok = covered[path] or path == FILE or
			(path:sub(1, #zone_dir + 1) == zone_dir .. "/" and path:match("%.spawns%.json$")) or
			(row[2] == "get_dir_list" and path == zone_dir) or
			(path:sub(1, #MAPGEN + 1) == MAPGEN .. "/" and path:match("%.lua$"))
		if not ok then bad[#bad + 1] = row[2] .. " " .. path end
	end
	check(#reads > 0, "the wrappers saw the reads")
	check(#bad == 0, "every file the builder reads is in the key: " .. table.concat(bad, ", "))
	print(("input coverage: %d reads, all in the key"):format(#reads))
end

local ids = {}
for _, zone_id in ipairs(SR.zone_ids()) do
	if SR.zone_has_recipe(zone_id) then ids[#ids + 1] = zone_id end
end
check(#ids == 38, "38 recipe zones (" .. #ids .. ")")
local hits, built = summary(cold)
check(hits == 0 and built == #ids and cold.writes == 1, "cold start builds every zone and stores")
local bytes1 = assert(read(FILE), "cache file stored")
check(bytes1:sub(1, 20) == "grug_region_maps_v1\n", "file header")
print(("cold start: %d zones built, file %d bytes"):format(built, #bytes1))

-- ---------------------------------------------------------------------------
-- 3. Compact maps equal fresh full builds
-- ---------------------------------------------------------------------------
local fulls = {}
local t0 = os.clock()
for _, zone_id in ipairs(ids) do
	fulls[zone_id] = assert(SR.full_map(zone_id))
end
local full_seconds = os.clock() - t0

local OFFS = {{16, 16}, {0, 0}, {31, 31}, {5, 27}, {31, 0}, {0, 31}, {12, 3}}
local N8 = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local function same_region(a, b)
	if a == nil or b == nil then return a == b end
	return a.id == b.id and a.kind == b.kind and a.belt == b.belt and a.x == b.x and
		a.z == b.z and a.size == b.size and a.level == b.level and a.levels == b.levels and
		(a.camp and a.camp.id) == (b.camp and b.camp.id)
end
local function same_result(a, b)
	if a == nil or b == nil then return a == b end
	for _, k in ipairs({"x", "z", "what", "distance", "dir", "phrase_key", "phrase"}) do
		if a[k] ~= b[k] then return false end
	end
	return true
end
local function equal_maps(zone_id, full, map)
	local where = zone_id .. ": "
	check(map.compact and map.cells == nil and map.order == nil, where .. "compact form")
	check(map.cell_count == #full.order, where .. "cell count")
	check(#map.regions == #full.regions, where .. "region count")
	for k, r in ipairs(full.regions) do
		check(same_region(r, map.regions[k]), where .. "region " .. k)
	end
	-- every land cell and a one-cell ring, seven points each
	local seen, points = {}, 0
	for _, c in ipairs(full.order) do
		for a = -1, 1 do
			for b = -1, 1 do
				local i, j = c.i + a, c.j + b
				local k = i .. ":" .. j
				if not seen[k] then
					seen[k] = true
					for _, o in ipairs(OFFS) do
						local x, z = i * 32 + o[1], j * 32 + o[2]
						local r1, r2 = full.region_at(x, z), map.region_at(x, z)
						if (r1 and r1.id) ~= (r2 and r2.id) then
							check(false, where .. "region_at " .. x .. "," .. z)
						end
						points = points + 1
					end
				end
			end
		end
	end
	check(#map.leaders == #full.leaders, where .. "leader count")
	for k, l in ipairs(full.leaders) do
		local m = map.leaders[k]
		check(m.role == l.role and m.x == l.x and m.z == l.z and m.level == l.level and
			m.respawn == l.respawn and m.region.id == l.region.id and m.fallback == l.fallback,
			where .. "leader " .. l.role)
	end
	check(#map.camps == #full.camps, where .. "camp count")
	for k, u in ipairs(full.camps) do
		local m = map.camps[k]
		check(m.id == u.id and m.camp == u.camp and m.x == u.x and m.z == u.z and
			m.region.id == u.region.id and m.score == u.score and m.slope == u.slope and
			m.poi_belt == u.poi_belt and m.site == u.site and m.tag == u.tag and
			m.belt == u.belt and m.rosters == u.rosters and m.levels_by_role == u.levels_by_role and
			m.levels == u.levels and m.is_camp == true and m.region.camp == m,
			where .. "camp " .. u.id)
	end
	for kind_id, list in pairs(full.by_kind) do
		local other = map.by_kind[kind_id]
		check(other and #other == #list, where .. "by_kind " .. kind_id)
		for k, r in ipairs(list) do check(other[k].id == r.id, where .. "by_kind order " .. kind_id) end
	end
	for kind_id in pairs(map.by_kind) do check(full.by_kind[kind_id], where .. "by_kind extra " .. kind_id) end
	check(#map.problems == #full.problems and #map.warnings == #full.warnings, where .. "findings")
	for k, t in ipairs(full.problems) do check(map.problems[k] == t, where .. "problem " .. k) end
	for k, t in ipairs(full.warnings) do check(map.warnings[k] == t, where .. "warning " .. k) end
	local f1, f2 = CORE.zone_frame(full), CORE.zone_frame(map)
	check(f1.x == f2.x and f1.z == f2.z and f1.hx == f2.hx and f1.hz == f2.hz, where .. "zone frame")
	local targets = {}
	for _, l in ipairs(map.recipe.leaders) do targets[#targets + 1] = l.role end
	for _, c in ipairs(map.recipe.camps) do targets[#targets + 1] = c.id end
	for _, kd in ipairs(map.recipe.kinds) do targets[#targets + 1] = kd.id end
	local hub = W.session.get(zone_id).hub or {x = 0, z = 0}
	local refs = {of = {x = hub.x + 123, z = hub.z - 456, name = "Somewhere"},
		from = {x = hub.x, z = hub.z}}
	for _, t in ipairs(targets) do
		for _, mode in ipairs({"of", "from", "zone"}) do
			local a, ra = CORE.describe(full, t, mode, refs[mode], "Zone")
			local b, rb = CORE.describe(map, t, mode, refs[mode], "Zone")
			check(same_result(a, b) and ra == rb, where .. "describe " .. t .. " " .. mode)
		end
	end
	return points
end

local points = 0
for _, zone_id in ipairs(ids) do
	points = points + equal_maps(zone_id, fulls[zone_id], SR.map(zone_id))
end
print(("compact maps equal full builds: %d zones, %d region_at points (full builds %.1f s)"):format(
	#ids, points, full_seconds))

-- ---------------------------------------------------------------------------
-- 4. A second build encodes byte-identically
-- ---------------------------------------------------------------------------
local parts = {{"format", CACHE.FORMAT}}
for name, value in bytes1:gmatch("\n([%a_]+)=([^\n]*)") do
	parts[#parts + 1] = {name, value}
	if #parts == 6 then break end
end
local decoded1 = assert(CACHE.decode(bytes1, parts))
do
	local entries = {}
	for _, zone_id in ipairs(ids) do
		entries[#entries + 1] = {zone = zone_id, digest = decoded1[zone_id].digest,
			payload = CACHE.compact(fulls[zone_id])}
	end
	check(CACHE.encode(parts, entries) == bytes1, "a second build encodes byte-identically")
end

-- ---------------------------------------------------------------------------
-- 5. Warm start
-- ---------------------------------------------------------------------------
local function start(label)
	local G = new_game()
	G.load()
	local t = os.clock()
	G.env.grug_mobs.spawn_regions.start_maps()
	G.seconds = os.clock() - t
	G.SR = G.env.grug_mobs.spawn_regions
	G.label = label
	return G
end
local warm = start("warm")
hits, built = summary(warm)
check(hits == #ids and built == 0 and warm.writes == 0, "warm start reads every zone, writes nothing")
check(count_logs(warm, "action", "cache hit") == 1, "warm summary line says cache hit")
for _, zone_id in ipairs(ids) do
	local map = warm.SR.map(zone_id)
	-- the warm game parsed its own recipes: compare against its own build
	equal_maps(zone_id, assert(warm.SR.full_map(zone_id)), map)
end
-- the problems and warnings of the builds are logged again on a hit
do
	local n_build, n_hit = count_logs(cold, "warning", "[grug_mobs] spawn regions "),
		count_logs(warm, "warning", "[grug_mobs] spawn regions ")
	check(n_build == n_hit, "a hit re-logs the stored findings (" .. n_build .. "/" .. n_hit .. ")")
end
print(("warm start: %d zones from the file in %.1f ms"):format(hits, warm.seconds * 1000))

-- ---------------------------------------------------------------------------
-- 6. One changed recipe digest rebuilds only that zone
-- ---------------------------------------------------------------------------
local function rewrite(mutate)
	local decoded = assert(CACHE.decode(bytes1, parts))
	local entries = {}
	for _, zone_id in ipairs(ids) do
		local e = {zone = zone_id, digest = decoded[zone_id].digest, payload = decoded[zone_id].payload}
		mutate(e)
		entries[#entries + 1] = e
	end
	write(FILE, CACHE.encode(parts, entries))
end
local SMALL = ids[1]
for _, zone_id in ipairs(ids) do
	if fulls[zone_id].order and #fulls[zone_id].order < #fulls[SMALL].order then SMALL = zone_id end
end
rewrite(function(e) if e.zone == SMALL then e.digest = string.rep("0", 64) end end)
local one = start("digest")
hits, built = summary(one)
check(hits == #ids - 1 and built == 1 and one.writes == 1, "a changed recipe rebuilds only its zone")
check(count_logs(one, "action", "spawn regions " .. SMALL .. ":") == 1, "the rebuilt zone is " .. SMALL)
check(read(FILE) == bytes1, "the replaced file equals the first")
print(("changed digest: %s rebuilt alone"):format(SMALL))

-- ---------------------------------------------------------------------------
-- 7. Corruption
-- ---------------------------------------------------------------------------
local function rehash(head)
	return head .. "end " .. sha256(head) .. "\n"
end
local head1 = bytes1:sub(1, #bytes1 - 69)
local mid = math.floor(#bytes1 / 2)
local cases = {
	{"empty", "", true},
	{"header only", "grug_region_maps_v1\n", true},
	{"truncated key", bytes1:sub(1, 40), true},
	{"truncated half", bytes1:sub(1, mid), true},
	{"last byte missing", bytes1:sub(1, -2), true},
	{"flipped byte", bytes1:sub(1, mid - 1) ..
		string.char((bytes1:byte(mid) + 1) % 256) .. bytes1:sub(mid + 1), true},
	{"trailing bytes", bytes1 .. "x", true},
	{"not a cache file", "hello\nworld\n", true},
	{"other format", "grug_region_maps_v0" .. bytes1:sub(20), false},
	{"other seed", rehash((head1:gsub("\nseed=[^\n]*", "\nseed=1", 1))), false},
	{"key line renamed", rehash((head1:gsub("\nseed=", "\nsead=", 1))), true},
	{"zone length", rehash((head1:gsub("\n(zone %S+ %x+ )(%d+)\n", function(a, n)
		return "\n" .. a .. (tonumber(n) + 5) .. "\n" end, 1))), true},
	{"region row", rehash((head1:gsub("\nr (%S+) ", "\nr %1 x ", 1))), true},
	{"grid line", rehash((head1:gsub("\ngrid (%-?%d+)", "\ngrid x%1", 1))), true},
	{"zone twice", (function()
		local first = head1:match("\n(zone .-)\nzone ")
		return rehash(head1 .. first .. "\n")
	end)(), true},
}
for _, case in ipairs(cases) do
	local ok, out, reason, damaged = pcall(CACHE.decode, case[2], parts)
	check(ok, "decode never raises: " .. case[1] .. " " .. tostring(out))
	check(out == nil and type(reason) == "string" and damaged == case[3],
		"decode " .. case[1] .. ": " .. tostring(reason) .. " damaged=" .. tostring(damaged))
end
print(("decode: %d corruption cases refused"):format(#cases))

-- Payloads that pass every hash but do not fit the recipe: the zone rebuilds.
local unfit = {
	{"unknown kind", function(p)
		for _, r in ipairs(p.regions) do if not r.camp then r.id = "no_such_kind"; return end end
	end},
	{"unknown camp", function(p)
		for _, r in ipairs(p.regions) do if r.camp then r.id = "no_such_camp"; return true end end
		p.regions[1].camp, p.regions[1].id = true, "no_such_camp"
	end},
	{"unknown leader", function(p)
		if p.leaders[1] then p.leaders[1].role = "no_such_leader" else p.regions[1].belt = 99 end
	end},
	{"region id in the grid", function(p)
		p.grid = string.char(#p.regions + 1) .. p.grid:sub(2)
	end},
	{"camp region out of range", function(p)
		if p.camps[1] then p.camps[1].region = #p.regions + 1 else p.regions[1].belt = 0 end
	end},
	{"wide grid flag", function(p) p.wide = not p.wide; p.w = p.w end},
}
for _, case in ipairs(unfit) do
	if case[1] == "wide grid flag" then
		-- a grid length that differs is refused by decode (damaged file)
		local decoded = assert(CACHE.decode(bytes1, parts))
		local p = decoded[SMALL].payload
		p.wide = not p.wide
		local entries = {}
		for _, zone_id in ipairs(ids) do
			entries[#entries + 1] = {zone = zone_id, digest = decoded[zone_id].digest,
				payload = decoded[zone_id].payload}
		end
		local ok, out, reason, damaged = pcall(CACHE.decode, CACHE.encode(parts, entries), parts)
		check(ok and out == nil and damaged == true, "decode: grid length " .. tostring(reason))
	else
		rewrite(function(e) if e.zone == SMALL then case[2](e.payload) end end)
		local G = start(case[1])
		hits, built = summary(G)
		check(hits == #ids - 1 and built == 1, case[1] .. ": only the zone rebuilds")
		check(count_logs(G, "warning", "does not fit the recipe") == 1, case[1] .. ": a warning")
		check(read(FILE) == bytes1, case[1] .. ": the replaced file equals the first")
	end
end
print(("rehydrate: %d unfit payloads rebuilt their zone"):format(#unfit - 1))

-- A damaged file: everything rebuilds, with a warning, and the file is replaced.
write(FILE, bytes1:sub(1, mid))
local broken = start("damaged")
hits, built = summary(broken)
local _, _, line = summary(broken)
check(hits == 0 and built == #ids and line[1] == "warning", "a damaged file rebuilds everything with a warning")
check(read(FILE) == bytes1, "damaged: the replaced file equals the first")
-- No file at all: an action line, a build, a store.
os.remove(FILE)
local missing = start("missing")
hits, built = summary(missing)
_, _, line = summary(missing)
check(hits == 0 and built == #ids and line[1] == "action" and line[2]:find("no cache file", 1, true),
	"a missing file rebuilds with an action line")
check(read(FILE) == bytes1, "missing: the stored file equals the first")
os.remove(FILE)

print(("R30 P3 PORTABLE PASS seed=%s checks=%d (world %.1f s, total %.1f s)"):format(seed,
	checks, world_seconds, os.clock() - t_start))

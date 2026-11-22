-- Round 87 ROADS: the two-candidate routing study on a real world (the seed
-- fleet's runtime, tools/seed_fleet/runtime.lua: the real R7 planner under
-- LuaJIT, no engine). Offline only: the world is built by the live
-- road_layout.lua; the study runs on the patched router (router.lua).
--
--   luajit tools/r87_roads/run.lua before REPO WORLD_REPO SEED OUT_FILE
--     The old map's occupancy: WORLD_REPO's world of SEED (an older checkout,
--     e.g. a worktree of the release before a road change), every road
--     corridor of its finished layout (network, trails, capital streets; half
--     width + world_protection ROAD_SIDE) on that world's housing zones,
--     through REPO's road_reference.lua. OUT_FILE uses the game's sealed
--     format with the reconstructed map as its first generation.
--
--   luajit tools/r87_roads/run.lua claims REPO SEED OCCUPIED OUT_DIR
--     OCCUPIED comes from export_claims.py on a stopped chunk-aligned world.
--     Only the distinct occupied home chunks intersected cost extra.
--   luajit tools/r87_roads/run.lua study REPO SEED BEFORE OUT_DIR
--     BEFORE is a same-seed reference file from the game or the before command.
--     1. REPO's world of SEED, its network road build captured.
--     2. The patched router on the captured inputs: observing (must equal the
--        world's network layout byte for byte), then per weight the two
--        candidates.
--     3. R87_FULL=1 (default): REPO's world again with the patched router and
--        the first weight inside it, so the capital streets and connectors
--        follow; the full maps' newly occupied housing chunks and the claim
--        masks of both worlds (claim_mask.lua on tools/r85_mask/world.lua),
--        compared. Holds two worlds at once for a while (about 3 GB).
--     Environment: R87_WEIGHTS (comma list, default 8 path-cost units per new chunk), R87_FEE (the A* entry fee, default each weight).
--     OUT_DIR gets:
--       summary.txt          the report
--       decisions_<w>.tsv    per decision both candidates (w = "ordinary"
--                            for the observing build)
--       chunks.tsv           variant, cx, cz of every newly occupied chunk
--       roads_<w>.tsv        the network centrelines (id kind a b x z, every
--                            4th point and the last)
--       claims.tsv           (R87_FULL) faction, cx, cz, lost / gained /
--                            changed, the reason or the changed components
local floor = math.floor
local mode = arg[1]

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end
local function copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end
local function parse_key(key)
	local cx, cz = key:match("^(%-?%d+) (%-?%d+)$")
	return tonumber(cx), tonumber(cz)
end

-- WORLD_REPO's world of SEED. Every road_layout.lua the world loads is
-- `inject.source` (the patched router; nil: the live file), its network
-- build (not the capital planner's kit) recorded in `builds` with its inputs,
-- its layout text and CPU seconds; `inject.study` rides along in its opts.
local function world(world_repo, seed, inject)
	local saved = dofile
	local prior_repo = arg[1]
	arg[1] = world_repo -- the shared node harness reads its repository from the command line
	local builds = {}
	rawset(_G, "dofile", function(path)
		if type(path) ~= "string" or not path:match("/wp40/road_layout%.lua$") then
			return saved(path)
		end
		local M = inject and assert(loadstring(inject.source, "=road_layout.lua (r87 study)"))() or
			saved(path)
		local build = M.build
		M.build = function(s, opts)
			if opts.kit then return build(s, opts) end
			local run = opts
			if inject and inject.study then
				run = copy(opts)
				run.study = inject.study
			end
			local t0 = os.clock()
			local layout = build(s, run)
			builds[#builds + 1] = {seed = s, opts = opts, seconds = os.clock() - t0,
				text = M.serialize(layout)}
			return layout
		end
		return M
	end)
	local ok, R = pcall(function()
		return dofile(world_repo .. "/tools/seed_fleet/runtime.lua")(world_repo, seed)
	end)
	rawset(_G, "dofile", saved)
	arg[1] = prior_repo
	if not ok then error(R, 0) end
	return R, builds
end

-- Geographic housing ground: a column of a zone that can hold claim ground
-- for either faction (claim_mask.lua zone_allowed; housing design §2).
local function housing_of(Z, CM, bounds)
	local allowed = {}
	return function(x, z)
		x, z = floor(x + 0.5), floor(z + 0.5)
		if x < bounds.min_x or x > bounds.max_x or z < bounds.min_z or z > bounds.max_z then
			return false
		end
		local id = Z.id_at(x, z)
		if not id then return false end
		local a = allowed[id]
		if a == nil then
			local rec = Z.get(id)
			a = CM.zone_allowed("accord", rec) or CM.zone_allowed("throng", rec)
			allowed[id] = a
		end
		return a
	end
end

-- The chunks a list of corridors {X, Z, reach} newly occupies beyond `reference`.
local function occupancy(Ref, corridors, housing_at, reference)
	local occ, new = copy(reference or {}), {}
	for _, c in ipairs(corridors) do
		for key in pairs(Ref.collect(c, housing_at, occ)) do
			occ[key], new[key] = true, true
		end
	end
	return new
end
local function layout_corridors(wp, module, text)
	local out = {}
	for _, c in ipairs(wp.road_corridors(module, text)) do
		out[#out + 1] = {X = c.X, Z = c.Z, reach = c.half_width + c.side}
	end
	return out
end

local function setup(repo)
	local T = {repo = repo}
	T.wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	T.CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
	T.Ref = dofile(repo .. "/mods/PLAYER/grug_housing/road_reference.lua")(T.CM)
	T.Study = dofile(repo .. "/tools/r87_roads/study.lua")
	T.Router = dofile(repo .. "/tools/r87_roads/router.lua")
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	T.sha256 = function(bytes) return common.hex(sha(bytes)) end
	return T
end

--
-- before
--
if mode == "before" then
	local repo, world_repo, seed, out = arg[2], arg[3], arg[4], arg[5]
	assert(repo and world_repo and seed and out,
		"usage: run.lua before REPO WORLD_REPO SEED OUT_FILE")
	local T = setup(repo)
	local t0 = os.clock()
	local R = world(world_repo, seed)
	local wwp40 = world_repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local housing_at = housing_of(R.built.zones_session, T.CM,
		dofile(wwp40 .. "/source/simple_map.lua").world_bounds)
	local wp = dofile(wwp40 .. "/world_protection.lua")
	local module = R.main.road_module and R.main.road_module() or dofile(wwp40 .. "/road_layout.lua")
	local corridors = layout_corridors(wp, module, R.main.road_layout_text())
	local set = occupancy(T.Ref, corridors, housing_at, nil)
	local f = assert(io.open(out, "wb"))
	f:write(T.Ref.encode({seed = tostring(R.built.full_seed), map_reset = 0,
		previous = {}, chunks = set}, T.sha256))
	f:close()
	print(("before %s: %d corridors, %d housing chunks occupied, %.1f s"):format(seed, #corridors,
		T.Study.count(set), os.clock() - t0))
	return
end

assert(mode == "study" or mode == "claims", "usage: run.lua before|study|claims ... (see the header)")
local repo, seed, before_path, out = arg[2], arg[3], arg[4], arg[5]
assert(repo and seed and before_path and out, "usage: run.lua study|claims REPO SEED SNAPSHOT OUT_DIR")
local T = setup(repo)
local CM, Ref, Study = T.CM, T.Ref, T.Study
local wp = dofile(T.wp40 .. "/world_protection.lua")
local SIDE = wp.ROAD_SIDE
local weights = {}
local function weight(value)
	local n = tonumber(value)
	assert(n and n >= 0 and n < math.huge, "invalid road study weight: " .. tostring(value))
	return n
end
for w in (os.getenv("R87_WEIGHTS") or "8"):gmatch("[^,%s]+") do weights[#weights + 1] = weight(w) end
assert(#weights > 0, "at least one study weight is required")
local FEE = os.getenv("R87_FEE") and weight(os.getenv("R87_FEE"))
local FULL = os.getenv("R87_FULL") ~= "0"
local report = {}
local function say(fmt, ...) report[#report + 1] = fmt:format(...) end
local function open(name) return assert(io.open(out .. "/" .. name, "wb")) end

-- 1. the world
local t0 = os.clock()
local R1, builds1 = world(repo, seed)
assert(#builds1 >= 1, "the world built no road network")
local cap = builds1[#builds1]
local full_seed = R1.built.full_seed
local Z1 = R1.built.zones_session
local housing_at = housing_of(Z1, CM, dofile(T.wp40 .. "/source/simple_map.lua").world_bounds)
local module1, text1 = R1.main.road_module(), R1.main.road_layout_text()
say("seed %s (full seed %s): world %.1f s, network builds %d, network build %.1f s", seed,
	tostring(full_seed), os.clock() - t0, #builds1, cap.seconds)
say("network layout sha256 %s; full layout (with capital streets) sha256 %s",
	T.sha256(cap.text), T.sha256(text1))

-- the old occupancy
local reference, held = {}, nil
local function target_ground(ground)
	if not held then return ground end
	return Study.claim_ground(held, ground, CM, Ref)
end
if mode == "claims" then
	held = Study.claims(read(before_path), tostring(full_seed), T.sha256)
	say("occupied-home study: %d placed claim chunks", Study.count(held))
else
	local decoded, reason = Ref.decode(read(before_path), T.sha256)
	assert(decoded, "invalid road reference: " .. tostring(reason))
	assert(decoded.seed == tostring(full_seed), "reference seed differs from world " .. tostring(full_seed))
	reference = decoded.chunks
	say("historical road comparison: %s, reset %d, %d housing chunks occupied", before_path,
		decoded.map_reset, Study.count(reference))
end
housing_at = target_ground(housing_at)
local metric = held and "occupied home chunks intersected" or "new housing-area road chunks"

-- 2. the replays on the captured inputs
local PSRC = T.Router.source(repo)
local PM = T.Router.load(repo, PSRC)
local function replay(cfg)
	local opts = copy(cap.opts)
	opts.study = cfg
	collectgarbage()
	local c0 = os.clock()
	local layout = PM.build(cap.seed, opts)
	return layout, PM.serialize(layout), os.clock() - c0
end
local function new_config(weight, propose)
	return Study.config({Ref = Ref, CM = CM, housing_at = housing_at, reference = reference,
		weight = weight, fee = FEE or weight, side = SIDE, propose = propose})
end

local chunks_f = open("chunks.tsv")
local function write_variant(name, layout, st)
	for _, key in ipairs(Study.sorted(st.network)) do
		local cx, cz = parse_key(key)
		chunks_f:write(name, "\t", cx, "\t", cz, "\n")
	end
	local f = open("roads_" .. name .. ".tsv")
	for _, r in ipairs(layout.roads) do
		local n = #r.X
		for i = 1, n do
			if i % 4 == 1 or i == n then
				f:write(r.id, "\t", r.kind, "\t", r.a, "\t", r.b, ("\t%.2f\t%.2f\n"):format(r.X[i], r.Z[i]))
			end
		end
	end
	f:close()
	local COLS = {"cost", "new", "length", "straight", "turns", "bridge", "deck", "deep", "free",
		"cut", "expand", "b", "pin_dropped", "profile"}
	f = open("decisions_" .. name .. ".tsv")
	local head = {"n", "label", "status", "winner"}
	for _, side in ipairs({"ord", "alt"}) do
		for _, c in ipairs(COLS) do head[#head + 1] = side .. "_" .. c end
		head[#head + 1] = side .. "_score"
	end
	head[#head + 1] = "alt_fee"
	f:write(table.concat(head, "\t"), "\n")
	for n, rec in ipairs(st.records) do
		local row = {n, rec.label, rec.status, rec.winner}
		for _, side in ipairs({"ord", "alt"}) do
			local m = rec[side] or {}
			for _, c in ipairs(COLS) do
				local v = m[c]
				row[#row + 1] = type(v) == "number" and v % 1 ~= 0 and ("%.2f"):format(v) or tostring(v == nil and "" or v)
			end
			row[#row + 1] = m.score and ("%.2f"):format(m.score) or ""
		end
		row[#row + 1] = rec.alt and tostring(rec.alt.fee) or ""
		f:write(table.concat(row, "\t"), "\n")
	end
	f:close()
end

local function summarize(layout, st, seconds)
	local s = {roads = #layout.roads, length = 0, cost = 0, seconds = seconds, by = {}, won = 0,
		searches = layout.stats.searches or 0, expansions = layout.stats.expansions or 0,
		failed = table.concat(layout.stats.failed_steps or {}, "; "), loops = layout.stats.loops or 0,
		trails = layout.stats.trails_built or 0, network = st.network, new = Study.count(st.network)}
	for _, r in ipairs(layout.roads) do s.length = s.length + #r.X - 1 end
	for _, rec in ipairs(st.records) do
		s.by[rec.status] = (s.by[rec.status] or 0) + 1
		local w = rec.winner == "alternative" and rec.alt or rec.ord
		s.cost = s.cost + (w.cost or 0)
		if rec.winner == "alternative" then s.won = s.won + 1 end
	end
	return s
end
local function line_of(name, s)
	return ("%s: %d roads (%d loops, %d trails), length %d, base cost %.0f, %s %d, " ..
		"%d searches, %d expansions, %.1f s; failed steps: %s"):format(name, s.roads, s.loops, s.trails,
		s.length, s.cost, metric, s.new, s.searches, s.expansions, s.seconds, s.failed == "" and "none" or s.failed)
end
local function describe(m)
	return ("cost %.0f, new %d, length %d (straight %.0f), turns %d, bridge %d, deck %d, deep %d, " ..
		"free %d, max cut %.1f, expansions %d, ends at %s"):format(m.cost, m.new, m.length, m.straight,
		m.turns, m.bridge, m.deck, m.deep, m.free, m.cut, m.expand, m.b)
end

local cfgO = new_config(0, false)
local layoutO, textO, secO = replay(cfgO)
local identical = textO == cap.text
say("ordinary replay on the patched router: %s the world's network layout",
	identical and "identical to" or "DIFFERS FROM")
if not identical then
	local f = open("summary.txt")
	f:write(table.concat(report, "\n"), "\n")
	f:close()
	error("the patched router's ordinary replay differs from the world's network layout", 0)
end
local base = summarize(layoutO, cfgO.state, secO)
write_variant("ordinary", layoutO, cfgO.state)
say("%s", line_of("ordinary", base))
layoutO, textO = nil, nil

local textW1
for index, w in ipairs(weights) do
	local cfg = new_config(w, true)
	local layout, text, sec = replay(cfg)
	if index == 1 then textW1 = text end
	local name = tostring(w)
	local s = summarize(layout, cfg.state, sec)
	write_variant(name, layout, cfg.state)
	say("")
	say("weight %g, entry fee %g:", w, FEE or w)
	say("  decisions: %d; skipped %d, proposed %d (alternative won %d), same corridor %d, " ..
		"alternative failed %d, degraded %d, straight %d", #cfg.state.records, s.by.skip or 0, s.by.proposed or 0,
		s.won, s.by.same or 0, s.by.alt_failed or 0, s.by.alt_degraded or 0, s.by.straight or 0)
	say("  %s", line_of("network", s))
	local only_o, only_s = 0, 0
	for k in pairs(base.network) do if not s.network[k] then only_o = only_o + 1 end end
	for k in pairs(s.network) do if not base.network[k] then only_s = only_s + 1 end end
	say("  against ordinary: length %+d, base cost %+.0f (%+.2f %%), %s %+d " ..
		"(only ordinary %d, only study %d), expansions %+d, CPU %+.1f s", s.length - base.length,
		s.cost - base.cost, 100 * (s.cost - base.cost) / base.cost, metric, s.new - base.new, only_o, only_s,
		s.expansions - base.expansions, s.seconds - base.seconds)
	if s.failed ~= base.failed then say("  FAILED STEPS CHANGED: ordinary [%s], study [%s]", base.failed, s.failed) end
	-- the most affected route: the winner with the largest extra cost, else
	-- the rejected proposal closest to winning
	local pick
	for _, rec in ipairs(cfg.state.records) do
		if rec.status == "proposed" then
			local won = rec.winner == "alternative"
			local key = won and rec.alt.cost - rec.ord.cost or -(rec.alt.score - rec.ord.score)
			if not pick or (won and not pick.won) or (won == pick.won and key > pick.key) then
				pick = {rec = rec, won = won, key = key}
			end
		end
	end
	if pick then
		say("  most affected route (%s): %s", pick.won and "alternative won" or "closest rejected",
			pick.rec.label)
		say("    ordinary:    %s", describe(pick.rec.ord))
		say("    alternative: %s, fee %g", describe(pick.rec.alt), pick.rec.alt.fee)
	end
end
chunks_f:close()

-- 3. the full map and the claim masks
if FULL and weights[1] then
	local names = {"height", "water", "zone", "roads", "places"}
	-- the fingerprints without road ids, roads in geometry order: a changed
	-- road number alone changes no digest
	local function claim_side(R)
		local W = dofile(repo .. "/tools/r85_mask/world.lua")(repo, R).world
		local mask = CM.build(W)
		local fw = setmetatable({}, {__index = W})
		local roads = {}
		for i, r in ipairs(W.roads) do roads[i] = {id = "-", X = r.X, Z = r.Z, R = r.R, reach = r.reach} end
		table.sort(roads, function(a, b)
			for _, p in ipairs({{a.X[1], b.X[1]}, {a.Z[1], b.Z[1]}, {a.X[#a.X], b.X[#b.X]},
					{a.Z[#a.Z], b.Z[#b.Z]}, {#a.X, #b.X}}) do
				if p[1] ~= p[2] then return p[1] < p[2] end
			end
			for _, axis in ipairs({"X", "Z", "R"}) do
				for i = 1, #a.X do
					if a[axis][i] ~= b[axis][i] then return a[axis][i] < b[axis][i] end
				end
			end
			return a.reach < b.reach
		end)
		fw.roads = roads
		local side = {ground = {}, fp = {}, mask = mask}
		for _, f in ipairs(CM.FACTIONS) do
			side.ground[f] = {}
			for _, c in ipairs(mask.list(f)) do side.ground[f][Ref.key(c[1], c[2])] = true end
		end
		for _, row in ipairs(CM.fingerprints(mask, fw, T.sha256)) do
			side.fp[row[1] .. " " .. Ref.key(row[2], row[3])] = row
		end
		return side
	end
	local map1 = occupancy(Ref, layout_corridors(wp, module1, text1), housing_at, reference)
	local claims1 = claim_side(R1)
	claims1.mask = nil
	-- only the zones session of the first world stays (housing_at)
	R1, builds1, cap, module1, text1 = nil, nil, nil, nil, nil
	collectgarbage()
	collectgarbage()

	local cfgF = new_config(weights[1], true)
	local R2, builds2 = world(repo, seed, {source = PSRC, study = cfgF})
	local net2 = builds2[#builds2].text
	local map2 = occupancy(Ref, layout_corridors(wp, R2.main.road_module(), R2.main.road_layout_text()),
		target_ground(housing_of(R2.built.zones_session, CM, dofile(T.wp40 .. "/source/simple_map.lua").world_bounds)), reference)
	local claims2 = claim_side(R2)
	say("")
	say("full map, weight %g (the world built with the study inside):", weights[1])
	assert(net2 == textW1, "the integrated network differs from the replay")
	say("  its network layout is identical to the replay's")
	local lost_m, gained_m = 0, 0
	for k in pairs(map1) do if not map2[k] then lost_m = lost_m + 1 end end
	for k in pairs(map2) do if not map1[k] then gained_m = gained_m + 1 end end
	say("  %s, every corridor with capital streets: ordinary %d, study %d " ..
		"(only ordinary %d, only study %d)", metric, Study.count(map1), Study.count(map2), lost_m, gained_m)
	local f = open("claims.tsv")
	for _, fac in ipairs(CM.FACTIONS) do
		local a, b = claims1.ground[fac], claims2.ground[fac]
		local lost, gained, changed, reasons, comps = 0, 0, 0, {}, {}
		for _, key in ipairs(Study.sorted(a)) do
			local cx, cz = parse_key(key)
			if not b[key] then
				lost = lost + 1
				local _, why = claims2.mask.ground(fac, cx, cz)
				why = tostring(why or "unknown")
					reasons[why] = (reasons[why] or 0) + 1
				f:write(fac, "\t", cx, "\t", cz, "\tlost\t", tostring(why), "\n")
			else
				local ra, rb = claims1.fp[fac .. " " .. key], claims2.fp[fac .. " " .. key]
				local diff = {}
				for i, name in ipairs(names) do
					if ra[3 + i] ~= rb[3 + i] then
						diff[#diff + 1] = name
						comps[name] = (comps[name] or 0) + 1
					end
				end
				if #diff > 0 then
					changed = changed + 1
					f:write(fac, "\t", cx, "\t", cz, "\tchanged\t", table.concat(diff, ","), "\n")
				end
			end
		end
		for _, key in ipairs(Study.sorted(b)) do
			if not a[key] then
				gained = gained + 1
				local cx, cz = parse_key(key)
				f:write(fac, "\t", cx, "\t", cz, "\tgained\t-\n")
			end
		end
		local rs, cs = {}, {}
		for why, n in pairs(reasons) do rs[#rs + 1] = why .. " " .. n end
		for _, name in ipairs(names) do cs[#cs + 1] = name .. " " .. (comps[name] or 0) end
		table.sort(rs)
		say("  %s claim ground: ordinary %d, study %d; lost %d (%s), gained %d; surviving chunks with " ..
			"changed fingerprints %d (%s)", fac, Study.count(a), Study.count(b), lost,
			#rs > 0 and table.concat(rs, ", ") or "-", gained, changed, table.concat(cs, ", "))
	end
	f:close()
end

local f = open("summary.txt")
f:write(table.concat(report, "\n"), "\n")
f:close()
print(table.concat(report, "\n"))

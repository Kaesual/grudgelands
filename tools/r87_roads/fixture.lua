-- Round 87 ROADS: the portable fixture of the two-candidate routing study
-- (study.lua on the patched real router, router.lua). No world, no engine:
-- a flat synthetic grid (41 x 41 cells of 16 nodes round 0, 0), three
-- villages, a pair road west - east along z = 0 and a join from the south;
-- the housing area is x -192 .. 191, z -32 .. 127, so the ordinary pair road
-- touches the five housing chunks -2 .. 2 of row 0 and a detour along the
-- cell row z = -48 touches none.
--
--   luajit tools/r87_roads/fixture.lua REPO
--
-- Checks: the patched router without a study and observing equals the live
-- one byte for byte; the ordinary new chunks; a reference holding them skips
-- every alternative; an alternative that loses leaves the layout, junctions
-- and occupancy exactly as the ordinary build; one that wins is committed
-- and the occupancy is that of the final roads alone; an unchanged proposal
-- is a tie the ordinary road keeps; the entry fee per move (same chunk,
-- chunk to chunk, re-entry, off housing, an occupied chunk, a diagonal
-- into a corner chunk, a network unlock). Prints the decisions of each case.
local repo = assert(arg[1], "usage: fixture.lua REPO")
local RL = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/road_layout.lua")
local PM = dofile(repo .. "/tools/r87_roads/router.lua").load(repo)
local CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
local Ref = dofile(repo .. "/mods/PLAYER/grug_housing/road_reference.lua")(CM)
local Study = dofile(repo .. "/tools/r87_roads/study.lua")

local checks, failures = 0, 0
local function check(ok, what)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. what)
	end
end

local SEED, SIDE = "8787", 1
local function inputs()
	local nx, height, land = 41, {}, {}
	for k = 0, nx * nx - 1 do height[k], land[k] = 10, true end
	return {
		grid = {nx = nx, nz = nx, cell = 16, x0 = -320, z0 = -320, height = height, land = land},
		simplex = function() return function() return 0 end end,
		terrain_at = function() return 10 end,
		water_at = function() return nil end,
		nodes = {
			{id = "west", kind = "village", x = -256, z = 0, y = 10},
			{id = "east", kind = "village", x = 256, z = 0, y = 10},
			{id = "south", kind = "village", x = 0, z = -192, y = 10},
		},
		order = {
			{op = "pair", kind = "secondary", a = "west", b = "east"},
			{op = "join", kind = "secondary", a = "south"},
		},
	}
end
local function housing_at(x, z)
	return x >= -192 and x <= 191 and z >= -32 and z <= 127
end

local function run(module, o)
	local opts = inputs()
	local cfg
	if o then
		o.Ref, o.CM, o.housing_at, o.side = Ref, CM, o.housing_at or housing_at, SIDE
		cfg = Study.config(o)
		local new = cfg.new
		cfg.new = function(ctx)
			local st = new(ctx)
			local choose = st.choose
			local function audited(road)
				return type(road.ndeep) == "number" and type(road.nfree) == "number" and
					type(road.cost) == "number"
			end
			st.choose = function(road, cost, propose)
				check(audited(road), "the router supplied no audited grade profile")
				return choose(road, cost, function()
					local alt, c = propose()
					if alt then check(audited(alt), "the alternative has no audited grade profile") end
					return alt, c
				end)
			end
			return st
		end
		opts.study = cfg
	end
	local layout = module.build(SEED, opts)
	local junctions = {}
	for _, r in ipairs(layout.roads) do
		local list = {}
		for _, j in ipairs(r.junctions) do list[#list + 1] = j.road .. "@" .. j.idx end
		junctions[#junctions + 1] = r.id .. ":" .. table.concat(list, ",")
	end
	return {text = module.serialize(layout), layout = layout, state = cfg and cfg.state,
		junctions = table.concat(junctions, " "), searches = layout.stats.searches}
end

local function same_set(a, b)
	for k in pairs(a) do if not b[k] then return false end end
	for k in pairs(b) do if not a[k] then return false end end
	return true
end

local function show(name, r)
	print(("%s: %d roads, %d searches, %d new chunks {%s}"):format(name, #r.layout.roads,
		r.searches, Study.count(r.state.network), table.concat(Study.sorted(r.state.network), "; ")))
	for _, rec in ipairs(r.state.records) do
		local line = ("  %-26s %-10s -> %-11s ordinary cost %.1f new %d"):format(rec.label,
			rec.status, rec.winner, rec.ord.cost, rec.ord.new)
		if rec.alt then
			line = line .. (" | alternative cost %.1f (fee %g) new %d length %d"):format(rec.alt.cost,
				rec.alt.fee, rec.alt.new, rec.alt.length)
		end
		print(line)
	end
end

-- 1. neutral: no study, observing
local live = run(RL)
check(run(PM).text == live.text, "the patched router without a study differs from the live one")
local observe = run(PM, {propose = false})
check(observe.text == live.text, "the observing study changes the layout")
show("observe", observe)
local expected = {}
for cx = -2, 2 do expected[Ref.key(cx, 0)] = true end
check(same_set(observe.state.network, expected), "the ordinary new chunks are not -2 .. 2 of row 0")

-- 2. skip: the reference holds every chunk the ordinary roads touch
local skip = run(PM, {reference = observe.state.network, weight = 400})
show("skip", skip)
for _, rec in ipairs(skip.state.records) do
	check(rec.status == "skip", "a road with no new chunk searched an alternative: " .. rec.label)
end
check(skip.text == live.text and skip.searches == observe.searches, "skipping changed the build")

-- 3. lost: the fee detours the pair road, the weight keeps the ordinary one
local lost = run(PM, {weight = 1, fee = 400})
show("lost", lost)
local first = lost.state.records[1]
check(first.status == "proposed" and first.winner == "ordinary" and first.alt.new < first.ord.new,
	"the pair road's alternative is not proposed and rejected")
check(lost.text == live.text, "a rejected alternative changed the layout")
check(lost.junctions == observe.junctions, "a rejected alternative changed a junction")
check(same_set(lost.state.network, observe.state.network), "a rejected alternative occupied a chunk")
check(lost.searches > observe.searches, "no alternative search ran")

-- 4. won: fee and weight 400 per chunk
local won = run(PM, {weight = 400})
show("won", won)
first = won.state.records[1]
check(first.status == "proposed" and first.winner == "alternative" and first.alt.new < first.ord.new,
	"the pair road's alternative does not win")
check(won.text ~= live.text, "the winning alternative is not in the layout")
local occ, final = {}, {}
for _, r in ipairs(won.layout.roads) do
	for k in pairs(Ref.collect({X = r.X, Z = r.Z, reach = r.hw + SIDE}, housing_at, occ)) do
		occ[k], final[k] = true, true
	end
end
check(same_set(won.state.network, final), "the occupancy is not that of the final roads")

-- 5. tie: a fee too small to move the search proposes the same corridor
local tie = run(PM, {weight = 0.001})
show("tie", tie)
first = tie.state.records[1]
check(first.status == "same" and first.winner == "ordinary", "an unchanged proposal is no tie")
check(tie.text == live.text, "a tie changed the layout")
check(first.alt.fee > 0 and math.abs(first.alt.cost - first.ord.cost) < 1e-6,
	"entry fees leaked into the ordinary cost of the same path")

local join = run(PM, {weight = 1, fee = 400, housing_at = function(x, z)
	return math.abs(x) <= 15 and z >= -140 and z <= -50
end})
local branch = join.state.records[2]
check(branch.status == "proposed" and branch.winner == "ordinary", "no rejected join alternative")
check(join.text == live.text and join.junctions == observe.junctions, "a losing join changed the network")

-- 6. the entry fee per move
local HK = {"0 0", "0 0", "1 0", false, "1 1", "5 5"}
local fee_occ = {["5 5"] = true}
local fee = Study.fee_function(HK, fee_occ, 10)
check(fee(1, 2) == 0, "a move inside a chunk pays")
check(fee(4, 1) == 10, "entering housing ground from off it is free")
check(fee(1, 3) == 10, "a crossing between two new chunks is free")
check(fee(1, 4) == 0, "a move off housing ground pays")
check(fee(1, 6) == 0, "an occupied chunk pays")
check(fee(1, 5) == 10, "a diagonal into the corner chunk does not pay once")
check(fee(4, 1) + fee(1, 2) + fee(2, 3) + fee(3, 1) + fee(1, 4) == 30, "a re-entry does not pay again")
fee_occ["1 0"] = true
check(fee(1, 3) == 0, "an accepted road's chunk still pays")

-- A fee must never select a failed elevation profile or a dropped core pin.
do
	local st = Study.config({Ref = Ref, CM = CM, housing_at = housing_at,
		weight = 100}).new({NL = 0})
	local road = {kind = "primary", a = "a", X = {0, 5}, Z = {0, 0}, hw = 1}
	for _, alt in ipairs({{no_core_pin = true}, {cost = math.huge}, {nfree = 1}, {ndeep = 1}}) do
		alt.X, alt.Z, alt.hw, alt.cells = {0, 5}, {300, 300}, 1, {}
		local winner = st.choose(road, 50, function() return alt, 0 end)
		check(winner == road and st.records[#st.records].status == "alt_degraded",
			"an invalid profile displaced the ordinary candidate")
	end
end

-- Re-entering the same new chunk changes the proposal's entry fees only.
-- With two different geometries at the same final score the ordinary one wins.
do
	local st = Study.config({Ref = Ref, CM = CM, housing_at = housing_at, weight = 10})
		.new({NL = 2, KOF = {1, 2}, cxz = function(k) return k == 1 and 0 or 80, 0 end})
	local a = {kind = "primary", a = "a", X = {0, 80, 0}, Z = {0, 0, 0}, hw = 1}
	local b = {X = {0, 5}, Z = {0, 0}, hw = 1, cells = {1, 2, 1}}
	local winner = st.choose(a, 20, function() return b, 50 end)
	local rec = st.records[1]
	check(rec.ord.new == 2 and rec.alt.new == 1 and rec.alt.fee == 20, "distinct footprint or entry fee")
	check(winner == a and rec.alt.score == rec.ord.score, "the ordinary road lost a tied score")
end

-- A reserved home and free ground on the very same route.
local function occupied_study(held, weight)
	return run(PM, {housing_at = Study.claim_ground(held, housing_at, CM, Ref), weight = weight})
end
local empty = occupied_study({}, 400)
check(empty.text == live.text and empty.searches == observe.searches, "an empty map paid for a road")
local held = {["0 0"] = true}
local occupied = occupied_study(held, 400)
local home = occupied.state.records[1]
check(home.ord.new == 1 and home.alt and home.alt.new == 0 and home.winner == "alternative",
	"avoiding a placed home failed or empty chunks were charged")
local distant = occupied_study({["80 70"] = true}, 400)
check(distant.text == live.text and distant.searches == observe.searches, "an unrelated home changed roads")

print(("r87 roads fixture: %d checks, %d failures"):format(checks, failures))
assert(failures == 0, "road study fixture failed")

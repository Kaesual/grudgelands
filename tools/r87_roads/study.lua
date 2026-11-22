-- Round 87 ROADS: the two-candidate decision of the routing study, handed to
-- the patched router (router.lua) as `opts.study`. Pure; every world query
-- is injected.
--
-- Per routed road (pairs, joins, loops, trails; ordinary searches, pin
-- retries, budgets and the loop check unchanged):
--   1. the ordinary candidate; its NEW chunks are the housing chunks its final
--      smoothed corridor (half width + side) touches that neither the
--      reference nor an accepted road of this build occupies
--      (road_reference.lua collect);
--   2. none: it is taken, no alternative is searched ("skip");
--   3. otherwise the same attempt with an ENTRY FEE in the A* proposes an
--      alternative: a move whose target cell centre lies on housing ground in
--      a chunk not yet occupied pays `fee` when it comes from another chunk or
--      from off housing ground (leaving and coming back pays again);
--   4. each candidate scores its ordinary routing cost (the fee taken off
--      again) + weight x its distinct new chunks; the alternative wins only
--      when strictly lower and a different corridor ("same" otherwise); a
--      failed alternative keeps the ordinary one ("alt_failed");
--   5. only the committed winner adds its new chunks to the occupancy, which
--      the fee and the later decisions read (a network-wide unlock).
-- With `propose = false` the study only observes (the ordinary build).
--
--   local Study = dofile(repo .. "/tools/r87_roads/study.lua")
--   local cfg = Study.config({Ref = Ref, CM = CM, housing_at = fn, reference = set,
--       weight = 80, fee = 80, side = 1, propose = true})
--   opts.study = cfg            -- then road_module.build(seed, opts)
--   cfg.state.records           -- one per decision, build order (see `measure`)
--   cfg.state.network           -- the chunks the accepted roads newly occupy
local sqrt, max = math.sqrt, math.max

local S = {}

function S.count(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

-- The keys of a 'cx cz' set in row order (cz, then cx).
function S.sorted(set)
	local list = {}
	for key in pairs(set) do list[#list + 1] = key end
	local function parts(key)
		local cx, cz = key:match("^(%-?%d+) (%-?%d+)$")
		return tonumber(cx), tonumber(cz)
	end
	table.sort(list, function(a, b)
		local ax, az = parts(a)
		local bx, bz = parts(b)
		if az ~= bz then return az < bz end
		return ax < bx
	end)
	return list
end

-- Study input from the stopped world's claim registry. A sealed empty set
-- means that every road is free. A road reference is a different file type.
function S.claims(bytes, seed, sha256)
	local body, digest = bytes:match("^(.*\n)end (%x+)\n$")
	assert(body and digest == sha256(body), "damaged claim snapshot")
	local lines = body:gmatch("([^\n]*)\n")
	assert(lines() == "grug_claim_chunks_v1" and lines() == "seed " .. seed,
		"claim snapshot format or seed differs")
	local count = tonumber((lines() or ""):match("^count (%d+)$"))
	assert(count, "missing claim count")
	local claims = {}
	for i = 1, count do
		local key = lines()
		assert(key and key:match("^%-?%d+ %-?%d+$") and not claims[key], "invalid claim chunk")
		claims[key] = true
	end
	assert(not lines(), "trailing claim rows")
	return claims
end

function S.claim_ground(claims, housing_at, CM, Ref)
	return function(x, z)
		return claims[Ref.key(CM.chunk_of(x), CM.chunk_of(z))] and housing_at(x, z) or false
	end
end

-- The entry fee of a move li -> lj. HK[li]: the chunk key of the cell
-- centre on housing ground, or false; `occ` is read live.
function S.fee_function(HK, occ, fee)
	return function(li, lj)
		local kj = HK[lj]
		if not kj or occ[kj] or HK[li] == kj then return 0 end
		return fee
	end
end

-- A candidate's numbers for the report.
local function measure(road, cost, new)
	local X, Z, n = road.X, road.Z, #road.X
	local rx, rz = X[n] - X[1], Z[n] - Z[1]
	local turns = 0
	local dirs = road.dirs or {}
	for i = 2, #dirs do
		if dirs[i] ~= dirs[i - 1] then turns = turns + 1 end
	end
	local bridge, deck, cut = 0, 0, 0
	for i = 1, n do
		local c = road.cls and road.cls[i]
		if c == "B" then bridge = bridge + 1 elseif c == "D" then deck = deck + 1 end
		if c == "G" and road.T and road.R then cut = max(cut, road.T[i][1] - road.R[i]) end
	end
	return {cost = cost, new = S.count(new), chunks = new, length = n - 1,
		straight = sqrt(rx * rx + rz * rz), turns = turns, bridge = bridge, deck = deck,
		deep = road.ndeep or 0, free = road.nfree or 0, cut = cut, expand = road.expand or 0,
		b = tostring(road.b), pin_dropped = road.no_core_pin == true, profile = road.cost}
end

local function same_corridor(p, q)
	if #p.X ~= #q.X then return false end
	for i = 1, #p.X do
		if p.X[i] ~= q.X[i] or p.Z[i] ~= q.Z[i] then return false end
	end
	return true
end

function S.config(o)
	local cfg = {weight = o.weight or 0, fee = o.fee or o.weight or 0, propose = o.propose ~= false}
	local Ref, CM, housing_at, side = o.Ref, o.CM, o.housing_at, o.side or 1
	-- ctx: the router's land cells (NL, KOF) and cell centres (cxz)
	function cfg.new(ctx)
		local st = {records = {}, occ = {}, network = {}}
		cfg.state = st
		for key in pairs(o.reference or {}) do st.occ[key] = true end
		local HK = {}
		for li = 1, ctx.NL do
			local x, z = ctx.cxz(ctx.KOF[li])
			HK[li] = housing_at(x, z) and Ref.key(CM.chunk_of(x), CM.chunk_of(z)) or false
		end
		st.fee_at = S.fee_function(HK, st.occ, cfg.fee)
		-- the new chunks of the candidates of the current decision
		local fresh = {}
		local function collect(road)
			local set = fresh[road]
			if not set then
				set = Ref.collect({X = road.X, Z = road.Z, reach = road.hw + side}, housing_at, st.occ)
				fresh[road] = set
			end
			return set
		end
		local function label(road)
			return road.kind .. " " .. tostring(road.a) .. " " ..
				(road.b_node and tostring(road.b_node.id) or "join")
		end

		function st.choose(road, cost, propose)
			local rec = {label = label(road), ord = measure(road, cost, collect(road))}
			st.records[#st.records + 1] = rec
			rec.ord.score = cost + cfg.weight * rec.ord.new
			local winner, wcost = road, cost
			if not cfg.propose then
				rec.status = "observe"
			elseif rec.ord.new == 0 then
				rec.status = "skip"
			else
				local t0 = os.clock()
				local alt, alt_cost = propose()
				rec.seconds = os.clock() - t0
				if not alt then
					rec.status = "alt_failed"
				else
					local fee = 0
					for i = 2, #alt.cells do fee = fee + st.fee_at(alt.cells[i - 1], alt.cells[i]) end
					rec.alt = measure(alt, alt_cost - fee, collect(alt))
					rec.alt.fee = fee
					local degraded = alt.no_core_pin or alt.cost == math.huge or
						rec.alt.free > rec.ord.free or rec.alt.deep > rec.ord.deep
					rec.alt.score = rec.alt.cost + cfg.weight * rec.alt.new
					if degraded then
						rec.status = "alt_degraded"
					elseif same_corridor(road, alt) then
						rec.status = "same"
					else
						rec.status = "proposed"
						if rec.alt.score < rec.ord.score - 1e-9 then winner, wcost = alt, rec.alt.cost end
					end
				end
			end
			rec.winner = winner == road and "ordinary" or "alternative"
			return winner, wcost
		end

		-- a road that joins the network (a chosen one or the arena's straight one)
		function st.accept(road)
			local set = collect(road)
			for key in pairs(set) do
				st.occ[key] = true
				st.network[key] = true
			end
			if not road.cells then
				st.records[#st.records + 1] = {label = road.kind .. " " .. tostring(road.a) .. " " ..
					tostring(road.b), status = "straight", winner = "ordinary",
					ord = measure(road, 0, set)}
			end
			fresh = {}
		end
		return st
	end
	return cfg
end

return S

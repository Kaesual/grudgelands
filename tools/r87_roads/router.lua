-- Round 87 ROADS: the real road router (wp40/road_layout.lua) with the
-- two-candidate study hooked in, for offline runs only. The live file is
-- read and five anchored edits are applied to the text in memory; nothing is
-- written and the game never loads this. Without `opts.study` the patched
-- build does exactly what the live one does (the fixture and run.lua check
-- the layout text byte for byte).
--
--   local Router = dofile(repo .. "/tools/r87_roads/router.lua")
--   local src = Router.source(repo)   -- the patched text
--   local M = Router.load(repo)       -- the patched module (as road_layout.lua's)
--
-- The edits (each anchor must match exactly once):
--   1. build: `FEE_AT` (nil, or the study's entry fee of a move) and `STUDY`
--      (opts.study.new(...) or nil) before the search's scratch arrays.
--   2. search: a relaxed move adds FEE_AT(li, lj) after its ordinary cost.
--   3. `routed` becomes `attempt`: the same searches, pin retries, loop check
--      and audit, but it returns the candidate instead of committing it.
--   4. a new `routed`: the ordinary attempt, then STUDY.choose(road, cost,
--      propose), where propose runs the same attempt with the fee on; only the
--      winner is committed and handed to STUDY.accept.
--   5. straight (the arena's inner road): STUDY.accept before it joins.
local Router = {}

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- The new `routed` (edit 4), every line indented by `i`.
local ROUTED = {
	"local function routed(kind, a, b_fixed, do_search)",
	"\tlocal before = nexpand",
	"\tlocal road, cost = attempt(kind, a, b_fixed, do_search)",
	"\tif road and STUDY then",
	"\t\troad.expand = nexpand - before",
	"\t\troad, cost = STUDY.choose(road, cost, function()",
	"\t\t\tFEE_AT = STUDY.fee_at",
	"\t\t\tlocal alt_before = nexpand",
	"\t\t\tlocal alt, alt_cost = attempt(kind, a, b_fixed, do_search)",
	"\t\t\tif alt then alt.expand = nexpand - alt_before end",
	"\t\t\tFEE_AT = nil",
	"\t\t\treturn alt, alt_cost",
	"\t\tend)",
	"\tend",
	"\tif not road then return nil end",
	"\tif STUDY then STUDY.accept(road) end",
	"\treturn commit(road), cost",
	"end",
}
local function routed_text(i)
	local out = {}
	for n, line in ipairs(ROUTED) do out[n] = i .. line .. "\n" end
	return table.concat(out)
end

function Router.source(repo)
	local src = read(repo .. "/mods/MAPGEN/grug_mapgen/wp40/road_layout.lua")
	local function edit(what, pattern, replace)
		local out, n = src:gsub(pattern, replace)
		if n ~= 1 then error("r87 router: anchor '" .. what .. "' matched " .. n .. " times", 0) end
		src = out
	end
	edit("scratch arrays", "\n([ \t]*)%-%- scratch state arrays %(reused; generation%-stamped%)\n",
		function(i)
			return "\n" .. i .. "local FEE_AT\n" .. i ..
				"local STUDY = opts.study and opts.study.new({NL = NL, KOF = KOF, cxz = cxz})\n" ..
				i .. "-- scratch state arrays (reused; generation-stamped)\n"
		end)
	edit("platform cost", "(c = c %+ P%.K_PLATFORM %* sl %* C\n([ \t]*)end\n)",
		function(all, i) return all .. i .. "if FEE_AT then c = c + FEE_AT(li, lj) end\n" end)
	edit("routed", "local function routed%(kind, a, b_fixed, do_search%)",
		function() return "local function attempt(kind, a, b_fixed, do_search)" end)
	edit("commit", "audit%(road%)\n([ \t]*)return commit%(road%), cost\n([ \t]*)end\n",
		function(i1, i2)
			return "audit(road)\n" .. i1 .. "return road, cost\n" .. i2 .. "end\n" ..
				routed_text(i2)
		end)
	edit("straight", "audit%(road%)\n([ \t]*)roads%[road%.id%] = road\n",
		function(i)
			return "audit(road)\n" .. i .. "if STUDY then STUDY.accept(road) end\n" .. i ..
				"roads[road.id] = road\n"
		end)
	return src
end

function Router.load(repo, src)
	return assert(loadstring(src or Router.source(repo), "=road_layout.lua (r87 study)"))()
end

return Router

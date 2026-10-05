-- Round 25 Lane H portable harness (LuaJIT): the capital planning phase of a
-- world's first boot, per seed, without the engine.
--
--   luajit tools/r25_capital_plots/harness.lua <repo> <out.tsv> seed [seed ...]
--
-- Built as the runtime builds it (the shared `wp40/world_assembly.lua`: the
-- horizontal + height session, inland water, road layout, main's plot
-- preparations, `r7_capitals.plan_all`) against the repo tree given as
-- <repo>, so the same file measures main and a branch.
-- `planner.plan` is wrapped to record, per capital: the required plots that
-- are missing (production fails the load on the first one; here a stand-in
-- entry is appended so the following capitals still plan), the named
-- (non-fill, non-required) plots left out, the number of fill pieces left
-- out, how many plots missed their own quarter in pass 1 (overflowed or
-- left out; `nb` counts only required and named ones -- a relaxed plot may
-- land in its own quarter and then shows only under `relaxed`, so "every
-- building fit its quarter in pass 1" is nb = 0 AND relaxed empty), the
-- plots placed with relaxed legality and a SHA-256 (first 16 hex) of
-- `planner.serialize(plan)`, the text the world stores.
--
-- One TSV line per seed: seed, status (OK | FAIL | ERROR), CPU seconds,
-- the failures (anchor:ids), then one field per capital
--   key[miss=..;leftbld=..;leftfill=N;ovf=N;nb=N;relaxed=..;digest=HEX16]
local repo, out_path = arg[1], arg[2]
assert(repo and out_path and arg[3], "usage: harness.lua <repo> <out.tsv> seed [seed ...]")
local seeds = {}
for i = 3, #arg do seeds[#seeds + 1] = arg[i] end
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()
local A = dofile(dir .. "/world_assembly.lua")(dir, raw_sha256)
local planner = A.capitals.planner
local key_of = {}
for _, profile in ipairs(A.capital_profiles) do key_of[profile.anchor_id] = profile.key end
-- plot preparations are seed-independent: once per process
A.capital_plots()

local original_plan = planner.plan
local current = {}
planner.plan = function(seed, I, opt)
	local plan = original_plan(seed, I, opt)
	local rec = {key = key_of[I.anchor.id] or I.anchor.id, missing = {}, left_bld = {},
		left_fill = 0, relaxed = {}}
	local placed, kind_of = {}, {}
	for _, p in ipairs(plan.plots) do placed[p.id] = true end
	for _, p in ipairs(I.plots) do
		kind_of[p.id] = p
		if p.required and not placed[p.id] then rec.missing[#rec.missing + 1] = p.id end
	end
	for _, p in ipairs(plan.left_out) do
		if p.kind == "fill" and not p.required then
			rec.left_fill = rec.left_fill + 1
		elseif not p.required then
			rec.left_bld[#rec.left_bld + 1] = p.id
		end
	end
	for _, id in ipairs(plan.relaxed) do rec.relaxed[#rec.relaxed + 1] = id end
	-- plots that missed their own quarter: overflowed (pass 2 or 3) or left out
	local missed = {}
	for _, id in ipairs(plan.stats.overflowed or {}) do missed[id] = true end
	for _, p in ipairs(plan.left_out) do missed[p.id] = true end
	rec.ovf, rec.nb = 0, 0
	for id in pairs(missed) do
		rec.ovf = rec.ovf + 1
		local p = kind_of[id]
		if p and (p.required or p.kind ~= "fill") then rec.nb = rec.nb + 1 end
	end
	rec.digest = raw_sha256(planner.serialize(plan)):sub(1, 8):gsub(".",
		function(c) return ("%02x"):format(c:byte()) end)
	current[#current + 1] = rec
	-- stand-in so plan_all continues with the next capital
	local template = plan.plots[1]
	for _, id in ipairs(rec.missing) do
		local copy = {}
		for k, v in pairs(template) do copy[k] = v end
		copy.id, copy.required = id, true
		plan.plots[#plan.plots + 1] = copy
	end
	return plan
end

local out = assert(io.open(out_path, "a"))
for _, seed in ipairs(seeds) do
	current = {}
	local t0 = os.clock()
	local ok, err = pcall(function() A.world(seed).plan_capitals() end)
	local secs = os.clock() - t0
	local fails, detail = {}, {}
	for _, rec in ipairs(current) do
		if #rec.missing > 0 then fails[#fails + 1] = rec.key .. ":" .. table.concat(rec.missing, "+") end
		detail[#detail + 1] = ("%s[miss=%s;leftbld=%s;leftfill=%d;ovf=%d;nb=%d;relaxed=%s;digest=%s]"):format(
			rec.key, table.concat(rec.missing, "+"), table.concat(rec.left_bld, "+"), rec.left_fill,
			rec.ovf, rec.nb, table.concat(rec.relaxed, "+"), rec.digest)
	end
	local status = not ok and "ERROR" or (#fails > 0 and "FAIL" or "OK")
	out:write(table.concat({seed, status, ("%.1f"):format(secs),
		ok and table.concat(fails, " ") or (tostring(err):gsub("[\t\n]", " ")),
		table.concat(detail, " ")}, "\t"), "\n")
	out:flush()
	io.stderr:write(seed, " ", status, " ", ("%.1f"):format(secs), " ", table.concat(fails, " "), "\n")
end
out:close()
